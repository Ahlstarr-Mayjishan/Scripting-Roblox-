--!nocheck
--[[
	NULLSCAPE - Remote Registry
	Centralizes remote lookup and guarded remote calls used by assist systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = {}

local KNOWN_PATHS = {
	Died = { "Events", "Died" },
	DiedFunc = { "Events", "DiedFunc" },
	GiftCollected = { "Events", "GiftCollected" },
	GiftCollectFailed = { "Events", "GiftCollectFailed" },
	MovementGiftMagnet = { "Events", "MovementGiftMagnet" },
	GrappleReplicator = { "Movement", "Events", "GrappleReplicator" },
	ReplicateAbility = { "Movement", "Events", "ReplicateAbility" },
	FleshTileTouched = { "Movement", "Events", "FleshTileTouched" },
	GetActiveEnemies = { "Events", "Functions", "GetActiveEnemies" },
	GetActiveUpgrades = { "Events", "Functions", "GetActiveUpgrades" },
	GetActiveCurses = { "Events", "Functions", "GetActiveCurses" },
	GetActiveGreaterCurses = { "Events", "Functions", "GetActiveGreaterCurses" },
}

local cache = {}

local function walkPath(root, path)
	local cursor = root
	for _, segment in ipairs(path) do
		cursor = cursor and cursor:FindFirstChild(segment)
		if not cursor then
			return nil
		end
	end
	return cursor
end

local function isRemote(instance)
	if typeof(instance) ~= "Instance" then
		return false
	end

	return instance:IsA("RemoteEvent")
		or instance:IsA("RemoteFunction")
		or instance:IsA("UnreliableRemoteEvent")
		or instance:IsA("BindableEvent")
		or instance:IsA("BindableFunction")
end

function Registry.get(name)
	if cache[name] and cache[name].Parent then
		return cache[name]
	end

	local path = KNOWN_PATHS[name]
	local remote = path and walkPath(ReplicatedStorage, path) or nil
	if remote and isRemote(remote) then
		cache[name] = remote
		return remote
	end

	remote = ReplicatedStorage:FindFirstChild(name, true)
	if remote and isRemote(remote) then
		cache[name] = remote
		return remote
	end

	return nil
end

function Registry.findUnder(root, name)
	if not root then
		return nil
	end

	local direct = root:FindFirstChild(name)
	if direct and isRemote(direct) then
		return direct
	end

	local found = root:FindFirstChild(name, true)
	return found and isRemote(found) and found or nil
end

function Registry.describe(remote)
	if typeof(remote) ~= "Instance" then
		return "<nil>"
	end

	local parts = {}
	local cursor = remote
	while cursor and cursor ~= game do
		table.insert(parts, 1, cursor.Name)
		cursor = cursor.Parent
	end

	return "game." .. table.concat(parts, ".")
end

function Registry.isRemote(remote)
	return isRemote(remote)
end

function Registry.safeFire(remoteOrName, ...)
	local remote = typeof(remoteOrName) == "string" and Registry.get(remoteOrName) or remoteOrName
	if not (remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"))) then
		return false, "missing remote event"
	end

	local ok, err = pcall(function(...)
		remote:FireServer(...)
	end, ...)
	return ok, err
end

function Registry.safeInvoke(remoteOrName, ...)
	local remote = typeof(remoteOrName) == "string" and Registry.get(remoteOrName) or remoteOrName
	if not (remote and remote:IsA("RemoteFunction")) then
		return false, "missing remote function"
	end

	local ok, result = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)
	if not ok then
		return false, result
	end
	return true, result
end

function Registry.clear()
	table.clear(cache)
end

return Registry
