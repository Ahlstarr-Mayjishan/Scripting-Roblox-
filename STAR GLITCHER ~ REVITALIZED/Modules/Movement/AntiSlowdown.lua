local RunService = game:GetService("RunService")

local AntiSlowdown = {}
AntiSlowdown.__index = AntiSlowdown

function AntiSlowdown.new(options, localCharacter)
    local self = setmetatable({}, AntiSlowdown)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.BaseJumpPower = 50
    self.TrackedHumanoid = nil
    return self
end

function AntiSlowdown:CaptureBaseStats(humanoid)
    local hum = humanoid or (self.LocalCharacter and self.LocalCharacter:GetHumanoid())
    if not hum then
        return
    end

    self.TrackedHumanoid = hum
    self.BaseWalkSpeed = math.max(hum.WalkSpeed, 16)
    self.BaseJumpPower = math.max(hum.JumpPower, 50)
end

function AntiSlowdown:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoSlowdown then
            return
        end

        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            return
        end

        if hum ~= self.TrackedHumanoid then
            self:CaptureBaseStats(hum)
        end

        if hum.WalkSpeed < self.BaseWalkSpeed then
            hum.WalkSpeed = self.BaseWalkSpeed
        end

        if hum.JumpPower < self.BaseJumpPower then
            hum.JumpPower = self.BaseJumpPower
        end
    end)
end

function AntiSlowdown:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AntiSlowdown
