--!nocheck
-- [[
--  NULLSCAPE - Advanced Gravity Coil client-upgrade bridge
--  Uses the native UpgradeHandler/MovementCore upgrade path instead of forcing
--  Humanoid.JumpPower every frame.
-- ]]

local Injector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local MIN_JUMP_POWER = 28
local MAX_JUMP_POWER = 100

local Logic = {
	JumpPower = MIN_JUMP_POWER,
	Hooked = false,
}

function Logic.start(controller, _gc)
	local enabled = controller and controller.AdvancedGravityCoilEnabled == true
	if Injector then
		Injector.set("AdvancedGravityCoil", enabled, 1)
	end
	Logic.Hooked = enabled
end

function Logic.stop()
	if Injector then
		Injector.set("AdvancedGravityCoil", false, 0)
	end
	Logic.Hooked = false
end

function Logic.setJumpPower(value)
	Logic.JumpPower = math.clamp(tonumber(value) or MIN_JUMP_POWER, MIN_JUMP_POWER, MAX_JUMP_POWER)
end

function Logic.getMinJumpPower()
	return MIN_JUMP_POWER
end

function Logic.getMaxJumpPower()
	return MAX_JUMP_POWER
end

return Logic
