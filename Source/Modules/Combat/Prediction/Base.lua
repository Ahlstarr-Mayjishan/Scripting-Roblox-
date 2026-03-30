--[[
    Base.lua — Scientific Physics Core (Smart Prediction)
    Implements advanced kinematic equations:
    • Uniform Linear Motion: s = vt
    • Uniformly Accelerated Motion: s = v0t + 0.5at^2
    • Braking/Deceleration compensation
    • Jerk-aware extrapolation
]]

local Base = {}
Base.__index = Base

function Base.new(config)
    local self = setmetatable({}, Base)
    self.Config = config
    self.Options = config.Options
    return self
end

function Base:Calculate(origin, part, velocity, acceleration, jerk, dt)
    local targetPos = part.Position
    local dist = (targetPos - origin).Magnitude
    
    -- 1. Travel Time Estimation (Projectile/Spell flight)
    -- Nếu là Beam (tốc độ ánh sáng), travelTime ~ 0.
    -- Với phép thuật có vận tốc, travelTime = dist / bulletSpeed.
    local travelTime = (dist / 1000) * (self.Options.PredictionScale or 1)
    
    -- 2. Kinematic Equations Dispatch
    local predictedOffset = Vector3.zero
    
    if acceleration and acceleration.Magnitude > 0.05 then
        -- Chuyển động có gia tốc đều: s = vt + 0.5at^2
        predictedOffset = (velocity * travelTime) + (0.5 * acceleration * travelTime * travelTime)
        
        -- Jerk compensation: s += (1/6) * j * t^3
        if jerk and jerk.Magnitude > 0.01 then
            predictedOffset = predictedOffset + ( (1/6) * jerk * math.pow(travelTime, 3) )
        end
    else
        -- Chuyển động thẳng đều: s = vt
        predictedOffset = velocity * travelTime
    end
    
    -- 3. Braking / Deceleration Logic (Quãng đường phanh)
    -- Nếu vận tốc đang giảm mạnh (a ngược chiều v), chúng ta bù trừ quãng đường phanh
    local speed = velocity.Magnitude
    if speed > 1 and acceleration then
        local dot = velocity.Unit:Dot(acceleration.Unit)
        if dot < -0.7 then -- Đang phanh/hãm
            local deceleration = acceleration.Magnitude
            -- s_phanh = v^2 / 2a (Công thức quãng đường hãm)
            local brakingDist = (speed * speed) / (2 * deceleration)
            
            -- Giới hạn bù trừ phanh để tránh jitter
            brakingDist = math.min(brakingDist, 5) 
            predictedOffset = predictedOffset + (acceleration.Unit * brakingDist * 0.5)
        end
    end
    
    return targetPos + predictedOffset
end

return Base
