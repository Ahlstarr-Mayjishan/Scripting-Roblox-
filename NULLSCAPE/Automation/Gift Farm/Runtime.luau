--!nocheck

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Scanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Scanner.luau")
local Collector = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Collector.luau")
local ClusterPlanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Cluster Planner.luau")
local Progress = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Progress.luau")
local Altar = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Altar.luau")
local Medal = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Medal.luau")
local Beacon = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Beacon.luau")
local GoldenWait = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Golden Wait.luau")

local Runtime = {}
local DEFAULT_RANGE = 60
local MIN_SCAN_INTERVAL = 0.04
local STATUS_UPDATE_INTERVAL = 0.15
local EMPTY_COMPLETE_DELAY = 2.5
local DISABLE_FOOTHOLD_DURATION = 2
local PYLON_LEVEL = 35
local TAIL_REMAINING_RATIO = 0.12
local SOFT_GC_INTERVAL = 1.5
local SOFT_GC_STEP = 64

local enabled = false
local busy = false
local connection = nil
local inRoundConnection = nil
local lastScan = 0
local lastGiftSeenAt = 0
local lastStatusAt = 0
local lastStatus = nil
local lastSoftGcAt = 0
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
		if Collector and typeof(Collector.restoreMovement) == "function" then
			Collector.restoreMovement({
				KeepFootholdDuration = DISABLE_FOOTHOLD_DURATION,
				OnlyKeepFootholdIfAirborne = true,
				SkipVelocityClear = true,
			})
		end
	end
	if Scanner and typeof(Scanner.reset) == "function" then
		Scanner.reset()
	end
	if Collector and typeof(Collector.resetAdaptive) == "function" then
		Collector.resetAdaptive(controller)
	end
	if Medal and typeof(Medal.reset) == "function" then
		Medal.reset()
	end
	if Altar and typeof(Altar.reset) == "function" then
		Altar.reset()
	end
	if inRound then
		setStatus(controller, "WaitingForGifts", "Round started")
	else
		setStatus(controller, "WaitingForRound", "Round ended")
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
	table.clear(route)
end

