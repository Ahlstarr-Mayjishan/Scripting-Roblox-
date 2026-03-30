--[[
    Estimator.lua — State Estimation & Noise Removal
    Analogy: Inferior Colliculus (Auditory/Visual processing before perception).
    Job: Filtering raw velocity, detecting acceleration/jerk, and scoring confidence.
]]

local Estimator = {}
Estimator.__index = Estimator

function Estimator.new(kalman)
    local self = setmetatable({}, Estimator)
    self.Kalman = kalman
    self._prevVelocity = Vector3.zero
    self._prevAcceleration = Vector3.zero
    return self
end

function Estimator:Estimate(raw, dt)
    local filteredVel = raw.Velocity
    if self.Kalman and self.Kalman.Update then
        filteredVel = self.Kalman:Update(raw.Velocity)
    end
    
    local accel = Vector3.zero
    if dt > 0 then
        accel = (filteredVel - self._prevVelocity) / dt
    end
    
    -- Jerk calculation (rate of accel change)
    local jerk = Vector3.zero
    if dt > 0 then
        jerk = (accel - self._prevAcceleration) / dt
    end
    
    -- Confidence scoring (Higher confidence if stable motion)
    local score = 1.0
    if raw.IsTeleport then score = 0.1 end
    if accel.Magnitude > 100 then score = 0.5 end -- High acceleration noise
    
    self._prevVelocity = filteredVel
    self._prevAcceleration = accel
    
    return {
        Velocity = filteredVel,
        Acceleration = accel,
        Jerk = jerk,
        Confidence = score,
        Stable = score > 0.8
    }
end

return Estimator
