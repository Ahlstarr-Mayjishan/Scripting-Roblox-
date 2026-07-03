--!nocheck
-- [[
--  NULLSCAPE - Automation Executor
--  Dispatch point for automation modules.
-- ]]

local Executor = {}
local GiftFarm = nil
local PylonActivator = nil

local function loadGiftFarm()
	if GiftFarm then
		return GiftFarm
	end

	local ok, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Automation/Gift Farm.luau")
	end)
	if ok and typeof(result) == "table" then
		GiftFarm = result
		return result
	end

	warn("[NULLSCAPE] Automation Gift Farm failed to load: " .. tostring(result))
	return nil
end

local function loadPylonActivator()
	if PylonActivator then
		return PylonActivator
	end

	local ok, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Automation/Pylon Activator.luau")
	end)
	if ok and typeof(result) == "table" then
		PylonActivator = result
		return result
	end

	warn("[NULLSCAPE] Automation Pylon Activator failed to load: " .. tostring(result))
	return nil
end

function Executor.enable(controller, gc)
	local farm = loadGiftFarm()
	if farm and typeof(farm.update) == "function" then
		farm.update(controller, gc)
	end
	local pylonActivator = loadPylonActivator()
	if pylonActivator and typeof(pylonActivator.update) == "function" then
		pylonActivator.update(controller, gc)
	end
	return true
end

function Executor.disable(controller, gc)
	local farm = loadGiftFarm()
	if farm and typeof(farm.disable) == "function" then
		farm.disable(controller)
	end
	local pylonActivator = loadPylonActivator()
	if pylonActivator and typeof(pylonActivator.disable) == "function" then
		pylonActivator.disable(controller)
	end
	if gc and typeof(gc.cleanAll) == "function" then
		gc.cleanAll()
	end
	return true
end

function Executor.update(controller, gc)
	local ok = true
	local farm = loadGiftFarm()
	if farm and typeof(farm.update) == "function" then
		ok = farm.update(controller, gc) ~= false and ok
	end
	local pylonActivator = loadPylonActivator()
	if pylonActivator and typeof(pylonActivator.update) == "function" then
		ok = pylonActivator.update(controller, gc) ~= false and ok
	end
	return ok
end

function Executor.getGiftFarmStatus(controller)
	local farm = loadGiftFarm()
	if farm and typeof(farm.getStatus) == "function" then
		return farm.getStatus(controller)
	end
	return {
		Status = controller and controller.GiftFarmStatus or "Idle",
		Detail = controller and controller.GiftFarmDetail or "",
	}
end

function Executor.getPylonActivatorStatus(controller)
	local pylonActivator = loadPylonActivator()
	if pylonActivator and typeof(pylonActivator.getStatus) == "function" then
		return pylonActivator.getStatus(controller)
	end
	return {
		Status = controller and controller.PylonActivatorStatus or "Idle",
		Detail = controller and controller.PylonActivatorDetail or "",
	}
end

return Executor
