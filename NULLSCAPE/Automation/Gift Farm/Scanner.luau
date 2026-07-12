--!nocheck

local CollectionService = game:GetService("CollectionService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Progress = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Progress.luau")
local Collapse = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Collapse.luau")

local Scanner = {}
local SPAWN_SETTLE = 0.22
local GOLDEN_SPAWN_SETTLE = 0.05
local FANNY_PACK_TILE_PRIORITY = 4
local seenGifts = setmetatable({}, { __mode = "k" })
local peakRawGolden = 0
local peakRawNormal = 0
local cachedUpgradeHandler = nil
local lastFannyPackCheckAt = -math.huge
local cachedHasFannyPack = false
local cachedFannyPackTiles = nil
local FANNY_PACK_CACHE_INTERVAL = 0.4

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
	if now - lastFannyPackCheckAt >= FANNY_PACK_CACHE_INTERVAL then
		cachedHasFannyPack = getActiveUpgradeStack("FannyPack") > 0
		cachedFannyPackTiles = if cachedHasFannyPack then CollectionService:GetTagged("FannyPackTile") else nil
		lastFannyPackCheckAt = now
	end

	return cachedHasFannyPack, cachedFannyPackTiles
end

function Scanner.reset()
	seenGifts = setmetatable({}, { __mode = "k" })
	peakRawGolden = 0
	peakRawNormal = 0
	lastFannyPackCheckAt = -math.huge
	cachedHasFannyPack = false
	cachedFannyPackTiles = nil
	if Collapse and typeof(Collapse.reset) == "function" then
		Collapse.reset()
	end
end

function Scanner.scan(controller, gch)
	local gifts = {}
	local goldenGifts = {}
	local normalGifts = {}
	local now = os.clock()
	local _, _, normalRatio = Progress.getNormalGiftProgress(gch)
	local rawGolden = 0
	local rawNormal = 0
	local hasFannyPack, fannyPackTiles = getFannyPackState(now)

	for _, gift in pairs(gch.Gifts or {}) do
		if gift and not gift.Destroyed and not gift.Collected and not gift.Tripmine then
			local pos = Context.getGiftPosition(gift)
			local priority = Progress.getGiftPriority(gift, normalRatio, controller)
			if pos and priority ~= nil then
				if gift.Golden then
					rawGolden += 1
				else
					rawNormal += 1
				end
				if not seenGifts[gift] then
					seenGifts[gift] = now
				end
				local settleTime = gift.Golden and GOLDEN_SPAWN_SETTLE or SPAWN_SETTLE
				if now - seenGifts[gift] >= settleTime then
					local collapsePriority = 0
					if Collapse and typeof(Collapse.getGiftUrgency) == "function" then
						collapsePriority = Collapse.getGiftUrgency(pos)
					end
					local entry = {
						rawObj = gift,
						pos = pos,
						priority = priority,
						collapsePriority = collapsePriority,
						bonusTilePriority = getFannyPackTilePriority(pos, fannyPackTiles),
						id = gift.Id or 0,
						golden = gift.Golden == true,
					}
					if gift.Golden then
						table.insert(goldenGifts, entry)
					else
						table.insert(normalGifts, entry)
					end
				end
			end
		end
	end

	peakRawGolden = math.max(peakRawGolden, rawGolden)
	peakRawNormal = math.max(peakRawNormal, rawNormal)

	if #goldenGifts > 0 then
		gifts = goldenGifts
	else
		gifts = normalGifts
	end

	return gifts, {
		Golden = #goldenGifts,
		Normal = #normalGifts,
		RawGolden = rawGolden,
		RawNormal = rawNormal,
		PeakRawGolden = peakRawGolden,
		PeakRawNormal = peakRawNormal,
		GoldenRemainingRatio = if peakRawGolden > 0 then rawGolden / peakRawGolden else 1,
		NormalRemainingRatio = if peakRawNormal > 0 then rawNormal / peakRawNormal else 1,
		CollapseTracked = true,
		FannyPackTracked = hasFannyPack,
		GoldenLocked = #goldenGifts > 0,
	}
end

return Scanner
