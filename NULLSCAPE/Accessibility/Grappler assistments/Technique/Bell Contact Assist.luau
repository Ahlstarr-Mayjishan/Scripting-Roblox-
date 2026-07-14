--!nocheck
--[[
	NULLSCAPE - Grappler Bell Contact Assist
	Releases Bell touch immunity for an intentional Bell cast, then restores it
	only when the native Bell ring remote confirms the contact.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")

local Logic = {
	Connection = nil,
	ActiveBell = nil,
	LastRingAt = 0,
}

local function getEvents()
	return ReplicatedStorage:FindFirstChild("Events")
end

local function getBellRemote()
	local events = getEvents()
	local bell = events and events:FindFirstChild("Bell")
	if bell and bell:IsA("RemoteEvent") then
		return bell
	end
	return nil
end

local function isBellPart(part)
	return typeof(part) == "Instance" and part:IsA("BasePart") and part.Name == "Bell"
end

local function isGrappledToBell(grapple)
	local movement = grapple and grapple.Movement
	local bell = grapple and grapple.grapplePart or movement and movement.grapplePart
	if not isBellPart(bell) then
		return false, nil
	end

	return movement and movement.grappling == true, bell
end

local function restore()
	Logic.ActiveBell = nil
	if TouchInterest and typeof(TouchInterest.endTemporaryAllow) == "function" then
		pcall(TouchInterest.endTemporaryAllow, "Bell")
	end
end

local function begin(bell)
	if not isBellPart(bell) then
		return false
	end

	if Logic.ActiveBell == bell then
		return
	end

	Logic.ActiveBell = bell

	if TouchInterest and typeof(TouchInterest.beginTemporaryAllow) == "function" then
		pcall(TouchInterest.beginTemporaryAllow, "Bell", math.huge)
	end
	return true
end

local function ensureRemoteListener()
	if Logic.Connection then
		return
	end

	local bellRemote = getBellRemote()
	if not bellRemote then
		return
	end

	Logic.Connection = bellRemote.OnClientEvent:Connect(function()
		if not Logic.ActiveBell then
			return
		end

		Logic.LastRingAt = time()
		restore()
	end)
end

function Logic.armCast(hit)
	local bell = typeof(hit) == "RaycastResult" and hit.Instance or hit
	if not isBellPart(bell) then
		return false
	end

	ensureRemoteListener()
	return begin(bell)
end

function Logic.beforeStep(grapple)
	ensureRemoteListener()

	local grapplingBell, bell = isGrappledToBell(grapple)
	if grapplingBell then
		return begin(bell)
	end

	return false
end

function Logic.afterStep(_grapple)
	return Logic.ActiveBell ~= nil
end

function Logic.disarm()
	if Logic.ActiveBell then
		restore()
	end
end

function Logic.reset()
	if Logic.Connection then
		pcall(function()
			Logic.Connection:Disconnect()
		end)
		Logic.Connection = nil
	end

	Logic.ActiveBell = nil

	if TouchInterest and typeof(TouchInterest.endTemporaryAllow) == "function" then
		pcall(TouchInterest.endTemporaryAllow, "Bell")
	end
end

return Logic
