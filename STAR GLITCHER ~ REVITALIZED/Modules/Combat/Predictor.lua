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
    self.Options = config.Options
    
    -- Load Layer Modules
    local Path = "Modules/Combat/Prediction/"
    local Sampler    = loader(Path.."Sampler.lua")
    local Estimator  = loader(Path.."Estimator.lua")
    local Engine     = loader(Path.."Engine.lua")
    local Stabilizer = loader(Path.."Stabilizer.lua")
    
    -- Instantiate Layers (Isolated State)
    self.Sampler    = Sampler.new()
    self.Estimator  = Estimator.new(kalman and kalman.new and kalman.new() or nil)
    self.Engine     = Engine.new(config)
    self.Stabilizer = Stabilizer.new()
    
    return self
end

function Predictor:Predict(origin, part, entry, dt)
    -- GUARD: Ensure entry exists
    if not entry then return part.Position end
    
    -- 1. SAMPLING (Input Only)
    local raw = self.Sampler:GetRawState(part, entry.LastPos, entry.LastTime, dt)
    
    -- 2. ESTIMATION (Cleaning State)
    local est = self.Estimator:Estimate(raw, dt)
    
    -- Update entry metadata (Monitoring only, No logic)
    entry.LastPos = raw.Position
    entry.LastTime = raw.Time
    
    -- 3. PREDICTION (Exactly one strategy)
    local predicted = self.Engine:Calculate(origin, raw.Position, est, dt)
    
    -- 4. PRESENTATION (Smoothing)
    return self.Stabilizer:Smooth(predicted, dt)
end

return Predictor
