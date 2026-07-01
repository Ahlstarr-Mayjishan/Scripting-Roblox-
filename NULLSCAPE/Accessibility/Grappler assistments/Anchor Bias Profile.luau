--!nocheck
-- [[
--  NULLSCAPE - Grappler Anchor Bias Profile
--  Combines landing, rail snap, and momentum bias into a single targeting adjustment.
-- ]]

local LandingPredictor = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Landing Predictor.luau")
local RailSnap = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Rail Snap Assist.luau")
local MomentumBridge = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Momentum Intent Bridge.luau")
local BiomeTuning = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Biome Tuning.luau")

local Bias = {}

function Bias.score(grapple, hit, part, origin, aimDirection, controller, intent)
	local score = 0
	local landing = nil

	if LandingPredictor and typeof(LandingPredictor.evaluate) == "function" then
		landing = LandingPredictor.evaluate(grapple, hit, part, controller, intent)
		score += (landing and tonumber(landing.Bonus) or 0) - (landing and tonumber(landing.Penalty) or 0)
	end

	if RailSnap and typeof(RailSnap.score) == "function" then
		score += RailSnap.score(part, origin, aimDirection, intent)
	end

	if MomentumBridge and typeof(MomentumBridge.score) == "function" then
		score += MomentumBridge.score(grapple, hit, controller, intent)
	end

	if BiomeTuning and typeof(BiomeTuning.score) == "function" then
		score += BiomeTuning.score(part, hit, controller, intent)
	end

	return score, {
		Landing = landing,
	}
end

return Bias
