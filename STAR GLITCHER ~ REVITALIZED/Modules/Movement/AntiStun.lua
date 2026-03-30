local RunService = game:GetService("RunService")

local AntiStun = {}
AntiStun.__index = AntiStun

function AntiStun.new(options, localCharacter)
    local self = setmetatable({}, AntiStun)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.TrackedHumanoid = nil
    return self
end

function AntiStun:_restoreStateGuards(humanoid)
    if not humanoid then
        return
    end

    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
    end)
end

function AntiStun:_applyStateGuards(humanoid)
    if not humanoid then
        return
    end

    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
end

function AntiStun:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local _, hum = self.LocalCharacter and self.LocalCharacter:GetState()

        if not self.Options.NoStun then
            if hum == self.TrackedHumanoid then
                self:_restoreStateGuards(hum)
                self.TrackedHumanoid = nil
            end
            return
        end

        if not hum then
            return
        end

        if hum ~= self.TrackedHumanoid then
            if self.TrackedHumanoid then
                self:_restoreStateGuards(self.TrackedHumanoid)
            end
            self.TrackedHumanoid = hum
            self:_applyStateGuards(hum)
        end

        local state = hum:GetState()
        if state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

function AntiStun:Destroy()
    if self.TrackedHumanoid then
        self:_restoreStateGuards(self.TrackedHumanoid)
        self.TrackedHumanoid = nil
    end

    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AntiStun
