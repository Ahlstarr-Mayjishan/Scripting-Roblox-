--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Distance = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Distance.luau")

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Collector = {}
local COLLECT_SETTLE = 0
local PRECISION_COLLECT_SETTLE = 0.05
local SYNC_MIN = 0.02
local SYNC_MAX = 0.055
local PRECISION_SYNC_MIN = 0.025
local PRECISION_SYNC_MAX = 0.08
local BASE_VALIDATION_WAIT = 0.06
local PRECISION_VALIDATION_WAIT = 0.12
local PRECISION_VALIDATION_MAX = 0.2
local ARRIVAL_TOLERANCE = 3
local PRECISION_ARRIVAL_TOLERANCE = 1.75
local ARRIVAL_STABLE_FRAMES = 1
local PRECISION_STABLE_FRAMES = 2
local TAIL_STABLE_FRAMES = 2
local ARRIVAL_TIMEOUT = 0.22
local PRECISION_ARRIVAL_TIMEOUT = 0.28
local TAIL_ARRIVAL_TIMEOUT = 0.38
local PRECISION_CLEANUP_DURATION = 0.18
local TAIL_CLEANUP_DURATION = 0.34
local PRECISION_CLEANUP_MAX_PULSES = 6
local TAIL_CLEANUP_MAX_PULSES = 10
local CLEANUP_PULSE_INTERVAL = 0.015
local MAX_RETRY_PASSES = 2
local MAX_PRECISION_RETRY_PASSES = 3
local RETRY_SETTLE = 0.045

local comboCount = 0
local lastCollectTick = 0
local adaptiveSuccessRate = 1
local adaptiveValidationWait = BASE_VALIDATION_WAIT
local failedAttempts = setmetatable({}, { __mode = "k" })
local hookedGifts = setmetatable({}, { __mode = "k" })

local function hookGiftFailure(gift)
	if not gift or hookedGifts[gift] then
		return
	end

	local originalUncollect = gift.Uncollect
	if typeof(originalUncollect) ~= "function" then
		hookedGifts[gift] = true
		return
	end

	hookedGifts[gift] = true
	gift.Uncollect = function(self, ...)
		failedAttempts[self] = os.clock()
		return originalUncollect(self, ...)
	end
end

local function collectGift(gift, collectedEvent)
	hookGiftFailure(gift)
	failedAttempts[gift] = nil

	local now = tick()
	if math.min(1.2, math.pow(1.1, comboCount) * 0.8) <= now - lastCollectTick then
		comboCount = 0
	end
	comboCount += 1
	lastCollectTick = now

	pcall(function()
		gift:Collect(false, true, comboCount)
	end)

	if collectedEvent then
		pcall(function()
			collectedEvent:Fire()
		end)
	end
end

local function isGiftAccepted(gift)
	if not gift then
		return true
	end
	if failedAttempts[gift] ~= nil then
		return false
	end
	return gift.Destroyed == true or gift.Collected == true or gift.ClientCollected == true
end

local function clearVelocity(hrp)
	if not (hrp and hrp.Parent) then
		return
	end

	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
end

local function waitIfPositive(seconds)
	local duration = tonumber(seconds) or 0
	if duration > 0 then
		task.wait(duration)
	end
end

local function normalizePingSeconds(value)
	local ping = tonumber(value)
	if not ping or ping <= 0 then
		return nil
	end
	if ping > 1 then
		ping /= 1000
	end
	return ping
end

local function getPingSeconds()
	local ok, result = pcall(function()
		if Stats.Network and typeof(Stats.Network.GetPing) == "function" then
			return Stats.Network:GetPing()
		end
		return nil
	end)
	local ping = ok and normalizePingSeconds(result) or nil
	if ping then
		return ping
	end

	ok, result = pcall(function()
		local serverStats = Stats.Network and Stats.Network:FindFirstChild("ServerStatsItem")
		local dataPing = serverStats and serverStats:FindFirstChild("Data Ping")
		if dataPing and typeof(dataPing.GetValue) == "function" then
			return dataPing:GetValue()
		end
		return nil
	end)
	return ok and normalizePingSeconds(result) or nil
