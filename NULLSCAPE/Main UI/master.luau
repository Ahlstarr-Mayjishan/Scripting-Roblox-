-- [[
--  NULLSCAPE Master Script (Modular Rayfield UI Edition)
--  Bootstraps runtime ownership, settings, UI modules, and update handling.
-- ]]

local getgenv = getgenv
local Game = game
local HttpService = Game:GetService("HttpService")

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

pcall(function()
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
			OperatorHackDropdown = {},
			SpringerHackDropdown = {},
			StatusImmunityDropdownV2 = {},
			EntityShieldBaitToggle = false,
			EntityShieldBaitChanceSlider = 0,
			ImmunitySkinwalkerToggle = false,
			KolonaHackDropdown = {},
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
			ImmunityScrapmawToggle = false,
			ImmunitynilEnemyToggle = false,
			ImmunitynilMirageToggle = false,
			AntiBonkToggle = false,
			IgnoreFakeCountToggle = false,
			BeaconMirageIdentifierToggle = false,
			PhysicalInteractionRangeGrapplePointSlider = 0,
			PhysicalInteractionRangeTriaOrbSlider = 0,
			PhysicalInteractionRangeJumpPadSlider = 0,
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
			GrappleAssistSafetyToggle = true,
			GrappleAssistSafetyRejectPenaltySlider = 74,
			GrappleAssistAnchorBiasToggle = true,
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
			GrappleDodgeThreatRangeSlider = 42,
			GrappleDodgeDangerRadiusSlider = 10,
			GrappleDodgeRangeSlider = 92,
			GrappleDodgeStrengthSlider = 1,
			GrappleSharkEscapeToggle = false,
			GrappleSharkEscapeRangeSlider = 26,
			GrappleSharkEscapeReelHoldSlider = 0.12,
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
			GrappleCatapultMultiplierSlider = 1,
			GrappleEasierVoidCastToggle = false,
			MatrixTetrahedronToggle = false,
			MomentumReductionSlider = 100,
			SpeedBuffSelectionsDropdown = {},
			AirJumpSelectionsDropdown = {},
			HelmetToggle = false,
			MiniatureHourglassToggle = false,
			AutoCollectGiftsToggle = false,
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
			GraceWingsAirControlSlider = 1,
			AdvancedGravityCoilToggle = false,
			AdvancedGravityCoilJumpPowerSlider = 28,
			BetterJumpPadToggle = false,
			BetterJumpPadPowerSlider = 100,
			InfiniteJumpToggle = false,
			AutomationGiftFarmToggle = false,
			AutomationCollectMedalToggle = false,
			AutomationGiftFarmRangeSlider = 60,
			AutomationGiftFarmReturnBeaconToggle = true,
			AutomationAltarSelectionsDropdown = {},
			AutomationPylonActivatorToggle = false,
			AutomationPylonActivatorReturnToggle = true,
			RuntimeUpdaterEnabledToggle = false,
			RuntimeUpdaterSilentToggle = false,
			PerformanceCullingDropdown = {},
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
		if type(currentSettings.OperatorHackDropdown) ~= "table" then
			currentSettings.OperatorHackDropdown = currentSettings.ImmunityOperatorToggle == true
				and { "Immunity" }
				or {}
			updated = true
		end
		if currentSettings.ImmunityOperatorToggle ~= nil then
			currentSettings.ImmunityOperatorToggle = nil
			updated = true
		end
		if type(currentSettings.ICBMHackDropdown) == "table" then
			for index, option in pairs(currentSettings.ICBMHackDropdown) do
				if option == "Burn effect (Curse)" then
					currentSettings.ICBMHackDropdown[index] = "Immune Scorched Earth"
					updated = true
				end
			end
		end
		if type(currentSettings.KolonaHackDropdown) ~= "table" then
			currentSettings.KolonaHackDropdown = {}
			updated = true
		end
		if type(currentSettings.PerformanceCullingDropdown) ~= "table" then
			currentSettings.PerformanceCullingDropdown = currentSettings.FPSBoostToggle == true
				and { "Low Graphics", "VFX" }
				or {}
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

		if currentSettings.AutoCollectGiftsToggle ~= false then
			currentSettings.AutoCollectGiftsToggle = false
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

local DEFAULT_ICON = 4483362458

local function normalizeIcon(icon)
	if typeof(icon) == "number" then
		return icon
	end
	if typeof(icon) == "string" then
		local assetId = string.match(icon, "^rbxassetid://(%d+)$")
		if assetId then
			return tonumber(assetId) or DEFAULT_ICON
		end
		return icon
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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local function getCharacterControlSnapshot(character)
	local snapshot = {
		HasCharacter = character ~= nil,
		HasHumanoidRootPart = false,
		HasHumanoid = false,
		RootAnchored = nil,
		HumanoidState = nil,
		PlatformStand = nil,
		Sit = nil,
		AutoRotate = nil,
		UsingAbility = nil,
		ChargingCheck = nil,
		AnimateDisabled = nil,
		DomaspControllingMouse = nil,
		MothGuiEnabled = nil,
		MothGuiCameraCloneCount = 0,
		DisabledTouchParts = {},
	}

	if not character then
		return snapshot
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	snapshot.HasHumanoidRootPart = hrp ~= nil
	if hrp then
		snapshot.RootAnchored = hrp.Anchored
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	snapshot.HasHumanoid = humanoid ~= nil
	if humanoid then
		snapshot.HumanoidState = tostring(humanoid:GetState())
		snapshot.PlatformStand = humanoid.PlatformStand
		snapshot.Sit = humanoid.Sit
		snapshot.AutoRotate = humanoid.AutoRotate
		snapshot.UsingAbility = humanoid:GetAttribute("UsingAbility")
	end
	snapshot.ChargingCheck = character:GetAttribute("ChargingCheck")

	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		snapshot.AnimateDisabled = animate.Disabled
	end

	snapshot.DomaspControllingMouse = shared.DomaspControllingMouse == true
	pcall(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local mothGui = playerGui and playerGui:FindFirstChild("MothGui")
		snapshot.MothGuiEnabled = mothGui and mothGui.Enabled or false
		if mothGui then
			for _, child in ipairs(mothGui:GetChildren()) do
				if child:IsA("Camera") then
					snapshot.MothGuiCameraCloneCount += 1
				end
			end
		end
	end)

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.CanTouch == false then
			table.insert(snapshot.DisabledTouchParts, descendant:GetFullName())
			if #snapshot.DisabledTouchParts >= 12 then
				break
			end
		end
	end

	return snapshot
end

local function isCelestialImmunityActive()
	local globals = getgenv()._NULLSCAPE_Globals
	local controller = globals and globals.activeEntitiesController
	return typeof(controller) == "table" and controller.CelestialImmune == true
end

local function recoverCelestialVisualLocks(reason)
	local didRecover = false

	pcall(function()
		RunService:UnbindFromRenderStep("MCRender")
	end)

	if shared.DomaspControllingMouse == true then
		shared.DomaspControllingMouse = false
		didRecover = true
	end

	pcall(function()
		UserInputService.MouseIconEnabled = true
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)

	pcall(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local mothGui = playerGui and playerGui:FindFirstChild("MothGui")
		local memory = mothGui and mothGui:FindFirstChild("Memory")
		local canvas = memory and memory:FindFirstChild("CanvasGroup")
		local playerViewport = canvas and canvas:FindFirstChild("Player")
		if playerViewport and playerViewport:IsA("ViewportFrame") and playerViewport.CurrentCamera then
			playerViewport.CurrentCamera = nil
			didRecover = true
		end
	end)

	pcall(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local mothGui = playerGui and playerGui:FindFirstChild("MothGui")
		if not mothGui then
			return
		end

		for _, child in ipairs(mothGui:GetChildren()) do
			if child:IsA("Camera") then
				child:Destroy()
				didRecover = true
			end
		end

		local memory = mothGui:FindFirstChild("Memory")
		local canvas = memory and memory:FindFirstChild("CanvasGroup")
		if canvas then
			canvas.GroupTransparency = 1
			canvas.BackgroundTransparency = 1
		end

		local ending = mothGui:FindFirstChild("Ending")
		if ending then
			local frame = ending:FindFirstChild("Frame")
			if frame and frame:IsA("GuiObject") then
				frame.BackgroundTransparency = 1
			end
			local image = ending:FindFirstChild("Image")
			if image and image:IsA("ImageLabel") then
				image.ImageTransparency = 1
			end
		end

		if mothGui.Enabled then
			mothGui.Enabled = false
			didRecover = true
		end
	end)

	if didRecover then
		local globals = getgenv()._NULLSCAPE_Globals
		if typeof(globals) == "table" then
			globals.LastCelestialVisualLockRecoveryAt = os.clock()
			globals.LastCelestialVisualLockRecoveryReason = reason or "Unknown"
			globals.LastCharacterControlSnapshot = getCharacterControlSnapshot(LocalPlayer.Character)
		end
	end

	return didRecover
end

local function startCelestialVisualLockGuard()
	local lockSince = nil
	local STALE_VISUAL_LOCK_TIMEOUT = 1.5

	task.spawn(function()
		while not Client.Destroyed do
			local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
			local mothGui = playerGui and playerGui:FindFirstChild("MothGui")
			local celestialActive = isCelestialImmunityActive()
			local hasMothLock = mothGui and mothGui.Enabled == true
			local hasMouseLock = shared.DomaspControllingMouse == true
			local hasCameraClone = false

			if mothGui then
				for _, child in ipairs(mothGui:GetChildren()) do
					if child:IsA("Camera") then
						hasCameraClone = true
						break
					end
				end
			end

			if hasMouseLock or hasCameraClone or (celestialActive and hasMothLock) then
				lockSince = lockSince or os.clock()
				if celestialActive or os.clock() - lockSince >= STALE_VISUAL_LOCK_TIMEOUT then
					recoverCelestialVisualLocks(celestialActive and "CelestialImmune" or "StaleCutsceneLock")
					lockSince = nil
				end
			else
				lockSince = nil
			end

			task.wait(0.2)
		end
	end)
end

function Client:GetCharacterControlSnapshot()
	return getCharacterControlSnapshot(Players.LocalPlayer and Players.LocalPlayer.Character)
end

function Client:ReleaseCharacterControl(options)
	local globals = getgenv()._NULLSCAPE_Globals
	if typeof(globals) == "table" then
		globals.LastCharacterControlReleaseRequest = {
			Reason = typeof(options) == "table" and options.Reason or "Unknown",
			At = os.clock(),
		}
	end
	return true
end

function Client:PrepareForRuntimeUpdate(reason)
	getgenv()._NULLSCAPE_PendingCharacterRelease = true
	self:ReleaseCharacterControl({ Reason = reason or "RuntimeUpdate" })
	return true
end

startCelestialVisualLockGuard()

if getgenv()._NULLSCAPE_PendingCharacterRelease == true then
	getgenv()._NULLSCAPE_PendingCharacterRelease = nil
end

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

function Client:LoadModule(moduleName, tabIcon, callback)
	local success, err = pcall(function()
		local newTab = self.Window:CreateTab(moduleName, tabIcon or 4483362458)
		self.Tabs[moduleName] = newTab

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
local remoteSourceCache = {}
local remoteSourceFetches = {}
local NIL_MODULE = {}
local GITHUB_RAW_ROOT = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/"
local REMOTE_PREFETCH_CONCURRENCY = 4
local REMOTE_FETCH_WAIT_TIMEOUT = 20

function Client:Destroy(reason)
	if self.Destroying or self.Destroyed then
		return false
	end

	self.Destroying = true
	self.Destroyed = true
	self.DestroyReason = reason or "Unknown"

	safeStep("cleanup modules", function()
		local destroyLogic = self.Modules and self.Modules.DestroyLogic
		if destroyLogic and typeof(destroyLogic.shutdown) == "function" then
			destroyLogic.shutdown(self, safeStep)
		end
	end)

	safeStep("cleanup fallback modules", function()
		if self.NativeStateRestored or not self.Modules then
			return
		end
		for name, module in pairs(self.Modules) do
			if typeof(module) == "table" then
				module.Destroyed = true
				if typeof(module.CleanUp) == "function" then
					safeStep("module " .. tostring(name), function()
						module:CleanUp()
					end)
				end
			end
		end
	end)

	safeStep("disconnect master connections", function()
		if self.ActiveConnections then
			for _, conn in pairs(self.ActiveConnections) do
				safeDisconnect(conn)
			end
			table.clear(self.ActiveConnections)
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
		if remoteSourceCache then
			table.clear(remoteSourceCache)
		end
		if remoteSourceFetches then
			table.clear(remoteSourceFetches)
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
	if typeof(source) == "string" and string.sub(source, 1, 3) == "\239\187\191" then
		source = string.sub(source, 4)
	end

	task.defer(function()
		Client:PrepareForRuntimeUpdate(reason or "HotRestart")
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
local function fetchRemoteSource(path)
	local cached = remoteSourceCache[path]
	if cached then
		return cached
	end

	local fetch = remoteSourceFetches[path]
	if fetch then
		local deadline = time() + REMOTE_FETCH_WAIT_TIMEOUT
		repeat
			task.wait()
		until fetch.Done or Client.Destroyed or time() >= deadline
		if fetch.Source then
			return fetch.Source
		end
		if not fetch.Done then
			error(Client.Destroyed and "Client destroyed" or ("Timed out downloading " .. tostring(path)))
		end
		error(fetch.Error or ("Failed to download " .. tostring(path)))
	end

	fetch = { Done = false }
	remoteSourceFetches[path] = fetch
	local success, source = pcall(function()
		return Game:HttpGet((GITHUB_RAW_ROOT .. path):gsub(" ", "%%20"))
	end)

	if Client.Destroyed then
		fetch.Error = "Client destroyed"
	elseif success and typeof(source) == "string" and #source > 0 then
		fetch.Source = source
		remoteSourceCache[path] = source
	else
		fetch.Error = tostring(source)
	end
	fetch.Done = true
	remoteSourceFetches[path] = nil

	if fetch.Source then
		return fetch.Source
	end
	error(fetch.Error or ("Failed to download " .. tostring(path)))
end

local function prefetchRemoteSources()
	task.spawn(function()
		local manifestSuccess, manifestSource = pcall(function()
			return Game:HttpGet((GITHUB_RAW_ROOT .. "NULLSCAPE/update_manifest.json"):gsub(" ", "%%20"))
		end)
		if not manifestSuccess or typeof(manifestSource) ~= "string" then
			return
		end

		local decodedSuccess, manifest = pcall(function()
			return HttpService:JSONDecode(manifestSource)
		end)
		local files = decodedSuccess and manifest and manifest.Files
		if typeof(files) ~= "table" then
			return
		end

		local queue = {}
		for _, entry in ipairs(files) do
			local path = entry and entry.Path
			if typeof(path) == "string" and path ~= "NULLSCAPE/Main UI/master.luau" then
				local isLocal = isfile and readfile and isfile(path)
				if not isLocal then
					table.insert(queue, path)
				end
			end
		end

		local nextIndex = 1
		local function worker()
			while true do
				if Client.Destroyed then
					return
				end
				local index = nextIndex
				nextIndex = index + 1
				local path = queue[index]
				if not path then
					return
				end
				pcall(fetchRemoteSource, path)
			end
		end

		for _ = 1, math.min(REMOTE_PREFETCH_CONCURRENCY, #queue) do
			task.spawn(worker)
		end
	end)
end

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
		return fetchRemoteSource(path)
	end)
	if not sourceSuccess then
		moduleLoading[path] = nil
		error("[NULLSCAPE] Failed to read module " .. tostring(path) .. ": " .. tostring(sourceResult), 2)
	end

	local source = sourceResult
	if typeof(source) == "string" and string.sub(source, 1, 3) == "\239\187\191" then
		source = string.sub(source, 4)
	end

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

prefetchRemoteSources()

local classContextLoaded, classContextResult = pcall(function()
	return loadModule("NULLSCAPE/Core/Class Context.luau")
end)
if classContextLoaded and typeof(classContextResult) == "table" then
	Client.Modules.ClassContext = classContextResult
	pcall(classContextResult.initialize)
else
	warn("[NULLSCAPE] Class context unavailable: " .. tostring(classContextResult))
end

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

local destroyLogicLoaded, destroyLogicError = pcall(function()
	Client.Modules.DestroyLogic = loadModule("NULLSCAPE/Setting/Destroy Logic.luau")
end)

if not destroyLogicLoaded then
	warn("[NULLSCAPE] Failed to load Destroy Logic: " .. tostring(destroyLogicError))
end

local fpsBoostLoaded, fpsBoostResult = pcall(function()
	return loadModule("NULLSCAPE/Setting/FPS Boost.luau")
end)
if fpsBoostLoaded and typeof(fpsBoostResult) == "table" then
	Client.Modules.FPSBoost = fpsBoostResult
else
	warn("[NULLSCAPE] FPS boost unavailable: " .. tostring(fpsBoostResult))
end

local ultimateFPSBoosterLoaded, ultimateFPSBoosterResult = pcall(function()
	return loadModule("NULLSCAPE/Setting/Ultimate FPS Booster.luau")
end)
if ultimateFPSBoosterLoaded and typeof(ultimateFPSBoosterResult) == "table" then
	Client.Modules.UltimateFPSBooster = ultimateFPSBoosterResult
else
	warn("[NULLSCAPE] Ultimate FPS booster unavailable: " .. tostring(ultimateFPSBoosterResult))
end

local settingsLoaded, settingsError = pcall(function()
	local SettingsTab = loadModule("NULLSCAPE/Setting/tab.luau")
	SettingsTab(Client)
end)

if not settingsLoaded then
	warn("[NULLSCAPE] Failed to load Settings: " .. tostring(settingsError))
end

getgenv()._NULLSCAPE_Booting = true
Rayfield:LoadConfiguration()
task.delay(2, function()
	if getgenv().Client == Client then
		getgenv()._NULLSCAPE_Booting = false
	end
end)
