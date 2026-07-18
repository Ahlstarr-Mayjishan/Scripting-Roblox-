--!nocheck
-- [[
--  NULLSCAPE - Tripmine Defuse / Barrier Logic
--  Keeps defensive tripmine modes separate from Charger-specific assists.
-- ]]

local Barrier = {}
local getgenv = getgenv

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TripmineIframeRegistry = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Tripmine Iframe Registry.luau")

local LocalPlayer = Players.LocalPlayer
local ChargerEvent = ReplicatedStorage:WaitForChild("Movement"):WaitForChild("Events"):WaitForChild("ChargerEvent")

local OFF_MODE = "Off"
local IFRAMES_MODE = "I-Frames"
local IMMUNITY_MODE = "Immunity"
local ACTIVE_WATCH_INTERVAL = 0.05
local IMMUNITY_SERVER_PULSE_INTERVAL = 0.8
local IMMUNITY_REARM_DELAY = 0.6
local IMMUNITY_ARM_DISTANCE = 7.5
local IMMUNITY_ARM_WINDOW = 2.0
local IMMUNITY_RESET_COOLDOWN = 0.08
local IMMUNITY_HOLD_AFTER_NEARBY = 0.75
local IMMUNITY_PASS_NEAR_DISTANCE = 6
local IMMUNITY_PASS_CORRIDOR = 9
local IMMUNITY_PRECOLLECT_DELAY = 0.08

local activeController = nil
local watcherRunning = false
local watcherToken = nil
local watcherGeneration = 0
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
local previousHrpPos = nil
local hookTripmineCollect = nil
local hookedTripmineCollects = setmetatable({}, { __mode = "k" })
local hookedReplicationClients = setmetatable({}, { __mode = "k" })
local originalTripmineCollects = setmetatable({}, { __mode = "k" })
local originalReplicationSendCollects = setmetatable({}, { __mode = "k" })
local bypassNextSendCollectDelay = false

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals
globals.TripmineBarrierWatcherToken = nil

local IFRAME_OWNER = "DefuseKits"

local function addIframes()
	TripmineIframeRegistry.acquire(IFRAME_OWNER)
end

local function removeIframes(_force)
	TripmineIframeRegistry.release(IFRAME_OWNER)
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

local function getSegmentInfo(fromPos, toPos, point)
	if not (fromPos and toPos and point) then
		return nil
	end

	local segment = toPos - fromPos
	local length = segment.Magnitude
	if length < 0.05 then
		return nil
	end

	local alpha = math.clamp((point - fromPos):Dot(segment) / (length * length), 0, 1)
	local closest = fromPos + segment * alpha
	local distance = (point - closest).Magnitude
	return alpha, distance
end

local function getTripmineThreatInfo(hrp)
	local GCH = getGiftClientHandler()
	if not (GCH and GCH.Gifts and hrp) then
		previousHrpPos = hrp and hrp.Position or nil
		return math.huge, false
	end

	local nearest = math.huge
	local passThreat = false
	local hrpPos = hrp.Position
	for _, gift in pairs(GCH.Gifts) do
		if isTripmineGift(gift) and not gift.Collected and not gift.Destroyed and not gift.ClientCollected then
			if hookTripmineCollect then
				hookTripmineCollect(gift)
			end

			local giftPos = getGiftPosition(gift)
			if giftPos then
				local distance = (hrpPos - giftPos).Magnitude
				nearest = math.min(nearest, distance)

				local alpha, corridorDistance
				if previousHrpPos then
					alpha, corridorDistance = getSegmentInfo(previousHrpPos, hrpPos, giftPos)
				end
				local wasPassed = alpha and alpha > 0 and alpha < 1 and corridorDistance <= IMMUNITY_PASS_CORRIDOR
				local isOverlapping = distance <= IMMUNITY_PASS_NEAR_DISTANCE
				if wasPassed or isOverlapping then
					passThreat = true
				end
			end
		end
	end

	previousHrpPos = hrpPos
	return nearest, passThreat
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
	pcall(function()
		ChargerEvent:FireServer(true)
	end)
	globals.TripmineImmunityOwner = watcherToken or Barrier
end

local function resetChargerImmunity(force)
	if not immunityArmed and (not force or globals.TripmineImmunityOwner == nil) then
		return
	end

	immunityArmed = false
	immunityHoldUntil = 0
	lastImmunityResetAt = os.clock()
	lastServerPulseAt = 0
	pcall(function()
		ChargerEvent:FireServer(false)
	end)
	globals.TripmineImmunityOwner = nil
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

hookTripmineCollect = function(gift)
	if not gift or hookedTripmineCollects[gift] or type(gift.Collect) ~= "function" then
		return
	end

	local originalCollect = gift.Collect
	originalTripmineCollects[gift] = originalCollect
	local wrappedCollect
	wrappedCollect = function(self, ...)
		if isTripmineGift(self) and isImmunityModeActive() then
			armChargerImmunityWindow()

			local args = table.pack(...)
			runAfterPrecollectDelay(function()
				bypassNextSendCollectDelay = true
				local ok, err = pcall(function()
					originalCollect(self, table.unpack(args, 1, args.n))
				end)
				bypassNextSendCollectDelay = false
				if not ok then
					error(err)
				end
			end)
			return
		end

		return originalCollect(self, ...)
	end
	hookedTripmineCollects[gift] = wrappedCollect
	gift.Collect = wrappedCollect
