--!nocheck
-- [[
--  NULLSCAPE - Grace Wings Simulation
--  Multiplies airborne control while Freefall/Jumping.
--  Avoids hooking HumanoidMovement.Step so it cannot break MovementCore.Step.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local function packValues(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local Logic = {
	AirControlMultiplier = 1.1,
	OriginalApplyFriction = nil,
	LastMovement = nil,
	Connection = nil,
	Hooked = false,
}

local function getHumanoidMovement()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	if not movement then
		return nil
	end
	return movement:FindFirstChild("HumanoidMovement")
end

local function isAirborne(humanoid)
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

local function getMultiplier(controller)
	return math.clamp(tonumber(controller.GraceWingsAirControlMultiplier) or Logic.AirControlMultiplier, 1.1, 5)
end

local function applyVelocitySteering(controller, movement, dt)
	if not controller.GraceWingsEnabled then
		return
	end
	if not controller.GraceWingsStrongAirControl then
		return
	end
	if not movement or not movement.RootPart or not movement.Humanoid then
		return
	end
	if not isAirborne(movement.Humanoid) then
		return
	end

	local wantDirection = movement.WantDirection
	if typeof(wantDirection) ~= "Vector3" or wantDirection.Magnitude <= 0.001 then
		return
	end

	local rootPart = movement.RootPart
	local velocity = rootPart.AssemblyLinearVelocity or rootPart.Velocity
	local horizontalVelocity = velocity * Vector3.new(1, 0, 1)
	local horizontalSpeed = horizontalVelocity.Magnitude
	local targetSpeed = math.max(horizontalSpeed, movement.Humanoid.WalkSpeed * 0.85)
	local targetHorizontal = wantDirection.Unit * targetSpeed
	local multiplier = getMultiplier(controller)
	local alpha = math.clamp((dt or 0.016) * (multiplier - 1) * 5, 0, 0.9)
	local newHorizontal = horizontalVelocity:Lerp(targetHorizontal, alpha)
	local newVelocity = newHorizontal + Vector3.new(0, velocity.Y, 0)

	pcall(function()
		rootPart.AssemblyLinearVelocity = newVelocity
	end)
	rootPart.Velocity = newVelocity
	local delta = newVelocity - velocity
	if delta.Magnitude > 0.05 then
		MomentumMemory.noteImpulse(rootPart, "GraceWingsAirControl", velocity, newVelocity, delta, {
			Multiplier = multiplier,
		})
	end
end

function Logic.start(controller, gc)
	local HumanoidMovementModule = getHumanoidMovement()
	if not HumanoidMovementModule then
		return
	end

	local success, HumanoidMovement = pcall(require, HumanoidMovementModule)
	if not success or not HumanoidMovement or type(HumanoidMovement) ~= "table" then
		return
	end
	if type(HumanoidMovement.ApplyFriction) ~= "function" then
		return
	end

	if not HumanoidMovement.__NULLSCAPE_original_ApplyFriction then
		HumanoidMovement.__NULLSCAPE_original_ApplyFriction = HumanoidMovement.ApplyFriction
	end
	Logic.OriginalApplyFriction = HumanoidMovement.__NULLSCAPE_original_ApplyFriction

	-- Repair older GraceWings versions that hooked Step and could leave a bad wrapper behind.
	if HumanoidMovement.__NULLSCAPE_original_GraceStep then
		HumanoidMovement.Step = HumanoidMovement.__NULLSCAPE_original_GraceStep
		HumanoidMovement.__NULLSCAPE_original_GraceStep = nil
	end

	if not HumanoidMovement.__NULLSCAPE_grace_wings_hooked then
		HumanoidMovement.ApplyFriction = function(self, dt)
			local results = packValues(Logic.OriginalApplyFriction(self, dt))
			local movement = self and self.Movement
			local humanoid = self and self.Humanoid

			if controller.GraceWingsEnabled and movement and humanoid and isAirborne(humanoid) then
				Logic.LastMovement = movement
				movement.friction = movement.friction * getMultiplier(controller)
			end

			return table.unpack(results, 1, results.n)
		end

		HumanoidMovement.__NULLSCAPE_grace_wings_hooked = true
	end

	if not Logic.Connection then
		Logic.Connection = RunService.Heartbeat:Connect(function(dt)
			applyVelocitySteering(controller, Logic.LastMovement, dt)
		end)
	end

	Logic.Hooked = true
end

function Logic.stop()
	if Logic.Connection then
		Logic.Connection:Disconnect()
		Logic.Connection = nil
	end

	local HumanoidMovementModule = getHumanoidMovement()
	if HumanoidMovementModule then
		local success, HumanoidMovement = pcall(require, HumanoidMovementModule)
		if
			success
			and HumanoidMovement
			and type(HumanoidMovement) == "table"
			and HumanoidMovement.__NULLSCAPE_original_ApplyFriction
		then
			HumanoidMovement.ApplyFriction = HumanoidMovement.__NULLSCAPE_original_ApplyFriction
			HumanoidMovement.__NULLSCAPE_grace_wings_hooked = false
		end
	end

	Logic.LastMovement = nil
	Logic.OriginalApplyFriction = nil
	Logic.Hooked = false
end

function Logic.setMultiplier(value)
	Logic.AirControlMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

return Logic
