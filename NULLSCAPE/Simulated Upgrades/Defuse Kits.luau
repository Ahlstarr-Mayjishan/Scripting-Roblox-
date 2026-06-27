--!nocheck
-- [[
--  NULLSCAPE - Tripmine Defuse / Barrier Logic
--  Keeps defensive tripmine modes separate from Charger-specific assists.
-- ]]

local Barrier = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local BLOCKER_MODE = "Blocker"
local BARRIER_MODE = "Barrier"
local BLOCKER_FOLDER_NAME = "NULLSCAPE_TripmineBlockers"
local BLOCKER_SCAN_RADIUS = 180
local BLOCKER_BASE_RADIUS = 7.5
local BLOCKER_REPEL_PADDING = 4
local BLOCKER_REPEL_SPEED = 46
local BLOCKER_REPEL_VERTICAL_LIFT = 4
local ACTIVE_WATCH_INTERVAL = 0.08
local IDLE_WATCH_INTERVAL = 0.35

local activeController = nil
local watcherRunning = false
local watcherToken = {}
local iframeObject = nil
local cachedGCH = nil
local blockerFolder = nil
local blockerParts = {}

local globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals = globals
globals.TripmineBarrierWatcherToken = watcherToken

local function hasIframes()
    return iframeObject ~= nil and iframeObject.Parent ~= nil
end

local function addIframes()
    if hasIframes() then
        return
    end

    local obj = Instance.new("BoolValue")
    obj.Name = "TRIP_IFRAMES"
    obj.Parent = LocalPlayer
    iframeObject = obj
end

local function removeIframes()
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

    local ok, result = pcall(function()
        return require(game:GetService("ReplicatedFirst").ClientModules.GiftClient.GiftClientHandler)
    end)
    if ok and result then
        cachedGCH = result
        return result
    end

    return nil
end

local function getBlockerFolder()
    if blockerFolder and blockerFolder.Parent then
        return blockerFolder
    end

    local existing = Workspace:FindFirstChild(BLOCKER_FOLDER_NAME)
    if existing then
        blockerFolder = existing
        return blockerFolder
    end

    local folder = Instance.new("Folder")
    folder.Name = BLOCKER_FOLDER_NAME
    folder.Parent = Workspace
    blockerFolder = folder
    return folder
end

local function destroyBlocker(giftId)
    local part = blockerParts[giftId]
    if part then
        pcall(function()
            part:Destroy()
        end)
        blockerParts[giftId] = nil
    end
end

local function clearBlockers()
    for giftId in pairs(blockerParts) do
        destroyBlocker(giftId)
    end
end

local function getBlockerRadius(gift)
    local size = tonumber(gift and gift.Size) or 1
    return math.clamp(BLOCKER_BASE_RADIUS * size, 6, 24)
end

local function ensureBlocker(giftId, gift)
    local giftPos = gift and gift.Position
    if typeof(giftPos) ~= "Vector3" then
        destroyBlocker(giftId)
        return nil
    end

    local radius = getBlockerRadius(gift)
    local part = blockerParts[giftId]
    if not (part and part.Parent) then
        part = Instance.new("Part")
        part.Name = "TripmineBlocker_" .. tostring(giftId)
        part.Shape = Enum.PartType.Ball
        part.Anchored = true
        part.CanCollide = true
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.ForceField
        part.Color = Color3.fromRGB(255, 0, 170)
        part.Transparency = 0.58
        part.Parent = getBlockerFolder()
        blockerParts[giftId] = part
    end

    local diameter = radius * 2
    part.Size = Vector3.new(diameter, diameter, diameter)
    part.CFrame = CFrame.new(giftPos)
    return part
end

local function applyTripmineRepel(hrp, gift, dist)
    local giftPos = gift and gift.Position
    if not (hrp and typeof(giftPos) == "Vector3") then
        return
    end

    local radius = getBlockerRadius(gift)
    if dist > radius + BLOCKER_REPEL_PADDING then
        return
    end

    local away = hrp.Position - giftPos
    if away.Magnitude <= 0.05 then
        away = Vector3.new(0, 0, 1)
    end

    local flatAway = Vector3.new(away.X, 0, away.Z)
    if flatAway.Magnitude <= 0.05 then
        flatAway = away
    end
    flatAway = flatAway.Unit

    local velocity = hrp.Velocity
    local inwardSpeed = -Vector3.new(velocity.X, 0, velocity.Z):Dot(flatAway)
    local pushSpeed = math.max(BLOCKER_REPEL_SPEED, inwardSpeed + 18)
    local nextHorizontal = flatAway * pushSpeed
    local nextY = math.max(velocity.Y, BLOCKER_REPEL_VERTICAL_LIFT)
    hrp.Velocity = Vector3.new(nextHorizontal.X, nextY, nextHorizontal.Z)
end

local function updateBlockers()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        clearBlockers()
        return
    end

    local GCH = getGiftClientHandler()
    if not GCH or not GCH.Gifts then
        clearBlockers()
        return
    end

    local hrpPos = hrp.Position
    local seen = {}
    for giftId, gift in pairs(GCH.Gifts) do
        if gift.Tripmine and not gift.Collected and typeof(gift.Position) == "Vector3" then
            local dist = (hrpPos - gift.Position).Magnitude
            if dist <= BLOCKER_SCAN_RADIUS then
                seen[giftId] = true
                ensureBlocker(giftId, gift)
                applyTripmineRepel(hrp, gift, dist)
            end
        end
    end

    for giftId in pairs(blockerParts) do
        if not seen[giftId] then
            destroyBlocker(giftId)
        end
    end
end

local function startWatcher()
    if watcherRunning then
        return
    end
    watcherRunning = true

    task.spawn(function()
        local cleanedIdle = false
        while not globals or globals.TripmineBarrierWatcherToken == watcherToken do
            task.wait(activeController and activeController.TripmineBarrierEnabled and ACTIVE_WATCH_INTERVAL or IDLE_WATCH_INTERVAL)

            if not activeController or not activeController.TripmineBarrierEnabled then
                if not cleanedIdle then
                    removeIframes()
                    clearBlockers()
                    cleanedIdle = true
                end
                continue
            end
            cleanedIdle = false

            local mode = activeController.TripmineMode or BARRIER_MODE
            if mode == BARRIER_MODE or mode == BLOCKER_MODE then
                addIframes()
            else
                removeIframes()
                clearBlockers()
                continue
            end

            if mode == BLOCKER_MODE then
                updateBlockers()
            else
                clearBlockers()
            end
        end
        removeIframes()
        clearBlockers()
        watcherRunning = false
    end)
end

function Barrier.update(controller)
    activeController = controller

    if not controller.TripmineBarrierEnabled then
        removeIframes()
        clearBlockers()
    end
end

function Barrier.Init()
    startWatcher()
    print("[NULLSCAPE Defuse] Module ready. Modes: Barrier | Blocker")
end

Barrier.Init()

return Barrier
