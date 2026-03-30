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
    return self
end

function SpeedMultiplier:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            return
        end

        if hum ~= self.TrackedHumanoid then
            self.TrackedHumanoid = hum
            self.BaseWalkSpeed = math.max(hum.WalkSpeed, 0)
        elseif not self.Options.SpeedMultiplierEnabled then
            self.BaseWalkSpeed = math.max(hum.WalkSpeed, 0)
        end

        if not self.Options.SpeedMultiplierEnabled or self.Options.CustomMoveSpeedEnabled then
            return
        end

        local desiredSpeed = self.BaseWalkSpeed * self.Options.SpeedMultiplier
        if math.abs(hum.WalkSpeed - desiredSpeed) > 0.1 then
            hum.WalkSpeed = desiredSpeed
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
