--!nocheck
-- [[
--  NULLSCAPE - Native Radar & Highlight Simulation Logic
--  Vai trò: Quản lý kích hoạt các tính năng định vị (Radar) và viền sáng (Highlight)
--  nativ của game thông qua cơ chế giả lập Upgrade.
-- ]]

local Logic = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local SIM_ATTR = "NULLSCAPE_Simulated"

Logic.RADAR_UPGRADES = {
	"HighlightGifts",
	"HighlightTripmines",
	"RadarInstruments",
	"RadarAltars",
	"RadarPlayer",
	"EnemyOnTop",
}

Logic.FEATURES = {
	Gift = { upgrade = "HighlightGifts" },
	Tripmine = { upgrade = "HighlightTripmines" },
	Cadence = { upgrade = "RadarInstruments" },
	Altar = { upgrade = "RadarAltars" },
	Player = { upgrade = "RadarPlayer" },
	Enemy = { upgrade = "EnemyOnTop" },
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
		if val and not val:GetAttribute(SIM_ATTR) and (val:IsA("ValueObject") or val:IsA("Attribute") or val:IsA("IntValue") or val:IsA("BoolValue")) then
			local value = 0
			pcall(function() value = val.Value or 0 end)
			if value > 0 or value == true then
				return true
			end
		end
	end

	return false
end

Logic.isNativelyOwned = isNativelyOwned

local function collectDesiredSimulatedUpgrades(controller)
	local desired = {}
	if not controller or controller.RadarEnabled ~= true then
		return desired
	end

	local features = controller.RadarFeatures or { "Gift", "Tripmine", "Cadance", "Altar", "Player", "Enemy" }
	local featureMap = {
		Gift = "HighlightGifts",
		Tripmine = "HighlightTripmines",
		Cadance = "RadarInstruments",
		Altar = "RadarAltars",
		Player = "RadarPlayer",
		Enemy = "EnemyOnTop",
	}

	for _, featureName in ipairs(features) do
		local upgradeName = featureMap[featureName]
		if upgradeName then
			desired[upgradeName] = true
		end
	end

	return desired
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

function Logic.syncSimulatedUpgradeHud(controller)
	if not controller or controller.Destroyed then
		return
	end

	local upgrades = getUpgradesFolder()
	if not upgrades then
		return
	end

	local desired = collectDesiredSimulatedUpgrades(controller)

	for _, child in ipairs(upgrades:GetChildren()) do
		if child:GetAttribute(SIM_ATTR) and not desired[child.Name] then
			removeSimulatedUpgradeInt(upgrades, child.Name)
		end
	end

	for upgradeName in pairs(desired) do
		ensureSimulatedUpgradeInt(upgrades, upgradeName)
	end

	-- Fire custom upgrade change signals for scripts listening via GetUpgradeChangedSignal (e.g. RadarInstruments/Cadence)
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and type(globals.customUpgradeEvents) == "table" then
		for _, name in ipairs(Logic.RADAR_UPGRADES) do
			local event = globals.customUpgradeEvents[name]
			if event then
				local isDesired = desired[name] == true
				pcall(function()
					event:Fire(isDesired and 1 or 0)
				end)
			end
		end
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

	-- Nếu người dùng đã thực sự mua nâng cấp này, nhường quyền kiểm soát lại cho game
	if isNativelyOwned(upgradeName) then
		return false
	end

	-- Kiểm tra nếu nâng cấp này nằm trong danh sách các mục được chọn
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
	task.spawn(function()
		local clientModules = ReplicatedFirst:WaitForChild("ClientModules", 15)
		local upgradeModule = clientModules and clientModules:FindFirstChild("UpgradeHandler")
		if upgradeModule then
			local ok, UpgradeHandler = pcall(require, upgradeModule)
			if ok and typeof(UpgradeHandler) == "table" and UpgradeHandler.UpgradesChanged then
				UpgradeHandler.UpgradesChanged:Connect(function()
					Logic.syncSimulatedUpgradeHud(controller)
					if onChanged then
						onChanged()
					end
				end)
			end
		end
	end)
end

-- Stubs to keep compatibility with executor/controller calls
function Logic.clearVisuals() end
function Logic.updateESPStyles() end

return Logic
