--!nocheck
-- [[
--  NULLSCAPE - Tripmine Defuse / Barrier Logic
--  Keeps defensive tripmine modes separate from Charger-specific assists.
-- ]]

local Barrier = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local LocalPlayer = Players.LocalPlayer
local ChargerEvent = ReplicatedStorage:WaitForChild("Movement"):WaitForChild("Events"):WaitForChild("ChargerEvent")

local OFF_MODE = "Off"
local IFRAMES_MODE = "I-Frames"
local IMMUNITY_MODE = "Immunity"
local ACTIVE_WATCH_INTERVAL = 0.05
local IDLE_WATCH_INTERVAL = 0.35
local IMMUNITY_SERVER_PULSE_INTERVAL = 0.8
local IMMUNITY_REARM_DELAY = 0.6
local IMMUNITY_ARM_DISTANCE = 7.5
local IMMUNITY_ARM_WINDOW = 2.0
local IMMUNITY_RESET_COOLDOWN = 0.08
local IMMUNITY_HOLD_AFTER_NEARBY = 0.75
local IMMUNITY_CLUSTER_DISTANCE = 8.5
local IMMUNITY_CLUSTER_COUNT = 2
local IMMUNITY_EMERGENCY_IFRAMES = 0.75
local IMMUNITY_PRECOLLECT_DELAY = 0.08
local IMMUNITY_DEBUG = true
local IMMUNITY_DEBUG_INTERVAL = 0.5

local activeController = nil
local watcherRunning = false
local watcherToken = {}
local iframeObject = nil
local cachedGCH = nil
local lastChargerState = nil
local lastRefreshAt = 0
local lastServerPulseAt = 0
local lastMode = OFF_MODE
local playerChildConnection = nil
local rearmToken = 0
local pulseChargerImmunity = nil
local immunityArmed = false
local lastImmunityResetAt = 0
local immunityHoldUntil = 0
local emergencyIframeUntil = 0
local lastDebugAt = 0
local lastDebugKey = ""
local hookTripmineCollect = nil
local hookedTripmineCollects = setmetatable({}, { __mode = "k" })
local hookedReplicationClients = setmetatable({}, { __mode = "k" })

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

local function getGiftClientHandler()
	if cachedGCH then
		return cachedGCH
	end

	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		or ReplicatedStorage:FindFirstChild("ClientModules")
	local giftClient = clientModules and clientModules:FindFirstChild("GiftClient")
	local handlerModule = giftClient and giftClient:FindFirstChild("GiftClientHandler")
	if not handlerModule then
		return nil
	end

	local ok, result = pcall(function()
		return require(handlerModule)
	end)
	if ok and result then
		cachedGCH = result
		return result
	end

	return nil
end

local function getGiftPosition(gift)
	local giftPos = gift and gift.Position
	if typeof(giftPos) == "Vector3" then
		return giftPos
	end

	local model = gift and gift.Model
	if typeof(model) == "Instance" then
		if model:IsA("BasePart") then
			return model.Position
		end

		local part = model:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	return nil
end

local function isTripmineGift(gift)
	if not gift then
		return false
	end

	if gift.Tripmine == true then
		return true
	end

	local giftType = gift.Type or gift.GiftType
	return giftType == "Tripmine" or giftType == "GoldTripmine"
end

local function getTripmineThreatInfo(hrp)
	local GCH = getGiftClientHandler()
	if not (GCH and GCH.Gifts and hrp) then
		return math.huge, 0
	end

	local nearest = math.huge
	local clustered = 0
	for _, gift in pairs(GCH.Gifts) do
		if isTripmineGift(gift) and not gift.Collected and not gift.Destroyed and not gift.ClientCollected then
			if hookTripmineCollect then
				hookTripmineCollect(gift)
			end

			local giftPos = getGiftPosition(gift)
			if giftPos then
				local distance = (hrp.Position - giftPos).Magnitude
				nearest = math.min(nearest, distance)
				if distance <= IMMUNITY_CLUSTER_DISTANCE then
					clustered += 1
				end
			end
		end
	end

	return nearest, clustered
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

local function getImmunityDebugState()
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")

	return {
		charging = char and char:GetAttribute("ChargingCheck") == true,
		usingAbility = humanoid and humanoid:GetAttribute("UsingAbility") == true,
		cancelCharge = LocalPlayer:FindFirstChild("CANCELCHARGE") ~= nil,
		tripIframes = LocalPlayer:FindFirstChild("TRIP_IFRAMES") ~= nil,
		health = humanoid and math.floor(humanoid.Health) or -1,
	}
end

