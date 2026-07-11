--!nocheck
--[[
	NULLSCAPE - Helmet Simulation
	Native movement logic already checks Movement:HasUpgrade("Helmet").
	This bridge only marks the client-side upgrade as active; it does not hook DiveBonk.
]]

local ClientUpgradeInjector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local Logic = {
	Hooked = false,
}

function Logic.start(_controller, _gc)
	if ClientUpgradeInjector then
		ClientUpgradeInjector.set("Helmet", true, 1)
	end

	Logic.Hooked = true
	return true
end

function Logic.stop()
	if ClientUpgradeInjector then
		ClientUpgradeInjector.set("Helmet", false, 0)
	end

	Logic.Hooked = false
end

return Logic
