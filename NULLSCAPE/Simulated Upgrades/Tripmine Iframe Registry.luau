--!nocheck

local Players = game:GetService("Players")
local getgenv = getgenv

local LocalPlayer = Players.LocalPlayer
local MARKER_NAME = "TRIP_IFRAMES"
local OWNER_ATTRIBUTE = "NULLSCAPE_Owner"

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals

local state = globals.TripmineIframeRegistry
if typeof(state) ~= "table" then
	state = {
		Objects = {},
	}
	globals.TripmineIframeRegistry = state
end
state.Objects = state.Objects or {}

local Registry = {}

local function isOwnedMarker(instance, owner)
	return instance
		and instance.Parent == LocalPlayer
		and instance.Name == MARKER_NAME
		and instance:GetAttribute(OWNER_ATTRIBUTE) == owner
end

local function findOwnedMarker(owner)
	local cached = state.Objects[owner]
	if isOwnedMarker(cached, owner) then
		return cached
	end

	state.Objects[owner] = nil
	for _, child in ipairs(LocalPlayer:GetChildren()) do
		if isOwnedMarker(child, owner) then
			state.Objects[owner] = child
			return child
		end
	end

	local legacyOwners = globals.TripmineIframeOwners
	if typeof(legacyOwners) == "table" and legacyOwners[owner] == true then
		for _, child in ipairs(LocalPlayer:GetChildren()) do
			if child.Name == MARKER_NAME and child:GetAttribute(OWNER_ATTRIBUTE) == nil then
				child:SetAttribute(OWNER_ATTRIBUTE, owner)
				legacyOwners[owner] = nil
				state.Objects[owner] = child
				return child
			end
		end
		legacyOwners[owner] = nil
	end

	return nil
end

function Registry.acquire(owner)
	if typeof(owner) ~= "string" or owner == "" then
		return nil
	end

	local existing = findOwnedMarker(owner)
	if existing then
		return existing
	end

	local marker = Instance.new("BoolValue")
	marker.Name = MARKER_NAME
	marker:SetAttribute(OWNER_ATTRIBUTE, owner)
	marker.Parent = LocalPlayer
	state.Objects[owner] = marker
	return marker
end

function Registry.release(owner)
	if typeof(owner) ~= "string" or owner == "" then
		return
	end

	local marker = findOwnedMarker(owner)
	state.Objects[owner] = nil
	if marker then
		pcall(function()
			marker:Destroy()
		end)
	end
end

function Registry.has(owner)
	return findOwnedMarker(owner) ~= nil
end

return Registry
