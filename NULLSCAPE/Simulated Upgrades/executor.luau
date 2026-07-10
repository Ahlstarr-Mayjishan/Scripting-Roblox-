-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Executor
--  Vai trò: Chỉ đảm nhiệm việc thực thi và gọi các tính năng/API từ file logic chính (như Simulated Upgrades/Radar logic.luau).
--  Thực thi dọn dẹp vẽ cũ và định vị vẽ ESP/Highlight mới.
-- ]]

local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local Magnet = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Magnet logic.luau")
local Barrier = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Defuse Kits.luau")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Executor = {}
local missingWarnings = {}
local HookedMovementHasUpgrade = nil

local function getCallable(module, methodName, label)
	if module and typeof(module[methodName]) == "function" then
		return module[methodName]
	end

	local key = tostring(label) .. "." .. tostring(methodName)
	if not missingWarnings[key] then
		missingWarnings[key] = true
		warn("[NULLSCAPE Executor] Missing callable: " .. key)
	end

	return nil
end

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getMovementModule()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCore = movement and movement:FindFirstChild("MovementCore")
	if not (movementCore and movementCore:IsA("ModuleScript")) then
		return nil
	end

	local success, movementModule = pcall(require, movementCore)
	if not success or typeof(movementModule) ~= "table" or typeof(movementModule.HasUpgrade) ~= "function" then
		return nil
	end

	return movementModule
end

local function shouldSpoofGrapplerUpgrade(movement, upgradeName)
	if not (movement and movement.ClassID == "class/Grappler") then
		return false, nil
	end

	local globals = getGlobals()
	local controller = globals.activeUpgradeController
	local enabled = false

	if upgradeName == "NinjaBelt" or upgradeName == "Ninja Belt" then
		enabled = controller and controller.GrappleVirtualNinjaBelt == true
	elseif upgradeName == "SharkTail" or upgradeName == "Shark Tail" or upgradeName == "SharkBelt" or upgradeName == "Shark Belt" then
		enabled = controller and controller.GrappleVirtualSharkTail == true
	end

	if enabled then
		return true, 1
	end

	return false, nil
end

function Executor.enableUpgradeSimulationHook()
	local globals = getGlobals()
	local movementModule = getMovementModule()
	if not movementModule then
		return false
	end

	if globals.SimulatedUpgradesOriginalMovementHasUpgrade then
		return true
	end

	local original = movementModule.HasUpgrade
	local wrapped
	wrapped = function(self, upgradeName, ...)
		local shouldSpoof, stack = shouldSpoofGrapplerUpgrade(self, upgradeName)
		if shouldSpoof then
			return true, stack
		end

		return original(self, upgradeName, ...)
	end

	globals.SimulatedUpgradesOriginalMovementHasUpgrade = original
	HookedMovementHasUpgrade = wrapped
	movementModule.HasUpgrade = wrapped
	return true
end

function Executor.restoreUpgradeSimulationHook()
	local globals = getGlobals()
	local movementModule = getMovementModule()
	if
		movementModule
		and globals.SimulatedUpgradesOriginalMovementHasUpgrade
		and (HookedMovementHasUpgrade == nil or movementModule.HasUpgrade == HookedMovementHasUpgrade)
	then
		movementModule.HasUpgrade = globals.SimulatedUpgradesOriginalMovementHasUpgrade
	end

	globals.SimulatedUpgradesOriginalMovementHasUpgrade = nil
	HookedMovementHasUpgrade = nil
end

-- Run visual cleanup
function Executor.clearVisuals(gc, keepArrows)
	local clearVisuals = getCallable(Logic, "clearVisuals", "RadarLogic")
	if clearVisuals then
		clearVisuals(gc, keepArrows)
	end
end

-- Run ESP/style updates
function Executor.updateESPStyles(controller, gc, hrp)
	local updateESPStyles = getCallable(Logic, "updateESPStyles", "RadarLogic")
	if updateESPStyles then
		updateESPStyles(controller, gc, hrp)
	end
end

-- Run gift magnet automation
function Executor.updateMagnet(controller, hrp)
	local update = getCallable(Magnet, "update", "Magnet")
	if update then
		update(controller, hrp)
	end
end

-- Run tripmine barrier assists
function Executor.updateBarriers(controller, gc)
	local updateBarrier = getCallable(Barrier, "update", "DefuseKits")
	if updateBarrier then
		updateBarrier(controller, gc)
	end
end

return Executor
