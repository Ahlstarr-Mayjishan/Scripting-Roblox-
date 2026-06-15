-- [[
--  NULLSCAPE - Anti-Tripmine Immunity & Defuse Kits Logic
--  Vai trò: Chuyên phụ trách việc bypass nổ mìn Tripmine:
--  - Hook chặn RemoteEvent gửi tín hiệu nổ lên server từ phía Client thông qua hệ thống Single-dispatch.
--  - Ghi đè thuộc tính CanTouch và CanCollide của mìn về false để triệt tiêu va chạm vật lý trên Client.
-- ]]

local Barrier = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local activeController = nil

-- Đảm bảo _NULLSCAPE_Globals tồn tại
getgenv()._NULLSCAPE_Globals = getgenv()._NULLSCAPE_Globals or {}

local function hookRemote()
    if getgenv()._NULLSCAPE_Globals.GiftCollectedHooked then return end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local GiftCollected = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("GiftCollected")
    if GiftCollected then
        local oldFireServer
        oldFireServer = hookfunction(GiftCollected.FireServer, function(self, gift, range)
            local dispatcher = getgenv()._NULLSCAPE_Globals.handleGiftCollectedCall
            if dispatcher then
                local success, shouldOverride = pcall(dispatcher, self, gift, range)
                if success and shouldOverride then
                    return -- Chặn đứng remote nổ mìn
                end
            end
            return oldFireServer(self, gift, range)
        end)
        getgenv()._NULLSCAPE_Globals.OriginalGiftCollectedFireServer = oldFireServer
        getgenv()._NULLSCAPE_Globals.GiftCollectedHooked = true
        print("[NULLSCAPE Defuse] Đã hook thành công GiftCollected RemoteEvent")
    end
end

-- Đăng ký dispatcher toàn cục
getgenv()._NULLSCAPE_Globals.handleGiftCollectedCall = function(self, gift, range)
    if activeController and gift and gift:IsDescendantOf(workspace) then
        local giftType = gift:GetAttribute("GiftType")
        local giftName = gift.Name:lower()
        local isMine = (giftType and string.find(giftType:lower(), "tripmine")) or string.find(giftName, "tripmine")
        if isMine then
            -- Nếu mìn đã được kích nổ chủ động hoặc tháo gỡ thành công từ trước, chặn cuộc gọi từ game
            if gift:GetAttribute("Detonated") or gift:GetAttribute("Defused") then
                return true
            end

            if activeController.TripmineBarrierEnabled then
                local mode = activeController.TripmineMode or "Delayed"
                if mode == "Delayed" then
                    -- Chặn remote tức thời và nổ sau khi chạy ra khoảng cách an toàn
                    task.spawn(function()
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local baseDist = activeController.TripmineDetonationDistance or 15
                            local jitter = activeController.TripmineDetonationJitter or 2
                            local targetDist = baseDist
                            if jitter > 0 then
                                targetDist = baseDist + math.random(-jitter, jitter)
                            end
                            
                            local startTime = os.clock()
                            while gift and gift.Parent and (os.clock() - startTime < 3.0) do
                                local diff = hrp.Position - gift.Position
                                if diff.Magnitude >= targetDist then
                                    break
                                end
                                task.wait(0.1)
                            end
                            
                            if gift and gift.Parent then
                                local orig = getgenv()._NULLSCAPE_Globals.OriginalGiftCollectedFireServer
                                if orig then
                                    orig(self, gift, range)
                                else
                                    self:FireServer(gift, range)
                                end
                            end
                        end
                    end)
                    return true -- Chặn cuộc gọi gốc tức thời
                else
                    -- Chế độ Barrier: Chặn hoàn toàn nổ mìn
                    return true
                end
            elseif activeController.SimulateDefuseKit then
                -- Check xem mìn đã được xử lý defuse trước đó chưa
                if gift:GetAttribute("Defused") then
                    return true
                elseif gift:GetAttribute("DefuseFailed") then
                    return false
                end

                -- Thực hiện roll tỷ lệ thành công (20% * Stack)
                local stack = activeController.DefuseKitStack or 3
                local chance = stack * 0.20
                local roll = math.random()
                if roll <= chance then
                    -- Defuse thành công!
                    gift:SetAttribute("Defused", true)

                    -- Phát âm thanh cắt dây
                    local sound = Instance.new("Sound")
                    sound.SoundId = "rbxassetid://118717483906381"
                    sound.Volume = 1.0
                    sound.Parent = game:GetService("SoundService")
                    sound:Play()
                    game:GetService("Debris"):AddItem(sound, 3)

                    -- Vô hiệu hóa va chạm và cảm ứng của mìn locally
                    pcall(function()
                        if gift:IsA("BasePart") then
                            gift.Transparency = 1
                            gift.CanCollide = false
                            gift.CanTouch = false
                        end
                        for _, child in ipairs(gift:GetDescendants()) do
                            if child:IsA("BasePart") then
                                child.Transparency = 1
                                child.CanCollide = false
                                child.CanTouch = false
                            elseif child:IsA("Texture") or child:IsA("Decal") then
                                child.Enabled = false
                            end
                        end
                    end)

                    return true
                else
                    -- Defuse thất bại -> Cho nổ mìn bình thường
                    gift:SetAttribute("DefuseFailed", true)
                    return false
                end
            end
        end
    end
    return false
end

-- Tự động thực hiện hook khi nạp file nếu môi trường hỗ trợ
if typeof(hookfunction) == "function" then
    pcall(hookRemote)
end

