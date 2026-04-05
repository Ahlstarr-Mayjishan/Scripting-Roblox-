--[[
    Noclip.lua - Phase Shifting Module
    Job: Disabling physics collisions for the local character.
    Status: Active frame-by-frame collision override.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Noclip = {}
Noclip.__index = Noclip

function Noclip.new(options, localCharacter)
    local self = setmetatable({}, Noclip)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    return self
end

function Noclip:Init()
    -- Use Stepped to override internal engine physics before the next frame is rendered
    self.Connection = RunService.Stepped:Connect(function()
        if not self.Options.NoclipEnabled then
            self.Status = "Disabled"
            return
        end

        local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        if not character then
            self.Status = "Char Missing"
            return
        end

        self.Status = "Active: NOCLIP ENABLED"
        
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

function Noclip:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return Noclip
