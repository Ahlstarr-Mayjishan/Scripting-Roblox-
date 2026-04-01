--[[
    TargetSelector.lua — OOP Target Selection Class
    Logic for finding the most optimal target based on distance and FOV.
    Optimized for crosshair proximity (Zero HP Bias).
]]

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")

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
    local localCharacter = Players.LocalPlayer.Character
    local mouseX = mousePos.X
    local mouseY = mousePos.Y
    
    local entries = self.Tracker:GetTargets()
    for i = 1, #entries do
        local entry = entries[i]
        if not entry or not entry.Model or entry.Model == localCharacter then
            continue
        end

        local part = self.Tracker:GetTargetPart(entry)
        if not part or (localCharacter and part:IsDescendantOf(localCharacter)) then
            continue
        end
        
        -- Physical Distance check (Bail early if too far)
        local distToOrigin = (part.Position - originPos).Magnitude
        if distToOrigin > (self.Options.MaxDistance or 2500) then continue end
        
        -- FOV Check (Calculate screen position)
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        
        -- Behavioral Fix: Zero HP Bias (Scientific approach: Crosshair proximity only)
        -- This resolves the "Behavioral Regression" identified in the findings.
        local dx = screenPos.X - mouseX
        local dy = screenPos.Y - mouseY
        local distToMouse = math.sqrt((dx * dx) + (dy * dy))
        
        if distToMouse < shortestDist then
            shortestDist = distToMouse
            bestTarget = entry
        end
    end
    
    return bestTarget
end

return TargetSelector
