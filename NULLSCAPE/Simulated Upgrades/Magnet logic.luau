-- [[
--  NULLSCAPE - Gift Magnet Bypass / Auto-Collect Logic
--  Vai trò: Tự động thu thập quà trong phạm vi cấu hình mà không gây sụt giảm FPS.
--  Tối ưu hóa: Loại bỏ hoàn toàn việc quét GetDescendants() liên tục, chỉ sử dụng dữ liệu từ ActiveGifts.
-- ]]

local Magnet = {}
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
    
    local hrpPos = hrp.Position
    local validGifts = {}
    
    -- Chỉ duyệt qua danh sách ActiveGifts đã được controller cập nhật thời gian thực bằng Event
    if controller.ActiveGifts then
        for _, g in ipairs(controller.ActiveGifts) do
            local part = g.part
            local model = g.model
            
            -- Xác định đối tượng chính để tương tác (thường là Model hoặc Part gốc được Server quản lý)
            local mainObject = model or part
            
            if mainObject and mainObject:IsDescendantOf(workspace) and g.type ~= "Tripmine" and g.type ~= "GoldenTripmine" then
                -- Kiểm tra xem quà đã được thu thập hay chưa (dùng cả Attribute trên Model hoặc Part)
                local isCollected = (mainObject:GetAttribute("Collected") == true) 
                    or (mainObject:GetAttribute("ClientCollected") == true)
                    or (part and part:GetAttribute("Collected") == true)
                    or (part and part:GetAttribute("ClientCollected") == true)
                
                if not isCollected then
                    -- Lấy vị trí bắt đầu
                    local startPos = mainObject:GetAttribute("StartPosition") 
                        or (part and part:GetAttribute("StartPosition"))
                        or (part and part.Position) 
                        or mainObject.Position
                        
                    if startPos then
                        local distance = (hrpPos - startPos).Magnitude
                        if distance <= range then
                            table.insert(validGifts, {
                                mainObj = mainObject, 
                                partObj = part,
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
        
        local target = validGifts[1].mainObj
        local part = validGifts[1].partObj
        
        target:SetAttribute("ClientCollected", true)
        if part then
            part:SetAttribute("ClientCollected", true)
        end
        
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
            local target = item.mainObj
            local part = item.partObj
            
            target:SetAttribute("ClientCollected", true)
            if part then
                part:SetAttribute("ClientCollected", true)
            end
            
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
