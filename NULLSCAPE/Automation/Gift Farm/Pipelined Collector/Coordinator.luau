--!nocheck
-- [[
--  NULLSCAPE - Pipelined Gift Farm Coordinator
--  Isolated runtime manager specifically for Pipelining (Network) mode.
-- ]]

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Scanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Scanner.luau")
local PipelinedCollector = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Pipelined Collector/PipelinedCollector.luau")
local ClusterPlanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Cluster Planner.luau")
local Altar = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Altar.luau")
local Medal = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Medal.luau")
local Beacon = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Beacon.luau")
local GoldenWait = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Golden Wait.luau")

local RunService = game:GetService("RunService")

local Coordinator = {}
local DEFAULT_RANGE = 60
local MIN_SCAN_INTERVAL = 0.04
local STATUS_UPDATE_INTERVAL = 0.15
local EMPTY_COMPLETE_DELAY = 2.5
local DISABLE_FOOTHOLD_DURATION = 2
local PYLON_LEVEL = 35

local enabled = false
local busy = false
local connection = nil
local inRoundConnection = nil
local lastScan = 0
local lastGiftSeenAt = 0
local lastStatusAt = 0
local lastStatus = nil
local roundToken = 0

local function setStatus(controller, status, detail, force)
	if controller then
		local nextStatus = status or "Idle"
		local now = os.clock()
		if not force and nextStatus == lastStatus and now - lastStatusAt < STATUS_UPDATE_INTERVAL then
			return
		end
		lastStatus = nextStatus
		lastStatusAt = now
		controller.GiftFarmStatus = nextStatus
		controller.GiftFarmDetail = detail or ""
	end
end

local function resetRoundState(controller, inRound)
	roundToken += 1
	busy = false
	lastScan = 0
	lastGiftSeenAt = 0
	lastStatusAt = 0
	lastStatus = nil
	if controller then
		controller.GiftFarmGoldenComplete = false
	end
	if GoldenWait and typeof(GoldenWait.reset) == "function" then
		GoldenWait.reset()
	end
	if Beacon and typeof(Beacon.reset) == "function" then
		Beacon.reset(inRound)
	end
	if not inRound then
		if Beacon and typeof(Beacon.restore) == "function" then
			Beacon.restore()
		end
		if PipelinedCollector and typeof(PipelinedCollector.releaseCharacter) == "function" then
			pcall(function()
				PipelinedCollector.releaseCharacter({
					KeepFootholdDuration = DISABLE_FOOTHOLD_DURATION,
				})
			end)
		end
	end
	if Scanner and typeof(Scanner.reset) == "function" then
		Scanner.reset()
	end
	if Medal and typeof(Medal.reset) == "function" then
		Medal.reset()
	end
	if Altar and typeof(Altar.reset) == "function" then
		Altar.reset()
	end
	if inRound then
		setStatus(controller, "WaitingForGifts", "Round started (Pipeline)")
	else
		setStatus(controller, "WaitingForRound", "Round ended (Pipeline)")
	end
end

local function observeInRound(controller, gc)
	local inRound = Context.getInRoundValue()
	if not inRound then
		setStatus(controller, "WaitingForGifts", nil, true)
		return
	end

	resetRoundState(controller, inRound.Value == true)
	inRoundConnection = inRound.Changed:Connect(function(value)
		if not enabled or not controller or controller.Destroyed then
			return
		end
		resetRoundState(controller, value == true)
	end)

	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(inRoundConnection)
	end
end

local function getGiftFarmRange(controller)
	local range = DEFAULT_RANGE
	if typeof(controller.GetGiftFarmRange) == "function" then
		range = controller:GetGiftFarmRange()
	else
		range = math.clamp(tonumber(controller.GiftFarmRange) or DEFAULT_RANGE, 5, DEFAULT_RANGE)
	end
	return range
end

local function markGoldenComplete(controller)
	if controller then
		controller.GiftFarmGoldenComplete = true
	end
end

local function clearRoute(route)
	if typeof(route) ~= "table" then
		return
	end
	for _, step in ipairs(route) do
		if typeof(step) == "table" then
			if typeof(step.Cluster) == "table" then
				table.clear(step.Cluster)
			end
			if typeof(step.Info) == "table" and typeof(step.Info.Score) == "table" then
				table.clear(step.Info.Score)
			end
			table.clear(step)
		end
	end
end

