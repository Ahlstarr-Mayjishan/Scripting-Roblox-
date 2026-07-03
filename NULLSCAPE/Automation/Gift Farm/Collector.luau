--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local RunService = game:GetService("RunService")

local Collector = {}
local BASE_COLLECTS_PER_FRAME = 12
local COLLECT_SETTLE = 0.03
local BASE_VALIDATION_WAIT = 0.16
local comboCount = 0
local lastCollectTick = 0
local activeRestore = nil
local adaptiveLoadScale = 1
local adaptiveSuccessRate = 1
local adaptiveValidationWait = BASE_VALIDATION_WAIT

local function collectGift(gift, collectedEvent)
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
	return not gift or gift.Destroyed == true or gift.Collected == true or gift.ClientCollected == true
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

local function getCollectsPerFrame(controller)
	if isAdaptiveEnabled(controller) then
		return math.clamp(math.floor(BASE_COLLECTS_PER_FRAME * adaptiveLoadScale), 4, 24)
	end
	return BASE_COLLECTS_PER_FRAME
end

local function getValidationWait(controller)
	if isAdaptiveEnabled(controller) then
		return math.clamp(adaptiveValidationWait, 0.08, 0.55)
	end
	return BASE_VALIDATION_WAIT
end

local function updateAdaptiveTiming(controller, attemptedGifts)
	if not isAdaptiveEnabled(controller) or not attemptedGifts or #attemptedGifts == 0 then
		return
	end

	local accepted = 0
	for _, gift in ipairs(attemptedGifts) do
		if isGiftAccepted(gift) then
			accepted += 1
		end
	end

	local ratio = accepted / #attemptedGifts
	adaptiveSuccessRate = adaptiveSuccessRate * 0.7 + ratio * 0.3

	if ratio < 0.65 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.06, BASE_VALIDATION_WAIT, 0.55)
		adaptiveLoadScale = math.clamp(adaptiveLoadScale - 0.12, 0.45, 1)
	elseif ratio < 0.9 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.025, BASE_VALIDATION_WAIT, 0.55)
		adaptiveLoadScale = math.clamp(adaptiveLoadScale - 0.04, 0.45, 1)
	elseif adaptiveSuccessRate > 0.96 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait - 0.01, 0.08, 0.55)
		adaptiveLoadScale = math.clamp(adaptiveLoadScale + 0.03, 0.45, 1)
	end

	if controller then
		controller.GiftFarmAdaptiveSuccessRate = adaptiveSuccessRate
		controller.GiftFarmAdaptiveLoadScale = adaptiveLoadScale
		controller.GiftFarmAdaptiveSpeedScale = adaptiveLoadScale
		controller.GiftFarmAdaptiveValidationWait = adaptiveValidationWait
	end
end

local function freeTeleport(hrp, targetCFrame)
	if not (hrp and hrp.Parent) then
		return false
	end

	Context.moveCharacterTo(targetCFrame)
	RunService.Heartbeat:Wait()
	return true
end

function Collector.releaseCharacter()
	local hrp = Context.getRootPart()
	if hrp and hrp.Parent then
		hrp.Anchored = false
		clearVelocity(hrp)
	end
end

function Collector.restoreMovement()
	local restore = activeRestore
	activeRestore = nil

	if restore and restore.Hrp and restore.Hrp.Parent then
		local hrp = restore.Hrp
		if restore.ReturnAfter ~= false and restore.CFrame then
			Context.moveCharacterTo(restore.CFrame)
		end
		hrp.Anchored = false
		clearVelocity(hrp)
		return true
	end

	Collector.releaseCharacter()
	return false
end

function Collector.resetAdaptive(controller)
	adaptiveLoadScale = 1
	adaptiveSuccessRate = 1
	adaptiveValidationWait = BASE_VALIDATION_WAIT
	if controller then
		controller.GiftFarmAdaptiveSuccessRate = adaptiveSuccessRate
		controller.GiftFarmAdaptiveLoadScale = adaptiveLoadScale
		controller.GiftFarmAdaptiveSpeedScale = adaptiveLoadScale
		controller.GiftFarmAdaptiveValidationWait = adaptiveValidationWait
	end
end

function Collector.collectCluster(controller, hrp, cluster, range, options)
	if not (hrp and hrp.Parent and cluster and cluster[1]) then
		return false
	end

	options = options or {}
	local oldCFrame = hrp.CFrame
	local targetPosition = options.TargetPosition or cluster.TargetPosition or cluster[1].pos
	local collectRange = options.SafeRange or cluster.SafeRange or range
	local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
	local collectedEvent = Context.getCollectedGiftEvent()
	local returnAfter = options.KeepPosition ~= true

	activeRestore = {
		Hrp = hrp,
		CFrame = oldCFrame,
		ReturnAfter = returnAfter,
	}

	local ok, err = pcall(function()
		hrp.Anchored = false
		freeTeleport(hrp, targetCFrame)
		clearVelocity(hrp)
		RunService.Heartbeat:Wait()
		task.wait(COLLECT_SETTLE)

		local currentPos = hrp.Position
		local perFrame = getCollectsPerFrame(controller)
		local collectedThisFrame = 0
		local attemptedGifts = {}

		for _, item in ipairs(cluster) do
			if item.rawObj
				and not item.rawObj.Destroyed
				and not item.rawObj.Collected
				and (item.pos - currentPos).Magnitude <= collectRange + 1
			then
				collectGift(item.rawObj, collectedEvent)
				table.insert(attemptedGifts, item.rawObj)
				collectedThisFrame += 1
				if collectedThisFrame >= perFrame then
					collectedThisFrame = 0
					RunService.Heartbeat:Wait()
					if not (hrp and hrp.Parent) then
						break
					end
					currentPos = hrp.Position
				end
			end
		end

		task.wait(getValidationWait(controller))
		updateAdaptiveTiming(controller, attemptedGifts)
	end)

	Collector.restoreMovement()
	if not ok then
		error(err, 0)
	end

	return true
end

return Collector
