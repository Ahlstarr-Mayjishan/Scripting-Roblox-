--[[
    BossDetector.lua - OOP Target Classification Class
    Identifies if an NPC is a boss based on common properties (Size, Health, Height).
]]

local BossDetector = {}
BossDetector.__index = BossDetector

function BossDetector.new()
    local self = setmetatable({}, BossDetector)
    self.CheckInterval = 10
    return self
end

function BossDetector:IsBoss(model, humanoid)
    local humanoid = humanoid or (model and model:FindFirstChildOfClass("Humanoid"))
    if not humanoid then return false end
    
    -- Size-based Boss check
    local cf, size = model:GetBoundingBox()
    local boundsScale = size.X * size.Y * size.Z
    
    -- Simple thresholds:
    -- Standard NPC Vol ~ 8-15
    -- Bosses usually scale > 2x
    if boundsScale > 70 then return true end
    
    -- Health-based check
    if humanoid.MaxHealth > 500 then return true end
    
    -- DisplayName check
    if humanoid.DisplayName:lower():find("boss") or humanoid.DisplayName:lower():find("king") then
        return true
    end
    
    return false
end

return BossDetector

