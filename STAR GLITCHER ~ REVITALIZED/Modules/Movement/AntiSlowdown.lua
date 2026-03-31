--[[
    AntiSlowdown.lua — Neuro-Motor Defense Module
    Job: Preventing speed-related debuffs (Slows).
    Status: Decoupled with active walkspeed/jump monitoring.
]]

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
    
    self.Status = "Idle"
    self._lastAction = 0 
    return self
end

function AntiSlowdown:CaptureBaseStats(humanoid)
    local hum = humanoid or (self.LocalCharacter and self.LocalCharacter:GetHumanoid())
    if not hum then return end

    self.TrackedHumanoid = hum
    -- Ensure we capture a valid base stat (not a slow value)
    self.BaseWalkSpeed = math.max(hum.WalkSpeed, 16)
    self.BaseJumpPower = math.max(hum.JumpPower, 50)
end

function AntiSlowdown:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoSlowdown then
            self.Status = "Disabled"
            return
        end

        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            self.Status = "Hum Missing"
            return
        end
        
        self.Status = "Monitoring Speed"

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
            self._lastAction = os.clock()
        end
        
        if (os.clock() - self._lastAction) < 1.0 then
            self.Status = "Active: SPEED PROTECTED ✅"
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
