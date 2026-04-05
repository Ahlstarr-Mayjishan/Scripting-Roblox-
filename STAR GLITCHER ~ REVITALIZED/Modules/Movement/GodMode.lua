--[[
    GodMode.lua - Biological Preservation Module (v4 Void Edition)
    Job: Locking health at infinity, preventing Dead state, and reinforcing joints.
    Logic: Uses math.huge and aggressive state resets to survive KillParts.
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

        -- 1. Void Health Lock (Using extreme values)
        humanoid.MaxHealth = 9e18 -- Set a massive MaxHealth
        humanoid.Health = 9e18    -- Force Health to match
        
        -- Fallback check: if somehow it goes below 1, reset immediately
        if humanoid.Health < 1 then
            humanoid.Health = 9e18
        end

        -- 2. Physical Reinforcement (Joints)
        humanoid.RequiresNeck = false
        
        local character = self.LocalCharacter:GetCharacter()
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("Motor6D") or part:IsA("Weld") or part:IsA("ManualWeld") then
                    -- Prevent joints from being disabled/broken
                    if part.Enabled == false then
                        part.Enabled = true
                    end
                end
            end
        end

        -- 3. State Lockdown (Hard Lock)
        if humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead) then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end
        
        -- 4. Force 'Physics' state to keep hitboxes active but alive
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end

        self.Status = "Active: VOID MODE v4"
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
            humanoid.MaxHealth = 100
            humanoid.Health = 100
            humanoid.RequiresNeck = true
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end)
    end
end

return GodMode
