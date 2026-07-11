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

local ClientUpgradeInjector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

function Logic.start(_controller, _gc)
	if ClientUpgradeInjector then
		ClientUpgradeInjector.set("MiniatureHourglass", true, 1)
	end

	Logic.Hooked = true
	return true
end

function Logic.stop()
	if ClientUpgradeInjector then
		ClientUpgradeInjector.set("MiniatureHourglass", false, 0)
	end

	Logic.Hooked = false
end

return Logic
