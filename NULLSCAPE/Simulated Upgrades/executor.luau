--!nocheck

local Magnet = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Magnet logic.luau")
local Barrier = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Defuse Kits.luau")
local ClientUpgradeInjector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")
local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")

local Executor = {}
local missingWarnings = {}

local VIRTUAL_GRAPPLER_UPGRADES = {
	AdvancedGravityCoil = true,
	BetterJumpPad = true,
	DoubleJump = true,
	Helmet = true,
	MatrixTetrahedron = true,
	MiniatureHourglass = true,
	NinjaBelt = true,
	PocketBell = true,
	SharkTail = true,
}

local function hasSelectedOption(options, option)
	return typeof(options) == "table" and table.find(options, option) ~= nil
end

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
		local isGrappler = ClassContext and ClassContext.is("Grappler")
		ClientUpgradeInjector.sync({
			AdvancedGravityCoil = controller and controller.AdvancedGravityCoilEnabled == true,
			BetterJumpPad = controller and controller.BetterJumpPadEnabled == true,
			DoubleJump = controller and hasSelectedOption(controller.AirJumpSelections, "DoubleJump"),
			Helmet = controller and controller.HelmetEnabled == true,
			MatrixTetrahedron = controller and controller.MatrixTetrahedronEnabled == true,
			MiniatureHourglass = controller and controller.MiniatureHourglassEnabled == true,
			NinjaBelt = isGrappler and controller and controller.GrappleVirtualNinjaBelt == true,
			PocketBell = controller and hasSelectedOption(controller.AirJumpSelections, "PocketBell"),
			SharkTail = isGrappler and controller and controller.GrappleVirtualSharkTail == true,
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

function Executor.stopBarriers()
	local stop = getCallable(Barrier, "stop", "DefuseKits")
	if stop then
		stop()
	end
end

return Executor
