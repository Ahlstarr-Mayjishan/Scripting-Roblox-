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
			BellHackDropdown = {},
			BellHackDropdownV2 = {},
			FleshHackDropdown = {},
			ImmunityMartToggle = false,
			ImmunityTelefraggerToggle = false,
			TelefraggerHackDropdown = {},
			ImmunityICBMToggle = false,
			ICBMHackDropdown = {},
			ImmunityGuardianToggle = false,
			SpringerHackDropdown = {},
			StatusImmunityDropdownV2 = {},
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
			ImmunitynilEnemyToggle = false,
			ImmunitynilMirageToggle = false,
			SpringerAutoJumpToggle = false,
			InfiniteAirJumpToggle = false,
			AntiBonkToggle = false,
			IgnoreFakeCountToggle = false,
			BeaconMirageIdentifierToggle = false,
			GrapplerStaminaModeDropdown = "Off",
			GrapplerStaminaRecoverySpeedSlider = 1,
			MomentumModeDropdown = "Off",
			MomentumDecaySlider = 4,
			MomentumSoftReductionSlider = 0.35,
			MomentumMaxHorizontalSpeedSlider = 500,
			MomentumMaxVerticalSpeedSlider = 500,
			GrappleAssistToggle = false,
			GrappleAssistStrengthSlider = 1,
			GrappleAssistCaptureAngleSlider = 45,
			GrappleAssistManualAnchorAngleSlider = 24,
			GrappleAssistRangeSlider = 500,
			GrappleAssistConfidenceGateToggle = true,
			GrappleAssistMinConfidenceScoreSlider = -35,
			GrappleAssistConfidenceMarginSlider = 5,
			GrappleAssistBiomeTuningToggle = true,
			GrappleAssistFailFeedbackToggle = true,
			GrappleAssistSpecialPriorityToggle = true,
			GrappleAnchorTargetingStyleDropdown = "Auto",
			GrappleAnchorPriorityGrapplePointSlider = 700,
			GrappleAnchorPriorityJumpPadSlider = 650,
			GrappleAnchorPriorityTriaOrbSlider = 620,
			GrappleAnchorPriorityBellSlider = 550,
			GrappleAssistTerrainPrioritySlider = 140,
			GrappleAssistSecondaryCastToggle = false,
			GrappleAssistSecondaryCastKeybind = "Q",
			GrappleVoidProtectionToggle = false,
			GrappleVoidProtectionHeightSlider = 24,
			GrappleVoidProtectionFallSpeedSlider = 85,
			GrappleTechniqueDropdown = {},
			GrappleReelSaverKeybind = "E",
			GrappleReelSaverSideRangeSlider = 26,
			GrappleReelSaverMinHeightSlider = 5,
			GrappleReelSaverMaxHeightSlider = 14,
			GrappleReelSaverClearanceSlider = 5,
			GrappleReelSaverReelHoldSlider = 0.16,
			GrappleVoidRescueAutoReelToggle = true,
			GrappleVoidRescueAutoSharkTailToggle = true,
			GrappleVoidRescueHeightSlider = 45,
			GrappleVoidRescueReelHoldSlider = 0.12,
			RailAssistSuiteToggle = false,
			RailAutoToggle = false,
			RailSpeedMultiplierSlider = 1.1,
			RailAutoDelaySlider = 1.5,
			RailAutoCaptureRangeSlider = 4,
			GrappleAirControlMultiplierSlider = 0,
			GrappleReelPullMultiplierSlider = 1.1,
			GrappleSharkTailPullMultiplierSlider = 1.1,
			GrappleJumpPadUsesBypassToggle = false,
			GrappleVirtualNinjaBeltToggle = false,
			GrappleVirtualSharkTailToggle = false,
			GrappleDisableGroundReleaseToggle = false,
			GrappleHookCastSpeedMultiplierSlider = 1,
			GrappleMaxRangeSlider = 90,
			GrappleEasierVoidCastToggle = false,
			MatrixTetrahedronToggle = false,
			MomentumReductionSlider = 100, -- Mặc định là 100% giảm quán tính
			SpeedBuffSelectionsDropdown = {},
			HelmetToggle = false,
			MiniatureHourglassToggle = false,
			AutoCollectGiftsToggle = false,
			AutomationMultiSelectDropdown = {},
			AutoCollectTargetsDropdown = { "Gift/GoldenGift", "Instrument (Cadence)" },
			AutoCollectRangeSlider = 20,
			AutoCollectInstrumentRangeSlider = 0,
			CollectMedalKeybind = "V",
			CollectMedalKeybindKeybind = "V",
			TripmineBarrierModeDropdown = "Off",
			TripmineBarrierCollectDelaySlider = 0.08,
			AutoCollectModeDropdown = "Legit",
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
			AutomationGiftFarmToggle = false,
			AutomationCollectMedalToggle = false,
			AutomationGiftFarmRangeSlider = 60,
			AutomationGiftFarmReturnBeaconToggle = true,
			AutomationAltarSelectionsDropdown = {},
			AutomationPylonActivatorToggle = false,
			AutomationPylonActivatorReturnToggle = true,
			RuntimeUpdaterEnabledToggle = false,
			RuntimeUpdaterSilentToggle = false,
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

		if currentSettings.BellHackDropdownV2 == nil and currentSettings.ImmunityBellToggle == true then
			currentSettings.BellHackDropdownV2 = { "Immunity" }
			updated = true
		end
		if currentSettings.TelefraggerHackDropdown == nil and currentSettings.ImmunityTelefraggerToggle == true then
			currentSettings.TelefraggerHackDropdown = { "Immunity" }
			updated = true
		end
		if currentSettings.ICBMHackDropdown == nil and currentSettings.ImmunityICBMToggle == true then
			currentSettings.ICBMHackDropdown = { "Immunity" }
			updated = true
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

