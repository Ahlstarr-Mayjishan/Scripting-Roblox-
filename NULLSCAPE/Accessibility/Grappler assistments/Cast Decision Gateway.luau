--!nocheck
--[[
	NULLSCAPE - Grappler Cast Decision Gateway
	One final safety and trajectory decision shared by manual assists and techniques.
]]

local CastSafety = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Safety Check.luau")
local LandingPredictor = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Landing Predictor.luau")

local Gateway = {}

local function isEmergency(context)
	local name = context and context.EntityIntent or context and context.Technique or context and context.Name
	return name == "VoidRescue" or name == "RazorbloomEscape" or name == "ThreatDodge" or name == "SharkEscape"
end

function Gateway.evaluate(grapple, hit, controller, context)
	if not (hit and hit.Instance) then
		return {
			Accept = false,
			Penalty = 100,
			Reason = "missing-hit",
		}
	end

	if controller and controller.GrappleAssistSafetyEnabled == false then
		return {
			Accept = true,
			Penalty = 0,
			Reason = "safety-disabled",
		}
	end

	local intent = context and context.Intent or context or {}
	local result = {
		Accept = true,
		Penalty = 0,
		Reason = "clear",
	}

	if CastSafety and typeof(CastSafety.evaluate) == "function" then
		local success, safety = pcall(CastSafety.evaluate, grapple, hit, hit.Instance, controller, intent)
		if success and safety then
			result.Accept = safety.Accept ~= false
			result.Penalty += tonumber(safety.Penalty) or 0
			result.Reason = table.concat(safety.Reasons or {}, ",")
		end
	end

	if not result.Accept then
		return result
	end

	if LandingPredictor and typeof(LandingPredictor.evaluate) == "function" then
		local success, trajectory = pcall(LandingPredictor.evaluate, grapple, hit, hit.Instance, controller, intent)
		if success and trajectory then
			local penalty = tonumber(trajectory.Penalty) or 0
			result.Penalty += penalty
			result.Trajectory = trajectory
			if penalty >= 36 and not isEmergency(context) then
				result.Accept = false
				result.Reason = tostring(trajectory.Reason or "unsafe-trajectory")
			end
		end
	end

	return result
end

return Gateway
