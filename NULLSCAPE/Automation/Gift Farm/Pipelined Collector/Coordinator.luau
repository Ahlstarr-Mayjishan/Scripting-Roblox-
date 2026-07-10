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
local ModeIsolation = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Mode Isolation.luau")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Coordinator = {}
local PIPELINE_MODE = "Pipelining (Network)"
local DEFAULT_RANGE = 60
local MIN_SCAN_INTERVAL = 0.04
local STATUS_UPDATE_INTERVAL = 0.15
local EMPTY_COMPLETE_DELAY = 2.5
local PYLON_LEVEL = 35
local GOLDEN_RETURN_VERIFY_ATTEMPTS = 6
local GOLDEN_RETURN_VERIFY_INTERVAL = 0.12
local MAX_RETRY_QUEUE = 32
local RESPAWN_READY_DELAY = 0.65

local enabled = false
local busy = false
local connection = nil
local inRoundConnection = nil
local characterAddedConnection = nil
local characterRemovingConnection = nil
local lastScan = 0
local lastGiftSeenAt = 0
local lastStatusAt = 0
local lastStatus = nil
local roundToken = 0
local modeToken = 0
local characterToken = 0
local characterReady = false
local characterReadyAt = 0
local pendingGoldenReturnSince = nil
local retryQueue = {}

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

local function forceReleasePipeline(options)
	options = options or {}
	if PipelinedCollector and typeof(PipelinedCollector.releaseCharacter) == "function" then
		pcall(function()
			PipelinedCollector.releaseCharacter({
				ForceRelease = true,
				SkipVelocityClear = options.SkipVelocityClear == true,
			})
		end)
	elseif PipelinedCollector and typeof(PipelinedCollector.cancelPending) == "function" then
		pcall(function()
			PipelinedCollector.cancelPending()
		end)
	end
end

local function releaseCurrentCharacterControl(options)
	options = options or {}
	forceReleasePipeline({
		SkipVelocityClear = options.SkipVelocityClear == true,
	})
	local hrp = Context.getRootPart()
	if not (hrp and hrp.Parent) then
		return
	end

	Context.releaseCharacterControl({
		SkipVelocityClear = options.SkipVelocityClear == true,
		State = Enum.HumanoidStateType.Running,
	})
end

local function clearRetryQueue()
	table.clear(retryQueue)
end

local function resetPipelineModules()
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
end

local function resetCharacterState(controller)
	roundToken += 1
	characterToken += 1
	characterReady = false
	characterReadyAt = math.huge
	busy = false
	lastScan = 0
	lastGiftSeenAt = 0
	lastStatusAt = 0
	lastStatus = nil
	pendingGoldenReturnSince = nil
	clearRetryQueue()
	if controller then
		controller.GiftFarmGoldenComplete = false
	end
	forceReleasePipeline({
		SkipVelocityClear = true,
	})
	releaseCurrentCharacterControl({
		SkipVelocityClear = true,
	})
	resetPipelineModules()
	if Beacon and typeof(Beacon.reset) == "function" then
		Beacon.reset(Context.isInRound())
	end
	if Beacon and typeof(Beacon.restore) == "function" then
		Beacon.restore(true)
	end
	setStatus(controller, "WaitingForCharacter", "Character respawned (Pipeline)", true)
end

local function resetRoundState(controller, inRound)
	roundToken += 1
	busy = false
	lastScan = 0
	lastGiftSeenAt = 0
	lastStatusAt = 0
	lastStatus = nil
	pendingGoldenReturnSince = nil
	clearRetryQueue()
	if controller then
		controller.GiftFarmGoldenComplete = false
	end
	resetPipelineModules()
	if Beacon and typeof(Beacon.reset) == "function" then
		Beacon.reset(inRound)
	end
	if PipelinedCollector and typeof(PipelinedCollector.cancelPending) == "function" then
		pcall(function()
			PipelinedCollector.cancelPending()
		end)
	end
	if not inRound then
		if Beacon and typeof(Beacon.restore) == "function" then
			Beacon.restore(true)
		end
		forceReleasePipeline()
	end
	if inRound then
		setStatus(controller, "WaitingForGifts", "Round started (Pipeline)")
	else
		setStatus(controller, "WaitingForRound", "Round ended (Pipeline)")
	end
end