end

local function waitForReplicationSync(precisionMode)
	local ping = getPingSeconds() or 0.08
	local targetWait = ping * 0.55
	local minWait = precisionMode and PRECISION_SYNC_MIN or SYNC_MIN
	local maxWait = math.max(precisionMode and PRECISION_SYNC_MAX or SYNC_MAX, ping * 0.8)
	local waitTime = math.clamp(targetWait, minWait, maxWait)

	local frames = precisionMode and 2 or 1
	for _ = 1, frames do
		RunService.Heartbeat:Wait()
	end
	waitIfPositive(waitTime)
end

local function getValidationWait(_controller, precisionMode)
	local ping = getPingSeconds() or 0.08
	local minWait = precisionMode and PRECISION_VALIDATION_WAIT or 0.065
	local baseWait = math.max(minWait, ping * 1.2)

	if precisionMode then
		local maxWait = math.max(PRECISION_VALIDATION_MAX, ping * 1.6)
		return math.clamp(math.max(baseWait, adaptiveValidationWait), PRECISION_VALIDATION_WAIT, maxWait)
	end
	
	local maxWait = math.max(0.22, ping * 1.4)
	return math.clamp(math.max(baseWait, adaptiveValidationWait), 0.065, maxWait)
end

local function updateAdaptiveTiming(controller, attemptedGifts, observedRejects)
	if not attemptedGifts or #attemptedGifts == 0 then
		return
	end

	local accepted = 0
	local failed = tonumber(observedRejects) or 0
	for _, gift in ipairs(attemptedGifts) do
		if isGiftAccepted(gift) then
			accepted += 1
		elseif failedAttempts[gift] ~= nil and failed <= 0 then
			failed += 1
		end
	end

	local ratio = accepted / #attemptedGifts
	adaptiveSuccessRate = adaptiveSuccessRate * 0.7 + ratio * 0.3

	if failed > 0 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.04, BASE_VALIDATION_WAIT, PRECISION_VALIDATION_MAX)
	elseif ratio < 0.65 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.03, BASE_VALIDATION_WAIT, PRECISION_VALIDATION_MAX)
	elseif ratio < 0.9 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.015, BASE_VALIDATION_WAIT, PRECISION_VALIDATION_MAX)
	elseif adaptiveSuccessRate > 0.98 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait - 0.035, 0.052, PRECISION_VALIDATION_MAX)
	elseif adaptiveSuccessRate > 0.94 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait - 0.02, 0.052, PRECISION_VALIDATION_MAX)
	end

	if controller then
		controller.GiftFarmAdaptiveSuccessRate = adaptiveSuccessRate
		controller.GiftFarmAdaptiveValidationWait = adaptiveValidationWait
		controller.GiftFarmAdaptiveRejects = failed
		controller.GiftFarmAdaptiveRetries = failed
	end
end

local function isAborted(options, lease, _currentSessionToken)
	if options and typeof(options.AbortCheck) == "function" and options.AbortCheck() == true then
		return true
	end
	if lease and not lease:isValid() then
		return true
	end
	return false
end

local function jumpToWaypoint(hrp, targetPosition, lease)
	if not (hrp and hrp.Parent) then
		return false
	end

	if lease:moveTo(CFrame.new(targetPosition)) == false then
		return false
	end
	clearVelocity(hrp)
	RunService.Heartbeat:Wait()
	return true
end

