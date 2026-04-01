--[[
    Engine.lua - Orthogonal Prediction Strategies
    Analogy: The Cognitive Decision Process.
    Job: Select exactly ONE strategy per frame: Intercept or Linear Extrapolation.
]]

local Engine = {}
Engine.__index = Engine

local Stats = game:GetService("Stats")
local DEFAULT_PROJECTILE_SPEED = 1000
local ZERO = Vector3.zero

function Engine.new(config)
    local self = setmetatable({}, Engine)
    self.Config = config
    self.Options = config.Options
    self.Prediction = config.Prediction or {}
    self.PvP = config.PvP or {}
    self._cachedPing = 50
    self._lastPingCheck = 0
    return self
end

function Engine:_GetLatency()
    local now = os.clock()
    if now - self._lastPingCheck >= 1 then
        self._lastPingCheck = now
        pcall(function()
            local raw = Stats.Network.ServerStatsItem("Data Ping"):GetValueString()
            self._cachedPing = tonumber((raw:gsub("[^%d%.]", ""))) or self._cachedPing
        end)
    end
    return math.clamp(self._cachedPing / 2000, 0, 0.2)
end

function Engine:_GetPingMultiplier()
    if self.Options.TargetPlayersToggle then
        return math.clamp(self.PvP.PING_MULTIPLIER or 1.5, 1, 2.25)
    end
    return 1
end

function Engine:Calculate(origin, targetPos, est, dt)
    local Options = self.Options
    if not Options.PredictionEnabled then
        return targetPos
    end

    local velocity = est.Velocity or ZERO
    local accel = est.Acceleration or ZERO
    local jerk = est.Jerk or ZERO
    local confidence = math.clamp(est.Confidence or 0, 0, 1)
    local motionShock = est.MotionShock or 0
    local speed = velocity.Magnitude

    local toTarget = targetPos - origin
    local distance = toTarget.Magnitude
    if distance <= 0.001 then
        return targetPos
    end

    local projectileSpeed = Options.ProjectileVelocity or Options.ProjectileSpeed or DEFAULT_PROJECTILE_SPEED
    projectileSpeed = math.max(projectileSpeed, 1)

    local travelTime = distance / projectileSpeed
    local latency = self:_GetLatency() * self:_GetPingMultiplier()
    local frameComp = math.min(math.max(est.TimeDelta or dt or 0, 0), 1 / 20) * 0.5
    local totalTime = travelTime + latency + frameComp

    local shotDir = toTarget.Unit
    local forwardSpeed = velocity:Dot(shotDir)
    local lateralVelocity = velocity - (shotDir * forwardSpeed)
    local lateralSpeed = lateralVelocity.Magnitude

    local shockAlpha = math.clamp(motionShock / 180, 0, 1)
    local speedAlpha = math.clamp(speed / 140, 0, 1)
    local lateralAlpha = math.clamp(lateralSpeed / 110, 0, 1)

    local predictedOffset = velocity * totalTime

    -- Strafing targets often miss because lateral movement needs slightly more
    -- aggressive lead than front/back motion under frame + ping delay.
    if lateralSpeed > 0.01 then
        local lateralTrust = math.clamp((0.16 + (confidence * 0.22) + (lateralAlpha * 0.18)) * (1 - shockAlpha * 0.35), 0.08, 0.42)
        predictedOffset = predictedOffset + (lateralVelocity * totalTime * lateralTrust)
    end

    if Options.SmartPrediction and (est.Stable or speed > 65) then
        local accelTrust = math.clamp(confidence * (1 - shockAlpha * 0.7), 0, 1)
        local jerkTrust = math.clamp(accelTrust * (1 - shockAlpha * 0.45), 0, 1)

        local accelWeight = math.clamp((1.08 - (totalTime * 0.3)) * (0.65 + (speedAlpha * 0.45) + (lateralAlpha * 0.2)), 0.24, 1.3) * accelTrust
        local jerkWeight = math.clamp((0.58 - totalTime) * (0.45 + (speedAlpha * 0.35) + (lateralAlpha * 0.15)), 0.05, 0.58) * jerkTrust

        predictedOffset = predictedOffset + ((0.5 * accel * (totalTime ^ 2)) * accelWeight)
        predictedOffset = predictedOffset + (((1 / 6) * jerk * (totalTime ^ 3)) * jerkWeight)
    end

    local leadCap = self.Prediction.MAX_LEAD_DIST or math.huge
    if self.Options.TargetPlayersToggle then
        leadCap = self.PvP.MAX_LEAD_DIST or leadCap
    end

    local maxOffset = math.max(
        18 + (speed * (0.14 + (confidence * 0.18))),
        distance * (0.22 + (speedAlpha * 0.18) + (lateralAlpha * 0.06))
    )
    maxOffset = math.min(maxOffset, leadCap)
    if predictedOffset.Magnitude > maxOffset then
        predictedOffset = predictedOffset.Unit * maxOffset
    end

    local predictedPos = targetPos + predictedOffset
    local trustFactor = math.clamp(
        (confidence * 0.75) + ((est.Stable and 0.15) or 0) + (speedAlpha * 0.12) + (lateralAlpha * 0.12) - (shockAlpha * 0.2),
        0.12,
        1
    )
    return targetPos:Lerp(predictedPos, trustFactor)
end

return Engine
