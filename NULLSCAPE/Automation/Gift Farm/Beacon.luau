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
	suppressed = Context.suppressBeaconInteraction() == true
		or suppressed
		or contextSuppressed
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

function Beacon.returnToBeacon(controller, hrp, setStatus, reason)
	if controller.GiftFarmReturnToBeaconAfterGolden == false then
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
		forceReturnOpen()
		RunService.Heartbeat:Wait()
	end

	local target = CFrame.new(beacon.Position + Vector3.new(0, 4, 0))
	local arrived = false
	for _ = 1, RETURN_ATTEMPTS do
		hrp = Context.getRootPart() or hrp
		if not (hrp and hrp.Parent and beacon and beacon.Parent) then
			break
		end

		forceReturnOpen()
		clearMotion(hrp)
		Context.moveCharacterTo(target)
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
		if not (hrp and hrp.Parent) then
			break
		end
		forceReturnOpen()
		clearMotion(hrp)
		Context.moveCharacterTo(target)
		RunService.Heartbeat:Wait()
	end

	return true
end

return Beacon
