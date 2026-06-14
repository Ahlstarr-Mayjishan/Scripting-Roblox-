-- [[
--  NULLSCAPE - Auto Jump Springer Logic
--  Vai trò: Chứa logic tính toán thời gian lan truyền sóng của Springer và tự động thực hiện nhảy né tránh.
-- ]]

local Logic = {}

-- Kiểm tra trạng thái Curse đang hoạt động (Tìm kiếm BoolValue trước, fallback về Module)
local function isCurseActive(curseName)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    -- 1. Tìm trực tiếp BoolValue trong ReplicatedStorage (tương tự InRound)
    local directVal = ReplicatedStorage:FindFirstChild(curseName)
    if directVal and directVal:IsA("BoolValue") then
        return directVal.Value
    end
    
    -- 2. Tìm trong các thư mục Curses thông dụng
    for _, folderName in ipairs({"Curses", "ActiveCurses", "Curse"}) do
        local folder = ReplicatedStorage:FindFirstChild(folderName)
        if folder then
            local val = folder:FindFirstChild(curseName)
            if val and val:IsA("BoolValue") then
                return val.Value
            end
        end
    end
    
    -- 3. Fallback: Require Module của game nếu không tìm thấy Value
    local isActive = false
    pcall(function()
        local ReplicatedFirst = game:GetService("ReplicatedFirst")
        local CurseHandler = require(ReplicatedFirst.ClientModules.CurseHandler)
        isActive = CurseHandler.IsCurseEnabled(curseName)
    end)
    return isActive
end

-- Thiết lập tự động nhảy né tránh sóng cho Springer
function Logic.setupAutoJump(enemy, shockwave, controller, gc)
    if not shockwave then return end
    
    local conn = shockwave:GetPropertyChangedSignal("CanTouch"):Connect(function()
        if not controller.SpringerAutoJumpEnabled then return end
        if not shockwave.CanTouch then return end
        
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        
        if hrp and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            local shockwavePos = shockwave.Position
            local playerPos = hrp.Position
            
            -- Tránh hiểu lầm khi làn sóng ở trên đầu hoặc dưới chân (khác cao độ/level)
            local heightDiff = math.abs(playerPos.Y - shockwavePos.Y)
            if heightDiff > 10 then return end
            
            local dist = (Vector3.new(playerPos.X, 0, playerPos.Z) - Vector3.new(shockwavePos.X, 0, shockwavePos.Z)).Magnitude
            if dist > 150 then return end
            
            local isSpringloaded = isCurseActive("Springloaded")
            
            local maxRadius = isSpringloaded and 128 or 64
            local duration = isSpringloaded and 2.5 or 1.5
            
            if dist < maxRadius then
                -- Tính toán chính xác thời điểm sóng chạm chân người chơi theo phương trình Easing EasingStyle.Sine, EasingDirection.Out
                local ratio = math.clamp(dist / maxRadius, 0, 1)
                local t_reach = duration * (2 / math.pi) * math.asin(ratio)
                local t_jump = t_reach - 0.18 -- Trừ đi thời gian cất cánh của nhân vật (~0.18s)
                
                if t_jump > 0 then
                    task.delay(t_jump, function()
                        -- Kiểm tra lại xem người chơi còn sống, vẫn ở trên mặt đất và trong vùng ảnh hưởng không
                        if controller.SpringerAutoJumpEnabled and LocalPlayer.Character == char and humanoid.Parent and humanoid.FloorMaterial ~= Enum.Material.Air then
                            local currentPos = hrp.Position
                            local currentDist = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(shockwavePos.X, 0, shockwavePos.Z)).Magnitude
                            if currentDist < maxRadius then
                                humanoid.Jump = true
                            end
                        end
                    end)
                else
                    humanoid.Jump = true
                end
            end
        end
    end)
    
    gc.registerEntityConnection(enemy, conn)
end

return Logic
