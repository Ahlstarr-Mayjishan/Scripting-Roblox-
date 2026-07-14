--!nocheck
-- [[
--  NULLSCAPE - Class Adjustment Control
--  Manages the state and settings of class-specific physics adjustments.
-- ]]

local HttpService = game:GetService("HttpService")

local SETTINGS_FOLDER = "NULLSCAPE"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/master_settings.json"

local Control = {
	GrappleAirControlMultiplier = 0,
	GrappleReelPullMultiplier = 1.1,
	GrappleSharkTailPullMultiplier = 1.1,
	GrappleHookCastSpeedMultiplier = 1,
	GrappleMaxRange = 90,
	GrappleEasierVoidCast = false,
	GrappleDisableGroundRelease = false,
	GrappleNoReelCooldown = false,
	GrappleSharkTailNoCooldown = false,
	GrappleSharkTailWindow = 0.25,
	GrappleJumpPadUsesBypassEnabled = false,
	ChargerTripmineAssistEnabled = false,
	ChargerTripmineMode = "Auto",
	ChargerTripmineDistance = 15,
	ChargerTripmineBatchDistance = 60,
	ChargerTripmineJitter = 2,
	ChargerSteeringAssistEnabled = false,
	ChargerSteeringAssistStrength = 50,
	ChargerCollisionGuardEnabled = false,
	GrappleInstantGroundCast = false,
	GrappleWallGlide = false,
	GrappleInstantMaxPull = false,
	GrappleCatapultMultiplier = 1,
	GrappleMomentumTransferPercent = 0,
	Destroyed = false,
	Initialized = false,
	PermanentConnections = {},
}

local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")
local Executor = getgenv().loadModule("NULLSCAPE/Class Adjustment/Executor.luau")
local GC = getgenv().loadModule("NULLSCAPE/Class Adjustment/GC.luau")
local pendingSettingsSave = nil
local settingsDirty = false
local SETTINGS_SAVE_DEBOUNCE = 0.25

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function claimActiveController(controller)
	local globals = getGlobals()
	if globals.activeClassAdjustmentController == nil then
		globals.activeClassAdjustmentController = controller
	end
	return globals.activeClassAdjustmentController == controller
end

local function normalizeChargerTripmineMode(value)
	value = tostring(value or "Auto")
	if value == "Passthrough" then
		return "PassBatch"
	end
	if value == "PassBatch" or value == "PreDetonate" or value == "Auto" then
		return value
	end
	return "Auto"
end

