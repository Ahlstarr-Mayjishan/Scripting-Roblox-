--!nocheck
-- [[
--  NULLSCAPE - Matrix Tetrahedron Simulation
--  - Momentum reduction through MovementCore.SetMoveDirection.
--  - QuickTurn brake animation control through HumanoidMovement.Step.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function packValues(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local Logic = {
	MomentumReduction = 1.0,
	OriginalSetMoveDirection = nil,
	OriginalHumanoidStep = nil,
	QuickTurnState = setmetatable({}, { __mode = "k" }),
	Hooked = false,
}

local function getMovementModule(name)
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	if not movement then
		return nil
	end
	return movement:FindFirstChild(name)
end

local function getQuickTurnMaxDuration(reduction)
	-- Below 60%, keep the brake animation. 10% leaves 90% duration, 50% leaves 50%.
	local baseDuration = 0.28
	local durationScale = math.clamp(1 - reduction, 0.5, 0.9)
	return baseDuration * durationScale
end

local function getDirectionBlend(reduction)
	if reduction >= 1 then
		return 1
	end

	local framesToConverge = 60 * (1 - reduction)
	local naturalBlend = 1 - math.pow(0.1, 1 / framesToConverge)
	local antiZigzagBlend = 0.025 + reduction * 0.08

	return math.clamp(math.max(naturalBlend, antiZigzagBlend), 0.035, 1)
end

local function stopQuickTurn(movement)
	movement.doingQuickTurn = false

	if movement.FloorParticles and movement.FloorParticles:FindFirstChild("QuickTurn") then
		movement.FloorParticles.QuickTurn.Rate = 0
	end

	if movement.Animator and movement.Animator.WeightAnimation then
		pcall(function()
			movement.Animator:WeightAnimation("QuickTurn", 0)
		end)
	end

	if movement.Animator and movement.Animator.FaceMoveDirection then
		pcall(function()
			movement.Animator:FaceMoveDirection()
		end)
	end
end

local function hookMovementCore(controller)
	local MovementCoreModule = getMovementModule("MovementCore")
	if not MovementCoreModule then
		return
	end

	local success, MovementCore = pcall(require, MovementCoreModule)
	if not success or not MovementCore or type(MovementCore) ~= "table" then
		return
	end

	if not MovementCore.__NULLSCAPE_original_SetMoveDirection then
		MovementCore.__NULLSCAPE_original_SetMoveDirection = MovementCore.SetMoveDirection
	end
	Logic.OriginalSetMoveDirection = MovementCore.__NULLSCAPE_original_SetMoveDirection

	MovementCore.SetMoveDirection = function(self, direction)
		local r = controller.MomentumReduction or Logic.MomentumReduction or 0.1
		if
			r > 0
			and self.WantDirection
			and typeof(self.WantDirection) == "Vector3"
			and typeof(direction) == "Vector3"
		then
			if r >= 0.6 then
				self.doingQuickTurn = false
				direction = direction:Lerp(self.WantDirection, getDirectionBlend(r))
			elseif self.doingQuickTurn then
				direction = direction:Lerp(self.WantDirection, getDirectionBlend(r))
			end
		end
		return Logic.OriginalSetMoveDirection(self, direction)
	end
end

local function hookHumanoidMovement(controller)
	local HumanoidMovementModule = getMovementModule("HumanoidMovement")
	if not HumanoidMovementModule then
		return
	end

	local success, HumanoidMovement = pcall(require, HumanoidMovementModule)
	if not success or not HumanoidMovement or type(HumanoidMovement) ~= "table" then
		return
	end

	if not HumanoidMovement.__NULLSCAPE_original_Step then
		HumanoidMovement.__NULLSCAPE_original_Step = HumanoidMovement.Step
	end
	Logic.OriginalHumanoidStep = HumanoidMovement.__NULLSCAPE_original_Step

	if HumanoidMovement.__NULLSCAPE_matrix_step_hooked then
		return
	end

	HumanoidMovement.Step = function(self, dt)
		local results = packValues(Logic.OriginalHumanoidStep(self, dt))
		local movement = self and self.Movement
		if not movement then
			return table.unpack(results, 1, results.n)
		end

		local r = controller.MomentumReduction or Logic.MomentumReduction or 0
		if controller.MatrixTetrahedronEnabled and r >= 0.6 then
			stopQuickTurn(movement)
			Logic.QuickTurnState[movement] = nil
		elseif controller.MatrixTetrahedronEnabled and r > 0 and movement.doingQuickTurn then
			local now = os.clock()
			local state = Logic.QuickTurnState[movement]
			if not state then
				state = { started = now }
				Logic.QuickTurnState[movement] = state
			end

			if now - state.started >= getQuickTurnMaxDuration(r) then
				stopQuickTurn(movement)
				Logic.QuickTurnState[movement] = nil
			end
		else
			Logic.QuickTurnState[movement] = nil
		end

		return table.unpack(results, 1, results.n)
	end
	HumanoidMovement.__NULLSCAPE_matrix_step_hooked = true
end

function Logic.start(controller, gc)
	if Logic.Hooked then
		return
	end

	hookMovementCore(controller)
	hookHumanoidMovement(controller)
	Logic.Hooked = true
end

function Logic.stop()
	if not Logic.Hooked then
		return
	end

	local MovementCoreModule = getMovementModule("MovementCore")
	if MovementCoreModule then
		local success, MovementCore = pcall(require, MovementCoreModule)
		if
			success
			and MovementCore
			and type(MovementCore) == "table"
			and MovementCore.__NULLSCAPE_original_SetMoveDirection
		then
			MovementCore.SetMoveDirection = MovementCore.__NULLSCAPE_original_SetMoveDirection
		end
	end

	local HumanoidMovementModule = getMovementModule("HumanoidMovement")
	if HumanoidMovementModule then
		local success, HumanoidMovement = pcall(require, HumanoidMovementModule)
		if
			success
			and HumanoidMovement
			and type(HumanoidMovement) == "table"
			and HumanoidMovement.__NULLSCAPE_original_Step
		then
			HumanoidMovement.Step = HumanoidMovement.__NULLSCAPE_original_Step
			HumanoidMovement.__NULLSCAPE_matrix_step_hooked = false
		end
	end

	Logic.OriginalSetMoveDirection = nil
	Logic.OriginalHumanoidStep = nil
	table.clear(Logic.QuickTurnState)
	Logic.Hooked = false
end

function Logic.setReduction(value)
	Logic.MomentumReduction = tonumber(value) or 1.0
end

return Logic
