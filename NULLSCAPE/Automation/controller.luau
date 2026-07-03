--!nocheck
-- [[
--  NULLSCAPE - Automation Controller
--  Coordinates automation features and owns the Automation tab state.
-- ]]

local getgenv = getgenv

local executorLoaded, Executor = pcall(function()
	return getgenv().loadModule("NULLSCAPE/Automation/executor.luau")
end)
if not executorLoaded or typeof(Executor) ~= "table" then
	warn("[NULLSCAPE] Automation executor failed; using fallback dispatcher: " .. tostring(Executor))
	Executor = {}
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
	local method = Executor and Executor[methodName]
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
	Destroyed = false,
	Initialized = false,
	GiftFarmEnabled = false,
	GiftFarmMode = "Golden Priority",
	GiftFarmRange = 60,
	GiftFarmBurstSize = 16,
	GiftFarmCollectsPerFrame = 8,
	GiftFarmTravelSpeed = 750,
	GiftFarmCollectSettle = 0.18,
	GiftFarmGoldenSpawnWait = 4,
	GiftFarmReturnAfterCluster = true,
	GiftFarmReturnToBeaconAfterGolden = true,
	AltarSelections = {},
	GiftFarmStatus = "Idle",
	GiftFarmDetail = "",
	PylonActivatorEnabled = false,
	PylonActivatorReturnAfter = true,
	PylonActivatorHolding = false,
	PylonActivatorStatus = "Idle",
	PylonActivatorDetail = "",
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

local function getUpgradeController()
	local globals = getGlobals()
	if globals and typeof(globals.activeUpgradeController) == "table" then
		return globals.activeUpgradeController
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
	return callExecutor("update", self, GC)
end

function Controller:SetGiftFarmEnabled(value)
	self.GiftFarmEnabled = value == true
	return self:update()
end

function Controller:SetGiftFarmMode(value)
	local mode = value
	if typeof(value) == "table" then
		mode = value[1]
	end
	self.GiftFarmMode = mode or "Golden Priority"
	return self:update()
end

function Controller:SetGiftFarmRange(value)
	local range = clampGiftRange(value)
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

	return self:update()
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

function Controller:SetGiftFarmBurstSize(value)
	self.GiftFarmBurstSize = math.clamp(tonumber(value) or 16, 1, 60)
	return self:update()
end

function Controller:SetGiftFarmCollectsPerFrame(value)
	self.GiftFarmCollectsPerFrame = math.clamp(tonumber(value) or 8, 1, 60)
	return self:update()
end

function Controller:SetGiftFarmTravelSpeed(value)
	self.GiftFarmTravelSpeed = math.clamp(tonumber(value) or 750, 150, 2000)
	return self:update()
end

function Controller:SetGiftFarmCollectSettle(value)
	self.GiftFarmCollectSettle = math.clamp(tonumber(value) or 0.18, 0.03, 0.6)
	return self:update()
end

function Controller:SetGiftFarmGoldenSpawnWait(value)
	self.GiftFarmGoldenSpawnWait = math.clamp(tonumber(value) or 4, 0, 10)
	return self:update()
end

function Controller:SetGiftFarmReturnAfterCluster(value)
	self.GiftFarmReturnAfterCluster = value == true
	return self:update()
end

function Controller:SetGiftFarmReturnToBeaconAfterGolden(value)
	self.GiftFarmReturnToBeaconAfterGolden = value == true
	return self:update()
end

function Controller:SetAltarSelections(value)
	local selections = {}
	if typeof(value) == "table" then
		for _, altarName in ipairs(value) do
			if not table.find(selections, altarName) then
				table.insert(selections, altarName)
			end
		end
	end
	self.AltarSelections = selections
	return self:update()
end

function Controller:SetPylonActivatorEnabled(value)
	self.PylonActivatorEnabled = value == true
	return self:update()
end

function Controller:SetPylonActivatorReturnAfter(value)
	self.PylonActivatorReturnAfter = value == true
	return self:update()
end

function Controller:CleanUp()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	callExecutor("disable", self, GC)
	if GC and typeof(GC.cleanAll) == "function" then
		GC.cleanAll()
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
