--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local Injector = {}

local SIM_ATTR = "NULLSCAPE_SimulatedClientUpgrade"
local NATIVE_REFRESH_COOLDOWN = 0.1
local nativeStacks = {}
local simulatedStacks = {}
local nativeSnapshotLoaded = false
local lastNativeRefresh = -math.huge
local serverUpgradeConnection = nil
local resetConnection = nil
local injectorActive = true

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

local function getNativeUpgradeRemote()
	local events = ReplicatedStorage:FindFirstChild("Events")
	local functions = events and events:FindFirstChild("Functions")
	local remote = functions and functions:FindFirstChild("GetActiveUpgrades")
	return remote and remote:IsA("RemoteFunction") and remote or nil
end

local function refreshNativeSnapshot(active, force)
	local now = os.clock()
	if nativeSnapshotLoaded and (force ~= true or now - lastNativeRefresh < NATIVE_REFRESH_COOLDOWN) then
		return true
	end

	local remote = getNativeUpgradeRemote()
	if not remote then
		return false
	end

	local success, snapshot = pcall(function()
		return remote:InvokeServer()
	end)
	if not success or typeof(snapshot) ~= "table" then
		return false
	end

	table.clear(nativeStacks)
	for upgradeName in pairs(active or {}) do
		nativeStacks[upgradeName] = math.max(tonumber(snapshot[upgradeName]) or 0, 0)
	end
	for upgradeName in pairs(simulatedStacks) do
		nativeStacks[upgradeName] = math.max(tonumber(snapshot[upgradeName]) or 0, 0)
	end
	for upgradeName, stack in pairs(snapshot) do
		nativeStacks[upgradeName] = math.max(tonumber(stack) or 0, 0)
	end

	nativeSnapshotLoaded = true
	lastNativeRefresh = now
	return true
end

local function ensureNativeStack(active, upgradeName)
	if nativeStacks[upgradeName] == nil and simulatedStacks[upgradeName] == nil then
		nativeStacks[upgradeName] = math.max(tonumber(active and active[upgradeName]) or 0, 0)
	end
	return math.max(tonumber(nativeStacks[upgradeName]) or 0, 0)
end

local function setActiveUpgradeStack(active, upgradeName, stack)
	if not injectorActive or not active then
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

local function reapplySimulations(activeUpgrades)
	if not injectorActive or not activeUpgrades then
		return false
	end

	local changed = false
	for upgradeName, simulatedStack in pairs(simulatedStacks) do
		local desiredStack = math.max(tonumber(nativeStacks[upgradeName]) or 0, simulatedStack)
		if not activeUpgrades or (tonumber(activeUpgrades[upgradeName]) or 0) ~= desiredStack then
			setActiveUpgradeStack(activeUpgrades, upgradeName, desiredStack)
			cleanupVisualFolders(upgradeName)
			fireCustomSignal(upgradeName, desiredStack)
			changed = true
		end
	end
	if changed then
		fireClientUpgradesChanged()
	end
	return changed
end

local function adoptNativeSnapshot(snapshot, activeUpgrades)
	if typeof(snapshot) ~= "table" then
		return false
	end

	table.clear(nativeStacks)
	for upgradeName in pairs(activeUpgrades or {}) do
		nativeStacks[upgradeName] = math.max(tonumber(snapshot[upgradeName]) or 0, 0)
	end
	for upgradeName in pairs(simulatedStacks) do
		nativeStacks[upgradeName] = math.max(tonumber(snapshot[upgradeName]) or 0, 0)
	end
	for upgradeName, stack in pairs(snapshot) do
		nativeStacks[upgradeName] = math.max(tonumber(stack) or 0, 0)
	end

	nativeSnapshotLoaded = true
	lastNativeRefresh = os.clock()
	return true
end

