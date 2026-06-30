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
	GrappleMaxRange = 90,
	GrappleDisableGroundRelease = false,
	GrappleNoReelCooldown = false,
	GrappleSharkTailWindow = 0.25,
	GrappleJumpPadUsesBypassEnabled = false,
	ChargerTripmineAssistEnabled = false,
	ChargerTripmineMode = "Auto",
	ChargerTripmineDistance = 15,
	ChargerTripmineJitter = 2,
	Destroyed = false,
	PermanentConnections = {},
}

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

local function readSettings()
	if not (isfile and readfile and isfile(SETTINGS_FILE)) then
		return
	end

	local success, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if success and type(decoded) == "table" then
		Control.GrappleAirControlMultiplier = tonumber(decoded.GrappleAirControlMultiplierSlider) or Control.GrappleAirControlMultiplier
		Control.GrappleReelPullMultiplier = tonumber(decoded.GrappleReelPullMultiplierSlider) or Control.GrappleReelPullMultiplier
		Control.GrappleSharkTailPullMultiplier = tonumber(decoded.GrappleSharkTailPullMultiplierSlider) or Control.GrappleSharkTailPullMultiplier
		Control.GrappleMaxRange = tonumber(decoded.GrappleMaxRangeSlider) or Control.GrappleMaxRange
		Control.GrappleSharkTailWindow = tonumber(decoded.GrappleSharkTailWindowSlider) or Control.GrappleSharkTailWindow
		
		if decoded.GrappleDisableGroundRelease ~= nil then
			Control.GrappleDisableGroundRelease = not not decoded.GrappleDisableGroundRelease
		end
		if decoded.GrappleNoReelCooldown ~= nil then
			Control.GrappleNoReelCooldown = not not decoded.GrappleNoReelCooldown
		end
		if decoded.GrappleJumpPadUsesBypassEnabled ~= nil then
			Control.GrappleJumpPadUsesBypassEnabled = not not decoded.GrappleJumpPadUsesBypassEnabled
		end
		if decoded.ChargerTripmineAssistToggle ~= nil then
			Control.ChargerTripmineAssistEnabled = not not decoded.ChargerTripmineAssistToggle
		end
		if decoded.ChargerTripmineModeDropdown ~= nil then
			Control.ChargerTripmineMode = tostring(decoded.ChargerTripmineModeDropdown)
		end
		Control.ChargerTripmineDistance = tonumber(decoded.ChargerTripmineDistanceSlider) or Control.ChargerTripmineDistance
		Control.ChargerTripmineJitter = tonumber(decoded.ChargerTripmineJitterSlider) or Control.ChargerTripmineJitter
	end
end

local function saveSettings()
	if not (makefolder and writefile and readfile and isfile) then
		return
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
	data.GrappleMaxRangeSlider = Control.GrappleMaxRange
	data.GrappleDisableGroundRelease = Control.GrappleDisableGroundRelease
	data.GrappleNoReelCooldown = Control.GrappleNoReelCooldown
	data.GrappleSharkTailWindowSlider = Control.GrappleSharkTailWindow
	data.GrappleJumpPadUsesBypassEnabled = Control.GrappleJumpPadUsesBypassEnabled
	data.ChargerTripmineAssistToggle = Control.ChargerTripmineAssistEnabled
	data.ChargerTripmineModeDropdown = Control.ChargerTripmineMode
	data.ChargerTripmineDistanceSlider = Control.ChargerTripmineDistance
	data.ChargerTripmineJitterSlider = Control.ChargerTripmineJitter

	pcall(function()
		makefolder(SETTINGS_FOLDER)
		writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
	end)
end

function Control:initialize()
	if self.Destroyed then
		return false
	end

	if not claimActiveController(self) then
		warn("[NULLSCAPE] Class Adjustment control already claimed by another instance")
		return false
	end

	readSettings()

	local Executor = getgenv().loadModule("NULLSCAPE/Class Adjustment/Executor.luau")
	if Executor and typeof(Executor.enable) == "function" then
		Executor.enable()
	end
	if Executor and typeof(Executor.updateChargerTripmineAssist) == "function" then
		Executor.updateChargerTripmineAssist(self)
	end

	return true
end

function Control:CleanUp()
	local globals = getGlobals()
	local finalCleanup = self.Destroyed or (globals.activeClassAdjustmentController ~= nil and globals.activeClassAdjustmentController ~= self)

	if finalCleanup then
		local Executor = getgenv().loadModule("NULLSCAPE/Class Adjustment/Executor.luau")
		if Executor then
			if self.Destroyed and typeof(Executor.restore) == "function" then
				pcall(Executor.restore)
			elseif typeof(Executor.disable) == "function" then
				pcall(Executor.disable)
			end
		end
	end

	local GC = getgenv().loadModule("NULLSCAPE/Class Adjustment/GC.luau")
	if GC and typeof(GC.cleanAll) == "function" then
		pcall(GC.cleanAll)
	end

	if self.Destroyed and self.PermanentConnections then
		for _, conn in ipairs(self.PermanentConnections) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		table.clear(self.PermanentConnections)
	end

	if self.Destroyed and globals and globals.activeClassAdjustmentController == self then
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

function Control:SetGrappleMaxRange(value)
	self.GrappleMaxRange = math.clamp(tonumber(value) or 90, 90, 120)
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

	local Executor = getgenv().loadModule("NULLSCAPE/Class Adjustment/Executor.luau")
	if Executor and typeof(Executor.updateChargerTripmineAssist) == "function" then
		Executor.updateChargerTripmineAssist(self)
	end
end

function Control:SetChargerTripmineMode(value)
	self.ChargerTripmineMode = value or "Auto"
	saveSettings()

	local Executor = getgenv().loadModule("NULLSCAPE/Class Adjustment/Executor.luau")
	if Executor and typeof(Executor.updateChargerTripmineAssist) == "function" then
		Executor.updateChargerTripmineAssist(self)
	end
end

function Control:SetChargerTripmineDistance(value)
	self.ChargerTripmineDistance = math.clamp(tonumber(value) or 15, 5, 50)
	saveSettings()
end

function Control:SetChargerTripmineJitter(value)
	self.ChargerTripmineJitter = math.clamp(tonumber(value) or 2, 0, 10)
	saveSettings()
end

return Control
