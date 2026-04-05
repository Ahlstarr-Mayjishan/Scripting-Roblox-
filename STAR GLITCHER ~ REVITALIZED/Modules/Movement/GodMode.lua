--[[
    GodMode.lua - Biological Preservation Module
    Job: Locking health and preventing the Dead state without character reset.
]]

local RunService = game:GetService("RunService")

local GodMode = {}
GodMode.__index = GodMode

function GodMode.new(options, localCharacter)
    local self = setmetatable({}, GodMode)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    return self
end

function GodMode:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.GodModeEnabled then
            self.Status = "Disabled"
            return
        end

        local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not humanoid then
            self.Status = "Hum Missing"
            return
        end

        -- Lock Health to Max
        if humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end

        -- Disable Dead state to prevent reset on lethal damage
        if humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead) then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end
        
        -- Force state away from dead if it somehow reaches it
        if humanoid:GetState() == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.None)
        end

        self.Status = "Active: GOD MODE ENABLED"
    end)
end

function GodMode:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    -- Try to restore state if humanoid still exists
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if humanoid then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end)
    end
end

return GodMode
