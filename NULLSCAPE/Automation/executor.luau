--!nocheck
-- [[
--  NULLSCAPE - Automation Executor
--  Dispatch point for automation modules.
-- ]]

local Executor = {}
local GiftFarm = nil
local PylonActivator = nil
local AutoChooseThings = nil

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

local function loadAutoChooseThings()
	if AutoChooseThings then
		return AutoChooseThings
	end

	local ok, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Automation/Auto Choose Things.luau")
	end)
	if ok and typeof(result) == "table" then
		AutoChooseThings = result
		return result
	end

	warn("[NULLSCAPE] Automation Auto Choose Things failed to load: " .. tostring(result))
	return nil
end

function Executor.enable(controller, gc)
	return Executor.update(controller, gc)
end

function Executor.disable(controller, gc)
	if GiftFarm and typeof(GiftFarm.disable) == "function" then
		GiftFarm.disable(controller)
	end
	if PylonActivator and typeof(PylonActivator.disable) == "function" then
		PylonActivator.disable(controller)
	end
	if AutoChooseThings and typeof(AutoChooseThings.disable) == "function" then
		AutoChooseThings.disable(controller)
	end
	if gc and typeof(gc.cleanAll) == "function" then
		gc.cleanAll()
	end
	return true
end

function Executor.update(controller, gc)
	local ok = true
	if controller and controller.GiftFarmEnabled then
		local farm = loadGiftFarm()
		if not (farm and typeof(farm.update) == "function") then
			ok = false
		else
			ok = farm.update(controller, gc) ~= false and ok
		end
	elseif GiftFarm and typeof(GiftFarm.disable) == "function" then
		ok = GiftFarm.disable(controller) ~= false and ok
	end

	if controller and controller.PylonActivatorEnabled then
		local pylonActivator = loadPylonActivator()
		if not (pylonActivator and typeof(pylonActivator.update) == "function") then
			ok = false
		else
			ok = pylonActivator.update(controller, gc) ~= false and ok
		end
	elseif PylonActivator and typeof(PylonActivator.disable) == "function" then
		ok = PylonActivator.disable(controller) ~= false and ok
	end

	if controller and controller.AutoChooseThingsEnabled then
		local chooser = loadAutoChooseThings()
		if not (chooser and typeof(chooser.update) == "function") then
			ok = false
		else
			ok = chooser.update(controller, gc) ~= false and ok
		end
	elseif AutoChooseThings and typeof(AutoChooseThings.disable) == "function" then
		ok = AutoChooseThings.disable(controller) ~= false and ok
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

function Executor.getAutoChooseThingsStatus(controller)
	local chooser = loadAutoChooseThings()
	if chooser and typeof(chooser.getStatus) == "function" then
		return chooser.getStatus(controller)
	end
	return {
		Status = controller and controller.AutoChooseThingsStatus or "Idle",
		Detail = controller and controller.AutoChooseThingsDetail or "",
	}
end

return Executor
