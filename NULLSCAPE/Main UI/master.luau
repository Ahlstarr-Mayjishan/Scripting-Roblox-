-- [[
--  NULLSCAPE Master Script (Modular Rayfield UI Edition)
--  Đây là file điều khiển chính (Master loader). Các tính năng sẽ được thêm dưới dạng module.
-- ]]

-- Tự động dọn dẹp phiên chạy cũ trước khi chạy phiên mới
if getgenv().Client then
	pcall(function()
		local oldClient = getgenv().Client
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
}
getgenv().Client = Client

-- Tạo hoặc tự động cập nhật file cấu hình mặc định để ngăn Rayfield in cảnh báo console
pcall(function()
	local HttpService = game:GetService("HttpService")
	if makefolder and writefile and readfile and isfile then
		local folder = "NULLSCAPE"
		local file = folder .. "/master_settings.json"

		makefolder(folder)

		local defaultSettings = {
			RadarEnabledToggle = false,
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
			GrappleAssistSuiteToggle = false,
			GrappleAimAssistToggle = false,
			GrappleAimAssistStrengthDropdown = "Balanced",
			GrappleRescueAssistToggle = false,
			GrappleEmergencyProtectionToggle = false,
			GrappleVoidRescueToggle = true,
			GrappleWallSlamRescueToggle = false,
			GrappleEmergencyProtectionModeDropdown = "Manual",
			GrappleEmergencySpeedThresholdSlider = 220,
			GrappleEmergencyFallThresholdSlider = 125,
			GrappleAntiBonkToggle = false,
			GrappleSmartReelToggle = false,
			GrappleSmartReelModeDropdown = "Manual",
			GrappleSharkTailHelperToggle = false,
			GrappleSharkTailModeDropdown = "Manual",
			GrappleSharkTailStyleDropdown = "Balanced",
			GrappleMomentumGuardToggle = false,
			GrappleAirControlMultiplierSlider = 1.1,
			GrappleReelPullMultiplierSlider = 1.1,
			GrappleSharkTailPullMultiplierSlider = 1.1,
			GrappleJumpPadUsesBypassToggle = false,
			GrappleAdaptInputKeybind = "T",
			GrappleAimAssistTargetPriorityDropdown = "GrapplePoint",
			GrappleAimAssistRangePriorityDropdown = "Nearest",
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
			TripmineModeDropdown = "Blocker",
			ChargerTripmineAssistToggle = false,
			ChargerTripmineModeDropdown = "Auto",
			ChargerTripmineDistanceSlider = 15,
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
			AntiBonkToggle = "GrappleAntiBonkToggle",
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
			if currentSettings[k] == nil then
				currentSettings[k] = v
				updated = true
			elseif type(currentSettings[k]) ~= type(v) then
				currentSettings[k] = v
				updated = true
			end
		end

		if updated or not isfile(file) then
			writefile(file, HttpService:JSONEncode(currentSettings))
		end
	end
end)

-- Defensively patch Rayfield's Notification template to prevent "Icon is not a valid member of Frame" crash
task.spawn(function()
	local function patchRayfieldGui(gui)
		if not gui or not (gui:IsA("ScreenGui") and string.find(gui.Name:lower(), "rayfield")) then
			return
		end

		local notifications = gui:WaitForChild("Notifications", 10)
		if not notifications then
			return
		end

		local function patchNotification(notif)
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

		local conn = notifications.ChildAdded:Connect(patchNotification)
		gui.Destroying:Connect(function()
			conn:Disconnect()
		end)

		for _, child in ipairs(notifications:GetChildren()) do
			patchNotification(child)
		end
	end

	local CoreGui = game:GetService("CoreGui")
	local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10)

	if CoreGui then
		CoreGui.ChildAdded:Connect(patchRayfieldGui)
		for _, child in ipairs(CoreGui:GetChildren()) do
			task.spawn(patchRayfieldGui, child)
		end
	end
	if PlayerGui then
		PlayerGui.ChildAdded:Connect(patchRayfieldGui)
		for _, child in ipairs(PlayerGui:GetChildren()) do
			task.spawn(patchRayfieldGui, child)
		end
	end
end)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
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

local fpsConnection = RunService.RenderStepped:Connect(function()
	frameCount = frameCount + 1
	local now = os.clock()
	if now - lastTime >= 1 then
		fps = math.floor(frameCount / (now - lastTime))
		frameCount = 0
		lastTime = now
	end
end)
table.insert(Client.ActiveConnections, fpsConnection)

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

-- ==========================================
-- TAB: SETTINGS
-- ==========================================
local SettingsTab = Window:CreateTab("Settings", 4483362458)
Client.Tabs["Settings"] = SettingsTab



SettingsTab:CreateButton({
	Name = "Destroy UI",
	Callback = function()
		pcall(function()
			-- Đánh dấu Client đã bị hủy để dừng các luồng/vòng lặp
			Client.Destroyed = true

			-- 1. Hủy các kết nối hệ thống chính trong master
			if fpsConnection then
				pcall(function()
					fpsConnection:Disconnect()
				end)
			end
			for _, conn in pairs(Client.ActiveConnections) do
				if conn then
					pcall(function()
						conn:Disconnect()
					end)
				end
			end

			-- 2. Hủy các module con và giải phóng tài nguyên của chúng
			for name, module in pairs(Client.Modules) do
				if typeof(module) == "table" then
					module.Destroyed = true
					if typeof(module.CleanUp) == "function" then
						pcall(function()
							module:CleanUp()
						end)
					end
					pcall(function()
						table.clear(module)
					end)
				end
			end

			-- 3. Hủy UI Rayfield
			Rayfield:Destroy()

			-- 4. Giải phóng các biến môi trường toàn cục
			getgenv().Rayfield = nil
			getgenv().Client = nil
			getgenv().loadModule = nil
			getgenv()._NULLSCAPE_Globals = nil

			-- 5. Xóa sạch dữ liệu trong bảng Client chính
			table.clear(Client)

			-- 6. Thu gom rác (Garbage Collector) để giải phóng RAM & Memory hoàn toàn
			local cg = collectgarbage
			if cg then
				pcall(cg, "collect")
			end
		end)
	end,
})

local moduleCache = {}
local function loadModule(path)
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end

	local isLocal = not not (isfile and readfile and isfile(path))
	warn("[NULLSCAPE] Loading module: " .. tostring(path) .. " (local=" .. tostring(isLocal) .. ")")

	local source
	if isLocal then
		source = readfile(path)
	else
		local githubRawUrl = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/"
		local url = (githubRawUrl .. path):gsub(" ", "%%20")
		source = game:HttpGet(url)
	end

	local chunk, compileErr = loadstring(source)
	if not chunk then
		error("[NULLSCAPE] Compile failed in " .. tostring(path) .. ": " .. tostring(compileErr), 2)
	end

	local traceback = debug and debug.traceback or function(message)
		return tostring(message)
	end
	local success, result = xpcall(chunk, traceback)
	if not success then
		error("[NULLSCAPE] Runtime failed in " .. tostring(path) .. ":\n" .. tostring(result), 2)
	end

	if result == nil then
		warn("[NULLSCAPE] WARNING: Module " .. tostring(path) .. " returned nil!")
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

-- Tải cấu hình lưu trữ của Rayfield
Rayfield:LoadConfiguration()