local function softCleanup(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if typeof(value) == "table" then
			table.clear(value)
		end
	end

	local now = os.clock()
	if now - lastSoftGcAt < SOFT_GC_INTERVAL then
		return
	end
	lastSoftGcAt = now

	task.defer(function()
		pcall(function()
			collectgarbage("step", SOFT_GC_STEP)
		end)
	end)
end

local function getLevel()
	local level = ReplicatedStorage:FindFirstChild("Level")
	if level and (level:IsA("IntValue") or level:IsA("NumberValue")) then
		return tonumber(level.Value) or 0
	end
	return 0
end

local function hasActivePylon()
	for _, model in ipairs(CollectionService:GetTagged("Pylon")) do
		if model and model:IsDescendantOf(workspace) and model:GetAttribute("Completed") ~= true then
			return true
		end
	end
	return false
end

local function shouldWaitForPylons(controller)
	if not (controller and controller.PylonActivatorEnabled == true and controller.PylonActivatorComplete ~= true) then
		return false
	end
	if getLevel() < PYLON_LEVEL then
		return false
	end
	return hasActivePylon()
end

local function isHoldingMedalBeforeGoldenComplete(controller)
	return controller
		and controller.CollectMedalEnabled == true
		and controller.GiftFarmGoldenComplete ~= true
		and Medal
		and typeof(Medal.isCarrying) == "function"
		and Medal.isCarrying() == true
end

local function tryMedalStep(controller, hrp)
	if Medal and typeof(Medal.tryStep) == "function" then
		return Medal.tryStep(controller, hrp)
	end
	return false
end

local function isTailPrecision(candidates, scanInfo, normalRatio)
	if #candidates <= 3 then
		return true
	end

	if scanInfo and scanInfo.GoldenLocked then
		local peakGolden = tonumber(scanInfo.PeakRawGolden) or 0
		local rawGolden = tonumber(scanInfo.RawGolden) or 0
		if peakGolden > 0 and rawGolden / peakGolden <= TAIL_REMAINING_RATIO then
			return true
		end
	end

	if not (scanInfo and scanInfo.GoldenLocked) and (tonumber(normalRatio) or 0) >= 1 - TAIL_REMAINING_RATIO then
		return true
	end

	return false
end

local function processOnce(controller)
	if not enabled or busy or not controller or controller.Destroyed then
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
			local _, _, normalRatio = Progress.getNormalGiftProgress(gch)
			local tailPrecision = isTailPrecision(candidates, scanInfo, normalRatio)
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
			local routeRejected = false
			for index, step in ipairs(route) do
				local cluster = step.Cluster or {}
				local planInfo = step.Info
				local score = planInfo and planInfo.Score
				local planned = score and (" | plan " .. tostring(score.Golden) .. "/" .. tostring(score.Total)) or ""
				local collapseCount = score and tonumber(score.CollapseCount) or 0
				local precisionMode = tailPrecision
					or (planInfo and planInfo.TailCleanup == true)
					or #cluster <= 2
					or (collapseCount > 0 and #cluster <= 4)
				setStatus(
					controller,
					precisionMode and "CollectingPrecision" or "Collecting",
					string.format("%d/%d route | %d/%d %s", index, #route, #cluster, totalPlanned, focus)
						.. planned
				)
				local collectResult = Collector.collectCluster(controller, hrp, cluster, range, {
					SafeRange = planInfo and planInfo.SafeRange,
					TargetPosition = planInfo and planInfo.TargetPosition,
					PrecisionMode = precisionMode,
					TailMode = tailPrecision,
					AbortCheck = function()
						return not isCurrentRoundActive()
					end,
				})
				if not isCurrentRoundActive() then
					clearRoute(route)
					softCleanup(candidates, remaining)
					setStatus(controller, "WaitingForRound")
					return
				end
				if collectResult and (tonumber(collectResult.Rejected) or 0) > 0 then
					routeRejected = true
				end
			end
			clearRoute(route)
			softCleanup(candidates, remaining)
			if routeRejected then
				lastGiftSeenAt = os.clock()
				setStatus(controller, "RetryingRejectedGifts", "Server returned one or more late gifts")
				return
			end
			if shouldHoldForGoldenWait then
				GoldenWait.holdNow()
			end

			local normalCollected, normalTotal, displayNormalRatio = Progress.getNormalGiftProgress(gch)
			local goldenText = scanInfo and (" | Golden " .. tostring(scanInfo.Golden or 0)) or ""
			local adaptiveText = ""
			if controller.GiftFarmAdaptiveTiming ~= false then
				local accepted = math.floor((tonumber(controller.GiftFarmAdaptiveSuccessRate) or 1) * 100)
				local validationWait = tonumber(controller.GiftFarmAdaptiveValidationWait) or 0
				local rejects = tonumber(controller.GiftFarmAdaptiveRejects) or 0
				local retries = tonumber(controller.GiftFarmAdaptiveRetries) or 0
				adaptiveText = string.format(
					" | Accept %d%% Reject %d Retry %d Wait %.2fs",
					accepted,
					rejects,
					retries,
					validationWait
				)
			end
			setStatus(
				controller,
				"Rescanning",
				string.format("Normal %d/%d (%.0f%%)", normalCollected, normalTotal, displayNormalRatio * 100)
					.. goldenText
					.. adaptiveText
			)
		end)

		if not ok then
			setStatus(controller, "Error", tostring(err), true)
		end
		busy = false
	end)
end

function Runtime.enable(controller, gc)
	if enabled then
		return true
	end

	enabled = true
	observeInRound(controller, gc)
	connection = RunService.Heartbeat:Connect(function()
		if controller and controller.GiftFarmEnabled then
			processOnce(controller)
		end
	end)
	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(connection)
	end
	return true
end

function Runtime.disable(controller)
	enabled = false
	busy = false
	if Beacon and typeof(Beacon.restore) == "function" then
		Beacon.restore()
	end
	if Collector and typeof(Collector.restoreMovement) == "function" then
		Collector.restoreMovement({
			KeepFootholdDuration = DISABLE_FOOTHOLD_DURATION,
			OnlyKeepFootholdIfAirborne = true,
			SkipVelocityClear = true,
		})
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

function Runtime.update(controller, gc)
	if controller and controller.GiftFarmEnabled then
		return Runtime.enable(controller, gc)
	end
	return Runtime.disable(controller)
end

function Runtime.getStatus(controller)
	return {
		Status = controller and controller.GiftFarmStatus or "Idle",
		Detail = controller and controller.GiftFarmDetail or "",
	}
end

return Runtime
