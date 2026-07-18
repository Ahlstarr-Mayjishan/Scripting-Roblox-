--!nocheck
-- [[
--  NULLSCAPE - Unified Gift Farm Coordinator
--  Single coordinator governing Normal and Pipeline modes, managing states
--  reactively via event triggers and enforcing strict execution lifetimes.
-- ]]

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Scanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Scanner.luau")
local Collector = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Collector.luau")
local PipelinedCollector = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Pipelined Collector/PipelinedCollector.luau")
local ClusterPlanner = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Cluster Planner.luau")
local Progress = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Progress.luau")
local Altar = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Altar.luau")
local Medal = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Medal.luau")
local Beacon = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Beacon.luau")
local GoldenWait = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Golden Wait.luau")
local MovementLease = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/MovementLease.luau")
local RunPolicy = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Run Policy.luau")

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Coordinator = {}
local NORMAL_MODE = "Normal (teleport)"
local PIPELINE_MODE = "Pipelining (Network)"
local DEFAULT_RANGE = 60
local STATUS_UPDATE_INTERVAL = 0.15
local EMPTY_COMPLETE_DELAY = 2.5
local PYLON_LEVEL = 35
local GOLDEN_RETURN_VERIFY_ATTEMPTS = 6
local GOLDEN_RETURN_VERIFY_INTERVAL = 0.12
local GOLDEN_RETURN_CONFIRM_DELAY = 0.25
local GOLDEN_COUNTER_STALE_TIMEOUT = 1.5
local RESPAWN_READY_DELAY = 0.85
local TAIL_REMAINING_RATIO = 0.12
local WATCHDOG_INTERVAL = 1
local WORKER_STALL_TIMEOUT = 6
local LOGICAL_STALL_TIMEOUT = 8
local WATCHDOG_MOVEMENT_EPSILON = 2
local GOLDEN_PREEMPT_SCAN_INTERVAL = 0.03

local enabled = false
local configDirty = false
local sessionToken = 0
local characterSessionToken = 0
local loopActive = false
local workerGeneration = 0
local watchdogGeneration = 0
local lastWorkerPulseAt = 0
local lastProgressAt = 0
local lastWatchPosition = nil
local lastWatchGiftCount = nil

-- Observers
local characterAddedConnection = nil
local characterRemovingConnection = nil
local inRoundConnection = nil
local configChangedConn = nil
local pylonAddedConnection = nil

-- Runtime state variables
local characterReady = false
local characterReadyAt = 0
local lastGiftSeenAt = 0
local pendingGoldenReturnSince = nil
local giftsStabilized = false
local startWaitAt = nil
local currentStatus = "Idle"
local lastStatusAt = 0

-- Hydrated configurations
local range = DEFAULT_RANGE
local mode = NORMAL_MODE

local function markWorkerPulse()
	lastWorkerPulseAt = os.clock()
end

local function markProgress()
	lastProgressAt = os.clock()
end

local function transitionTo(controller, status, detail, force)
	local nextStatus = status or "Idle"
	local now = os.clock()
	lastWorkerPulseAt = now
	if not force and nextStatus == currentStatus and now - lastStatusAt < STATUS_UPDATE_INTERVAL then
		return
	end
	currentStatus = nextStatus
	lastStatusAt = now
	if controller then
		controller.GiftFarmStatus = nextStatus
		controller.GiftFarmDetail = detail or ""
	end
end

local function recoverAfterStop(controller, detail)
	sessionToken += 1
	if MovementLease.invalidateActive(10) then
		Context.releaseCharacterControl({
			SkipVelocityClear = true,
			SkipStateChange = true,
			ForceAbilityClear = true,
		})
	end

	if Beacon and typeof(Beacon.restore) == "function" then
		Beacon.restore(true)
	end

	pendingGoldenReturnSince = nil
	giftsStabilized = false
	startWaitAt = nil
	lastGiftSeenAt = 0
	lastWatchGiftCount = nil
	markProgress()
	if controller then
		controller.GiftFarmGoldenComplete = false
	end

	transitionTo(controller, "Idle", detail or "Gift Farm stopped", true)
end

local function getGiftFarmRange(controller)
	local r = DEFAULT_RANGE
	if typeof(controller.GetGiftFarmRange) == "function" then
		r = controller:GetGiftFarmRange()
	else
		r = math.clamp(tonumber(controller.GiftFarmRange) or DEFAULT_RANGE, 5, DEFAULT_RANGE)
	end
	return r
end

local function getLevel()
	local lvl = ReplicatedStorage:FindFirstChild("Level")
	if lvl and (lvl:IsA("IntValue") or lvl:IsA("NumberValue")) then
		return tonumber(lvl.Value) or 0
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

local function getPylonProgress()
	local completed = tonumber(ReplicatedStorage:GetAttribute("PylonsDone")) or 0
	local maximum = tonumber(ReplicatedStorage:GetAttribute("MaxPylons")) or 0
	return completed, maximum
end

local function shouldWaitForPylons(controller)
	if not (controller and controller.PylonActivatorEnabled) then
		return false
	end

	local completed, maximum = getPylonProgress()
	if maximum > 0 then
		return completed < maximum
	end
	if controller.PylonActivatorComplete then
		return false
	end

	return getLevel() >= PYLON_LEVEL and hasActivePylon()
