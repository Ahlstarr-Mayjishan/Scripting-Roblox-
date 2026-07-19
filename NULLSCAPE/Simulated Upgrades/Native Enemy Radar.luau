--!nocheck
-- [[
--  NULLSCAPE - Native Enemy Radar Adapter
--  Replays the game's spriteManager callback for enemies that already exist when
--  EnemyOnTop becomes available. Future enemies remain owned by the native listener.
-- ]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Adapter = {
	Enabled = false,
	PreserveNativeMarkers = false,
	RefreshGeneration = 0,
}

local pendingEnemies = setmetatable({}, { __mode = "k" })
local REFRESH_DELAYS = { 0, 0.1, 0.35, 1 }

local DIRECT_EXECUTOR_FUNCTIONS = {
	getconnections = getconnections,
	getfenv = getfenv,
}

local EXCLUDED_ENEMIES = {
	nilEnemy = true,
	nilMirage = true,
	Celestial = true,
	MothSpectator = true,
	CatalystHand = true,
}

local DISPLAY_NAMES = {
	shadowguardian = "voidboundguardian",
	shadowbaby = "voidboundbaby",
	skinwalker = "husk",
	mirage = "???",
}

local function getExecutorFunction(name)
	local captured = DIRECT_EXECUTOR_FUNCTIONS[name]
	if typeof(captured) == "function" then
		return captured
	end

	local environment = getgenv()
	local direct = environment[name]
	if typeof(direct) == "function" then
		return direct
	end

	local debugLibrary = environment.debug or debug
	local debugFunction = debugLibrary and debugLibrary[name]
	return typeof(debugFunction) == "function" and debugFunction or nil
end

local function getEnemiesFolder()
	return Workspace:FindFirstChild("Enemies")
end

local function getSpriteManager()
	local playerScripts = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
	return playerScripts and playerScripts:FindFirstChild("spriteManager", true) or nil
end

local function isNativeMarker(instance)
	return instance:IsA("BillboardGui") and (instance.Name == "ESP" or instance.Name == "ESPCrayon")
end

local function hasNativeMarker(enemy)
	for _, child in ipairs(enemy:GetChildren()) do
		if isNativeMarker(child) then
			return true
		end
	end
	return false
end

local function clearEnemyMarkers(enemy)
	for _, child in ipairs(enemy:GetChildren()) do
		if isNativeMarker(child) then
			child:Destroy()
		end
	end
end

local function findNativeEnemyAddedCallback(enemies, spriteManager)
	local getConnections = getExecutorFunction("getconnections")
	local getEnvironment = getExecutorFunction("getfenv")
	if not (getConnections and getEnvironment and enemies and spriteManager) then
		return nil
	end

	local success, connections = pcall(getConnections, enemies.ChildAdded)
	if not success or typeof(connections) ~= "table" then
		return nil
	end

	for _, connection in ipairs(connections) do
		local callback = connection.Function
		if typeof(callback) == "function" then
			local envSuccess, environment = pcall(getEnvironment, callback)
			local sourceScript = envSuccess and environment and environment.script
			if sourceScript == spriteManager then
				return callback
			end
		end
	end

	return nil
end

local function getCurseHandler()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local module = clientModules and clientModules:FindFirstChild("CurseHandler")
	if not module then
		return nil
	end

	local success, handler = pcall(require, module)
	return success and handler or nil
end

local function isCurseEnabled(handler, curseName)
	if not handler or typeof(handler.IsCurseEnabled) ~= "function" then
		return false
	end
	local success, enabled = pcall(handler.IsCurseEnabled, curseName)
	return success and enabled == true
end

local function createMarkerFromNativeAssets(enemy, spriteManager)
	if EXCLUDED_ENEMIES[enemy.Name] or hasNativeMarker(enemy) then
		return true
	end

	local curseHandler = getCurseHandler()
	if (enemy.Name == "Guardian" or enemy.Name == "ShadowGuardian") and isCurseEnabled(curseHandler, "Camouflage") then
		return true
	end

	local head = enemy:FindFirstChild("head") or enemy:WaitForChild("head", 3)
	if not head or not Adapter.Enabled or not enemy.Parent then
		return false
	end

	local crayonEnabled = isCurseEnabled(curseHandler, "CrayonEnemies")
	local template = spriteManager and spriteManager:FindFirstChild(crayonEnabled and "ESPCrayon" or "ESP")
	if not template or not template:IsA("BillboardGui") then
		return false
	end

	local marker = template:Clone()
	marker.Adornee = enemy
	marker.Enabled = true
	marker.Size = head.Size

	local label = marker:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		if crayonEnabled then
			local namesModule = spriteManager:FindFirstChild("StupidNames")
			local namesSuccess, names = pcall(require, namesModule)
			if namesSuccess and typeof(names) == "table" and #names > 0 then
				label.Text = names[math.random(1, #names)]
			end
		else
			local lowerName = string.lower(enemy.Name)
			label.Text = DISPLAY_NAMES[lowerName] or lowerName
		end
	end

	marker.Parent = enemy
	return true
end

local function refreshEnemy(enemy, callback, spriteManager)
	if not Adapter.Enabled or not enemy.Parent or hasNativeMarker(enemy) or pendingEnemies[enemy] then
		return
	end

	pendingEnemies[enemy] = true
	task.spawn(function()
		local handled = false
		if callback then
			handled = pcall(callback, enemy)
		end
		if not handled and Adapter.Enabled and enemy.Parent then
			createMarkerFromNativeAssets(enemy, spriteManager)
		elseif not Adapter.Enabled and not Adapter.PreserveNativeMarkers and enemy.Parent then
			clearEnemyMarkers(enemy)
		end
		pendingEnemies[enemy] = nil
	end)
end

local function refreshExisting(generation)
	if not Adapter.Enabled or generation ~= Adapter.RefreshGeneration then
		return
	end

	local enemies = getEnemiesFolder()
	local spriteManager = getSpriteManager()
	if not (enemies and spriteManager) then
		return
	end

	local callback = findNativeEnemyAddedCallback(enemies, spriteManager)
	for _, enemy in ipairs(enemies:GetChildren()) do
		refreshEnemy(enemy, callback, spriteManager)
	end
end

local function clearMarkers()
	local enemies = getEnemiesFolder()
	if not enemies then
		return
	end

	for _, enemy in ipairs(enemies:GetChildren()) do
		clearEnemyMarkers(enemy)
	end
end

function Adapter.sync(enabled, preserveNativeMarkers)
	Adapter.Enabled = enabled == true
	Adapter.PreserveNativeMarkers = preserveNativeMarkers == true
	Adapter.RefreshGeneration += 1
	local generation = Adapter.RefreshGeneration

	if not Adapter.Enabled then
		if preserveNativeMarkers ~= true then
			clearMarkers()
		end
		return
	end

	for _, delayTime in ipairs(REFRESH_DELAYS) do
		task.delay(delayTime, function()
			refreshExisting(generation)
		end)
	end
end

return Adapter
