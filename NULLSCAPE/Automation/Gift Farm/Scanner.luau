--!nocheck

local CollectionService = game:GetService("CollectionService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Progress = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Progress.luau")
local Collapse = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Collapse.luau")
local GoldenEfficiency = getgenv().loadModule("NULLSCAPE/Automation/GoldenEfficiency.luau")
local NativeGiftRegistry = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Native Gift Registry.luau")
local RuntimeBudget = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Runtime Budget.luau")

local Scanner = {}
local SPAWN_SETTLE = 0.22
local GOLDEN_SPAWN_SETTLE = 0.05
local FANNY_PACK_TILE_PRIORITY = 4
local FANNY_PACK_CACHE_INTERVAL = RuntimeBudget.Scanner.FannyPackCacheInterval
local SCAN_SAFETY_INTERVAL = RuntimeBudget.Scanner.SafetyInterval
local SCAN_FRAME_BUDGET = RuntimeBudget.Scanner.FrameBudget
local SCAN_CHECK_INTERVAL = RuntimeBudget.Scanner.CheckInterval
local TRACKED_GIFT_TYPES = { "PassageGift", "GoldenGift", "Gift" }
local GOLDEN_GIFT_TYPES = { "PassageGift", "GoldenGift" }

local seenGifts = setmetatable({}, { __mode = "k" })
local peakRawGolden = 0
local peakRawNormal = 0
local cachedUpgradeHandler = nil
local lastFannyPackCheckAt = -math.huge
local cachedHasFannyPack = false
local cachedFannyPackTiles = nil
local fannyPackTileSet = {}
local fannyPackConnections = {}
local fannyPackTrackingStarted = false
local fannyPackTilesDirty = true
local lastScanRevision = -1
local lastScanAt = -math.huge
local lastConfigSignature = nil
local nextSettleAt = nil
local cachedCandidates = nil
local cachedInfo = nil
local stats = {
	Scans = 0,
	CacheHits = 0,
	LastDuration = 0,
	LastGiftCount = 0,
}

