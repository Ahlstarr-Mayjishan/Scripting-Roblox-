--[[
    Stabilizer.lua — Vision & Presentation Smoothing
    Analogy: The vestibulo-ocular reflex (Vision stabilization).
    Job: Resolve micro-jitters without modifying core prediction state.
]]

local Stabilizer = {}
Stabilizer.__index = Stabilizer

function Stabilizer.new()
    local self = setmetatable({}, Stabilizer)
    self.Smoothing = 0.5 -- Default micro-smoothing
    self._lastTarget = Vector3.zero
    return self
end

function Stabilizer:Reset(targetPos)
    self._lastTarget = targetPos or Vector3.zero
end

function Stabilizer:Smooth(targetPos, dt)
    if self._lastTarget == Vector3.zero then self._lastTarget = targetPos end
    
    -- Exponential smoothing (Post-process only)
    -- This resolving the jitter identified in the findings.
    local alpha = 1 - math.exp(-self.Smoothing * (dt * 60))
    local result = self._lastTarget:Lerp(targetPos, alpha)
    
    self._lastTarget = result
    return result
end

return Stabilizer