function Barrier.update(controller, gc)
    activeController = controller
    
    local enabled = controller.TripmineBarrierEnabled
    if not enabled then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local activeGifts = controller.ActiveGifts or {}
    local hrpPos = hrp.Position
    local mode = controller.TripmineMode or "Delayed"
    
    if mode == "Delayed" then
        -- Chế độ Delayed: Chủ động kích nổ mìn từ xa khi người chơi lại gần khoảng cách an toàn
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local GiftCollected = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("GiftCollected")
        if not GiftCollected then return end
        
        local baseDist = controller.TripmineDetonationDistance or 15
        local jitter = controller.TripmineDetonationJitter or 2
        
        for _, g in ipairs(activeGifts) do
            if g.type == "Tripmine" or g.type == "GoldenTripmine" then
                -- Giải quyết realPart và realModel từ đối tượng rawObj nếu có
                local realPart = g.part
                local realModel = g.model
                if g.rawObj and g.rawObj.Model then
                    realModel = g.rawObj.Model
                    if realModel:IsA("Model") then
                        realPart = realModel.PrimaryPart or realModel:FindFirstChild("HumanoidRootPart") or realModel:FindFirstChildWhichIsA("BasePart") or realModel
                    else
                        realPart = realModel
                    end
                end
                
                if realPart and realPart.Parent and realPart:IsDescendantOf(workspace) then
                    local isDetonated = realPart:GetAttribute("Detonated")
                    local isDefused = realPart:GetAttribute("Defused")
                    
                    if not isDetonated and not isDefused then
                        local pos = realPart:IsA("BasePart") and realPart.Position or (g.part and g.part:IsA("BasePart") and g.part.Position)
                        if pos then
                            local dist = (hrpPos - pos).Magnitude
                            
                            local targetDist: number = baseDist
                            if jitter > 0 then
                                local detDist = realPart:GetAttribute("DetonationDist")
                                if typeof(detDist) == "number" then
                                    targetDist = detDist
                                else
                                    local randomDist = baseDist + math.random(-jitter, jitter)
                                    realPart:SetAttribute("DetonationDist", randomDist)
                                    targetDist = randomDist
                                end
                            end
                            
                            -- Kích nổ từ xa khi ở trong khoảng cách an toàn nhưng phải lớn hơn 4.5 studs để tránh nổ sát người
                            if dist <= targetDist and dist > 4.5 then
                                realPart:SetAttribute("Detonated", true)
                                
                                -- Ẩn locally để tránh hiển thị ESP và giảm tải đồ họa trên client
                                pcall(function()
                                    if realPart:IsA("BasePart") then
                                        realPart.Transparency = 1
                                        realPart.CanCollide = false
                                        realPart.CanTouch = false
                                    end
                                    if realModel then
                                        if realModel:IsA("BasePart") then
                                            realModel.Transparency = 1
                                            realModel.CanCollide = false
                                            realModel.CanTouch = false
                                        end
                                        for _, child in ipairs(realModel:GetDescendants()) do
                                            if child:IsA("BasePart") then
                                                child.Transparency = 1
                                                child.CanCollide = false
                                                child.CanTouch = false
                                            elseif child:IsA("Texture") or child:IsA("Decal") then
                                                child.Enabled = false
                                            end
                                        end
                                    end
                                    -- Ẩn cả proxyPart ảo nếu có để ESP ngừng vẽ
                                    if g.part and g.part ~= realPart and g.part:IsA("BasePart") then
                                        g.part.Transparency = 1
                                    end
                                end)
                                
                                task.spawn(function()
                                    local orig = getgenv()._NULLSCAPE_Globals.OriginalGiftCollectedFireServer
                                    if orig then
                                        pcall(orig, GiftCollected, realPart, 30)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
    elseif mode == "Barrier" then
        -- Chỉ tắt va chạm vật lý mìn khi ở chế độ Barrier (Đi xuyên)
        for _, g in ipairs(activeGifts) do
            if g.type == "Tripmine" or g.type == "GoldenTripmine" then
                -- Giải quyết realPart và realModel từ đối tượng rawObj nếu có
                local realPart = g.part
                local realModel = g.model
                if g.rawObj and g.rawObj.Model then
                    realModel = g.rawObj.Model
                    if realModel:IsA("Model") then
                        realPart = realModel.PrimaryPart or realModel:FindFirstChild("HumanoidRootPart") or realModel:FindFirstChildWhichIsA("BasePart") or realModel
                    else
                        realPart = realModel
                    end
                end
                
                if realPart and realPart.Parent and realPart:IsDescendantOf(workspace) then
                    -- Vô hiệu hóa va chạm và cảm ứng của Part chính
                    if realPart:IsA("BasePart") then
                        if realPart.CanCollide ~= false then
                            pcall(function() realPart.CanCollide = false end)
                        end
                        if realPart.CanTouch ~= false then
                            pcall(function() realPart.CanTouch = false end)
                        end
                    end
                    
                    -- Vô hiệu hóa va chạm của toàn bộ các bộ phận con của mìn (nếu là Model)
                    if realModel then
                        if realModel:IsA("BasePart") then
                            if realModel.CanCollide ~= false then
                                pcall(function() realModel.CanCollide = false end)
                            end
                            if realModel.CanTouch ~= false then
                                pcall(function() realModel.CanTouch = false end)
                            end
                        end
                        for _, child in ipairs(realModel:GetDescendants()) do
                            if child:IsA("BasePart") then
                                if child.CanCollide ~= false then
                                    pcall(function() child.CanCollide = false end)
                                end
                                if child.CanTouch ~= false then
                                    pcall(function() child.CanTouch = false end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

return Barrier
