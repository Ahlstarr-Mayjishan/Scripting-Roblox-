--!nocheck
-- [[
--  NULLSCAPE - Charger Tripmine Assists
--  Temporary home for tripmine PassBatch / PreDetonate style helpers.
--  These modes are intentionally separate from Defuse Kits because they depend
--  on movement/class timing and are not reliable server-side immunity.
-- ]]

local ChargerAssist = {}

local getgenv = getgenv
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")
local TripmineIframeRegistry = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Tripmine Iframe Registry.luau")

local PREDETONATE_MODE = "PreDetonate"
local AUTO_MODE = "Auto"
local PASS_BATCH_MODE = "PassBatch"
local COLLECT_COOLDOWN = 0.45
local NEAR_PASS_DISTANCE = 6
local AUTO_LOOKAHEAD_SECONDS = 0.55
local AUTO_MIN_APPROACH_SPEED = 28
local ACTIVE_WATCH_INTERVAL = 0.08
local IDLE_WATCH_INTERVAL = 0.35
local PASS_BATCH_DISTANCE = 60
local PASS_BATCH_CORRIDOR = 9
local PASS_BATCH_MIN_SPEED = 22

local activeController = nil
local watcherRunning = false
local watcherToken = nil
local watcherGeneration = 0
local cachedGCH = nil
local processedMines = {}
local targetDistances = {}
local logs = {}
local lastCollectAt = {}
local passBatchLocked = false
local previousHrpPos = nil
local characterConnection = nil

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals
globals.ChargerTripmineWatcherToken = nil

local IFRAME_OWNER = "ChargerAssist"

local function isChargerAssistMode(mode)
	return mode == AUTO_MODE or mode == PREDETONATE_MODE or mode == PASS_BATCH_MODE
end

local function isActiveForNativeClass(controller)
	return ClassContext
		and ClassContext.is("Charger")
		and controller
		and controller.ChargerTripmineAssistEnabled
		and isChargerAssistMode(controller.ChargerTripmineMode)
end

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

local function clearMineState(giftId)
	processedMines[giftId] = nil
	targetDistances[giftId] = nil
	lastCollectAt[giftId] = nil
	logs[giftId] = nil
end

local function clearState()
	table.clear(processedMines)
	table.clear(targetDistances)
	table.clear(logs)
	table.clear(lastCollectAt)
	passBatchLocked = false
	previousHrpPos = nil
end

local function logOnce(giftId, reason, dist)
	local giftLogs = logs[giftId]
	if not giftLogs then
		giftLogs = {}
		logs[giftId] = giftLogs
	end
	if giftLogs[reason] then
		return
	end

	giftLogs[reason] = true
	print("[NULLSCAPE Charger Assist] " .. reason, giftId, "at", math.round(dist), "studs")
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

local function getApproachInfo(hrp, giftPos, dist)
	local velocity = hrp.AssemblyLinearVelocity or hrp.Velocity
	local toMine = giftPos - hrp.Position
	local dir = toMine.Magnitude > 0.05 and toMine.Unit or Vector3.new(0, 0, 0)
	local approachSpeed = velocity:Dot(dir)
	local timeToMine = if approachSpeed > 1 then dist / approachSpeed else math.huge

	return approachSpeed, timeToMine
end

local function tryCollectTripmine(giftId, gift, reason, dist)
	if not gift or gift.Collected or gift.Destroyed or gift.ClientCollected then
		return false
	end

	local now = os.clock()
	if lastCollectAt[giftId] and now - lastCollectAt[giftId] < COLLECT_COOLDOWN then
		return false
	end
	lastCollectAt[giftId] = now

	local wasClientCollected = gift.ClientCollected == true
	local wasCollected = gift.Collected == true
	local ok = pcall(function()
		gift:Collect(false, true, 0)
	end)

	local collected = ok
		and ((gift.ClientCollected == true and not wasClientCollected) or (gift.Collected == true and not wasCollected))
	if collected then
		logOnce(giftId, reason, dist)
	end

	return collected
end

local function isCharging(char, hrp)
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local usingAbility = humanoid:GetAttribute("UsingAbility") == true
	local chargingCheck = char:GetAttribute("ChargingCheck") == true
	if not (usingAbility or chargingCheck) then
		return false
	end

	local velocity = hrp.AssemblyLinearVelocity or hrp.Velocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= PASS_BATCH_MIN_SPEED
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

local function updatePassBatch(char, hrp, hrpPos, GCH, batchDistance)
	local charging = isCharging(char, hrp)
	if not charging then
		passBatchLocked = false
		previousHrpPos = nil
		removeIframes(false)
		return
	end

	addIframes()

	if passBatchLocked then
		previousHrpPos = hrpPos
		return
	end

	if not previousHrpPos then
		previousHrpPos = hrpPos
		return
	end

	local bestId = nil
	local bestGift = nil
	local bestPosition = nil
	local bestAlpha = math.huge
	for giftId, gift in pairs(GCH.Gifts) do
		if gift.Tripmine and not gift.Collected and not processedMines[giftId] then
			local giftPos = getGiftPosition(gift)
			local dist = giftPos and (hrpPos - giftPos).Magnitude or math.huge
			local segmentAlpha, segmentDistance = getSegmentInfo(previousHrpPos, hrpPos, giftPos)
			local wasPassed = segmentAlpha
				and segmentAlpha > 0
				and segmentAlpha < 1
				and segmentDistance <= PASS_BATCH_CORRIDOR
			local isOverlapping = dist <= NEAR_PASS_DISTANCE

			if (wasPassed or isOverlapping) and dist <= batchDistance then
				local alpha = segmentAlpha or 1
				if alpha < bestAlpha then
					bestId = giftId
					bestGift = gift
					bestPosition = giftPos
					bestAlpha = alpha
				end
			end
		end
	end

	if bestId then
		local dist = (hrpPos - bestPosition).Magnitude
		local ok = tryCollectTripmine(bestId, bestGift, "PassBatchSingle", dist)
		if ok then
			processedMines[bestId] = true
			passBatchLocked = true
			logOnce(bestId, "PassBatchSingle", dist)
		end
	end

	previousHrpPos = hrpPos
