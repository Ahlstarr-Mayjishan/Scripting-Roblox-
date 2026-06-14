-- [[
--  NULLSCAPE - Movement Control Logic (Friction Hook Edition)
--  Vai trò: Hook phương thức SetMoveDirection của MovementCore để giảm/triệt tiêu momentum mượt mà.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
    MomentumReduction = 0,
    OriginalSetMoveDirection = nil,
    Hooked = false
}

-- Tìm kiếm MovementCore động để tránh lỗi nếu ReplicatedStorage chưa tải xong
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
        local r = Logic.MomentumReduction
        if r > 0 and self.WantDirection and typeof(self.WantDirection) == "Vector3" and typeof(direction) == "Vector3" then
            -- Chỉ can thiệp khi không ở trong trạng thái quay đầu gấp (quick turn) để giữ lại animation phanh/quay đầu
            if not self.doingQuickTurn then
                local k = r
                if r < 1 then
                    -- Áp dụng đường cong lũy thừa để các mức nhỏ (như 10%, 20%) mượt mà và tự nhiên hơn
                    k = (r ^ 2) * 0.4
                end
                
                -- In log chẩn đoán mỗi 2 giây để kiểm tra giá trị thực tế truyền vào
                if not self._lastPrint or os.clock() - self._lastPrint > 2 then
                    self._lastPrint = os.clock()
                    print(string.format("[NULLSCAPE] Hook Active - r: %.3f, k: %.4f", r, k))
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
    Logic.MomentumReduction = tonumber(value) or 0
end

return Logic
