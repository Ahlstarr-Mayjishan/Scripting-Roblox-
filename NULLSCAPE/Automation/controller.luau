--!nocheck
-- [[
--  NULLSCAPE - Automation Controller
--  Coordinates automation features and owns the Automation tab state.
-- ]]

local getgenv = getgenv

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local antiAfkConnection = nil

local function enableAntiAfk()
	if antiAfkConnection then
		return
	end
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	local ok, connection = pcall(function()
		return localPlayer.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0))
			end)
		end)
	end)
	if ok then
		antiAfkConnection = connection
	end
end

local function disableAntiAfk()
	if antiAfkConnection then
		pcall(function()
			antiAfkConnection:Disconnect()
		end)
		antiAfkConnection = nil
	end
end

local Executor = nil
local lastExecutorLoadError = nil

local function getExecutor()
	if typeof(Executor) == "table" then
		return Executor
	end

	local loaded, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Automation/executor.luau")
	end)
	if loaded and typeof(result) == "table" then
		Executor = result
		lastExecutorLoadError = nil
		return Executor
	end

	local loadError = tostring(result)
	if loadError ~= lastExecutorLoadError then
		lastExecutorLoadError = loadError
		warn("[NULLSCAPE] Automation executor unavailable: " .. loadError)
	end
	return nil
end

local gcLoaded, GC = pcall(function()
	return getgenv().loadModule("NULLSCAPE/Automation/GC.luau")
end)
if not gcLoaded or typeof(GC) ~= "table" then
	warn("[NULLSCAPE] Automation GC failed; using fallback cleaner: " .. tostring(GC))
	GC = {
		cleanAll = function() end,
	}
end

local function getGlobals()
	getgenv()._NULLSCAPE_Globals = getgenv()._NULLSCAPE_Globals or {}
	return getgenv()._NULLSCAPE_Globals
end

local function callExecutor(methodName, ...)
	local executor = getExecutor()
	local method = executor and executor[methodName]
	if typeof(method) ~= "function" then
		return false
	end

	local success, result = pcall(method, ...)
	if not success then
		warn("[NULLSCAPE] Automation executor call failed: " .. tostring(methodName) .. " -> " .. tostring(result))
		return false
	end

	return result ~= false
end

local Controller = {
	ConfigChanged = Instance.new("BindableEvent"),
	Destroyed = false,
	Initialized = false,
	GiftFarmEnabled = false,
	GiftFarmMode = "Normal (teleport)",
	CollectMedalEnabled = false,
	GiftFarmRange = 60,
	GiftFarmRangeRevision = 0,
	GiftFarmAdaptiveSuccessRate = 1,
	GiftFarmAdaptiveValidationWait = 0.08,
	GiftFarmAdaptiveRejects = 0,
	GiftFarmAdaptiveRetries = 0,
	GiftFarmGoldenComplete = false,
	GiftFarmReturnToBeaconAfterGolden = true,
	AltarSelections = {},
	GiftFarmRulesEnabled = false,
	GiftFarmNoTrackingEnabled = false,
	ChoiceWhitelist = {},
	ChoiceBlacklist = {},
	GiftFarmGoalMode = "Reach to Levels",
	GiftFarmTargetLevel = 100,
	GiftFarmMinLevel = 10,
	GiftFarmMaxLevel = 50,
	GiftFarmGoldenEfficiency = 100,
	GiftFarmWaitMinutes10To24 = 5,
	GiftFarmWaitMinutes25To49 = 10,
	GiftFarmWaitMinutes50Plus = 20,
	GiftFarmRepeatCount = 0,
	GiftFarmCompletedRuns = 0,
	GiftFarmActiveTargetLevel = nil,
	GiftFarmPolicyHolding = false,
	GiftFarmStatus = "Idle",
	GiftFarmDetail = "",
	PylonActivatorEnabled = false,
	PylonActivatorReturnAfter = true,
	PylonActivatorHolding = false,
	PylonActivatorComplete = false,
	PylonActivatorStatus = "Idle",
	PylonActivatorDetail = "",
	AutoChooseThingsEnabled = false,
	AutoChooseThingSelections = {},
	AutoChooseThingsStatus = "Idle",
	AutoChooseThingsDetail = "",
}

