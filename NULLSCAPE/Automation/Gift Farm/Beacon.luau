--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local RunService = game:GetService("RunService")

local Beacon = {}
local SUPPRESS_REFRESH_INTERVAL = 0.25
local RETURN_ATTEMPTS = 8
local RETURN_SETTLE_FRAMES = 2
local RETURN_HOLD_FRAMES = 4
local RETURN_DISTANCE = 8
local RETURN_OPEN_DURATION = 5
local RETURN_APPROACH_DISTANCE = 10
local RETURN_TOUCH_PULSES = 3
local WAIT_MIN_HORIZONTAL_DISTANCE = 36
local WAIT_EDGE_CLEARANCE = 12
local WAIT_HEIGHT = 4

local returnDone = false
local suppressed = false
local lastSuppressAt = 0
local returnOpenUntil = 0

function Beacon.reset(inRound)
	returnDone = false
	returnOpenUntil = 0
	lastSuppressAt = 0
	if not inRound and suppressed then
		Context.restoreBeaconInteraction()
		suppressed = false
	end
end

function Beacon.suppressUntilReturn()
	if os.clock() < returnOpenUntil then
		Beacon.restore(true)
		return false
	end

	if returnDone then
		Beacon.restore(true)
		return false
	end

	local contextSuppressed = typeof(Context.isBeaconInteractionSuppressed) == "function"
		and Context.isBeaconInteractionSuppressed()
	local now = os.clock()
	if (suppressed or contextSuppressed) and now - lastSuppressAt < SUPPRESS_REFRESH_INTERVAL then
		suppressed = true
		return true
	end

	lastSuppressAt = now
	suppressed = Context.suppressBeaconInteraction() == true or suppressed or contextSuppressed
	return suppressed
end

function Beacon.restore(force)
	local contextSuppressed = typeof(Context.isBeaconInteractionSuppressed) == "function"
		and Context.isBeaconInteractionSuppressed()
	if force == true then
		local forced = false
		if typeof(Context.forceBeaconInteraction) == "function" then
			forced = Context.forceBeaconInteraction() == true
		else
			forced = Context.restoreBeaconInteraction() == true
		end
		suppressed = false
		lastSuppressAt = 0
		return forced or contextSuppressed or suppressed
	end
	if not suppressed and not contextSuppressed then
		return false
	end

	Context.restoreBeaconInteraction()
	suppressed = false
	lastSuppressAt = 0
	return true
end

local function clearMotion(hrp)
	if not (hrp and hrp.Parent) then
		return
	end

	Context.releaseCharacterControl({
		State = Enum.HumanoidStateType.Freefall,
	})
end

local function waitFrames(frames)
	for _ = 1, frames do
		RunService.Heartbeat:Wait()
	end
end

local function forceReturnOpen()
	returnOpenUntil = os.clock() + RETURN_OPEN_DURATION
	return Beacon.restore(true)
end

local function getFlatDirection(beacon, hrp)
	local beaconPos = beacon.Position
	local rootPos = hrp and hrp.Position or beaconPos
	local offset = rootPos - beaconPos
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 0.1 then
		local look = beacon.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(1, 0, 0)
		end
	end
	return flat.Unit
end

local function getReturnCFrames(beacon, hrp)
	local beaconPos = beacon.Position
	local direction = getFlatDirection(beacon, hrp)
	local approach = beaconPos + direction * RETURN_APPROACH_DISTANCE + Vector3.new(0, 4, 0)
	local target = beaconPos + Vector3.new(0, 4, 0)
	return CFrame.new(approach), CFrame.new(target)
end

local function getWaitCFrame(beacon, hrp)
	local halfWidth = math.max(beacon.Size.X, beacon.Size.Z) * 0.5
	local safeDistance = math.max(WAIT_MIN_HORIZONTAL_DISTANCE, halfWidth + WAIT_EDGE_CLEARANCE)
	local target = beacon.Position
		+ getFlatDirection(beacon, hrp) * safeDistance
		+ Vector3.new(0, WAIT_HEIGHT, 0)
	return CFrame.new(target)
end

function Beacon.stageForWait(hrp, lease)
	local beacon = Context.getBeaconPart()
	if not (beacon and hrp and hrp.Parent) then
		return false
	end

	Beacon.suppressUntilReturn()
	local waitCFrame = getWaitCFrame(beacon, hrp)
	Context.waitForStreamedGround(waitCFrame.Position, 0.25)
	if lease then
		return lease:moveTo(waitCFrame)
	end
	return Context.moveCharacterTo(waitCFrame)
end

local function pulseBeaconTouch(beacon, hrp)
	if not (beacon and beacon.Parent and hrp and hrp.Parent) then
		return false
	end

	if typeof(firetouchinterest) ~= "function" then
		return false
	end

	for _ = 1, RETURN_TOUCH_PULSES do
		forceReturnOpen()
		pcall(function()
			firetouchinterest(hrp, beacon, 0)
		end)
		RunService.Heartbeat:Wait()
		pcall(function()
			firetouchinterest(hrp, beacon, 1)
		end)
		RunService.Heartbeat:Wait()
	end

	return true
end

function Beacon.returnToBeacon(controller, hrp, setStatus, reason, lease, _currentSessionToken, forceReturn)
	if controller.GiftFarmReturnToBeaconAfterGolden == false and forceReturn ~= true then
		return false
	end

	local beacon = Context.getBeaconPart()
	if not (beacon and hrp and hrp.Parent) then
		return false
	end

	returnDone = false
	forceReturnOpen()
	if typeof(setStatus) == "function" then
		setStatus(controller, "ReturningToBeacon", reason or "Golden gifts complete")
	end

	for _ = 1, RETURN_SETTLE_FRAMES do
		if lease and not lease:isValid() then
			return false
		end
		forceReturnOpen()
		RunService.Heartbeat:Wait()
	end

	local arrived = false
	for _ = 1, RETURN_ATTEMPTS do
		if lease and not lease:isValid() then
			return false
		end
		hrp = Context.getRootPart() or hrp
		if not (hrp and hrp.Parent and beacon and beacon.Parent) then
			break
		end

		local approach, target = getReturnCFrames(beacon, hrp)
		forceReturnOpen()
		clearMotion(hrp)
		if lease then
			lease:moveTo(approach)
		else
			Context.moveCharacterTo(approach)
		end

		if lease and not lease:isValid() then
			return false
		end
		waitFrames(1)

		if lease and not lease:isValid() then
			return false
		end
		forceReturnOpen()
		clearMotion(hrp)
		if lease then
			lease:moveTo(target)
		else
			Context.moveCharacterTo(target)
		end
		pulseBeaconTouch(beacon, hrp)

		if lease and not lease:isValid() then
			if not (hrp and hrp.Parent) or Context.getRootPart() ~= hrp then
				return true
			end
			return false
		end
		waitFrames(1)

		if (hrp.Position - beacon.Position).Magnitude <= RETURN_DISTANCE then
			arrived = true
			break
		end
	end

	if not arrived then
		return false
	end

	returnDone = true
	forceReturnOpen()
	for _ = 1, RETURN_HOLD_FRAMES do
		if lease and not lease:isValid() then
			return true
		end
		if not (hrp and hrp.Parent) then
			break
		end
		forceReturnOpen()
		clearMotion(hrp)
		pulseBeaconTouch(beacon, hrp)
		local _, target = getReturnCFrames(beacon, hrp)
		if lease then
			lease:moveTo(target)
		else
			Context.moveCharacterTo(target)
		end
		RunService.Heartbeat:Wait()
	end

	return true
end

return Beacon
