local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
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
    self.ActiveCharacter = nil
    self.ActiveHumanoid = nil
    self.ActiveRoot = nil
    self.VisualRoot = nil
    self.VisualParts = {}
    self.VisualOffsets = {}
    self.NexusPos = Vector3.zero
    self.NexusRot = 0
    self.RootJoint = nil
    self.JointParent = nil
    self.MirrorBox = nil
    self.SafePos = Vector3.new(-1000, -250, -1000)
    self.SafeCFrame = CFrame.new(self.SafePos + Vector3.new(0, 3, 0))
    self.OriginalRootTransparency = 0
    self.OriginalAutoRotate = true
    self.OriginalCameraSubject = nil
    self.FlickerUntil = 0
    self.FlickerOffset = CFrame.new(0, 0, 1.5)
    return self
end

function HitboxDesync:_findRootJoint(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("Motor6D")
            and (part.Name == "RootJoint" or part.Name == "Root")
            and part.Part0
            and part.Part0.Name == "HumanoidRootPart"
            and part.Part1
            and part.Part1.Name == "Torso"
        then
            return part
        end
    end
    return nil
end

function HitboxDesync:_getVisualRoot(character)
    return character:FindFirstChild("Torso")
end

function HitboxDesync:_captureVisualRig(character, visualRoot, root)
    table.clear(self.VisualParts)
    table.clear(self.VisualOffsets)

    if not visualRoot then
        return
    end

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") and obj ~= root then
            self.VisualParts[#self.VisualParts + 1] = obj
            self.VisualOffsets[obj] = visualRoot.CFrame:ToObjectSpace(obj.CFrame)
        end
    end
end

function HitboxDesync:_createMirrorBox()
    self:_destroyMirrorBox()

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

function HitboxDesync:_destroyMirrorBox()
    if self.MirrorBox then
        self.MirrorBox:Destroy()
        self.MirrorBox = nil
    end
end

function HitboxDesync:_clearRigState()
    self.ActiveCharacter = nil
    self.ActiveHumanoid = nil
    self.ActiveRoot = nil
    self.VisualRoot = nil
    table.clear(self.VisualParts)
    table.clear(self.VisualOffsets)
    self.RootJoint = nil
    self.JointParent = nil
    self.OriginalCameraSubject = nil
    self.FlickerUntil = 0
end

function HitboxDesync:_placeHitboxRoot(root)
    local now = os.clock()
    if self.Options.SilentDamageEnabled and self.FlickerUntil > now and _G.CurrentZTarget then
        local target = _G.CurrentZTarget
        if typeof(target) == "Instance" and target:IsA("BasePart") and target.Parent then
            root.CFrame = target.CFrame * self.FlickerOffset
            root.AssemblyLinearVelocity = Vector3.zero
            return
        end
    end

    root.CFrame = self.SafeCFrame
    root.AssemblyLinearVelocity = Vector3.zero
end

function HitboxDesync:_applyVisualPose()
    local visualRoot = self.VisualRoot
    if not visualRoot or not visualRoot.Parent then
        return false
    end

    local pose = CFrame.new(self.NexusPos) * CFrame.Angles(0, self.NexusRot, 0)
    for _, part in ipairs(self.VisualParts) do
        if part and part.Parent then
            local offset = self.VisualOffsets[part]
            if offset then
                part.CFrame = pose * offset
            end
        end
    end
    return true
end

function HitboxDesync:_tickMovement(dt)
    local character = self.ActiveCharacter
    local hum = self.ActiveHumanoid
    if not character or not hum or not self.VisualRoot or not self.VisualRoot.Parent then
        self.Status = "Visual Root Missing"
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then
        self.Status = "Camera Missing"
        return
    end

    local moveVec = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveVec += cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveVec -= cam.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveVec -= cam.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveVec += cam.CFrame.RightVector
    end

    moveVec = Vector3.new(moveVec.X, 0, moveVec.Z)
    if moveVec.Magnitude > 0 then
        moveVec = moveVec.Unit
        local speed = self.Options.CustomMoveSpeedEnabled and (self.Options.CustomMoveSpeed or 16) or 16
        self.NexusPos += (moveVec * speed * dt)
        self.NexusRot = math.atan2(moveVec.X, moveVec.Z)
        hum:Move(moveVec, true)
    else
        hum:Move(Vector3.zero, true)
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        hum.Jump = true
    end

    if self:_applyVisualPose() then
        self.Status = "Zenith Active"
    else
        self.Status = "Visual Sync Lost"
    end
end

function HitboxDesync:Init()
    local heartbeat = RunService.Heartbeat:Connect(function()
        if not self.Options.ZenithDesyncEnabled then
            if self.IsActive then
                self:Stop()
            end
            self.Status = "Disabled"
            return
        end

        local character, humanoid, root = self.LocalCharacter:GetState()
        if not character or not humanoid or not root then
            if self.IsActive then
                self:Stop()
            end
            self.Status = "Body Missing"
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if self.IsActive then
                self:Stop()
            end
            self.Status = "Respawn Grace"
            return
        end

        if not self.IsActive or character ~= self.ActiveCharacter or root ~= self.ActiveRoot then
            self:Start(character, root, humanoid)
        end

        if not self.IsActive then
            self.Status = "Start Failed"
            return
        end

        if self.Options.SilentDamageEnabled and _G.CurrentZTarget then
            self.FlickerUntil = os.clock() + 0.06
        end

        root.Anchored = true
        root.Transparency = 1
        self:_placeHitboxRoot(root)
    end)

    local renderConn = RunService.RenderStepped:Connect(function(dt)
        if not self.IsActive then
            return
        end
        self:_tickMovement(dt)
    end)

    table.insert(self.Connections, heartbeat)
    table.insert(self.Connections, renderConn)
end

function HitboxDesync:Start(character, root, hum)
    if self.IsActive then
        self:Stop()
    end

    local visualRoot = self:_getVisualRoot(character)
    local joint = self:_findRootJoint(character)
    if hum.RigType ~= Enum.HumanoidRigType.R6 then
        self.Status = "R6 Only"
        return
    end

    if not visualRoot then
        self.Status = "R6 Torso Missing"
        return
    end

    if not joint then
        self.Status = "RootJoint Missing"
        return
    end

    self.ActiveCharacter = character
    self.ActiveHumanoid = hum
    self.ActiveRoot = root
    self.VisualRoot = visualRoot
    self.NexusPos = visualRoot.Position
    self.NexusRot = root.Orientation.Y * math.pi / 180
    self.RootJoint = joint
    self.JointParent = joint.Parent
    self.OriginalRootTransparency = root.Transparency
    self.OriginalAutoRotate = hum.AutoRotate
    self.OriginalCameraSubject = Workspace.CurrentCamera and Workspace.CurrentCamera.CameraSubject or nil

    self:_captureVisualRig(character, visualRoot, root)
    self:_createMirrorBox()

    joint.Parent = nil
    root.Anchored = true
    root.Transparency = 1
    root.AssemblyLinearVelocity = Vector3.zero
    hum.AutoRotate = false

    self:_placeHitboxRoot(root)
    self.IsActive = true

    pcall(function()
        Workspace.CurrentCamera.CameraSubject = visualRoot
    end)
end

function HitboxDesync:Stop()
    if self.RootJoint and self.JointParent then
        self.RootJoint.Parent = self.JointParent
    end

    local character, hum, root = self.LocalCharacter:GetState()
    local restoreRoot = root or self.ActiveRoot
    local restoreHumanoid = hum or self.ActiveHumanoid

    if restoreRoot then
        restoreRoot.Anchored = false
        restoreRoot.Transparency = self.OriginalRootTransparency or 0
        restoreRoot.AssemblyLinearVelocity = Vector3.zero
        restoreRoot.CFrame = CFrame.new(self.NexusPos) * CFrame.Angles(0, self.NexusRot, 0)
    end

    if restoreHumanoid then
        restoreHumanoid.AutoRotate = self.OriginalAutoRotate
    end

    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CameraSubject = self.OriginalCameraSubject or restoreHumanoid or camera.CameraSubject
        end
    end)

    self:_destroyMirrorBox()
    self:_clearRigState()
    self.IsActive = false
    self.Status = "Disabled"
end

function HitboxDesync:Destroy()
    self:Stop()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    table.clear(self.Connections)
end

return HitboxDesync
