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
    local inputDirection = deps.getInputDirection and deps.getInputDirection(grapple) or nil
    local inputHorizontal = getHorizontal(inputDirection)
    local inputUnit = inputHorizontal.Magnitude > 0.05 and inputHorizontal.Unit or nil
    local horizontalSpeed = horizontal.Magnitude
    local velocityUnit = horizontalSpeed > 0.05 and horizontal.Unit or nil
    local horizon = deps.getPredictionHorizon and deps.getPredictionHorizon(grapple) or nil
    local controlProbeTime = tonumber(options.ControlProbeTime) or tonumber(horizon and horizon.Tactical) or 0.72
    local routeTime = tonumber(horizon and horizon.Route) or controlProbeTime
    local controlProbeDistance = math.clamp(horizontalSpeed * controlProbeTime, 16, tonumber(options.MaxControlProbeDistance) or 96)
    local coarseProbeDistance = math.clamp(horizontalSpeed * routeTime, 32, tonumber(options.MaxCoarseProbeDistance) or 180)
    local samples = {
        rootPart.Position,
        rootPart.Position + horizontal * 0.2,
        rootPart.Position + horizontal * 0.42,
    }
    if velocityUnit then
        table.insert(samples, rootPart.Position + velocityUnit * math.min(controlProbeDistance, 72))
    end
    if inputUnit then
        table.insert(samples, rootPart.Position + inputUnit * controlProbeDistance)
        if velocityUnit then
            local blendedDirection = inputUnit + velocityUnit
            if blendedDirection.Magnitude > 0.05 then
                table.insert(samples, rootPart.Position + blendedDirection.Unit * math.min(controlProbeDistance * 0.85, 84))
            end
        end
    end

    local coarseSamples = {}
    if velocityUnit then
        table.insert(coarseSamples, rootPart.Position + velocityUnit * coarseProbeDistance)
    end
    if inputUnit then
        table.insert(coarseSamples, rootPart.Position + inputUnit * coarseProbeDistance)
    end

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
    if not bestHit and deps.raycastCoarseFloor then
        for _, sample in ipairs(coarseSamples) do
            local hit = deps.raycastCoarseFloor(sample, depth)
            if hit and hit.Position then
                local distance = rootPart.Position.Y - hit.Position.Y
                if distance >= 0 and distance < bestDistance then
                    bestHit = hit
                    bestDistance = distance
                    result.Coarse = true
                end
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
        local controlledMaxTime = (tonumber(options.ControlledMaxTime) or tonumber(horizon and horizon.Route) or 2.35) * (profile and profile.PredictionScale or 1)
        local normalOk = not bestHit.Normal or bestHit.Normal.Y >= (tonumber(options.MinNormalY) or 0.45)
        local killY = deps.getVoidKillPlaneY and deps.getVoidKillPlaneY() or nil
        local aboveKill = not killY or bestHit.Position.Y > killY + (tonumber(options.KillMargin) or 12)
        local threatOk = (tonumber(threat.Score) or 0) < (tonumber(options.MaxThreatScore) or 52)
        local playerCanSteer = inputUnit ~= nil and horizontalSpeed >= (tonumber(options.MinControlledHorizontalSpeed) or 20)
        local canAirJump = deps.canAirJump and deps.canAirJump(grapple) == true
        local controlledLanding = (playerCanSteer or canAirJump) and timeToLanding <= controlledMaxTime

        result.Hit = bestHit
        result.Distance = bestDistance
        result.TimeToLanding = timeToLanding
        result.ThreatScore = tonumber(threat.Score) or 0
        result.ThreatReason = threat.Reason

        if normalOk and aboveKill and threatOk and (timeToLanding <= maxTime or controlledLanding) then
            result.Safe = true
            result.Intentional = controlledLanding or playerCanSteer
            result.Reason = controlledLanding and (result.Coarse and "CoarseReachableLanding" or "ReachableLanding") or "SafeLanding"
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
