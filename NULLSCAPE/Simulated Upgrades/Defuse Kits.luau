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
local lastMode = OFF_MODE

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals
globals.TripmineBarrierWatcherToken = watcherToken
globals.TripmineIframeOwners = globals.TripmineIframeOwners or {}

local IFRAME_OWNER = "DefuseKits"

-- 1. Tìm MovementCore
local function getMovementCore()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
	if not movementCoreScript then
		return nil
	end
	local ok, result = pcall(require, movementCoreScript)
	return ok and result or nil
end

local cachedInstance = nil
local lastCharacter = nil

-- 2. Tìm thực thể chuyển động hoạt động (Active Movement Instance)
local function getActiveMovementInstance()
	local char = LocalPlayer.Character
	if cachedInstance and lastCharacter == char and cachedInstance.Character == char then
		return cachedInstance
	end

	cachedInstance = nil
	lastCharacter = char
	if not char then
		return nil
	end

	local movementCore = getMovementCore()
	if not movementCore then
		return nil
	end

	if typeof(getgc) == "function" then
		for _, obj in ipairs(getgc(true)) do
			if type(obj) == "table" and getmetatable(obj) == movementCore then
				if obj.Player == LocalPlayer and obj.Character == char then
					cachedInstance = obj
					return obj
				end
			end
		end
	end

	if typeof(debug.getregistry) == "function" then
		for _, obj in pairs(debug.getregistry()) do
			if type(obj) == "table" and getmetatable(obj) == movementCore then
				if obj.Player == LocalPlayer and obj.Character == char then
					cachedInstance = obj
					return obj
				end
			end
		end
	end

	return nil
end

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

local function removeIframes(force)
	getIframeOwners()[IFRAME_OWNER] = nil
	if hasIframeOwner() and not force then
		return
	end

	if iframeObject then
		pcall(function()
			iframeObject:Destroy()
		end)
		iframeObject = nil
	end

	if force then
		local existing = LocalPlayer:FindFirstChild("TRIP_IFRAMES")
		if existing then
			pcall(function()
				existing:Destroy()
			end)
		end
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

local function startWatcher()
	if watcherRunning then
		return
	end
	watcherRunning = true

	task.spawn(function()
		local cleanedIdle = false
		while not globals or globals.TripmineBarrierWatcherToken == watcherToken do
			task.wait(
				activeController and activeController.TripmineBarrierEnabled and ACTIVE_WATCH_INTERVAL
					or IDLE_WATCH_INTERVAL
			)

			local mode = getBarrierMode()
			if mode ~= lastMode then
				local oldMode = lastMode
				lastMode = mode
				if mode == IMMUNITY_MODE or mode == OFF_MODE then
					removeIframes(true)
				end
			end

			if mode == OFF_MODE then
				if not cleanedIdle then
					removeIframes(true)
					cleanedIdle = true
				end
				continue
			end
			cleanedIdle = false

			if mode == IFRAMES_MODE then
				addIframes()
			elseif mode == IMMUNITY_MODE then
				-- Gửi tín hiệu giả lập lướt lên Server định kỳ (mỗi 0.8 giây) để tránh kích hoạt bộ chặn spam (Rate Limit) của Server
				local now = os.clock()
				if now - lastRefreshAt >= 0.8 then
					lastRefreshAt = now
					pcall(function()
						ChargerEvent:FireServer(true)
					end)
				end

				-- Cô lập tính năng liên kết: Hỗ trợ tạo I-Frames tạm thời khi kết thúc Charge thực tế (chỉ cho Charger Class)
				local movementInstance = getActiveMovementInstance()
				local isNativeCharger = movementInstance and (movementInstance.ClassID == "class/Charger")
				
				if isNativeCharger then
					if hasIframes() and os.clock() >= immunityPulseUntil then
						removeIframes()
					end
					watchNativeChargerState()
				end
			end
		end
		removeIframes(true)
		watcherRunning = false
	end)
end

function Barrier.update(controller)
	activeController = controller

	if getBarrierMode() == OFF_MODE then
		removeIframes(true)
	end
end

function Barrier.Init()
	startWatcher()
	-- Dọn dẹp TRIP_IFRAMES cũ nếu có khi load/reload script
	local existing = LocalPlayer:FindFirstChild("TRIP_IFRAMES")
	if existing then
		pcall(function()
			existing:Destroy()
		end)
	end
	print("[NULLSCAPE Defuse] Module ready. Modes: I-Frames | Immunity")
end

Barrier.Init()

return Barrier