local function isControllerActiveOrUnclaimed(controller)
	local globals = getGlobals()
	return globals.activeAutomationController == controller or globals.activeAutomationController == nil
end

local function claimActiveController(controller)
	local globals = getGlobals()
	if globals.activeAutomationController == nil then
		globals.activeAutomationController = controller
	end
	return globals.activeAutomationController == controller
end

local function getUpgradeController(loadIfMissing)
	local globals = getGlobals()
	if globals and typeof(globals.activeUpgradeController) == "table" then
		return globals.activeUpgradeController
	end

	if loadIfMissing ~= true then
		return nil
	end

	local success, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Simulated Upgrades/controller.luau")
	end)
	if success and typeof(result) == "table" then
		return result
	end

	return nil
end

local function clampGiftRange(value)
	return math.clamp(tonumber(value) or 60, 5, 60)
end

local function normalizeSelections(value)
	local selections = {}
	if typeof(value) ~= "table" then
		return selections
	end

	for _, selection in ipairs(value) do
		if typeof(selection) == "string" and selection ~= "" and not table.find(selections, selection) then
			table.insert(selections, selection)
		end
	end
	for selection, enabled in pairs(value) do
		if typeof(selection) == "string" and enabled == true and not table.find(selections, selection) then
			table.insert(selections, selection)
		end
	end
	return selections
end

local function setConfigNumber(controller, key, value, minimum, maximum, fallback)
	local nextValue = math.clamp(math.floor(tonumber(value) or fallback), minimum, maximum)
	controller[key] = nextValue
	controller.ConfigChanged:Fire()
	return true
end

function Controller:initialize()
	if self.Destroyed then
		return false
	end
	if not isControllerActiveOrUnclaimed(self) then
		warn("[NULLSCAPE] Automation controller already claimed by another instance")
		return false
	end

	claimActiveController(self)
	self.Initialized = true
	callExecutor("enable", self, GC)
	return true
end

function Controller:update()
	if self.Destroyed then
		return false
	end
	if not isControllerActiveOrUnclaimed(self) then
		return false
	end

	claimActiveController(self)

	if self.GiftFarmEnabled then
		enableAntiAfk()
	else
		disableAntiAfk()
	end

	return callExecutor("update", self, GC)
end

function Controller:SetGiftFarmEnabled(value)
	local nextEnabled = value == true
	if self.GiftFarmEnabled ~= nextEnabled then
		self.GiftFarmRangeRevision = (tonumber(self.GiftFarmRangeRevision) or 0) + 1
	end
	self.GiftFarmEnabled = nextEnabled

	local upgradeController = getUpgradeController(true)
	if upgradeController then
		upgradeController.GiftMagnetBlocked = nextEnabled
		if nextEnabled then
			if typeof(upgradeController.SetAutoCollectEnabled) == "function" then
				pcall(function()
					upgradeController:SetAutoCollectEnabled(false)
				end)
			else
				upgradeController.AutoCollectEnabled = false
			end
		end
	end

	self.ConfigChanged:Fire()
	return self:update()
end

function Controller:SetGiftFarmMode(value)
	if self.GiftFarmMode == value then
		return true
	end

	self.GiftFarmRangeRevision = (tonumber(self.GiftFarmRangeRevision) or 0) + 1
	self.GiftFarmMode = value
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetGiftFarmRange(value)
	local range = clampGiftRange(value)
	if self.GiftFarmRange ~= range then
		self.GiftFarmRangeRevision = (tonumber(self.GiftFarmRangeRevision) or 0) + 1
	end
	self.GiftFarmRange = range

	local upgradeController = getUpgradeController()
	if upgradeController and typeof(upgradeController.SetAutoCollectGiftRange) == "function" then
		pcall(function()
			upgradeController:SetAutoCollectGiftRange(range)
		end)
	elseif upgradeController then
		upgradeController.AutoCollectGiftRange = range
		upgradeController.AutoCollectRange = range
	end

	self.ConfigChanged:Fire()
	return true
