-- [[
--  NULLSCAPE Master Script (Modular Rayfield UI Edition)
--  Đây là file điều khiển chính (Master loader). Các tính năng sẽ được thêm dưới dạng module.
-- ]]

-- Tự động dọn dẹp phiên chạy cũ trước khi chạy phiên mới
local getgenv = getgenv
local Game = game :: any

if getgenv().Client then
	pcall(function()
		local oldClient = getgenv().Client
		if typeof(oldClient) == "table" and typeof(oldClient.Destroy) == "function" then
			oldClient:Destroy("Reload")
		else
			oldClient.Destroyed = true

			if oldClient.Modules then
				for _, module in pairs(oldClient.Modules) do
					if typeof(module) == "table" then
						module.Destroyed = true
						if typeof(module.CleanUp) == "function" then
							pcall(function()
								module:CleanUp()
							end)
						end
					end
				end
			end

			if oldClient.ActiveConnections then
				for _, conn in pairs(oldClient.ActiveConnections) do
					if conn then
						pcall(function()
							conn:Disconnect()
						end)
					end
				end
			end

			if getgenv().Rayfield then
				pcall(function()
					getgenv().Rayfield:Destroy()
				end)
			end
		end
	end)
end
getgenv()._NULLSCAPE_Globals = getgenv()._NULLSCAPE_Globals or {}

-- Đối tượng quản lý chung của Client
local Client = {
	Window = nil,
	Tabs = {},
	Modules = {},
	ActiveConnections = {},
	Destroyed = false,
	Destroying = false,
}
getgenv().Client = Client

local function safeDisconnect(conn)
	if conn then
		pcall(function()
			conn:Disconnect()
		end)
	end
end

local function trackConnection(conn)
	if conn and Client and type(Client.ActiveConnections) == "table" then
		table.insert(Client.ActiveConnections, conn)
	end
	return conn
end

local function safeStep(label, callback)
	local success, err = pcall(callback)
	if not success then
		warn("[NULLSCAPE] Destroy step failed: " .. tostring(label) .. " -> " .. tostring(err))
	end
	return success
end

-- Tạo hoặc tự động cập nhật file cấu hình mặc định để ngăn Rayfield in cảnh báo console
pcall(function()
	local HttpService = game:GetService("HttpService")
	if makefolder and writefile and readfile and isfile then
		local folder = "NULLSCAPE"
		local file = folder .. "/master_settings.json"

		makefolder(folder)

		local defaultSettings = {
			RadarEnabledToggle = false,
			RadarFeaturesDropdown = { "Gift", "Tripmine", "Cadance", "Altar", "Player", "Enemy" },
			ESPSelectionDropdown = {},
			ESPStyleDropdown = "Highlight",
			AltarFilterDropdown = "All",
			ImmunityBabyToggle = false,
			ImmunityBellToggle = false,
			ImmunityFleshToggle = false,
			ImmunityMartToggle = false,
			ImmunityTelefraggerToggle = false,
			ImmunityICBMToggle = false,
			ImmunityGuardianToggle = false,
			ImmunitySpringerToggle = false,
			ImmunitySkinwalkerToggle = false,
			ImmunityKolonaToggle = false,
			ImmunityOblivionToggle = false,
			ImmunityShadowBabyToggle = false,
			ImmunityQuartzToggle = false,
			ImmunitySigilToggle = false,
			ImmunitySlicerToggle = false,
			ImmunityVoidbreakerToggle = false,
			ImmunityRazorbloomToggle = false,
			ImmunityVoidImplosionToggle = false,
			ImmunityCadenceToggle = false,
			ImmunityCatalystToggle = false,
			ImmunityCelestialToggle = false,
			ImmunityOperatorToggle = false,
			ImmunityScrapmawToggle = false,
			SpringerAutoJumpToggle = false,
			InfiniteAirJumpToggle = false,
			AntiBonkToggle = false,
			GrapplerStaminaModeDropdown = "Off",
			RailAssistSuiteToggle = false,
			RailAutoToggle = false,
			RailSpeedMultiplierSlider = 1.1,
			RailAutoDelaySlider = 1.5,
			RailAutoCaptureRangeSlider = 4,
			GrappleAirControlMultiplierSlider = 0,
			GrappleReelPullMultiplierSlider = 1.1,
			GrappleSharkTailPullMultiplierSlider = 1.1,
			GrappleJumpPadUsesBypassToggle = false,
			SpringerImmunityModeDropdown = "Legit",
			MatrixTetrahedronToggle = false,
			MomentumReductionSlider = 100, -- Mặc định là 100% giảm quán tính
			SpeedBuffSelectionsDropdown = {},
			AutoCollectGiftsToggle = false,
			AutoCollectTargetsDropdown = { "Gift/GoldenGift", "Instrument (Cadence)" },
			AutoCollectRangeSlider = 20,
			AutoCollectInstrumentRangeSlider = 0,
			CollectMedalKeybind = "V",
			CollectMedalKeybindKeybind = "V",
			TripmineBarrierToggle = false,
			SimulateDefuseKitToggle = false,
			DefuseKitStackSlider = 3,
			AutoCollectModeDropdown = "Legit",
			TripmineModeDropdown = "Barrier",
			ChargerTripmineAssistToggle = false,
			ChargerTripmineModeDropdown = "Auto",
			ChargerTripmineDistanceSlider = 15,
			ChargerTripmineBatchDistanceSlider = 60,
			ChargerTripmineJitterSlider = 2,
			GraceWingsToggle = false,
			GraceWingsAirControlSlider = 1.1,
			GraceWingsStrongAirControlToggle = false,
			AdvancedGravityCoilToggle = false,
			AdvancedGravityCoilJumpPowerSlider = 28,
			BetterJumpPadToggle = false,
			BetterJumpPadPowerSlider = 100,
		}

		local currentSettings = {}
		if isfile(file) then
			local content = readfile(file)
			local success, decoded = pcall(function()
				return HttpService:JSONDecode(content)
			end)
			if success and type(decoded) == "table" then
				currentSettings = decoded
			end
		end

		local aliases = {
			CollectMedalKeybind = "CollectMedalKeybindKeybind",
		}

		local updated = false
		for newKey, oldKey in pairs(aliases) do
			if currentSettings[newKey] == nil and currentSettings[oldKey] ~= nil then
				currentSettings[newKey] = currentSettings[oldKey]
				updated = true
			end
		end

		for k, v in pairs(defaultSettings) do
			local currentValue = currentSettings[k]
			if currentValue == nil or type(currentValue) ~= type(v) then
				currentSettings[k] = v
				updated = true
			end
		end

		if
			type(currentSettings.GrappleAirControlMultiplierSlider) == "number"
			and currentSettings.GrappleAirControlMultiplierSlider > 0
			and currentSettings.GrappleAirControlMultiplierSlider <= 1.1
		then
			currentSettings.GrappleAirControlMultiplierSlider = 0
			updated = true
		end

		if updated or not isfile(file) then
			writefile(file, HttpService:JSONEncode(currentSettings))
		end
	end
end)

