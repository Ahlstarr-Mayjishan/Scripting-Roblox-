local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local SAFE_POS = Vector3.new(-1000, -250, -1000)
local SAFE_CFRAME = CFrame.new(SAFE_POS + Vector3.new(0, 3, 0))
local FLICKER_OFFSET = CFrame.new(0, 0, 1.5)
local FLICKER_DURATION = 0.06
local DEFAULT_SPEED = 16

local HitboxDesync = {}
HitboxDesync.__index = HitboxDesync

function HitboxDesync.new(options, localCharacter)
    local self = setmetatable({}, HitboxDesync)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self.IsActive = false
    self.Connections = {}
    self.MirrorBox = nil
    self.ActiveCharacter = nil
    self.ActiveHumanoid = nil
    self.ActiveRoot = nil
    self.VisualRoot = nil
    self.RootJoint = nil
    self.JointParent = nil
    self.VisualParts = {}
    self.VisualOffsets = {}
    self.NexusPos = Vector3.zero
    self.NexusRot = 0
    self.FlickerUntil = 0
    self.OriginalRootTransparency = 0
    self.OriginalAutoRotate = true
    self.OriginalCameraSubject = nil
    return self
end

function HitboxDesync:_setStatus(status)
    self.Status = status
end

function HitboxDesync:_getCharacterState()
    if not self.LocalCharacter or not self.LocalCharacter.GetState then
        return nil, nil, nil
    end
    return self.LocalCharacter:GetState()
end

function HitboxDesync:_isRespawning()
    return self.LocalCharacter
        and self.LocalCharacter.IsRespawning
        and self.LocalCharacter:IsRespawning()
end

function HitboxDesync:_isValidDamageTarget(target)
    return typeof(target) == "Instance"
        and target:IsA("BasePart")
        and target.Parent ~= nil
end

function HitboxDesync:_findRootJoint(character)
    for _, joint in ipairs(character:GetDescendants()) do
        if joint:IsA("Motor6D")
            and (joint.Name == "RootJoint" or joint.Name == "Root")
            and joint.Part0
            and joint.Part0.Name == "HumanoidRootPart"
            and joint.Part1
            and joint.Part1.Name == "Torso"
        then
            return joint
        end
    end
    return nil
end

function HitboxDesync:_validateR6Rig(character, humanoid, root)
    if not character or not humanoid or not root then
        return false, "Body Missing"
    end

    if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        return false, "R6 Only"
    end

    local torso = character:FindFirstChild("Torso")
    if not torso or not torso:IsA("BasePart") then
        return false, "R6 Torso Missing"
    end

    local rootJoint = self:_findRootJoint(character)
    if not rootJoint then
        return false, "RootJoint Missing"
    end

    return true, torso, rootJoint
end

function HitboxDesync:_clearVisualRig()
    table.clear(self.VisualParts)
    table.clear(self.VisualOffsets)
end

function HitboxDesync:_captureVisualRig(character, visualRoot, root)
    self:_clearVisualRig()

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
    box.CFrame = CFrame.new(SAFE_POS)
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

function HitboxDesync:_clearSession()
    self.ActiveCharacter = nil
    self.ActiveHumanoid = nil
    self.ActiveRoot = nil
    self.VisualRoot = nil
    self.RootJoint = nil
    self.JointParent = nil
    self.FlickerUntil = 0
    self.OriginalCameraSubject = nil
    self:_clearVisualRig()
end

function HitboxDesync:_computeMoveVector(camera)
    local moveVec = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveVec += camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveVec -= camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveVec -= camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveVec += camera.CFrame.RightVector
    end

    moveVec = Vector3.new(moveVec.X, 0, moveVec.Z)
    if moveVec.Magnitude <= 0 then
        return Vector3.zero
    end

    return moveVec.Unit
end

function HitboxDesync:_getVisualSpeed()
    if self.Options.CustomMoveSpeedEnabled then
        return self.Options.CustomMoveSpeed or DEFAULT_SPEED
    end
    return DEFAULT_SPEED
end

function HitboxDesync:_updateNexusMotion(dt, humanoid, camera)
    local moveVec = self:_computeMoveVector(camera)
    if moveVec.Magnitude > 0 then
        self.NexusPos += (moveVec * self:_getVisualSpeed() * dt)
        self.NexusRot = math.atan2(moveVec.X, moveVec.Z)
        humanoid:Move(moveVec, true)
    else
        humanoid:Move(Vector3.zero, true)
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        humanoid.Jump = true
    end
end

function HitboxDesync:_applyVisualPose()
    if not self.VisualRoot or not self.VisualRoot.Parent then
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

function HitboxDesync:_beginSilentDamageWindow()
    if self.Options.SilentDamageEnabled and self:_isValidDamageTarget(_G.CurrentZTarget) then
        self.FlickerUntil = os.clock() + FLICKER_DURATION
    end
end

function HitboxDesync:_placeHitboxRoot(root)
    local target = _G.CurrentZTarget
    if self.Options.SilentDamageEnabled
        and self.FlickerUntil > os.clock()
        and self:_isValidDamageTarget(target)
    then
        root.CFrame = target.CFrame * FLICKER_OFFSET
        root.AssemblyLinearVelocity = Vector3.zero
        return
    end

    root.CFrame = SAFE_CFRAME
    root.AssemblyLinearVelocity = Vector3.zero