local function observeCharacter(controller, gc)
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end

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

	characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
		if not enabled or not controller or controller.Destroyed then
			return
		end
		resetCharacterState(controller)
		local thisCharacterToken = characterToken
		task.spawn(function()
			local hrp = character and character:WaitForChild("HumanoidRootPart", 6)
			if hrp
				and enabled
				and localPlayer.Character == character
				and thisCharacterToken == characterToken
				and ModeIsolation.isActive(PIPELINE_MODE, modeToken)
			then
				releaseCurrentCharacterControl({
					SkipVelocityClear = true,
				})
			end
			for _ = 1, 8 do
				RunService.Heartbeat:Wait()
			end
			if enabled
				and hrp
				and localPlayer.Character == character
				and thisCharacterToken == characterToken
				and ModeIsolation.isActive(PIPELINE_MODE, modeToken)
			then
				characterReady = true
				characterReadyAt = os.clock() + RESPAWN_READY_DELAY
				if Context.isInRound() then
					setStatus(controller, "WaitingForGifts", "Character ready (Pipeline)", true)
				else
					setStatus(controller, "WaitingForRound", "Character ready (Pipeline)", true)
				end
			end
		end)
	end)

	characterRemovingConnection = localPlayer.CharacterRemoving:Connect(function()
		if not enabled or not controller or controller.Destroyed then
			return
		end
		characterReady = false
		resetCharacterState(controller)
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

local function returnToBeacon(controller, hrp, reason)
	if PipelinedCollector and typeof(PipelinedCollector.releaseCharacter) == "function" then
		pcall(function()
			PipelinedCollector.releaseCharacter({
				ForceRelease = true,
			})
		end)
	end
	if Beacon and typeof(Beacon.returnToBeacon) == "function" then
		return Beacon.returnToBeacon(controller, hrp, setStatus, reason)
	end
	return false
end

local function tryGoldenCompleteReturn(controller, hrp, scanInfo, isCurrentRoundActive)
	if not (pendingGoldenReturnSince and scanInfo and tonumber(scanInfo.RawGolden) == 0) then
		return false
	end

	pendingGoldenReturnSince = nil
	markGoldenComplete(controller)
	if shouldWaitForPylons(controller) then
		setStatus(controller, "WaitingForPylons", "Golden gifts complete")
		return true
	end

	local handledMedal, medalStatus = tryMedalStep(controller, hrp)
	if not isCurrentRoundActive() then
		setStatus(controller, "WaitingForRound")
		return true
	end
	if handledMedal then
		setStatus(controller, medalStatus or "MedalAction")
		return true
	end

	if returnToBeacon(controller, hrp, "Golden gifts complete") then
		return true
	end

	setStatus(controller, "GoldenCompleteWatching", "Beacon return retry pending")
	pendingGoldenReturnSince = os.clock()
	return true
end

local function verifyGoldenRouteComplete(controller, hrp, isCurrentRoundActive)
	for _ = 1, GOLDEN_RETURN_VERIFY_ATTEMPTS do
		if not isCurrentRoundActive() then
			setStatus(controller, "WaitingForRound")
			return true
		end

		hrp = Context.getRootPart() or hrp
		if not hrp then
			setStatus(controller, "WaitingForCharacter")
			return true
		end

		local gch = Context.getGiftClientHandler()
		if not (gch and gch.Gifts) then
			setStatus(controller, "WaitingForGiftClient")
			return true
		end

		local verifyCandidates, verifyInfo = Scanner.scan(controller, gch)
		if GoldenWait and typeof(GoldenWait.noteScan) == "function" then
			GoldenWait.noteScan(verifyInfo)
		end
		softCleanup(verifyCandidates, nil)

		if tryGoldenCompleteReturn(controller, hrp, verifyInfo, isCurrentRoundActive) then
			return true
		end

		if verifyInfo and tonumber(verifyInfo.RawGolden) and tonumber(verifyInfo.RawGolden) > 0 then
			return false
		end

		task.wait(GOLDEN_RETURN_VERIFY_INTERVAL)
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
		return enabled
			and token == roundToken
			and ModeIsolation.isActive(PIPELINE_MODE, modeToken)
			and Context.isInRound()
	end

	task.spawn(function()
		local ok, err = pcall(function()
			if not isCurrentRoundActive() then
				setStatus(controller, "WaitingForRound")
				return
			end

			local hrp = Context.getRootPart()
			if not (characterReady and hrp) then
				setStatus(controller, "WaitingForCharacter")
				return
			end
			if os.clock() < characterReadyAt then
				setStatus(controller, "WaitingForCharacter", "Waiting for respawn replication")
				return
			end

			if controller.PylonActivatorHolding == true then
				setStatus(controller, "PausedForPylon", "Pylon activation has movement priority")
				return
			end

			if controller.GiftFarmGoldenComplete ~= true
				and pendingGoldenReturnSince == nil
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
			if tryGoldenCompleteReturn(controller, hrp, scanInfo, isCurrentRoundActive) then
				return
			end
			local goldenWaitReason = GoldenWait.hasSeenGolden() and "Golden respawn check" or "Post-clear check"
			if GoldenWait.shouldWait(controller, scanInfo, lastGiftSeenAt, setStatus, goldenWaitReason) then
				return
			end
			local retryCount = 0
			candidates, retryCount = applyRetryPriority(candidates, scanInfo)
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
				local success = returnToBeacon(controller, hrp, "Golden gifts complete")
				if success then
					return
				end
				local reason = ""
				if not Beacon then
					reason = "NoBeaconMod"
				elseif not Context.isBeaconActive() then
					reason = "BeaconInactive"
				elseif not Context.getBeaconPart() then
					reason = "NoBeaconPart"
				elseif controller.GiftFarmReturnToBeaconAfterGolden == false then
					reason = "ReturnDisabled"
				else
					reason = "Unknown/AlreadyDone"
				end
				setStatus(controller, "GoldenCompleteWatching", "Beacon fail: " .. reason)
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
					local success = returnToBeacon(controller, hrp, "Round targets complete")
					if success then
						return
					end
					local reason = ""
					if not Beacon then
						reason = "NoBeaconMod"
					elseif not Context.isBeaconActive() then
						reason = "BeaconInactive"
					elseif not Context.getBeaconPart() then
						reason = "NoBeaconPart"
					elseif controller.GiftFarmReturnToBeaconAfterGolden == false then
						reason = "ReturnDisabled"
					else
						reason = "Unknown/AlreadyDone"
					end
					setStatus(controller, "RoundCompleteWatching", "Beacon fail: " .. reason)
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

			local wasGoldenRoute = scanInfo and scanInfo.GoldenLocked == true
			local shouldHoldForGoldenWait = GoldenWait.shouldHoldAfterRoute(scanInfo, totalPlanned)
			local focus = scanInfo and scanInfo.GoldenLocked and "golden" or "gifts"
			
			-- Bắt đầu thu thập kiểu Pipelined
			setStatus(
				controller,
				"Collecting (Pipeline)",
				string.format(
					"%d routes | %d %s planned%s",
					#route,
					totalPlanned,
					focus,
					retryCount > 0 and string.format(" | retry %d", retryCount) or ""
				)
			)

			local routeCompleted, routeStats = PipelinedCollector.collectRoute(controller, hrp, route, range, {
				AbortCheck = function()
					return not isCurrentRoundActive()
				end,
			})
			enqueueRetryItems(routeStats)

			clearRoute(route)
			softCleanup(candidates, remaining)

			if shouldHoldForGoldenWait then
				if typeof(GoldenWait.startNormalClearWindow) == "function" then
					GoldenWait.startNormalClearWindow()
				else
					GoldenWait.holdNow()
				end
			end
			if routeCompleted and wasGoldenRoute then
				pendingGoldenReturnSince = os.clock()
				setStatus(controller, "VerifyingGoldenComplete", "Checking final golden gifts")
				if verifyGoldenRouteComplete(controller, hrp, isCurrentRoundActive) then
					return
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
	if enabled and ModeIsolation.isActive(PIPELINE_MODE, modeToken) then
		return true
	end
	if enabled then
		Coordinator.disable(controller)
	end

	modeToken = ModeIsolation.enter(PIPELINE_MODE)
	enabled = true
	observeCharacter(controller, gc)
	observeInRound(controller, gc)
	connection = RunService.Heartbeat:Connect(function()
		if controller
			and controller.GiftFarmEnabled
			and controller.GiftFarmMode == PIPELINE_MODE
			and ModeIsolation.isActive(PIPELINE_MODE, modeToken)
		then
			processOnce(controller)
		end
	end)
	if gc and typeof(gc.registerConnection) == "function" then
		gc.registerConnection(connection)
	end
	return true
end

function Coordinator.disable(controller)
	if not enabled and not ModeIsolation.isActive(PIPELINE_MODE, modeToken) then
		if Beacon and typeof(Beacon.restore) == "function" then
			Beacon.restore(true)
		end
		forceReleasePipeline()
		if Context and typeof(Context.releaseCharacterControl) == "function" then
			Context.releaseCharacterControl()
		end
		return true
	end

	enabled = false
	busy = false
	ModeIsolation.leave(PIPELINE_MODE, modeToken)
	if Beacon and typeof(Beacon.restore) == "function" then
		Beacon.restore(true)
	end
	forceReleasePipeline()
	if Context and typeof(Context.releaseCharacterControl) == "function" then
		Context.releaseCharacterControl()
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
	resetRoundState(controller, false)
	softCleanup()
	setStatus(controller, "Idle", nil, true)
	return true
end

function Coordinator.update(controller, gc)
	if controller and controller.GiftFarmEnabled and controller.GiftFarmMode == PIPELINE_MODE then
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
