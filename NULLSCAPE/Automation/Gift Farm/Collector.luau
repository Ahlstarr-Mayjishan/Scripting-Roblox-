--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Distance = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Distance.luau")

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Collector = {}
local COLLECT_SETTLE = 0
local PRECISION_COLLECT_SETTLE = 0.035
local PRECISION_SYNC_MIN = 0.025
local PRECISION_SYNC_MAX = 0.08
local BASE_VALIDATION_WAIT = 0.045
local FAST_VALIDATION_MAX = 0.12
local PRECISION_VALIDATION_WAIT = 0.18
local PRECISION_VALIDATION_MAX = 0.26
local ARRIVAL_TOLERANCE = 3
local PRECISION_ARRIVAL_TOLERANCE = 1.25
local ARRIVAL_STABLE_FRAMES = 1
local PRECISION_STABLE_FRAMES = 2
local ARRIVAL_TIMEOUT = 0.22
local PRECISION_ARRIVAL_TIMEOUT = 0.35
local FOOTHOLD_SIZE = Vector3.new(18, 1, 18)
local FOOTHOLD_OFFSET = Vector3.new(0, -3.6, 0)
local MAX_RETRY_PASSES = 2
local RETRY_SETTLE = 0.04
local comboCount = 0
local lastCollectTick = 0
local foothold = nil
local footholdRemovalToken = 0
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

local function getHumanoid(hrp)
	local character = hrp and hrp.Parent
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function releaseHumanoidState(hrp)
	local humanoid = getHumanoid(hrp)
	if not humanoid then
		return
	end

	pcall(function()
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)
end

local function hasGroundBelow(hrp)
	if not (hrp and hrp.Parent) then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { hrp.Parent, foothold }

	local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0), params)
	return result ~= nil
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
	if not precisionMode then
		return
	end

	local ping = getPingSeconds()
	local waitTime = math.clamp((ping or PRECISION_SYNC_MIN) * 0.5, PRECISION_SYNC_MIN, PRECISION_SYNC_MAX)
	RunService.RenderStepped:Wait()
	waitIfPositive(waitTime)
end

local function getValidationWait(controller, precisionMode)
	if precisionMode then
		return math.clamp(math.max(PRECISION_VALIDATION_WAIT, adaptiveValidationWait), PRECISION_VALIDATION_WAIT, PRECISION_VALIDATION_MAX)
	end
	if isAdaptiveEnabled(controller) then
		return math.clamp(adaptiveValidationWait, 0.035, FAST_VALIDATION_MAX)
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
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.04, BASE_VALIDATION_WAIT, PRECISION_VALIDATION_MAX)
	elseif ratio < 0.65 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.03, BASE_VALIDATION_WAIT, PRECISION_VALIDATION_MAX)
	elseif ratio < 0.9 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait + 0.015, BASE_VALIDATION_WAIT, PRECISION_VALIDATION_MAX)
	elseif adaptiveSuccessRate > 0.96 then
		adaptiveValidationWait = math.clamp(adaptiveValidationWait - 0.02, 0.035, PRECISION_VALIDATION_MAX)
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
	footholdRemovalToken += 1
	local part = getFoothold()
	part.CFrame = CFrame.new(position + FOOTHOLD_OFFSET)
	return part
end

local function removeFoothold(delaySeconds)
	local delayTime = tonumber(delaySeconds) or 0
	if delayTime > 0 and foothold and foothold.Parent then
		local token = footholdRemovalToken + 1
		footholdRemovalToken = token
		local part = foothold
		task.delay(delayTime, function()
			if footholdRemovalToken ~= token or foothold ~= part then
				return
			end
			if part and part.Parent then
				pcall(function()
					part:Destroy()
				end)
			end
			if foothold == part then
				foothold = nil
			end
		end)
		return
	end

	if foothold then
		footholdRemovalToken += 1
		pcall(function()
			foothold:Destroy()
		end)
		foothold = nil
	end
end

local function waitForArrival(hrp, targetPosition, precisionMode)
	if not (hrp and hrp.Parent and typeof(targetPosition) == "Vector3") then
		return false
	end

	local startedAt = os.clock()
	local stableFrames = 0
	local timeout = precisionMode and PRECISION_ARRIVAL_TIMEOUT or ARRIVAL_TIMEOUT
	local tolerance = precisionMode and PRECISION_ARRIVAL_TOLERANCE or ARRIVAL_TOLERANCE
	local requiredFrames = precisionMode and PRECISION_STABLE_FRAMES or ARRIVAL_STABLE_FRAMES

	while os.clock() - startedAt <= timeout do
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
			Context.moveCharacterTo(CFrame.new(targetPosition))
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
			and failedAttempts[item.rawObj] ~= nil
			and not item.rawObj.Destroyed
			and not item.rawObj.Collected
			and Distance.isWithinRange(item.pos, currentPos, collectRange)
		then
			table.insert(rejected, item)
		end
	end
	return rejected
end

function Collector.releaseCharacter(options)
	options = options or {}
	local hrp = Context.getRootPart()
	local shouldKeepFoothold = options.KeepFootholdDuration
		and hrp
		and hrp.Parent
		and (not options.OnlyKeepFootholdIfAirborne or not hasGroundBelow(hrp))
	if shouldKeepFoothold and (not foothold or not foothold.Parent) then
		placeFoothold(hrp.Position)
	end

	removeFoothold(shouldKeepFoothold and options.KeepFootholdDuration or nil)
	if hrp and hrp.Parent then
		hrp.Anchored = false
		releaseHumanoidState(hrp)
		if options.SkipVelocityClear ~= true then
			clearVelocity(hrp)
		end
	end
end

function Collector.restoreMovement(options)
	Collector.releaseCharacter(options)
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
	local precisionMode = options.PrecisionMode == true or #cluster <= 2
	local targetPosition = options.TargetPosition or cluster.TargetPosition or cluster[1].pos
	local collectRange = options.SafeRange or cluster.SafeRange or range
	local standingPosition = Distance.getRootPosition(targetPosition)
	local collectedEvent = Context.getCollectedGiftEvent()
	local result = {
		Attempted = 0,
		Rejected = 0,
		Accepted = 0,
		Precision = precisionMode,
	}

	local ok, err = pcall(function()
		hrp.Anchored = false
		placeFoothold(standingPosition)
		jumpToWaypoint(hrp, standingPosition)
		clearVelocity(hrp)
		waitForArrival(hrp, standingPosition, precisionMode)
		waitIfPositive(precisionMode and PRECISION_COLLECT_SETTLE or COLLECT_SETTLE)
		waitForReplicationSync(precisionMode)

		local currentPos = hrp.Position
		local attemptedGifts = {}
		local observedRejects = 0
		if precisionMode then
			comboCount = 0
		end

		collectItems(cluster, currentPos, collectRange, collectedEvent, attemptedGifts)
		task.wait(getValidationWait(controller, precisionMode))

		for _ = 1, MAX_RETRY_PASSES do
			currentPos = hrp.Position
			local rejected = getRejectedItems(cluster, currentPos, collectRange)
			if #rejected == 0 then
				break
			end

			observedRejects += #rejected
			comboCount = 0
			waitForArrival(hrp, standingPosition, true)
			task.wait(RETRY_SETTLE)
			currentPos = hrp.Position
			collectItems(rejected, currentPos, collectRange, collectedEvent, attemptedGifts)
			task.wait(getValidationWait(controller, true))
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

	Collector.restoreMovement()
	if not ok then
		error(err, 0)
	end

	return result
end

return Collector
