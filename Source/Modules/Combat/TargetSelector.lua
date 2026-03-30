--[[
    TargetSelector.lua — OOP Target Selection Class
    Logic for finding the most optimal target based on distance and FOV.
]]

local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local TargetSelector = {}
TargetSelector.__index = TargetSelector

function TargetSelector.new(config, tracker, predictor)
    local self = setmetatable({}, TargetSelector)
    self.Options = config.Options
    self.Tracker = tracker
    self.Predictor = predictor
    return self
end

function TargetSelector:GetClosestTarget(mousePos, originPos)
    local bestTarget = nil
    local shortestDist = self.Options.FOV or 150
    
    local entries = self.Tracker:GetTargets()
    for _, entry in pairs(entries) do
        local part = self.Tracker:GetTargetPart(entry)
        if not part then continue end
        
        -- Distance distance check
        local distToOrigin = (part.Position - originPos).Magnitude
        if distToOrigin > (self.Options.MaxDistance or 2500) then continue end
        
        -- FOV check
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        
        local distToMouse = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if distToMouse < shortestDist then
            shortestDist = distToMouse
            bestTarget = entry
        end
    end
    
    return bestTarget
end

return TargetSelector
