--!nocheck
-- [[
--  NULLSCAPE - Matrix Tetrahedron strength simulation
--  Below the native threshold, blends friction toward Matrix's native value while
--  preserving the game's quick-turn behavior. At the threshold, native ownership
--  takes over and suppresses the brake animation exactly as the upgrade does.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Injector = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Client Upgrade Injector.luau")

local MIN_REDUCTION = 0.1
local NATIVE_MODE_THRESHOLD = 0.7
local NATIVE_FRICTION = 20
local WRAPPER_KEY = "__NULLSCAPE_matrix_tetrahedron"

local Logic = {
	MomentumReduction = 1,
	HumanoidMovement = nil,
	OriginalStep = nil,
	WrappedStep = nil,
	Hooked = false,
}

local function getActiveController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeUpgradeController
end

local function getHumanoidMovement()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local module = movement and movement:FindFirstChild("HumanoidMovement")
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end

	local success, humanoidMovement = pcall(require, module)
	return success and typeof(humanoidMovement) == "table" and humanoidMovement or nil
end

local function getReduction(controller)
	local value = controller and controller.MomentumReduction or Logic.MomentumReduction
	return math.clamp(tonumber(value) or 1, MIN_REDUCTION, 1)
end

local function isNativeMode(controller)
	return controller ~= nil
		and controller.MatrixTetrahedronEnabled == true
		and getReduction(controller) >= NATIVE_MODE_THRESHOLD
end

local function syncNativeUpgrade(controller)
	if not Injector then
		return false
	end
	return Injector.set("MatrixTetrahedron", isNativeMode(controller), 1)
end

local function stopQuickTurn(movement)
	if not movement then
		return
	end

	movement.doingQuickTurn = false
	local floorParticles = movement.FloorParticles
	local quickTurn = floorParticles and floorParticles:FindFirstChild("QuickTurn")
	if quickTurn then
		quickTurn.Rate = 0
	end

	local animator = movement.Animator
	if animator and typeof(animator.WeightAnimation) == "function" then
		pcall(function()
			animator:WeightAnimation("QuickTurn", 0)
		end)
	end
	if animator and typeof(animator.FaceMoveDirection) == "function" then
		pcall(function()
			animator:FaceMoveDirection()
		end)
	end
end

local function getNativeFrictionTarget(humanoidMovement)
	local movement = humanoidMovement and humanoidMovement.Movement
	local humanoid = humanoidMovement and humanoidMovement.Humanoid
	if not (movement and humanoid) then
		return nil
	end
	if movement.diving or movement.diveBonked and not movement:HasUpgrade("Helmet") then
		return 0
	end

	local target = NATIVE_FRICTION
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		local hasAirControl = movement:HasUpgrade("GraceWings")
			or movement:HasUpgrade("RealWings")
			or movement.jumpPadAirControl == true
		if not hasAirControl then
			return nil
		end
		if movement.springerDebounce then
			target *= 2
		end
	end
	if movement.Status and movement.Status.HasStatus("Panic") then
		target *= 1.25
	end
	return target
end

local function applySimulation(humanoidMovement)
	local controller = getActiveController()
	local movement = humanoidMovement and humanoidMovement.Movement
	if not (
		controller
		and controller.MatrixTetrahedronEnabled == true
		and movement
		and movement.IsLocalPlayer == true
	) then
		return
	end

	local reduction = getReduction(controller)
	if reduction >= NATIVE_MODE_THRESHOLD then
		stopQuickTurn(movement)
		return
	end

	local target = getNativeFrictionTarget(humanoidMovement)
	if target ~= nil and typeof(movement.friction) == "number" then
		movement.friction += (target - movement.friction) * reduction
	end
end

local function installHook()
	local humanoidMovement = getHumanoidMovement()
	if not (humanoidMovement and typeof(humanoidMovement.Step) == "function") then
		return false
	end

	local existing = humanoidMovement[WRAPPER_KEY]
	if typeof(existing) == "table" and existing.Step then
		existing.Apply = applySimulation
		Logic.HumanoidMovement = humanoidMovement
		Logic.OriginalStep = existing.OriginalStep
		Logic.WrappedStep = existing.Step
		return true
	end

	local originalStep = humanoidMovement.Step
	local wrappedStep = function(self, dt, ...)
		local results = table.pack(originalStep(self, dt, ...))
		local state = humanoidMovement[WRAPPER_KEY]
		if state and typeof(state.Apply) == "function" then
			state.Apply(self)
		end
		return table.unpack(results, 1, results.n)
	end

	humanoidMovement.Step = wrappedStep
	humanoidMovement[WRAPPER_KEY] = {
		Apply = applySimulation,
		OriginalStep = originalStep,
		Step = wrappedStep,
	}
	Logic.HumanoidMovement = humanoidMovement
	Logic.OriginalStep = originalStep
	Logic.WrappedStep = wrappedStep
	return true
end

local function uninstallHook()
	local humanoidMovement = Logic.HumanoidMovement or getHumanoidMovement()
	if not humanoidMovement then
		return
	end

	if humanoidMovement.Step == Logic.WrappedStep and Logic.OriginalStep then
		humanoidMovement.Step = Logic.OriginalStep
		humanoidMovement[WRAPPER_KEY] = nil
	else
		local state = humanoidMovement[WRAPPER_KEY]
		if typeof(state) == "table" then
			state.Apply = nil
		end
	end

	Logic.HumanoidMovement = nil
	Logic.OriginalStep = nil
	Logic.WrappedStep = nil
end

function Logic.start(controller, _gc)
	local enabled = controller and controller.MatrixTetrahedronEnabled == true
	local hookReady = enabled and installHook()
	local nativeReady = syncNativeUpgrade(controller)
	Logic.Hooked = enabled and hookReady == true and nativeReady == true
	return Logic.Hooked
end

function Logic.stop()
	if Injector then
		Injector.set("MatrixTetrahedron", false, 0)
	end
	uninstallHook()
	Logic.Hooked = false
end

function Logic.setReduction(value)
	Logic.MomentumReduction = math.clamp(tonumber(value) or 1, MIN_REDUCTION, 1)
	syncNativeUpgrade(getActiveController())
end

function Logic.isNativeMode(controller)
	return isNativeMode(controller or getActiveController())
end

function Logic.getNativeModeThreshold()
	return NATIVE_MODE_THRESHOLD
end

return Logic
