--[[
    GodMode.lua - Biological Preservation Module (v5 Ghost Edition)
    Job: Locking health and HIDING the humanoid from game sensors.
    Logic: Renames Humanoid to a random string to bypass FindFirstChild("Humanoid").
]]

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local GodMode = {}
GodMode.__index = GodMode

function GodMode.new(options, localCharacter)
    local self = setmetatable({}, GodMode)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.OriginalName = "Humanoid"
    self.GhostName = "_SG_" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
    self.Status = "Idle"
    return self
end

function GodMode:_rename(humanoid, toName)
    if not humanoid then return end
    if humanoid.Name ~= toName then
        pcall(function()
            humanoid.Name = toName
        end)
    end
end

function GodMode:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        
        if not self.Options.GodModeEnabled then
            if humanoid and humanoid.Name ~= self.OriginalName then
                self:_rename(humanoid, self.OriginalName)
            end
            self.Status = "Disabled"
            return
        end

        if not humanoid then
            self.Status = "Hum Missing"
            return
        end

        -- 1. Stealth Mode: Rename to hide from game scripts
        self:_rename(humanoid, self.GhostName)

        -- 2. Void Health Lock
        humanoid.MaxHealth = 9e18
        humanoid.Health = 9e18
        
        if humanoid.Health < 1 then
            humanoid.Health = 9e18
        end

        -- 3. physical Reinforcement
        humanoid.RequiresNeck = false
        
        local character = self.LocalCharacter:GetCharacter()
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("Motor6D") or part:IsA("Weld") or part:IsA("ManualWeld") then
                    if part.Enabled == false then
                        part.Enabled = true
                    end
                end
            end
        end

        -- 4. State Lockdown
        if humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead) then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end
        
        if humanoid:GetState() == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end

        self.Status = "Active: GHOST MODE v5"
    end)
end

function GodMode:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if humanoid then
        self:_rename(humanoid, self.OriginalName)
        pcall(function()
            humanoid.MaxHealth = 100
            humanoid.Health = 100
            humanoid.RequiresNeck = true
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end)
    end
end

return GodMode
