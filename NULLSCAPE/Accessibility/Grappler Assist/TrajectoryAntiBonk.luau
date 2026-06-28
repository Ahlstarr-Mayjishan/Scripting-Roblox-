--!nocheck
--[[
 NULLSCAPE - Grappler Assist Trajectory Anti-Bonk
 Predicts high-speed wall impacts and applies bounded soft braking.
]]

local TrajectoryAntiBonk = {}

local state = {
    LastAt = 0,
    LastResult = nil,
}

local function horizontal(vector)
    if typeof(vector) ~= "Vector3" then
        return Vector3.new(0, 0, 0)
    end
    return Vector3.new(vector.X, 0, vector.Z)
end

function TrajectoryAntiBonk.predict(deps, grapple)
    deps = deps or {}
    local now = (deps.now and deps.now()) or time()
    local interval = tonumber(deps.Interval) or 0.055
    if state.LastResult and now - (state.LastAt or 0) <= interval then
        return state.LastResult
    end

    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    local result = {
        Danger = false,
        Reason = "NoState",
        Hit = nil,
        Speed = 0,
        TimeToImpact = math.huge,
    }

    if not (rootPart and velocity and deps.raycast) then
        state.LastAt = now
        state.LastResult = result
        return result
    end

    local flat = horizontal(velocity)
    local speed = flat.Magnitude
    result.Speed = speed
    local profile = deps.getPhysicsProfile and deps.getPhysicsProfile(grapple) or nil
    local minSpeed = tonumber(deps.MinSpeed) or 112
    if profile and profile.Helmet then
        minSpeed = math.max(minSpeed, 170)
    end
    if speed < minSpeed then
        result.Reason = "SpeedLow"
        state.LastAt = now
        state.LastResult = result
        return result
    end

    local lookahead = math.clamp((tonumber(deps.Lookahead) or 0.26) * (profile and profile.PredictionScale or 1), 0.12, 0.38)
    local direction = flat.Unit * math.max(speed * lookahead, tonumber(deps.MinProbeDistance) or 10)
    local hit = deps.raycast(rootPart.Position, direction)
    if hit and hit.Normal and hit.Normal.Y < (tonumber(deps.MaxNormalY) or 0.42) then
        result.Danger = true
        result.Reason = "WallImpact"
        result.Hit = hit
        result.TimeToImpact = (hit.Position - rootPart.Position).Magnitude / math.max(speed, 1)
    else
        result.Reason = "PathClear"
    end

    state.LastAt = now
    state.LastResult = result
    return result
end

function TrajectoryAntiBonk.apply(deps, grapple)
    deps = deps or {}
    local prediction = TrajectoryAntiBonk.predict(deps, grapple)
    if not (prediction and prediction.Danger) then
        return false
    end

    local rootPart = grapple and grapple.RootPart
    local velocityAssist = deps.VelocityAssist
    if not (rootPart and velocityAssist and velocityAssist.limitHorizontal) then
        return false
    end

    local profile = deps.getPhysicsProfile and deps.getPhysicsProfile(grapple) or nil
    local targetSpeed = profile and profile.Helmet and 140 or 92
    velocityAssist.limitHorizontal(rootPart, targetSpeed, 0.55, 26, "TrajectoryAntiBonk")
    return true, prediction
end

function TrajectoryAntiBonk.clear()
    state.LastAt = 0
    state.LastResult = nil
end

function TrajectoryAntiBonk.snapshot()
    local result = state.LastResult
    if not result then
        return "Bonk:pending"
    end
    return tostring(result.Reason) .. ":" .. string.format("%.0f", tonumber(result.Speed) or 0)
end

return TrajectoryAntiBonk
