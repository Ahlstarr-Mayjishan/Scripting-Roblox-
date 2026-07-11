--!nocheck
--[[
	NULLSCAPE - Grappler Ability Intent Context
	Separates user-controlled ability moments from hands-off pilot and emergency assist.
]]

local GameState = getgenv().loadModule("NULLSCAPE/Core/Game State Context.luau")

local Context = {}

local function hasMovementInput(grapple)
	local humanoid = grapple and grapple.Humanoid
	return humanoid and humanoid.MoveDirection.Magnitude > 0.08
end

local function hasManualAbilityIntent(grapple)
	if not grapple then
		return false
	end

	return grapple.specialHeld == true
		or grapple.grappleReel == true
		or grapple.jumpPadReel == true
		or GameState.getUsingAbility(grapple.Character) == true
end

function Context.resolve(grapple, intent, options)
	options = options or {}
	local name = intent and intent.Name or "AnchorAssist"

	if name == "VoidRescue" or name == "RazorbloomEscape" then
		return {
			Mode = "EmergencyPilot",
			CanAutomate = true,
			Reason = name,
		}
	end

	if options.Technique == "ReelSaver" or name == "ReelSaver" then
		return {
			Mode = "Technique",
			CanAutomate = true,
			Reason = "ReelSaver",
		}
	end

	if hasManualAbilityIntent(grapple) then
		return {
			Mode = "UserControlled",
			CanAutomate = options.AllowDuringManual == true,
			Reason = "UsingAbility",
		}
	end

	if hasMovementInput(grapple) then
		return {
			Mode = "UserSteering",
			CanAutomate = options.AllowWhileMoving == true,
			Reason = "MoveInput",
		}
	end

	return {
		Mode = "Pilot",
		CanAutomate = true,
		Reason = "HandsOff",
	}
end

function Context.canTechniqueRun(grapple, intent, options)
	local state = Context.resolve(grapple, intent, options)
	return state.CanAutomate == true, state
end

return Context
