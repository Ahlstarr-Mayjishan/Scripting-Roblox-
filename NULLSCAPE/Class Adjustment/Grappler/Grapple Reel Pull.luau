--!nocheck
-- [[
--  NULLSCAPE - Grapple Reel Pull Adjustment
-- ]]

local PhysicsProfile = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/PhysicsProfile.luau")
local VelocityAssist = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/VelocityAssist.luau")

local ReelPull = {}


local CachedControl = nil

local function getControl()
	if CachedControl then
		return CachedControl
	end
	CachedControl = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	return CachedControl
end
function ReelPull.apply(grapple)
	local rootPart = grapple and grapple.RootPart
	if not (grapple and rootPart and grapple.jumpPadReel) then
		return
	end

	-- Prevent interference if landing assist is active
	local globals = getgenv()._NULLSCAPE_Globals
	local aimAssist = globals and globals.activeGrappleAimAssist
	if aimAssist and typeof(aimAssist.SmartReelLandingAssistUntil) == "number" and time() <= aimAssist.SmartReelLandingAssistUntil then
		return
	end

	local Control = getControl()
	local multiplier = Control and Control.GrappleReelPullMultiplier or 1.1
	if multiplier <= 1 then
		return
	end

	local profile = PhysicsProfile.get(nil, grapple)
	multiplier = 1 + (multiplier - 1) * (tonumber(profile and profile.PullScale) or 1)

	local desiredVelocity = rootPart.Velocity * multiplier
	if VelocityAssist and VelocityAssist.applyDelta then
		VelocityAssist.applyDelta(rootPart, desiredVelocity - rootPart.Velocity, 38, "ReelPull")
	else
		rootPart.Velocity = desiredVelocity
	end
end

return ReelPull
