--[[
    Engine.lua — Orthogonal Prediction Strategies
    Analogy: The Cognitive Decision Process.
    Job: Select exactly ONE strategy per frame: Intercept or Linear Extrapolation.
]]

local Engine = {}
Engine.__index = Engine

function Engine.new(config)
    local self = setmetatable({}, Engine)
    self.Options = config.Options
    return self
end

function Engine:Calculate(origin, targetPos, est, dt)
    local Options = self.Options
    if not Options.PredictionEnabled then return targetPos end
    
    local velocity = est.Velocity
    local accel = est.Acceleration
    local jerk = est.Jerk
    local confidence = est.Confidence
    
    -- Calculate Latency/Travel Compensation
    local distance = (targetPos - origin).Magnitude
    local projectileSpeed = Options.ProjectileVelocity or Options.ProjectileSpeed or 1000
    local travelTime = distance / (projectileSpeed > 0 and projectileSpeed or 1)
    local latency = 0.05 -- Static latency (50ms)
    
    local totalTime = travelTime + latency
    
    -- PREDICTION SENSITIVITY BRAKES (Adaptive)
    -- We dampen higher order terms (Accel/Jerk) to prevent "Flying Predictions"
    local accelWeight = math.clamp(1.0 - (totalTime / 2), 0.2, 0.8)
    local jerkWeight  = math.clamp(0.5 - totalTime, 0.1, 0.3)
    
    -- ONE ORTHOGONAL STRATEGY: Select one, don't stack.
    local predictedPos = targetPos
    
    if Options.SmartPrediction and est.Stable then
        -- KINEMATIC INTERCEPT (Scientific with Adaptive Braking)
        -- s = vt + (0.5at^2 * damping) + (jt^3 * damping)
        local linear = velocity * totalTime
        local accelerated = (0.5 * accel * (totalTime ^ 2)) * accelWeight
        local jerked = ((1/6) * jerk * (totalTime ^ 3)) * jerkWeight
        
        predictedPos = targetPos + linear + accelerated + jerked
    else
        -- LINEAR EXTRAPOLATION (Fallback)
        predictedPos = targetPos + (velocity * totalTime)
    end
    
    -- Global Confidence Brake: 
    -- Ensure prediction doesn't exceed a realistic offset from the target
    local maxOffset = math.max(distance * 0.2, 10)
    local actualOffset = (predictedPos - targetPos)
    if actualOffset.Magnitude > maxOffset then
        predictedPos = targetPos + (actualOffset.Unit * maxOffset)
    end

    -- High Confidence weight: Fade back if confidence is low
    return targetPos:Lerp(predictedPos, math.clamp(confidence * 0.8, 0, 1))
end

return Engine
