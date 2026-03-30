--[[
    Aimbot.lua — Pure OOP Camera Lock Class
    Handles smooth camera manipulation for tracking targets.
]]

local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local Aimbot = {}
Aimbot.__index = Aimbot

function Aimbot.new(config)
    local self = setmetatable({}, Aimbot)
    self.Config = config
    self.Options = config.Options
    self.Active = false
    return self
end

function Aimbot:Update(targetPosition, smoothness)
    if not targetPosition then return end
    
    local alpha = smoothness or self.Options.Smoothness or 0.15
    local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPosition)
    
    -- Safety check for NaN
    if targetPosition.X == targetPosition.X then
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, alpha)
    end
end

function Aimbot:SetState(active)
    self.Active = active
end

return Aimbot
