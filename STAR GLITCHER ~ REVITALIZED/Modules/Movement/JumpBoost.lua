local RunService = game:GetService("RunService")

local JumpBoost = {}
JumpBoost.__index = JumpBoost

local DEFAULT_JUMP_POWER = 50

function JumpBoost.new(options, localCharacter)
    local self = setmetatable({}, JumpBoost)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self.TrackedHumanoid = nil
    self.BaseJumpPower = DEFAULT_JUMP_POWER
    self._connection = nil
    self._applied = false
    return self
end

function JumpBoost:_captureBaseJump(humanoid)
    if humanoid then
        self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
    end
end

function JumpBoost:_restore()
    local humanoid = self.TrackedHumanoid
    if humanoid and humanoid.Parent and self._applied then
        if math.abs(humanoid.JumpPower - self.BaseJumpPower) > 0.1 then
            humanoid.JumpPower = self.BaseJumpPower
        end
    end
    self._applied = false
end

function JumpBoost:Init()
    if self._connection then
        return
    end

    self._connection = RunService.Heartbeat:Connect(function()
        local humanoid = self.LocalCharacter:GetHumanoid()
        if humanoid ~= self.TrackedHumanoid then
            self.TrackedHumanoid = humanoid
            self:_captureBaseJump(humanoid)
            self._applied = false
        end

        if not humanoid then
            self.Status = "Waiting for humanoid"
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            self.Status = "Respawn grace"
            return
        end

        if not self.Options.JumpBoostEnabled then
            if not self._applied then
                self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
                self.Status = "Idle"
                return
            end

            self:_restore()
            self.Status = "Idle"
            return
        end

        local desired = math.clamp(tonumber(self.Options.JumpBoostPower) or DEFAULT_JUMP_POWER, 1, 300)
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        if math.abs(humanoid.JumpPower - desired) > 0.1 then
            humanoid.JumpPower = desired
        end
        self._applied = true
        self.Status = string.format("Active: %.0f", desired)
    end)
end

function JumpBoost:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self:_restore()
end

return JumpBoost
