--[[
    GarbageCollector.lua — Memory & Workspace Optimization v1.0
    Job: Proactive cleanup of visual debris, effects, and orphaned instances.
    Analogy: The Lymphatic System (Cleaning up cellular debris).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local GarbageCollector = {}
GarbageCollector.__index = GarbageCollector

function GarbageCollector.new(options)
    local self = setmetatable({}, GarbageCollector)
    self.Options = options
    self.Connection = nil
    self._lastClean = 0
    self._cleanInterval = 60 -- Default to every 60 seconds
    return self
end

local DEBRIS_TAGS = {
    "Debris", "Effect", "Projectile", "Shell", "Bullet", 
    "Particle", "Emitter", "Orb", "Trail", "Beam", "Visual"
}

function GarbageCollector:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.AutoCleanEnabled then return end
        
        local now = os.clock()
        if now - self._lastClean < self._cleanInterval then return end
        self._lastClean = now
        
        self:Clean()
    end)
end

function GarbageCollector:Clean()
    local count = 0
    pcall(function()
        -- 1. Workspace Cleanup (Debris & Effects)
        -- Star Glitcher creates massive amount of visual clutter.
        for _, v in ipairs(Workspace:GetChildren()) do
            if v:IsA("BasePart") or v:IsA("Model") or v:IsA("Folder") then
                local name = v.Name:lower()
                for _, tag in ipairs(DEBRIS_TAGS) do
                    if name:find(tag:lower()) and not v:FindFirstChildOfClass("Humanoid") then
                        -- Check distance: Don't delete things near player to avoid visual glitches
                        local char = LocalPlayer.Character
                        local dist = (char and char.PrimaryPart) and (v:GetPivot().Position - char.PrimaryPart.Position).Magnitude or 1000
                        
                        if dist > 300 then -- Only delete far away debris
                            v:Destroy()
                            count = count + 1
                            break
                        end
                    end
                end
            end
        end

        -- 2. Lua Memory Flush
        collectgarbage("collect")
    end)
    
    return count
end

function GarbageCollector:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return GarbageCollector
