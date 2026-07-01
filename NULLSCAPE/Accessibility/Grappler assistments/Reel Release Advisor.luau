--!nocheck
-- [[
--  NULLSCAPE - Grappler Reel Release Advisor
--  Nudges auto-release hold times based on current velocity and technique intent.
-- ]]

local Advisor = {}

local function getVelocity(rootPart)
	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or Vector3.zero
end

function Advisor.suggestHoldTime(grapple, reason, fallbackHoldTime, metadata)
	local rootPart = grapple and grapple.RootPart
	local velocity = getVelocity(rootPart)
	local holdTime = tonumber(fallbackHoldTime) or 0.14
	local intent = metadata and metadata.Intent or reason

	if intent == "VoidRescue" then
		if velocity.Y < -70 then
			holdTime += 0.035
		elseif velocity.Y > 35 then
			holdTime -= 0.025
		end
	elseif intent == "ReelSaver" then
		if velocity.Y > 28 then
			holdTime -= 0.035
		elseif velocity.Y < -20 then
			holdTime += 0.025
		end
	end

	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if horizontal > 135 then
		holdTime -= 0.015
	end

	return math.clamp(holdTime, 0.04, 0.36)
end

return Advisor
