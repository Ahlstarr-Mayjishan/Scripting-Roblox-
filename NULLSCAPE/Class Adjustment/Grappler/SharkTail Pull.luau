--!nocheck
-- [[
--  NULLSCAPE - SharkTail Pull Adjustment
-- ]]

local SharkTailPull = {}


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

local function getPullScale(grapple)
	local movement = grapple and grapple.Movement
	local lowGravity = hasUpgrade(movement, "AdvancedGravityCoil")
		or characterHas(grapple, "HighriseLowGravity")
		or characterHas(grapple, "Highrise")
		or hasMovementFlag(movement, "HighriseLowGravity")

	return lowGravity and 0.78 or 1
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

function SharkTailPull.apply(grapple, previousVelocity)
	local Control = getControl()
	local multiplier = Control and Control.GrappleSharkTailPullMultiplier or 1.1
	if multiplier <= 1 then
		return
	end

	local rootPart = grapple and grapple.RootPart
	if not (grapple and rootPart) then
		return
	end

	local beforeVelocity = previousVelocity
	if typeof(beforeVelocity) ~= "Vector3" then
		beforeVelocity = Vector3.new(0, 0, 0)
	end

	local deltaVelocity = rootPart.Velocity - beforeVelocity
	if deltaVelocity.Magnitude <= 0.01 then
		return
	end

	multiplier = 1 + (multiplier - 1) * getPullScale(grapple)

	local desiredVelocity = beforeVelocity + deltaVelocity * multiplier
	applyVelocityDelta(rootPart, desiredVelocity - rootPart.Velocity, 42)
end

return SharkTailPull
