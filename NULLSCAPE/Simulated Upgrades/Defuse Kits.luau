-- [[
--  NULLSCAPE - Anti-Tripmine Immunity & Defuse Kits Logic
--
--  3 CHẾ ĐỘ BẢO VỆ:
--  ───────────────────────────────────────────────────────────────────────
--  "Passthrough"  – Đi xuyên qua mìn (có iframes bảo vệ), sau khi ra ngoài
--                   phạm vi an toàn (BlastSafeRadius) mới kích nổ sau lưng.
--
--  "PreDetonate"  – Kích nổ mìn từ xa trước khi chạm. Chỉ nổ khi player
--                   đang trong phạm vi DetonationDistance và đã ở khoảng cách
--                   an toàn (BlastSafeRadius) để tránh tự sát.
--
--  "Barrier"      – Đi xuyên mìn hoàn toàn, không bao giờ nổ.
--  ───────────────────────────────────────────────────────────────────────
--
--  Tối ưu hóa Iframes & Tránh tự sát do Latency:
--  1. Giữ TRIP_IFRAMES liên tục trong suốt quá trình xử lý mìn (kể cả khi chờ nổ).
--     Không tắt iframes trước khi gửi gói tin Collect để tránh bị nổ ngược do lag gói tin.
--  2. Tốc độ kiểm tra khoảng cách an toàn nâng lên tần số cao (mỗi frame - task.wait())
--     thay vì 0.05s để tránh việc di chuyển quá nhanh đâm vào vùng nổ.
--  3. Tăng giới hạn cấu hình khoảng cách trong UI lên đến 50 studs để người chơi
--     bù đắp ping cao hoặc tốc độ di chuyển cực nhanh.
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
    -- Xóa luôn bất kỳ object nào game tự tạo hoặc thừa
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
-- processedMines[giftId] = true | "__dist_"..giftId = targetDist
-- passthroughState[giftId] = "inside" | "exited"
local processedMines = {}
local passthroughState = {}
local pendingDetonations = {}

local function clearMineState(giftId)
    processedMines[giftId] = nil
    processedMines["__dist_" .. giftId] = nil
    passthroughState[giftId] = nil
    pendingDetonations[giftId] = nil
end

local function getEffectiveSafeRadius(gift, configuredRadius)
    local sizeValue = gift and gift.Size
    local size = if type(sizeValue) == "number" then sizeValue else 1
    return math.max(configuredRadius or 8, 18, size * 10)
end

local function getGiftDistance(hrp, gift)
    if not (hrp and gift and gift.Position) then
        return math.huge
    end
    return (hrp.Position - gift.Position).Magnitude
end

local function waitUntilTripmineSafe(hrp, gift, configuredRadius, timeoutSeconds)
    local startedAt = os.clock()
    local effectiveSafeRadius = getEffectiveSafeRadius(gift, configuredRadius)

    while gift and not gift.Collected and os.clock() - startedAt < (timeoutSeconds or 10) do
        local currentDist = getGiftDistance(hrp, gift)
        if currentDist >= effectiveSafeRadius then
            return true, currentDist, effectiveSafeRadius
        end
        addIframes()
        task.wait()
    end

    return false, getGiftDistance(hrp, gift), effectiveSafeRadius
end

local function safeCollectTripmine(gift, giftId, hrp, configuredRadius, reason)
    if not (gift and not gift.Collected) then
        return false
    end

    local effectiveSafeRadius = getEffectiveSafeRadius(gift, configuredRadius)
    local currentDist = getGiftDistance(hrp, gift)
    if currentDist < effectiveSafeRadius then
        return false, currentDist, effectiveSafeRadius
    end

    addIframes()
    local ok = pcall(function()
        gift:Collect(false, true, 0)
    end)
    if ok then
        processedMines[giftId] = true
        print("[NULLSCAPE] " .. reason .. ": tripmine detonated", giftId, "at", math.round(currentDist), "studs (safe:", math.round(effectiveSafeRadius), ")")
    end
    return ok, currentDist, effectiveSafeRadius
end

local function queueSafeDetonation(giftId, gift, safeRadius, reason)
    if pendingDetonations[giftId] then
        return
    end

    pendingDetonations[giftId] = true
    task.spawn(function()
        while activeController and activeController.TripmineBarrierEnabled and gift and not gift.Collected do
            if (activeController.TripmineMode or "Passthrough") == "Barrier" then
                break
            end

            addIframes()

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                task.wait()
                continue
            end

            local isSafe = waitUntilTripmineSafe(hrp, gift, safeRadius, 0.35)
            if isSafe then
                safeCollectTripmine(gift, giftId, hrp, safeRadius, reason)
                break
            end

            task.wait()
        end

        pendingDetonations[giftId] = nil
        if gift and gift.Collected then
            clearMineState(giftId)
        end
    end)
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
            task.wait(0.05) -- 20 Hz scan các thực thể xung quanh

            if not activeController or not activeController.TripmineBarrierEnabled then
                -- Không hoạt động: đảm bảo dọn sạch iframes
                if hasIframes() then removeIframes() end
                continue
            end

            local mode = activeController.TripmineMode or "Passthrough"
            addIframes()

            -- Barrier mode: chỉ cần duy trì iframes liên tục, không cần quét nổ
            if mode == "Barrier" then
                table.clear(passthroughState)
                table.clear(pendingDetonations)
                continue
            end

            -- Các mode khác cần scan Gifts
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                addIframes() -- giữ iframes khi không có character để an toàn
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
            local safeRadius = activeController.TripmineBlastSafeRadius or 8
            local Gifts = GCH.Gifts

            -- ── Dọn dẹp trạng thái cho các mìn đã nổ/biến mất ──────────
            for id, _ in pairs(processedMines) do
                local idStr = tostring(id)
                if idStr:sub(1, 7) == "__dist_" then continue end
                local numId = tonumber(id)
                if numId and not Gifts[numId] then
                    clearMineState(numId)
                end
            end

            -- ── Quét và xử lý từng Tripmine ────────────────────────────
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
                        -- Chưa theo dõi: Player bắt đầu đi xuyên qua mìn
                        if dist < 6 then
                            passthroughState[giftId] = "inside"
                            addIframes()
                            -- Tính toán khoảng cách kích nổ sau khi đi xa ra ngoài
                            local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
                            processedMines["__dist_" .. giftId] = math.max(targetDist, 6)
                            print("[NULLSCAPE] Passthrough: đang đi xuyên mìn", giftId)
                        end

                    elseif state == "inside" then
                        -- Đang ở trong vùng mìn với iframes bảo vệ
                        -- Đợi cho đến khi đi ra ngoài khoảng cách kích nổ đã định
                        local targetDist = processedMines["__dist_" .. giftId] or baseDist
                        if dist >= targetDist then
                            passthroughState[giftId] = "exited"
                            print("[NULLSCAPE] Passthrough: đã đi ra cách mìn", math.round(dist), "studs, chờ khoảng cách an toàn trước khi nổ...", giftId)

                            queueSafeDetonation(giftId, gift, safeRadius, "Passthrough")
                        end
                    end

                -- ── CHẾ ĐỘ PREDETONATE ─────────────────────────────────
                elseif mode == "PreDetonate" then
                    if processedMines[giftId] or pendingDetonations[giftId] then continue end

                    -- Xác định khoảng cách kích nổ sớm cho quả mìn này
                    if not processedMines["__dist_" .. giftId] then
                        local targetDist = baseDist + (jitter > 0 and math.random(-jitter, jitter) or 0)
                        processedMines["__dist_" .. giftId] = math.max(targetDist, 5)
                    end

                    local targetDist = processedMines["__dist_" .. giftId]

                    -- Khi player đi vào vùng kích nổ sớm
                    if dist <= targetDist then
                        queueSafeDetonation(giftId, gift, safeRadius, "PreDetonate")
                    end
                end
            end

        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────
-- Barrier.update(controller) — gọi định kỳ từ controller
-- ─────────────────────────────────────────────────────────────────────
function Barrier.update(controller, gc)
    activeController = controller

    if not controller.TripmineBarrierEnabled then
        removeIframes()
        -- Reset trạng thái khi tắt bypass
        table.clear(processedMines)
        table.clear(passthroughState)
        table.clear(pendingDetonations)
    end
end

-- ─────────────────────────────────────────────────────────────────────
-- Init
-- ─────────────────────────────────────────────────────────────────────
function Barrier.Init()
    startWatcher()
    print("[NULLSCAPE Defuse] Module khởi tạo thành công. Bảo vệ: Passthrough | PreDetonate | Barrier")
end

Barrier.Init()

return Barrier
