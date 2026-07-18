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

local function getActiveUpgradeTable()
	local handler = getUpgradeHandler()
	if not (handler and typeof(handler.GetActiveUpgrades) == "function") then
		return nil
	end

	local success, active = pcall(handler.GetActiveUpgrades)
	if not success or typeof(active) ~= "table" then
		return nil
	end
	return active
end

local function setActiveUpgradeStack(active, upgradeName, stack)
	if not active then
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
	local active = getActiveUpgradeTable()
	if active then
		for upgradeName, stack in pairs(active) do
			state[upgradeName] = stack
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

local function applyUpgrade(active, upgradeName, enabled, stack)
	stack = tonumber(stack) or 1
	if stack < 1 then
		stack = 1
	end
	local desiredStack = enabled and stack or 0
	local changed = not active or (tonumber(active[upgradeName]) or 0) ~= desiredStack

	setActiveUpgradeStack(active, upgradeName, desiredStack)
	cleanupVisualFolders(upgradeName)
	if changed then
		fireCustomSignal(upgradeName, desiredStack)
	end
	return changed
end

function Injector.set(upgradeName, enabled, stack)
	local active = getActiveUpgradeTable()
	if applyUpgrade(active, upgradeName, enabled == true, stack) then
		fireClientUpgradesChanged()
	end
	return true
end

function Injector.sync(desired)
	desired = desired or {}
	local active = getActiveUpgradeTable()
	local changed = false
	for upgradeName, enabled in pairs(desired) do
		changed = applyUpgrade(active, upgradeName, enabled == true, 1) or changed
	end
	if changed then
		fireClientUpgradesChanged()
	end
	return true
end

function Injector.syncStacks(desiredStacks)
	local active = getActiveUpgradeTable()
	local changed = false
	for upgradeName, stack in pairs(desiredStacks or {}) do
		local numericStack = math.max(tonumber(stack) or 0, 0)
		changed = applyUpgrade(active, upgradeName, numericStack > 0, numericStack) or changed
	end
	if changed then
		fireClientUpgradesChanged()
	end
	return true
end

function Injector.clear(upgrades)
	local active = getActiveUpgradeTable()
	local changed = false
	for _, upgradeName in ipairs(upgrades or {}) do
		changed = applyUpgrade(active, upgradeName, false, 0) or changed
	end
	if changed then
		fireClientUpgradesChanged()
	end
end

function Injector.isSimulated(instance)
	return instance and instance:GetAttribute(SIM_ATTR) == true
end

cleanupAllSimulatedVisuals()

return Injector
