--!nocheck
-- [[
--  NULLSCAPE - Source Event Immunity
--  Stops client-driven entity attacks at their source and restores callbacks cleanly.
-- ]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
	Connections = {},
	DisabledConnections = setmetatable({}, { __mode = "k" }),
	ObservedEnemies = setmetatable({}, { __mode = "k" }),
	TouchParts = setmetatable({}, { __mode = "k" }),
	Enabled = false,
}

local RETRY_DELAYS = { 0, 0.1, 0.5 }
local DIED_REASON = "celestial"
local DIED_GUARD_STATE_KEY = "_NULLSCAPE_CelestialDiedGuardState"
local SOURCE_EVENTS = {
	Celestial = {
		ControllerFlag = "CelestialImmune",
		-- Preserve native intro, attacks, and ending. Outgoing kill reports are filtered by RemoteBlocking.
		Remotes = {},
	},
	RealityBreak = {
		ControllerFlag = "RealityBreakImmune",
		Remotes = { ClientEvent = true },
	},
}

local function getController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeEntitiesController
end

local function getSourceEvent(enemy)
	if not enemy or not (enemy:IsA("Model") or enemy:IsA("Folder") or enemy:IsA("BasePart")) then
		return nil
	end

	local lowerName = string.lower(enemy.Name)
	for sourceName, config in pairs(SOURCE_EVENTS) do
		if string.find(lowerName, string.lower(sourceName), 1, true) ~= nil then
			return config
		end
	end

	return nil
end

local function isSourceEnabled(config)
	local controller = getController()
	return controller and not controller.Destroyed and controller.inLobby ~= true and controller[config.ControllerFlag] == true
end

local function wrapHook(callback)
	if typeof(newcclosure) == "function" then
		return newcclosure(callback)
	end
	return callback
end

local function installDiedGuard()
	if typeof(hookfunction) ~= "function" then
		return false
	end

	local events = ReplicatedStorage:FindFirstChild("Events")
	local diedRemote = events and events:FindFirstChild("Died")
	if not (diedRemote and diedRemote:IsA("RemoteEvent")) then
		return false
	end

	local environment = getgenv()
	local state = environment[DIED_GUARD_STATE_KEY]
	if typeof(state) ~= "table" then
		state = {}
		environment[DIED_GUARD_STATE_KEY] = state
	end

	state.DiedRemote = diedRemote
	state.ShouldBlock = function(remote, firstArg)
		local controller = getController()
		return Logic.Enabled
			and remote == state.DiedRemote
			and controller ~= nil
			and not controller.Destroyed
			and controller.CelestialImmune == true
			and controller.ShieldBaitEnabled ~= true
			and string.lower(tostring(firstArg or "")) == DIED_REASON
	end

	if state.Installed == true then
		return true
	end

	local success, originalFireServer = pcall(function()
		local original
		original = hookfunction(diedRemote.FireServer, wrapHook(function(remote, ...)
			local shouldBlock = state.ShouldBlock
			if typeof(shouldBlock) == "function" and shouldBlock(remote, ...) then
				local globals = getgenv()._NULLSCAPE_Globals
				if typeof(globals) == "table" then
					globals.LastCelestialDeathReportBlockedAt = os.clock()
					globals.LastCelestialDeathReportBlockedReason = DIED_REASON
				end
				return
			end
			return original(remote, ...)
		end))
		return original
	end)

	if success and typeof(originalFireServer) == "function" then
		state.OriginalFireServer = originalFireServer
		state.Installed = true
		return true
	end

	return false
end

local function disableSignal(signal)
	if typeof(getconnections) ~= "function" then
		return
	end

	local ok, connections = pcall(getconnections, signal)
	if not ok or typeof(connections) ~= "table" then
		return
	end

	for _, connection in ipairs(connections) do
		if not Logic.DisabledConnections[connection] then
			local disabled = pcall(function()
				connection:Disable()
			end)
			if disabled then
				Logic.DisabledConnections[connection] = true
			end
		end
	end
end

local function suppressRemote(remote, config)
	if not (Logic.Enabled and config and remote:IsA("RemoteEvent") and config.Remotes[remote.Name]) then
		return
	end

	for _, delayTime in ipairs(RETRY_DELAYS) do
		task.delay(delayTime, function()
			if Logic.Enabled and remote.Parent and isSourceEnabled(config) then
				disableSignal(remote.OnClientEvent)
			end
		end)
	end
end

local function suppressCelestialTouch(enemy, config)
	if
		not (Logic.Enabled and enemy:IsA("BasePart"))
		or config.ControllerFlag ~= "CelestialImmune"
		or Logic.TouchParts[enemy] ~= nil
	then
		return
	end

	Logic.TouchParts[enemy] = enemy.CanTouch
	enemy.CanTouch = false
	table.insert(Logic.Connections, enemy:GetPropertyChangedSignal("CanTouch"):Connect(function()
		if Logic.Enabled and enemy.Parent and isSourceEnabled(config) and enemy.CanTouch then
			enemy.CanTouch = false
		end
	end))
end

local function observeEnemy(enemy)
	local config = getSourceEvent(enemy)
	if not (Logic.Enabled and config and isSourceEnabled(config)) or Logic.ObservedEnemies[enemy] then
		return
	end

	Logic.ObservedEnemies[enemy] = true
	suppressCelestialTouch(enemy, config)
	for _, child in ipairs(enemy:GetChildren()) do
		suppressRemote(child, config)
	end

	table.insert(Logic.Connections, enemy.ChildAdded:Connect(function(child)
		suppressRemote(child, config)
	end))
end

local function observeEnemiesFolder(folder)
	for _, enemy in ipairs(folder:GetChildren()) do
		observeEnemy(enemy)
	end

	table.insert(Logic.Connections, folder.ChildAdded:Connect(observeEnemy))
end

local function disconnectObservers()
	for _, connection in ipairs(Logic.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(Logic.Connections)
	Logic.ObservedEnemies = setmetatable({}, { __mode = "k" })
end

local function restoreCallbacks()
	for connection in pairs(Logic.DisabledConnections) do
		pcall(function()
			connection:Enable()
		end)
	end
	Logic.DisabledConnections = setmetatable({}, { __mode = "k" })
end

local function restoreTouchParts()
	for part, originalCanTouch in pairs(Logic.TouchParts) do
		if part and part.Parent then
			pcall(function()
				part.CanTouch = originalCanTouch
			end)
		end
	end
	Logic.TouchParts = setmetatable({}, { __mode = "k" })
end

function Logic.enable()
	if Logic.Enabled then
		installDiedGuard()
		return true
	end

	Logic.Enabled = true
	installDiedGuard()
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies and enemies:IsA("Folder") then
		observeEnemiesFolder(enemies)
	end

	table.insert(Logic.Connections, Workspace.ChildAdded:Connect(function(child)
		if Logic.Enabled and child.Name == "Enemies" and child:IsA("Folder") then
			observeEnemiesFolder(child)
		end
	end))

	return true
end

function Logic.disable()
	if
		not Logic.Enabled
		and #Logic.Connections == 0
		and next(Logic.DisabledConnections) == nil
		and next(Logic.TouchParts) == nil
	then
		return
	end

	Logic.Enabled = false
	disconnectObservers()
	restoreCallbacks()
	restoreTouchParts()
end

return Logic
