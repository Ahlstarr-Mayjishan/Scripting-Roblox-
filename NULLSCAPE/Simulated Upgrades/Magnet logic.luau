-- [[
--  NULLSCAPE - Gift Magnet Bypass / Auto-Collect Logic
--  Vai trò: Tự động thu thập quà trong phạm vi cấu hình mà không gây sụt giảm FPS.
--  Tối ưu hóa: Sử dụng CollectionService để định vị các phần quà nhanh chóng và hiệu quả.
-- ]]

local Magnet = {}
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local lastCollectTime = 0
local COLLECT_DELAY = 0.35 -- Khoảng trễ nhặt giữa các hộp quà ở chế độ Legit (giây)

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
    local GiftCollected = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("GiftCollected")
    local CollectedGiftEvent = ReplicatedStorage:FindFirstChild("Movement") 
        and ReplicatedStorage.Movement:FindFirstChild("Events") 
        and ReplicatedStorage.Movement.Events:FindFirstChild("CollectedGift")
        
    if not GiftCollected then return end
    
    local gifts = CollectionService:GetTagged("Gift")
    local hrpPos = hrp.Position
    local validGifts = {}
    
    for _, gift in ipairs(gifts) do
        if gift:IsDescendantOf(workspace) then
            -- Kiểm tra xem quà đã được thu thập hay chưa
            local isCollected = (gift:GetAttribute("Collected") == true) or (gift:GetAttribute("ClientCollected") == true)
            if not isCollected then
                -- Bỏ qua Tripmine
                local giftType = gift:GetAttribute("GiftType")
                local giftName = gift.Name:lower()
                local isMine = (giftType and string.find(giftType:lower(), "tripmine")) or string.find(giftName, "tripmine")
                if not isMine then
                    -- Lấy vị trí bắt đầu
                    local startPos = gift:GetAttribute("StartPosition") 
                        or (gift:IsA("BasePart") and gift.Position)
                        or (gift:IsA("Model") and gift.PrimaryPart and gift.PrimaryPart.Position)
                        or (gift:IsA("Model") and gift:GetPivot().Position)
                    
                    if startPos then
                        local distance = (hrpPos - startPos).Magnitude
                        if distance <= range then
                            table.insert(validGifts, {
                                part = gift,
                                dist = distance
                            })
                        end
                    end
                end
            end
        end
    end
    
    if #validGifts == 0 then return end
    
    if mode == "Legit" then
        -- Sắp xếp theo khoảng cách và chỉ nhặt 1 hộp quà gần nhất
        table.sort(validGifts, function(a, b) return a.dist < b.dist end)
        
        local target = validGifts[1].part
        target:SetAttribute("ClientCollected", true)
        
        pcall(function()
            GiftCollected:FireServer(target, range)
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
            local target = item.part
            target:SetAttribute("ClientCollected", true)
            
            pcall(function()
                GiftCollected:FireServer(target, range)
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
