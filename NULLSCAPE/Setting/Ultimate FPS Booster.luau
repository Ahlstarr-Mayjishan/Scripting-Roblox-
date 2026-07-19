--!nocheck
--[[
	NULLSCAPE - Ultimate FPS Booster
	Headless render mode dedicated to Auto Gift Farm.
	Collection and replication stay active; client rendering and enemy presentation do not.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Booster = {
	Enabled = false,
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
	OriginalGlobalShadows = nil,
	OriginalQualityLevel = nil,
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

local function disconnect(name)
	local connection = Booster.Connections[name]
	if connection then
		connection:Disconnect()
		Booster.Connections[name] = nil
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
	if Booster.RendererSuppressed then
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
	end
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
		if Booster.Enabled and camera.CFrame ~= PARKED_CAMERA_CFRAME then
			camera.CFrame = PARKED_CAMERA_CFRAME
		end
	end)
end

local function installCameraParking()
	parkCamera(Workspace.CurrentCamera)
	Booster.Connections.CurrentCamera = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if Booster.Enabled then
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
		if Booster.Enabled then
			return nil
		end
		return originalNew(...)
	end

	Booster.ProjectileHandler = handler
	Booster.OriginalProjectileNew = originalNew
	Booster.WrappedProjectileNew = wrappedNew
	handler.new = wrappedNew

	local cleared, clearError = pcall(handler.ClearProjectiles)
	if not cleared then
		uninstallProjectileSuppression()
		return false, "Active projectiles could not be cleared: " .. tostring(clearError)
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
		if Booster.Enabled and typeof(path) == "table" and path[1] == "Graphics" then
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
	Booster.EnemiesRoot = enemiesRoot
	Booster.Connections.EnemyAdded = enemiesRoot.DescendantAdded:Connect(function(instance)
		suspendIfVisualScript(instance, enemiesRoot)
		drainPositionRemote(instance, enemiesRoot)
	end)

	for _, instance in ipairs(enemiesRoot:GetDescendants()) do
		suspendIfVisualScript(instance, enemiesRoot)
		drainPositionRemote(instance, enemiesRoot)
	end
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
	disconnect("EnemiesRootAdded")
	Booster.EnemiesRoot = nil
	disconnectPositionDrains()
	restoreVisualScripts()
end

local function disableMechanisms()
	Booster.Enabled = false
	uninstallProjectileSuppression()
	uninstallGiftRenderSuppression()
	uninstallGraphicsSuppression()
	uninstallVisualSuspension()
	restoreCameras()
	restoreHeadlessRenderer()
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

	Booster.Enabled = true
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
		installHeadlessRenderer()
		installCameraParking()
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