end

local function hookTripmineSendCollect()
	local GCH = getGiftClientHandler()
	local replicationClient = GCH and GCH.ReplicationClient
	if
		not replicationClient
		or hookedReplicationClients[replicationClient]
		or type(replicationClient.SendCollect) ~= "function"
	then
		return
	end

	local originalSendCollect = replicationClient.SendCollect
	originalReplicationSendCollects[replicationClient] = originalSendCollect
	local wrappedSendCollect
	wrappedSendCollect = function(first, ...)
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
			if bypassNextSendCollectDelay then
				if colonCall then
					return originalSendCollect(giftId, table.unpack(args, 1, args.n))
				end

				return originalSendCollect(first, table.unpack(args, 1, args.n))
			end

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
	hookedReplicationClients[replicationClient] = wrappedSendCollect
	replicationClient.SendCollect = wrappedSendCollect
end

local function updateImmunityTripmineWindow()
	if not isImmunityModeActive() then
		previousHrpPos = nil
		resetChargerImmunity()
		return
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		previousHrpPos = nil
		resetChargerImmunity()
		return
	end

	local now = os.clock()
	hookTripmineSendCollect()
	local nearestTripmine, passThreat = getTripmineThreatInfo(hrp)

	if passThreat or nearestTripmine <= IMMUNITY_ARM_DISTANCE then
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
	if playerChildConnection or not isImmunityModeActive() then
		return
	end

	playerChildConnection = LocalPlayer.ChildAdded:Connect(function(child)
		if child.Name == "CANCELCHARGE" or child.Name == "TRIP_IFRAMES" then
			scheduleImmunityRearm(IMMUNITY_REARM_DELAY)
		end
	end)
end

local function startWatcher()
	if watcherRunning or not isImmunityModeActive() then
		return
	end
	watcherRunning = true
	watcherGeneration += 1
	local generation = watcherGeneration
	local token = {}
	watcherToken = token
	globals.TripmineBarrierWatcherToken = token
	bindImmunityRearmWatcher()

	task.spawn(function()
		while
			watcherGeneration == generation
			and globals.TripmineBarrierWatcherToken == token
			and isImmunityModeActive()
		do
			task.wait(ACTIVE_WATCH_INTERVAL)
			if
				watcherGeneration ~= generation
				or globals.TripmineBarrierWatcherToken ~= token
				or not isImmunityModeActive()
			then
				break
			end
			updateImmunityTripmineWindow()
			watchNativeChargerState()
		end
		if watcherGeneration == generation then
			watcherRunning = false
			watcherToken = nil
		end
	end)
end

local function stopWatcher()
	watcherGeneration += 1
	if watcherToken and globals.TripmineBarrierWatcherToken == watcherToken then
		globals.TripmineBarrierWatcherToken = nil
	end
	watcherToken = nil
	watcherRunning = false
	if playerChildConnection then
		playerChildConnection:Disconnect()
		playerChildConnection = nil
	end
	resetChargerImmunity(true)
	previousHrpPos = nil
	lastChargerState = nil
end

function Barrier.update(controller)
	activeController = controller
	local mode = getBarrierMode()
	local previousMode = lastMode
	lastMode = mode
	if previousMode ~= mode then
		rearmToken += 1
		stopWatcher()
	end

	if mode == OFF_MODE then
		stopWatcher()
		removeIframes(false)
	elseif mode == IFRAMES_MODE then
		stopWatcher()
		addIframes()
	elseif mode == IMMUNITY_MODE then
		removeIframes(false)
		startWatcher()
		updateImmunityTripmineWindow()
	end
end

function Barrier.Init()
	print("[NULLSCAPE Defuse] Module ready. Modes: I-Frames | Immunity")
end

function Barrier.stop()
	rearmToken += 1
	stopWatcher()
	removeIframes(false)

	for gift, originalCollect in pairs(originalTripmineCollects) do
		if gift and gift.Collect == hookedTripmineCollects[gift] then
			gift.Collect = originalCollect
		end
	end
	for replicationClient, originalSendCollect in pairs(originalReplicationSendCollects) do
		if replicationClient and replicationClient.SendCollect == hookedReplicationClients[replicationClient] then
			replicationClient.SendCollect = originalSendCollect
		end
	end

	hookedTripmineCollects = setmetatable({}, { __mode = "k" })
	hookedReplicationClients = setmetatable({}, { __mode = "k" })
	originalTripmineCollects = setmetatable({}, { __mode = "k" })
	originalReplicationSendCollects = setmetatable({}, { __mode = "k" })
	cachedGCH = nil
	activeController = nil
	lastMode = OFF_MODE
end

Barrier.Init()

return Barrier
