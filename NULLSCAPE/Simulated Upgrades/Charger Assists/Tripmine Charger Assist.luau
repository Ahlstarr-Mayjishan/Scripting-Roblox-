--!nocheck
-- [[
--  NULLSCAPE - Charger Tripmine Assists
--  Temporary home for tripmine Passthrough / PreDetonate style helpers.
--  These modes are intentionally separate from Defuse Kits because they depend
--  on movement/class timing and are not reliable server-side immunity.
-- ]]

local ChargerAssist = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PASSTHROUGH_MODE = "Passthrough"
local PREDETONATE_MODE = "PreDetonate"

local activeController = nil
local watcherRunning = false
local cachedGCH = nil
local iframeObject = nil
local processedMines = {}
local passthroughState = {}
local logs = {}

local function isChargerAssistMode(mode)
    return mode == PASSTHROUGH_MODE or mode == PREDETONATE_MODE
end

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

local function clearMineState(giftId)
    processedMines[giftId] = nil
    processedMines["__dist_" .. giftId] = nil
    passthroughState[giftId] = nil
end

local function clearState()
    table.clear(processedMines)
    table.clear(passthroughState)
    table.clear(logs)
end

local function logOnce(giftId, reason, dist)
    local key = reason .. ":" .. tostring(giftId)
    if logs[key] then
        return
    end

    logs[key] = true
    print("[NULLSCAPE Charger Assist] " .. reason, giftId, "at", math.round(dist), "studs")
end

local function startWatcher()
    if watcherRunning then
        return
    end
    watcherRunning = true

    task.spawn(function()
        while true do
            task.wait(0.05)

            local mode = activeController and activeController.ChargerTripmineMode
            if not (activeController and activeController.ChargerTripmineAssistEnabled and isChargerAssistMode(mode)) then
                removeIframes()
                clearState()
                continue
            end

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
            local baseDist = activeController.ChargerTripmineDistance or activeController.TripmineDetonationDistance or 15
            local jitter = activeController.ChargerTripmineJitter or activeController.TripmineDetonationJitter or 2

            for id in pairs(processedMines) do
                local idText = tostring(id)
                if idText:sub(1, 7) ~= "__dist_" then
                    local giftId = tonumber(id)
                    if giftId and not GCH.Gifts[giftId] then
                        clearMineState(giftId)
                    end
                end
            end

            for giftId, gift in pairs(GCH.Gifts) do
                if not gift.Tripmine or gift.Collected then
                    clearMineState(giftId)
                    continue
                end

                local giftPos = gift.Position
                if typeof(giftPos) ~= "Vector3" then
                    continue
                end

                local dist = (hrpPos - giftPos).Magnitude
                if mode == PASSTHROUGH_MODE then
                    local state = passthroughState[giftId]
                    if not state and dist < 6 then
                        passthroughState[giftId] = "inside"
                        local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
                        processedMines["__dist_" .. giftId] = math.max(targetDist, 6)
                        logOnce(giftId, "PassthroughEntered", dist)
                    elseif state == "inside" then
                        local targetDist = processedMines["__dist_" .. giftId] or baseDist
                        if dist >= targetDist then
                            logOnce(giftId, "PassthroughExited", dist)
                            clearMineState(giftId)
                        end
                    end
                elseif mode == PREDETONATE_MODE then
                    if processedMines[giftId] then
                        continue
                    end

                    if not processedMines["__dist_" .. giftId] then
                        local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
                        processedMines["__dist_" .. giftId] = math.max(targetDist, 5)
                    end

                    local targetDist = processedMines["__dist_" .. giftId]
                    if dist <= targetDist then
                        processedMines[giftId] = true
                        logOnce(giftId, "PreDetonateWindow", dist)
                    end
                end
            end
        end
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
    print("[NULLSCAPE Charger Assist] Module ready. Modes: Passthrough | PreDetonate")
end

ChargerAssist.Init()

return ChargerAssist
