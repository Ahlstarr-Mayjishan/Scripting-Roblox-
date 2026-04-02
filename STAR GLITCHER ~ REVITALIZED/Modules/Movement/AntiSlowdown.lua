--[[
    AntiSlowdown.lua - Neuro-Motor Defense Module
    Job: Preventing speed-related debuffs (Slows).
    Status: Decoupled with active walkspeed/jump monitoring.
]]

local RunService = game:GetService("RunService")
local clock = os.clock

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

    self.Status = "Idle"
    self._lastAction = 0
    return self
end

function AntiSlowdown:_setStatus(status)
    if self.Status ~= status then
        self.Status = status
    end
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
            self:_setStatus("Disabled")
            return
        end

        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            self:_setStatus("Hum Missing")
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                self:CaptureBaseStats(hum)
            end
            self:_setStatus("Respawn Grace")
            return
        end

        self:_setStatus("Monitoring Speed")

        if hum ~= self.TrackedHumanoid then
            self:CaptureBaseStats(hum)
        end

        local actionTaken = false
        if hum.WalkSpeed < self.BaseWalkSpeed then
            hum.WalkSpeed = self.BaseWalkSpeed
            actionTaken = true
        end

        if hum.JumpPower < self.BaseJumpPower then
            hum.JumpPower = self.BaseJumpPower
            actionTaken = true
        end

        if actionTaken then
            self._lastAction = clock()
        end

        if (clock() - self._lastAction) < 1.0 then
            self:_setStatus("Active: SPEED PROTECTED")
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
