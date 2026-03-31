--[[
    Estimator.lua — State Estimation & Noise Removal (Physics Damping v2)
    Analogy: Inferior Colliculus (Auditory/Visual processing before perception).
    Job: Filtering raw velocity, detecting acceleration/jerk, and scoring confidence.
    Fixes: Jitter/Shakiness (rung) via progressive damping filters.
]]

local Estimator = {}
Estimator.__index = Estimator

function Estimator.new(kalman)
    local self = setmetatable({}, Estimator)
    self.Kalman = kalman
    self._prevVelocity = Vector3.zero
    self._prevAcceleration = Vector3.zero
    self._prevJerk = Vector3.zero
    return self
end

function Estimator:Reset()
    self._prevVelocity = Vector3.zero
    self._prevAcceleration = Vector3.zero
    self._prevJerk = Vector3.zero
    if self.Kalman then
        self.Kalman.Value = nil
        self.Kalman.P = 1
    end
end

function Estimator:Estimate(raw, dt)
    local filteredVel = raw.Velocity
    if self.Kalman and self.Kalman.Update then
        filteredVel = self.Kalman:Update(raw.Velocity)
    end
    
    local accel = Vector3.zero
    if dt > 0 then
        local rawAccel = (filteredVel - self._prevVelocity) / dt
        -- Damping: Micro-jitters in velocity create massive spikes in accel.
        -- We lerp the acceleration to bridge the noise (Linear Mix).
        accel = self._prevAcceleration:Lerp(rawAccel, math.clamp(dt * 10, 0, 1))
    end
    
    -- Jerk calculation (rate of accel change with damping)
    local jerk = Vector3.zero
    if dt > 0 then
        local rawJerk = (accel - self._prevAcceleration) / dt
        jerk = self._prevJerk:Lerp(rawJerk, math.clamp(dt * 5, 0, 1))
    end
    
    -- Confidence scoring (Higher confidence if stable motion)
    local score = 1.0
    if raw.IsTeleport then score = 0.1 end
    if accel.Magnitude > 120 then score = 0.4 end -- If acceleration is too noisy, lower confidence
    
    self._prevVelocity = filteredVel
    self._prevAcceleration = accel
    self._prevJerk = jerk
    
    return {
        Velocity = filteredVel,
        Acceleration = accel,
        Jerk = jerk,
        Confidence = score,
        Stable = score > 0.8
    }
end

return Estimator
