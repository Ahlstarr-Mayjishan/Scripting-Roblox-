--[[
    SpeedSpoof.lua — OOP Metamethod Hooking Class
    Masks real speed from game server checks.
]]

local Players = game:GetService("Players")

local SpeedSpoof = {}
SpeedSpoof.__index = SpeedSpoof

function SpeedSpoof.new(options)
    local self = setmetatable({}, SpeedSpoof)
    self.Options = options
    self._isHooked = false
    return self
end

function SpeedSpoof:Init()
    if not hookmetamethod or self._isHooked then return end
    
    local Options = self.Options
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(obj, index)
        if not checkcaller() and typeof(obj) == "Instance" and obj:IsA("Humanoid") then
            if Options.SpeedSpoofEnabled then
                if index == "WalkSpeed" then return 16 end
                if index == "JumpPower" then return 50 end
            end
        end
        return oldIndex(obj, index)
    end))
    
    self._isHooked = true
end

return SpeedSpoof