local function applyUpgrade(active, upgradeName, enabled, stack)
	stack = tonumber(stack) or 1
	if stack < 1 then
		stack = 1
	end

	local nativeStack = ensureNativeStack(active, upgradeName)
	if enabled then
		simulatedStacks[upgradeName] = stack
	else
		simulatedStacks[upgradeName] = nil
	end
	local desiredStack = math.max(nativeStack, tonumber(simulatedStacks[upgradeName]) or 0)
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
	refreshNativeSnapshot(active, enabled ~= true)
	if applyUpgrade(active, upgradeName, enabled == true, stack) then
		fireClientUpgradesChanged()
	end
	return true
end

function Injector.sync(desired)
	desired = desired or {}
	local active = getActiveUpgradeTable()
	local restoring = false
	for upgradeName, enabled in pairs(desired) do
		if enabled ~= true and simulatedStacks[upgradeName] ~= nil then
			restoring = true
			break
		end
	end
	refreshNativeSnapshot(active, restoring)
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
	local restoring = false
	for upgradeName, stack in pairs(desiredStacks or {}) do
		if (tonumber(stack) or 0) <= 0 and simulatedStacks[upgradeName] ~= nil then
			restoring = true
			break
		end
	end
	refreshNativeSnapshot(active, restoring)
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
	refreshNativeSnapshot(active, true)
	local changed = false
	for _, upgradeName in ipairs(upgrades or {}) do
		changed = applyUpgrade(active, upgradeName, false, 0) or changed
	end
	if changed then
		fireClientUpgradesChanged()
	end
end

function Injector.getNativeStack(upgradeName)
	local active = getActiveUpgradeTable()
	refreshNativeSnapshot(active, false)
	return ensureNativeStack(active, upgradeName)
end

function Injector.isSimulating(upgradeName)
	return simulatedStacks[upgradeName] ~= nil
end

function Injector.captureCurrentNativeAndReapply()
	local activeUpgrades = getActiveUpgradeTable()
	if not activeUpgrades then
		return false
	end

	local snapshot = {}
	for upgradeName, stack in pairs(activeUpgrades) do
		snapshot[upgradeName] = math.max(tonumber(stack) or 0, 0)
	end
	adoptNativeSnapshot(snapshot, activeUpgrades)
	return reapplySimulations(activeUpgrades)
end

function Injector.CleanUp()
	local activeUpgrades = getActiveUpgradeTable()
	refreshNativeSnapshot(activeUpgrades, true)
	local simulatedNames = {}
	for upgradeName in pairs(simulatedStacks) do
		table.insert(simulatedNames, upgradeName)
	end
	local changed = false
	for _, upgradeName in ipairs(simulatedNames) do
		changed = applyUpgrade(activeUpgrades, upgradeName, false, 0) or changed
	end
	if changed then
		fireClientUpgradesChanged()
	end

	injectorActive = false
	if serverUpgradeConnection then
		serverUpgradeConnection:Disconnect()
		serverUpgradeConnection = nil
	end
	if resetConnection then
		resetConnection:Disconnect()
		resetConnection = nil
	end
	table.clear(simulatedStacks)
end

function Injector.isSimulated(instance)
	return instance and instance:GetAttribute(SIM_ATTR) == true
end

cleanupAllSimulatedVisuals()

do
	local events = ReplicatedStorage:FindFirstChild("Events")
	local upgradesChanged = events and events:FindFirstChild("UpgradesChanged")
	if upgradesChanged and upgradesChanged:IsA("RemoteEvent") then
		serverUpgradeConnection = upgradesChanged.OnClientEvent:Connect(function(snapshot)
			local activeUpgrades = getActiveUpgradeTable()
			if adoptNativeSnapshot(snapshot, activeUpgrades) then
				task.defer(reapplySimulations, activeUpgrades)
			end
		end)
	end

	local resetGame = events and events:FindFirstChild("ResetGame")
	if resetGame and resetGame:IsA("RemoteEvent") then
		resetConnection = resetGame.OnClientEvent:Connect(function()
			local activeUpgrades = getActiveUpgradeTable()
			local snapshot = {}
			for upgradeName in pairs(activeUpgrades or {}) do
				snapshot[upgradeName] = 0
			end
			adoptNativeSnapshot(snapshot, activeUpgrades)
			task.defer(reapplySimulations, activeUpgrades)
		end)
	end
end

return Injector
