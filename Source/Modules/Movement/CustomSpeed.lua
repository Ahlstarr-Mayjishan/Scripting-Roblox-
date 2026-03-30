--[[
    CustomSpeed.lua — OOP Movement Speed Controller
    Forces the character's movement speed to a fixed value.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CustomSpeed = {}
CustomSpeed.__index = CustomSpeed

function CustomSpeed.new(options)
    local self = setmetatable({}, CustomSpeed)
    self.Options = options
    return self
end

function CustomSpeed:Init()
    local Options = self.Options
    
    RunService.Heartbeat:Connect(function()
        if not Options.CustomMoveSpeedEnabled then return end
        
        local char = Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        if math.abs(hum.WalkSpeed - Options.CustomMoveSpeed) > 0.1 then
            hum.WalkSpeed = Options.CustomMoveSpeed
        end
    end)
    
    -- Block game from changing it when active
    if hookmetamethod then
        local oldNewIndex
        oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(obj, index, value)
            if not checkcaller() and typeof(obj) == "Instance" and obj:IsA("Humanoid") then
                if Options.CustomMoveSpeedEnabled and index == "WalkSpeed" then
                    return oldNewIndex(obj, index, Options.CustomMoveSpeed)
                end
            end
            return oldNewIndex(obj, index, value)
        end))
    end
end

return CustomSpeed
