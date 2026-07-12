--!nocheck
--[[
	NULLSCAPE - Class Context
	Resolves the local player's native class once and broadcasts only real changes.
]]

local Players = game:GetService("Players")

local ClassContext = {
	CurrentId = nil,
	Started = false,
	Listeners = {},
	Connections = {},
	NextListenerId = 0,
}

local LocalPlayer = Players.LocalPlayer
local GameState = getgenv().loadModule("NULLSCAPE/Core/Game State Context.luau")

local function normalize(classId)
	if typeof(classId) ~= "string" then
		return nil
	end

	local normalized = string.lower(classId)
	normalized = normalized:gsub("^class/", "")
	return normalized
end

local function notify(previousId, currentId)
	for _, callback in pairs(ClassContext.Listeners) do
		task.spawn(function()
			pcall(callback, currentId, previousId)
		end)
	end
end

local function refresh()
	local rawId = GameState and GameState.getClassId and GameState.getClassId() or nil
	local currentId = normalize(rawId)
	if ClassContext.CurrentId == currentId then
		return currentId
	end

	local previousId = ClassContext.CurrentId
	ClassContext.CurrentId = currentId
	notify(previousId, currentId)
	return currentId
end

local function disconnectCharacterConnection()
	local connection = ClassContext.Connections.CharacterClassChanged
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
		ClassContext.Connections.CharacterClassChanged = nil
	end
end

local function watchCharacter(character)
	disconnectCharacterConnection()
	if character then
		ClassContext.Connections.CharacterClassChanged = character:GetAttributeChangedSignal("Class"):Connect(refresh)
	end
	refresh()
end

function ClassContext.initialize()
	if ClassContext.Started then
		return refresh()
	end

	ClassContext.Started = true
	ClassContext.Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(watchCharacter)
	watchCharacter(LocalPlayer.Character)
	return ClassContext.CurrentId
end

function ClassContext.getId()
	if not ClassContext.Started then
		ClassContext.initialize()
	end
	return ClassContext.CurrentId
end

function ClassContext.is(classId)
	return ClassContext.getId() == normalize(classId)
end

function ClassContext.isAny(classIds)
	if typeof(classIds) ~= "table" then
		return false
	end

	local currentId = ClassContext.getId()
	for _, classId in ipairs(classIds) do
		if currentId == normalize(classId) then
			return true
		end
	end
	return false
end

function ClassContext.subscribe(callback)
	if typeof(callback) ~= "function" then
		return nil
	end

	ClassContext.initialize()
	ClassContext.NextListenerId += 1
	local listenerId = ClassContext.NextListenerId
	ClassContext.Listeners[listenerId] = callback
	return {
		Disconnect = function()
			ClassContext.Listeners[listenerId] = nil
		end,
	}
end

function ClassContext.CleanUp()
	for key, connection in pairs(ClassContext.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
		ClassContext.Connections[key] = nil
	end
	table.clear(ClassContext.Listeners)
	ClassContext.CurrentId = nil
	ClassContext.Started = false
end

return ClassContext
