-- [[
--  NULLSCAPE - Anti-Tripmine Immunity & Defuse Kits Logic
--  Vai trò: Chuyên phụ trách việc bypass nổ mìn Tripmine:
--  - Hook chặn RemoteEvent gửi tín hiệu nổ lên server từ phía Client.
--  - Ghi đè thuộc tính CanTouch và CanCollide của mìn về false để triệt tiêu va chạm vật lý trên Client.
-- ]]

local Barrier = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local activeController = nil
local hooked = false
local function hookRemote()
    if hooked then return end
    hooked = true
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local GiftCollected = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("GiftCollected")
    if GiftCollected then
        local oldFireServer
        oldFireServer = hookfunction(GiftCollected.FireServer, function(self, gift, range)
            if activeController and gift and gift:IsDescendantOf(workspace) then
                local giftType = gift:GetAttribute("GiftType")
                local giftName = gift.Name:lower()
                local isMine = (giftType and string.find(giftType:lower(), "tripmine")) or string.find(giftName, "tripmine")
                if isMine then
                    if activeController.TripmineBarrierEnabled then
                        local mode = activeController.TripmineMode or "Delayed"
                        if mode == "Delayed" then
                            -- Chặn remote tức thời
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
                                    
                                    -- Chờ cho đến khi người chơi cách quả mìn ít nhất targetDist studs
                                    -- Để phòng hờ đứng yên hoặc lag, giới hạn chờ tối đa 3 giây
                                    local startTime = os.clock()
                                    while gift and gift.Parent and (os.clock() - startTime < 3.0) do
                                        local diff = hrp.Position - gift.Position
                                        if diff.Magnitude >= targetDist then
                                            break
                                        end
                                        task.wait(0.1) -- 0.1s là khoảng thời gian tối ưu cho máy cấu hình yếu/di động
                                    end
                                    
                                    -- Gửi remote thật lên server khi đã ở khoảng cách an toàn!
                                    if gift and gift.Parent then
                                        oldFireServer(self, gift, range)
                                    end
                                end
                            end)
                            return
                        else
                            -- Chế độ Barrier: Chặn hoàn toàn Remote nhặt/nổ mìn gửi lên server (Bypass 100%)
                            return
                        end
                    elseif activeController.SimulateDefuseKit then
                        -- Check xem mìn đã được xử lý defuse trước đó chưa
                        if gift:GetAttribute("Defused") then
                            return
                        elseif gift:GetAttribute("DefuseFailed") then
                            return oldFireServer(self, gift, range)
                        end

                        -- Thực hiện roll tỷ lệ thành công (20% * Stack)
                        local stack = activeController.DefuseKitStack or 3
                        local chance = stack * 0.20
                        local roll = math.random()
                        if roll <= chance then
                            -- Defuse thành công!
                            gift:SetAttribute("Defused", true)

                            -- Phát âm thanh cắt dây của Defuse Kit
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

                            return
                        else
                            -- Defuse thất bại -> Cho nổ mìn bình thường
                            gift:SetAttribute("DefuseFailed", true)
                            return oldFireServer(self, gift, range)
                        end
                    end
                end
            end
            return oldFireServer(self, gift, range)
        end)
    end
end

-- Tự động thực hiện hook khi nạp file nếu môi trường hỗ trợ
if typeof(hookfunction) == "function" then
    pcall(hookRemote)
end

function Barrier.update(controller, gc)
    activeController = controller
    
    local enabled = controller.TripmineBarrierEnabled
    if not enabled then return end
    
    -- Chỉ tắt va chạm vật lý mìn khi ở chế độ Barrier (Đi xuyên). Chế độ Delayed (Nổ trễ) giữ nguyên va chạm.
    if controller.TripmineMode ~= "Barrier" then return end
    
    -- Lấy danh sách quà hiện tại
    local activeGifts = controller.ActiveGifts or {}
    
    -- Quét và gỡ bỏ thuộc tính va chạm vật lý của mìn (chỉ chạy khi bật Bypass)
    for _, g in ipairs(activeGifts) do
        local part = g.part
        if part and part.Parent and part:IsDescendantOf(workspace) then
            if g.type == "Tripmine" or g.type == "GoldenTripmine" then
                -- Vô hiệu hóa va chạm và cảm ứng của Part chính
                if part:IsA("BasePart") then
                    if part.CanCollide ~= false then
                        pcall(function() part.CanCollide = false end)
                    end
                    if part.CanTouch ~= false then
                        pcall(function() part.CanTouch = false end)
                    end
                end
                
                -- Vô hiệu hóa va chạm của toàn bộ các bộ phận con của mìn (nếu là Model)
                for _, child in ipairs(part:GetDescendants()) do
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

return Barrier