local function readSettings()
	if not (isfile and readfile and isfile(SETTINGS_FILE)) then
		return
	end

	local success, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if success and type(decoded) == "table" then
		Control.GrappleAirControlMultiplier = tonumber(decoded.GrappleAirControlMultiplierSlider)
			or Control.GrappleAirControlMultiplier
		Control.GrappleReelPullMultiplier = tonumber(decoded.GrappleReelPullMultiplierSlider)
			or Control.GrappleReelPullMultiplier
		Control.GrappleSharkTailPullMultiplier = tonumber(decoded.GrappleSharkTailPullMultiplierSlider)
			or Control.GrappleSharkTailPullMultiplier
		Control.GrappleHookCastSpeedMultiplier = tonumber(decoded.GrappleHookCastSpeedMultiplierSlider)
			or Control.GrappleHookCastSpeedMultiplier
		Control.GrappleMaxRange = math.clamp(tonumber(decoded.GrappleMaxRangeSlider) or Control.GrappleMaxRange, 0, 500)
		Control.GrappleSharkTailWindow = tonumber(decoded.GrappleSharkTailWindowSlider)
			or Control.GrappleSharkTailWindow

		if decoded.GrappleEasierVoidCast ~= nil then
			Control.GrappleEasierVoidCast = not not decoded.GrappleEasierVoidCast
		elseif decoded.GrappleVoidCastAssistSlider ~= nil then
			Control.GrappleEasierVoidCast = (tonumber(decoded.GrappleVoidCastAssistSlider) or 0) > 0
		end
		if decoded.GrappleDisableGroundRelease ~= nil then
			Control.GrappleDisableGroundRelease = not not decoded.GrappleDisableGroundRelease
		end
		if decoded.GrappleNoReelCooldown ~= nil then
			Control.GrappleNoReelCooldown = not not decoded.GrappleNoReelCooldown
		end
		if decoded.GrappleSharkTailNoCooldown ~= nil then
			Control.GrappleSharkTailNoCooldown = not not decoded.GrappleSharkTailNoCooldown
		end
		if decoded.GrappleJumpPadUsesBypassEnabled ~= nil then
			Control.GrappleJumpPadUsesBypassEnabled = not not decoded.GrappleJumpPadUsesBypassEnabled
		end
		if decoded.GrappleInstantGroundCast ~= nil then
			Control.GrappleInstantGroundCast = not not decoded.GrappleInstantGroundCast
		end
		if decoded.GrappleWallGlide ~= nil then
			Control.GrappleWallGlide = not not decoded.GrappleWallGlide
		end
		if decoded.GrappleInstantMaxPull ~= nil then
			Control.GrappleInstantMaxPull = not not decoded.GrappleInstantMaxPull
		end
		Control.GrappleCatapultMultiplier =
			math.clamp(tonumber(decoded.GrappleCatapultMultiplierSlider) or Control.GrappleCatapultMultiplier, 1, 3)
		Control.GrappleMomentumTransferPercent = tonumber(decoded.GrappleMomentumTransferSlider)
			or Control.GrappleMomentumTransferPercent
		if decoded.ChargerTripmineAssistToggle ~= nil then
			Control.ChargerTripmineAssistEnabled = not not decoded.ChargerTripmineAssistToggle
		end
		if decoded.ChargerTripmineModeDropdown ~= nil then
			Control.ChargerTripmineMode = normalizeChargerTripmineMode(decoded.ChargerTripmineModeDropdown)
		end
		Control.ChargerTripmineDistance = tonumber(decoded.ChargerTripmineDistanceSlider)
			or Control.ChargerTripmineDistance
		Control.ChargerTripmineBatchDistance = tonumber(decoded.ChargerTripmineBatchDistanceSlider)
			or Control.ChargerTripmineBatchDistance
		Control.ChargerTripmineJitter = tonumber(decoded.ChargerTripmineJitterSlider) or Control.ChargerTripmineJitter
		if decoded.ChargerSteeringAssistToggle ~= nil then
			Control.ChargerSteeringAssistEnabled = not not decoded.ChargerSteeringAssistToggle
		end
		Control.ChargerSteeringAssistStrength = math.clamp(
			tonumber(decoded.ChargerSteeringAssistStrengthSlider) or Control.ChargerSteeringAssistStrength,
			0,
			100
		)
		if decoded.ChargerCollisionGuardToggle ~= nil then
			Control.ChargerCollisionGuardEnabled = not not decoded.ChargerCollisionGuardToggle
		end
	end
end

local function writeSettings()
	if not (makefolder and writefile and readfile and isfile) then
		return false
	end

	local data = {}
	if isfile(SETTINGS_FILE) then
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(SETTINGS_FILE))
		end)
		if success and type(decoded) == "table" then
			data = decoded
		end
	end

	data.GrappleAirControlMultiplierSlider = Control.GrappleAirControlMultiplier
	data.GrappleReelPullMultiplierSlider = Control.GrappleReelPullMultiplier
	data.GrappleSharkTailPullMultiplierSlider = Control.GrappleSharkTailPullMultiplier
	data.GrappleHookCastSpeedMultiplierSlider = Control.GrappleHookCastSpeedMultiplier
	data.GrappleMaxRangeSlider = Control.GrappleMaxRange
	data.GrappleEasierVoidCast = Control.GrappleEasierVoidCast
	data.GrappleDisableGroundRelease = Control.GrappleDisableGroundRelease
	data.GrappleNoReelCooldown = Control.GrappleNoReelCooldown
	data.GrappleSharkTailNoCooldown = Control.GrappleSharkTailNoCooldown
	data.GrappleSharkTailWindowSlider = Control.GrappleSharkTailWindow
	data.GrappleJumpPadUsesBypassEnabled = Control.GrappleJumpPadUsesBypassEnabled
	data.GrappleInstantGroundCast = Control.GrappleInstantGroundCast
	data.GrappleWallGlide = Control.GrappleWallGlide
	data.GrappleInstantMaxPull = Control.GrappleInstantMaxPull
	data.GrappleCatapultMultiplierSlider = Control.GrappleCatapultMultiplier
	data.GrappleMomentumTransferSlider = Control.GrappleMomentumTransferPercent
	data.ChargerTripmineAssistToggle = Control.ChargerTripmineAssistEnabled
	data.ChargerTripmineModeDropdown = Control.ChargerTripmineMode
	data.ChargerTripmineDistanceSlider = Control.ChargerTripmineDistance
	data.ChargerTripmineBatchDistanceSlider = Control.ChargerTripmineBatchDistance
	data.ChargerTripmineJitterSlider = Control.ChargerTripmineJitter
	data.ChargerSteeringAssistToggle = Control.ChargerSteeringAssistEnabled
	data.ChargerSteeringAssistStrengthSlider = Control.ChargerSteeringAssistStrength
	data.ChargerCollisionGuardToggle = Control.ChargerCollisionGuardEnabled

	pcall(makefolder, SETTINGS_FOLDER)

	local success = pcall(function()
		writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
	end)
	if success then
		settingsDirty = false
	end
	return success
