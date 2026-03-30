--[[
    OccipitalLobe.lua — Visual Processing
    Analogy: Primary visual cortex.
    Script Job: Manages FOV, Highlight, and Target feedback dots.
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
    self.fov:Update(mousePos)
    self.dot:Set(targetPos, onScreen)
    self.highlight:Set(targetPart, true)
end

function OccipitalLobe:Clear()
    self.highlight:Clear()
    self.dot:Set(nil, false)
end

return OccipitalLobe
