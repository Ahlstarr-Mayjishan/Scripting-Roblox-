--[[
    Stabilizer.lua - Vision & Presentation Smoothing
    Analogy: The vestibulo-ocular reflex (Vision stabilization).
    Job: Resolve micro-jitters without modifying core prediction state.
]]

local Stabilizer = {}
Stabilizer.__index = Stabilizer

local DEFAULT_DT = 1 / 60
local ZERO = Vector3.zero

function Stabilizer.new()
    local self = setmetatable({}, Stabilizer)
    self.BaseSmoothing = 2.45
    self.CatchupSmoothing = 6.8
    self.SnapDistance = 4.25
    self._lastTarget = ZERO
    return self
end

function Stabilizer:Reset(targetPos)
    self._lastTarget = targetPos or ZERO
end

function Stabilizer:Smooth(targetPos, dt)
    local lastTarget = self._lastTarget
    if lastTarget == ZERO then
        self._lastTarget = targetPos
        return targetPos
    end

    local delta = targetPos - lastTarget
    local deltaMagnitude = delta.Magnitude
    if deltaMagnitude >= self.SnapDistance then
        self._lastTarget = targetPos
        return targetPos
    end

    local catchupAlpha = math.clamp((deltaMagnitude - 0.45) / 6.25, 0, 1)
    local smoothing = self.BaseSmoothing + ((self.CatchupSmoothing - self.BaseSmoothing) * catchupAlpha)
    local alpha = 1 - math.exp(-smoothing * math.max((dt or DEFAULT_DT) * 60, 1))
    local result = lastTarget:Lerp(targetPos, alpha)

    self._lastTarget = result
    return result
end

return Stabilizer