end

local function flushSettings()
	if pendingSettingsSave then
		pcall(task.cancel, pendingSettingsSave)
		pendingSettingsSave = nil
	end
	if settingsDirty then
		writeSettings()
	end
end

local function saveSettings()
	settingsDirty = true
	if pendingSettingsSave then
		pcall(task.cancel, pendingSettingsSave)
	end
	pendingSettingsSave = task.delay(SETTINGS_SAVE_DEBOUNCE, function()
		pendingSettingsSave = nil
		if not Control.Destroyed then
			writeSettings()
		end
	end)
end

function Control:initialize()
	if self.Destroyed then
		return false
	end
	if self.Initialized then
		return true
	end

	if not claimActiveController(self) then
		warn("[NULLSCAPE] Class Adjustment control already claimed by another instance")
		return false
	end
	getGlobals().ClassAdjustmentHookOwner = self

	readSettings()

	if Executor and typeof(Executor.enable) == "function" then
		Executor.enable()
	end
	if Executor and typeof(Executor.updateChargerTripmineAssist) == "function" then
		Executor.updateChargerTripmineAssist(self)
	end
	if Executor and typeof(Executor.updateChargerSteeringAssist) == "function" then
		Executor.updateChargerSteeringAssist(self)
	end
	if Executor and typeof(Executor.updateChargerCollisionGuard) == "function" then
		Executor.updateChargerCollisionGuard(self)
	end
	if ClassContext and typeof(ClassContext.subscribe) == "function" then
		local connection = ClassContext.subscribe(function()
			if not self.Destroyed and Executor and typeof(Executor.updateChargerTripmineAssist) == "function" then
				Executor.updateChargerTripmineAssist(self)
			end
			if not self.Destroyed and Executor and typeof(Executor.updateChargerSteeringAssist) == "function" then
				Executor.updateChargerSteeringAssist(self)
			end
			if not self.Destroyed and Executor and typeof(Executor.updateChargerCollisionGuard) == "function" then
				Executor.updateChargerCollisionGuard(self)
			end
		end)
		if connection then
			table.insert(self.PermanentConnections, connection)
		end
	end

	self.Initialized = true
	return true
end

function Control:CleanUp()
	local globals = getGlobals()
	local finalCleanup = self.Destroyed
		or (globals.activeClassAdjustmentController ~= nil and globals.activeClassAdjustmentController ~= self)
	local ownsHooks = globals.ClassAdjustmentHookOwner == nil or globals.ClassAdjustmentHookOwner == self

	if finalCleanup then
		flushSettings()
	end
	if finalCleanup and ownsHooks then
		if Executor then
			if typeof(Executor.restore) == "function" then
				pcall(Executor.restore)
			elseif typeof(Executor.disable) == "function" then
				pcall(Executor.disable)
			end
		end
		globals.ClassAdjustmentHookOwner = nil
	end

	if GC and typeof(GC.cleanAll) == "function" then
		pcall(GC.cleanAll)
	end

	if finalCleanup and self.PermanentConnections then
		for _, conn in ipairs(self.PermanentConnections) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		table.clear(self.PermanentConnections)
	end

	if finalCleanup then
		self.Initialized = false
	end
	if finalCleanup and globals and globals.activeClassAdjustmentController == self then
		globals.activeClassAdjustmentController = nil
	end
end

