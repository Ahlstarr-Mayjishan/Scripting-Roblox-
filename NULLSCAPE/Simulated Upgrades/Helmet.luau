--!nocheck
--[[
	NULLSCAPE - Helmet Simulation
	Native parity target:
	- MovementCore:DiveBonk still owns bonk side effects, sounds, particles, hitbox and animation.
	- HasUpgrade("Helmet") makes native bonk add upward velocity and keeps air-control friction active.
	- This module only wraps DiveBonk for late-load resilience and momentum telemetry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local HELMET_MIN_UPWARD_BOOST = 30

local Logic = {
	OriginalDiveBonk = nil,
	Hooked = false,
}

local function packValues(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local function getMovementCore()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
	if not movementCoreScript or not movementCoreScript:IsA("ModuleScript") then
		return nil
	end

	local success, movementCore = pcall(require, movementCoreScript)
	if not success or typeof(movementCore) ~= "table" then
		return nil
	end

	return movementCore
end

local function getVelocity(rootPart)
	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or nil
end

local function setVelocity(rootPart, velocity)
	if not rootPart or typeof(velocity) ~= "Vector3" then
		return
	end

	pcall(function()
		rootPart.AssemblyLinearVelocity = velocity
	end)
	rootPart.Velocity = velocity
end

local function noteHelmetImpulse(rootPart, beforeVelocity, afterVelocity, source)
	if not MomentumMemory or typeof(MomentumMemory.noteImpulse) ~= "function" then
		return
	end
	if typeof(beforeVelocity) ~= "Vector3" or typeof(afterVelocity) ~= "Vector3" then
		return
	end

	pcall(function()
		MomentumMemory.noteImpulse(
			rootPart,
			source or "HelmetBonk",
			beforeVelocity,
			afterVelocity,
			afterVelocity - beforeVelocity,
			{
				Native = true,
			}
		)
	end)
end

local function applyFallbackBoost(movement, beforeVelocity)
	local rootPart = movement and movement.RootPart
	if not rootPart or typeof(beforeVelocity) ~= "Vector3" then
		return
	end

	local afterVelocity = getVelocity(rootPart)
	if typeof(afterVelocity) ~= "Vector3" then
		return
	end

	local expectedY = beforeVelocity.Y + HELMET_MIN_UPWARD_BOOST
	if afterVelocity.Y >= expectedY - 0.5 then
		return
	end

	local boostedVelocity = Vector3.new(afterVelocity.X, math.max(afterVelocity.Y, expectedY), afterVelocity.Z)
	setVelocity(rootPart, boostedVelocity)
	noteHelmetImpulse(rootPart, afterVelocity, boostedVelocity, "HelmetFallbackBoost")
end

function Logic.start(controller, _gc)
	local movementCore = getMovementCore()
	if not (movementCore and typeof(movementCore.DiveBonk) == "function") then
		return false
	end

	if not movementCore.__NULLSCAPE_original_DiveBonk then
		movementCore.__NULLSCAPE_original_DiveBonk = movementCore.DiveBonk
	end
	Logic.OriginalDiveBonk = movementCore.__NULLSCAPE_original_DiveBonk

	if Logic.Hooked or movementCore.__NULLSCAPE_helmet_hooked then
		Logic.Hooked = true
		return true
	end

	movementCore.DiveBonk = function(self, ...)
		if not (controller and controller.HelmetEnabled == true) then
			return Logic.OriginalDiveBonk(self, ...)
		end

		local rootPart = self and self.RootPart
		local beforeVelocity = getVelocity(rootPart)
		local results = packValues(Logic.OriginalDiveBonk(self, ...))
		local afterVelocity = getVelocity(rootPart)

		noteHelmetImpulse(rootPart, beforeVelocity, afterVelocity, "HelmetNativeBonk")
		applyFallbackBoost(self, beforeVelocity)

		return table.unpack(results, 1, results.n)
	end

	movementCore.__NULLSCAPE_helmet_hooked = true
	Logic.Hooked = true
	return true
end

function Logic.stop()
	if not Logic.Hooked then
		return
	end

	local movementCore = getMovementCore()
	if movementCore and movementCore.__NULLSCAPE_original_DiveBonk then
		movementCore.DiveBonk = movementCore.__NULLSCAPE_original_DiveBonk
		movementCore.__NULLSCAPE_helmet_hooked = false
	end

	Logic.OriginalDiveBonk = nil
	Logic.Hooked = false
end

return Logic
