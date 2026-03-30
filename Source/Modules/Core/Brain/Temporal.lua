--[[
    TemporalLobe.lua — Memory & Language/Prediction
    Analogy: Processing sensory input into derived meanings (Prediction).
    Script Job: Runs calculations on target motion and determines best target.
]]

local TemporalLobe = {}
TemporalLobe.__index = TemporalLobe

function TemporalLobe.new(selector, predictor)
    local self = setmetatable({}, TemporalLobe)
    self.Selector = selector
    self.Predictor = predictor
    return self
end

function TemporalLobe:Scan(mousePos, originPos)
    return self.Selector:GetClosestTarget(mousePos, originPos)
end

function TemporalLobe:Calculate(origin, part, entry, dt)
    return self.Predictor:Predict(origin, part, entry, dt)
end

return TemporalLobe
