--[[
    GodMode.lua - Biological Preservation Module (v6 Ultimate Balance)
    Job: Locking health AND protecting against Void death.
    Logic: Uses Void Guard (height override) and Auto-Rescue (teleport).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GodMode = {}
GodMode.__index = GodMode

function GodMode.new(options, localCharacter)
    local self = setmetatable({}, GodMode)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    self._lastSafePosition = Vector3.new(0, 10, 0)
    return self
end

function GodMode:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.GodModeEnabled then
            self.Status = "Disabled"
            return
        end

        local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()
        
        if not humanoid then
            self.Status = "Hum Missing"
            return
        end

        -- 1. Void Guard (Engine Override)
        pcall(function()
            if Workspace.FallenPartsDestroyHeight ~= -99999 then
                Workspace.FallenPartsDestroyHeight = -99999
            end
        end)

        -- 2. Void Rescue (Auto-Teleport)
        if rootPart then
            local pos = rootPart.Position
            if pos.Y > -400 then
                -- Store safe position while on/above the map
                self._lastSafePosition = pos + Vector3.new(0, 5, 0)
            elseif pos.Y < -480 then
                -- TRIGGER RESCUE: Teleport back to safety before engine-death or infinite fall
                rootPart.Velocity = Vector3.zero
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.CFrame = CFrame.new(self._lastSafePosition)
                self.Status = "Active: VOID RESCUED"
                return
            end
        end

        -- 3. Ultimate Health Lock
        humanoid.MaxHealth = 9e18
        humanoid.Health = 9e18
        
        if humanoid.Health < 1 then
            humanoid.Health = 9e18
        end

        -- 4. physical Reinforcement (Joints)
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

        -- 5. State Lockdown
        if humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead) then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end
        
        if humanoid:GetState() == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end

        self.Status = "Active: BALANCED GOD v6"
    end)
end

function GodMode:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    pcall(function()
        Workspace.FallenPartsDestroyHeight = -500 -- Restore default
    end)

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
