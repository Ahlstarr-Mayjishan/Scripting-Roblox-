--!nocheck
-- [[
--  NULLSCAPE - Grace Wings Simulation
--  Multiplies native GraceWings friction only while Freefall.
--  Avoids hooking HumanoidMovement.Step so it cannot break MovementCore.Step.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function packValues(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local Logic = {
	AirControlMultiplier = 1,
	OriginalApplyFriction = nil,
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
	return humanoid:GetState() == Enum.HumanoidStateType.Freefall
end

local function getMultiplier(controller)
	return math.clamp(tonumber(controller.GraceWingsAirControlMultiplier) or Logic.AirControlMultiplier, 1, 5)
end

function Logic.start(controller, _gc)
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
				local multiplier = getMultiplier(controller)
				if multiplier > 1 then
					movement.friction *= multiplier
				end
			end

			return table.unpack(results, 1, results.n)
		end

		HumanoidMovement.__NULLSCAPE_grace_wings_hooked = true
	end

	Logic.Hooked = true
end

function Logic.stop()
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

	Logic.OriginalApplyFriction = nil
	Logic.Hooked = false
end

function Logic.setMultiplier(value)
	Logic.AirControlMultiplier = math.clamp(tonumber(value) or 1, 1, 5)
end

return Logic
