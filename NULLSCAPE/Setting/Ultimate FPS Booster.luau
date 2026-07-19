--!nocheck
--[[
	NULLSCAPE - Ultimate FPS Booster
	Headless render mode dedicated to Auto Gift Farm.
	Collection and replication stay active; client rendering and enemy presentation do not.
]]

local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Booster = {
	Enabled = false,
	LifecycleGeneration = 0,
	ProjectileHandler = nil,
	OriginalProjectileNew = nil,
	WrappedProjectileNew = nil,
	GiftRenderHandler = nil,
	OriginalGiftSetCFrame = nil,
	WrappedGiftSetCFrame = nil,
	SettingsHandler = nil,
	OriginalSettingsGet = nil,
	WrappedSettingsGet = nil,
	EnemiesRoot = nil,
	Connections = {},
	SuspendedScripts = setmetatable({}, { __mode = "k" }),
	PositionDrains = setmetatable({}, { __mode = "k" }),
	CameraStates = setmetatable({}, { __mode = "k" }),
	RendererSuppressed = false,
	CelestialPresentationActive = false,
	OriginalGlobalShadows = nil,
	OriginalQualityLevel = nil,
	BackgroundColor = Color3.fromRGB(24, 24, 24),
	BackgroundGui = nil,
	BackgroundFrame = nil,
}

local PARKED_CAMERA_CFRAME = CFrame.lookAt(Vector3.new(0, -10000000, 0), Vector3.new(0, -10000000, -1))
local HEADLESS_GRAPHICS = {
	CollapseVFX = false,
	FragileTilesVFX = false,
	GiftParticles = false,
	GiftRadarBillboard = false,
	HideTileDecoration = true,
	ScrollTextures = false,
}

local function destroyBackgroundOverlay()
	if Booster.BackgroundGui then
		pcall(function()
			Booster.BackgroundGui:Destroy()
		end)
	end
	Booster.BackgroundGui = nil
	Booster.BackgroundFrame = nil
end

local function installBackgroundOverlay()
	destroyBackgroundOverlay()

	local gui = Instance.new("ScreenGui")
	gui.Name = "NULLSCAPE_UltimateFPSBackground"
	gui.DisplayOrder = -10000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.Active = false
	frame.Selectable = false
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Booster.BackgroundColor
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 0
	frame.Parent = gui

	local parented = pcall(function()
		gui.Parent = CoreGui
	end)
	if not parented then
		local localPlayer = Players.LocalPlayer
		local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			gui:Destroy()
			return false
		end
		gui.Parent = playerGui
	end

	Booster.BackgroundGui = gui
	Booster.BackgroundFrame = frame
	return true
end

local function disconnect(name)
	local connection = Booster.Connections[name]
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
		Booster.Connections[name] = nil
	end
end

local function disconnectAll()
	for name, connection in pairs(Booster.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
		Booster.Connections[name] = nil
	end
end

local function runCleanupStep(name, callback)
	local success, err = pcall(callback)
	if not success then
		warn("[NULLSCAPE] Ultimate FPS cleanup failed at " .. name .. ": " .. tostring(err))
	end
end

local function installHeadlessRenderer()
	if Booster.OriginalGlobalShadows == nil then
		Booster.OriginalGlobalShadows = Lighting.GlobalShadows
	end
	Lighting.GlobalShadows = false

	pcall(function()
		local rendering = settings().Rendering
		if Booster.OriginalQualityLevel == nil then
			Booster.OriginalQualityLevel = rendering.QualityLevel
		end
		rendering.QualityLevel = Enum.QualityLevel.Level01
	end)

	Booster.RendererSuppressed = pcall(function()
		RunService:Set3dRenderingEnabled(false)
	end)
end

local function restoreHeadlessRenderer()
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
	end)
	Booster.RendererSuppressed = false

	if Booster.OriginalGlobalShadows ~= nil then
		Lighting.GlobalShadows = Booster.OriginalGlobalShadows
		Booster.OriginalGlobalShadows = nil
	end
	if Booster.OriginalQualityLevel ~= nil then
		pcall(function()
			settings().Rendering.QualityLevel = Booster.OriginalQualityLevel
		end)
		Booster.OriginalQualityLevel = nil
	end
end

local function parkCamera(camera)
	if not camera or Booster.CameraStates[camera] then
		return
	end

	Booster.CameraStates[camera] = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = PARKED_CAMERA_CFRAME
	camera.Focus = PARKED_CAMERA_CFRAME

	disconnect("CameraCFrame")
	Booster.Connections.CameraCFrame = camera:GetPropertyChangedSignal("CFrame"):Connect(function()
		if Booster.Enabled and not Booster.CelestialPresentationActive and camera.CFrame ~= PARKED_CAMERA_CFRAME then
			camera.CFrame = PARKED_CAMERA_CFRAME
		end
	end)
