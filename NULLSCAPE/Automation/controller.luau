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

local characterAddedConnection = nil
local antiAnchorConnection = nil
local antiControlConnections = {}
local giftFarmContext = nil
local SERVER_ANCHOR_PING_GRACE = 0.08

local function getGiftFarmContext()
	if giftFarmContext then
		return giftFarmContext
	end

	local ok, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
	end)
	if ok and typeof(result) == "table" then
		giftFarmContext = result
	end
	return giftFarmContext
end

local function stopAntiAnchor()
	if antiAnchorConnection then
		pcall(function()
			antiAnchorConnection:Disconnect()
		end)
		antiAnchorConnection = nil
	end
	if characterAddedConnection then
		pcall(function()
			characterAddedConnection:Disconnect()
		end)
		characterAddedConnection = nil
	end
	for _, conn in ipairs(antiControlConnections) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	table.clear(antiControlConnections)
end

local function startAntiAnchor(controller)
	if characterAddedConnection then
		return
	end

	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end

	local function setupHrp(character)
		if not character then
			return
		end
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if not hrp then
			return
		end

		if antiAnchorConnection then
			pcall(function()
				antiAnchorConnection:Disconnect()
			end)
			antiAnchorConnection = nil
		end
		for _, conn in ipairs(antiControlConnections) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		table.clear(antiControlConnections)

		local function releaseIfGiftFarmActive()
			local globals = getgenv()._NULLSCAPE_Globals
			local movementLeaseActive = typeof(globals) == "table" and globals.GiftFarmMovementLeaseActive == true
			if not controller.GiftFarmEnabled or not movementLeaseActive then
				return
			end
			local context = getGiftFarmContext()
			if context and typeof(context.releaseCharacterControl) == "function" then
				context.releaseCharacterControl({
					SkipVelocityClear = true,
					SkipTouchRestore = true,
					SkipStateChange = true,
				})
			else
				pcall(function()
					hrp.Anchored = false
				end)
			end
		end

		antiAnchorConnection = hrp:GetPropertyChangedSignal("Anchored"):Connect(function()
			local context = getGiftFarmContext()
			local inRound = not context or (typeof(context.isInRound) == "function" and context.isInRound() == true)

			local deadVal = localPlayer and localPlayer:FindFirstChild("Dead")
			local isDead = deadVal and deadVal.Value == true

			local globals = getgenv()._NULLSCAPE_Globals
			local movementLeaseActive = typeof(globals) == "table" and globals.GiftFarmMovementLeaseActive == true
			if controller.GiftFarmEnabled and movementLeaseActive and hrp.Anchored and inRound and not isDead then
				task.delay(SERVER_ANCHOR_PING_GRACE, function()
					local latestGlobals = getgenv()._NULLSCAPE_Globals
					local latestLeaseActive = typeof(latestGlobals) == "table" and latestGlobals.GiftFarmMovementLeaseActive == true
					if controller.GiftFarmEnabled and latestLeaseActive and hrp and hrp.Parent and hrp.Anchored then
						releaseIfGiftFarmActive()
					end
				end)
			end
		end)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(antiControlConnections, humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
				if controller.GiftFarmEnabled and humanoid.PlatformStand then
					releaseIfGiftFarmActive()
				end
			end))
			table.insert(antiControlConnections, humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
				if controller.GiftFarmEnabled and humanoid.Sit then
					releaseIfGiftFarmActive()
				end
			end))
			table.insert(antiControlConnections, humanoid:GetPropertyChangedSignal("AutoRotate"):Connect(function()
				if controller.GiftFarmEnabled and not humanoid.AutoRotate then
					releaseIfGiftFarmActive()
				end
			end))
		end

		local globals = getgenv()._NULLSCAPE_Globals
		local movementLeaseActive = typeof(globals) == "table" and globals.GiftFarmMovementLeaseActive == true
		if controller.GiftFarmEnabled and movementLeaseActive and (
			hrp.Anchored
			or (humanoid and (humanoid.PlatformStand or humanoid.Sit))
		) then
			releaseIfGiftFarmActive()
		end
	end

	characterAddedConnection = localPlayer.CharacterAdded:Connect(setupHrp)
	if localPlayer.Character then
		task.spawn(setupHrp, localPlayer.Character)
	end
end

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
	GiftFarmStatus = "Idle",
	GiftFarmDetail = "",
	PylonActivatorEnabled = false,
	PylonActivatorReturnAfter = true,
	PylonActivatorHolding = false,
	PylonActivatorComplete = false,
	PylonActivatorStatus = "Idle",
	PylonActivatorDetail = "",
	AutomationSelections = {},
	AutoCompleteKolonaEnabled = false,
	AutoCompleteKolonaStatus = "Idle",
	AutoCompleteKolonaDetail = "",
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
		startAntiAnchor(self)
	else
		disableAntiAfk()
		stopAntiAnchor()
	end

	return callExecutor("update", self, GC)
end

function Controller:SetGiftFarmEnabled(value)
	local nextEnabled = value == true
	if self.GiftFarmEnabled ~= nextEnabled then
		self.GiftFarmRangeRevision = (tonumber(self.GiftFarmRangeRevision) or 0) + 1
	end
	self.GiftFarmEnabled = nextEnabled
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
	local selections = {}
	if typeof(value) == "table" then
		for _, altarName in ipairs(value) do
			if not table.find(selections, altarName) then
				table.insert(selections, altarName)
			end
		end
		for altarName, enabled in pairs(value) do
			if typeof(altarName) == "string" and enabled == true and not table.find(selections, altarName) then
				table.insert(selections, altarName)
			end
		end
	end
	self.AltarSelections = selections
	self.ConfigChanged:Fire()
	return true
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

function Controller:SetAutomationSelections(value)
	local selections = {}
	if typeof(value) == "table" then
		for _, selection in ipairs(value) do
			if typeof(selection) == "string" and not table.find(selections, selection) then
				table.insert(selections, selection)
			end
		end
		for selection, selected in pairs(value) do
			if typeof(selection) == "string" and selected == true and not table.find(selections, selection) then
				table.insert(selections, selection)
			end
		end
	end

	self.AutomationSelections = selections
	self.AutoCompleteKolonaEnabled = table.find(selections, "Auto Complete - Kolóna") ~= nil
	return self:update()
end

function Controller:SetAutoChooseThingsEnabled(value)
	self.AutoChooseThingsEnabled = value == true
	return self:update()
end

function Controller:SetAutoChooseThingSelections(value)
	local selections = {}
	if typeof(value) == "table" then
		for _, selection in ipairs(value) do
			if typeof(selection) == "string" and not table.find(selections, selection) then
				table.insert(selections, selection)
			end
		end
		for selection, selected in pairs(value) do
			if typeof(selection) == "string" and selected == true and not table.find(selections, selection) then
				table.insert(selections, selection)
			end
		end
	end

	self.AutoChooseThingSelections = selections
	return self:update()
end

function Controller:CleanUp()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	disableAntiAfk()
	stopAntiAnchor()
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
