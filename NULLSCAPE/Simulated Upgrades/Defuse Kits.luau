-- [[
--  NULLSCAPE - Anti-Tripmine Immunity & Defuse Kits Logic
--
--  3 CHẾ ĐỘ:
--  ─────────────────────────────────────────────────────────────────────
--  "Passthrough"  – Đi xuyên qua mìn mà không nổ ngay. Sau khi đi qua
--                   một khoảng cách (DetonationDistance), mìn mới nổ.
--                   Cơ chế: Duy trì TRIP_IFRAMES khi đang đứng gần mìn
--                   (< 3 studs). Khi đi ra đủ xa → remove iframes → mìn
--                   sẽ tự trigger bình thường nếu player quay lại trong
--                   2.25 studs, hoặc force Collect() từ xa.
--
--  "PreDetonate"  – Kích hoạt mìn sớm từ khoảng cách an toàn trước khi
--                   chạm vào. Player chưa cần bước vào vùng nguy hiểm.
--                   Cơ chế: Duy trì TRIP_IFRAMES để ngăn trigger tự nhiên.
--                   Khi player tiếp cận <= DetonationDistance studs → gọi
--                   gift:Collect() trực tiếp (player đang đủ xa để không
--                   nhận blast damage).
--
--  "Barrier"      – Đi xuyên mìn hoàn toàn, không bao giờ nổ.
--                   Cơ chế: Duy trì TRIP_IFRAMES vĩnh viễn.
--  ─────────────────────────────────────────────────────────────────────
--
--  Tại sao dùng TRIP_IFRAMES?
--  Game kiểm tra LocalPlayer:FindFirstChild("TRIP_IFRAMES") trong UpdateGifts
--  (GiftClientHandler, dòng 467). Nếu tìm thấy → bán kính trigger = -1
--  → không bao giờ kích hoạt mìn phía client.
-- ]]

local Barrier = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local activeController = nil

-- ─────────────────────────────────────────────────────────────────────
-- TRIP_IFRAMES helper
-- ─────────────────────────────────────────────────────────────────────
local iframeObject = nil

local function hasIframes()
    return iframeObject ~= nil and iframeObject.Parent ~= nil
end

local function addIframes()
    if hasIframes() then return end
    local obj = Instance.new("BoolValue")
    obj.Name = "TRIP_IFRAMES"
    obj.Parent = LocalPlayer
    iframeObject = obj
end

local function removeIframes()
    if iframeObject then
        pcall(function() iframeObject:Destroy() end)
        iframeObject = nil
    end
    -- Xóa luôn bất kỳ object nào game tạo
    local existing = LocalPlayer:FindFirstChild("TRIP_IFRAMES")
    if existing and existing ~= iframeObject then
        pcall(function() existing:Destroy() end)
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- Lấy GiftClientHandler từ game
-- ─────────────────────────────────────────────────────────────────────
local cachedGCH = nil
local function getGiftClientHandler()
    if cachedGCH then return cachedGCH end
    local ok, result = pcall(function()
        return require(game:GetService("ReplicatedFirst").ClientModules.GiftClient.GiftClientHandler)
    end)
    if ok and result then
        cachedGCH = result
        return result
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────
-- State tracking
-- ─────────────────────────────────────────────────────────────────────
-- processedMines[giftId] = "passthrough_tracking" | "predetonate_done" | "passthrough_done"
-- passthroughState[giftId] = "inside" | "exited"
local processedMines = {}
local passthroughState = {}

local function clearMineState(giftId)
    processedMines[giftId] = nil
    processedMines["__dist_" .. giftId] = nil
    passthroughState[giftId] = nil
end

-- ─────────────────────────────────────────────────────────────────────
-- Watcher: vòng lặp chính phát hiện và xử lý tripmines
-- ─────────────────────────────────────────────────────────────────────
local watcherRunning = false

