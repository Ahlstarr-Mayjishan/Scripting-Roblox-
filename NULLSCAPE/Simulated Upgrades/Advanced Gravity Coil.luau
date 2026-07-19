--!nocheck
-- [[
--  NULLSCAPE - Advanced Gravity Coil client-upgrade bridge
--  Uses the native UpgradeHandler/MovementCore upgrade path instead of forcing
--  Humanoid.JumpPower every frame.
-- ]]

local Injector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local MIN_JUMP_POWER = 28
local MAX_JUMP_POWER = 100
local MOVEMENT_WRAPPER_KEY = "__NULLSCAPE_advanced_gravity_coil"

local Logic = {
	JumpPower = MIN_JUMP_POWER,
	ApplyVersion = 0,
	AppliedHumanoid = nil,
	AppliedVersion = -1,
	LastMovement = nil,
	MovementCore = nil,
	OriginalStep = nil,
	WrappedStep = nil,
	OriginalUpgradeChanged = nil,
	WrappedUpgradeChanged = nil,
	Hooked = false,
}

local function getActiveController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeUpgradeController
end

local function getMovementCore()
	local movement = game:GetService("ReplicatedStorage"):FindFirstChild("Movement")
	local module = movement and movement:FindFirstChild("MovementCore")
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end

	local success, core = pcall(require, module)
	return success and typeof(core) == "table" and core or nil
end

local function applyJumpPower(movement, force)
	local controller = getActiveController()
	if not (controller and controller.AdvancedGravityCoilEnabled == true and movement) then
		return false
	end
	if movement.IsLocalPlayer ~= true then
		return false
	end
	Logic.LastMovement = movement

	local humanoid = movement.Humanoid
	if not (humanoid and humanoid:IsA("Humanoid") and humanoid.Parent) then
		return false
	end
	if
		force ~= true
		and Logic.AppliedHumanoid == humanoid
		and Logic.AppliedVersion == Logic.ApplyVersion
	then
		return true
	end

	local success = pcall(function()
		humanoid.JumpPower = Logic.JumpPower
	end)
	if success then
		Logic.AppliedHumanoid = humanoid
		Logic.AppliedVersion = Logic.ApplyVersion
	end
	return success
end

local function installMovementHooks()
	local movementCore = getMovementCore()
	if not (
		movementCore
		and typeof(movementCore.Step) == "function"
		and typeof(movementCore.UpgradeChanged) == "function"
	) then
		return false
	end

	local existing = movementCore[MOVEMENT_WRAPPER_KEY]
	if typeof(existing) == "table" and existing.Step and existing.UpgradeChanged then
		existing.Apply = applyJumpPower
		Logic.MovementCore = movementCore
		Logic.OriginalStep = existing.OriginalStep
		Logic.WrappedStep = existing.Step
		Logic.OriginalUpgradeChanged = existing.OriginalUpgradeChanged
		Logic.WrappedUpgradeChanged = existing.UpgradeChanged
		return true
	end

	local originalStep = movementCore.Step
	local originalUpgradeChanged = movementCore.UpgradeChanged
	local wrappedStep = function(self, dt, ...)
		local results = table.pack(originalStep(self, dt, ...))
		local state = movementCore[MOVEMENT_WRAPPER_KEY]
		if state and typeof(state.Apply) == "function" then
			state.Apply(self, false)
		end
		return table.unpack(results, 1, results.n)
	end
	local wrappedUpgradeChanged = function(self, ...)
		local results = table.pack(originalUpgradeChanged(self, ...))
		local state = movementCore[MOVEMENT_WRAPPER_KEY]
		if state and typeof(state.Apply) == "function" then
			state.Apply(self, true)
		end
		return table.unpack(results, 1, results.n)
	end

	movementCore.Step = wrappedStep
	movementCore.UpgradeChanged = wrappedUpgradeChanged
	movementCore[MOVEMENT_WRAPPER_KEY] = {
		Apply = applyJumpPower,
		OriginalStep = originalStep,
		Step = wrappedStep,
		OriginalUpgradeChanged = originalUpgradeChanged,
		UpgradeChanged = wrappedUpgradeChanged,
	}
	Logic.MovementCore = movementCore
	Logic.OriginalStep = originalStep
	Logic.WrappedStep = wrappedStep
	Logic.OriginalUpgradeChanged = originalUpgradeChanged
	Logic.WrappedUpgradeChanged = wrappedUpgradeChanged
	return true
end

local function uninstallMovementHooks()
	local movementCore = Logic.MovementCore or getMovementCore()
	if not movementCore then
		return
	end

	local restoredStep = movementCore.Step == Logic.WrappedStep and Logic.OriginalStep ~= nil
	local restoredUpgrade = movementCore.UpgradeChanged == Logic.WrappedUpgradeChanged
		and Logic.OriginalUpgradeChanged ~= nil
	if restoredStep then
		movementCore.Step = Logic.OriginalStep
	end
	if restoredUpgrade then
		movementCore.UpgradeChanged = Logic.OriginalUpgradeChanged
	end
	if restoredStep and restoredUpgrade then
		movementCore[MOVEMENT_WRAPPER_KEY] = nil
	else
		local state = movementCore[MOVEMENT_WRAPPER_KEY]
		if typeof(state) == "table" then
			state.Apply = nil
		end
	end

	Logic.MovementCore = nil
	Logic.OriginalStep = nil
	Logic.WrappedStep = nil
	Logic.OriginalUpgradeChanged = nil
	Logic.WrappedUpgradeChanged = nil
end

function Logic.start(controller, _gc)
	local enabled = controller and controller.AdvancedGravityCoilEnabled == true
	local hooksReady = enabled and installMovementHooks()
	local injected = Injector and Injector.set("AdvancedGravityCoil", enabled, 1)
	Logic.Hooked = enabled and hooksReady == true and injected == true
	if Logic.Hooked then
		applyJumpPower(Logic.LastMovement, true)
	end
	return Logic.Hooked
end

function Logic.stop()
	if Injector then
		Injector.set("AdvancedGravityCoil", false, 0)
	end
	uninstallMovementHooks()
	Logic.LastMovement = nil
	Logic.AppliedHumanoid = nil
	Logic.AppliedVersion = -1
	Logic.Hooked = false
end

function Logic.setJumpPower(value)
	Logic.JumpPower = math.clamp(tonumber(value) or MIN_JUMP_POWER, MIN_JUMP_POWER, MAX_JUMP_POWER)
	Logic.ApplyVersion += 1
	applyJumpPower(Logic.LastMovement, true)
end

function Logic.getMinJumpPower()
	return MIN_JUMP_POWER
end

function Logic.getMaxJumpPower()
	return MAX_JUMP_POWER
end

return Logic
