--[[
    GodMode.lua - Biological Preservation Module (Ultimate Upgrade)
    Job: Locking health, preventing Dead state, and preserving joints.
    Logic: Disables the 'Dead' state and neck requirements to prevent BreakJoints success.
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

        -- 1. Ultimate Health Lock (Prevent Zero-HP flags)
        if humanoid.Health < 0.1 then
            humanoid.Health = humanoid.MaxHealth
        elseif humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end

        -- 2. Joint Preservation (Prevents dying from head-loss/BreakJoints)
        if humanoid.RequiresNeck then
            humanoid.RequiresNeck = false
        end

        -- 3. State Lockdown (Disable Dead state)
        if humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead) then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end
        
        -- 4. Force State Recovery (If server pushes a dead state)
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics) -- Alternative to None for better hit feedback
        end

        self.Status = "Active: ULTIMATE GOD MODE"
    end)
end

function GodMode:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    -- Restore defaults if possible
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if humanoid then
        pcall(function()
            humanoid.RequiresNeck = true
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end)
    end
end

return GodMode