end

local function tryMedalStep(controller, hrp, lease, currentSessionToken)
	if Medal and typeof(Medal.tryStep) == "function" then
		return Medal.tryStep(controller, hrp, lease, currentSessionToken)
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
	if Medal and typeof(Medal.isCarrying) == "function" then
		return Medal.isCarrying() == true
	end
	return false
end

local function tryGoldenCompleteReturn(controller, hrp, scanInfo, isSessionActive)
	if not (pendingGoldenReturnSince and scanInfo and tonumber(scanInfo.RawGolden) == 0) then
		return false
	end
	if (tonumber(scanInfo.RawNormal) or 0) > 0 then
		return false
	end

	local pendingDuration = os.clock() - pendingGoldenReturnSince
	local rawGoldenExhausted = (tonumber(scanInfo.PeakRawGolden) or 0) > 0
	local counterConfirmed = scanInfo.GoldenProgressComplete == true or scanInfo.GoldenTargetReached == true
	local staleCounterConfirmed = rawGoldenExhausted and pendingDuration >= GOLDEN_COUNTER_STALE_TIMEOUT
	if not counterConfirmed and not staleCounterConfirmed then
		if controller then
			controller.GiftFarmGoldenComplete = false
		end
		return false
	end
	if pendingDuration < GOLDEN_RETURN_CONFIRM_DELAY then
		return false
	end

	pendingGoldenReturnSince = nil
	if controller then
		controller.GiftFarmGoldenComplete = true
	end
	if GoldenWait and typeof(GoldenWait.finishPylonWindow) == "function" then
		GoldenWait.finishPylonWindow()
	end

	if shouldWaitForPylons(controller) then
		transitionTo(controller, "Paused", "Golden gifts complete; waiting for pylons")
		return true
	end

	-- Try Medal step
	local lease = MovementLease.acquire("MedalStep")
	transitionTo(controller, "Collecting", "Medal check")
	local handledMedal, medalStatus = tryMedalStep(controller, hrp, lease, sessionToken)
	lease:release()
	if not isSessionActive() then return true end

	if not Context.isInRound() then
		transitionTo(controller, "Recovering", "Waiting for round")
		MovementLease.invalidateActive(10)
		return true
	end

	if handledMedal then
		transitionTo(controller, "Collecting", medalStatus or "MedalAction")
		return true
	end

	-- Return to Beacon
	lease = MovementLease.acquire("ReturningBeacon")
	transitionTo(controller, "ReturningBeacon", "Golden complete; returning to beacon")
	local success = Beacon.returnToBeacon(
		controller,
		hrp,
		function(c, status, detail)
			transitionTo(c, status, detail)
		end,
		"Golden complete",
		lease,
		sessionToken
	)
	lease:release()
	if not isSessionActive() then return true end

	if success then
		return true
	end

	transitionTo(controller, "Paused", "Golden complete; beacon return retry pending")
	pendingGoldenReturnSince = os.clock()
	return true
end

local function verifyGoldenRouteComplete(controller, hrp, isSessionActive)
	for _ = 1, GOLDEN_RETURN_VERIFY_ATTEMPTS do
		if not isSessionActive() then
			return true
		end

		hrp = Context.getRootPart() or hrp
		if not hrp then
			transitionTo(controller, "Recovering", "Waiting for character root part")
			return true
		end

		local gch = Context.getGiftClientHandler()
		if not (gch and gch.Gifts) then
			transitionTo(controller, "Recovering", "Waiting for GiftClientHandler")
			return true
		end

		local _, verifyInfo = Scanner.scan(controller, gch)
		if GoldenWait and typeof(GoldenWait.noteScan) == "function" then
			GoldenWait.noteScan(verifyInfo)
		end
		if tryGoldenCompleteReturn(controller, hrp, verifyInfo, isSessionActive) then
			return true
		end

		if verifyInfo and tonumber(verifyInfo.RawGolden) and tonumber(verifyInfo.RawGolden) > 0 then
			return false
		end

		task.wait(GOLDEN_RETURN_VERIFY_INTERVAL)
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

local function disconnectObservers()
	if characterAddedConnection then
		pcall(function()
			characterAddedConnection:Disconnect()
		end)
		characterAddedConnection = nil
	end
	if characterRemovingConnection then
		pcall(function()
			characterRemovingConnection:Disconnect()
		end)
		characterRemovingConnection = nil
	end
	if inRoundConnection then
		pcall(function()
			inRoundConnection:Disconnect()
		end)
		inRoundConnection = nil
	end
	if pylonAddedConnection then
		pcall(function()
			pylonAddedConnection:Disconnect()
		end)
		pylonAddedConnection = nil
	end
end

