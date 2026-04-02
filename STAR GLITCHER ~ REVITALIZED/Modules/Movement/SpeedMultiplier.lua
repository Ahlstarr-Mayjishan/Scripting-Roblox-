local RunService = game:GetService("RunService")

local SpeedMultiplier = {}
SpeedMultiplier.__index = SpeedMultiplier

function SpeedMultiplier.new(options, localCharacter)
    local self = setmetatable({}, SpeedMultiplier)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.TrackedHumanoid = nil
    self.Status = "Idle"
    self._lastBoostTime = 0
    self._lastWalkWriteTime = 0
    self._fallbackWarmupUntil = 0
    return self
end

function SpeedMultiplier:_captureBaseSpeed(humanoid)
    self.TrackedHumanoid = humanoid
    self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
end

function SpeedMultiplier:_learnLegitBaseSpeed(humanoid)
    local multiplier = math.max(self.Options.SpeedMultiplier or 1, 1)
    local now = os.clock()
    if (now - self._lastWalkWriteTime) < 0.2 then
        return
    end

    if not self.Options.SpeedMultiplierEnabled then
        self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
        return
    end

    local observedBase = humanoid.WalkSpeed / multiplier
    if observedBase > (self.BaseWalkSpeed + 0.75) then
        self.BaseWalkSpeed = observedBase
    end
end

function SpeedMultiplier:_applyVelocityFallback(humanoid, rootPart, desiredSpeed)
    if not rootPart or desiredSpeed <= 0 then
        return false
    end

    local now = os.clock()
    local moveDirection = humanoid.MoveDirection
    if moveDirection.Magnitude <= 0.05 then
        self._fallbackWarmupUntil = 0
        return false
    end

    local planarVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
    local currentSpeedAlongMove = planarVelocity:Dot(moveDirection)
    local perpendicularPlanarVelocity = planarVelocity - (moveDirection * currentSpeedAlongMove)
    local missingSpeed = desiredSpeed - currentSpeedAlongMove
    if missingSpeed <= 0.75 then
        self._fallbackWarmupUntil = 0
        return false
    end

    if self._fallbackWarmupUntil == 0 then
        self._fallbackWarmupUntil = now + 0.2
        return false
    end

    if now < self._fallbackWarmupUntil then
        return false
    end

    local targetAlongMove = math.min(desiredSpeed, math.max(currentSpeedAlongMove, 0) + math.max(missingSpeed * 0.45, 4))
    local targetPlanarVelocity = perpendicularPlanarVelocity + (moveDirection * targetAlongMove)
    local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
    rootPart.AssemblyLinearVelocity = Vector3.new(targetPlanarVelocity.X, verticalVelocity, targetPlanarVelocity.Z)
    self._lastBoostTime = now
    return true
end

function SpeedMultiplier:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            self.Status = "Hum Missing"
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                self:_captureBaseSpeed(hum)
            end
            self._fallbackWarmupUntil = 0
            self.Status = "Respawn Grace"
            return
        end

        if hum ~= self.TrackedHumanoid then
            self:_captureBaseSpeed(hum)
        elseif not self.Options.SpeedMultiplierEnabled then
            self.BaseWalkSpeed = math.max(hum.WalkSpeed, 16)
        end

        self:_learnLegitBaseSpeed(hum)

        if not self.Options.SpeedMultiplierEnabled or self.Options.CustomMoveSpeedEnabled then
            self._fallbackWarmupUntil = 0
            self.Status = self.Options.CustomMoveSpeedEnabled and "Blocked by Fixed Speed" or "Disabled"
            return
        end

        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()
        local desiredSpeed = self.BaseWalkSpeed * self.Options.SpeedMultiplier
        local boosted = false

        if math.abs(hum.WalkSpeed - desiredSpeed) > 0.1 then
            hum.WalkSpeed = desiredSpeed
            self._lastWalkWriteTime = os.clock()
        end

        -- Some games ignore WalkSpeed entirely and drive movement from custom controllers.
        -- When that happens, nudge the root part's horizontal velocity along MoveDirection.
        if self.Options.SpeedMultiplier > 1 then
            boosted = self:_applyVelocityFallback(hum, rootPart, desiredSpeed)
        end

        if boosted then
            self.Status = "Active: Velocity Fallback"
        elseif math.abs(hum.WalkSpeed - desiredSpeed) <= 0.1 then
            self.Status = "Active: WalkSpeed"
        else
            self.Status = "Contested"
        end
    end)
end

function SpeedMultiplier:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return SpeedMultiplier