function Control:SetGrappleAirControlMultiplier(value)
	self.GrappleAirControlMultiplier = math.clamp(tonumber(value) or 0, 0, 10)
	saveSettings()
end

function Control:SetGrappleReelPullMultiplier(value)
	self.GrappleReelPullMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
	saveSettings()
end

function Control:SetGrappleSharkTailPullMultiplier(value)
	self.GrappleSharkTailPullMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
	saveSettings()
end

function Control:SetGrappleHookCastSpeedMultiplier(value)
	local numeric = tonumber(value)
	if numeric == nil then
		numeric = 1
	end
	self.GrappleHookCastSpeedMultiplier = math.clamp(numeric, 0, 10)
	saveSettings()
end

function Control:SetGrappleMaxRange(value)
	self.GrappleMaxRange = math.clamp(tonumber(value) or 90, 0, 500)
	saveSettings()
end

function Control:SetGrappleEasierVoidCast(value)
	self.GrappleEasierVoidCast = value == true
	saveSettings()
end

function Control:SetGrappleDisableGroundRelease(value)
	self.GrappleDisableGroundRelease = not not value
	saveSettings()
end

function Control:SetGrappleNoReelCooldown(value)
	self.GrappleNoReelCooldown = not not value
	saveSettings()
end

function Control:SetGrappleSharkTailNoCooldown(value)
	self.GrappleSharkTailNoCooldown = not not value
	saveSettings()
end

function Control:SetGrappleSharkTailWindow(value)
	self.GrappleSharkTailWindow = math.clamp(tonumber(value) or 0.25, 0.25, 1.0)
	saveSettings()
end

function Control:SetGrappleJumpPadUsesBypass(value)
	self.GrappleJumpPadUsesBypassEnabled = value == true
	saveSettings()
end

function Control:SetChargerTripmineAssist(value)
	self.ChargerTripmineAssistEnabled = value == true
	saveSettings()

	if Executor and typeof(Executor.updateChargerTripmineAssist) == "function" then
		Executor.updateChargerTripmineAssist(self)
	end
end

function Control:SetChargerTripmineMode(value)
	self.ChargerTripmineMode = normalizeChargerTripmineMode(value)
	saveSettings()

	if Executor and typeof(Executor.updateChargerTripmineAssist) == "function" then
		Executor.updateChargerTripmineAssist(self)
	end
end

function Control:SetChargerTripmineDistance(value)
	self.ChargerTripmineDistance = math.clamp(tonumber(value) or 15, 5, 50)
	saveSettings()
end

function Control:SetChargerTripmineBatchDistance(value)
	self.ChargerTripmineBatchDistance = math.clamp(tonumber(value) or 60, 20, 60)
	saveSettings()
end

function Control:SetChargerTripmineJitter(value)
	self.ChargerTripmineJitter = math.clamp(tonumber(value) or 2, 0, 10)
	saveSettings()
end

function Control:SetChargerSteeringAssist(value)
	self.ChargerSteeringAssistEnabled = value == true
	saveSettings()
	if Executor and typeof(Executor.updateChargerSteeringAssist) == "function" then
		Executor.updateChargerSteeringAssist(self)
	end
end

function Control:SetChargerSteeringAssistStrength(value)
	self.ChargerSteeringAssistStrength = math.clamp(tonumber(value) or 50, 0, 100)
	saveSettings()
end

function Control:SetChargerCollisionGuard(value)
	self.ChargerCollisionGuardEnabled = value == true
	saveSettings()
	if Executor and typeof(Executor.updateChargerCollisionGuard) == "function" then
		Executor.updateChargerCollisionGuard(self)
	end
end

function Control:SetGrappleInstantGroundCast(value)
	self.GrappleInstantGroundCast = value == true
	saveSettings()
end

function Control:SetGrappleWallGlide(value)
	self.GrappleWallGlide = value == true
	saveSettings()
end

function Control:SetGrappleInstantMaxPull(value)
	self.GrappleInstantMaxPull = value == true
	saveSettings()
end

function Control:SetGrappleCatapultMultiplier(value)
	self.GrappleCatapultMultiplier = math.clamp(tonumber(value) or 1, 1, 3)
	saveSettings()
end

function Control:SetGrappleMomentumTransferPercent(value)
	self.GrappleMomentumTransferPercent = math.clamp(tonumber(value) or 0, 0, 100)
	saveSettings()
end

return Control
