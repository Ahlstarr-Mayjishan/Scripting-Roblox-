-- [[
--  NULLSCAPE - Universal Anti Bonk
--  Suppresses all DiveBonk/stun states from diving or sliding into obstacles completely.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function shouldSuppress()
	local controller = getGlobals().activeAccessibilityController
	return controller and controller.AntiBonkEnabled == true
end

function Logic.initialize()
	local globals = getGlobals()
	if globals.AntiBonkHooked then
		return true
	end

	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
	if not movementCoreScript or not movementCoreScript:IsA("ModuleScript") then
		return false
	end

	local success, movementCore = pcall(require, movementCoreScript)
	if not success or typeof(movementCore) ~= "table" or typeof(movementCore.DiveBonk) ~= "function" then
		return false
	end

	local originalDiveBonk = movementCore.DiveBonk
	globals.OriginalDiveBonk = originalDiveBonk

	-- Hook DiveBonk to do absolutely nothing when shouldSuppress() is true
	movementCore.DiveBonk = function(self, ...)
		if shouldSuppress() then
			-- Suppress the stun state and animation
			self.diveBonked = false
			self.bonkedOffPlayer = false
			return nil
		end
		return originalDiveBonk(self, ...)
	end

	globals.AntiBonkHooked = true
	return true
end

return Logic