end

function HitboxDesync:_freezeHitboxRoot(root)
    root.Anchored = true
    root.Transparency = 1
    self:_placeHitboxRoot(root)
end

function HitboxDesync:_restoreRoot(root)
    if not root then
        return
    end

    root.Anchored = false
    root.Transparency = self.OriginalRootTransparency or 0
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.new(self.NexusPos) * CFrame.Angles(0, self.NexusRot, 0)
end

function HitboxDesync:_restoreCamera(restoreHumanoid)
    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CameraSubject = self.OriginalCameraSubject or restoreHumanoid or camera.CameraSubject
        end
    end)
end

function HitboxDesync:_stopCurrentSession(status)
    if not self.IsActive and not self.ActiveRoot and not self.RootJoint and not self.MirrorBox then
        self:_clearSession()
        self:_setStatus(status or "Disabled")
        return
    end

    if self.RootJoint and self.JointParent then
        self.RootJoint.Parent = self.JointParent
    end

    local _, humanoid, root = self:_getCharacterState()
    local restoreHumanoid = humanoid or self.ActiveHumanoid
    local restoreRoot = root or self.ActiveRoot

    if restoreHumanoid then
        restoreHumanoid.AutoRotate = self.OriginalAutoRotate
    end

    self:_restoreRoot(restoreRoot)
    self:_restoreCamera(restoreHumanoid)
    self:_destroyMirrorBox()
    self:_clearSession()
    self.IsActive = false
    self:_setStatus(status or "Disabled")
end

function HitboxDesync:_startSession(character, humanoid, root)
    if self.IsActive then
        self:_stopCurrentSession("Restarting")
    end

    local ok, visualRoot, rootJoint = self:_validateR6Rig(character, humanoid, root)
    if not ok then
        self:_setStatus(visualRoot)
        return false
    end

    self.ActiveCharacter = character
    self.ActiveHumanoid = humanoid
    self.ActiveRoot = root
    self.VisualRoot = visualRoot
    self.RootJoint = rootJoint
    self.JointParent = rootJoint.Parent
    self.NexusPos = visualRoot.Position
    self.NexusRot = root.Orientation.Y * math.pi / 180
    self.OriginalRootTransparency = root.Transparency
    self.OriginalAutoRotate = humanoid.AutoRotate
    self.OriginalCameraSubject = Workspace.CurrentCamera and Workspace.CurrentCamera.CameraSubject or nil

    self:_captureVisualRig(character, visualRoot, root)
    self:_createMirrorBox()

    rootJoint.Parent = nil
    humanoid.AutoRotate = false
    self:_freezeHitboxRoot(root)

    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CameraSubject = visualRoot
        end
    end)

    self.IsActive = true
    self:_setStatus("Zenith Active")
    return true
end

function HitboxDesync:_needsRestart(character, root)
    return not self.IsActive
        or character ~= self.ActiveCharacter
        or root ~= self.ActiveRoot
        or not self.VisualRoot
        or not self.VisualRoot.Parent
        or not self.RootJoint
        or not self.JointParent
end

function HitboxDesync:_onHeartbeat()
    if not self.Options.ZenithDesyncEnabled then
        if self.IsActive then
            self:_stopCurrentSession("Disabled")
        else
            self:_setStatus("Disabled")
        end
        return
    end

    local character, humanoid, root = self:_getCharacterState()
    if not character or not humanoid or not root then
        if self.IsActive then
            self:_stopCurrentSession("Body Missing")
        else
            self:_setStatus("Body Missing")
        end
        return
    end

    if self:_isRespawning() then
        if self.IsActive then
            self:_stopCurrentSession("Respawn Grace")
        else
            self:_setStatus("Respawn Grace")
        end
        return
    end

    if self:_needsRestart(character, root) and not self:_startSession(character, humanoid, root) then
        return
    end

    self:_beginSilentDamageWindow()
    self:_freezeHitboxRoot(root)
end

function HitboxDesync:_onRenderStepped(dt)
    if not self.IsActive then
        return
    end

    local humanoid = self.ActiveHumanoid
    local camera = Workspace.CurrentCamera
    if not humanoid or not camera then
        self:_setStatus(camera and "Humanoid Missing" or "Camera Missing")
        return
    end

    self:_updateNexusMotion(dt, humanoid, camera)
    if self:_applyVisualPose() then
        self:_setStatus("Zenith Active")
    else
        self:_setStatus("Visual Sync Lost")
    end
end

function HitboxDesync:Init()
    table.insert(self.Connections, RunService.Heartbeat:Connect(function()
        self:_onHeartbeat()
    end))

    table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
        self:_onRenderStepped(dt)
    end))
end

function HitboxDesync:Start(character, root, humanoid)
    self:_startSession(character, humanoid, root)
end

function HitboxDesync:Stop()
    self:_stopCurrentSession("Disabled")
end

function HitboxDesync:Destroy()
    self:Stop()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    table.clear(self.Connections)
end

return HitboxDesync