local function debugImmunity(label, details, force)
	if not IMMUNITY_DEBUG then
		return
	end

	local now = os.clock()
	local state = getImmunityDebugState()
	local key = table.concat({
		label,
		tostring(state.charging),
		tostring(state.usingAbility),
		tostring(state.cancelCharge),
		tostring(state.tripIframes),
		tostring(state.health),
		tostring(details or ""),
	}, "|")

	if not force and key == lastDebugKey and now - lastDebugAt < IMMUNITY_DEBUG_INTERVAL then
		return
	end

	lastDebugAt = now
	lastDebugKey = key
	print(
		string.format(
			"[Defuse Immunity] %s | charge=%s using=%s cancel=%s trip_iframes=%s hp=%s%s",
			label,
			tostring(state.charging),
			tostring(state.usingAbility),
			tostring(state.cancelCharge),
			tostring(state.tripIframes),
			tostring(state.health),
			details and (" | " .. details) or ""
		)
	)
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

	if pulseChargerImmunity then
		pulseChargerImmunity(true)
	end
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

pulseChargerImmunity = function(force)
	if not isImmunityModeActive() then
		return
	end

	local now = os.clock()
	if not force and now - lastServerPulseAt < IMMUNITY_SERVER_PULSE_INTERVAL then
		return
	end

	lastServerPulseAt = now
	debugImmunity("FireServer(true)", nil, true)
	pcall(function()
		ChargerEvent:FireServer(true)
	end)
end

local function resetChargerImmunity(force)
	if not force and not immunityArmed then
		return
	end

	immunityArmed = false
	immunityHoldUntil = 0
	lastImmunityResetAt = os.clock()
	lastServerPulseAt = 0
	debugImmunity("FireServer(false)", force and "force=true" or nil, true)
	pcall(function()
		ChargerEvent:FireServer(false)
	end)
end

local function holdEmergencyIframes(duration)
	emergencyIframeUntil = math.max(emergencyIframeUntil, os.clock() + duration)
	addIframes()
	debugImmunity("EmergencyIFrames", string.format("until=%.2f", emergencyIframeUntil), false)

	local token = rearmToken
	task.delay(duration, function()
		if token == rearmToken and isImmunityModeActive() and os.clock() >= emergencyIframeUntil then
			debugImmunity("EmergencyIFramesEnd", nil, true)
			removeIframes()
		end
	end)
end

local function armChargerImmunityWindow()
	immunityHoldUntil = math.max(immunityHoldUntil, os.clock() + IMMUNITY_HOLD_AFTER_NEARBY)

	if immunityArmed then
		return
	end

	local now = os.clock()
	if now - lastImmunityResetAt < IMMUNITY_RESET_COOLDOWN then
		return
	end

	immunityArmed = true
	pulseChargerImmunity(true)

	local token = rearmToken
	task.delay(IMMUNITY_ARM_WINDOW, function()
		if token == rearmToken and isImmunityModeActive() then
			local deadlineNow = os.clock()
			if deadlineNow >= immunityHoldUntil then
				resetChargerImmunity()
				return
			end

			task.delay(immunityHoldUntil - deadlineNow, function()
				if token == rearmToken and isImmunityModeActive() and os.clock() >= immunityHoldUntil then
					resetChargerImmunity()
				end
			end)
		end
	end)
end

local function runAfterPrecollectDelay(callback)
	local delaySeconds = math.clamp(
		tonumber(activeController and activeController.TripmineBarrierCollectDelay) or IMMUNITY_PRECOLLECT_DELAY,
		0.03,
		1
	)

	if delaySeconds <= 0 then
		task.defer(callback)
		return
	end

	task.delay(delaySeconds, callback)
end

local function getPrecollectDelay()
	return math.clamp(
		tonumber(activeController and activeController.TripmineBarrierCollectDelay) or IMMUNITY_PRECOLLECT_DELAY,
		0.03,
		1
	)
end

hookTripmineCollect = function(gift)
	if not gift or hookedTripmineCollects[gift] or type(gift.Collect) ~= "function" then
		return
	end

	hookedTripmineCollects[gift] = true
	local originalCollect = gift.Collect
	gift.Collect = function(self, ...)
		if isTripmineGift(self) and isImmunityModeActive() then
			debugImmunity(
				"PreCollectHook",
				string.format("%s delay=%.2f", tostring(self.Id or self.Type or "Tripmine"), getPrecollectDelay()),
				true
			)
			armChargerImmunityWindow()

			local args = table.pack(...)
			runAfterPrecollectDelay(function()
				originalCollect(self, table.unpack(args, 1, args.n))
			end)
			return
		end

		return originalCollect(self, ...)
	end
end

