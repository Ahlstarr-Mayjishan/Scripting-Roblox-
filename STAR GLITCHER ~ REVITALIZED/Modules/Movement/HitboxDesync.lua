--[[
    HitboxDesync.lua - True Zenith Desync (Soul Mode)
    ================================================
    Separates the visual character (Soul) from the physical hitbox (Body).
    Features:
      * Ghost Mirroring: Visual representation remains on the map.
      * Soul Partition: Physical RootPart is tucked away at -850 studs.
      * Silent Flicker: Real body snaps to target for damage registration.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local HitboxDesync = {}
HitboxDesync.__index = HitboxDesync

function HitboxDesync.new(options, localCharacter)
    local self = setmetatable({}, HitboxDesync)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.IsActive = false
    self.Status = "Idle"
    self.Ghost = nil
    self.Connections = {}
    self.SoulRoomPos = Vector3.new(0, -850, 0)
    self.LastRealCFrame = nil
    return self
end

function HitboxDesync:_createGhost(realChar)
    if self.Ghost then self.Ghost:Destroy() end
    
    -- Clone to create visual soul
    realChar.Archivable = true
    local ghost = realChar:Clone()
    realChar.Archivable = false
    
    ghost.Name = "Zenith_Soul"
    ghost.Parent = Workspace
    
    -- Setup Ghost Visuals (Glassmorphism effect)
    for _, part in ipairs(ghost:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Transparency = 0.4
            if part.Name == "HumanoidRootPart" then
                part.Transparency = 1
            end
        elseif part:IsA("Script") or part:IsA("LocalScript") then
            part:Destroy()
        end
    end
    
    self.Ghost = ghost
    return ghost
end

function HitboxDesync:Init()
    local heartbeat = RunService.Heartbeat:Connect(function()
        if not self.Options.ZenithDesyncEnabled then
            if self.IsActive then self:Stop() end
            self.Status = "Disabled"
            return
        end

        local character, realHum, realRoot = self.LocalCharacter:GetState()
        if not realRoot or not realHum then
            self.Status = "Hum Missing"
            return
        end

        if not self.IsActive then
            self:Start(character, realRoot, realHum)
        end

        -- 1. LOCK REAL BODY AT SOUL ROOM
        realRoot.CFrame = CFrame.new(self.SoulRoomPos)
        realRoot.AssemblyLinearVelocity = Vector3.zero
        
        -- 2. CONTROL THE SOUL (GHOST)
        if self.Ghost and self.Ghost:FindFirstChild("Humanoid") then
            local ghostHum = self.Ghost.Humanoid
            local ghostRoot = self.Ghost.PrimaryPart or self.Ghost:FindFirstChild("HumanoidRootPart")
            
            -- Mirror Real Character's Intended Movement
            -- Since Real Body is anchored, we use MoveDirection or Inputs
            local moveVec = realHum.MoveDirection
            ghostHum:Move(moveVec, true)
            
            -- Sync Jump
            if realHum.Jump then
                ghostHum.Jump = true
            end
            
            -- Update Status
            self.Status = "Active: SOUL MODE"
        end
        
        -- 3. SILENT DAMAGE FLICKER
        if self.Options.SilentDamageEnabled and _G.CurrentZTarget then
            local target = _G.CurrentZTarget
            local oldCF = realRoot.CFrame
            realRoot.CFrame = target.CFrame * CFrame.new(0, 0, 1.5)
            RunService.Heartbeat:Wait()
            realRoot.CFrame = oldCF
        end
    end)
    
    table.insert(self.Connections, heartbeat)
end

function HitboxDesync:Start(character, root, hum)
    self.IsActive = true
    self.LastRealCFrame = root.CFrame
    
    -- Create the Soul
    local ghost = self:_createGhost(character)
    ghost:SetPrimaryPartCFrame(self.LastRealCFrame)
    
    -- Redirect Camera to the Soul
    pcall(function()
        Workspace.CurrentCamera.CameraSubject = ghost:FindFirstChildOfClass("Humanoid")
    end)
    
    -- Hide Real Body (Local Only)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
            part.CanTouch = false
            part.CanQuery = false
        end
    end
    
    -- Engine Protection
    pcall(function() Workspace.FallenPartsDestroyHeight = -99999 end)
end

function HitboxDesync:Stop()
    self.IsActive = false
    
    if self.Ghost then
        self.Ghost:Destroy()
        self.Ghost = nil
    end
    
    local character, hum, root = self.LocalCharacter:GetState()
    if root and self.LastRealCFrame then
        root.CFrame = self.LastRealCFrame
    end
    
    -- Restore Visuals
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0 -- Typical assumption
                part.CanTouch = true
                part.CanQuery = true
            end
        end
    end
    
    -- Restore Camera
    pcall(function()
        Workspace.CurrentCamera.CameraSubject = hum
    end)
    
    pcall(function() Workspace.FallenPartsDestroyHeight = -500 end)
end

function HitboxDesync:Destroy()
    self:Stop()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
end

return HitboxDesync
