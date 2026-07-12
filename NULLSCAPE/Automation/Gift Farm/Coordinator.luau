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
local MAX_RETRY_QUEUE = 32
local RESPAWN_READY_DELAY = 0.85
local TAIL_REMAINING_RATIO = 0.12

local enabled = false
local configDirty = false
local sessionToken = 0
local characterSessionToken = 0
local activeLease = nil
local loopActive = false

-- Observers
local characterAddedConnection = nil
local characterRemovingConnection = nil
local inRoundConnection = nil
local configChangedConn = nil

-- Runtime state variables
local characterReady = false
local characterReadyAt = 0
local lastGiftSeenAt = 0
local pendingGoldenReturnSince = nil
local retryQueue = {}
local lastGiftCount = nil
local lastGiftCountChangedAt = 0
local giftsStabilized = false
local startWaitAt = nil
local currentStatus = "Idle"
local lastStatusAt = 0

-- Hydrated configurations
local range = DEFAULT_RANGE
local mode = NORMAL_MODE

local function transitionTo(controller, status, detail, force)
	local nextStatus = status or "Idle"
	local now = os.clock()
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
	MovementLease.invalidateActive()

	if activeLease then
		activeLease:release({
			SkipVelocityClear = true,
			SkipStateChange = true,
			ForceAbilityClear = true,
		})
		activeLease = nil
	else
		Context.releaseCharacterControl({
			SkipVelocityClear = true,
			SkipStateChange = true,
			ForceAbilityClear = true,
		})
	end

	if Beacon and typeof(Beacon.restore) == "function" then
		Beacon.restore(true)
	end

	table.clear(retryQueue)
	pendingGoldenReturnSince = nil
	giftsStabilized = false
	startWaitAt = nil
	lastGiftCount = nil
	lastGiftSeenAt = 0
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
end

local function isRetryGiftAlive(item)
	local rawObj = item and item.rawObj
	if not rawObj or rawObj.Destroyed or rawObj.Collected or rawObj.ClientCollected or rawObj.Tripmine then
		return false
	end
	return Context.getGiftPosition(rawObj) ~= nil
end

local function enqueueRetryItems(routeStats)
	if not (routeStats and typeof(routeStats.Retry) == "table") then
		return 0
	end

	local queued = 0
	local existing = {}
	for _, item in ipairs(retryQueue) do
		if item and item.rawObj then
			existing[item.rawObj] = true
		end
	end

	for _, item in ipairs(routeStats.Retry) do
		if #retryQueue >= MAX_RETRY_QUEUE then
			break
		end
		if isRetryGiftAlive(item) and not existing[item.rawObj] then
			table.insert(retryQueue, item)
			existing[item.rawObj] = true
			queued += 1
		end
	end
	return queued
end

local function applyRetryPriority(candidates, scanInfo)
	if #retryQueue == 0 then
		return candidates, 0
	end

	local goldenOnly = scanInfo and scanInfo.GoldenLocked == true
	local nextQueue = {}
	local retryCandidates = {}
	local retryMap = {}
	local retryCount = 0
	for _, item in ipairs(retryQueue) do
		local rawObj = item and item.rawObj
		local pos = isRetryGiftAlive(item) and Context.getGiftPosition(rawObj) or nil
		if pos then
			local isGolden = rawObj.Golden == true
			if goldenOnly and not isGolden then
				table.insert(nextQueue, item)
			elseif not retryMap[rawObj] then
				table.insert(retryCandidates, {
					rawObj = rawObj,
					pos = pos,
					priority = -1000,
					collapsePriority = item.collapsePriority or 0,
					id = item.id or rawObj.Id or 0,
					golden = isGolden,
				})
				retryMap[rawObj] = true
				retryCount += 1
			end
		end
	end
	retryQueue = nextQueue

	if #retryCandidates == 0 then
		return candidates, 0
	end

	for _, item in ipairs(candidates) do
		if not (item and item.rawObj and retryMap[item.rawObj]) then
			table.insert(retryCandidates, item)
		end
	end
	return retryCandidates, retryCount
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

