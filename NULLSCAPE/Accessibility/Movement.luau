-- [[
--  NULLSCAPE - Movement Control Logic (Friction & Safe Velocity Edition)
--  Vai trò: Điều khiển chuyển động nhân vật, kết hợp LERP bẻ hướng nhanh khi chạy
--  và ghi đè ma sát vật lý để phanh tức thì, tránh crash LocalScript của game và giữ hoạt ảnh phanh.
-- ]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")

local Logic = {
    Connection = nil,
    DescendantConn = nil,
    CharAddedConn = nil,
    MomentumReduction = 0,
    SavedFrictionData = {},
    DiagnosticsInitialized = false
}

-- Hệ thống chẩn đoán tự động (Diagnostics)
local function runDiagnostics(LocalPlayer)
    if Logic.DiagnosticsInitialized then return end
    Logic.DiagnosticsInitialized = true
    
    task.spawn(function()
        print("[MOVEMENT DIAGNOSTICS] Starting diagnostics...")
        local char = LocalPlayer.Character
        if not char then
            print("[MOVEMENT DIAGNOSTICS] Character not found, waiting...")
            char = LocalPlayer.CharacterAdded:Wait()
        end
        
        local humanoid = char:WaitForChild("Humanoid", 10)
        local root = char:WaitForChild("HumanoidRootPart", 10)
        
        if humanoid then
            print("[MOVEMENT DIAGNOSTICS] Humanoid found. Current WalkSpeed: " .. tostring(humanoid.WalkSpeed))
            humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                print("[MOVEMENT DIAGNOSTICS] WalkSpeed changed to: " .. tostring(humanoid.WalkSpeed))
            end)
        end
        
        if root then
            print("[MOVEMENT DIAGNOSTICS] HumanoidRootPart found.")
        end
        
        -- Quét tìm đối tượng lực trong Character
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("BodyMover") or desc:IsA("Constraint") then
                print(string.format("[MOVEMENT DIAGNOSTICS] Found force object: %s | Class: %s", desc:GetFullName(), desc.ClassName))
            end
        end
        
        -- Lắng nghe lỗi client-side để bắt lỗi nếu có script game bị crash
        ScriptContext.Error:Connect(function(message, stackTrace, scriptInstance)
            local scriptPath = scriptInstance and scriptInstance:GetFullName() or "Unknown Script"
            print(string.format("[GAME SCRIPT ERROR] Script: %s\n   Message: %s\n   Stack: %s", scriptPath, message, stackTrace))
        end)
        
        print("[MOVEMENT DIAGNOSTICS] Diagnostics successfully initialized.")
    end)
end

-- Áp dụng ma sát lớn lên part
local function applyFriction(part)
    if not part:IsA("BasePart") then return end
    if not Logic.SavedFrictionData[part] then
        Logic.SavedFrictionData[part] = {
            properties = part.CustomPhysicalProperties
        }
    end
    -- Gán ma sát tối đa (friction = 2.0, frictionWeight = 100.0)
    pcall(function()
        part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 2.0, 0.0, 100.0, 100.0)
    end)
end

-- Khôi phục ma sát gốc
local function restoreFriction(part)
    local data = Logic.SavedFrictionData[part]
    if data then
        pcall(function()
            part.CustomPhysicalProperties = data.properties
        end)
        Logic.SavedFrictionData[part] = nil
    end
end

function Logic.start(controller, gc)
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then return end
    
    -- Khởi chạy Diagnostics
    runDiagnostics(LocalPlayer)
    
    if Logic.Connection then return end
    
    local function processCharacter(char)
        if not char then return end
        
        -- Áp dụng ma sát cho các part hiện có
        for _, part in ipairs(char:GetDescendants()) do
            applyFriction(part)
        end
        
        -- Lắng nghe part mới được thêm vào
        if Logic.DescendantConn then
            pcall(function() Logic.DescendantConn:Disconnect() end)
        end
        Logic.DescendantConn = char.DescendantAdded:Connect(function(desc)
            applyFriction(desc)
        end)
    end
    
    -- Xử lý nhân vật hiện tại
    if LocalPlayer.Character then
        processCharacter(LocalPlayer.Character)
    end
    
    -- Lắng nghe khi nhân vật hồi sinh
    Logic.CharAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
        table.clear(Logic.SavedFrictionData)
        processCharacter(char)
    end)
    if gc then
        gc.registerConnection(Logic.CharAddedConn)
    end
    
    -- Chạy vòng lặp LERP bẻ hướng an toàn
    Logic.Connection = RunService.Heartbeat:Connect(function()
        if controller.Destroyed then
            Logic.stop()
            return
        end
        
        local reduction = Logic.MomentumReduction
        if reduction <= 0 then return end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        
        if root and humanoid and humanoid.Health > 0 and not humanoid.Sit then
            local moveDirection = humanoid.MoveDirection
            
            -- Chỉ can thiệp vận tốc khi đang bấm phím di chuyển
            if moveDirection.Magnitude > 0 then
                local walkSpeed = humanoid.WalkSpeed
                
                -- Tính toán vận tốc mục tiêu ngang
                local targetX = moveDirection.X * walkSpeed
                local targetZ = moveDirection.Z * walkSpeed
                
                local currentVelocity = root.AssemblyLinearVelocity
                
                -- LERP vận tốc ngang
                local newX = currentVelocity.X + (targetX - currentVelocity.X) * reduction
                local newZ = currentVelocity.Z + (targetZ - currentVelocity.Z) * reduction
                
                root.AssemblyLinearVelocity = Vector3.new(newX, currentVelocity.Y, newZ)
            else
                -- Khi buông phím di chuyển, nhường quyền kiểm soát vận tốc lại cho game
                -- Điều này ngăn game script bị crash và cho phép chạy hoạt ảnh phanh (braking animation) bình thường.
                -- Ma sát vật lý cực lớn (friction = 2.0) được gán ở trên sẽ tự động dừng nhân vật cực nhanh.
            end
        end
    end)
    
    if gc then
        gc.registerConnection(Logic.Connection)
    end
end

function Logic.stop()
    -- Ngắt kết nối loop
    if Logic.Connection then
        pcall(function() Logic.Connection:Disconnect() end)
        Logic.Connection = nil
    end
    if Logic.DescendantConn then
        pcall(function() Logic.DescendantConn:Disconnect() end)
        Logic.DescendantConn = nil
    end
    if Logic.CharAddedConn then
        pcall(function() Logic.CharAddedConn:Disconnect() end)
        Logic.CharAddedConn = nil
    end
    
    -- Khôi phục ma sát gốc của nhân vật
    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            restoreFriction(part)
        end
    end
    table.clear(Logic.SavedFrictionData)
end

function Logic.setReduction(value)
    Logic.MomentumReduction = tonumber(value) or 0
end

return Logic