local function observePylons(controller, gc)
	local function notePylonSpawn(model)
		if not (enabled and controller and not controller.Destroyed and Context.isInRound()) then
			return
		end
		if not (model and model:IsDescendantOf(workspace) and model:GetAttribute("Completed") ~= true) then
			return
		end
		if not (GoldenWait and typeof(GoldenWait.startPylonWindow) == "function") then
			return
		end
		if not GoldenWait.startPylonWindow() then
			return
		end

		controller.GiftFarmGoldenComplete = false
		pendingGoldenReturnSince = nil
		lastGiftSeenAt = os.clock()
		sessionToken += 1
		MovementLease.invalidateActive(10)
		transitionTo(controller, "Scanning", "Pylon detected; waiting for golden gifts", true)
	end

	pylonAddedConnection = CollectionService:GetInstanceAddedSignal("Pylon"):Connect(notePylonSpawn)
	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(pylonAddedConnection)
	end

	for _, model in ipairs(CollectionService:GetTagged("Pylon")) do
		if model and model:IsDescendantOf(workspace) and model:GetAttribute("Completed") ~= true then
			notePylonSpawn(model)
			break
		end
	end
end

local function observeCharacter(controller, gc)
	if not localPlayer then
		return
	end

	disconnectObservers()

	local function resetCharacterState()
		sessionToken += 1
		characterSessionToken += 1
		MovementLease.invalidateActive()
		MovementLease.resetTransport()
		characterReady = false
		characterReadyAt = math.huge
		pendingGoldenReturnSince = nil
		lastWatchGiftCount = nil
		markProgress()
		if controller then
			controller.GiftFarmGoldenComplete = false
		end

		if GoldenWait and typeof(GoldenWait.reset) == "function" then
			GoldenWait.reset()
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
		if Beacon and typeof(Beacon.reset) == "function" then
			Beacon.reset(Context.isInRound())
		end
		if Beacon and typeof(Beacon.restore) == "function" then
			Beacon.restore(true)
		end

		transitionTo(controller, "Recovering", "Character respawned; waiting for replication")
	end

	characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
		if not enabled or not controller or controller.Destroyed then
			return
		end
		resetCharacterState()
		local myCharacterSession = characterSessionToken
		task.spawn(function()
			local hrp = character and character:WaitForChild("HumanoidRootPart", 6)
			
			if localPlayer:HasAppearanceLoaded() == false then
				local startWait = os.clock()
				while not localPlayer:HasAppearanceLoaded() and os.clock() - startWait < 4 do
					RunService.Heartbeat:Wait()
				end
			end

			for _ = 1, 8 do
				RunService.Heartbeat:Wait()
			end
			if enabled and hrp and localPlayer.Character == character and myCharacterSession == characterSessionToken then
				characterReady = true
				characterReadyAt = os.clock() + RESPAWN_READY_DELAY
			end
		end)
	end)

	characterRemovingConnection = localPlayer.CharacterRemoving:Connect(function()
		if not enabled or not controller or controller.Destroyed then
			return
		end
		characterReady = false
		resetCharacterState()
	end)

	if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
		characterReady = true
		characterReadyAt = os.clock()
	end

	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(characterAddedConnection)
		gc.registerConnection(characterRemovingConnection)
	end
end

local function observeInRound(controller, gc)
	local inRound = Context.getInRoundValue()
	if not inRound then
		return
	end

	local function resetRoundState(value)
		sessionToken += 1
		MovementLease.invalidateActive()
		MovementLease.resetTransport()
		if PipelinedCollector and typeof(PipelinedCollector.cancelPending) == "function" then
			PipelinedCollector.cancelPending(controller)
		end
		pendingGoldenReturnSince = nil
		giftsStabilized = false
		startWaitAt = nil
		lastGiftSeenAt = 0
		lastWatchGiftCount = nil
		markProgress()
		if controller then
			controller.GiftFarmGoldenComplete = false
		end

		if GoldenWait and typeof(GoldenWait.reset) == "function" then
			GoldenWait.reset()
		end
		if Beacon and typeof(Beacon.reset) == "function" then
			Beacon.reset(value)
		end
		if not value then
			if Beacon and typeof(Beacon.restore) == "function" then
				Beacon.restore(true)
			end
			Context.releaseCharacterControl({
				SkipVelocityClear = true,
				ForceAbilityClear = true,
				SkipStateChange = true,
			})
		end
		if Scanner and typeof(Scanner.reset) == "function" then
			Scanner.reset()
		end
		if Collector and typeof(Collector.resetAdaptive) == "function" then
			Collector.resetAdaptive(controller)
		end
		if PipelinedCollector and typeof(PipelinedCollector.resetAdaptive) == "function" then
			PipelinedCollector.resetAdaptive(controller)
		end
		if Medal and typeof(Medal.reset) == "function" then
			Medal.reset()
		end
		if Altar and typeof(Altar.reset) == "function" then
			Altar.reset()
		end

		if value then
			transitionTo(controller, "Scanning", "Round started")
		else
			transitionTo(controller, "Recovering", "Round ended")
		end
	end

	resetRoundState(inRound.Value == true)
	inRoundConnection = inRound.Changed:Connect(function(value)
		if not enabled or not controller or controller.Destroyed then
			return
		end
		resetRoundState(value == true)
	end)

	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(inRoundConnection)
	end
end

