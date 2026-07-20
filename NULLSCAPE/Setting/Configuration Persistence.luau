--!nocheck
-- Keeps Rayfield configuration durable even when its private autosave path stops writing.

local HttpService = game:GetService("HttpService")

local Persistence = {
	Active = false,
	Generation = 0,
	Rayfield = nil,
	ConfigFolder = "NULLSCAPE",
	ConfigFile = "NULLSCAPE/master_settings.rfld",
	LastEncoded = nil,
	LastError = nil,
	LastWarningAt = 0,
}

local SAVE_INTERVAL = 0.75
local WARNING_INTERVAL = 10

local function packColor(color)
	return {
		R = color.R * 255,
		G = color.G * 255,
		B = color.B * 255,
	}
end

local function getFlagValue(flag)
	if flag.Type == "ColorPicker" and typeof(flag.Color) == "Color3" then
		return packColor(flag.Color)
	end
	if flag.CurrentValue ~= nil then
		return flag.CurrentValue
	end
	if flag.CurrentKeybind ~= nil then
		return flag.CurrentKeybind
	end
	if flag.CurrentOption ~= nil then
		return flag.CurrentOption
	end
	if flag.Color ~= nil then
		return flag.Color
	end
	return nil
end

local function encodeFlags(rayfield)
	local flags = rayfield and rayfield.Flags
	if typeof(flags) ~= "table" then
		return nil, "Rayfield flags are unavailable"
	end

	local data = {}
	for name, flag in pairs(flags) do
		if typeof(name) == "string" and typeof(flag) == "table" then
			local value = getFlagValue(flag)
			if value ~= nil then
				data[name] = value
			end
		end
	end

	local success, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not success then
		return nil, tostring(encoded)
	end
	return encoded
end

local function reportFailure(reason)
	Persistence.LastError = tostring(reason)
	local now = os.clock()
	if Persistence.LastWarningAt == 0 or now - Persistence.LastWarningAt >= WARNING_INTERVAL then
		Persistence.LastWarningAt = now
		warn("[NULLSCAPE] Rayfield configuration save failed: " .. Persistence.LastError)
	end
end

function Persistence.flush(force)
	if not Persistence.Rayfield then
		return false, "Persistence is not initialized"
	end
	if not (makefolder and writefile) then
		return false, "Executor filesystem write support is unavailable"
	end

	local encoded, encodeError = encodeFlags(Persistence.Rayfield)
	if not encoded then
		reportFailure(encodeError)
		return false, encodeError
	end
	if not force and encoded == Persistence.LastEncoded then
		return true
	end

	pcall(makefolder, Persistence.ConfigFolder)
	local success, writeError = pcall(writefile, Persistence.ConfigFile, encoded)
	if not success then
		reportFailure(writeError)
		return false, tostring(writeError)
	end

	if readfile then
		local verified, content = pcall(readfile, Persistence.ConfigFile)
		if not verified or content ~= encoded then
			local reason = verified and "saved content verification failed" or tostring(content)
			reportFailure(reason)
			return false, reason
		end
	end

	Persistence.LastEncoded = encoded
	Persistence.LastError = nil
	return true
end

function Persistence.initialize(rayfield, options)
	Persistence.Generation += 1
	Persistence.Rayfield = rayfield
	Persistence.Active = typeof(rayfield) == "table"
	Persistence.LastEncoded = nil
	Persistence.LastError = nil

	if typeof(options) == "table" then
		Persistence.ConfigFolder = tostring(options.FolderName or Persistence.ConfigFolder)
		Persistence.ConfigFile = Persistence.ConfigFolder .. "/" .. tostring(options.FileName or "master_settings.rfld")
	end
	if not Persistence.Active then
		return false, "Rayfield is unavailable"
	end

	local generation = Persistence.Generation
	task.spawn(function()
		while Persistence.Active and Persistence.Generation == generation do
			task.wait(SAVE_INTERVAL)
			if Persistence.Active and Persistence.Generation == generation then
				Persistence.flush(false)
			end
		end
	end)

	local saved, reason = Persistence.flush(true)
	return saved, reason
end

function Persistence:CleanUp()
	if self.Active then
		self.flush(true)
	end
	self.Generation += 1
	self.Active = false
	self.Rayfield = nil
	local globals = getgenv()
	if globals._NULLSCAPE_ConfigurationPersistence == self then
		globals._NULLSCAPE_ConfigurationPersistence = nil
	end
end

local globals = getgenv()
local previous = globals._NULLSCAPE_ConfigurationPersistence
if previous and previous ~= Persistence and typeof(previous.CleanUp) == "function" then
	pcall(function()
		previous:CleanUp()
	end)
end
globals._NULLSCAPE_ConfigurationPersistence = Persistence

return Persistence
