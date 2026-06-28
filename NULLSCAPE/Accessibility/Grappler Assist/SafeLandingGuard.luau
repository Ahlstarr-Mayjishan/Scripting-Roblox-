--!nocheck
--[[
 NULLSCAPE - Grappler Assist Safe Landing Guard
 Detects intentional safe landings and applies bounded vertical damping.
]]

local SafeLandingGuard = {}

local state = {
    LastAt = 0,
    LastGrapple = nil,
    LastResult = nil,
}

local function getNow(deps)
    return (deps and deps.now and deps.now()) or time()
end

local function getHorizontal(velocity)
    if typeof(velocity) ~= "Vector3" then
        return Vector3.new(0, 0, 0)
    end
    return Vector3.new(velocity.X, 0, velocity.Z)
end

function SafeLandingGuard.analyze(deps, grapple, options)
    deps = deps or {}
    options = options or {}
    local now = getNow(deps)
    local ttl = tonumber(options.TTL) or 0.05
    if state.LastResult and state.LastGrapple == grapple and now - (state.LastAt or 0) <= ttl then
        return state.LastResult
    end

    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    local result = {
        Safe = false,
        Intentional = false,
        Reason = "NoState",
        Hit = nil,
        TimeToLanding = math.huge,
        Distance = math.huge,
        ThreatScore = 0,
    }

    if not (rootPart and velocity and velocity.Y < -2 and deps.raycastFloor) then
        state.LastAt = now
        state.LastGrapple = grapple
        state.LastResult = result
        return result
    end

    local profile = deps.getPhysicsProfile and deps.getPhysicsProfile(grapple) or nil
    local depth = tonumber(options.Depth) or 190
    local horizontal = getHorizontal(velocity)
    local samples = {
        rootPart.Position,
        rootPart.Position + horizontal * 0.2,
        rootPart.Position + horizontal * 0.42,
    }

    local bestHit = nil
    local bestDistance = math.huge
    for _, sample in ipairs(samples) do
        local hit = deps.raycastFloor(sample, depth)
        if hit and hit.Position then
            local distance = rootPart.Position.Y - hit.Position.Y
            if distance >= 0 and distance < bestDistance then
                bestHit = hit
                bestDistance = distance
            end
        end
    end

    if not bestHit then
        result.Reason = "NoFloor"
    else
        local threat = deps.getLandingThreat and deps.getLandingThreat(bestHit) or { Score = 0, Reason = "LandingClear" }
        local fallSpeed = math.max(-velocity.Y, 8)
        local timeToLanding = bestDistance / fallSpeed
        local maxTime = (tonumber(options.MaxTime) or 1.55) * (profile and profile.PredictionScale or 1)
        local normalOk = not bestHit.Normal or bestHit.Normal.Y >= (tonumber(options.MinNormalY) or 0.45)
        local killY = deps.getVoidKillPlaneY and deps.getVoidKillPlaneY() or nil
        local aboveKill = not killY or bestHit.Position.Y > killY + (tonumber(options.KillMargin) or 12)
        local threatOk = (tonumber(threat.Score) or 0) < (tonumber(options.MaxThreatScore) or 52)

        result.Hit = bestHit
        result.Distance = bestDistance
        result.TimeToLanding = timeToLanding
        result.ThreatScore = tonumber(threat.Score) or 0
        result.ThreatReason = threat.Reason

        if normalOk and aboveKill and threatOk and timeToLanding <= maxTime then
            result.Safe = true
            result.Intentional = true
            result.Reason = "SafeLanding"
        else
            result.Reason = threatOk and "UnsafeLandingGeometry" or tostring(threat.Reason or "LandingThreat")
        end
    end

    state.LastAt = now
    state.LastGrapple = grapple
    state.LastResult = result
    return result
end

function SafeLandingGuard.applyDamping(deps, grapple, landing)
    deps = deps or {}
    landing = landing or SafeLandingGuard.analyze(deps, grapple)
    if not (landing and landing.Safe) then
        return false
    end

    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    local velocityAssist = deps.VelocityAssist
    if not (rootPart and velocity and velocity.Y < -18 and velocityAssist and velocityAssist.setVerticalSoft) then
        return false
    end

    if landing.TimeToLanding > 0.16 then
        return false
    end

    local targetY = math.max(velocity.Y * 0.45, -42)
    velocityAssist.setVerticalSoft(rootPart, targetY, 0.5, 18, "SafeLanding")
    return true
end

function SafeLandingGuard.clear()
    state.LastAt = 0
    state.LastGrapple = nil
    state.LastResult = nil
end

function SafeLandingGuard.snapshot()
    local result = state.LastResult
    if not result then
        return "Landing:pending"
    end
    return tostring(result.Reason) .. ":" .. string.format("%.2f", tonumber(result.TimeToLanding) or 0)
end

return SafeLandingGuard
