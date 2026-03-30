--[[
    TemporalLobe.lua — Processing sensory input into cognition.
    Analogy: High-level cognition và logic orchestration.
    Job: Orchestrates the target selection và prediction pipeline.
    Resolves the "Thin Wrapper" debt by owning the decision state.
]]

local TemporalLobe = {}
TemporalLobe.__index = TemporalLobe

function TemporalLobe.new(selector, predictor)
    local self = setmetatable({}, TemporalLobe)
    self.Selector = selector
    self.Predictor = predictor
    
    self._targetEntry = nil
    self._targetPart = nil
    self._prediction = nil
    return self
end

function TemporalLobe:Scan(mousePos, originPos)
    -- Cognition: Select the best target entry
    self._targetEntry = self.Selector:GetClosestTarget(mousePos, originPos)
    return self._targetEntry
end

function TemporalLobe:Process(originPos, dt)
    -- Cognition: Process the target into a prediction
    if not self._targetEntry then 
        self._targetPart = nil 
        self._prediction = nil
        return nil, nil 
    end
    
    self._targetPart = self.Selector.Tracker:GetTargetPart(self._targetEntry)
    if not self._targetPart then return nil, nil end
    
    self._prediction = self.Predictor:Predict(originPos, self._targetPart, self._targetEntry, dt)
    
    return self._targetPart, self._prediction
end

return TemporalLobe
