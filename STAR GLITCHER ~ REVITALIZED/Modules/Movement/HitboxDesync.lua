--[[
    HitboxDesync.lua - Zenith Desync (Soul Mode)
    ============================================
    Architecture:
      * Ghost Character: Visual representation controlled by the player.
      * Physical Hitbox: Original RootPart anchored in a "Soul Room" (-999, -400, -999).
      * Silent Damage Sync: Flickers the physical hitbox to targets for damage registration.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local HitboxDesync = {}
HitboxDesync.__index = HitboxDesync

function HitboxDesync.new(options, localCharacter)
    local self = setmetatable({}, HitboxDesync)
    self.Options = options
    self.LocalCharacter = localCharacter localCharacter
    self.IsActive = false
    self.Status = "Idle"
    self.Ghost = nil
    self.Connection = nil
    self.DamageConnection = nil
    
    self.SoulRoomPos = Vector3.new(0, -850, 0) -- Hidden under the world
    self.LastRealCFrame = nil
    
    return self
end

function HitboxDesync:_createGhost(character)
    if self.Ghost then self.Ghost:Destroy() end
    
    local ghost = Instance.new("Folder")
    ghost.Name = "Zenith_Ghost"
    ghost.Parent = Workspace
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local clone = part:Clone()
            clone:BreakJoints()
            clone.CanCollide = false
            clone.CanTouch = false
            clone.CanQuery = false
            clone.Transparency = 0.5 -- Ghost effect
            clone.Parent = ghost
            
            -- Sync position
            RunService.RenderStepped:Connect(function()
                if ghost and ghost.Parent and part and part.Parent then
                    clone.CFrame = part.CFrame
                end
            end)
        end
    end
    
    self.Ghost = ghost
    return ghost
end

function HitboxDesync:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.ZenithDesyncEnabled then
            if self.IsActive then self:Stop() end
            self.Status = "Disabled"
            return
        end

        local character, humanoid, root = self.LocalCharacter:GetState()
        if not root or not humanoid then
            self.Status = "Hum Missing"
            return
        end

        if not self.IsActive then
            self:Start(character, root)
        end

        -- LOCK HITBOX TO SOUL ROOM
        root.CFrame = CFrame.new(self.SoulRoomPos)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        
        -- Health Locking (Backup)
        humanoid.MaxHealth = 9e18
        humanoid.Health = 9e18
        
        self.Status = "Active: SOUL SEPARATED"
    end)
    
    -- SILENT DAMAGE SYNC
    self.DamageConnection = RunService.Heartbeat:Connect(function()
        if not self.Options.ZenithDesyncEnabled or not self.Options.SilentDamageEnabled then
            return
        end
        
        local root = self.LocalCharacter:GetRootPart()
        if not root then return end
        
        -- Find nearby target (Ghost position is where the player 'is')
        -- Logic: We use the camera focus or ghost position
        local target = self:_getClosestEnemy()
        if target then
            -- FLICKER HITBOX TO TARGET
            local oldCF = root.CFrame
            root.CFrame = target.CFrame * CFrame.new(0, 0, 2)
            task.wait() -- 1 tick flicker
            root.CFrame = oldCF
        end
    end)
end

function HitboxDesync:_getClosestEnemy()
    -- This is a placeholder; in Bundle.lua we will use Tracker:GetTargets()
    return nil 
end

function HitboxDesync:Start(character, root)
    self.IsActive = true
    self.LastRealCFrame = root.CFrame
    
    -- Engine Protection
    pcall(function()
        Workspace.FallenPartsDestroyHeight = -99999
    end)
    
    -- Disable collisions on real body to prevent 'flinging' the ghost
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanTouch = false
            part.CanQuery = false
        end
    end
end

function HitboxDesync:Stop()
    self.IsActive = false
    if self.Ghost then
        self.Ghost:Destroy()
        self.Ghost = nil
    end
    
    local root = self.LocalCharacter:GetRootPart()
    if root and self.LastRealCFrame then
        root.CFrame = self.LastRealCFrame
    end
    
    pcall(function()
        Workspace.FallenPartsDestroyHeight = -500
    end)
end

function HitboxDesync:Destroy()
    self:Stop()
    if self.Connection then self.Connection:Disconnect() end
    if self.DamageConnection then self.DamageConnection:Disconnect() end
end

return HitboxDesync
