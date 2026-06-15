-- [[
--  NULLSCAPE - Gift Magnet Bypass / Auto-Collect Logic
--  Vai trò: Tự động thu thập quà trong phạm vi cấu hình mà không gây sụt giảm FPS.
--  Tối ưu hóa: Gọi trực tiếp hàm :Collect gốc của game để đồng bộ hoá 100%, bypass anticheat và có đầy đủ combo/sound.
-- ]]

local Magnet = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local lastCollectTime = 0
local COLLECT_DELAY = 0.35 -- Khoảng trễ nhặt giữa các hộp quà ở chế độ Legit (giây)

local comboCount = 0
local lastCollectTick = 0

function Magnet.update(controller, hrp)
    if not controller.AutoCollectEnabled then return end
    if not hrp then return end
    
    local mode = controller.AutoCollectMode or "Legit"
    
    -- Ở chế độ Legit, giới hạn tốc độ nhặt để tránh spam remote gây ban/kick
    if mode == "Legit" and os.clock() - lastCollectTime < COLLECT_DELAY then
        return
    end
    
    local range = controller.AutoCollectRange or 20
    local char = LocalPlayer.Character
    if not char then return end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local CollectedGiftEvent = ReplicatedStorage:FindFirstChild("Movement") 
        and ReplicatedStorage.Movement:FindFirstChild("Events") 
        and ReplicatedStorage.Movement.Events:FindFirstChild("CollectedGift")
        
    local activeGifts = controller.ActiveGifts or {}
    local hrpPos = hrp.Position
    local validGifts = {}
    
    for _, g in ipairs(activeGifts) do
        local rawObj = g.rawObj
        -- Chỉ nhặt quà chưa được thu thập/chưa bị hủy, và bỏ qua mìn (Tripmine)
        if rawObj and not rawObj.Collected and not rawObj.Destroyed and g.type ~= "Tripmine" then
            local pos = rawObj.Position
            if pos then
                local distance = (hrpPos - pos).Magnitude
                if distance <= range then
                    table.insert(validGifts, {
                        gift = g,
                        dist = distance
                    })
                end
            end
        end
    end
    
    if #validGifts == 0 then return end
    
    if mode == "Legit" then
        -- Sắp xếp theo khoảng cách và chỉ nhặt 1 hộp quà gần nhất
        table.sort(validGifts, function(a, b) return a.dist < b.dist end)
        
        local target = validGifts[1].gift
        local rawObj = target.rawObj
        
        -- Tính combo nhặt quà tương thích hoàn hảo với game gốc
        local now = tick()
        if math.min(1.2, math.pow(1.1, comboCount) * 0.8) <= now - lastCollectTick then
            comboCount = 0
        end
        comboCount = comboCount + 1
        lastCollectTick = now
        
        pcall(function()
            rawObj:Collect(false, true, comboCount)
        end)
        
        if CollectedGiftEvent then
            pcall(function()
                CollectedGiftEvent:Fire()
            end)
        end
        
        lastCollectTime = os.clock()
    else
        -- Chế độ Blatant: Nhặt toàn bộ quà trong phạm vi cùng một lúc
        for _, item in ipairs(validGifts) do
            local rawObj = item.gift.rawObj
            
            local now = tick()
            if math.min(1.2, math.pow(1.1, comboCount) * 0.8) <= now - lastCollectTick then
                comboCount = 0
            end
            comboCount = comboCount + 1
            lastCollectTick = now
            
            pcall(function()
                rawObj:Collect(false, true, comboCount)
            end)
            
            if CollectedGiftEvent then
                pcall(function()
                    CollectedGiftEvent:Fire()
                end)
            end
        end
    end
end

return Magnet
