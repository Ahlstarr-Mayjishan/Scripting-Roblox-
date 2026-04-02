--[[
    Predictor.lua — High-Performance Layered Orchestrator
    Analogy: The Neural Motor Network.
    Job: Orchestrates the 4 layers: Sampler -> Estimator -> Engine -> Stabilizer.
    Architecture: Orthogonal-First design (Zero feedback loop).
]]

local Predictor = {}
Predictor.__index = Predictor

function Predictor.new(config, loader, kalman)
    local self = setmetatable({}, Predictor)
    self.Config = config
    self.Options = config.Options
    
    -- Load Layer Modules
    local Path = "Modules/Combat/Prediction/"
    local Sampler    = loader(Path.."Sampler.lua")
    local Estimator  = loader(Path.."Estimator.lua")
    local Engine     = loader(Path.."Engine.lua")
    local Stabilizer = loader(Path.."Stabilizer.lua")
    
    -- Instantiate shared stateless layers
    self.Sampler = Sampler.new(config)
    self.Engine = Engine.new(config)

    -- Keep stateful layers isolated per target so target switching does not
    -- bleed velocity smoothing or screen stabilization across different entries.
    self._EstimatorClass = Estimator
    self._StabilizerClass = Stabilizer
    self._KalmanFactory = kalman and kalman.new or nil
    self._EntryStates = setmetatable({}, { __mode = "k" })
    return self
end

function Predictor:_GetState(entry)
    local state = self._EntryStates[entry]
    if state then
        return state
    end

    local kalman = self._KalmanFactory and self._KalmanFactory(self.Config) or nil
    state = {
        Estimator = self._EstimatorClass.new(kalman, self.Config),
        Stabilizer = self._StabilizerClass.new(),
    }
    self._EntryStates[entry] = state
    return state
end

function Predictor:NotifyTargetChanged(entry, part)
    if not entry then
        return
    end

    local state = self:_GetState(entry)
    if state.Estimator and state.Estimator.Reset then
        state.Estimator:Reset()
    end
    if state.Stabilizer and state.Stabilizer.Reset then
        state.Stabilizer:Reset(part and part.Position or nil)
    end
end

function Predictor:Predict(origin, part, entry, dt)
    -- GUARD: Ensure entry exists
    if not entry then return part.Position end
    local state = self:_GetState(entry)
    
    -- 1. SAMPLING (Input Only)
    local raw = self.Sampler:GetRawState(part, entry.LastPos, entry.LastTime, dt)
    
    -- 2. ESTIMATION (Cleaning State)
    local est = state.Estimator:Estimate(raw, dt)
    
    -- Update entry metadata (Monitoring only, No logic)
    entry.LastPos = raw.Position
    entry.LastTime = raw.Time
    
    -- 3. PREDICTION (Exactly one strategy)
    local predicted = self.Engine:Calculate(origin, raw.Position, est, dt, entry, part)
    
    -- 4. PRESENTATION (Smoothing)
    return state.Stabilizer:Smooth(predicted, dt)
end

return Predictor