end

function Controller:GetGiftFarmRange()
	local upgradeController = getUpgradeController()
	if upgradeController then
		local linkedRange = upgradeController.AutoCollectGiftRange or upgradeController.AutoCollectRange
		if tonumber(linkedRange) then
			local range = clampGiftRange(linkedRange)
			self.GiftFarmRange = range
			return range
		end
	end

	return clampGiftRange(self.GiftFarmRange)
end

function Controller:SetGiftFarmReturnToBeaconAfterGolden(value)
	self.GiftFarmReturnToBeaconAfterGolden = value == true
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetAltarSelections(value)
	self.AltarSelections = normalizeSelections(value)
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetGiftFarmRulesEnabled(value)
	self.GiftFarmRulesEnabled = value == true
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetGiftFarmNoTrackingEnabled(value)
	self.GiftFarmNoTrackingEnabled = value == true
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetChoiceWhitelist(value)
	self.ChoiceWhitelist = normalizeSelections(value)
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetChoiceBlacklist(value)
	self.ChoiceBlacklist = normalizeSelections(value)
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetGiftFarmGoalMode(value)
	self.GiftFarmGoalMode = value == "Min-Max" and "Min-Max" or "Reach to Levels"
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetGiftFarmTargetLevel(value)
	return setConfigNumber(self, "GiftFarmTargetLevel", value, 0, 1000000000, 100)
end

function Controller:SetGiftFarmMinLevel(value)
	return setConfigNumber(self, "GiftFarmMinLevel", value, 0, 1000000000, 10)
end

function Controller:SetGiftFarmMaxLevel(value)
	return setConfigNumber(self, "GiftFarmMaxLevel", value, 0, 1000000000, 50)
end

function Controller:SetGiftFarmGoldenEfficiency(value)
	return setConfigNumber(self, "GiftFarmGoldenEfficiency", value, 0, 100, 100)
end

function Controller:SetGiftFarmWaitMinutes10To24(value)
	return setConfigNumber(self, "GiftFarmWaitMinutes10To24", value, 0, 30, 5)
end

function Controller:SetGiftFarmWaitMinutes25To49(value)
	return setConfigNumber(self, "GiftFarmWaitMinutes25To49", value, 0, 30, 10)
end

function Controller:SetGiftFarmWaitMinutes50Plus(value)
	return setConfigNumber(self, "GiftFarmWaitMinutes50Plus", value, 0, 30, 20)
end

function Controller:SetGiftFarmRepeatCount(value)
	return setConfigNumber(self, "GiftFarmRepeatCount", value, 0, 1000000, 0)
end

function Controller:SetCollectMedalEnabled(value)
	self.CollectMedalEnabled = value == true
	self.ConfigChanged:Fire()
	return true
end

function Controller:SetPylonActivatorEnabled(value)
	self.PylonActivatorEnabled = value == true
	return self:update()
end

function Controller:SetPylonActivatorReturnAfter(value)
	self.PylonActivatorReturnAfter = value == true
	return self:update()
end

function Controller:SetAutoChooseThingsEnabled(value)
	self.AutoChooseThingsEnabled = value == true
	return self:update()
end

function Controller:SetAutoChooseThingSelections(value)
	self.AutoChooseThingSelections = normalizeSelections(value)
	return self:update()
end

function Controller:CleanUp()
	if self.CleanedUp then
		return
	end

	self.CleanedUp = true
	self.Destroyed = true
	disableAntiAfk()
	callExecutor("disable", self, GC)
	if GC and typeof(GC.cleanAll) == "function" then
		GC.cleanAll()
	end

	if self.ConfigChanged then
		pcall(function()
			self.ConfigChanged:Destroy()
		end)
	end

	local globals = getGlobals()
	if globals.activeAutomationController == self then
		globals.activeAutomationController = nil
	end
end

function Controller:Destroy()
	self:CleanUp()
end

getGlobals().activeAutomationController = Controller
Controller:initialize()

return Controller
