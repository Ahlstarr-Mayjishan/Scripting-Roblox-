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
    
    -- ONE ORTHOGONAL STRATEGY: Select one, don't stack.
    local predictedPos = targetPos
    
    if Options.SmartPrediction and est.Stable then
        -- KINEMATIC INTERCEPT (Scientific)
        -- s = vt + 0.5at^2 + (1/6)jt^3
        local linear = velocity * totalTime
        local accelerated = 0.5 * accel * (totalTime ^ 2)
        local jerked = (1/6) * jerk * (totalTime ^ 3)
        
        predictedPos = targetPos + linear + accelerated + jerked
    else
        -- LINEAR EXTRAPOLATION (Fallback)
        predictedPos = targetPos + (velocity * totalTime)
    end
    
    -- High Confidence weight: Fade back to raw position if confidence is low
    return targetPos:Lerp(predictedPos, math.clamp(confidence, 0, 1))
end

return Engine