local function shouldWaitForPylons(controller)
	if not (controller and controller.PylonActivatorEnabled) then
		return false
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

	pendingGoldenReturnSince = nil
	if controller then
		controller.GiftFarmGoldenComplete = true
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
		MovementLease.invalidateActive()
		Context.releaseCharacterControl({
			SkipVelocityClear = true,
			ForceAbilityClear = true,
			SkipStateChange = true,
		})
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

		local verifyCandidates, verifyInfo = Scanner.scan(controller, gch)
		if GoldenWait and typeof(GoldenWait.noteScan) == "function" then
			GoldenWait.noteScan(verifyInfo)
		end
		softCleanup(verifyCandidates)

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
		characterReady = false
		characterReadyAt = math.huge
		pendingGoldenReturnSince = nil
		table.clear(retryQueue)
		if controller then
			controller.GiftFarmGoldenComplete = false
		end

		if activeLease then
			activeLease:release({ SkipVelocityClear = true, SkipStateChange = true })
			activeLease = nil
		end

		if Context and typeof(Context.resetGiftClientHandler) == "function" then
			Context.resetGiftClientHandler()
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

			if hrp and enabled and localPlayer.Character == character and myCharacterSession == characterSessionToken then
				if activeLease then
					activeLease:release({ SkipVelocityClear = true, SkipStateChange = true })
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
		pendingGoldenReturnSince = nil
		lastGiftCount = nil
		giftsStabilized = false
		startWaitAt = nil
		lastGiftSeenAt = 0
		table.clear(retryQueue)
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
			if activeLease then
				activeLease:release({ ForceRelease = true })
				activeLease = nil
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
			PipelinedCollector.resetAdaptive()
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
	loopActive = true

	task.spawn(function()
		while enabled and not controller.Destroyed do
			local mySessionToken = sessionToken

			local function isSessionActive()
				return enabled and sessionToken == mySessionToken and not controller.Destroyed
			end

			-- 1. Check config changes (HydratingConfig)
			if configDirty then
				configDirty = false
				transitionTo(controller, "HydratingConfig", "Updating configuration options")
				sessionToken += 1
				MovementLease.invalidateActive()
				mySessionToken = sessionToken

				range = getGiftFarmRange(controller)
				mode = controller.GiftFarmMode

				-- Invalidate/Acquire main loop lease reference
				if activeLease then
					activeLease:release()
					activeLease = nil
				end
				activeLease = MovementLease.acquire("CoordinatorLoop")
				task.wait(0.1)
				if not isSessionActive() then continue end
			end

			if not controller.GiftFarmEnabled then
				transitionTo(controller, "Idle", "Gift Farm disabled")
				if activeLease then
					activeLease:release()
					activeLease = nil
				end
				break
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
				if activeLease then
					activeLease:release()
					activeLease = nil
				end
				task.wait(0.5)
				continue
			end

			if not inRound then
				transitionTo(controller, "Recovering", "Waiting for round to start")
				MovementLease.invalidateActive()
				if activeLease then
					activeLease:release({
						SkipVelocityClear = true,
						ForceAbilityClear = true,
						SkipStateChange = true,
					})
					activeLease = nil
				else
					Context.releaseCharacterControl({
						SkipVelocityClear = true,
						ForceAbilityClear = true,
						SkipStateChange = true,
					})
				end
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
					if elapsed < 6 then
						transitionTo(controller, "Scanning", string.format("Waiting for gifts to spawn (%.1fs/6.0s)...", elapsed))
						task.wait(0.2)
						continue
					else
						giftsStabilized = true
						lastGiftSeenAt = os.clock()
						startWaitAt = nil
					end
				else
					if not lastGiftCount or lastGiftCount ~= giftCount then
						lastGiftCount = giftCount
						lastGiftCountChangedAt = os.clock()
					end

					local stableDuration = os.clock() - lastGiftCountChangedAt
					if stableDuration < 3 then
						transitionTo(controller, "Scanning", string.format("Waiting for gifts to stabilize (%.1fs/3.0s)", stableDuration))
						task.wait(0.15)
						continue
					end

					giftsStabilized = true
					lastGiftSeenAt = os.clock()
					startWaitAt = nil
				end
			end

			-- 3. Check pylon priority
			if controller.PylonActivatorHolding == true then
				transitionTo(controller, "Paused", "Paused for pylon activator")
				if activeLease then
					activeLease:release({ KeepFootholdDuration = 2.5, OnlyKeepFootholdIfAirborne = true })
				end
				task.wait(0.2)
				continue
			end

			-- Ensure we have a valid lease for general states
			if not activeLease or not activeLease:isValid() then
				activeLease = MovementLease.acquire("CoordinatorLoop")
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

			local rawGolden = scanInfo and (tonumber(scanInfo.RawGolden) or 0) or 0
			if rawGolden > 0 then
				if Beacon and typeof(Beacon.suppressUntilReturn) == "function" then
					Beacon.suppressUntilReturn()
				end
			else
				if Beacon and typeof(Beacon.restore) == "function" then
					Beacon.restore(true)
				end
			end

			if GoldenWait and typeof(GoldenWait.noteScan) == "function" then
				GoldenWait.noteScan(scanInfo)
			end

			-- Try Altar step
			local passageGoldenPriority = GoldenWait
				and typeof(GoldenWait.isPassageWindowActive) == "function"
				and GoldenWait.isPassageWindowActive() == true
			if not passageGoldenPriority and Altar and typeof(Altar.tryStep) == "function" then
				local lease = MovementLease.acquire("AltarStep")
				transitionTo(controller, "Collecting", "Attempting Altar activation")
				local handledAltar, altarStatus, altarDetail = Altar.tryStep(controller, hrp, lease, mySessionToken)
				lease:release()
				if not isSessionActive() then continue end
				if handledAltar then
					if typeof(altarDetail) == "string"
						and string.find(altarDetail, "Passage", 1, true)
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

			-- Try Golden Return
			if tryGoldenCompleteReturn(controller, hrp, scanInfo, isSessionActive) then
				continue
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
			local candidatesWithRetry, retryCount = applyRetryPriority(candidates, scanInfo)
			
			local route, remaining = ClusterPlanner.planRoute(candidatesWithRetry, range, hrp.Position)
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
			local shouldHoldForGoldenWait = GoldenWait.shouldHoldAfterRoute(scanInfo, totalPlanned)

			-- Acquire Collecting Lease
			local lease = MovementLease.acquire("Collecting")
			transitionTo(controller, "Collecting", string.format("Collecting %d clusters (%d %s%s)", #route, totalPlanned, focus, retryCount > 0 and (" | retry " .. tostring(retryCount)) or ""))

			local routeCompleted = false
			local routeStats = nil

			if mode == PIPELINE_MODE then
				routeCompleted, routeStats = PipelinedCollector.collectRoute(controller, hrp, route, range, {
					AbortCheck = function()
						return not isSessionActive() or (tonumber(controller.GiftFarmRangeRevision) or 0) ~= rangeRevision
					end,
				}, lease, mySessionToken)
			else
				-- Normal mode collection loop
				routeCompleted = true
				routeStats = { Attempted = 0, Accepted = 0, Failed = 0, Retry = {} }
				local _, _, normalRatio = Progress.getNormalGiftProgress(gch)
				local tailPrecision = isTailPrecision(candidatesWithRetry, scanInfo, normalRatio)
				local routeRejected = false

				for index, step in ipairs(route) do
					if not isSessionActive() or (tonumber(controller.GiftFarmRangeRevision) or 0) ~= rangeRevision then
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
						or #cluster <= 2
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
						AbortCheck = function()
							return not isSessionActive() or (tonumber(controller.GiftFarmRangeRevision) or 0) ~= rangeRevision
						end,
					}, lease, mySessionToken)

					if collectResult then
						routeStats.Attempted += collectResult.Attempted
						routeStats.Accepted += collectResult.Accepted
						routeStats.Failed += collectResult.Rejected
						if (tonumber(collectResult.Rejected) or 0) > 0 then
							routeRejected = true
						end
					end
				end

				if routeRejected then
					routeStats.Failed = 0
					-- Enqueue the rejected ones as retry
					routeStats.Retry = candidatesWithRetry
				end
			end

			-- Release lease
			lease:release({ KeepFootholdDuration = 2.5, OnlyKeepFootholdIfAirborne = true })
			enqueueRetryItems(routeStats)
			clearRoute(route)
			softCleanup(candidates, remaining)

			if not isSessionActive() then continue end

			if (tonumber(controller.GiftFarmRangeRevision) or 0) ~= rangeRevision then
				transitionTo(controller, "Paused", "Range changed; recalculating")
				task.wait(0.1)
				continue
			end

			if shouldHoldForGoldenWait then
				if typeof(GoldenWait.startNormalClearWindow) == "function" then
					GoldenWait.startNormalClearWindow()
				else
					GoldenWait.holdNow()
				end
			end

			if routeCompleted and wasGoldenRoute then
				pendingGoldenReturnSince = os.clock()
				transitionTo(controller, "Scanning", "Verifying golden complete")
				verifyGoldenRouteComplete(controller, hrp, isSessionActive)
			end

			task.wait(0.04)
		end
		loopActive = false
	end)
end

function Coordinator.enable(controller, gc)
	if enabled then
		return true
	end

	enabled = true
	configDirty = true

	if Context and typeof(Context.suppressRails) == "function" then
		Context.suppressRails()
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
			MovementLease.invalidateActive()
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

	runLoop(controller)
	return true
end

function Coordinator.disable(controller)
	if not enabled then
		return true
	end

	enabled = false
	recoverAfterStop(controller, "Gift Farm disabled")

	if Context and typeof(Context.restoreRails) == "function" then
		Context.restoreRails()
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
	}
end

return Coordinator
