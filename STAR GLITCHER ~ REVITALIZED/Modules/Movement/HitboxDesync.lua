--[[
    HitboxDesync.lua - Zenith v3: The Nexus Proxy
    ============================================
    Architecture:
      * Joint Decoupling: Removing connection between Hitbox and Visuals.
      * Mirror Box: Local platform underground for Hitbox grounding.
      * Nexus Sync: High-fidelity visual persistence on the map.
    
    Fixes:
      * Clone Error: Uses real body parts (no cloning needed).
      * Falling State: Hitbox is grounded on a platform.
      * Stuck bug: Direct input mapping.
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
    self.Connections = {}
    self.NexusPos = Vector3.zero
    self.NexusRot = 0
    self.RootJoint = nil
    self.JointParent = nil
    self.MirrorBox = nil
    self.SafePos = Vector3.new(-1000, -250, -1000)
    return self
end

function HitboxDesync:_findRootJoint(char)
    -- Unified lookup for R6 and R15 root joints
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("Motor6D") and (part.Name == "Root" or part.Name == "RootJoint" or part.Part0 and part.Part0.Name == "HumanoidRootPart") then
            return part
        end
    end
    return nil
end

function HitboxDesync:_createMirrorBox()
    if self.MirrorBox then self.MirrorBox:Destroy() end
    local box = Instance.new("Part")
    box.Name = "Zenith_MirrorBox"
    box.Size = Vector3.new(10, 1, 10)
    box.CFrame = CFrame.new(self.SafePos)
    box.Transparency = 1
    box.Anchored = true
    box.CanCollide = true
    box.Parent = Workspace
    self.MirrorBox = box
end

function HitboxDesync:Init()
    local heartbeat = RunService.Heartbeat:Connect(function()
        if not self.Options.ZenithDesyncEnabled then
            if self.IsActive then self:Stop() end
            self.Status = "Disabled"
            return
        end

        local character, humanoid, root = self.LocalCharacter:GetState()
        if not root or not humanoid then self.Status = "Body Missing" return end

        if not self.IsActive then self:Start(character, root, humanoid) end

        -- LOCK HITBOX AT MIRROR BOX (Grounded)
        root.CFrame = CFrame.new(self.SafePos + Vector3.new(0, 3, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        
        -- SILENT DAMAGE FLICKER
        if self.Options.SilentDamageEnabled and _G.CurrentZTarget then
            local target = _G.CurrentZTarget
            local oldCF = root.CFrame
            root.CFrame = target.CFrame * CFrame.new(0, 0, 1.5)
            RunService.Heartbeat:Wait()
            root.CFrame = oldCF
        end
        
        self.Status = "ZENITH v3: NEXUS ACTIVE"
    end)
    
    local renderConn = RunService.RenderStepped:Connect(function(dt)
        if not self.IsActive then return end
        local character, hum, root = self.LocalCharacter:GetState()
        if not character or not hum then return end
        
        local cam = Workspace.CurrentCamera
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
            self.NexusPos = self.NexusPos + (moveVec * speed * dt)
            self.NexusRot = math.atan2(moveVec.X, moveVec.Z)
            
            -- Mirror input back to real humanoid for animation state
            hum:Move(Vector3.new(0, 0, -1), true)
        else
            hum:Move(Vector3.zero)
        end
        
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then hum.Jump = true end

        -- POSITION VISUAL BODY PARTS (Direct Nexus Link)
        -- Torso is usually the parent of most joints
        local torso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
        if torso then
            -- Manual CFrame without HRP constraint
            local nextCF = CFrame.new(self.NexusPos) * CFrame.Angles(0, self.NexusRot, 0)
            
            -- We must move all parts relative to the torso to maintain rig integrity
            -- or just MoveTo (which might fight physics)
            character:SetPrimaryPartCFrame(nextCF)
            -- Wait, character's PrimaryPart is usually the HRP. We moved HRP to SafeRoom.
            -- So we must CFrame the TORSO.
            torso.CFrame = nextCF
        end
    end)
    
    table.insert(self.Connections, heartbeat)
    table.insert(self.Connections, renderConn)
end

function HitboxDesync:Start(character, root, hum)
    self.IsActive = true
    self.NexusPos = root.Position
    self.NexusRot = 0
    
    -- 1. Partition Joint
    local joint = self:_findRootJoint(character)
    if joint then
        self.RootJoint = joint
        self.JointParent = joint.Parent
        joint.Parent = nil
    end
    
    -- 2. Create Mirror Box for Grounding
    self:_createMirrorBox()
    
    -- 3. Lock Hitbox to Mirror Box
    root.CFrame = CFrame.new(self.SafePos + Vector3.new(0, 3, 0))
    root.Transparency = 1
    
    -- 4. Redirect Camera to Visuals (Torso)
    local torso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
    if torso then
        pcall(function() Workspace.CurrentCamera.CameraSubject = torso end)
    end
end

function HitboxDesync:Stop()
    self.IsActive = false
    
    -- 1. Restore Joint
    if self.RootJoint and self.JointParent then
        self.RootJoint.Parent = self.JointParent
    end
    
    -- 2. Clean Mirror Box
    if self.MirrorBox then self.MirrorBox:Destroy() self.MirrorBox = nil end
    
    -- 3. Restore Body
    local character, hum, root = self.LocalCharacter:GetState()
    if root then root.CFrame = CFrame.new(self.NexusPos) end
end

function HitboxDesync:Destroy()
    self:Stop()
    for _, conn in ipairs(self.Connections) do conn:Disconnect() end
end

return HitboxDesync
