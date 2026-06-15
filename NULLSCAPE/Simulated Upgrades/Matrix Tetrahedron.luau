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
    
    -- Tránh hook lồng nhau (chaining hooks) khi chạy lại script bằng cách luôn lấy hàm gốc thực sự từ Roblox
    if not MovementCore.__original_SetMoveDirection then
        MovementCore.__original_SetMoveDirection = MovementCore.SetMoveDirection
    end
    Logic.OriginalSetMoveDirection = MovementCore.__original_SetMoveDirection
    
    if Logic.Hooked then return end
    
    MovementCore.SetMoveDirection = function(self, direction)
        local r = controller.MomentumReduction or 0.1
        if r > 0 and self.WantDirection and typeof(self.WantDirection) == "Vector3" and typeof(direction) == "Vector3" then
            local bypassQuickTurn = (r >= 0.7)
            if bypassQuickTurn or not self.doingQuickTurn then
                if bypassQuickTurn then
                    self.doingQuickTurn = false
                end
                
                -- Áp dụng công thức tính hệ số LERP dựa trên số frame hội tụ để mỗi nấc 10% khác biệt rõ rệt
                local k = 1
                if r < 1 then
                    local N = 60 * (1 - r) -- số frame hội tụ (từ 6 đến 54 frame tương ứng 90% đến 10%)
                    k = 1 - math.pow(0.1, 1 / N)
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
    if success and MovementCore and type(MovementCore) == "table" and MovementCore.__original_SetMoveDirection then
        MovementCore.SetMoveDirection = MovementCore.__original_SetMoveDirection
    end
    
    Logic.OriginalSetMoveDirection = nil
    Logic.Hooked = false
end

function Logic.setReduction(value)
    Logic.MomentumReduction = tonumber(value) or 1.0
end

return Logic