end

local function installCameraParking()
	disconnect("CurrentCamera")
	parkCamera(Workspace.CurrentCamera)
	Booster.Connections.CurrentCamera = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if Booster.Enabled and not Booster.CelestialPresentationActive then
			parkCamera(Workspace.CurrentCamera)
		end
	end)
end

local function restoreCameras()
	disconnect("CameraCFrame")
	disconnect("CurrentCamera")
	for camera, original in pairs(Booster.CameraStates) do
		if camera.Parent then
			pcall(function()
				camera.CameraSubject = original.CameraSubject
				camera.CFrame = original.CFrame
				camera.Focus = original.Focus
				camera.CameraType = original.CameraType
			end)
		end
		Booster.CameraStates[camera] = nil
	end
end

local function isCelestialDescendant(instance, enemiesRoot)
	local current = instance
	while current and current ~= enemiesRoot do
		if string.find(string.lower(current.Name), "celestial", 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hasLiveCelestial()
	local enemiesRoot = Booster.EnemiesRoot or Workspace:FindFirstChild("Enemies")
	if not enemiesRoot or not enemiesRoot.Parent then
		return false
	end

	for _, enemy in ipairs(enemiesRoot:GetChildren()) do
		if string.find(string.lower(enemy.Name), "celestial", 1, true) then
			return true
		end
	end
	return false
end

local function setCelestialPresentationActive(active, force)
	active = Booster.Enabled and active == true
	if Booster.CelestialPresentationActive == active and not force then
		return
	end

	Booster.CelestialPresentationActive = active
	if active then
		if Booster.BackgroundGui then
			Booster.BackgroundGui.Enabled = false
		end
		restoreCameras()
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		Booster.RendererSuppressed = false
		return
	end

	if Booster.BackgroundGui then
		Booster.BackgroundGui.Enabled = true
	end
	Booster.RendererSuppressed = pcall(function()
		RunService:Set3dRenderingEnabled(false)
	end)
	installCameraParking()
end

local function refreshCelestialPresentation(force)
	setCelestialPresentationActive(hasLiveCelestial(), force)
end

local function deferCelestialPresentationRefresh()
	local generation = Booster.LifecycleGeneration
	task.defer(function()
		if Booster.Enabled and Booster.LifecycleGeneration == generation then
			refreshCelestialPresentation()
		end
	end)
end

local function getProjectileHandler()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local projectileClient = clientModules and clientModules:FindFirstChild("ProjectileClient")
	local handlerScript = projectileClient and projectileClient:FindFirstChild("ProjectileClientHandler")
	if not handlerScript or not handlerScript:IsA("ModuleScript") then
		return nil, "ProjectileClientHandler was not found"
	end

	local success, handler = pcall(require, handlerScript)
	if not success or typeof(handler) ~= "table" then
		return nil, "ProjectileClientHandler could not be required: " .. tostring(handler)
	end
	if typeof(handler.new) ~= "function" or typeof(handler.ClearProjectiles) ~= "function" then
		return nil, "ProjectileClientHandler has an unsupported interface"
	end

	return handler
end

local function uninstallProjectileSuppression()
	local handler = Booster.ProjectileHandler
	if
		handler
		and Booster.WrappedProjectileNew
		and handler.new == Booster.WrappedProjectileNew
		and Booster.OriginalProjectileNew
	then
		handler.new = Booster.OriginalProjectileNew
	end

	Booster.ProjectileHandler = nil
	Booster.OriginalProjectileNew = nil
	Booster.WrappedProjectileNew = nil
end

local function installProjectileSuppression()
	local handler, reason = getProjectileHandler()
	if not handler then
		return false, reason
	end

	local originalNew = handler.new
	local wrappedNew = function(...)
		if Booster.Enabled and not Booster.CelestialPresentationActive then
			return nil
		end
		return originalNew(...)
	end

	Booster.ProjectileHandler = handler
	Booster.OriginalProjectileNew = originalNew
	Booster.WrappedProjectileNew = wrappedNew
	handler.new = wrappedNew

	if not Booster.CelestialPresentationActive then
		local cleared, clearError = pcall(handler.ClearProjectiles)
		if not cleared then
			uninstallProjectileSuppression()
			return false, "Active projectiles could not be cleared: " .. tostring(clearError)
		end
	end

	return true
end

local function uninstallGiftRenderSuppression()
	local renderHandler = Booster.GiftRenderHandler
	if
		renderHandler
		and Booster.WrappedGiftSetCFrame
		and renderHandler.SetCFrame == Booster.WrappedGiftSetCFrame
		and Booster.OriginalGiftSetCFrame
	then
		renderHandler.SetCFrame = Booster.OriginalGiftSetCFrame
	end

	Booster.GiftRenderHandler = nil
	Booster.OriginalGiftSetCFrame = nil
	Booster.WrappedGiftSetCFrame = nil
end

local function installGiftRenderSuppression()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local giftClient = clientModules and clientModules:FindFirstChild("GiftClient")
	local handlerScript = giftClient and giftClient:FindFirstChild("GiftClientHandler")
	if not handlerScript or not handlerScript:IsA("ModuleScript") then
		return false, "GiftClientHandler was not found"
	end

	local success, handler = pcall(require, handlerScript)
	local renderHandler = success and typeof(handler) == "table" and handler.RenderHandler or nil
	if typeof(renderHandler) ~= "table" or typeof(renderHandler.SetCFrame) ~= "function" then
		return false, "Gift render handler has an unsupported interface"
	end

	local originalSetCFrame = renderHandler.SetCFrame
	local wrappedSetCFrame = function(...)
		if Booster.Enabled then
			return
		end
		return originalSetCFrame(...)
	end

	Booster.GiftRenderHandler = renderHandler
	Booster.OriginalGiftSetCFrame = originalSetCFrame
	Booster.WrappedGiftSetCFrame = wrappedSetCFrame
	renderHandler.SetCFrame = wrappedSetCFrame
	return true
end

local function uninstallGraphicsSuppression()
	local handler = Booster.SettingsHandler
	if
		handler
		and Booster.WrappedSettingsGet
		and handler.Get == Booster.WrappedSettingsGet
		and Booster.OriginalSettingsGet
	then
		handler.Get = Booster.OriginalSettingsGet
	end

	Booster.SettingsHandler = nil
	Booster.OriginalSettingsGet = nil
	Booster.WrappedSettingsGet = nil
end

local function installGraphicsSuppression()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local core = clientModules and clientModules:FindFirstChild("Core")
	local playerData = core and core:FindFirstChild("PlayerData")
	local handlerScript = playerData and playerData:FindFirstChild("SettingsHandler")
	if not handlerScript or not handlerScript:IsA("ModuleScript") then
		return false, "SettingsHandler was not found"
	end

	local success, handler = pcall(require, handlerScript)
	if not success or typeof(handler) ~= "table" or typeof(handler.Get) ~= "function" then
		return false, "SettingsHandler has an unsupported interface"
	end

	local originalGet = handler.Get
	local wrappedGet = function(path, ...)
		if
			Booster.Enabled
			and not Booster.CelestialPresentationActive
			and typeof(path) == "table"
			and path[1] == "Graphics"
		then
			local override = HEADLESS_GRAPHICS[path[2]]
			if override ~= nil then
				return override
			end
		end
		return originalGet(path, ...)
	end

	Booster.SettingsHandler = handler
	Booster.OriginalSettingsGet = originalGet
	Booster.WrappedSettingsGet = wrappedGet
	handler.Get = wrappedGet
	return true
end

local function suspendIfVisualScript(instance, enemiesRoot)
	if not Booster.Enabled or not instance:IsA("BaseScript") then
		return
	end
	if isCelestialDescendant(instance, enemiesRoot) then
		return
	end

	if not instance:IsDescendantOf(enemiesRoot) or Booster.SuspendedScripts[instance] ~= nil then
		return
	end

	local state = {
		Enabled = instance.Enabled,
		Connection = nil,
	}
	Booster.SuspendedScripts[instance] = state
	instance.Enabled = false
	state.Connection = instance:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Booster.Enabled and instance.Enabled then
			instance.Enabled = false
		end
	end)
