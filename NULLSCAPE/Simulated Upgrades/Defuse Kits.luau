--!nocheck
-- [[
--  NULLSCAPE - Tripmine Defuse / Barrier Logic
--  Keeps defensive tripmine modes separate from Charger-specific assists.
-- ]]

local Barrier = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local ChargerEvent = ReplicatedStorage:WaitForChild("Movement"):WaitForChild("Events"):WaitForChild("ChargerEvent")

local OFF_MODE = "Off"
local IFRAMES_MODE = "I-Frames"
local IMMUNITY_MODE = "Immunity"
local ACTIVE_WATCH_INTERVAL = 0.12
local IDLE_WATCH_INTERVAL = 0.35
local IMMUNITY_REFRESH_TIME = 0.5

local activeController = nil
local watcherRunning = false
local watcherToken = {}
local iframeObject = nil
local lastChargerState = nil
local lastRefreshAt = 0
local immunityPulseUntil = 0

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals
globals.TripmineBarrierWatcherToken = watcherToken
globals.TripmineIframeOwners = globals.TripmineIframeOwners or {}
globals.DefuseKitsChargerEventHooked = globals.DefuseKitsChargerEventHooked or false

local IFRAME_OWNER = "DefuseKits"

local function getIframeOwners()
	globals.TripmineIframeOwners = globals.TripmineIframeOwners or {}
	return globals.TripmineIframeOwners
end

local function hasIframeOwner()
	for _, owns in pairs(getIframeOwners()) do
		if owns then
			return true
		end
	end

	return false
end

local function hasIframes()
	return iframeObject ~= nil and iframeObject.Parent ~= nil
end

local function addIframes()
	getIframeOwners()[IFRAME_OWNER] = true

	if hasIframes() then
		return
	end

	local existing = LocalPlayer:FindFirstChild("TRIP_IFRAMES")
	if existing then
		iframeObject = existing
		return
	end

	local obj = Instance.new("BoolValue")
	obj.Name = "TRIP_IFRAMES"
	obj.Parent = LocalPlayer
	iframeObject = obj
end

local function removeIframes()
	getIframeOwners()[IFRAME_OWNER] = nil
	if hasIframeOwner() then
		return
	end

	if iframeObject then
		pcall(function()
			iframeObject:Destroy()
		end)
		iframeObject = nil
	end

	local existing = LocalPlayer:FindFirstChild("TRIP_IFRAMES")
	if existing then
		pcall(function()
			existing:Destroy()
		end)
	end
end

local function getBarrierMode()
	if not activeController or not activeController.TripmineBarrierEnabled then
		return OFF_MODE
	end

	local mode = activeController.TripmineBarrierMode
	if mode == IMMUNITY_MODE then
		return IMMUNITY_MODE
	end

	return IFRAMES_MODE
end

local function isImmunityModeActive()
	return getBarrierMode() == IMMUNITY_MODE
end

local function refreshImmunity()
	if not isImmunityModeActive() then
		return
	end

	local now = os.clock()
	if now - lastRefreshAt < 0.05 then
		return
	end
	lastRefreshAt = now
	immunityPulseUntil = now + IMMUNITY_REFRESH_TIME

	removeIframes()
	task.defer(function()
		if isImmunityModeActive() then
			addIframes()
			task.delay(IMMUNITY_REFRESH_TIME, function()
				if isImmunityModeActive() then
					immunityPulseUntil = 0
					removeIframes()
				end
			end)
		end
	end)
end

local function getNativeChargerState()
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and humanoid) then
		return false
	end

	return char:GetAttribute("ChargingCheck") == true or humanoid:GetAttribute("UsingAbility") == true
end

local function watchNativeChargerState()
	if not isImmunityModeActive() then
		lastChargerState = nil
		return
	end

	local charging = getNativeChargerState()
	if lastChargerState == nil then
		lastChargerState = charging
		return
	end

	if lastChargerState == true and charging == false then
		refreshImmunity()
	end

	lastChargerState = charging
end

local function installChargerEventWatcher()
	-- Luôn cập nhật hàm callback mới nhất vào bảng toàn cục khi reload script
	globals.DefuseKitsOnFireServer = function()
		refreshImmunity()
	end

	if globals.DefuseKitsChargerEventHooked then
		return
	end

	if not (typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function") then
		return
	end

	local oldNamecall
	local ok = pcall(function()
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			local args = { ... }

			if self == ChargerEvent and method == "FireServer" and args[1] == false then
				task.defer(function()
					if globals.DefuseKitsOnFireServer then
						globals.DefuseKitsOnFireServer()
					end
				end)
			end

			return oldNamecall(self, ...)
		end)
	end)

	if ok then
		globals.DefuseKitsChargerEventHooked = true
	end
end

local function startWatcher()
	if watcherRunning then
		return
	end
	watcherRunning = true
	installChargerEventWatcher()

	task.spawn(function()
		local cleanedIdle = false
		while not globals or globals.TripmineBarrierWatcherToken == watcherToken do
			task.wait(
				activeController and activeController.TripmineBarrierEnabled and ACTIVE_WATCH_INTERVAL
					or IDLE_WATCH_INTERVAL
			)

			local mode = getBarrierMode()
			if mode == OFF_MODE then
				if not cleanedIdle then
					removeIframes()
					lastChargerState = nil
					cleanedIdle = true
				end
				continue
			end
			cleanedIdle = false

			if mode == IFRAMES_MODE then
				addIframes()
				lastChargerState = nil
			elseif mode == IMMUNITY_MODE then
				-- Gửi tín hiệu giả lập lướt lên Server vô điều kiện để đảm bảo bất tử mìn luôn được giữ vững
				pcall(function()
					ChargerEvent:FireServer(true)
				end)

				if hasIframes() and os.clock() >= immunityPulseUntil then
					removeIframes()
				end
				watchNativeChargerState()
			else
				lastChargerState = nil
			end
		end
		removeIframes()
		watcherRunning = false
	end)
end

function Barrier.update(controller)
	activeController = controller

	if getBarrierMode() == OFF_MODE then
		removeIframes()
	end
end

function Barrier.Init()
	startWatcher()
	print("[NULLSCAPE Defuse] Module ready. Modes: I-Frames | Immunity")
end

Barrier.Init()

return Barrier
