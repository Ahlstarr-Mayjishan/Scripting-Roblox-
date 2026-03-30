local RunService = game:GetService("RunService")

local AntiStun = {}
AntiStun.__index = AntiStun

function AntiStun.new(options, localCharacter)
    local self = setmetatable({}, AntiStun)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    return self
end

function AntiStun:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoStun then
            return
        end

        local _, hum, root = self.LocalCharacter and self.LocalCharacter:GetState()
        if not hum then
            return
        end

        local state = hum:GetState()
        if state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.PlatformStanding then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        if root and root.Anchored then
            root.Anchored = false
        end
    end)
end

function AntiStun:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AntiStun
