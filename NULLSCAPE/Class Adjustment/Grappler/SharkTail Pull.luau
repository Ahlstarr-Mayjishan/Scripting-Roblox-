--!nocheck
-- [[
--  NULLSCAPE - SharkTail Pull Adjustment
-- ]]

local PhysicsProfile = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/PhysicsProfile.luau")
local VelocityAssist = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/VelocityAssist.luau")

local SharkTailPull = {}


local CachedControl = nil

local function getControl()
	if CachedControl then
		return CachedControl
	end
	CachedControl = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	return CachedControl
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

	local profile = PhysicsProfile.get(nil, grapple)
	multiplier = 1 + (multiplier - 1) * (tonumber(profile and profile.PullScale) or 1)

	local desiredVelocity = beforeVelocity + deltaVelocity * multiplier
	if VelocityAssist and VelocityAssist.applyDelta then
		VelocityAssist.applyDelta(rootPart, desiredVelocity - rootPart.Velocity, 42, "SharkTailPull")
	else
		rootPart.Velocity = desiredVelocity
	end
end

return SharkTailPull