local function startWatcher()
    if watcherRunning then return end
    watcherRunning = true

    task.spawn(function()
        while true do
            task.wait(0.05) -- 20 Hz

            if not activeController or not activeController.TripmineBarrierEnabled then
                -- Không hoạt động: đảm bảo iframes được dọn
                if hasIframes() then removeIframes() end
                continue
            end

            local mode = activeController.TripmineMode or "Passthrough"

            -- Barrier mode: chỉ cần duy trì iframes, không cần scan
            if mode == "Barrier" then
                addIframes()
                continue
            end

            -- Các mode khác cần scan Gifts
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                addIframes() -- giữ iframes khi không có character
                continue
            end

            local GCH = getGiftClientHandler()
            if not GCH or not GCH.Gifts then
                addIframes()
                continue
            end

            local hrpPos = hrp.Position
            local baseDist = activeController.TripmineDetonationDistance or 15
            local jitter = activeController.TripmineDetonationJitter or 2
            local Gifts = GCH.Gifts

            -- ── Dọn processedMines cho gifts đã biến mất ──────────────
            for id, _ in pairs(processedMines) do
                local idStr = tostring(id)
                if idStr:sub(1, 7) == "__dist_" then continue end
                local numId = tonumber(id)
                if numId and not Gifts[numId] then
                    clearMineState(numId)
                end
            end

            -- ── Scan từng tripmine ─────────────────────────────────────
            for giftId, gift in pairs(Gifts) do
                if not gift.Tripmine or gift.Collected then
                    if passthroughState[giftId] then
                        clearMineState(giftId)
                    end
                    continue
                end

                local giftPos = gift.Position
                if not giftPos then continue end
                local dist = (hrpPos - giftPos).Magnitude

                -- ── CHẾ ĐỘ PASSTHROUGH ─────────────────────────────────
                if mode == "Passthrough" then
                    local state = passthroughState[giftId]

                    if not state then
                        -- Chưa tracking: player vừa vào gần mìn
                        if dist < 6 then
                            passthroughState[giftId] = "inside"
                            addIframes()
                            -- Tính khoảng cách nổ sau khi đi ra
                            local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
                            processedMines["__dist_" .. giftId] = math.max(targetDist, 6)
                            print("[NULLSCAPE] Passthrough: đang xuyên mìn", giftId)
                        end

                    elseif state == "inside" then
                        -- Đang ở trong vùng mìn với iframes
                        -- Kiểm tra nếu đã đi ra đủ xa
                        local targetDist = processedMines["__dist_" .. giftId] or baseDist
                        if dist >= targetDist then
                            passthroughState[giftId] = "exited"
                            print("[NULLSCAPE] Passthrough: đã đi ra", math.round(dist), "studs, chuẩn bị nổ mìn", giftId)

                            -- Kiểm tra còn mìn nào khác đang "inside" không
                            local anyInside = false
                            for id2, s2 in pairs(passthroughState) do
                                if id2 ~= giftId and s2 == "inside" then
                                    anyInside = true
                                    break
                                end
                            end

                            -- Nếu không còn mìn nào đang "inside" → có thể remove iframes
                            if not anyInside then
                                removeIframes()
                            end

                            -- Force collect mìn này (nổ từ vị trí an toàn)
                            task.spawn(function()
                                task.wait(0.05) -- 1 frame delay
                                if gift and not gift.Collected then
                                    local ok = pcall(function() gift:Collect(false, true, 0) end)
                                    if ok then
                                        print("[NULLSCAPE] Passthrough: đã kích nổ mìn", giftId, "tại", math.round(dist), "studs")
                                    end
                                end
                                clearMineState(giftId)
                            end)
                        end

                    elseif state == "exited" then
                        -- Đã xử lý, chờ dọn
                    end

                    -- Đảm bảo iframes ON khi bất kỳ mìn nào đang ở "inside"
                    local anyInside = false
                    for _, s in pairs(passthroughState) do
                        if s == "inside" then
                            anyInside = true
                            break
                        end
                    end
                    if anyInside then
                        addIframes()
                    end

                -- ── CHẾ ĐỘ PREDETONATE ─────────────────────────────────
                elseif mode == "PreDetonate" then
                    -- Luôn duy trì iframes để ngăn trigger tự nhiên
                    addIframes()

                    if processedMines[giftId] then continue end

                    -- Xác định khoảng cách kích nổ cho mìn này
                    if not processedMines["__dist_" .. giftId] then
                        local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
                        processedMines["__dist_" .. giftId] = math.max(targetDist, 5)
                    end

                    local targetDist = processedMines["__dist_" .. giftId]

                    -- Khi player tiếp cận đủ gần để PreDetonate
                    if dist <= targetDist then
                        processedMines[giftId] = true

                        local capturedDist = dist
                        task.spawn(function()
                            if gift and not gift.Collected then
                                local ok = pcall(function() gift:Collect(false, true, 0) end)
                                if ok then
                                    print("[NULLSCAPE] PreDetonate: kích nổ mìn", giftId, "tại", math.round(capturedDist), "studs")
                                end
                            end
                            processedMines["__dist_" .. giftId] = nil
                        end)
                    end
                end
            end

            -- Đảm bảo iframes OFF khi không có mìn nào "inside" (Passthrough)
            if mode == "Passthrough" then
                local anyInside = false
                for _, s in pairs(passthroughState) do
                    if s == "inside" then
                        anyInside = true
                        break
                    end
                end
                if not anyInside and hasIframes() then
                    removeIframes()
                end
            end
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────
-- Barrier.update(controller) — gọi từ executor
-- ─────────────────────────────────────────────────────────────────────
function Barrier.update(controller, gc)
    activeController = controller

    if not controller.TripmineBarrierEnabled then
        removeIframes()
        -- Reset state khi tắt
        table.clear(processedMines)
        table.clear(passthroughState)
    end
    -- Logic chính chạy trong watcher loop
end

-- ─────────────────────────────────────────────────────────────────────
-- Init
-- ─────────────────────────────────────────────────────────────────────
function Barrier.Init()
    startWatcher()
    print("[NULLSCAPE Defuse] Module khởi tạo. Modes: Passthrough | PreDetonate | Barrier")
end

Barrier.Init()

return Barrier
