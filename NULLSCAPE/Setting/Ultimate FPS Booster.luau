--!nocheck
--[[
	NULLSCAPE - Ultimate FPS Booster
	Reversibly suppresses native client projectiles and suspends verified visual-only enemy scripts.
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")

local Booster = {
	Enabled = false,
	ProjectileHandler = nil,
	OriginalProjectileNew = nil,
	WrappedProjectileNew = nil,
	EnemiesRoot = nil,
	Connections = {},
	SuspendedScripts = setmetatable({}, { __mode = "k" }),
}

local VISUAL_SCRIPT_RULES = {
	Cadence = {
		Cadence_ClientAI = true,
	},
	Celestial = {
		Wobble = true,
	},
	Flesh = {
		Flesh_ClientAI = true,
	},
	Guardian = {
		Guardian_ClientAI = true,
	},
	ShadowGuardian = {
		ShadowGuardian_ClientAI = true,
	},
	Telefragger = {
		MirrorClient = true,
		Telefragger_ClientAI = true,
	},
	nilEnemy = {
		nilEnemy_ClientAI = true,
	},
	nilMirage = {
		nilMirage_ClientAI = true,
	},
}

local function disconnect(name)
	local connection = Booster.Connections[name]
	if connection then
		connection:Disconnect()
		Booster.Connections[name] = nil
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

local function getEnemyRoot(instance, enemiesRoot)
	if not instance:IsDescendantOf(enemiesRoot) then
		return nil
	end

	local current = instance.Parent
	while current and current.Parent ~= enemiesRoot do
		current = current.Parent
	end
	return current
end

local function suspendIfVisualScript(instance, enemiesRoot)
	if not Booster.Enabled or not instance:IsA("BaseScript") then
		return
	end

	local enemyRoot = getEnemyRoot(instance, enemiesRoot)
	local rules = enemyRoot and VISUAL_SCRIPT_RULES[enemyRoot.Name]
	if not rules or not rules[instance.Name] or Booster.SuspendedScripts[instance] ~= nil then
		return
	end

	Booster.SuspendedScripts[instance] = instance.Enabled
	instance.Enabled = false
end

local function restoreVisualScripts()
	for visualScript, wasEnabled in pairs(Booster.SuspendedScripts) do
		if visualScript.Parent then
			pcall(function()
				visualScript.Enabled = wasEnabled
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
	end)

	for _, instance in ipairs(enemiesRoot:GetDescendants()) do
		suspendIfVisualScript(instance, enemiesRoot)
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
	restoreVisualScripts()
end

function Booster.setEnabled(enabled)
	enabled = enabled == true
	if enabled and Booster.Enabled then
		return true
	end

	if not enabled then
		Booster.Enabled = false
		uninstallProjectileSuppression()
		uninstallVisualSuspension()
		return true
	end

	Booster.Enabled = true
	local installed, reason = installProjectileSuppression()
	if not installed then
		Booster.Enabled = false
		return false, reason
	end

	local visualInstalled, visualError = pcall(installVisualSuspension)
	if not visualInstalled then
		Booster.Enabled = false
		uninstallProjectileSuppression()
		uninstallVisualSuspension()
		return false, "Visual suspension could not be installed: " .. tostring(visualError)
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
