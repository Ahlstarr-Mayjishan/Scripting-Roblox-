--[[
    Predictor.lua — OOP Universal Prediction Orchestrator
    Combines Base physics with Kalman smoothing for specific entities.
]]

local Predictor = {}
Predictor.__index = Predictor

function Predictor.new(config, basePredictorClass, kalmanClass)
    local self = setmetatable({}, Predictor)
    self.Options = config.Options
    self.Base = basePredictorClass.new(config)
    self.KalmanFactory = kalmanClass
    return self
end

function Predictor:Predict(origin, part, entry, dt)
    local rawVelocity = self:_CalculateRawVelocity(part, entry, dt)
    
    -- Smooth velocity using Kalman filters if not present
    if not entry._kalmanX then
        entry._kalmanX = self.KalmanFactory.new()
        entry._kalmanY = self.KalmanFactory.new()
        entry._kalmanZ = self.KalmanFactory.new()
    end
    
    local vx = entry._kalmanX:Update(rawVelocity.X)
    local vy = entry._kalmanY:Update(rawVelocity.Y)
    local vz = entry._kalmanZ:Update(rawVelocity.Z)
    local smoothedVelocity = Vector3.new(vx, vy, vz)
    
    -- Final calculation
    return self.Base:Calculate(origin, part, smoothedVelocity, entry.Acceleration)
end

function Predictor:_CalculateRawVelocity(part, entry, dt)
    local pos = part.Position
    local lastPos = entry.LastPos or pos
    local lastTime = entry.LastTime or os.clock()
    local currentTime = os.clock()
    local delta = currentTime - lastTime
    
    if delta > 0 then
        local vel = (pos - lastPos) / delta
        entry.LastPos = pos
        entry.LastTime = currentTime
        return vel
    end
    return entry.Velocity or Vector3.zero
end

return Predictor
