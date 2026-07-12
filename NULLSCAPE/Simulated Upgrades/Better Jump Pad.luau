--!nocheck
-- [[
--  NULLSCAPE - Better Jump Pad client-upgrade bridge
--  Preserves native JumpPad behavior, then optionally raises its resulting launch.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Injector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local MIN_JUMP_PAD_POWER = 100
local MAX_JUMP_PAD_POWER = 300

local Logic = {
	JumpPadPower = MIN_JUMP_PAD_POWER,
	Controller = nil,
	MovementCore = nil,
	OriginalOnHitboxTouch = nil,
	WrappedOnHitboxTouch = nil,
	Hooked = false,
}

local function getMovementCore()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local module = movement and movement:FindFirstChild("MovementCore")
	if not module then
		return nil
	end

	local success, core = pcall(require, module)
	if success and typeof(core) == "table" then
		return core
	end

	return nil
end

local function getPower()
	return math.clamp(tonumber(Logic.JumpPadPower) or MIN_JUMP_PAD_POWER, MIN_JUMP_PAD_POWER, MAX_JUMP_PAD_POWER)
end

local function getActiveController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeUpgradeController or Logic.Controller
end

local function boostNativeJumpPad(movement, desiredPower)
	local deadline = time() + 0.08
	while time() < deadline do
		if movement and movement.jumpPadDebounce == true and movement.RootPart then
			local velocity = movement.RootPart.AssemblyLinearVelocity or movement.RootPart.Velocity
			if velocity.Y > 0 and desiredPower > MIN_JUMP_PAD_POWER then
				local boosted = Vector3.new(velocity.X, math.max(velocity.Y, desiredPower), velocity.Z)
				pcall(function()
					movement.RootPart.AssemblyLinearVelocity = boosted
				end)
				movement.RootPart.Velocity = boosted
			end
			return
		end
		task.wait()
	end
end

local function installHook()
	local movementCore = getMovementCore()
	if not (movementCore and typeof(movementCore.OnHitboxTouch) == "function") then
		return false
	end

	if Logic.MovementCore == movementCore and movementCore.OnHitboxTouch == Logic.WrappedOnHitboxTouch then
		return true
	end

	if movementCore.__NULLSCAPE_better_jump_pad_wrapper then
		Logic.MovementCore = movementCore
		Logic.OriginalOnHitboxTouch = movementCore.__NULLSCAPE_better_jump_pad_original
		Logic.WrappedOnHitboxTouch = movementCore.__NULLSCAPE_better_jump_pad_wrapper
		return true
	end

	local originalOnHitboxTouch = movementCore.OnHitboxTouch
	local wrappedOnHitboxTouch
	wrappedOnHitboxTouch = function(self, hitPart, ...)
		local controller = getActiveController()
		local shouldBoost = controller
			and controller.BetterJumpPadEnabled == true
			and hitPart
			and hitPart.Name == "JumpPad"
			and self
			and self.jumpPadDebounce ~= true
			and getPower() > MIN_JUMP_PAD_POWER

		if shouldBoost then
			local desiredPower = getPower()
			task.defer(boostNativeJumpPad, self, desiredPower)
		end

		return originalOnHitboxTouch(self, hitPart, ...)
	end

	movementCore.OnHitboxTouch = wrappedOnHitboxTouch
	movementCore.__NULLSCAPE_better_jump_pad_original = originalOnHitboxTouch
	movementCore.__NULLSCAPE_better_jump_pad_wrapper = wrappedOnHitboxTouch

	Logic.MovementCore = movementCore
	Logic.OriginalOnHitboxTouch = originalOnHitboxTouch
	Logic.WrappedOnHitboxTouch = wrappedOnHitboxTouch
	return true
end

local function uninstallHook()
	local movementCore = Logic.MovementCore or getMovementCore()
	if movementCore and movementCore.OnHitboxTouch == Logic.WrappedOnHitboxTouch and Logic.OriginalOnHitboxTouch then
		movementCore.OnHitboxTouch = Logic.OriginalOnHitboxTouch
	end
	if movementCore and movementCore.__NULLSCAPE_better_jump_pad_wrapper == Logic.WrappedOnHitboxTouch then
		movementCore.__NULLSCAPE_better_jump_pad_original = nil
		movementCore.__NULLSCAPE_better_jump_pad_wrapper = nil
	end

	Logic.MovementCore = nil
	Logic.OriginalOnHitboxTouch = nil
	Logic.WrappedOnHitboxTouch = nil
end

function Logic.start(controller, _gc)
	local enabled = controller and controller.BetterJumpPadEnabled == true
	Logic.Controller = controller
	if Injector then
		Injector.set("BetterJumpPad", enabled, 1)
	end
	Logic.Hooked = enabled and installHook()
end

function Logic.stop()
	if Injector then
		Injector.set("BetterJumpPad", false, 0)
	end
	uninstallHook()
	Logic.Controller = nil
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
