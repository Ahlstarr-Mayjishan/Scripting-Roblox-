--!nocheck
-- [[
--  NULLSCAPE - Better Jump Pad client-upgrade bridge
--  Keeps the native upgrade flag visible without patching MovementCore.OnHitboxTouch.
-- ]]

local Injector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local MIN_JUMP_PAD_POWER = 100
local MAX_JUMP_PAD_POWER = 200

local Logic = {
	JumpPadPower = MIN_JUMP_PAD_POWER,
	Hooked = false,
}

function Logic.start(controller, _gc)
	local enabled = controller and controller.BetterJumpPadEnabled == true
	if Injector then
		Injector.set("BetterJumpPad", enabled, 1)
	end
	Logic.Hooked = enabled
end

function Logic.stop()
	if Injector then
		Injector.set("BetterJumpPad", false, 0)
	end
	Logic.Hooked = false
end

function Logic.setJumpPadPower(value)
	Logic.JumpPadPower = math.clamp(tonumber(value) or MIN_JUMP_PAD_POWER, MIN_JUMP_PAD_POWER, MAX_JUMP_PAD_POWER)
end

function Logic.getMinJumpPadPower()
	return MIN_JUMP_PAD_POWER
end

function Logic.getMaxJumpPadPower()
	return MAX_JUMP_PAD_POWER
end

return Logic
