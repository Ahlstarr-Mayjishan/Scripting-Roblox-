--!nocheck
-- [[
--  NULLSCAPE - Grapple Air Control Adjustment
-- ]]

local Workspace = game:GetService("Workspace")

local AirControl = {}


local CachedControl = nil

local function getControl()
	if CachedControl then
		return CachedControl
	end
	CachedControl = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	return CachedControl
end
local function hasUpgrade(movement, upgradeName)
	if not (movement and typeof(movement.HasUpgrade) == "function") then
		return false
	end
	local success, result = pcall(function()
		return movement:HasUpgrade(upgradeName)
	end)
	return success and result == true
end

local function hasMovementFlag(movement, flagName)
	if not movement then
		return false
	end

	local value = movement[flagName]
	return value == true or (typeof(value) == "number" and value > 0)
end

local function characterHas(grapple, name)
	local rootPart = grapple and grapple.RootPart
	local character = rootPart and rootPart.Parent
	return character and character:FindFirstChild(name) ~= nil
end

local function getPhysicsProfile(grapple)
	local movement = grapple and grapple.Movement
	local graceWings = hasUpgrade(movement, "GraceWings")
	local lowGravity = hasUpgrade(movement, "AdvancedGravityCoil")
		or characterHas(grapple, "HighriseLowGravity")
		or characterHas(grapple, "Highrise")
		or hasMovementFlag(movement, "HighriseLowGravity")

	local airControlScale = 1
	if graceWings then
		airControlScale += 0.35
	end
	if lowGravity then
		airControlScale += 0.2
	end

	return {
		AirControlScale = airControlScale,
		LowGravity = lowGravity,
	}
end

local function applyVelocityDelta(rootPart, delta, maxDelta)
	if not (rootPart and typeof(delta) == "Vector3") then
		return false
	end
	if delta.Magnitude > maxDelta then
		delta = delta.Unit * maxDelta
	end
	if delta.Magnitude <= 0.001 then
		return false
	end

	rootPart.Velocity += delta
	return true
end

function AirControl.apply(grapple, dt)
	local Control = getControl()
	local controlLevel = Control and Control.GrappleAirControlMultiplier or 0
	if controlLevel <= 0 then
		return
	end

	local movement = grapple and grapple.Movement
	local rootPart = grapple and grapple.RootPart
	if not (movement and rootPart and movement.grappling and not grapple.jumpPadReel) then
		return
	end

	local playerMoveDirection = movement.PlayerMoveDirection
	if typeof(playerMoveDirection) ~= "Vector3" or playerMoveDirection.Magnitude <= 0.01 then
		return
	end

	local dtClamped = math.clamp(tonumber(dt) or 0, 0, 1 / 20)
	if dtClamped <= 0 then
		return
	end

	local levelAlpha = math.clamp(controlLevel / 10, 0, 1)
	local velocity = rootPart.Velocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local profile = getPhysicsProfile(grapple)
	local graceWingsMultiplier = hasUpgrade(movement, "GraceWings") and 1.5 or 1
	local profileAirScale = tonumber(profile and profile.AirControlScale) or 1
	local movementSpeedMultiplier = tonumber(movement.movementSpeedMulti) or 1

	local inputUnit = playerMoveDirection.Unit
	local alongInputSpeed = horizontalVelocity:Dot(inputUnit)
	local lateralVelocity = horizontalVelocity - inputUnit * alongInputSpeed
	local assistAcceleration = (28 + controlLevel * 22)
		* movementSpeedMultiplier
		* graceWingsMultiplier
		* profileAirScale
	local authority = levelAlpha ^ 1.35
	local maxControlSpeed = 62 + controlLevel * 13
	local desiredAlongSpeed =
		math.clamp(alongInputSpeed + assistAcceleration * dtClamped, -maxControlSpeed * 0.35, maxControlSpeed)
	local alongDelta =
		math.clamp(desiredAlongSpeed - alongInputSpeed, -assistAcceleration * dtClamped, assistAcceleration * dtClamped)
	local nextHorizontal = horizontalVelocity + inputUnit * alongDelta

	local lateralBrakeAlpha = math.clamp((0.025 + authority * 0.14) * dtClamped * 60, 0, 0.28)
	local lateralBrake = lateralVelocity * lateralBrakeAlpha
	local maxBrakeDelta = (12 + controlLevel * 7) * dtClamped
	if lateralBrake.Magnitude > maxBrakeDelta then
		lateralBrake = lateralBrake.Unit * maxBrakeDelta
	end
	nextHorizontal -= lateralBrake

	local maxHorizontalSpeed = 128 + controlLevel * 15
	if nextHorizontal.Magnitude > maxHorizontalSpeed then
		nextHorizontal = nextHorizontal.Unit * maxHorizontalSpeed
	end

	local gravityCancel = (math.clamp((controlLevel - 3) / 7, 0, 1) ^ 1.35) * 0.82
	if profile and profile.LowGravity then
		gravityCancel *= 0.65
	end
	local nextY = velocity.Y
	if gravityCancel > 0 then
		nextY += Workspace.Gravity * gravityCancel * dtClamped
	end

	local desiredVelocity = Vector3.new(nextHorizontal.X, nextY, nextHorizontal.Z)
	applyVelocityDelta(rootPart, desiredVelocity - rootPart.Velocity, 26 + controlLevel * 4)
end

return AirControl
