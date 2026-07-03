--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local RunService = game:GetService("RunService")

local Collector = {}
local COLLECT_SETTLE = 0.02
local BASE_VALIDATION_WAIT = 0.08
local ARRIVAL_TOLERANCE = 3
local ARRIVAL_STABLE_FRAMES = 2
local ARRIVAL_TIMEOUT = 0.35
local FOOTHOLD_SIZE = Vector3.new(18, 1, 18)
local FOOTHOLD_OFFSET = Vector3.new(0, -3.6, 0)
local MAX_RETRY_PASSES = 2
local RETRY_SETTLE = 0.06
local comboCount = 0
local lastCollectTick = 0
local foothold = nil
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

local function isAdaptiveEnabled(controller)
	return not (controller and controller.GiftFarmAdaptiveTiming == false)
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

local function getValidationWait(controller)
	if isAdaptiveEnabled(controller) then
		return math.clamp(adaptiveValidationWait, 0.04, 0.45)
	end
	return BASE_VALIDATION_WAIT
end

local function updateAdaptiveTiming(controller, attemptedGifts, observedRejects)
	if not isAdaptiveEnabled(controller) or not attemptedGifts or #attemptedGifts == 0 then
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
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.08, BASE_VALIDATION_WAIT, 0.45)
	elseif ratio < 0.65 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.06, BASE_VALIDATION_WAIT, 0.45)
	elseif ratio < 0.9 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.025, BASE_VALIDATION_WAIT, 0.45)
	elseif adaptiveSuccessRate > 0.96 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait - 0.01, 0.04, 0.45)
	end

	if controller then
		controller.GiftFarmAdaptiveSuccessRate = adaptiveSuccessRate
		controller.GiftFarmAdaptiveValidationWait = adaptiveValidationWait
		controller.GiftFarmAdaptiveRejects = failed
		controller.GiftFarmAdaptiveRetries = failed
	end
end

local function jumpToWaypoint(hrp, targetPosition)
	if not (hrp and hrp.Parent) then
		return false
	end

	Context.moveCharacterTo(CFrame.new(targetPosition))
	clearVelocity(hrp)
	RunService.Heartbeat:Wait()
	return true
end

local function getFoothold()
	if foothold and foothold.Parent then
		return foothold
	end

	foothold = Instance.new("Part")
	foothold.Name = "NULLSCAPE_GiftFarmFoothold"
	foothold.Anchored = true
	foothold.CanCollide = true
	foothold.CanTouch = false
	foothold.CanQuery = false
	foothold.CastShadow = false
	foothold.Material = Enum.Material.SmoothPlastic
	foothold.Transparency = 1
	foothold.Size = FOOTHOLD_SIZE
	foothold.Parent = workspace
	return foothold
end

local function placeFoothold(position)
	local part = getFoothold()
	part.CFrame = CFrame.new(position + FOOTHOLD_OFFSET)
	return part
end

local function removeFoothold()
	if foothold then
		pcall(function()
			foothold:Destroy()
		end)
		foothold = nil
	end
end

local function waitForArrival(hrp, targetPosition)
	if not (hrp and hrp.Parent and typeof(targetPosition) == "Vector3") then
		return false
	end

	local startedAt = os.clock()
	local stableFrames = 0
	while os.clock() - startedAt <= ARRIVAL_TIMEOUT do
		if not (hrp and hrp.Parent) then
			return false
		end

		clearVelocity(hrp)
		local distance = (hrp.Position - targetPosition).Magnitude
		if distance <= ARRIVAL_TOLERANCE then
			stableFrames += 1
			if stableFrames >= ARRIVAL_STABLE_FRAMES then
				return true
			end
		else
			stableFrames = 0
			Context.moveCharacterTo(CFrame.new(targetPosition))
		end

		RunService.Heartbeat:Wait()
	end

	return (hrp.Position - targetPosition).Magnitude <= ARRIVAL_TOLERANCE
end

local function collectItems(items, currentPos, collectRange, collectedEvent, attemptedGifts)
	local collected = 0
	for _, item in ipairs(items) do
		if item.rawObj
			and not item.rawObj.Destroyed
			and not item.rawObj.Collected
			and (item.pos - currentPos).Magnitude <= collectRange + 1
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
			and failedAttempts[item.rawObj] ~= nil
			and not item.rawObj.Destroyed
			and not item.rawObj.Collected
			and (item.pos - currentPos).Magnitude <= collectRange + 1
		then
			table.insert(rejected, item)
		end
	end
	return rejected
end

function Collector.releaseCharacter()
	removeFoothold()
	local hrp = Context.getRootPart()
	if hrp and hrp.Parent then
		hrp.Anchored = false
		clearVelocity(hrp)
	end
end

function Collector.restoreMovement()
	Collector.releaseCharacter()
	return true
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

function Collector.collectCluster(controller, hrp, cluster, range, options)
	if not (hrp and hrp.Parent and cluster and cluster[1]) then
		return false
	end

	options = options or {}
	local targetPosition = options.TargetPosition or cluster.TargetPosition or cluster[1].pos
	local collectRange = options.SafeRange or cluster.SafeRange or range
	local standingPosition = targetPosition + Vector3.new(0, 3, 0)
	local collectedEvent = Context.getCollectedGiftEvent()

	local ok, err = pcall(function()
		hrp.Anchored = false
		placeFoothold(standingPosition)
		jumpToWaypoint(hrp, standingPosition)
		clearVelocity(hrp)
		waitForArrival(hrp, standingPosition)
		task.wait(COLLECT_SETTLE)

		local currentPos = hrp.Position
		local attemptedGifts = {}
		local observedRejects = 0

		collectItems(cluster, currentPos, collectRange, collectedEvent, attemptedGifts)
		task.wait(getValidationWait(controller))

		for _ = 1, MAX_RETRY_PASSES do
			currentPos = hrp.Position
			local rejected = getRejectedItems(cluster, currentPos, collectRange)
			if #rejected == 0 then
				break
			end

			observedRejects += #rejected
			waitForArrival(hrp, standingPosition)
			task.wait(RETRY_SETTLE)
			currentPos = hrp.Position
			collectItems(rejected, currentPos, collectRange, collectedEvent, attemptedGifts)
			task.wait(getValidationWait(controller))
		end

		updateAdaptiveTiming(controller, attemptedGifts, observedRejects)
	end)

	Collector.restoreMovement()
	if not ok then
		error(err, 0)
	end

	return true
end

return Collector
