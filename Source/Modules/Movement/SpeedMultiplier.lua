--[[
    SpeedMultiplier.lua — OOP Character Enhancement Class
    Multiplies the player's movement speed by a user-defined factor.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local SpeedMultiplier = {}
SpeedMultiplier.__index = SpeedMultiplier

function SpeedMultiplier.new(options)
    local self = setmetatable({}, SpeedMultiplier)
    self.Options = options
    return self
end

function SpeedMultiplier:Init()
    local baseSpeed = 16
    
    RunService.Heartbeat:Connect(function()
        if not self.Options.SpeedMultiplierEnabled then return end
        
        local char = Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        local target = baseSpeed * self.Options.SpeedMultiplier
        if math.abs(hum.WalkSpeed - target) > 0.1 then
            hum.WalkSpeed = target
        end
    end)
    
    -- Hook __newindex for instant reflection
    if hookmetamethod then
        local oldNewIndex
        local Options = self.Options
        oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(obj, index, value)
            if not checkcaller() and typeof(obj) == "Instance" and obj:IsA("Humanoid") then
                if Options.SpeedMultiplierEnabled and index == "WalkSpeed" then
                    return oldNewIndex(obj, index, value * Options.SpeedMultiplier)
                end
            end
            return oldNewIndex(obj, index, value)
        end))
    end
end

return SpeedMultiplier