end

local function drainPositionRemote(instance, enemiesRoot)
	if
		not Booster.Enabled
		or not instance:IsA("RemoteEvent")
		or instance.Name ~= "UpdatePosition"
		or not instance:IsDescendantOf(enemiesRoot)
		or isCelestialDescendant(instance, enemiesRoot)
		or Booster.PositionDrains[instance] ~= nil
	then
		return
	end

	Booster.PositionDrains[instance] = instance.OnClientEvent:Connect(function() end)
end

local function disconnectPositionDrains()
	for remote, connection in pairs(Booster.PositionDrains) do
		pcall(function()
			connection:Disconnect()
		end)
		Booster.PositionDrains[remote] = nil
	end
end

local function restoreVisualScripts()
	for visualScript, state in pairs(Booster.SuspendedScripts) do
		if state.Connection then
			state.Connection:Disconnect()
		end
		if visualScript.Parent then
			pcall(function()
				visualScript.Enabled = state.Enabled
			end)
		end
		Booster.SuspendedScripts[visualScript] = nil
	end
end

local function attachEnemiesRoot(enemiesRoot)
	if not Booster.Enabled or Booster.EnemiesRoot == enemiesRoot then
		return
	end

	disconnect("EnemyAdded")
	disconnect("CelestialAdded")
	disconnect("CelestialRemoved")
	Booster.EnemiesRoot = enemiesRoot
	Booster.Connections.EnemyAdded = enemiesRoot.DescendantAdded:Connect(function(instance)
		suspendIfVisualScript(instance, enemiesRoot)
		drainPositionRemote(instance, enemiesRoot)
	end)
	Booster.Connections.CelestialAdded = enemiesRoot.ChildAdded:Connect(function()
		deferCelestialPresentationRefresh()
	end)
	Booster.Connections.CelestialRemoved = enemiesRoot.ChildRemoved:Connect(function()
		deferCelestialPresentationRefresh()
	end)

	for _, instance in ipairs(enemiesRoot:GetDescendants()) do
		suspendIfVisualScript(instance, enemiesRoot)
		drainPositionRemote(instance, enemiesRoot)
	end
	refreshCelestialPresentation()
