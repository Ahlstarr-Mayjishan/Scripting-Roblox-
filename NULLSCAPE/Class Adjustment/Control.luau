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

return Control
