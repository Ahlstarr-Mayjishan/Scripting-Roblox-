--[[
    AttributeCleaner.lua — OOP Debuff Cleaning Class
    Removes debuff flags from character (Values, Attributes).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AttributeCleaner = {}
AttributeCleaner.__index = AttributeCleaner

function AttributeCleaner.new(options)
    local self = setmetatable({}, AttributeCleaner)
    self.Options = options
    return self
end

function AttributeCleaner:Init()
    RunService.Heartbeat:Connect(function()
        if not self.Options.NoDelay then return end
        
        local char = Players.LocalPlayer.Character
        if not char then return end
        
        -- Value Destroyer (slow, stun, freeze, root, debuff, delay)
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("ValueBase") then
                local n = child.Name:lower()
                if n:find("slow") or n:find("stun") or n:find("freeze") 
                   or n:find("root") or n:find("debuff") or n:find("delay")
                   or n:find("cooldown") then
                    child:Destroy()
                end
            end
        end
        
        -- Attribute Sweeper
        for attr, _ in pairs(char:GetAttributes()) do
            local lower = attr:lower()
            if lower:find("slow") or lower:find("stun") or lower:find("freeze")
               or lower:find("delay") or lower:find("debuff") then
                char:SetAttribute(attr, nil)
            end
        end
    end)
end

return AttributeCleaner
