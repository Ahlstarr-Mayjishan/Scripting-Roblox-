--!nocheck
--[[
	NULLSCAPE - Miniature Hourglass Simulation
	Most native effects are already gated behind Movement:HasUpgrade("MiniatureHourglass"):
	- Grappler recharge rate +30%
	- Charger charge cooldown / air platform duration
	- Spirit relocation cooldown and distance penalty
	- Diver powered-dive pickup range

	This module intentionally stays small. The controller spoofs upgrade ownership,
	then native class logic applies the effect in its own Step/SpecialAction paths.
]]

local Logic = {
	Hooked = false,
}

function Logic.start(_controller, _gc)
	Logic.Hooked = true
	return true
end

function Logic.stop()
	Logic.Hooked = false
end

return Logic
