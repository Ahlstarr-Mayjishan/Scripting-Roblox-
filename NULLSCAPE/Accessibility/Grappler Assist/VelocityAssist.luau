--!nocheck
--[[
 NULLSCAPE - Grappler Assist Velocity Layer
 Small helpers for bounded velocity edits. Keeps assists from hard-snapping RootPart velocity.
]]

local VelocityAssist = {}

local function horizontal(vector)
    if typeof(vector) ~= "Vector3" then
        return Vector3.new(0, 0, 0)
    end
    return Vector3.new(vector.X, 0, vector.Z)
end

local function clampVector(vector, maxMagnitude)
    maxMagnitude = tonumber(maxMagnitude) or math.huge
    if typeof(vector) ~= "Vector3" or vector.Magnitude <= maxMagnitude then
        return vector
    end
    if vector.Magnitude <= 0 then
        return vector
    end
    return vector.Unit * maxMagnitude
end

function VelocityAssist.applyDelta(rootPart, delta, maxDelta, reason)
    if not (rootPart and typeof(delta) == "Vector3") then
        return false
    end

    local bounded = clampVector(delta, maxDelta)
    if bounded.Magnitude <= 0.001 then
        return false
    end

    rootPart.Velocity = rootPart.Velocity + bounded
    return true, bounded, reason
end

function VelocityAssist.blendHorizontal(rootPart, desiredHorizontal, alpha, maxDelta, reason)
    if not (rootPart and typeof(desiredHorizontal) == "Vector3") then
        return false
    end

    local velocity = rootPart.Velocity
    local currentHorizontal = horizontal(velocity)
    local targetHorizontal = horizontal(desiredHorizontal)
    local delta = (targetHorizontal - currentHorizontal) * math.clamp(tonumber(alpha) or 0, 0, 1)
    local bounded = clampVector(delta, maxDelta)
    if bounded.Magnitude <= 0.001 then
        return false
    end

    local nextHorizontal = currentHorizontal + bounded
    rootPart.Velocity = Vector3.new(nextHorizontal.X, velocity.Y, nextHorizontal.Z)
    return true, bounded, reason
end

function VelocityAssist.limitHorizontal(rootPart, maxSpeed, blend, maxDelta, reason)
    if not rootPart then
        return false
    end

    local velocity = rootPart.Velocity
    local currentHorizontal = horizontal(velocity)
    local speed = currentHorizontal.Magnitude
    maxSpeed = tonumber(maxSpeed) or speed
    if speed <= maxSpeed or speed <= 0 then
        return false
    end

    local desired = currentHorizontal.Unit * maxSpeed
    return VelocityAssist.blendHorizontal(rootPart, desired, blend or 1, maxDelta, reason)
end

function VelocityAssist.setVerticalSoft(rootPart, desiredY, alpha, maxDelta, reason)
    if not rootPart then
        return false
    end

    local velocity = rootPart.Velocity
    local deltaY = (tonumber(desiredY) or velocity.Y) - velocity.Y
    deltaY = math.clamp(deltaY * math.clamp(tonumber(alpha) or 0, 0, 1), -(maxDelta or math.huge), maxDelta or math.huge)
    if math.abs(deltaY) <= 0.001 then
        return false
    end

    rootPart.Velocity = Vector3.new(velocity.X, velocity.Y + deltaY, velocity.Z)
    return true, Vector3.new(0, deltaY, 0), reason
end

return VelocityAssist
