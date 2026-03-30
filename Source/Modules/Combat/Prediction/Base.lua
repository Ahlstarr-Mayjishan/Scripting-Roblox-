--[[
    BasePredictor.lua — OOP Extrapolation & Math Core
    Provides scientific physics calculation for target prediction.
]]

local BasePredictor = {}
BasePredictor.__index = BasePredictor

function BasePredictor.new(config)
    local self = setmetatable({}, BasePredictor)
    self.Config = config
    self.Options = config.Options
    return self
end

-- Linear prediction with distance/speed scale
function BasePredictor:Calculate(origin, part, velocity, acceleration)
    local targetPos = part.Position
    local distance = (targetPos - origin).Magnitude
    
    -- Estimation of travel time (for a projectile logic)
    -- If beam (instant), time is 0. 
    -- If we have bullet speed, we'd use travelTime = distance / bulletSpeed.
    local travelTime = (distance / 1000) * (self.Options.PredictionScale or 1)
    
    -- Extrapolate
    local extrapolated = targetPos + (velocity * travelTime)
    
    -- Acceleration compensation
    if acceleration and acceleration.Magnitude > 0.1 then
        extrapolated = extrapolated + (0.5 * acceleration * travelTime * travelTime)
    end
    
    return extrapolated
end

return BasePredictor