local function softCleanup(candidates, remaining)
	if typeof(candidates) == "table" then
		table.clear(candidates)
	end
	if typeof(remaining) == "table" then
		table.clear(remaining)
	end
end

local function shouldWaitForPylons(controller)
	if not (controller and controller.PylonActivatorEnabled) then
		return false
	end
	if controller.PylonActivatorComplete then
		return false
	end
	local playerLevel = Context.getPlayerLevel() or 0
	return playerLevel >= PYLON_LEVEL
end

local function tryMedalStep(controller, hrp)
	if not (controller and controller.CollectMedalEnabled) then
		return false
	end
	if Medal and typeof(Medal.tryStep) == "function" then
		return Medal.tryStep(controller, hrp)
	end
	return false
end

local function isHoldingMedalBeforeGoldenComplete(controller)
	if not (controller and controller.CollectMedalEnabled) then
		return false
	end
	if controller.GiftFarmGoldenComplete == true then
		return false
	end
	if Medal and typeof(Medal.isPlayerHoldingMedal) == "function" then
		return Medal.isPlayerHoldingMedal() == true
	end
	return false
end

local function processOnce(controller)
	if busy or not enabled or controller.Destroyed then
		return
	end

	local now = os.clock()
	if now - lastScan < MIN_SCAN_INTERVAL then
		return
	end
	lastScan = now
	busy = true

	local token = roundToken
	local function isCurrentRoundActive()
		return enabled and token == roundToken and Context.isInRound()
	end

	task.spawn(function()
		local ok, err = pcall(function()
			if not isCurrentRoundActive() then
				setStatus(controller, "WaitingForRound")
				return
			end

			local hrp = Context.getRootPart()
			if not hrp then
				setStatus(controller, "WaitingForCharacter")
				return
			end

			if controller.PylonActivatorHolding == true then
				setStatus(controller, "PausedForPylon", "Pylon activation has movement priority")
				return
			end

			if controller.GiftFarmGoldenComplete ~= true
				and Beacon
				and typeof(Beacon.suppressUntilReturn) == "function"
			then
				Beacon.suppressUntilReturn()
			end

			local passageGoldenPriority = GoldenWait
				and typeof(GoldenWait.isPassageWindowActive) == "function"
				and GoldenWait.isPassageWindowActive() == true
			if not passageGoldenPriority and Altar and typeof(Altar.tryStep) == "function" then
				local handledAltar, altarStatus, altarDetail = Altar.tryStep(controller, hrp)
				if not isCurrentRoundActive() then
					setStatus(controller, "WaitingForRound")
					return
				end
				if handledAltar then
					if typeof(altarDetail) == "string"
						and string.find(altarDetail, "Passage", 1, true)
						and GoldenWait
						and typeof(GoldenWait.startPassageWindow) == "function"
					then
						lastGiftSeenAt = os.clock()
						GoldenWait.startPassageWindow()
					end
					setStatus(controller, altarStatus or "ActivatingAltar", altarDetail or "")
					return
				end
			end

			local gch = Context.getGiftClientHandler()
			if not (gch and gch.Gifts) then
				setStatus(controller, "WaitingForGiftClient")
				return
			end

			local candidates, scanInfo = Scanner.scan(controller, gch)
			if not isCurrentRoundActive() then
				setStatus(controller, "WaitingForRound")
				return
			end
			if GoldenWait and typeof(GoldenWait.noteScan) == "function" then
				GoldenWait.noteScan(scanInfo)
			end
			local goldenWaitReason = GoldenWait.hasSeenGolden() and "Golden respawn check" or "Post-clear check"
			if GoldenWait.shouldWait(controller, scanInfo, lastGiftSeenAt, setStatus, goldenWaitReason) then
				return
			end
			if lastGiftSeenAt > 0 and GoldenWait.hasSeenGolden() and scanInfo and scanInfo.RawGolden == 0 then
				markGoldenComplete(controller)
				if shouldWaitForPylons(controller) then
					setStatus(controller, "WaitingForPylons", "Golden gifts complete")
					return
				end
				local handledMedal, medalStatus = tryMedalStep(controller, hrp)
				if not isCurrentRoundActive() then
					setStatus(controller, "WaitingForRound")
					return
				end
				if handledMedal then
					setStatus(controller, medalStatus or "MedalAction")
					return
				end
				if Beacon.returnToBeacon(controller, hrp, setStatus, "Golden gifts complete") then
					return
				end
			end

			if #candidates == 0 then
				local rawGolden = scanInfo and (tonumber(scanInfo.RawGolden) or 0) or 0
				local rawNormal = scanInfo and (tonumber(scanInfo.RawNormal) or 0) or 0
				if rawGolden > 0 or rawNormal > 0 then
					lastGiftSeenAt = os.clock()
					setStatus(
						controller,
						"WaitingForGiftSettle",
						string.format("Raw gifts visible | Golden %d Normal %d", rawGolden, rawNormal)
					)
					return
				end
				if isHoldingMedalBeforeGoldenComplete(controller) then
					setStatus(controller, "HoldingMedalForGolden", "Waiting for golden gifts before beacon")
					return
				end
				local handledMedal, medalStatus = tryMedalStep(controller, hrp)
				if not isCurrentRoundActive() then
					setStatus(controller, "WaitingForRound")
					return
				end
				if handledMedal then
					setStatus(controller, medalStatus or "MedalAction")
					return
				end
				if lastGiftSeenAt > 0 and os.clock() - lastGiftSeenAt >= EMPTY_COMPLETE_DELAY then
					if Beacon.returnToBeacon(controller, hrp, setStatus, "Round targets complete") then
						return
					end
					setStatus(controller, "RoundCompleteWatching")
				else
					setStatus(controller, "WaitingForGifts")
				end
				return
			end

			lastGiftSeenAt = os.clock()
			local range = getGiftFarmRange(controller)
			local route, remaining = ClusterPlanner.planRoute(candidates, range, hrp.Position)
			if remaining and #remaining > 0 and typeof(ClusterPlanner.planTailRoute) == "function" then
				local tailRoute = ClusterPlanner.planTailRoute(remaining, range, hrp.Position)
				for _, step in ipairs(tailRoute) do
					table.insert(route, step)
				end
			end
			local totalPlanned = 0
			for _, step in ipairs(route) do
				totalPlanned += #(step.Cluster or {})
			end

			local shouldHoldForGoldenWait = GoldenWait.shouldHoldAfterRoute(scanInfo, totalPlanned)
			local focus = scanInfo and scanInfo.GoldenLocked and "golden" or "gifts"
			
			-- Bắt đầu thu thập kiểu Pipelined
			setStatus(
				controller,
				"Collecting (Pipeline)",
				string.format("%d routes | %d %s planned", #route, totalPlanned, focus)
			)

			PipelinedCollector.collectRoute(controller, hrp, route, range, {
				AbortCheck = function()
					return not isCurrentRoundActive()
				end,
			})

			clearRoute(route)
			softCleanup(candidates, remaining)

			if shouldHoldForGoldenWait then
				if typeof(GoldenWait.startNormalClearWindow) == "function" then
					GoldenWait.startNormalClearWindow()
				else
					GoldenWait.holdNow()
				end
			end
		end)

		if not ok then
			setStatus(controller, "Error (Pipeline)", tostring(err), true)
		end
		busy = false
	end)
end

function Coordinator.enable(controller, gc)
	if enabled then
		return true
	end

	enabled = true
	observeInRound(controller, gc)
	connection = RunService.Heartbeat:Connect(function()
		if controller and controller.GiftFarmEnabled and controller.GiftFarmMode == "Pipelining (Network)" then
			processOnce(controller)
		end
	end)
	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(connection)
	end
	return true
end

function Coordinator.disable(controller)
	enabled = false
	busy = false
	if Beacon and typeof(Beacon.restore) == "function" then
		Beacon.restore()
	end
	if PipelinedCollector and typeof(PipelinedCollector.releaseCharacter) == "function" then
		pcall(function()
			PipelinedCollector.releaseCharacter({
				KeepFootholdDuration = DISABLE_FOOTHOLD_DURATION,
			})
		end)
	end
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
		connection = nil
	end
	if inRoundConnection then
		pcall(function()
			inRoundConnection:Disconnect()
		end)
		inRoundConnection = nil
	end
	resetRoundState(controller, false)
	softCleanup()
	setStatus(controller, "Idle", nil, true)
	return true
end

function Coordinator.update(controller, gc)
	if controller and controller.GiftFarmEnabled and controller.GiftFarmMode == "Pipelining (Network)" then
		return Coordinator.enable(controller, gc)
	end
	return Coordinator.disable(controller)
end

function Coordinator.getStatus(controller)
	return {
		Status = controller and controller.GiftFarmStatus or "Idle",
		Detail = controller and controller.GiftFarmDetail or "",
	}
end

return Coordinator
