--!nocheck
--[[
	NULLSCAPE - Grappler Bell Contact Assist
	Temporarily releases Bell touch immunity while a grapple is attached to Bell,
	then restores it after the native Bell ring remote confirms contact.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")

local CONTACT_WINDOW = 2.5
local RESTORE_DELAY = 0.08
local MAX_ATTACH_DISTANCE = 7

local Logic = {
	Connection = nil,
	ActiveBell = nil,
	ExpireAt = 0,
	LastRingAt = 0,
	Restoring = false,
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

local function nearBell(grapple, bell)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and rootPart.Parent and bell and bell.Parent) then
		return false
	end

	return (rootPart.Position - bell.Position).Magnitude <= MAX_ATTACH_DISTANCE
end

local function restore()
	if Logic.Restoring then
		return
	end

	Logic.Restoring = true
	task.delay(RESTORE_DELAY, function()
		Logic.ActiveBell = nil
		Logic.ExpireAt = 0
		Logic.Restoring = false

		if TouchInterest and typeof(TouchInterest.endTemporaryAllow) == "function" then
			pcall(TouchInterest.endTemporaryAllow, "Bell")
		end
	end)
end

local function begin(bell)
	if Logic.ActiveBell == bell and time() <= Logic.ExpireAt then
		if TouchInterest and typeof(TouchInterest.beginTemporaryAllow) == "function" then
			pcall(TouchInterest.beginTemporaryAllow, "Bell", 0.25)
		end
		return
	end

	Logic.ActiveBell = bell
	Logic.ExpireAt = time() + CONTACT_WINDOW

	if TouchInterest and typeof(TouchInterest.beginTemporaryAllow) == "function" then
		pcall(TouchInterest.beginTemporaryAllow, "Bell", CONTACT_WINDOW)
	end
end

local function ensureRemoteListener()
	if Logic.Connection then
		return
	end

	local bellRemote = getBellRemote()
	if not bellRemote then
		return
	end

	Logic.Connection = bellRemote.OnClientEvent:Connect(function(...)
		if not Logic.ActiveBell then
			return
		end

		Logic.LastRingAt = time()
		restore()
	end)
end

function Logic.beforeStep(grapple)
	ensureRemoteListener()

	local grapplingBell, bell = isGrappledToBell(grapple)
	if not grapplingBell then
		if Logic.ActiveBell and time() > Logic.ExpireAt then
			restore()
		end
		return false
	end

	begin(bell)
	return true
end

function Logic.afterStep(grapple)
	if not Logic.ActiveBell then
		return false
	end

	if time() > Logic.ExpireAt then
		restore()
		return false
	end

	local grapplingBell, bell = isGrappledToBell(grapple)
	if not grapplingBell then
		restore()
		return false
	end

	if grapplingBell and bell == Logic.ActiveBell and nearBell(grapple, bell) then
		return true
	end

	return true
end

function Logic.reset()
	if Logic.Connection then
		pcall(function()
			Logic.Connection:Disconnect()
		end)
		Logic.Connection = nil
	end

	Logic.ActiveBell = nil
	Logic.ExpireAt = 0
	Logic.Restoring = false

	if TouchInterest and typeof(TouchInterest.endTemporaryAllow) == "function" then
		pcall(TouchInterest.endTemporaryAllow, "Bell")
	end
end

return Logic
