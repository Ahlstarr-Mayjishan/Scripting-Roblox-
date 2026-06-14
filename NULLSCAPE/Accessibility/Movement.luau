-- [[
--  NULLSCAPE - Movement Control Logic
--  Vai trò: Điều khiển chuyển động nhân vật, giảm/xóa momentum (quán tính) để đổi hướng tức thì.
-- ]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Logic = {
    Connection = nil,
    MomentumReduction = 0
}

function Logic.start(controller, gc)
    if Logic.Connection then return end
    
    local LocalPlayer = Players.LocalPlayer
    
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
            local walkSpeed = humanoid.WalkSpeed
            
            -- Tính toán vận tốc mục tiêu trên trục X và Z
            local targetX = moveDirection.X * walkSpeed
            local targetZ = moveDirection.Z * walkSpeed
            
            local currentVelocity = root.AssemblyLinearVelocity
            
            -- LERP vận tốc hiện tại về vận tốc mục tiêu dựa vào tỉ lệ reduction
            local newX = currentVelocity.X + (targetX - currentVelocity.X) * reduction
            local newZ = currentVelocity.Z + (targetZ - currentVelocity.Z) * reduction
            
            root.AssemblyLinearVelocity = Vector3.new(newX, currentVelocity.Y, newZ)
        end
    end)
    
    if gc then
        gc.registerConnection(Logic.Connection)
    end
end

function Logic.stop()
    if Logic.Connection then
        pcall(function() Logic.Connection:Disconnect() end)
        Logic.Connection = nil
    end
end

function Logic.setReduction(value)
    Logic.MomentumReduction = tonumber(value) or 0
end

return Logic
