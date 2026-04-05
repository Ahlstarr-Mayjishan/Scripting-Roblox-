--[[
    HitboxDesync.lua - Zenith v2: Soul Stability Fixes
    ================================================
    High-fidelity movement mirroring and animation syncing.
    Fixes:
      * No-Movement bug (Direct WASD input)
      * Statue bug (Animation Mirroring)
      * Void Kill bug (Safe Room at 50,000 studs)
      * Jitter bug (RenderStepped lerping)
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
    self.SoulRoomPos = Vector3.new(0, 50000, 0)
    self.GhostPos = Vector3.zero
    self.GhostRot = 0
    return self
end

function HitboxDesync:_createGhost(realChar)
    if self.Ghost then self.Ghost:Destroy() end
    realChar.Archivable = true
    local ghost = realChar:Clone()
    realChar.Archivable = false
    
    ghost.Name = "Zenith_Soul_v2"
    ghost.Parent = Workspace
    
    -- Setup Ghost Visuals (Glassmorphism effect)
    for _, part in ipairs(ghost:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
            part.Transparency = 0.4
            if part.Name == "HumanoidRootPart" then part.Transparency = 1 end
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
        if not realRoot or not realHum then self.Status = "Body Missing" return end

        if not self.IsActive then self:Start(character, realRoot, realHum) end

        -- LOCK REAL BODY AT HIGH HEAVEN (SAFE ROOM)
        realRoot.CFrame = CFrame.new(self.SoulRoomPos)
        realRoot.AssemblyLinearVelocity = Vector3.zero
        realHum.PlatformStand = true -- Disable physics engine fighting

        -- SILENT DAMAGE FLICKER
        if self.Options.SilentDamageEnabled and _G.CurrentZTarget then
            local target = _G.CurrentZTarget
            local oldCF = realRoot.CFrame
            realRoot.CFrame = target.CFrame * CFrame.new(0, 0, 1.5)
            RunService.Heartbeat:Wait()
            realRoot.CFrame = oldCF
        end
        
        self.Status = "ZENITH v2 ACTIVE"
    end)
    
    -- RENDERSTEPPED FOR 0-LATENCY GHOST MOVEMENT
    local renderConn = RunService.RenderStepped:Connect(function(dt)
        if not self.IsActive or not self.Ghost then return end
        
        local cam = Workspace.CurrentCamera
        local ghostHum = self.Ghost:FindFirstChildOfClass("Humanoid")
        local moveVec = Vector3.zero
        
        -- DIRECT INPUT PROXY
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + cam.CFrame.RightVector end
        
        moveVec = Vector3.new(moveVec.X, 0, moveVec.Z)
        if moveVec.Magnitude > 0 then
            moveVec = moveVec.Unit
            local speed = self.Options.CustomMoveSpeed or 16
            self.GhostPos = self.GhostPos + (moveVec * speed * dt)
            
            -- Smooth Rotation
            local targetRot = math.atan2(moveVec.X, moveVec.Z)
            self.GhostRot = targetRot
        end
        
        -- Apply Transform
        self.Ghost:SetPrimaryPartCFrame(CFrame.new(self.GhostPos) * CFrame.Angles(0, self.GhostRot, 0))
        
        -- ANIMATION SYNC
        if ghostHum then
            if moveVec.Magnitude > 0 then
                ghostHum:Move(Vector3.new(0, 0, -1), true) -- Trigger internal walk cycle
            else
                ghostHum:Move(Vector3.zero)
            end
            
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                ghostHum.Jump = true
            end
        end
    end)
    
    table.insert(self.Connections, heartbeat)
    table.insert(self.Connections, renderConn)
end

function HitboxDesync:Start(character, root, hum)
    self.IsActive = true
    self.GhostPos = root.Position
    self.GhostRot = 0
    
    -- Create the Soul
    local ghost = self:_createGhost(character)
    
    -- Redirect Camera
    pcall(function() Workspace.CurrentCamera.CameraSubject = ghost:FindFirstChildOfClass("Humanoid") end)
    
    -- Hide Real Body
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then part.Transparency = 1 end
    end
end

function HitboxDesync:Stop()
    self.IsActive = false
    if self.Ghost then self.Ghost:Destroy() self.Ghost = nil end
    
    local character, hum, root = self.LocalCharacter:GetState()
    if root then root.CFrame = CFrame.new(self.GhostPos) end
    if hum then hum.PlatformStand = false end
    
    -- Restore Visuals
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0 end
        end
    end
    
    -- Restore Camera
    pcall(function() Workspace.CurrentCamera.CameraSubject = hum end)
end

function HitboxDesync:Destroy()
    self:Stop()
    for _, conn in ipairs(self.Connections) do conn:Disconnect() end
end

return HitboxDesync
