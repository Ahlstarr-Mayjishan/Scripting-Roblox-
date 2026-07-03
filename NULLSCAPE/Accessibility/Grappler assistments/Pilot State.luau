--!nocheck
--[[
	NULLSCAPE - Grappler Pilot State
	Separates active player intent from hands-off assist pilot moments.
]]

local PilotState = {}

local function hasMoveInput(grapple)
	local humanoid = grapple and grapple.Humanoid
	return humanoid and humanoid.MoveDirection.Magnitude > 0.08
end

local function hasManualGrappleInput(grapple)
	if not grapple then
		return false
	end

	return grapple.specialHeld == true
		or grapple.charging == true
		or grapple.grappleReel == true
		or grapple.jumpPadReel == true
end

function PilotState.resolve(grapple, intent, context)
	if context and context.PilotMode then
		return context.PilotMode
	end

	if context and context.ManualCast == true then
		return "Manual"
	end

	if intent and intent.Name == "VoidRescue" then
		return "Emergency"
	end

	if context and context.Technique then
		return "Technique"
	end

	if not hasMoveInput(grapple) and not hasManualGrappleInput(grapple) then
		return "Pilot"
	end

	return "Manual"
end

return PilotState