local function waitForArrival(hrp, targetPosition, precisionMode, lease, currentSessionToken, options)
	if not (hrp and hrp.Parent and typeof(targetPosition) == "Vector3") then
		return false
	end

	local startedAt = os.clock()
	local stableFrames = 0
	local tailMode = precisionMode == "tail"
	local timeout = tailMode and TAIL_ARRIVAL_TIMEOUT or (precisionMode and PRECISION_ARRIVAL_TIMEOUT or ARRIVAL_TIMEOUT)
	local tolerance = precisionMode and PRECISION_ARRIVAL_TOLERANCE or ARRIVAL_TOLERANCE
	local requiredFrames = tailMode and TAIL_STABLE_FRAMES or (precisionMode and PRECISION_STABLE_FRAMES or ARRIVAL_STABLE_FRAMES)

	while os.clock() - startedAt <= timeout do
		if isAborted(options, lease, currentSessionToken) then
			return false
		end
		if not (hrp and hrp.Parent) then
			return false
		end

		clearVelocity(hrp)
		local distance = (hrp.Position - targetPosition).Magnitude
		if distance <= tolerance then
			stableFrames += 1
			if stableFrames >= requiredFrames then
				return true
			end
		else
			stableFrames = 0
			lease:moveTo(CFrame.new(targetPosition))
		end

		RunService.Heartbeat:Wait()
	end

	return (hrp.Position - targetPosition).Magnitude <= tolerance
end

local function collectItems(items, currentPos, collectRange, collectedEvent, attemptedGifts)
	local collected = 0
	for _, item in ipairs(items) do
		if item.rawObj
			and not item.rawObj.Destroyed
			and not item.rawObj.Collected
			and Distance.isWithinRange(item.pos, currentPos, collectRange)
		then
			collectGift(item.rawObj, collectedEvent)
			table.insert(attemptedGifts, item.rawObj)
			collected += 1
		end
	end
	return collected
end

local function getRejectedItems(items, currentPos, collectRange)
	local rejected = {}
	for _, item in ipairs(items) do
		if item.rawObj
			and not item.rawObj.Destroyed
			and not item.rawObj.Collected
			and not item.rawObj.ClientCollected
			and Distance.isWithinRange(item.pos, currentPos, collectRange)
		then
			table.insert(rejected, item)
		end
	end
	return rejected
end

local function runPrecisionCleanup(hrp, items, standingPosition, collectRange, collectedEvent, attemptedGifts, options, lease, currentSessionToken)
	if not (hrp and hrp.Parent and items and items[1]) then
		return 0, 0
	end

	local tailMode = options and options.TailMode == true
	local duration = tailMode and TAIL_CLEANUP_DURATION or PRECISION_CLEANUP_DURATION
	local maxPulses = tailMode and TAIL_CLEANUP_MAX_PULSES or PRECISION_CLEANUP_MAX_PULSES
	local deadline = os.clock() + duration
	local pulses = 0

	while pulses < maxPulses and os.clock() <= deadline do
		if isAborted(options, lease, currentSessionToken) then
			break
		end
		if not (hrp and hrp.Parent) then
			break
		end

		clearVelocity(hrp)
		if (hrp.Position - standingPosition).Magnitude > PRECISION_ARRIVAL_TOLERANCE then
			waitForArrival(hrp, standingPosition, tailMode and "tail" or true, lease, currentSessionToken, options)
		end

		local currentPos = hrp.Position
		local rejected = getRejectedItems(items, currentPos, collectRange)
		if #rejected == 0 then
			break
		end

		comboCount = 0
		collectItems(rejected, currentPos, collectRange, collectedEvent, attemptedGifts)
		pulses += 1
		RunService.Heartbeat:Wait()
		waitIfPositive(CLEANUP_PULSE_INTERVAL)
	end

	if not (hrp and hrp.Parent) then
		return 0, pulses
	end

	local remainingRejected = getRejectedItems(items, hrp.Position, collectRange)
	return #remainingRejected, pulses
end

function Collector.resetAdaptive(controller)
	adaptiveSuccessRate = 1
	adaptiveValidationWait = BASE_VALIDATION_WAIT
	failedAttempts = setmetatable({}, { __mode = "k" })
	if controller then
		controller.GiftFarmAdaptiveSuccessRate = adaptiveSuccessRate
		controller.GiftFarmAdaptiveValidationWait = adaptiveValidationWait
		controller.GiftFarmAdaptiveRejects = 0
		controller.GiftFarmAdaptiveRetries = 0
	end
end