end

local function shouldAutoPredetonate(hrp, giftPos, dist, targetDist)
	local approachSpeed, timeToMine = getApproachInfo(hrp, giftPos, dist)
	if dist <= NEAR_PASS_DISTANCE then
		return true
	end

	if dist <= targetDist and approachSpeed >= AUTO_MIN_APPROACH_SPEED then
		return true
	end

	return timeToMine <= AUTO_LOOKAHEAD_SECONDS
end

local function startWatcher()
	if watcherRunning then
		return
	end
	watcherRunning = true
	watcherGeneration += 1
	local generation = watcherGeneration
	local token = {}
	watcherToken = token
	globals.ChargerTripmineWatcherToken = token

	if not characterConnection and LocalPlayer then
		characterConnection = LocalPlayer.CharacterAdded:Connect(function()
			clearState()
			cachedGCH = nil
			if activeController and activeController.ChargerTripmineMode == PASS_BATCH_MODE then
				removeIframes(true)
			end
		end)
	end

	task.spawn(function()
		local cleanedIdle = false
		while watcherGeneration == generation and globals.ChargerTripmineWatcherToken == token do
			local mode = activeController and activeController.ChargerTripmineMode
			local active = isActiveForNativeClass(activeController)
			task.wait(active and ACTIVE_WATCH_INTERVAL or IDLE_WATCH_INTERVAL)
			if watcherGeneration ~= generation or globals.ChargerTripmineWatcherToken ~= token then
				break
			end

			mode = activeController and activeController.ChargerTripmineMode
			active = isActiveForNativeClass(activeController)
			if not active then
				if not cleanedIdle then
					removeIframes(true)
					clearState()
					cleanedIdle = true
				end
				continue
			end
			cleanedIdle = false

			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				if mode == PASS_BATCH_MODE then
					removeIframes(false)
					clearState()
				end
				continue
			end

			local GCH = getGiftClientHandler()
			if not GCH or not GCH.Gifts then
				continue
			end

			local hrpPos = hrp.Position
			local baseDist = activeController.ChargerTripmineDistance
				or activeController.TripmineDetonationDistance
				or 15
			local jitter = activeController.ChargerTripmineJitter or activeController.TripmineDetonationJitter or 2
			local batchDistance = math.clamp(
				tonumber(activeController.ChargerTripmineBatchDistance) or PASS_BATCH_DISTANCE,
				NEAR_PASS_DISTANCE,
				PASS_BATCH_DISTANCE
			)

			for id in pairs(processedMines) do
				local giftId = tonumber(id)
				if not GCH.Gifts[id] and (not giftId or not GCH.Gifts[giftId]) then
					clearMineState(id)
				end
			end
			for id in pairs(targetDistances) do
				local giftId = tonumber(id)
				if not GCH.Gifts[id] and (not giftId or not GCH.Gifts[giftId]) then
					clearMineState(id)
				end
			end

			if mode == PASS_BATCH_MODE then
				updatePassBatch(char, hrp, hrpPos, GCH, batchDistance)
				continue
			else
				addIframes()
				passBatchLocked = false
				previousHrpPos = nil
			end

			for giftId, gift in pairs(GCH.Gifts) do
				if not gift.Tripmine or gift.Collected then
					clearMineState(giftId)
					continue
				end

				local giftPos = getGiftPosition(gift)
				if not giftPos then
					continue
				end

				local dist = (hrpPos - giftPos).Magnitude
				if mode == PREDETONATE_MODE or mode == AUTO_MODE then
					if processedMines[giftId] then
						continue
					end

					if not targetDistances[giftId] then
						local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
						targetDistances[giftId] = math.max(targetDist, 5)
					end

					local targetDist = targetDistances[giftId]
					local shouldCollect = dist <= targetDist
					if mode == AUTO_MODE then
						shouldCollect = shouldAutoPredetonate(hrp, giftPos, dist, targetDist)
					end

					if shouldCollect then
						local ok = tryCollectTripmine(
							giftId,
							gift,
							mode == AUTO_MODE and "AutoTripmineCollect" or "PreDetonateWindow",
							dist
						)
						if ok then
							processedMines[giftId] = true
						end
					end
				end
			end
		end
		if watcherGeneration == generation then
			removeIframes(true)
			clearState()
			watcherRunning = false
			watcherToken = nil
		end
	end)
end

local function stopWatcher()
	watcherGeneration += 1
	if watcherToken and globals.ChargerTripmineWatcherToken == watcherToken then
		globals.ChargerTripmineWatcherToken = nil
	end
	watcherToken = nil
	watcherRunning = false
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	removeIframes(true)
	clearState()
end

function ChargerAssist.update(controller)
	activeController = controller
	if controller and controller.ChargerTripmineMode == "Passthrough" then
		controller.ChargerTripmineMode = PASS_BATCH_MODE
	end

	if isActiveForNativeClass(controller) then
		startWatcher()
	else
		stopWatcher()
	end
end

function ChargerAssist.stop()
	activeController = nil
	stopWatcher()
end

function ChargerAssist.Init()
	print("[NULLSCAPE Charger Assist] Module ready. Modes: Auto | PassBatch | PreDetonate")
end

ChargerAssist.Init()

return ChargerAssist