-- Defensively patch Rayfield's Notification template to prevent "Icon is not a valid member of Frame" crash
task.spawn(function()
	local function patchRayfieldGui(gui)
		if Client.Destroyed then
			return
		end
		if not gui or not (gui:IsA("ScreenGui") and string.find(gui.Name:lower(), "rayfield")) then
			return
		end

		local notifications = gui:WaitForChild("Notifications", 10)
		if not notifications then
			return
		end

		local function patchNotification(notif)
			if Client.Destroyed then
				return
			end
			if notif:IsA("Frame") and not notif:FindFirstChild("Icon") then
				local dummyIcon = Instance.new("ImageLabel")
				dummyIcon.Name = "Icon"
				dummyIcon.Image = ""
				dummyIcon.BackgroundTransparency = 1
				dummyIcon.ImageTransparency = 1
				dummyIcon.Visible = false
				dummyIcon.Parent = notif
			end
		end

		local template = notifications:WaitForChild("Template", 5)
		if template then
			patchNotification(template)
		end

		local conn = trackConnection(notifications.ChildAdded:Connect(patchNotification))
		trackConnection(gui.Destroying:Connect(function()
			safeDisconnect(conn)
		end))

		for _, child in ipairs(notifications:GetChildren()) do
			patchNotification(child)
		end
	end

	local CoreGui = game:GetService("CoreGui")
	local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10)

	if CoreGui then
		trackConnection(CoreGui.ChildAdded:Connect(patchRayfieldGui))
		for _, child in ipairs(CoreGui:GetChildren()) do
			task.spawn(patchRayfieldGui, child)
		end
	end
	if PlayerGui then
		trackConnection(PlayerGui.ChildAdded:Connect(patchRayfieldGui))
		for _, child in ipairs(PlayerGui:GetChildren()) do
			task.spawn(patchRayfieldGui, child)
		end
	end
end)