function Collector.collectCluster(controller, hrp, cluster, range, options, lease, currentSessionToken)
	if not (hrp and hrp.Parent and cluster and cluster[1]) then
		return false
	end

	options = options or {}
	local tailMode = options.TailMode == true
	local precisionMode = tailMode or options.PrecisionMode == true or #cluster <= 2
	local targetPosition = options.TargetPosition or cluster.TargetPosition or cluster[1].pos
	local collectRange = options.SafeRange or cluster.SafeRange or range
	local standingPosition = Distance.getRootPosition(targetPosition)
	local collectedEvent = Context.getCollectedGiftEvent()
	local result = {
		Attempted = 0,
		Rejected = 0,
		Accepted = 0,
		Precision = precisionMode,
		CleanupPulses = 0,
	}

	local ok, err = pcall(function()
		if isAborted(options, lease, currentSessionToken) then
			return
		end

		if Context.isInRound() and not Context.waitForStreamedGround(standingPosition, 0.85) then
			result.Rejected = #cluster
			return
		end

		hrp.Anchored = false
		lease:placeFoothold(standingPosition)
		if not jumpToWaypoint(hrp, standingPosition, lease) then
			result.Rejected = #cluster
			return
		end
		if isAborted(options, lease, currentSessionToken) then
			return
		end
		clearVelocity(hrp)
		waitForArrival(hrp, standingPosition, tailMode and "tail" or precisionMode, lease, currentSessionToken, options)
		if isAborted(options, lease, currentSessionToken) then
			return
		end
		waitIfPositive(precisionMode and PRECISION_COLLECT_SETTLE or COLLECT_SETTLE)
		if isAborted(options, lease, currentSessionToken) then
			return
		end
		waitForReplicationSync(precisionMode)
		if isAborted(options, lease, currentSessionToken) then
			return
		end

		local currentPos = hrp.Position
		local attemptedGifts = {}
		local observedRejects = 0
		if precisionMode then
			comboCount = 0
		end

		collectItems(cluster, currentPos, collectRange, collectedEvent, attemptedGifts)
		if isAborted(options, lease, currentSessionToken) then
			return
		end
		task.wait(getValidationWait(controller, precisionMode))

		local retryPasses = precisionMode and MAX_PRECISION_RETRY_PASSES or MAX_RETRY_PASSES
		for _ = 1, retryPasses do
			if isAborted(options, lease, currentSessionToken) then
				return
			end
			currentPos = hrp.Position
			local rejected = getRejectedItems(cluster, currentPos, collectRange)
			if #rejected == 0 then
				break
			end

			observedRejects += #rejected
			comboCount = 0
			waitForArrival(hrp, standingPosition, tailMode and "tail" or true, lease, currentSessionToken, options)
			task.wait(RETRY_SETTLE)
			if isAborted(options, lease, currentSessionToken) then
				return
			end
			waitForReplicationSync(true)
			if isAborted(options, lease, currentSessionToken) then
				return
			end
			currentPos = hrp.Position
			collectItems(rejected, currentPos, collectRange, collectedEvent, attemptedGifts)
			task.wait(getValidationWait(controller, true))
		end

		if precisionMode and not isAborted(options, lease, currentSessionToken) then
			local cleanupRejects, cleanupPulses = runPrecisionCleanup(
				hrp,
				cluster,
				standingPosition,
				collectRange,
				collectedEvent,
				attemptedGifts,
				options,
				lease,
				currentSessionToken
			)
			observedRejects += cleanupRejects
			result.CleanupPulses = cleanupPulses
			if cleanupPulses > 0 then
				task.wait(getValidationWait(controller, true))
			end
		end

		updateAdaptiveTiming(controller, attemptedGifts, observedRejects)
		result.Attempted = #attemptedGifts
		result.Rejected = observedRejects
		for _, gift in ipairs(attemptedGifts) do
			if isGiftAccepted(gift) then
				result.Accepted += 1
			end
		end
	end)

	if not ok then
		error(err, 0)
	end

	return result
end

return Collector
