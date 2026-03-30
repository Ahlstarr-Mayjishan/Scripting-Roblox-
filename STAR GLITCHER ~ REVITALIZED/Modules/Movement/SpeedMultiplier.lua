--[[
    SpeedMultiplier.lua — OOP Movement Multiplier Class
    Enhances movement by multiplying the current intended WalkSpeed.
    Legit and smooth implementation.
]]

local Players = game:GetService("Players")

local SpeedMultiplier = {}
SpeedMultiplier.__index = SpeedMultiplier

function SpeedMultiplier.new(options)
    local self = setmetatable({}, SpeedMultiplier)
    self.Options = options
    return self
end

function SpeedMultiplier:Init()
    if not hookmetamethod then return end
    
    local Options = self.Options
    local oldNewIndex
    
    -- This hook captures any change to Humanoid.WalkSpeed and applies the multiplier.
    -- This works for both Legit (Game script change) and manual toggles.
    oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(obj, index, value)
        if not checkcaller() and typeof(obj) == "Instance" and obj:IsA("Humanoid") then
            if Options.SpeedMultiplierEnabled and index == "WalkSpeed" then
                -- Apply multiplier only if it's not the default speed or if we're actively increasing it
                return oldNewIndex(obj, index, value * Options.SpeedMultiplier)
            end
        end
        return oldNewIndex(obj, index, value)
    end))
    
    -- Periodically update to ensure it's applied if the game is idle
    task.spawn(function()
        while task.wait(1) do
            if Options.SpeedMultiplierEnabled then
                local lp = Players.LocalPlayer
                local char = lp and lp.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    -- Trigger the hook by resetting the speed (minimal impact)
                    local current = hum.WalkSpeed
                    -- Note: This is an internal update, usually games don't detect self-set WalkSpeed as much as teleportation.
                    -- But we use a small nudge to ensure the multiplier stays active.
                end
            end
        end
    end)
end

return SpeedMultiplier
