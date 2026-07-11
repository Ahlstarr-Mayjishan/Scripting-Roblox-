--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local Injector = {}

local SIM_ATTR = "NULLSCAPE_SimulatedClientUpgrade"

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getFolder(folderName)
	local upgradeFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder")
	return upgradeFolder and upgradeFolder:FindFirstChild(folderName)
end

local function getUpgradeHandler()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local module = clientModules and clientModules:FindFirstChild("UpgradeHandler")
	if not module then
		return nil
	end

	local success, handler = pcall(require, module)
	if success and typeof(handler) == "table" then
		return handler
	end

	return nil
end

local function setActiveUpgradeStack(upgradeName, stack)
	local handler = getUpgradeHandler()
	if not (handler and typeof(handler.GetActiveUpgrades) == "function") then
		return false
	end

	local success, active = pcall(handler.GetActiveUpgrades)
	if not success or typeof(active) ~= "table" then
		return false
	end

	active[upgradeName] = stack
	return true
end

local function removeInt(folder, upgradeName)
	if not folder then
		return
	end

	local existing = folder:FindFirstChild(upgradeName)
	if existing and existing:GetAttribute(SIM_ATTR) == true then
		existing:Destroy()
	end
end

local function cleanupVisualFolders(upgradeName)
	removeInt(getFolder("ClientUpgrades"), upgradeName)
	removeInt(getFolder("Upgrades"), upgradeName)
end

local function cleanupAllSimulatedVisuals()
	for _, folderName in ipairs({ "ClientUpgrades", "Upgrades" }) do
		local folder = getFolder(folderName)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if child:GetAttribute(SIM_ATTR) == true then
					child:Destroy()
				end
			end
		end
	end
end

local function fireCustomSignal(upgradeName, stack)
	local globals = getGlobals()
	local events = globals.customUpgradeEvents
	local event = events and events[upgradeName]
	if event then
		pcall(function()
			event:Fire(stack)
		end)
	end
end

local function collectClientUpgradeState()
	local state = {}
	local handler = getUpgradeHandler()
	if handler and typeof(handler.GetActiveUpgrades) == "function" then
		local success, active = pcall(handler.GetActiveUpgrades)
		if success and typeof(active) == "table" then
			for upgradeName, stack in pairs(active) do
				state[upgradeName] = stack
			end
		end
	end

	return state
end

local function fireClientUpgradesChanged()
	local changed = ReplicatedStorage:FindFirstChild("Events")
		and ReplicatedStorage.Events:FindFirstChild("ClientUpgradesChanged")
	if changed and changed:IsA("BindableEvent") then
		pcall(function()
			changed:Fire(collectClientUpgradeState())
		end)
	end
end

function Injector.set(upgradeName, enabled, stack)
	stack = tonumber(stack) or 1
	if stack < 1 then
		stack = 1
	end

	if enabled then
		setActiveUpgradeStack(upgradeName, stack)
		cleanupVisualFolders(upgradeName)
		fireCustomSignal(upgradeName, stack)
	else
		setActiveUpgradeStack(upgradeName, 0)
		cleanupVisualFolders(upgradeName)
		fireCustomSignal(upgradeName, 0)
	end

	fireClientUpgradesChanged()
	return true
end

function Injector.sync(desired)
	desired = desired or {}
	for upgradeName, enabled in pairs(desired) do
		Injector.set(upgradeName, enabled == true, 1)
	end
	return true
end

function Injector.clear(upgrades)
	for _, upgradeName in ipairs(upgrades or {}) do
		Injector.set(upgradeName, false, 0)
	end
end

function Injector.isSimulated(instance)
	return instance and instance:GetAttribute(SIM_ATTR) == true
end

cleanupAllSimulatedVisuals()

return Injector
