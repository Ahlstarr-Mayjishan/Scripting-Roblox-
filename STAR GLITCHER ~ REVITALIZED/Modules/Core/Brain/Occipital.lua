--[[
    OccipitalLobe.lua - Visual Processing
    Analogy: Primary visual cortex.
    Job: Manages FOV, Highlight, and Target feedback dots.
]]

local OccipitalLobe = {}
OccipitalLobe.__index = OccipitalLobe

function OccipitalLobe.new(visuals)
    local self = setmetatable({}, OccipitalLobe)
    self.fov = visuals.fov
    self.hit = visuals.hit
    self.highlight = visuals.highlight
    self.dot = visuals.dot
    return self
end

function OccipitalLobe:Process(mousePos, targetPos, targetPart, onScreen)
    -- GUARD: FOV Update should always happen to ensure crosshair feedback
    self.fov:Update(mousePos)
    
    -- GUARD: Resolution findings (Fragility fixes)
    -- Only set dot/highlight if we have a valid onscreen target
    if targetPos and targetPart and onScreen then
        self.dot:Set(targetPos, true)
        self.highlight:Set(targetPart, true)
    else
        self:Clear()
    end
end

function OccipitalLobe:Clear()
    -- Safe cleanup: Ensure no trailing highlights or disconnected dots
    self.highlight:Clear()
    self.dot:Set(nil, false)
end

return OccipitalLobe