local Rayfield = loadstring(Game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().Rayfield = Rayfield

-- Dịch vụ Roblox phổ biến
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- FPS & Ping Tracker
local fps = 0
local ping = 0
local lastTime = os.clock()
local frameCount = 0

trackConnection(RunService.RenderStepped:Connect(function()
	frameCount = frameCount + 1
	local now = os.clock()
	if now - lastTime >= 1 then
		fps = math.floor(frameCount / (now - lastTime))
		frameCount = 0
		lastTime = now
	end
end))

task.spawn(function()
	while task.wait(2) do
		if Client.Destroyed then
			break
		end
		pcall(function()
			ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
		end)
	end
end)

-- Khởi tạo Window chính
local Window = Rayfield:CreateWindow({
	Name = "NULLSCAPE Client",
	LoadingTitle = "NULLSCAPE Loader",
	LoadingSubtitle = "by Antigravity AI",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "NULLSCAPE",
		FileName = "master_settings",
		AutoSave = true,
	},
	Discord = {
		Enabled = false,
		Invite = "nullscape",
		RememberJoins = true,
	},
	KeySystem = false,
})
Client.Window = Window

-- Hàm đăng ký các module tính năng
function Client:LoadModule(moduleName, tabIcon, callback)
	local success, err = pcall(function()
		local newTab = self.Window:CreateTab(moduleName, tabIcon or 4483362458)
		self.Tabs[moduleName] = newTab

		-- Thực thi callback để khởi tạo các phần tử UI và Logic của module
		if callback then
			callback(newTab, self)
		end
	end)

	if not success then
		warn("Lỗi khi tải module [" .. tostring(moduleName) .. "]: " .. tostring(err))
	end
end

-- ==========================================
-- TAB: DASHBOARD (HOME)
-- ==========================================
local HomeTab = Window:CreateTab("Home", 4483362458)
Client.Tabs["Home"] = HomeTab

HomeTab:CreateSection("Player Info")
HomeTab:CreateLabel("Account Name: " .. LocalPlayer.Name)
HomeTab:CreateLabel("Account Age: " .. LocalPlayer.AccountAge .. " days")

HomeTab:CreateSection("Server Info")
local statsLabel = HomeTab:CreateLabel("FPS: Calculating... | Ping: Calculating... | Players: 0/0")

task.spawn(function()
	while task.wait(1) do
		if Client.Destroyed then
			break
		end
		pcall(function()
			local playerCount = #Players:GetPlayers()
			local maxPlayers = Players.MaxPlayers
			statsLabel:Set(string.format("FPS: %d | Ping: %d ms | Players: %d/%d", fps, ping, playerCount, maxPlayers))
		end)
	end
end)

local moduleCache = {}
local moduleLoading = {}
local NIL_MODULE = {}

function Client:Destroy(reason)
	if self.Destroying or self.Destroyed then
		return false
	end

	self.Destroying = true
	self.Destroyed = true
	self.DestroyReason = reason or "Unknown"

	safeStep("disconnect master connections", function()
		if self.ActiveConnections then
			for _, conn in pairs(self.ActiveConnections) do
				safeDisconnect(conn)
			end
			table.clear(self.ActiveConnections)
		end
	end)

	safeStep("cleanup modules", function()
		if self.Modules then
			local modules = {}
			for name, module in pairs(self.Modules) do
				table.insert(modules, {
					Name = name,
					Module = module,
				})
			end

			for _, entry in ipairs(modules) do
				local name = entry.Name
				local module = entry.Module
				if typeof(module) == "table" then
					module.Destroyed = true
					if typeof(module.CleanUp) == "function" then
						safeStep("module " .. tostring(name), function()
							module:CleanUp()
						end)
					end
				end
			end
		end
	end)

	safeStep("destroy Rayfield", function()
		local rayfield = getgenv().Rayfield or Rayfield
		if rayfield and typeof(rayfield.Destroy) == "function" then
			rayfield:Destroy()
		end
	end)

	safeStep("release tables", function()
		if self.Modules then
			table.clear(self.Modules)
		end
		if self.Tabs then
			table.clear(self.Tabs)
		end
		if moduleCache then
			table.clear(moduleCache)
		end
		if moduleLoading then
			table.clear(moduleLoading)
		end
	end)

	safeStep("release globals", function()
		if getgenv().Client == self then
			getgenv().Client = nil
		end
		getgenv().Rayfield = nil
		getgenv().loadModule = nil
		getgenv()._NULLSCAPE_Globals = nil
	end)

	safeStep("collect garbage", function()
		if collectgarbage then
			pcall(collectgarbage, "collect")
		end
	end)

	return true
end
-- ==========================================
-- TAB: SETTINGS
-- ==========================================
local SettingsTab = Window:CreateTab("Settings", 4483362458)
Client.Tabs["Settings"] = SettingsTab

SettingsTab:CreateButton({
	Name = "Destroy UI",
	Callback = function()
		Client:Destroy("User")
	end,
})

