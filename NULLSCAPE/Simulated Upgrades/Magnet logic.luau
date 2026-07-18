--!nocheck
-- [[
--  NULLSCAPE - Gift Magnet / Auto Collect
--  Handles gift collection with range filters and safety checks.
--  (Medal collection has been moved to manual blink-teleport keybind by user request)
-- ]]

local Magnet = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local COLLECT_DELAY = 0.35

local lastCollectTime = 0
local comboCount = 0
local lastCollectTick = 0
local cachedGCH = nil
local cachedCollectedGiftEvent = nil
local scanGeneration = 0
local scannedGifts = setmetatable({}, { __mode = "k" })

-- Non-blocking spawn time tracker for Gift replication settle check
local seenGifts = setmetatable({}, { __mode = "k" })

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

local function getCollectedGiftEvent()
	if cachedCollectedGiftEvent and cachedCollectedGiftEvent.Parent then
		return cachedCollectedGiftEvent
	end
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local events = movement and movement:FindFirstChild("Events")
	cachedCollectedGiftEvent = events and events:FindFirstChild("CollectedGift")
	return cachedCollectedGiftEvent
end

local function getGiftPosition(gift)
	local pos = gift and gift.Position
	if typeof(pos) == "Vector3" then
		return pos
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

local function collectGift(rawObj, collectedEvent)
	local now = tick()
	if math.min(1.2, math.pow(1.1, comboCount) * 0.8) <= now - lastCollectTick then
		comboCount = 0
	end
	comboCount += 1
	lastCollectTick = now

	pcall(function()
		rawObj:Collect(false, true, comboCount)
	end)

	if collectedEvent then
		pcall(function()
			collectedEvent:Fire()
		end)
	end
end

local function getCandidateDistance(rawObj, hrpPos, range, generation, now)
	if not rawObj or scannedGifts[rawObj] == generation then
		return nil
	end
	scannedGifts[rawObj] = generation
	if rawObj.Collected or rawObj.Destroyed or rawObj.Tripmine then
		return nil
	end

	local pos = getGiftPosition(rawObj)
	if not pos then
		return nil
	end

	-- Settle check: Track first seen timestamp
	if not seenGifts[rawObj] then
		seenGifts[rawObj] = now
	end
	if now - seenGifts[rawObj] < 0.5 then
		return nil
	end

	local distance = (hrpPos - pos).Magnitude
	if distance > range then
		return nil
	end

	return distance
end

function Magnet.update(controller, hrp)
	if controller.GiftMagnetBlocked == true then
		return
	end
	if not controller.AutoCollectEnabled then
		return
	end
	if not hrp then
		return
	end

	local mode = controller.AutoCollectMode or "Legit"
	local hrpPos = hrp.Position
	local giftRange = controller.AutoCollectGiftRange or controller.AutoCollectRange or 20
	if giftRange > 60 then
		giftRange = 60 -- Server limit safety ceiling
	end

	local canCollectGift = true
	if mode == "Legit" and os.clock() - lastCollectTime < COLLECT_DELAY then
		canCollectGift = false
	end

	if canCollectGift then
		scanGeneration += 1
		local generation = scanGeneration
		local now = os.clock()
		local collectedEvent = getCollectedGiftEvent()
		local nearestGift = nil
		local nearestDistance = math.huge

		local function consider(rawObj)
			local distance = getCandidateDistance(rawObj, hrpPos, giftRange, generation, now)
			if not distance then
				return
			end

			if mode == "Legit" then
				if distance < nearestDistance then
					nearestGift = rawObj
					nearestDistance = distance
				end
			else
				collectGift(rawObj, collectedEvent)
			end
		end

		for _, giftInfo in ipairs(controller.ActiveGifts or {}) do
			consider(giftInfo.rawObj)
		end

		local GCH = getGiftClientHandler()
		if GCH and GCH.Gifts then
			for _, rawObj in pairs(GCH.Gifts) do
				consider(rawObj)
			end
		end

		if nearestGift then
			collectGift(nearestGift, collectedEvent)
			lastCollectTime = now
		end
	end
end

return Magnet
