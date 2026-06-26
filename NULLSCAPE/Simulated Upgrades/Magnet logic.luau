--!nocheck
-- [[
--  NULLSCAPE - Gift Magnet / Auto Collect
--  Uses controller.ActiveGifts when the radar hook is healthy, then falls back
--  to the native GiftClientHandler.Gifts table so automation still works when
--  the simulated upgrade hook loads late.
-- ]]

local Magnet = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local COLLECT_DELAY = 0.35

local lastCollectTime = 0
local comboCount = 0
local lastCollectTick = 0
local cachedGCH = nil

local function getGiftClientHandler()
    if cachedGCH then
        return cachedGCH
    end

    local replicatedFirst = game:GetService("ReplicatedFirst")
    local clientModules = replicatedFirst:FindFirstChild("ClientModules") or ReplicatedStorage:FindFirstChild("ClientModules")
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

function Magnet.update(controller, hrp)
    if not controller.AutoCollectEnabled then
        return
    end
    if not hrp then
        return
    end

    local mode = controller.AutoCollectMode or "Legit"
    if mode == "Legit" and os.clock() - lastCollectTime < COLLECT_DELAY then
        return
    end

    local char = LocalPlayer.Character
    if not char then
        return
    end

    local range = controller.AutoCollectRange or 20
    local hrpPos = hrp.Position
    local validGifts = {}
    local seenRawObjects = {}

    for _, giftInfo in ipairs(controller.ActiveGifts or {}) do
        addCandidate(validGifts, seenRawObjects, giftInfo.rawObj, hrpPos, range)
    end

    local GCH = getGiftClientHandler()
    if GCH and GCH.Gifts then
        for _, rawObj in pairs(GCH.Gifts) do
            addCandidate(validGifts, seenRawObjects, rawObj, hrpPos, range)
        end
    end

    if #validGifts == 0 then
        return
    end

    local collectedEvent = getCollectedGiftEvent()
    if mode == "Legit" then
        table.sort(validGifts, function(a, b)
            return a.dist < b.dist
        end)
        collectGift(validGifts[1].rawObj, collectedEvent)
        lastCollectTime = os.clock()
        return
    end

    for _, item in ipairs(validGifts) do
        collectGift(item.rawObj, collectedEvent)
    end
end

return Magnet