local function hookTripmineSendCollect()
	local GCH = getGiftClientHandler()
	local replicationClient = GCH and GCH.ReplicationClient
	if not replicationClient or hookedReplicationClients[replicationClient] or type(replicationClient.SendCollect) ~= "function" then
		return
	end

	hookedReplicationClients[replicationClient] = true
	local originalSendCollect = replicationClient.SendCollect
	replicationClient.SendCollect = function(first, ...)
		local giftId = first
		local args = table.pack(...)
		local colonCall = first == replicationClient
		if colonCall then
			giftId = args[1]
			table.remove(args, 1)
			args.n -= 1
		end

		local gift = GCH.Gifts and GCH.Gifts[giftId]
		if isTripmineGift(gift) and isImmunityModeActive() then
			debugImmunity("PreSendCollectHook", string.format("%s delay=%.2f", tostring(giftId), getPrecollectDelay()), true)
			armChargerImmunityWindow()

			runAfterPrecollectDelay(function()
				if colonCall then
					originalSendCollect(giftId, table.unpack(args, 1, args.n))
				else
					originalSendCollect(first, table.unpack(args, 1, args.n))
				end
			end)
			return
		end

		if colonCall then
			return originalSendCollect(giftId, table.unpack(args, 1, args.n))
		end

		return originalSendCollect(first, ...)
	end
end

local function updateImmunityTripmineWindow()
	if not isImmunityModeActive() then
		emergencyIframeUntil = 0
		removeIframes()
		resetChargerImmunity()
		return
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		emergencyIframeUntil = 0
		removeIframes()
		resetChargerImmunity()
		return
	end

	local now = os.clock()
	hookTripmineSendCollect()
	local nearestTripmine, clusteredTripmines = getTripmineThreatInfo(hrp)
	local rearmCoolingDown = now - lastImmunityResetAt < IMMUNITY_REARM_DELAY
	debugImmunity(
		"ThreatScan",
		string.format(
			"nearest=%.2f cluster=%d armed=%s cooldown=%s hold=%.2f emergency=%.2f",
			nearestTripmine,
			clusteredTripmines,
			tostring(immunityArmed),
			tostring(rearmCoolingDown),
			math.max(0, immunityHoldUntil - now),
			math.max(0, emergencyIframeUntil - now)
		),
		false
	)

	if clusteredTripmines >= IMMUNITY_CLUSTER_COUNT or (rearmCoolingDown and nearestTripmine <= IMMUNITY_ARM_DISTANCE) then
		holdEmergencyIframes(IMMUNITY_EMERGENCY_IFRAMES)
	elseif emergencyIframeUntil > 0 and now >= emergencyIframeUntil then
		debugImmunity("EmergencyIFramesClear", nil, true)
		removeIframes()
	end

	if nearestTripmine <= IMMUNITY_ARM_DISTANCE then
		armChargerImmunityWindow()
	elseif immunityArmed and now >= immunityHoldUntil then
		resetChargerImmunity()
	end
end

local function scheduleImmunityRearm(delaySeconds)
	if not isImmunityModeActive() then
		return
	end

	rearmToken += 1
	local token = rearmToken
	task.delay(delaySeconds or IMMUNITY_REARM_DELAY, function()
		if token ~= rearmToken or not isImmunityModeActive() then
			return
		end

		resetChargerImmunity(true)
		task.delay(IMMUNITY_RESET_COOLDOWN + 0.02, function()
			if token == rearmToken and isImmunityModeActive() then
				updateImmunityTripmineWindow()
			end
		end)
	end)
end

local function bindImmunityRearmWatcher()
	if playerChildConnection then
		return
	end

	playerChildConnection = LocalPlayer.ChildAdded:Connect(function(child)
		if child.Name == "CANCELCHARGE" or child.Name == "TRIP_IFRAMES" then
			debugImmunity("PlayerChildAdded", child.Name, true)
			scheduleImmunityRearm(IMMUNITY_REARM_DELAY)
		end
	end)
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
				rearmToken += 1
				lastMode = mode
				if mode == OFF_MODE or mode == IMMUNITY_MODE then
					resetChargerImmunity(true)
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
				updateImmunityTripmineWindow()

				-- Cô lập tính năng liên kết: Hỗ trợ tạo I-Frames tạm thời khi kết thúc Charge thực tế (chỉ cho Charger Class)
				local movementInstance = getActiveMovementInstance()
				local isNativeCharger = movementInstance and (movementInstance.ClassID == "class/Charger")

				if isNativeCharger then
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
	local mode = getBarrierMode()
	local previousMode = lastMode
	lastMode = mode
	if previousMode ~= mode then
		rearmToken += 1
	end

	if mode == OFF_MODE then
		resetChargerImmunity(true)
		removeIframes(true)
	elseif mode == IMMUNITY_MODE then
		if previousMode ~= IMMUNITY_MODE then
			resetChargerImmunity(true)
			removeIframes(true)
		end
		updateImmunityTripmineWindow()
	end
end

function Barrier.Init()
	bindImmunityRearmWatcher()
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
