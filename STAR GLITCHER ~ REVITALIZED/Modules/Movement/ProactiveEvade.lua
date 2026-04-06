local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PROACTIVE_STRIDE = 4.5
local PROACTIVE_INTERVAL = 0.42
local FORWARD_BLEND = 1.2

local ProactiveEvade = {}
ProactiveEvade.__index = ProactiveEvade

function ProactiveEvade.new(options, localCharacter)
    local self = setmetatable({}, ProactiveEvade)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    self._lastEvadeAt = 0
    self._lastDirection = 1
    return self
end

function ProactiveEvade:_isRespawning()
    return self.LocalCharacter
        and self.LocalCharacter.IsRespawning
        and self.LocalCharacter:IsRespawning()
end

function ProactiveEvade:_getPlanarBasis(root)
    local look = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector or root.CFrame.LookVector
    look = Vector3.new(look.X, 0, look.Z)
    if look.Magnitude <= 0.001 then
        look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    end

    if look.Magnitude <= 0.001 then
        look = Vector3.zAxis
    end

    look = look.Unit
    local right = Vector3.new(look.Z, 0, -look.X)
    if right.Magnitude <= 0.001 then
        right = Vector3.xAxis
    end

    return look, right.Unit
end

function ProactiveEvade:_pickOffset(character, root)
    local forward, right = self:_getPlanarBasis(root)
    local stride = tonumber(self.Options.ProactiveEvadeStride) or PROACTIVE_STRIDE
    local forwardBlend = math.clamp(stride * 0.28, 0.75, FORWARD_BLEND)

    local offsets = {
        (right * stride) + (forward * forwardBlend),
        (-right * stride) + (forward * forwardBlend),
    }

    if self._lastDirection < 0 then
        offsets[1], offsets[2] = offsets[2], offsets[1]
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.IgnoreWater = true

    for index, offset in ipairs(offsets) do
        local result = Workspace:Raycast(root.Position, offset, params)
        if not result then
            self._lastDirection = (index == 1) and 1 or -1
            return offset
        end
    end

    self._lastDirection = -self._lastDirection
    return offsets[1]
end

function ProactiveEvade:_step()
    if not self.Options.ProactiveEvadeEnabled then
        if self.Status ~= "Disabled" then
            self.Status = "Disabled"
        end
        return
    end

    if self:_isRespawning() then
        self.Status = "Respawn Grace"
        return
    end

    local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    local root = self.LocalCharacter and self.LocalCharacter:GetRootPart()

    if not character or not humanoid or not root then
        self.Status = "Char Missing"
        return
    end

    if humanoid.Health <= 0 then
        self.Status = "Dead"
        return
    end

    local now = os.clock()
    local interval = tonumber(self.Options.ProactiveEvadeInterval) or PROACTIVE_INTERVAL
    if (now - self._lastEvadeAt) < interval then
        self.Status = "Active: Weaving"
        return
    end

    local offset = self:_pickOffset(character, root)
    local targetCFrame = root.CFrame + offset

    character:PivotTo(targetCFrame)
    root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
    self._lastEvadeAt = now
    self.Status = "Active: Sidestepping"
end

function ProactiveEvade:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function()
        self:_step()
    end)
end

function ProactiveEvade:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return ProactiveEvade
