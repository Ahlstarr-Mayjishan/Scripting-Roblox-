--!nocheck
-- [[
--  NULLSCAPE - Gift, Instrument, and Medal Magnet / Auto Collect
--  Handles multi-target collection (Gifts, Instruments, Medals) with range filters and safety checks.
-- ]]

local Magnet = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local COLLECT_DELAY = 0.35

local lastCollectTime = 0
local comboCount = 0
local lastCollectTick = 0
local cachedGCH = nil

-- Non-blocking spawn time tracker for Gift replication settle check
local seenGifts = {}

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

local function getCollectedGiftEvent()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local events = movement and movement:FindFirstChild("Events")
	return events and events:FindFirstChild("CollectedGift")
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

local function addCandidate(validGifts, seenRawObjects, rawObj, hrpPos, range)
	if not rawObj or seenRawObjects[rawObj] then
		return
	end
	if rawObj.Collected or rawObj.Destroyed or rawObj.Tripmine then
		return
	end

	local pos = getGiftPosition(rawObj)
	if not pos then
		return
	end

	-- Settle check: Track first seen timestamp
	if not seenGifts[rawObj] then
		seenGifts[rawObj] = os.clock()
	end
	if os.clock() - seenGifts[rawObj] < 0.5 then
		return -- Wait 0.5s for settle
	end

	local distance = (hrpPos - pos).Magnitude
	if distance > range then
		return
	end

	seenRawObjects[rawObj] = true
	table.insert(validGifts, {
		rawObj = rawObj,
		dist = distance,
	})
end

local function findMedal()
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("Medal") then
		return nil
	end
	local medal = workspace:FindFirstChild("Medal")
	if medal then
		if medal:IsA("BasePart") then
			return medal
		elseif medal:IsA("Model") then
			local handle = medal:FindFirstChild("Handle") or medal:FindFirstChildWhichIsA("BasePart", true)
			if handle then
				return handle
			end
		end
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "Medal" then
			if child:IsA("BasePart") then
				return child
			end
			local handle = child:FindFirstChild("Handle") or child:FindFirstChildWhichIsA("BasePart", true)
			if handle then
				return handle
			end
		end
	end
	return nil
end

function Magnet.update(controller, hrp)
	if not controller.AutoCollectEnabled then
		return
	end
	if not hrp then
		return
	end

	local targets = controller.AutoCollectTargets or {}
	local hasGiftTarget = table.find(targets, "Gift/GoldenGift") ~= nil
	local hasInstrumentTarget = table.find(targets, "Instrument (Cadence)") ~= nil
	local hasMedalTarget = table.find(targets, "Medal") ~= nil

	local mode = controller.AutoCollectMode or "Legit"
	local hrpPos = hrp.Position

	-- 1. GIFT COLLECTION
	if hasGiftTarget then
		local giftRange = controller.AutoCollectGiftRange or controller.AutoCollectRange or 20
		if giftRange > 30 then
			giftRange = 30 -- Server limit safety ceiling
		end

		local canCollectGift = true
		if mode == "Legit" and os.clock() - lastCollectTime < COLLECT_DELAY then
			canCollectGift = false
		end

		if canCollectGift then
			local validGifts = {}
			local seenRawObjects = {}

			for _, giftInfo in ipairs(controller.ActiveGifts or {}) do
				addCandidate(validGifts, seenRawObjects, giftInfo.rawObj, hrpPos, giftRange)
			end

			local GCH = getGiftClientHandler()
			if GCH and GCH.Gifts then
				for _, rawObj in pairs(GCH.Gifts) do
					addCandidate(validGifts, seenRawObjects, rawObj, hrpPos, giftRange)
				end
			end

			if #validGifts > 0 then
				local collectedEvent = getCollectedGiftEvent()
				if mode == "Legit" then
					table.sort(validGifts, function(a, b)
						return a.dist < b.dist
					end)
					collectGift(validGifts[1].rawObj, collectedEvent)
					lastCollectTime = os.clock()
				else
					for _, item in ipairs(validGifts) do
						collectGift(item.rawObj, collectedEvent)
					end
				end
			end
		end
	end

	-- 2. CADENCE ORB / INSTRUMENT COLLECTION
	if hasInstrumentTarget then
		local instrumentRange = controller.AutoCollectInstrumentRange or 0
		for _, orb in ipairs(CollectionService:GetTagged("CadenceOrb")) do
			if orb:IsA("BasePart") and orb.Parent then
				local dist = (orb.Position - hrpPos).Magnitude
				if instrumentRange == 0 or dist <= instrumentRange then
					pcall(function()
						if typeof(firetouchinterest) == "function" then
							firetouchinterest(orb, hrp, 0)
							task.wait()
							firetouchinterest(orb, hrp, 1)
						end
					end)
				end
			end
		end
	end

	-- 3. MEDAL COLLECTION & SUBMISSION
	if hasMedalTarget then
		local char = LocalPlayer.Character
		if char then
			local carriesMedal = char:FindFirstChild("Medal") ~= nil
			if carriesMedal then
				-- Auto-submit to Beacon if within 30 studs
				local beacon = workspace:FindFirstChild("Beacon")
				local beaconPart = beacon and beacon:FindFirstChildWhichIsA("BasePart", true)
				if beaconPart then
					local distToBeacon = (beaconPart.Position - hrpPos).Magnitude
					if distToBeacon <= 30 then
						pcall(function()
							if typeof(firetouchinterest) == "function" then
								firetouchinterest(beaconPart, hrp, 0)
								task.wait()
								firetouchinterest(beaconPart, hrp, 1)
							end
						end)
					end
				end
			else
				-- Auto-pickup Medal
				local medalRange = controller.AutoCollectMedalRange or 0
				local medal = findMedal()
				if medal then
					local distToMedal = (medal.Position - hrpPos).Magnitude
					if medalRange == 0 or distToMedal <= medalRange then
						pcall(function()
							if typeof(firetouchinterest) == "function" then
								firetouchinterest(medal, hrp, 0)
								task.wait()
								firetouchinterest(medal, hrp, 1)
							end
						end)
					end
				end
			end
		end
	end
end

return Magnet
