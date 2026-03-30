--[[
    KalmanFilter.lua — OOP Noise Reduction Class
    A scientific implementation of 1D Kalman Filter for linear motion smoothing.
]]

local Kalman = {}
Kalman.__index = Kalman

function Kalman.new()
    local self = setmetatable({}, Kalman)
    self.P = 1 -- Estimation error covariance
    self.Q = 0.05 -- Process noise covariance
    self.R = 0.5 -- Measurement noise covariance
    self.Value = nil
    return self
end

function Kalman:Update(measurement)
    if not self.Value then
        self.Value = measurement
        return measurement
    end
    
    -- Prediction phase
    self.P = self.P + self.Q
    
    -- Update phase
    local gain = self.P / (self.P + self.R)
    self.Value = self.Value + gain * (measurement - self.Value)
    self.P = (1 - gain) * self.P
    
    return self.Value
end

return Kalman