local function runLoop(controller)
	if loopActive then
		return
	end
	workerGeneration += 1
	local myWorkerGeneration = workerGeneration
	loopActive = true
	markWorkerPulse()

	task.spawn(function()
		local ok, err = xpcall(function()
			while enabled and not controller.Destroyed and workerGeneration == myWorkerGeneration do
				markWorkerPulse()
			local mySessionToken = sessionToken

			local function isSessionActive()
				return enabled
					and sessionToken == mySessionToken
					and workerGeneration == myWorkerGeneration
					and not controller.Destroyed
			end

			-- 1. Check config changes (HydratingConfig)
			if configDirty then
				configDirty = false
				transitionTo(controller, "HydratingConfig", "Updating configuration options")
				sessionToken += 1
				MovementLease.invalidateActive(10)
				if PipelinedCollector and typeof(PipelinedCollector.cancelPending) == "function" then
					PipelinedCollector.cancelPending(controller)
				end
				mySessionToken = sessionToken

				range = getGiftFarmRange(controller)
				mode = controller.GiftFarmMode

				task.wait(0.1)
				if not isSessionActive() then continue end
			end

			if not controller.GiftFarmEnabled then
				transitionTo(controller, "Idle", "Gift Farm disabled")
				break
			end

			local lifecyclePolicy = RunPolicy and RunPolicy.step(controller)
			if lifecyclePolicy and lifecyclePolicy.Hold then
				transitionTo(
					controller,
					lifecyclePolicy.Status or "Paused",
					lifecyclePolicy.Detail or "Gift Farm policy hold",
					true
				)
				task.wait(0.1)
				continue
			end

			-- 2. Basic environment checks
			local hrp = Context.getRootPart()
			local inRound = Context.isInRound()

			if not (characterReady and hrp) then
				transitionTo(controller, "Recovering", "Waiting for character root part")
				task.wait(0.4)
				continue
			end

			if os.clock() < characterReadyAt then
				transitionTo(controller, "Recovering", "Waiting for respawn replication")
				task.wait(0.1)
				continue
			end

			local deadVal = localPlayer and localPlayer:FindFirstChild("Dead")
			if deadVal and deadVal.Value == true then
				transitionTo(controller, "Paused", "Player is dead; waiting for respawn")
				task.wait(0.5)
				continue
			end

			if not inRound then
				transitionTo(controller, "Recovering", "Waiting for round to start")
				task.wait(0.4)
				continue
			end

			-- 3. Wait for normal gifts to spawn and stabilize
			if not giftsStabilized then
				if not startWaitAt then
					startWaitAt = os.clock()
				end

				local function getGiftCount()
					local gch = Context.getGiftClientHandler()
					local _, total = Progress.getNormalGiftProgress(gch)
					if total > 0 then
						return total
					end
					local counters = ReplicatedStorage:FindFirstChild("GiftCounters")
					local giftCounter = counters and counters:FindFirstChild("Gift")
					if giftCounter then
						return tonumber(giftCounter.Value) or 0
					end
					return 0
				end

				local giftCount = getGiftCount()
				local elapsed = os.clock() - startWaitAt

				if giftCount == 0 then
					if elapsed < 1 then
						transitionTo(controller, "Scanning", string.format("Waiting for gifts to spawn (%.1fs/1.0s)...", elapsed))
						task.wait(0.2)
						continue
					else
						giftsStabilized = true
						lastGiftSeenAt = os.clock()
						startWaitAt = nil
					end
				else
					giftsStabilized = true
					lastGiftSeenAt = os.clock()
					startWaitAt = nil
				end
			end

			-- 3. Check pylon priority
			if controller.PylonActivatorHolding == true then
				transitionTo(controller, "Paused", "Paused for pylon activator")
				task.wait(0.2)
				continue
			end

			-- 4. Scanning state
			transitionTo(controller, "Scanning")

			local gch = Context.getGiftClientHandler()
			if not (gch and gch.Gifts) then
				transitionTo(controller, "Recovering", "Waiting for GiftClientHandler")
				task.wait(0.4)
				continue
			end

			local candidates, scanInfo = Scanner.scan(controller, gch)
			if not isSessionActive() then continue end

			local efficiencyPolicy = RunPolicy and RunPolicy.step(controller, scanInfo)
			if efficiencyPolicy and efficiencyPolicy.Hold then
				transitionTo(
					controller,
					efficiencyPolicy.Status or "Paused",
					efficiencyPolicy.Detail or "Gift Farm policy hold",
					true
				)
				task.wait(0.1)
				continue
			end

			local rawGolden = scanInfo and (tonumber(scanInfo.RawGolden) or 0) or 0
			local goldenTargetReached = scanInfo and scanInfo.GoldenTargetReached == true
			if rawGolden > 0 then
				controller.GiftFarmGoldenComplete = false
				pendingGoldenReturnSince = nil
				if Beacon and typeof(Beacon.suppressUntilReturn) == "function" then
					Beacon.suppressUntilReturn()
				end
			else
				if goldenTargetReached and controller.GiftFarmGoldenComplete ~= true and not pendingGoldenReturnSince then
					pendingGoldenReturnSince = os.clock()
				end
				if Beacon and typeof(Beacon.restore) == "function" then
					Beacon.restore(true)
				end
			end

			if GoldenWait and typeof(GoldenWait.noteScan) == "function" then
				GoldenWait.noteScan(scanInfo)
			end

			-- Try Golden Return
			if tryGoldenCompleteReturn(controller, hrp, scanInfo, isSessionActive) then
				continue
			end
			if pendingGoldenReturnSince
				and rawGolden == 0
				and scanInfo
				and scanInfo.GoldenProgressComplete ~= true
				and scanInfo.GoldenTargetReached ~= true
			then
				transitionTo(
					controller,
					"Scanning",
					string.format(
						"Verifying golden gifts %d/%d",
						tonumber(scanInfo.GoldenCollected) or 0,
						tonumber(scanInfo.GoldenMax) or 0
					)
				)
				task.wait(GOLDEN_RETURN_VERIFY_INTERVAL)
				continue
			end

			-- Golden always wins. Altar is the next producer action before normal gifts.
			local producerWindowActive = (GoldenWait.isPassageWindowActive and GoldenWait.isPassageWindowActive())
				or (GoldenWait.isPylonWindowActive and GoldenWait.isPylonWindowActive())
			if rawGolden == 0
				and not producerWindowActive
				and Altar
				and typeof(Altar.tryStep) == "function"
			then
				local lease = MovementLease.acquire("AltarStep")
				transitionTo(controller, "Collecting", "Attempting Altar activation")
				local _, _, normalGiftRatio = Progress.getNormalGiftProgress(gch)
				local handledAltar, altarStatus, _altarDetail, altarConfirmed, altarName = Altar.tryStep(
					controller,
					hrp,
					lease,
					mySessionToken,
					normalGiftRatio
				)
				lease:release()
				if not isSessionActive() then continue end
				if handledAltar then
					markProgress()
					local isPassage = altarName == "Passage"
					if isPassage then
						controller.GiftFarmGoldenComplete = false
						pendingGoldenReturnSince = nil
					end
					if isPassage
						and altarConfirmed == true
						and GoldenWait
						and typeof(GoldenWait.startPassageWindow) == "function"
					then
						lastGiftSeenAt = os.clock()
						GoldenWait.startPassageWindow()
					end
					transitionTo(controller, "Collecting", altarStatus or "ActivatingAltar", true)
					task.wait(0.08)
					continue
				end
			end

			-- Check Golden Wait
			local goldenWaitReason = GoldenWait.hasSeenGolden() and "Golden respawn check" or "Post-clear check"
			if GoldenWait.shouldWait(
				controller,
				scanInfo,
				lastGiftSeenAt,
				function(c, _, d)
					transitionTo(c, "Paused", d)
				end,
				goldenWaitReason
			) then
				task.wait(0.1)
				continue
			end

			if GoldenWait
				and typeof(GoldenWait.canReleasePylonWithoutGolden) == "function"
				and GoldenWait.canReleasePylonWithoutGolden()
			then
				if typeof(GoldenWait.finishPylonWindow) == "function" then
					GoldenWait.finishPylonWindow()
				end
				controller.GiftFarmGoldenComplete = true
				transitionTo(controller, "Paused", "No golden generation detected; releasing pylon priority", true)
				task.wait(0.2)
				continue
			end

			-- Handle no candidates
			if #candidates == 0 then
				rawGolden = scanInfo and (tonumber(scanInfo.RawGolden) or 0) or 0
				local rawNormal = scanInfo and (tonumber(scanInfo.RawNormal) or 0) or 0
				if rawGolden > 0 or rawNormal > 0 then
					lastGiftSeenAt = os.clock()
					transitionTo(controller, "Paused", string.format("Waiting for gifts to settle | Golden %d Normal %d", rawGolden, rawNormal))
					task.wait(0.1)
					continue
				end

				if isHoldingMedalBeforeGoldenComplete(controller) then
					transitionTo(controller, "Paused", "Holding medal; waiting for golden gifts")
					task.wait(0.2)
					continue
				end

				if shouldWaitForPylons(controller) then
					local completed, maximum = getPylonProgress()
					local detail = if maximum > 0
						then string.format("Waiting for pylons %d/%d", completed, maximum)
						else "Waiting for pylons"
					transitionTo(
						controller,
						"Paused",
						detail
					)
					task.wait(0.2)
					continue
				end

				-- Try Medal step
				local lease = MovementLease.acquire("MedalStep")
				transitionTo(controller, "Collecting", "Medal check")
				local handledMedal, medalStatus = tryMedalStep(controller, hrp, lease, mySessionToken)
				lease:release()
				if not isSessionActive() then continue end
				if handledMedal then
					transitionTo(controller, "Collecting", medalStatus or "MedalAction")
					task.wait(0.08)
					continue
				end

				-- Empty complete delay return
				if lastGiftSeenAt > 0 and os.clock() - lastGiftSeenAt >= EMPTY_COMPLETE_DELAY then
					lease = MovementLease.acquire("ReturningBeacon")
					transitionTo(controller, "ReturningBeacon", "Round complete; returning to beacon")
					local success = Beacon.returnToBeacon(
						controller,
						hrp,
						function(c, status, detail)
							transitionTo(c, status, detail)
						end,
						"Round targets complete",
						lease,
						mySessionToken
					)
					lease:release()
					if not isSessionActive() then continue end
					if success then
						transitionTo(controller, "Paused", "At beacon; round complete")
						task.wait(0.4)
					else
						transitionTo(controller, "Recovering", "Beacon return failed; retrying")
						task.wait(0.4)
					end
				else
					transitionTo(controller, "Paused", "Waiting for gifts")
					task.wait(0.25)
				end
				continue
			end

			-- 5. Collecting state
			lastGiftSeenAt = os.clock()
			
			local rangeRevision = tonumber(controller.GiftFarmRangeRevision) or 0
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

			local focus = scanInfo and scanInfo.GoldenLocked and "golden" or "gifts"
			local wasGoldenRoute = scanInfo and scanInfo.GoldenLocked == true
			local wasPassageRoute = scanInfo and scanInfo.PassageLocked == true
			local _, _, normalRatio = Progress.getNormalGiftProgress(gch)
			local normalPacingBatchSize = if wasGoldenRoute
				then nil
				else Progress.getNormalPacingBatchSize(normalRatio, scanInfo and scanInfo.RawNormal or #candidates)
			local shouldHoldForGoldenWait = GoldenWait.shouldHoldAfterRoute(scanInfo, totalPlanned)
			local goldenPreempted = false
			local goldenTargetMet = false
			local lastGoldenPreemptCheckAt = -math.huge
			local cachedLiveGoldenKind = nil
			local cachedGoldenTargetReached = false
			local function shouldAbortRoute()
				if not isSessionActive()
					or not Context.isInRound()
					or controller.PylonActivatorHolding == true
					or controller.GiftFarmPolicyHolding == true
					or (tonumber(controller.GiftFarmRangeRevision) or 0) ~= rangeRevision
				then
					return true
				end
				local now = os.clock()
				if now - lastGoldenPreemptCheckAt >= GOLDEN_PREEMPT_SCAN_INTERVAL then
					lastGoldenPreemptCheckAt = now
					cachedGoldenTargetReached = Scanner.isGoldenTargetReached(gch, controller)
					cachedLiveGoldenKind = if cachedGoldenTargetReached
						then nil
						else Scanner.getLiveGoldenKind(gch, controller)
				end
				if wasGoldenRoute and cachedGoldenTargetReached then
					goldenTargetMet = true
					return true
				end
				if (cachedLiveGoldenKind == "PassageGift" and not wasPassageRoute)
					or (cachedLiveGoldenKind ~= nil and not wasGoldenRoute)
				then
					goldenPreempted = true
					return true
				end

				return false
			end

			-- Acquire Collecting Lease
			local lease = MovementLease.acquire("Collecting")
			if not lease:isValid() then
				transitionTo(
					controller,
					"Paused",
					"Waiting for " .. tostring(lease.BlockedBy or "movement owner")
				)
				task.wait(0.1)
				continue
			end
			transitionTo(controller, "Collecting", string.format("Collecting %d clusters (%d %s)", #route, totalPlanned, focus))

			local routeCompleted = false
			local routeStats = nil

			if mode == PIPELINE_MODE then
				routeCompleted, routeStats = PipelinedCollector.collectRoute(controller, hrp, route, range, {
					NormalPacingBatchSize = normalPacingBatchSize,
					AbortCheck = shouldAbortRoute,
					ProgressCallback = function(progress)
						transitionTo(
							controller,
							"Collecting",
							string.format(
								"Network pipeline %d/%d | %s | ACK %d/%d | sent %d",
								tonumber(progress.Index) or 0,
								tonumber(progress.Total) or #route,
								tostring(progress.Stage or "streaming"),
								tonumber(progress.InFlight) or 0,
								tonumber(progress.Window) or 0,
								tonumber(progress.Dispatched) or 0
							)
						)
					end,
				}, lease, mySessionToken)
			else
				-- Normal mode collection loop
				routeCompleted = true
				routeStats = { Attempted = 0, Accepted = 0, Failed = 0 }
				local tailPrecision = isTailPrecision(candidates, scanInfo, normalRatio)

				for index, step in ipairs(route) do
					if shouldAbortRoute() then
						routeCompleted = false
						break
					end

					local cluster = step.Cluster or {}
					if #cluster == 0 then continue end

					local planInfo = step.Info
					local score = planInfo and planInfo.Score
					local planned = score and (" | plan " .. tostring(score.Golden) .. "/" .. tostring(score.Total)) or ""
					local collapseCount = score and tonumber(score.CollapseCount) or 0
					local precisionMode = tailPrecision
						or (planInfo and planInfo.TailCleanup == true)
						or (collapseCount > 0 and #cluster <= 4)

					transitionTo(
						controller,
						"Collecting",
						string.format("Cluster %d/%d | size %d/%d (%s)", index, #route, #cluster, totalPlanned, precisionMode and "precision" or "normal") .. planned
					)

					local collectResult = Collector.collectCluster(controller, hrp, cluster, range, {
						SafeRange = planInfo and planInfo.SafeRange,
						TargetPosition = planInfo and planInfo.TargetPosition,
						PrecisionMode = precisionMode,
						TailMode = tailPrecision,
						NormalPacingBatchSize = normalPacingBatchSize,
						AbortCheck = shouldAbortRoute,
					}, lease, mySessionToken)

					if collectResult then
						routeStats.Attempted += collectResult.Attempted
						routeStats.Accepted += collectResult.Accepted
						routeStats.Failed += collectResult.Rejected
					end
				end
				if shouldAbortRoute() then
					routeCompleted = false
				end
			end

			-- Release lease
			if routeStats and (tonumber(routeStats.Accepted) or 0) > 0 then
				markProgress()
			end
			if routeCompleted and shouldHoldForGoldenWait and typeof(Beacon.stageForWait) == "function" then
				transitionTo(controller, "Collecting", "Moving to a safe Golden Gift wait position")
				Beacon.stageForWait(hrp, lease)
			end
			lease:release({ KeepFootholdDuration = 2.5, OnlyKeepFootholdIfAirborne = true })

			if not isSessionActive() then continue end
			if goldenPreempted then
				transitionTo(controller, "Scanning", "Golden gifts detected; preempting normal route")
				continue
			end
			if goldenTargetMet then
				transitionTo(controller, "Scanning", "Golden Gift collection target reached")
				continue
			end

			if (tonumber(controller.GiftFarmRangeRevision) or 0) ~= rangeRevision then
				transitionTo(controller, "Paused", "Range changed; recalculating")
				task.wait(0.1)
				continue
			end

			if routeCompleted and shouldHoldForGoldenWait then
				if typeof(GoldenWait.startNormalClearWindow) == "function" then
					GoldenWait.startNormalClearWindow()
				else
					GoldenWait.holdNow()
				end
			end

			if routeCompleted and wasGoldenRoute and not wasPassageRoute then
				pendingGoldenReturnSince = os.clock()
				transitionTo(controller, "Scanning", "Verifying golden complete")
				verifyGoldenRouteComplete(controller, hrp, isSessionActive)
			elseif routeCompleted and wasPassageRoute then
				transitionTo(controller, "Scanning", "Passage gifts cleared; resuming route")
			end

			task.wait(0.04)
			end
		end, debug.traceback)
		if workerGeneration == myWorkerGeneration then
			loopActive = false
		end

		if not ok
			and workerGeneration == myWorkerGeneration
			and enabled
			and not controller.Destroyed
			and controller.GiftFarmEnabled
		then
			warn("[NULLSCAPE] Gift Farm coordinator recovered: " .. tostring(err))
			sessionToken += 1
			if MovementLease.invalidateActive(10) then
				Context.releaseCharacterControl({
					SkipVelocityClear = true,
					SkipStateChange = true,
					ForceAbilityClear = true,
				})
			end
			transitionTo(controller, "Recovering", "Coordinator restarted after runtime error", true)
			task.delay(0.25, function()
				if enabled and not controller.Destroyed and controller.GiftFarmEnabled then
					runLoop(controller)
				end
			end)
		end
	end)
end

local function getLiveGiftCount()
	local gch = Context.getGiftClientHandler()
	if not (gch and typeof(gch.Gifts) == "table") then
		return nil
	end

	local count = 0
	for _, gift in pairs(gch.Gifts) do
		if gift
			and not gift.Destroyed
			and not gift.Collected
			and not gift.ClientCollected
			and not gift.Tripmine
			and Context.getGiftPosition(gift) ~= nil
		then
			count += 1
		end
	end
	return count
end

local function restartStalledWorker(controller, detail)
	workerGeneration += 1
	loopActive = false
	sessionToken += 1
	local releasedGiftMovement = MovementLease.invalidateActive(10)
	MovementLease.resetTransport()
	lastWatchGiftCount = nil
	markWorkerPulse()
	markProgress()
	if Scanner and typeof(Scanner.reset) == "function" then
		Scanner.reset()
	end
	if Collector and typeof(Collector.resetAdaptive) == "function" then
		Collector.resetAdaptive(controller)
	end
	if PipelinedCollector and typeof(PipelinedCollector.cancelPending) == "function" then
		PipelinedCollector.cancelPending(controller)
	end
	if PipelinedCollector and typeof(PipelinedCollector.resetAdaptive) == "function" then
		PipelinedCollector.resetAdaptive(controller)
	end
	if releasedGiftMovement then
		Context.releaseCharacterControl({
			SkipVelocityClear = true,
			SkipStateChange = true,
			ForceAbilityClear = true,
		})
	end
	transitionTo(controller, "Recovering", detail, true)
	runLoop(controller)
end

local function startWatchdog(controller)
	watchdogGeneration += 1
	local myWatchdogGeneration = watchdogGeneration
	lastWatchPosition = nil
	lastWatchGiftCount = nil
	markWorkerPulse()
	markProgress()

	task.spawn(function()
		while enabled and not controller.Destroyed and watchdogGeneration == myWatchdogGeneration do
			task.wait(WATCHDOG_INTERVAL)
			if not (enabled and controller.GiftFarmEnabled and watchdogGeneration == myWatchdogGeneration) then
				continue
			end

			local hrp = Context.getRootPart()
			if hrp and hrp.Parent then
				local position = hrp.Position
				if lastWatchPosition and (position - lastWatchPosition).Magnitude >= WATCHDOG_MOVEMENT_EPSILON then
					markWorkerPulse()
				end
				lastWatchPosition = position
			else
				lastWatchPosition = nil
				markWorkerPulse()
			end

			local liveGiftCount = getLiveGiftCount()
			if liveGiftCount ~= nil then
				if liveGiftCount == 0 or lastWatchGiftCount == nil or liveGiftCount ~= lastWatchGiftCount then
					markProgress()
				end
				lastWatchGiftCount = liveGiftCount
			end

			local now = os.clock()
			local workerStalled = now - lastWorkerPulseAt >= WORKER_STALL_TIMEOUT
			local progressStalled = liveGiftCount ~= nil
				and liveGiftCount > 0
				and controller.PylonActivatorHolding ~= true
				and controller.GiftFarmPolicyHolding ~= true
				and now - lastProgressAt >= LOGICAL_STALL_TIMEOUT
			if Context.isInRound() and (workerStalled or progressStalled) then
				local detail = if progressStalled
					then string.format("No gift progress for %.0fs; rebuilding route", LOGICAL_STALL_TIMEOUT)
					else "Worker stopped responding; restarting"
				warn("[NULLSCAPE] Gift Farm watchdog recovery: " .. detail)
				restartStalledWorker(controller, detail)
			end
		end
	end)
end

function Coordinator.enable(controller, gc)
	if enabled then
		if Context and typeof(Context.suppressMovementInteractions) == "function" then
			Context.suppressMovementInteractions()
		end
		if not loopActive and controller and not controller.Destroyed and controller.GiftFarmEnabled then
			runLoop(controller)
		end
		return true
	end

	enabled = true
	configDirty = true
	if RunPolicy and typeof(RunPolicy.enable) == "function" then
		RunPolicy.enable(controller)
	end

	if Context and typeof(Context.suppressMovementInteractions) == "function" then
		Context.suppressMovementInteractions()
	end

	-- Connect reactively to ConfigChanged
	if controller and controller.ConfigChanged then
		if configChangedConn then
			pcall(function()
				configChangedConn:Disconnect()
			end)
		end
		configChangedConn = controller.ConfigChanged.Event:Connect(function()
			configDirty = true
			sessionToken += 1
			MovementLease.invalidateActive(10)
			if enabled then
				runLoop(controller)
			end
		end)
		if gc and typeof(gc.registerConnection) == "function" then
			gc.registerConnection(configChangedConn)
		end
	end

	observeCharacter(controller, gc)
	observeInRound(controller, gc)
	observePylons(controller, gc)

	startWatchdog(controller)
	runLoop(controller)
	return true
end

function Coordinator.disable(controller)
	local wasEnabled = enabled
	enabled = false
	watchdogGeneration += 1
	workerGeneration += 1
	loopActive = false
	sessionToken += 1
	MovementLease.invalidateActive(10)
	if PipelinedCollector and typeof(PipelinedCollector.cancelPending) == "function" then
		PipelinedCollector.cancelPending(controller)
	end

	if Context and typeof(Context.restoreMovementInteractions) == "function" then
		local restored, restoreError = pcall(Context.restoreMovementInteractions)
		if not restored then
			warn("[NULLSCAPE] Gift Farm interaction restore failed: " .. tostring(restoreError))
		end
	end
	if RunPolicy and typeof(RunPolicy.disable) == "function" then
		RunPolicy.disable(controller)
	end

	if wasEnabled then
		local recovered, recoveryError = pcall(recoverAfterStop, controller, "Gift Farm disabled")
		if not recovered then
			warn("[NULLSCAPE] Gift Farm shutdown recovery failed: " .. tostring(recoveryError))
		end
	end

	if configChangedConn then
		pcall(function()
			configChangedConn:Disconnect()
		end)
		configChangedConn = nil
	end

	disconnectObservers()
	return true
end

function Coordinator.update(controller, gc)
	if controller and controller.GiftFarmEnabled then
		return Coordinator.enable(controller, gc)
	end
	return Coordinator.disable(controller)
end

function Coordinator.getStatus(controller)
	return {
		Status = controller and controller.GiftFarmStatus or "Idle",
		Detail = controller and controller.GiftFarmDetail or "",
		Mode = controller and controller.GiftFarmMode or NORMAL_MODE,
		Pipeline = {
			Window = controller and controller.GiftFarmPipelineWindow or 0,
			InFlight = controller and controller.GiftFarmPipelineInFlight or 0,
			Dispatched = controller and controller.GiftFarmPipelineDispatched or 0,
			Accepted = controller and controller.GiftFarmPipelineAccepted or 0,
			Unresolved = controller and controller.GiftFarmPipelineUnresolved or 0,
			TransientRejects = controller and controller.GiftFarmPipelineTransientRejects or 0,
			Rejected = controller and controller.GiftFarmPipelineRejected or 0,
			Retries = controller and controller.GiftFarmPipelineRetries or 0,
			AckLatency = controller and controller.GiftFarmPipelineAckLatency or 0,
		},
	}
end

return Coordinator