local function loadModule(path)
	if moduleCache[path] ~= nil then
		local cached = moduleCache[path]
		if cached == NIL_MODULE then
			return nil
		end
		return cached
	end

	if moduleLoading[path] then
		local globals = getgenv()._NULLSCAPE_Globals
		if path == "NULLSCAPE/Accessibility/controller.luau" then
			return globals and globals.activeAccessibilityController or nil
		end
		if path == "NULLSCAPE/Entities/controller.luau" then
			return globals and globals.activeEntitiesController or nil
		end
		if path == "NULLSCAPE/Simulated Upgrades/controller.luau" then
			return globals and globals.activeUpgradeController or nil
		end
		if path == "NULLSCAPE/Class Adjustment/Control.luau" then
			return globals and globals.activeClassAdjustmentController or nil
		end
		warn("[NULLSCAPE] Skipping re-entrant module load: " .. tostring(path))
		return nil
	end

	local isLocal = not not (isfile and readfile and isfile(path))
	warn("[NULLSCAPE] Loading module: " .. tostring(path) .. " (local=" .. tostring(isLocal) .. ")")
	moduleLoading[path] = true

	local sourceSuccess, sourceResult = pcall(function()
		if isLocal then
			local content = readfile(path)
			if content and #content:gsub("%s+", "") > 0 then
				return content
			else
				warn("[NULLSCAPE] Local file " .. tostring(path) .. " is empty or invalid, falling back to GitHub!")
			end
		end

		local githubRawUrl = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/"
		local url = (githubRawUrl .. path):gsub(" ", "%%20")
		return Game:HttpGet(url)
	end)
	if not sourceSuccess then
		moduleLoading[path] = nil
		error("[NULLSCAPE] Failed to read module " .. tostring(path) .. ": " .. tostring(sourceResult), 2)
	end

	local source = sourceResult

	local chunk, compileErr = loadstring(source)
	if not chunk then
		moduleLoading[path] = nil
		error("[NULLSCAPE] Compile failed in " .. tostring(path) .. ": " .. tostring(compileErr), 2)
	end

	local traceback = debug and debug.traceback or function(message)
		return tostring(message)
	end
	local success, result = xpcall(chunk, traceback)
	moduleLoading[path] = nil
	if not success then
		error("[NULLSCAPE] Runtime failed in " .. tostring(path) .. ":\n" .. tostring(result), 2)
	end

	if result == nil then
		error(
			"[NULLSCAPE] Module "
				.. tostring(path)
				.. " returned nil! This indicates a file reading or download failure (such as an empty file or network block).",
			2
		)
	end

	moduleCache[path] = result
	return result
end
getgenv().loadModule = loadModule

-- Tải các module con
local success, err = pcall(function()
	local EntitiesController = loadModule("NULLSCAPE/Entities/controller.luau")
	Client.Modules["EntitiesController"] = EntitiesController
	local EntitiesTab = loadModule("NULLSCAPE/Entities/tab.luau")

	EntitiesTab(Client, EntitiesController)
end)

if not success then
	warn("[NULLSCAPE] Lỗi khi nạp module Entities: " .. tostring(err))
end

local success2, err2 = pcall(function()
	local UnlockController = loadModule("NULLSCAPE/Simulated Upgrades/controller.luau")
	Client.Modules["UnlockController"] = UnlockController
	local UnlockTab = loadModule("NULLSCAPE/Simulated Upgrades/tab.luau")

	UnlockTab(Client, UnlockController)
end)

if not success2 then
	warn("[NULLSCAPE] Lỗi khi nạp module Simulated Upgrades/Radar: " .. tostring(err2))
end

local success3, err3 = pcall(function()
	local AccessibilityController = loadModule("NULLSCAPE/Accessibility/controller.luau")
	Client.Modules["AccessibilityController"] = AccessibilityController
	local AccessibilityTab = loadModule("NULLSCAPE/Accessibility/tab.luau")

	AccessibilityTab(Client, AccessibilityController)
end)

if not success3 then
	warn("[NULLSCAPE] Lỗi khi nạp module Accessibility: " .. tostring(err3))
end

local success4, err4 = pcall(function()
	local ClassAdjustmentController = loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	Client.Modules["ClassAdjustmentController"] = ClassAdjustmentController
	ClassAdjustmentController:initialize()
	local ClassAdjustmentTab = loadModule("NULLSCAPE/Class Adjustment/tab.luau")

	ClassAdjustmentTab(Client, ClassAdjustmentController)
end)

if not success4 then
	warn("[NULLSCAPE] Lỗi khi nạp module Class Adjustment: " .. tostring(err4))
end

-- Tải cấu hình lưu trữ của Rayfield
Rayfield:LoadConfiguration()
