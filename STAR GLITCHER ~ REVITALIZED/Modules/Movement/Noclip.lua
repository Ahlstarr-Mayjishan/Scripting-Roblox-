--[[
    Noclip.lua - Phase Shifting Module (Deep v5)
    Job: Disabling physics collisions AND touch sensors.
    Status: Active frame-by-frame override via Stepped.
]]

local RunService = game:GetService("RunService")

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
    self.Connection = RunService.Stepped:Connect(function()
        if not self.Options.NoclipEnabled then
            if self.Status ~= "Disabled" then
                self.Status = "Disabled"
            end
            return
        end

        local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        if not character then
            self.Status = "Char Missing"
            return
        end

        self.Status = "Active: DEEP PHASING"
        
        -- Deep Noclip: Disable collisions, touch sensors, and raycasters
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                if obj.CanCollide then
                    obj.CanCollide = false
                end
                
                -- NEW 2024/2025 Property: Prevents .Touched events from firing
                pcall(function()
                    if obj.CanTouch then
                        obj.CanTouch = false
                    end
                    if obj.CanQuery then
                        obj.CanQuery = false
                    end
                end)
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
