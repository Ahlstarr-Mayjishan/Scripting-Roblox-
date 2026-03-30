local RunService = game:GetService("RunService")

local CustomSpeed = {}
CustomSpeed.__index = CustomSpeed

function CustomSpeed.new(options, localCharacter)
    local self = setmetatable({}, CustomSpeed)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    return self
end

function CustomSpeed:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.CustomMoveSpeedEnabled then
            return
        end

        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            return
        end

        if math.abs(hum.WalkSpeed - self.Options.CustomMoveSpeed) > 0.1 then
            hum.WalkSpeed = self.Options.CustomMoveSpeed
        end
    end)
end

function CustomSpeed:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return CustomSpeed
