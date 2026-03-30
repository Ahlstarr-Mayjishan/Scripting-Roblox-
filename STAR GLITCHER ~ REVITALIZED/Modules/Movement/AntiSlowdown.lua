--[[
    AntiSlowdown.lua — OOP Speed Enforcer Class
    Prevents WalkSpeed from dropping below the default (16).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AntiSlowdown = {}
AntiSlowdown.__index = AntiSlowdown

function AntiSlowdown.new(options)
    local self = setmetatable({}, AntiSlowdown)
    self.Options = options
    return self
end

function AntiSlowdown:Init()
    local oldSpeed = 16
    
    RunService.Heartbeat:Connect(function()
        if not self.Options.NoSlowdown then return end
        
        local char = Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        -- Always keep speed >= 16
        if hum.WalkSpeed < 16 then
            hum.WalkSpeed = 16
        end
        
        -- Same for JumpPower >= 50
        if hum.JumpPower < 50 then
            hum.JumpPower = 50
        end
    end)
    
    -- Hook newindex for instant reflection
    if hookmetamethod then
        local oldNewIndex
        local Options = self.Options
        oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(obj, index, value)
            if not checkcaller() and typeof(obj) == "Instance" and obj:IsA("Humanoid") then
                if Options.NoSlowdown then
                    if index == "WalkSpeed" and value < 16 then return end
                    if index == "JumpPower" and value < 50 then return end
                end
            end
            return oldNewIndex(obj, index, value)
        end))
    end
end

return AntiSlowdown
