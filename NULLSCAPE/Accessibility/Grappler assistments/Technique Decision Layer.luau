--!nocheck
--[[
	NULLSCAPE - Grappler Technique Decision Layer
	Single policy point for technique priority and user-intent respect.
]]

local AbilityIntent = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Ability Intent Context.luau")
local Arbiter = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique Arbiter.luau")

local Decision = {}

Decision.Priority = {
	SharkVoid = 100,
	RazorbloomEscape = 94,
	GrappleDodge = 88,
	ReelSaver = 82,
	ReleaseTiming = 76,
	SecondaryCast = 72,
	DeferredAim = 45,
	Feedback = 10,
}

local DEFAULT_HOLDS = {
	SharkVoid = 0.45,
	RazorbloomEscape = 0.35,
	GrappleDodge = 0.42,
	ReelSaver = 0.45,
	ReleaseTiming = 0.12,
	SecondaryCast = 0.35,
	DeferredAim = 0.25,
}

function Decision.canRun(grapple, name, intent, options)
	local priority = Decision.Priority[name] or 0
	if Arbiter and typeof(Arbiter.isBlocked) == "function" and Arbiter.isBlocked(grapple, name, priority) then
		return false, {
			Mode = "Blocked",
			Reason = "HigherPriority",
		}
	end

	if AbilityIntent and typeof(AbilityIntent.canTechniqueRun) == "function" then
		local canRun, state = AbilityIntent.canTechniqueRun(grapple, intent, options or {})
		if not canRun then
			return false, state
		end
		return true, state
	end

	return true, {
		Mode = "Unknown",
		CanAutomate = true,
	}
end

function Decision.claim(grapple, name, holdTime)
	if not (Arbiter and typeof(Arbiter.claim) == "function") then
		return false
	end

	return Arbiter.claim(grapple, name, Decision.Priority[name] or 0, holdTime or DEFAULT_HOLDS[name])
end

function Decision.release(grapple, name)
	if Arbiter and typeof(Arbiter.release) == "function" then
		Arbiter.release(grapple, name)
	end
end

return Decision
