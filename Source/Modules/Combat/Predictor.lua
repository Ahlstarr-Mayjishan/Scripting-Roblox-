--[[
    Predictor.lua — OOP Advanced Physics Orchestrator
    Tracks Velocity, Acceleration, and Jerk for high-precision targeting.
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
    local currentTime = os.clock()
    local delta = currentTime - (entry.LastTime or currentTime)
    if delta == 0 then delta = 0.016 end -- Fallback
    
    -- 1. Velocity Tracking
    local rawVel = self:_CalculateRawVelocity(part, entry, delta)
    local smoothedVel = self:_KalmanSmoothVector(rawVel, entry, "_v")
    
    -- 2. Acceleration Tracking (a = dv/dt)
    local rawAccel = (smoothedVel - (entry.PrevVel or smoothedVel)) / delta
    local smoothedAccel = self:_KalmanSmoothVector(rawAccel, entry, "_a")
    
    -- 3. Jerk Tracking (j = da/dt)
    local rawJerk = (smoothedAccel - (entry.PrevAccel or smoothedAccel)) / delta
    local smoothedJerk = self:_KalmanSmoothVector(rawJerk, entry, "_j")
    
    -- Store states for next frame
    entry.PrevVel = smoothedVel
    entry.PrevAccel = smoothedAccel
    entry.LastTime = currentTime
    entry.Acceleration = smoothedAccel -- Export for other modules

    -- 4. Final Calculation (Consumes scientific formulas in Base)
    return self.Base:Calculate(origin, part, smoothedVel, smoothedAccel, smoothedJerk, delta)
end

function Predictor:_CalculateRawVelocity(part, entry, delta)
    local pos = part.Position
    local lastPos = entry.LastPos or pos
    local vel = (pos - lastPos) / delta
    entry.LastPos = pos
    return vel
end

function Predictor:_KalmanSmoothVector(vector, entry, prefix)
    local kx = prefix.."_kx"
    local ky = prefix.."_ky"
    local kz = prefix.."_kz"
    
    if not entry[kx] then
        entry[kx] = self.KalmanFactory.new()
        entry[ky] = self.KalmanFactory.new()
        entry[kz] = self.KalmanFactory.new()
    end
    
    local vx = entry[kx]:Update(vector.X)
    local vy = entry[ky]:Update(vector.Y)
    local vz = entry[kz]:Update(vector.Z)
    
    return Vector3.new(vx, vy, vz)
end

return Predictor
