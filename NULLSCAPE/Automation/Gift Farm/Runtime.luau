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

local Runtime = {}
local DEFAULT_RANGE = 60
local MIN_SCAN_INTERVAL = 0.06
local EMPTY_COMPLETE_DELAY = 2.5
local GOLDEN_SPAWN_WAIT = 4
local PYLON_LEVEL = 35

local enabled = false
local busy = false
local connection = nil
local inRoundConnection = nil
local lastScan = 0
local lastGiftSeenAt = 0
local beaconReturnDone = false
local hasSeenGoldenThisRound = false
local goldenMissingSince = nil
local beaconSuppressed = false

local function setStatus(controller, status, detail)
	if controller then
		controller.GiftFarmStatus = status or "Idle"
		controller.GiftFarmDetail = detail or ""
	end
end

local function resetRoundState(controller, inRound)
	busy = false
	lastScan = 0
	lastGiftSeenAt = 0
	beaconReturnDone = false
	hasSeenGoldenThisRound = false
	goldenMissingSince = nil
	if controller then
		controller.GiftFarmGoldenComplete = false
	end
	if not inRound and beaconSuppressed then
		Context.restoreBeaconInteraction()
		beaconSuppressed = false
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
		setStatus(controller, "WaitingForGifts")
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

local function returnToBeacon(controller, hrp, reason)
	if beaconReturnDone or controller.GiftFarmReturnToBeaconAfterGolden == false then
		return false
	end
	if not Context.isBeaconActive() then
		return false
	end

	local beacon = Context.getBeaconPart()
	if not (beacon and hrp and hrp.Parent) then
		return false
	end

	beaconReturnDone = true
	if beaconSuppressed then
		Context.restoreBeaconInteraction()
		beaconSuppressed = false
	end
	Context.moveCharacterTo(CFrame.new(beacon.Position + Vector3.new(0, 4, 0)))
	setStatus(controller, "ReturningToBeacon", reason or "Golden gifts complete")
	return true
end

local function suppressBeaconUntilReturn()
	beaconSuppressed = Context.suppressBeaconInteraction() == true or beaconSuppressed
end

local function getGoldenSpawnWait()
	return GOLDEN_SPAWN_WAIT
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

local function waitForLateGolden(controller, scanInfo, reason)
	if not (lastGiftSeenAt > 0 and scanInfo and scanInfo.RawGolden == 0) then
		goldenMissingSince = nil
		return false
	end

	if not hasSeenGoldenThisRound and (tonumber(scanInfo.RawNormal) or 0) > 0 then
		return false
	end

	local waitTime = getGoldenSpawnWait()
	if waitTime <= 0 then
		return false
	end

	goldenMissingSince = goldenMissingSince or os.clock()
	local elapsed = os.clock() - goldenMissingSince
	if elapsed < waitTime then
		setStatus(
			controller,
			"WaitingForGoldenSpawn",
			string.format("%s %.1fs/%.1fs", reason or "Golden settle", elapsed, waitTime)
		)
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

	task.spawn(function()
		local ok, err = pcall(function()
			if not Context.isInRound() then
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

			suppressBeaconUntilReturn()

			if Altar and typeof(Altar.tryStep) == "function" then
				local handledAltar, altarStatus, altarDetail = Altar.tryStep(controller, hrp)
				if handledAltar then
					setStatus(controller, altarStatus or "ActivatingAltar", altarDetail or "")
					return
				end
			end

			if Medal and typeof(Medal.tryStep) == "function" then
				local handledMedal, medalStatus = Medal.tryStep(controller, hrp)
				if handledMedal then
					if medalStatus == "SubmittingMedal" then
						beaconSuppressed = false
					end
					setStatus(controller, medalStatus or "MedalAction")
					return
				end
			end

			local gch = Context.getGiftClientHandler()
			if not (gch and gch.Gifts) then
				setStatus(controller, "WaitingForGiftClient")
				return
			end

			local candidates, scanInfo = Scanner.scan(controller, gch)
			if scanInfo and scanInfo.RawGolden and scanInfo.RawGolden > 0 then
				hasSeenGoldenThisRound = true
				goldenMissingSince = nil
			end
			if waitForLateGolden(controller, scanInfo, hasSeenGoldenThisRound and "Golden respawn check" or "Post-clear check") then
				return
			end
			if lastGiftSeenAt > 0 and hasSeenGoldenThisRound and scanInfo and scanInfo.RawGolden == 0 then
				markGoldenComplete(controller)
				if shouldWaitForPylons(controller) then
					setStatus(controller, "WaitingForPylons", "Golden gifts complete")
					return
				end
				if returnToBeacon(controller, hrp, "Golden gifts complete") then
					return
				end
			end

			if #candidates == 0 then
				if lastGiftSeenAt > 0 and os.clock() - lastGiftSeenAt >= EMPTY_COMPLETE_DELAY then
					if returnToBeacon(controller, hrp, "Round targets complete") then
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
			local route = ClusterPlanner.planRoute(candidates, range, hrp.Position)
			local totalPlanned = 0
			for _, step in ipairs(route) do
				totalPlanned += #(step.Cluster or {})
			end

			local rawNormal = scanInfo and (tonumber(scanInfo.RawNormal) or 0) or 0
			local rawGolden = scanInfo and (tonumber(scanInfo.RawGolden) or 0) or 0
			local shouldHoldForGoldenWait = rawGolden == 0
				and rawNormal > 0
				and rawNormal <= totalPlanned
				and getGoldenSpawnWait() > 0

			local focus = scanInfo and scanInfo.GoldenLocked and "golden" or "gifts"
			local routeRejected = false
			local collectedPlanned = 0
			for index, step in ipairs(route) do
				local cluster = step.Cluster or {}
				local planInfo = step.Info
				local score = planInfo and planInfo.Score
				local planned = score and (" | plan " .. tostring(score.Golden) .. "/" .. tostring(score.Total)) or ""
				local remainingAfterStep = math.max(totalPlanned - collectedPlanned - #cluster, 0)
				local precisionMode = #cluster <= 2 or remainingAfterStep <= 2
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
				})
				collectedPlanned += #cluster
				if collectResult and (tonumber(collectResult.Rejected) or 0) > 0 then
					routeRejected = true
				end
			end
			if routeRejected then
				lastGiftSeenAt = os.clock()
				setStatus(controller, "RetryingRejectedGifts", "Server returned one or more late gifts")
				return
			end
			if shouldHoldForGoldenWait then
				goldenMissingSince = os.clock()
			end

			local normalCollected, normalTotal, normalRatio = Progress.getNormalGiftProgress(gch)
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
				string.format("Normal %d/%d (%.0f%%)", normalCollected, normalTotal, normalRatio * 100)
					.. goldenText
					.. adaptiveText
			)
		end)

		if not ok then
			setStatus(controller, "Error", tostring(err))
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
	if beaconSuppressed then
		Context.restoreBeaconInteraction()
		beaconSuppressed = false
	end
	if Collector and typeof(Collector.restoreMovement) == "function" then
		Collector.restoreMovement()
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
	setStatus(controller, "Idle")
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
