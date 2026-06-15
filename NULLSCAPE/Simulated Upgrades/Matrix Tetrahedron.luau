-- [[
--  NULLSCAPE - Matrix Tetrahedron Simulation
--  Vai trò: Giả lập nâng cấp di chuyển Matrix Tetrahedron (Level 15, Cost 2500).
--  Chức năng:
--    - Làm cho gia tốc di chuyển trở nên tức thì (instant acceleration), loại bỏ trơn trượt (slippery).
--    - Triệt tiêu gần như hoàn toàn quán tính của Ice Tiles (sàn băng).
--    - Hook phương thức SetMoveDirection của MovementCore để ghi đè hướng di chuyển mong muốn ngay lập tức.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
    MomentumReduction = 1.0, -- Mặc định là 1.0 (Instant Acceleration) cho Matrix Tetrahedron
    OriginalSetMoveDirection = nil,
    Hooked = false
}

local function getMovementCore()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    if not movement then return nil end
    return movement:FindFirstChild("MovementCore")
end

function Logic.start(controller, gc)
    local MovementCoreModule = getMovementCore()
    if not MovementCoreModule then return end
    
    local success, MovementCore = pcall(require, MovementCoreModule)
    if not success or not MovementCore or type(MovementCore) ~= "table" then return end
    
    if Logic.Hooked then return end
    
    Logic.OriginalSetMoveDirection = MovementCore.SetMoveDirection
    if not Logic.OriginalSetMoveDirection then return end
    
    MovementCore.SetMoveDirection = function(self, direction)
        local r = controller.MomentumReduction or 0.1
        if r > 0 and self.WantDirection and typeof(self.WantDirection) == "Vector3" and typeof(direction) == "Vector3" then
            local bypassQuickTurn = (r >= 0.7)
            if bypassQuickTurn or not self.doingQuickTurn then
                if bypassQuickTurn then
                    self.doingQuickTurn = false
                end
                
                -- Áp dụng đường cong lũy thừa để độ trơn trượt khác biệt rõ rệt mỗi 10%
                local k = r
                if r < 1 then
                    k = r ^ 2.2
                end
                
                direction = direction:Lerp(self.WantDirection, k)
            end
        end
        return Logic.OriginalSetMoveDirection(self, direction)
    end
    
    Logic.Hooked = true
end

function Logic.stop()
    if not Logic.Hooked then return end
    
    local MovementCoreModule = getMovementCore()
    if not MovementCoreModule then return end
    
    local success, MovementCore = pcall(require, MovementCoreModule)
    if success and MovementCore and type(MovementCore) == "table" and Logic.OriginalSetMoveDirection then
        MovementCore.SetMoveDirection = Logic.OriginalSetMoveDirection
    end
    
    Logic.OriginalSetMoveDirection = nil
    Logic.Hooked = false
end

function Logic.setReduction(value)
    Logic.MomentumReduction = tonumber(value) or 1.0
end

return Logic
