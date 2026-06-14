-- [[
--  NULLSCAPE - Movement Control Logic (Friction Hack Edition)
--  Vai trò: Hook phương thức SetMoveDirection của MovementCore để giảm/triệt tiêu momentum mượt mà.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementCoreModule = ReplicatedStorage:FindFirstChild("Movement") and ReplicatedStorage.Movement:FindFirstChild("MovementCore")

local Logic = {
    MomentumReduction = 0,
    OriginalSetMoveDirection = nil,
    Hooked = false
}

function Logic.start(controller, gc)
    if not MovementCoreModule then return end
    
    local success, MovementCore = pcall(require, MovementCoreModule)
    if not success or not MovementCore or type(MovementCore) ~= "table" then return end
    
    if Logic.Hooked then return end
    
    Logic.OriginalSetMoveDirection = MovementCore.SetMoveDirection
    if not Logic.OriginalSetMoveDirection then return end
    
    MovementCore.SetMoveDirection = function(self, direction)
        local r = Logic.MomentumReduction
        if r > 0 and self.WantDirection and typeof(self.WantDirection) == "Vector3" and typeof(direction) == "Vector3" then
            -- LERP từ hướng đã qua quán tính (direction) về hướng thô của người chơi (WantDirection)
            direction = direction:Lerp(self.WantDirection, r)
        end
        return Logic.OriginalSetMoveDirection(self, direction)
    end
    
    Logic.Hooked = true
end

function Logic.stop()
    if not Logic.Hooked then return end
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
