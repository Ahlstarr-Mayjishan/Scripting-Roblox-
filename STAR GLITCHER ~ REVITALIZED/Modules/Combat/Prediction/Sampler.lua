--[[
    Sampler.lua — Pure Kinematic Data Extraction
    Analogy: The sensory nerves (Afferent fibers).
    Job: Extract raw position, velocity, and teleportation data without modification.
]]

local Sampler = {}
Sampler.__index = Sampler

function Sampler.new()
    return setmetatable({}, Sampler)
end

function Sampler:GetRawState(part, lastPos, lastTime, dt)
    local currentPos = part.Position
    local currentTime = os.clock()
    
    local velocity = Vector3.zero
    if lastPos and lastTime > 0 then
        local delta = currentPos - lastPos
        local timeDelta = currentTime - lastTime
        if timeDelta > 0 then
            velocity = delta / timeDelta
        end
    end
    
    -- Teleport detection (Distance threshold)
    local isTeleport = lastPos and (currentPos - lastPos).Magnitude > 50
    
    return {
        Position = currentPos,
        Velocity = velocity,
        IsTeleport = isTeleport,
        Time = currentTime
    }
end

return Sampler