-- Defensively clean old notification icon shims. Newer Rayfield/Fusion builds treat Icon as data,
-- so an Instance child named Icon can make ImageLabel.Image receive an Instance.
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
			if notif:IsA("Frame") then
				local icon = notif:FindFirstChild("Icon")
				if icon and icon:IsA("ImageLabel") and icon.Image == "" and icon.Visible == false then
					icon:Destroy()
				end
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

local DEFAULT_ICON = "rbxassetid://4483362458"

local function normalizeIcon(icon)
	if typeof(icon) == "string" then
		return icon
	end
	if typeof(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end
	return DEFAULT_ICON
end

do
	local originalNotify = Rayfield.Notify
	if typeof(originalNotify) == "function" then
		function Rayfield:Notify(options)
			if typeof(options) == "table" then
				options = table.clone(options)
				options.Icon = normalizeIcon(options.Icon)
			end
			return originalNotify(self, options)
		end
	end
end

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

do
	local originalCreateTab = Window.CreateTab
	if typeof(originalCreateTab) == "function" then
		function Window:CreateTab(name, icon, ...)
			return originalCreateTab(self, name, normalizeIcon(icon), ...)
		end
	end
end

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
local GITHUB_RAW_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/"

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

function Client:InvalidateModule(path)
	if typeof(path) ~= "string" then
		return false
	end
	moduleCache[path] = nil
	moduleLoading[path] = nil
	return true
end

function Client:InvalidateModulePrefix(prefix)
	if typeof(prefix) ~= "string" then
		return false
	end
	for path in pairs(moduleCache) do
		if typeof(path) == "string" and string.sub(path, 1, #prefix) == prefix then
			moduleCache[path] = nil
		end
	end
	for path in pairs(moduleLoading) do
		if typeof(path) == "string" and string.sub(path, 1, #prefix) == prefix then
			moduleLoading[path] = nil
		end
	end
	return true
end

function Client:HotRestart(reason)
	if self.Destroying or self.Destroyed then
		return false
	end

	local source = nil
	if readfile and isfile and isfile("NULLSCAPE/Main UI/master.luau") then
		local ok, result = pcall(readfile, "NULLSCAPE/Main UI/master.luau")
		if ok and typeof(result) == "string" and #result > 0 then
			source = result
		end
	end
	if not source then
		local ok, result = pcall(function()
			return Game:HttpGet((GITHUB_RAW_ROOT .. "NULLSCAPE/Main UI/master.luau"):gsub(" ", "%%20"))
		end)
		if ok and typeof(result) == "string" and #result > 0 then
			source = result
		end
	end
	if not source then
		return false
	end

	task.defer(function()
		Client:Destroy(reason or "HotRestart")
		task.wait(0.15)
		local chunk, err = loadstring(source)
		if not chunk then
			warn("[NULLSCAPE] Hot restart compile failed: " .. tostring(err))
			return
		end
		local ok, runtimeErr = pcall(chunk)
		if not ok then
			warn("[NULLSCAPE] Hot restart failed: " .. tostring(runtimeErr))
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

local function getRuntimeUpdater()
	local updater = Client.Modules and Client.Modules.RuntimeUpdater
	if updater then
		return updater
	end
	if getgenv().loadModule then
		local ok, result = pcall(function()
			return getgenv().loadModule("NULLSCAPE/Main UI/Updater.luau")
		end)
		if ok and typeof(result) == "table" then
			Client.Modules.RuntimeUpdater = result
			if typeof(result.initialize) == "function" then
				pcall(function()
					result:initialize(Client, {
						GithubRawRoot = GITHUB_RAW_ROOT,
						ManifestPath = "NULLSCAPE/update_manifest.json",
					})
				end)
			end
			return result
		end
	end
	return nil
end

SettingsTab:CreateSection("Runtime Updates")

SettingsTab:CreateToggle({
	Name = "Auto Runtime Update",
	CurrentValue = false,
	Flag = "RuntimeUpdaterEnabledToggle",
	Callback = function(Value)
		local updater = getRuntimeUpdater()
		if updater and typeof(updater.setAutoUpdateEnabled) == "function" then
			updater:setAutoUpdateEnabled(Value)
		end
	end,
})

SettingsTab:CreateToggle({
	Name = "Silent Update Install",
	CurrentValue = false,
	Flag = "RuntimeUpdaterSilentToggle",
	Callback = function(Value)
		local updater = getRuntimeUpdater()
		if updater and typeof(updater.setSilentInstall) == "function" then
			updater:setSilentInstall(Value)
		end
	end,
})

SettingsTab:CreateButton({
	Name = "Check Runtime Update",
	Callback = function()
		local updater = getRuntimeUpdater()
		if updater and typeof(updater.checkAndInstall) == "function" then
			task.spawn(function()
				updater:checkAndInstall(true)
			end)
		end
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
		if path == "NULLSCAPE/Automation/controller.luau" then
			return globals and globals.activeAutomationController or nil
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

		local url = (GITHUB_RAW_ROOT .. path):gsub(" ", "%%20")
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

local updaterLoaded, updaterResult = pcall(function()
	return loadModule("NULLSCAPE/Main UI/Updater.luau")
end)
if updaterLoaded and typeof(updaterResult) == "table" then
	Client.Modules.RuntimeUpdater = updaterResult
	pcall(function()
		updaterResult:initialize(Client, {
			GithubRawRoot = GITHUB_RAW_ROOT,
			ManifestPath = "NULLSCAPE/update_manifest.json",
		})
	end)
else
	warn("[NULLSCAPE] Runtime updater unavailable: " .. tostring(updaterResult))
end

-- Tải các module con
local success0, err0 = pcall(function()
	local AutomationController = loadModule("NULLSCAPE/Automation/controller.luau")
	Client.Modules["AutomationController"] = AutomationController
	local AutomationTab = loadModule("NULLSCAPE/Automation/tab.luau")

	AutomationTab(Client, AutomationController)
end)

if not success0 then
	warn("[NULLSCAPE] Lá»—i khi náº¡p module Automation: " .. tostring(err0))
end

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
