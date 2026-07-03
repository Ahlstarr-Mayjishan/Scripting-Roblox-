--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local RunService = game:GetService("RunService")

local Collector = {}
local MAX_STEP_DISTANCE = 160
local comboCount = 0
local lastCollectTick = 0
local activeRestore = nil
local adaptiveSettle = nil
local adaptiveSpeedScale = 1
local adaptiveSuccessRate = 1

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

local function getTravelSpeed(controller)
	local baseSpeed = math.clamp(tonumber(controller.GiftFarmTravelSpeed) or 750, 150, 2000)
	if isAdaptiveEnabled(controller) then
		return math.clamp(baseSpeed * adaptiveSpeedScale, 150, 2000)
	end
	return baseSpeed
end

local function getCollectSettle(controller)
	local baseSettle = math.clamp(tonumber(controller.GiftFarmCollectSettle) or 0.18, 0.03, 0.6)
	if not isAdaptiveEnabled(controller) then
		return baseSettle
	end

	adaptiveSettle = math.clamp(adaptiveSettle or baseSettle, 0.03, 0.8)
	return math.max(baseSettle, adaptiveSettle)
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
	local baseSettle = math.clamp(tonumber(controller.GiftFarmCollectSettle) or 0.18, 0.03, 0.6)
	adaptiveSettle = adaptiveSettle or baseSettle

	if ratio < 0.65 then
		adaptiveSettle = math.clamp(adaptiveSettle + 0.06, baseSettle, 0.8)
		adaptiveSpeedScale = math.clamp(adaptiveSpeedScale - 0.12, 0.45, 1)
	elseif ratio < 0.9 then
		adaptiveSettle = math.clamp(adaptiveSettle + 0.025, baseSettle, 0.8)
		adaptiveSpeedScale = math.clamp(adaptiveSpeedScale - 0.04, 0.45, 1)
	elseif adaptiveSuccessRate > 0.96 then
		adaptiveSettle = math.clamp(adaptiveSettle - 0.01, baseSettle, 0.8)
		adaptiveSpeedScale = math.clamp(adaptiveSpeedScale + 0.03, 0.45, 1)
	end

	if controller then
		controller.GiftFarmAdaptiveSuccessRate = adaptiveSuccessRate
		controller.GiftFarmAdaptiveSettle = adaptiveSettle
		controller.GiftFarmAdaptiveSpeedScale = adaptiveSpeedScale
	end
end

local function pacedMove(controller, hrp, targetCFrame)
	if not (hrp and hrp.Parent) then
		return false
	end

	local startPosition = hrp.Position
	local targetPosition = targetCFrame.Position
	local delta = targetPosition - startPosition
	local distance = delta.Magnitude
	if distance <= 1 then
		Context.moveCharacterTo(targetCFrame)
		RunService.Heartbeat:Wait()
		return true
	end

	local travelSpeed = getTravelSpeed(controller)
	local steps = math.max(1, math.ceil(distance / MAX_STEP_DISTANCE))
	local totalTime = math.clamp(distance / travelSpeed, 0.08, 1.25)
	local stepWait = math.clamp(totalTime / steps, 0.03, 0.2)

	for step = 1, steps do
		if not (hrp and hrp.Parent) then
			return false
		end

		local alpha = step / steps
		local position = startPosition:Lerp(targetPosition, alpha)
		local cframe = targetCFrame - targetCFrame.Position + position
		Context.moveCharacterTo(cframe)
		task.wait(stepWait)
	end

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

function Collector.collectCluster(controller, hrp, cluster, range, options)
	if not (hrp and hrp.Parent and cluster and cluster[1]) then
		return false
	end

	options = options or {}
	local oldCFrame = hrp.CFrame
	local targetCFrame = CFrame.new(cluster[1].pos + Vector3.new(0, 3, 0))
	local collectedEvent = Context.getCollectedGiftEvent()
	local returnAfter = controller.GiftFarmReturnAfterCluster ~= false and options.KeepPosition ~= true

	activeRestore = {
		Hrp = hrp,
		CFrame = oldCFrame,
		ReturnAfter = returnAfter,
	}

	local ok, err = pcall(function()
		hrp.Anchored = false
		pacedMove(controller, hrp, targetCFrame)
		clearVelocity(hrp)
		RunService.Heartbeat:Wait()
		task.wait(getCollectSettle(controller))

		local currentPos = hrp.Position
		local perFrame = math.clamp(tonumber(controller.GiftFarmCollectsPerFrame) or 8, 1, 60)
		local collectedThisFrame = 0
		local attemptedGifts = {}

		for _, item in ipairs(cluster) do
			if item.rawObj
				and not item.rawObj.Destroyed
				and not item.rawObj.Collected
				and (item.pos - currentPos).Magnitude <= range + 1
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

		task.wait(getCollectSettle(controller))
		updateAdaptiveTiming(controller, attemptedGifts)
	end)

	Collector.restoreMovement()
	if not ok then
		error(err, 0)
	end

	return true
end

return Collector
