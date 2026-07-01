--!nocheck
-- [[
--  NULLSCAPE - Charger Tripmine Assists
--  Temporary home for tripmine Passthrough / PreDetonate style helpers.
--  These modes are intentionally separate from Defuse Kits because they depend
--  on movement/class timing and are not reliable server-side immunity.
-- ]]

local ChargerAssist = {}

local getgenv = getgenv
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local PASSTHROUGH_MODE = "Passthrough"
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
local PASS_BATCH_MAX_TIME = 0.4
local PASS_BATCH_MAX_COUNT = 5
local PASS_BATCH_MIN_SPEED = 22

local activeController = nil
local watcherRunning = false
local watcherToken = {}
local cachedGCH = nil
local iframeObject = nil
local processedMines = {}
local passthroughState = {}
local logs = {}
local lastCollectAt = {}
local passBatch = nil
local passBatchLocked = false
local previousHrpPos = nil

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals
globals.ChargerTripmineWatcherToken = watcherToken
globals.TripmineIframeOwners = globals.TripmineIframeOwners or {}

local IFRAME_OWNER = "ChargerAssist"

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

local function isChargerAssistMode(mode)
	return mode == AUTO_MODE or mode == PASSTHROUGH_MODE or mode == PREDETONATE_MODE or mode == PASS_BATCH_MODE
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

local function getGiftClientHandler()
	if cachedGCH then
		return cachedGCH
	end

	local replicatedFirst = game:GetService("ReplicatedFirst")
	local clientModules = replicatedFirst:FindFirstChild("ClientModules")
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
	processedMines["__dist_" .. giftId] = nil
	passthroughState[giftId] = nil
	lastCollectAt[giftId] = nil
end

local function clearState()
	table.clear(processedMines)
	table.clear(passthroughState)
	table.clear(logs)
	table.clear(lastCollectAt)
	passBatch = nil
	passBatchLocked = false
	previousHrpPos = nil
end

local function logOnce(giftId, reason, dist)
	local key = reason .. ":" .. tostring(giftId)
	if logs[key] then
		return
	end

	logs[key] = true
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

	local ok = pcall(function()
		gift:Collect(false, true, 0)
	end)

	if ok then
		logOnce(giftId, reason, dist)
	end

	return ok
end

local function isCharging(char, hrp)
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	if humanoid:GetAttribute("UsingAbility") ~= true then
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
	return {
		alpha = alpha,
		distance = distance,
		closest = closest,
		length = length,
	}
end

local function resetPassBatch()
	passBatch = nil
end

local function startPassBatch(giftId, gift, giftPos, hrpPos)
	passBatch = {
		anchorId = giftId,
		anchorPos = giftPos,
		startTime = os.clock(),
		lastAddTime = os.clock(),
		items = {},
		itemSet = {},
		startPos = hrpPos,
	}

	passBatch.items[1] = {
		id = giftId,
		gift = gift,
		pos = giftPos,
	}
	passBatch.itemSet[giftId] = true
end

local function addToPassBatch(giftId, gift, giftPos, batchDistance)
	if not passBatch or passBatch.itemSet[giftId] then
		return false
	end

	if (giftPos - passBatch.anchorPos).Magnitude > batchDistance then
		return false
	end

	table.insert(passBatch.items, {
		id = giftId,
		gift = gift,
		pos = giftPos,
	})
	passBatch.itemSet[giftId] = true
	passBatch.lastAddTime = os.clock()
	return true
end

local function flushPassBatch(reason, hrpPos, lockUntilChargeEnd)
	if not passBatch then
		return
	end

	local batch = passBatch
	resetPassBatch()
	if lockUntilChargeEnd then
		passBatchLocked = true
	end

	for _, item in ipairs(batch.items) do
		local gift = item.gift
		local dist = hrpPos and (hrpPos - item.pos).Magnitude or 0
		if gift and not gift.Collected then
			local ok = tryCollectTripmine(item.id, gift, reason or "PassBatchFlush", dist)
			if ok then
				processedMines[item.id] = true
			end
		end
	end
end