local function startFannyPackTracking()
	if fannyPackTrackingStarted then
		return
	end
	fannyPackTrackingStarted = true
	for _, tile in ipairs(CollectionService:GetTagged("FannyPackTile")) do
		fannyPackTileSet[tile] = true
	end
	fannyPackConnections[#fannyPackConnections + 1] = CollectionService:GetInstanceAddedSignal("FannyPackTile")
		:Connect(function(tile)
			fannyPackTileSet[tile] = true
			fannyPackTilesDirty = true
		end)
	fannyPackConnections[#fannyPackConnections + 1] = CollectionService:GetInstanceRemovedSignal("FannyPackTile")
		:Connect(function(tile)
			fannyPackTileSet[tile] = nil
			fannyPackTilesDirty = true
		end)
end

local function rebuildFannyPackTiles()
	local tiles = {}
	for tile in pairs(fannyPackTileSet) do
		if tile and tile:IsA("BasePart") and tile:IsDescendantOf(workspace) then
			tiles[#tiles + 1] = tile
		else
			fannyPackTileSet[tile] = nil
		end
	end
	cachedFannyPackTiles = tiles
	fannyPackTilesDirty = false
end

local function getUpgradeHandler()
	if cachedUpgradeHandler ~= nil then
		return cachedUpgradeHandler
	end

	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local upgradeHandlerModule = clientModules and clientModules:FindFirstChild("UpgradeHandler")
	if not upgradeHandlerModule then
		local core = clientModules and clientModules:FindFirstChild("Core")
		local playerData = core and core:FindFirstChild("PlayerData")
		upgradeHandlerModule = playerData and playerData:FindFirstChild("UpgradeHandler")
	end

	if not upgradeHandlerModule then
		return nil
	end

	local ok, handler = pcall(require, upgradeHandlerModule)
	if ok then
		cachedUpgradeHandler = handler
	end
	return cachedUpgradeHandler
end

local function getActiveUpgradeStack(upgradeName)
	local handler = getUpgradeHandler()
	if typeof(handler) == "table" and typeof(handler.GetActiveUpgrades) == "function" then
		local ok, upgrades = pcall(handler.GetActiveUpgrades)
		if ok and typeof(upgrades) == "table" then
			local value = upgrades[upgradeName]
			if value == true then
				return 1
			end
			return tonumber(value) or 0
		end
	end

	local folder = ReplicatedStorage:FindFirstChild("UpgradeFolder")
	local clientUpgrades = folder and folder:FindFirstChild("ClientUpgrades")
	local direct = clientUpgrades and clientUpgrades:FindFirstChild(upgradeName)
	if direct and (direct:IsA("IntValue") or direct:IsA("NumberValue") or direct:IsA("BoolValue")) then
		return direct:IsA("BoolValue") and (direct.Value and 1 or 0) or (tonumber(direct.Value) or 0)
	end

	return 0
end

local function pointInsidePart(part, position)
	if not (part and part:IsA("BasePart") and position) then
		return false
	end

	local localPosition = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size * 0.5 + Vector3.new(2, 6, 2)
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function getFannyPackTilePriority(position, fannyPackTiles)
	if not fannyPackTiles then
		return 0
	end

	for _, tile in ipairs(fannyPackTiles) do
		if pointInsidePart(tile, position) then
			return FANNY_PACK_TILE_PRIORITY
		end
	end
	return 0
end

local function getFannyPackState(now)
	startFannyPackTracking()
	if now - lastFannyPackCheckAt >= FANNY_PACK_CACHE_INTERVAL then
		cachedHasFannyPack = getActiveUpgradeStack("FannyPack") > 0
		lastFannyPackCheckAt = now
	end
	if cachedHasFannyPack and (fannyPackTilesDirty or cachedFannyPackTiles == nil) then
		rebuildFannyPackTiles()
	end
	return cachedHasFannyPack, cachedHasFannyPack and cachedFannyPackTiles or nil
end

local function visitLiveGifts(gch, callback)
	local gifts = gch and gch.Gifts
	if typeof(gifts) ~= "table" then
		return 0
	end
	local giftsByType = gch.GiftsByType
	local visitedIds = {}
	local count = 0
	local sliceStartedAt = os.clock()
	local function visit(giftId, gift)
		if visitedIds[giftId] then
			return
		end
		visitedIds[giftId] = true
		count += 1
		callback(gift)
		if count % SCAN_CHECK_INTERVAL == 0 and os.clock() - sliceStartedAt >= SCAN_FRAME_BUDGET then
			task.wait()
			sliceStartedAt = os.clock()
		end
	end

	if typeof(giftsByType) == "table" then
		for _, giftType in ipairs(TRACKED_GIFT_TYPES) do
			local giftIds = giftsByType[giftType]
			if typeof(giftIds) == "table" then
				for giftId in pairs(giftIds) do
					visit(giftId, gifts[giftId])
				end
			end
		end
		if count == 0 and next(gifts) ~= nil then
			for giftId, gift in pairs(gifts) do
				visit(giftId, gift)
			end
		end
	else
		for giftId, gift in pairs(gifts) do
			visit(giftId, gift)
		end
	end
	return count
end

local function getEffectiveGoldenPercent(controller)
	local configured = tonumber(controller and controller.GiftFarmGoldenEfficiency) or 100
	local floorPercent = math.clamp(tonumber(controller and controller.GiftFarmGoldenEfficiencyFloor) or 0, 0, 100)
	if floorPercent <= 0 then
		return configured
	end
	local normalizedConfigured = if configured <= 0 then 100 else math.clamp(configured, 0, 100)
	return math.max(normalizedConfigured, floorPercent)
end

local function getConfigSignature(controller)
	return tostring(getEffectiveGoldenPercent(controller))
		.. ":"
		.. tostring(controller and controller.GiftFarmXpTripcoinMode == true)
end

function Scanner.reset()
	seenGifts = setmetatable({}, { __mode = "k" })
	peakRawGolden = 0
	peakRawNormal = 0
	lastFannyPackCheckAt = -math.huge
	cachedHasFannyPack = false
	lastScanRevision = -1
	lastScanAt = -math.huge
	lastConfigSignature = nil
	nextSettleAt = nil
	cachedCandidates = nil
	cachedInfo = nil
	if Collapse and typeof(Collapse.reset) == "function" then
		Collapse.reset()
	end
end

function Scanner.stop()
	for _, connection in ipairs(fannyPackConnections) do
		connection:Disconnect()
	end
	table.clear(fannyPackConnections)
	table.clear(fannyPackTileSet)
	fannyPackTrackingStarted = false
	fannyPackTilesDirty = true
	cachedFannyPackTiles = nil
	if Collapse and typeof(Collapse.stop) == "function" then
		Collapse.stop()
	end
	Scanner.reset()
end

function Scanner.isGoldenTargetReached(gch, controller)
	local collected, maximum = Progress.getGoldenGiftProgress(gch)
	return GoldenEfficiency.evaluate(getEffectiveGoldenPercent(controller), collected, maximum).Reached
end

function Scanner.getLiveGoldenKind(gch, controller)
	if Scanner.isGoldenTargetReached(gch, controller) then
		return nil
	end
	local gifts = gch and gch.Gifts
	local giftsByType = gch and gch.GiftsByType
	if typeof(gifts) ~= "table" or typeof(giftsByType) ~= "table" then
		return nil
	end

	for _, giftType in ipairs(GOLDEN_GIFT_TYPES) do
		local giftIds = giftsByType[giftType]
		if giftIds then
			for giftId in pairs(giftIds) do
				local gift = gifts[giftId]
				if gift and gift.Golden == true and not gift.Destroyed and not gift.Collected then
					return giftType
				end
			end
		end
	end
	return nil
end

function Scanner.scan(controller, gch)
	NativeGiftRegistry.start()
	local now = os.clock()
	local revision = NativeGiftRegistry.getRevision()
	local configSignature = getConfigSignature(controller)
	local settleDue = nextSettleAt ~= nil and now >= nextSettleAt
	if
		cachedCandidates
		and revision == lastScanRevision
		and configSignature == lastConfigSignature
		and not settleDue
		and now - lastScanAt < SCAN_SAFETY_INTERVAL
	then
		stats.CacheHits += 1
		return cachedCandidates, cachedInfo
	end

	local scanStartedAt = os.clock()
	local goldenGifts = {}
	local normalGifts = {}
	local _, _, normalRatio = Progress.getNormalGiftProgress(gch)
	local goldenCollected, goldenMax, goldenRatio = Progress.getGoldenGiftProgress(gch)
	local goldenEfficiency = GoldenEfficiency.evaluate(getEffectiveGoldenPercent(controller), goldenCollected, goldenMax)
	local goldenFloor = tonumber(controller and controller.GiftFarmGoldenEfficiencyFloor) or 0
	local normalOnly = controller and controller.GiftFarmXpTripcoinMode == true and goldenFloor <= 0
	local rawGolden, rawPassage, rawNormal = 0, 0, 0
	local settledGolden, settledPassage, settledNormal = 0, 0, 0
	local hasFannyPack, fannyPackTiles = getFannyPackState(now)
	local collapseTiles = Collapse and typeof(Collapse.prepareScan) == "function" and Collapse.prepareScan() or nil
	local earliestSettleAt = nil
	local visitedCount = visitLiveGifts(gch, function(gift)
		if not (gift and not gift.Destroyed and not gift.Collected and not gift.Tripmine) then
			return
		end
		local pos = Context.getGiftPosition(gift)
		local priority = Progress.getGiftPriority(gift, normalRatio, controller)
		if not pos or priority == nil then
			return
		end

		local isGolden = gift.Golden == true
		local isPassage = gift.Type == "PassageGift"
		if isGolden then
			rawGolden += 1
			if isPassage then
				rawPassage += 1
			end
		else
			rawNormal += 1
		end
		if not seenGifts[gift] then
			seenGifts[gift] = now
		end
		local settleTime = isGolden and GOLDEN_SPAWN_SETTLE or SPAWN_SETTLE
		local settleAt = seenGifts[gift] + settleTime
		if now < settleAt then
			earliestSettleAt = math.min(earliestSettleAt or settleAt, settleAt)
			return
		end

		if isGolden then
			settledGolden += 1
			if isPassage then
				settledPassage += 1
			end
		else
			settledNormal += 1
		end
		local collapsePriority = Collapse
				and typeof(Collapse.getGiftUrgency) == "function"
				and Collapse.getGiftUrgency(pos, collapseTiles)
			or 0
		local candidates = isGolden and goldenGifts or normalGifts
		candidates[#candidates + 1] = {
			rawObj = gift,
			pos = pos,
			priority = priority,
			collapsePriority = collapsePriority,
			bonusTilePriority = getFannyPackTilePriority(pos, fannyPackTiles),
			id = gift.Id or 0,
			golden = isGolden,
			passage = isPassage,
		}
	end)

	peakRawGolden = math.max(peakRawGolden, rawGolden)
	peakRawNormal = math.max(peakRawNormal, rawNormal)
	local actionableRawGolden = (normalOnly or goldenEfficiency.Reached) and 0 or rawGolden
	local actionableRawPassage = (normalOnly or goldenEfficiency.Reached) and 0 or rawPassage
	local candidates = actionableRawGolden > 0 and goldenGifts or normalGifts
	local info = {
		Golden = settledGolden,
		Passage = settledPassage,
		Normal = settledNormal,
		RawGolden = actionableRawGolden,
		RawPassage = actionableRawPassage,
		TotalRawGolden = rawGolden,
		TotalRawPassage = rawPassage,
		RawNormal = rawNormal,
		PeakRawGolden = peakRawGolden,
		PeakRawNormal = peakRawNormal,
		GoldenRemainingRatio = peakRawGolden > 0 and rawGolden / peakRawGolden or 1,
		GoldenCollected = goldenCollected,
		GoldenMax = goldenMax,
		GoldenProgressRatio = goldenRatio,
		GoldenProgressComplete = goldenMax > 0 and goldenCollected >= goldenMax,
		GoldenTargetPercent = goldenEfficiency.TargetPercent,
		GoldenTargetReached = goldenEfficiency.Reached,
		GoldenTargetFloorPercent = math.clamp(goldenFloor, 0, 100),
		NormalRemainingRatio = peakRawNormal > 0 and rawNormal / peakRawNormal or 1,
		CollapseTracked = true,
		FannyPackTracked = hasFannyPack,
		GoldenLocked = actionableRawGolden > 0,
		PassageLocked = actionableRawPassage > 0,
	}

	lastScanRevision = revision
	lastConfigSignature = configSignature
	lastScanAt = now
	nextSettleAt = earliestSettleAt
	cachedCandidates = candidates
	cachedInfo = info
	stats.Scans += 1
	stats.LastDuration = os.clock() - scanStartedAt
	stats.LastGiftCount = visitedCount
	return candidates, info
end

function Scanner.getStats()
	return table.clone(stats)
end

return Scanner
