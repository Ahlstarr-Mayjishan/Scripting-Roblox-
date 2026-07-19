--!nocheck
-- [[
--  NULLSCAPE - Native Radar & Highlight Simulation Logic
--  Mirrors native upgrade ownership while preserving game-controlled effects.
-- ]]

local Logic = {}
local upgradeWatcherConnection = nil
local upgradeWatcherController = nil
local simulatedUpgradeStates = {}
local desiredCache = setmetatable({}, { __mode = "k" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local NativeEnemyRadar = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Native Enemy Radar.luau")

local SIM_ATTR = "NULLSCAPE_Simulated"

Logic.RADAR_UPGRADES = {
	"HighlightGifts",
	"HighlightTripmines",
	"RadarInstruments",
	"RadarAltars",
	"RadarPlayer",
	"EnemyOnTop",
}

local RADAR_UPGRADE_SET = {}
for _, upgradeName in ipairs(Logic.RADAR_UPGRADES) do
	RADAR_UPGRADE_SET[upgradeName] = true
end

Logic.FEATURES = {
	Gift = { upgrade = "HighlightGifts" },
	Tripmine = { upgrade = "HighlightTripmines" },
	Cadence = { upgrade = "RadarInstruments" },
	Altar = { upgrade = "RadarAltars" },
	Player = { upgrade = "RadarPlayer" },
	Enemy = { upgrade = "EnemyOnTop" },
}

local FEATURE_TO_UPGRADE = {
	Gift = "HighlightGifts",
	Tripmine = "HighlightTripmines",
	Cadance = "RadarInstruments",
	Cadence = "RadarInstruments",
	Altar = "RadarAltars",
	Player = "RadarPlayer",
	Enemy = "EnemyOnTop",
}

local DIRECT_FOLDER_UPGRADES = {
	EnemyOnTop = true,
}

local function getUpgradesFolder()
	local upgradeFolder = ReplicatedStorage:FindFirstChild("UpgradeFolder")
	return upgradeFolder and upgradeFolder:FindFirstChild("Upgrades")
end

local function isNativelyOwned(upgradeName)
	local globals = getgenv()._NULLSCAPE_Globals
	local orig = globals and globals.OriginalIsUpgradeEnabled
	if typeof(orig) == "function" then
		local success, result = pcall(orig, upgradeName)
		if success then
			return result == true
		end
	end

	local upgradesFolder = getUpgradesFolder()
	if upgradesFolder then
		local val = upgradesFolder:FindFirstChild(upgradeName)
		if
			val
			and not val:GetAttribute(SIM_ATTR)
			and (val:IsA("ValueObject") or val:IsA("Attribute") or val:IsA("IntValue") or val:IsA("BoolValue"))
		then
			local value = 0
			pcall(function()
				value = val.Value or 0
			end)
			if value > 0 or value == true then
				return true
			end
		end
	end

	return false
end

Logic.isNativelyOwned = isNativelyOwned

local function collectDesiredSimulatedUpgrades(controller)
	local cached = controller and desiredCache[controller]
	if cached and cached.Enabled == controller.RadarEnabled and cached.Features == controller.RadarFeatures then
		return cached.Desired
	end

	local desired = {}
	if not controller or controller.RadarEnabled ~= true then
		if controller then
			desiredCache[controller] = {
				Enabled = controller.RadarEnabled,
				Features = controller.RadarFeatures,
				Desired = desired,
			}
		end
		return desired
	end

	local features = controller.RadarFeatures or { "Gift", "Tripmine", "Cadance", "Altar", "Player", "Enemy" }

	for _, featureName in ipairs(features) do
		local upgradeName = FEATURE_TO_UPGRADE[featureName]
		if upgradeName then
			desired[upgradeName] = true
		end
	end
	desiredCache[controller] = {
		Enabled = controller.RadarEnabled,
		Features = controller.RadarFeatures,
		Desired = desired,
	}

	return desired
end

function Logic.invalidateDesired(controller)
	if controller then
		desiredCache[controller] = nil
	end
end

local function ensureSimulatedUpgradeInt(upgrades, upgradeName)
	local existing = upgrades:FindFirstChild(upgradeName)
	if existing then
		if existing:GetAttribute(SIM_ATTR) then
			if existing.Value ~= 1 then
				existing.Value = 1
			end
			return existing
		end
		return nil
	end

	local simulated = Instance.new("IntValue")
	simulated.Name = upgradeName
	simulated.Value = 1
	simulated:SetAttribute(SIM_ATTR, true)
	simulated.Parent = upgrades
	return simulated
end

local function removeSimulatedUpgradeInt(upgrades, upgradeName)
	local existing = upgrades:FindFirstChild(upgradeName)
	if existing and existing:GetAttribute(SIM_ATTR) then
		pcall(function()
			existing:Destroy()
		end)
	end
end

local function getUpvalueValue(fn, index)
	local environment = getgenv and getgenv()
	local getUpvalue = environment and environment.debug and environment.debug.getupvalue
	if typeof(getUpvalue) ~= "function" then
		return nil
	end

	local success, first, second = pcall(getUpvalue, fn, index)
	if not success then
		return nil
	end

	return second ~= nil and second or first
end

local function getNativeUpgradeSignal(upgradeName)
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local upgradeModule = clientModules and clientModules:FindFirstChild("UpgradeHandler")
	if not upgradeModule then
		return nil
	end

	local success, handler = pcall(require, upgradeModule)
	if not success or typeof(handler) ~= "table" or typeof(handler.GetUpgradeChangedSignal) ~= "function" then
		return nil
	end

	for index = 1, 8 do
		local upvalue = getUpvalueValue(handler.GetUpgradeChangedSignal, index)
		if typeof(upvalue) == "table" then
			local event = upvalue[upgradeName]
			if event and typeof(event.Fire) == "function" then
				return event
			end
		end
	end

	return nil
end

local function fireUpgradeTransition(upgradeName, value)
	local signal = getNativeUpgradeSignal(upgradeName)
	if signal then
		pcall(function()
			signal:Fire(value)
		end)
		return
	end

	local globals = getgenv()._NULLSCAPE_Globals
	local fallback = globals and globals.customUpgradeEvents and globals.customUpgradeEvents[upgradeName]
	if fallback then
		pcall(function()
			fallback:Fire(value)
		end)
	end
end

function Logic.syncSimulatedUpgradeHud(controller)
	if not controller or controller.Destroyed then
		return
	end

	local upgrades = getUpgradesFolder()
	if not upgrades then
		return
	end

	local desired = collectDesiredSimulatedUpgrades(controller)
	local enemyRadarDesired = desired.EnemyOnTop == true
	local enemyRadarNative = isNativelyOwned("EnemyOnTop")
	for _, child in ipairs(upgrades:GetChildren()) do
		if
			child:GetAttribute(SIM_ATTR)
			and RADAR_UPGRADE_SET[child.Name]
			and (not DIRECT_FOLDER_UPGRADES[child.Name] or not desired[child.Name])
		then
			removeSimulatedUpgradeInt(upgrades, child.Name)
		end
	end

	for upgradeName in pairs(desired) do
		if DIRECT_FOLDER_UPGRADES[upgradeName] then
			ensureSimulatedUpgradeInt(upgrades, upgradeName)
		end
	end

	NativeEnemyRadar.sync(enemyRadarDesired or enemyRadarNative, enemyRadarNative)

	for _, upgradeName in ipairs(Logic.RADAR_UPGRADES) do
		local simulatedEnabled = desired[upgradeName] == true and not isNativelyOwned(upgradeName)
		local wasSimulated = simulatedUpgradeStates[upgradeName] == true
		if simulatedEnabled and not wasSimulated then
			fireUpgradeTransition(upgradeName, 1)
		elseif wasSimulated and not simulatedEnabled and not isNativelyOwned(upgradeName) then
			fireUpgradeTransition(upgradeName, 0)
		end
		simulatedUpgradeStates[upgradeName] = simulatedEnabled
	end

	-- Untag and retag "Voting" tagged instances to force the game's Altar listener to re-evaluate (RadarAltars)
	if desired["RadarAltars"] then
		local CollectionService = game:GetService("CollectionService")
		for _, instance in ipairs(CollectionService:GetTagged("Voting")) do
			pcall(function()
				CollectionService:RemoveTag(instance, "Voting")
				CollectionService:AddTag(instance, "Voting")
			end)
		end
	end
end

function Logic.shouldSpoofUpgradeEnabled(controller, upgradeName)
	if not controller or controller.RadarEnabled ~= true then
		return false
	end

	if isNativelyOwned(upgradeName) then
		return false
	end

	local desired = collectDesiredSimulatedUpgrades(controller)
	if desired[upgradeName] then
		return true, true
	end

	return false
end

function Logic.shouldSpoofUpgradeStack(controller, upgradeName)
	local shouldSpoof, enabled = Logic.shouldSpoofUpgradeEnabled(controller, upgradeName)
	if shouldSpoof then
		return true, enabled and 1 or 0
	end
	return false
end

function Logic.bindUpgradeWatcher(controller, onChanged)
	Logic.unbindUpgradeWatcher()
	upgradeWatcherController = controller
	task.spawn(function()
		local clientModules = ReplicatedFirst:WaitForChild("ClientModules", 15)
		local upgradeModule = clientModules and clientModules:FindFirstChild("UpgradeHandler")
		if upgradeModule then
			local ok, UpgradeHandler = pcall(require, upgradeModule)
			if ok and typeof(UpgradeHandler) == "table" and UpgradeHandler.UpgradesChanged then
				local connection = UpgradeHandler.UpgradesChanged:Connect(function()
					if upgradeWatcherController ~= controller or controller.Destroyed then
						return
					end
					Logic.syncSimulatedUpgradeHud(controller)
					if onChanged then
						onChanged()
					end
				end)
				if upgradeWatcherController ~= controller or controller.Destroyed then
					connection:Disconnect()
					return
				end
				upgradeWatcherConnection = connection
			end
		end
	end)
end

function Logic.unbindUpgradeWatcher(controller)
	if controller and upgradeWatcherController ~= controller then
		return
	end

	if upgradeWatcherConnection then
		pcall(function()
			upgradeWatcherConnection:Disconnect()
		end)
		upgradeWatcherConnection = nil
	end
	upgradeWatcherController = nil
end

function Logic.disableRadarSimulation()
	NativeEnemyRadar.sync(false, isNativelyOwned("EnemyOnTop"))

	for _, upgradeName in ipairs(Logic.RADAR_UPGRADES) do
		if simulatedUpgradeStates[upgradeName] == true and not isNativelyOwned(upgradeName) then
			fireUpgradeTransition(upgradeName, 0)
		end
		simulatedUpgradeStates[upgradeName] = false
	end

	local upgrades = getUpgradesFolder()
	if upgrades then
		for _, child in ipairs(upgrades:GetChildren()) do
			if child:GetAttribute(SIM_ATTR) and RADAR_UPGRADE_SET[child.Name] then
				removeSimulatedUpgradeInt(upgrades, child.Name)
			end
		end
	end
end

return Logic