end

local function installVisualSuspension()
	local enemiesRoot = Workspace:FindFirstChild("Enemies")
	if enemiesRoot then
		attachEnemiesRoot(enemiesRoot)
	end

	Booster.Connections.EnemiesRootAdded = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Enemies" then
			attachEnemiesRoot(child)
		end
	end)
end

local function uninstallVisualSuspension()
	disconnect("EnemyAdded")
	disconnect("CelestialAdded")
	disconnect("CelestialRemoved")
	disconnect("EnemiesRootAdded")
	Booster.EnemiesRoot = nil
	disconnectPositionDrains()
	restoreVisualScripts()
end

local function disableMechanisms()
	Booster.LifecycleGeneration += 1
	Booster.Enabled = false
	Booster.CelestialPresentationActive = false
	runCleanupStep("background", destroyBackgroundOverlay)
	runCleanupStep("renderer", restoreHeadlessRenderer)
	runCleanupStep("camera", restoreCameras)
	runCleanupStep("projectiles", uninstallProjectileSuppression)
	runCleanupStep("gift rendering", uninstallGiftRenderSuppression)
	runCleanupStep("graphics settings", uninstallGraphicsSuppression)
	runCleanupStep("enemy presentation", uninstallVisualSuspension)
	runCleanupStep("connections", disconnectAll)
end

function Booster.setBackgroundColor(color)
	if typeof(color) ~= "Color3" then
		return false, "Background color must be a Color3"
	end

	Booster.BackgroundColor = color
	if Booster.BackgroundFrame then
		Booster.BackgroundFrame.BackgroundColor3 = color
	end
	return true
end

function Booster.setEnabled(enabled)
	enabled = enabled == true
	if enabled and Booster.Enabled then
		return true
	end

	if not enabled then
		disableMechanisms()
		return true
	end

	Booster.LifecycleGeneration += 1
	Booster.Enabled = true
	Booster.CelestialPresentationActive = hasLiveCelestial()
	local installed, reason = installProjectileSuppression()
	if not installed then
		Booster.Enabled = false
		return false, reason
	end

	local giftInstalled, giftReason = installGiftRenderSuppression()
	if not giftInstalled then
		disableMechanisms()
		return false, giftReason
	end

	local graphicsInstalled, graphicsReason = installGraphicsSuppression()
	if not graphicsInstalled then
		disableMechanisms()
		return false, graphicsReason
	end

	local visualInstalled, visualError = pcall(installVisualSuspension)
	if not visualInstalled then
		disableMechanisms()
		return false, "Visual suspension could not be installed: " .. tostring(visualError)
	end

	local headlessInstalled, headlessError = pcall(function()
		installBackgroundOverlay()
		installHeadlessRenderer()
		installCameraParking()
		refreshCelestialPresentation(true)
	end)
	if not headlessInstalled then
		disableMechanisms()
		return false, "Headless renderer could not be installed: " .. tostring(headlessError)
	end
	return true
end

function Booster.CleanUp()
	Booster.setEnabled(false)
	local globals = getgenv()
	if globals._NULLSCAPE_UltimateFPSBooster == Booster then
		globals._NULLSCAPE_UltimateFPSBooster = nil
	end
end

local globals = getgenv()
local previous = globals._NULLSCAPE_UltimateFPSBooster
if previous and previous ~= Booster and typeof(previous.CleanUp) == "function" then
	pcall(previous.CleanUp)
end
globals._NULLSCAPE_UltimateFPSBooster = Booster

return Booster
