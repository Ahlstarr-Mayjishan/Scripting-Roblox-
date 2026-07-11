--!nocheck
-- [[
--  NULLSCAPE - Matrix Tetrahedron client-upgrade bridge
--  Lets the native UpgradeHandler/MovementCore paths see MatrixTetrahedron without
--  patching MovementCore.SetMoveDirection or HumanoidMovement.Step.
-- ]]

local Injector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local Logic = {
	MomentumReduction = 1.0,
	Hooked = false,
}

function Logic.start(controller, _gc)
	local enabled = controller and controller.MatrixTetrahedronEnabled == true
	if Injector then
		Injector.set("MatrixTetrahedron", enabled, 1)
	end
	Logic.Hooked = enabled
end

function Logic.stop()
	if Injector then
		Injector.set("MatrixTetrahedron", false, 0)
	end
	Logic.Hooked = false
end

function Logic.setReduction(value)
	Logic.MomentumReduction = tonumber(value) or 1.0
end

return Logic