local function updatePassBatch(char, hrp, hrpPos, GCH, batchDistance)
	local charging = isCharging(char, hrp)
	if not charging then
		if passBatch then
			flushPassBatch("PassBatchChargeEnded", hrpPos, false)
		end
		passBatchLocked = false
		previousHrpPos = nil
		return
	end

	if passBatchLocked then
		previousHrpPos = hrpPos
		return
	end

	if not previousHrpPos then
		previousHrpPos = hrpPos
		return
	end

	local candidates = {}
	for giftId, gift in pairs(GCH.Gifts) do
		if gift.Tripmine and not gift.Collected and not processedMines[giftId] then
			local giftPos = getGiftPosition(gift)
			local segmentInfo = giftPos and getSegmentInfo(previousHrpPos, hrpPos, giftPos)
			if
				segmentInfo
				and segmentInfo.alpha > 0
				and segmentInfo.alpha < 1
				and segmentInfo.distance <= PASS_BATCH_CORRIDOR
			then
				table.insert(candidates, {
					id = giftId,
					gift = gift,
					pos = giftPos,
					alpha = segmentInfo.alpha,
				})
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.alpha < b.alpha
	end)

	for _, candidate in ipairs(candidates) do
		if not passBatch then
			startPassBatch(candidate.id, candidate.gift, candidate.pos, hrpPos)
			logOnce(candidate.id, "PassBatchAnchor", (hrpPos - candidate.pos).Magnitude)
		elseif addToPassBatch(candidate.id, candidate.gift, candidate.pos, batchDistance) then
			logOnce(candidate.id, "PassBatchQueued", (hrpPos - candidate.pos).Magnitude)
		end
	end

	if passBatch then
		local now = os.clock()
		local anchorDistance = (hrpPos - passBatch.anchorPos).Magnitude
		if
			anchorDistance >= batchDistance
			or now - passBatch.startTime >= PASS_BATCH_MAX_TIME
			or #passBatch.items >= PASS_BATCH_MAX_COUNT
		then
			flushPassBatch("PassBatchFlush", hrpPos, true)
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

	task.spawn(function()
		local cleanedIdle = false
		while not globals or globals.ChargerTripmineWatcherToken == watcherToken do
			local mode = activeController and activeController.ChargerTripmineMode
			local active = activeController
				and activeController.ChargerTripmineAssistEnabled
				and isChargerAssistMode(mode)
			task.wait(active and ACTIVE_WATCH_INTERVAL or IDLE_WATCH_INTERVAL)

			mode = activeController and activeController.ChargerTripmineMode
			active = activeController and activeController.ChargerTripmineAssistEnabled and isChargerAssistMode(mode)
			if not active then
				if not cleanedIdle then
					removeIframes()
					clearState()
					cleanedIdle = true
				end
				continue
			end
			cleanedIdle = false

			addIframes()

			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
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
				local idText = tostring(id)
				if idText:sub(1, 7) ~= "__dist_" then
					local giftId = tonumber(id)
					if giftId and not GCH.Gifts[giftId] then
						clearMineState(giftId)
					end
				end
			end

			if mode == PASS_BATCH_MODE then
				updatePassBatch(char, hrp, hrpPos, GCH, batchDistance)
				continue
			else
				if passBatch then
					flushPassBatch("PassBatchModeChanged", hrpPos, false)
				end
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
				if mode == PASSTHROUGH_MODE or mode == AUTO_MODE then
					local state = passthroughState[giftId]
					if not state and dist < NEAR_PASS_DISTANCE then
						passthroughState[giftId] = "inside"
						local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
						processedMines["__dist_" .. giftId] = math.max(targetDist, NEAR_PASS_DISTANCE)
						tryCollectTripmine(giftId, gift, "PassthroughEntered", dist)
					elseif state == "inside" then
						local targetDist = processedMines["__dist_" .. giftId] or baseDist
						if dist >= targetDist then
							logOnce(giftId, "PassthroughExited", dist)
							clearMineState(giftId)
						end
					end
				end

				if mode == PREDETONATE_MODE or mode == AUTO_MODE then
					if processedMines[giftId] then
						continue
					end

					if not processedMines["__dist_" .. giftId] then
						local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
						processedMines["__dist_" .. giftId] = math.max(targetDist, 5)
					end

					local targetDist = processedMines["__dist_" .. giftId]
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
		removeIframes()
		clearState()
		watcherRunning = false
	end)
end

function ChargerAssist.update(controller)
	activeController = controller

	if not (controller.ChargerTripmineAssistEnabled and isChargerAssistMode(controller.ChargerTripmineMode)) then
		removeIframes()
		clearState()
	end
end

function ChargerAssist.Init()
	startWatcher()
	print("[NULLSCAPE Charger Assist] Module ready. Modes: Auto | PassBatch | Passthrough | PreDetonate")
end

ChargerAssist.Init()

return ChargerAssist
