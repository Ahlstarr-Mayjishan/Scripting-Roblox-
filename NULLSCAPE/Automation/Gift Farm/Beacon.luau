--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local RunService = game:GetService("RunService")

local Beacon = {}
local SUPPRESS_REFRESH_INTERVAL = 0.25
local RETURN_ATTEMPTS = 8
local RETURN_SETTLE_FRAMES = 2
local RETURN_HOLD_FRAMES = 4
local RETURN_DISTANCE = 8

local returnDone = false
local suppressed = false
local lastSuppressAt = 0

function Beacon.reset(inRound)
	returnDone = false
	lastSuppressAt = 0
	if not inRound and suppressed then
		Context.restoreBeaconInteraction()
		suppressed = false
	end
end

function Beacon.suppressUntilReturn()
	if returnDone then
		Beacon.restore()
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

function Beacon.restore()
	local contextSuppressed = typeof(Context.isBeaconInteractionSuppressed) == "function"
		and Context.isBeaconInteractionSuppressed()
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

	pcall(function()
		hrp.Anchored = false
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)

	local humanoid = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.PlatformStand = false
			humanoid.Sit = false
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end)
	end
end

local function waitFrames(frames)
	for _ = 1, frames do
		RunService.Heartbeat:Wait()
	end
end

function Beacon.returnToBeacon(controller, hrp, setStatus, reason)
	if returnDone or controller.GiftFarmReturnToBeaconAfterGolden == false then
		return false
	end
	if not Context.isBeaconActive() then
		return false
	end

	local beacon = Context.getBeaconPart()
	if not (beacon and hrp and hrp.Parent) then
		return false
	end

	Beacon.restore()
	if typeof(setStatus) == "function" then
		setStatus(controller, "ReturningToBeacon", reason or "Golden gifts complete")
	end

	waitFrames(RETURN_SETTLE_FRAMES)

	local target = CFrame.new(beacon.Position + Vector3.new(0, 4, 0))
	local arrived = false
	for _ = 1, RETURN_ATTEMPTS do
		if not (hrp and hrp.Parent and beacon and beacon.Parent) then
			break
		end

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
	for _ = 1, RETURN_HOLD_FRAMES do
		if not (hrp and hrp.Parent) then
			break
		end
		clearMotion(hrp)
		Context.moveCharacterTo(target)
		RunService.Heartbeat:Wait()
	end

	return true
end

return Beacon
