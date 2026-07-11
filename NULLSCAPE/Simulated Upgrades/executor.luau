--!nocheck

local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local Magnet = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Magnet logic.luau")
local Barrier = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Defuse Kits.luau")
local ClientUpgradeInjector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local Executor = {}
local missingWarnings = {}

local VIRTUAL_GRAPPLER_UPGRADES = {
	AdvancedGravityCoil = true,
	BetterJumpPad = true,
	Helmet = true,
	MatrixTetrahedron = true,
	MiniatureHourglass = true,
	NinjaBelt = true,
	SharkTail = true,
}

local function getCallable(module, methodName, label)
	if module and typeof(module[methodName]) == "function" then
		return module[methodName]
	end

	local key = tostring(label) .. "." .. tostring(methodName)
	if not missingWarnings[key] then
		missingWarnings[key] = true
		warn("[NULLSCAPE Executor] Missing callable: " .. key)
	end

	return nil
end

function Executor.enableUpgradeSimulationHook()
	return true
end

function Executor.restoreUpgradeSimulationHook()
	Executor.clearVirtualGrapplerUpgradeVisuals()
end

function Executor.syncVirtualGrapplerUpgradeVisuals(controller)
	if ClientUpgradeInjector then
		ClientUpgradeInjector.sync({
			AdvancedGravityCoil = controller and controller.AdvancedGravityCoilEnabled == true,
			BetterJumpPad = controller and controller.BetterJumpPadEnabled == true,
			Helmet = controller and controller.HelmetEnabled == true,
			MatrixTetrahedron = controller and controller.MatrixTetrahedronEnabled == true,
			MiniatureHourglass = controller and controller.MiniatureHourglassEnabled == true,
			NinjaBelt = controller and controller.GrappleVirtualNinjaBelt == true,
			SharkTail = controller and controller.GrappleVirtualSharkTail == true,
		})
	end
	return true
end

function Executor.clearVirtualGrapplerUpgradeVisuals()
	if ClientUpgradeInjector then
		local upgrades = {}
		for upgradeName in pairs(VIRTUAL_GRAPPLER_UPGRADES) do
			table.insert(upgrades, upgradeName)
		end
		ClientUpgradeInjector.clear(upgrades)
	end
	return true
end

function Executor.clearVisuals(gc, keepArrows)
	local clearVisuals = getCallable(Logic, "clearVisuals", "RadarLogic")
	if clearVisuals then
		clearVisuals(gc, keepArrows)
	end
end

function Executor.updateESPStyles(controller, gc, hrp)
	local updateESPStyles = getCallable(Logic, "updateESPStyles", "RadarLogic")
	if updateESPStyles then
		updateESPStyles(controller, gc, hrp)
	end
end

function Executor.updateMagnet(controller, hrp)
	local update = getCallable(Magnet, "update", "Magnet")
	if update then
		update(controller, hrp)
	end
end

function Executor.updateBarriers(controller, gc)
	local updateBarrier = getCallable(Barrier, "update", "DefuseKits")
	if updateBarrier then
		updateBarrier(controller, gc)
	end
end

return Executor
