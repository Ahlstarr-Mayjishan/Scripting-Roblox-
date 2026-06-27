--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Terrain Sense
--  Surface classification and scoring for terrain-aware rescue targeting.
-- ]]


local TerrainSense = {}

function TerrainSense.getSurfaceKind(normal)
    if not normal then
        return "Unknown"
    end

    if normal.Y >= 0.68 then
        return "Floor"
    elseif normal.Y >= 0.22 then
        return "Slope"
    elseif normal.Y <= -0.25 then
        return "Ceiling"
    end

    return "Wall"
end

function TerrainSense.getEdgePenalty(deps, grapple, result)
    local cfg = deps.CFG
    local normal = result and result.Normal
    local rootPart = grapple and grapple.RootPart
    if not (normal and rootPart and result.Position) then
        return 0
    end

    local flatNormal = Vector3.new(normal.X, 0, normal.Z)
    if flatNormal.Magnitude <= 0.05 then
        return 0
    end

    local probeOrigin = result.Position + normal * 0.25 + Vector3.new(0, cfg.TERRAIN_EDGE_PROBE_DISTANCE, 0)
    local probeDirection = Vector3.new(0, -cfg.TERRAIN_EDGE_PROBE_DISTANCE * 2, 0)
    local workspace = deps.Workspace
    if not workspace then
        return 0
    end

    local hit = workspace:Raycast(probeOrigin, probeDirection, grapple.grappleParams)
    if hit and hit.Instance == result.Instance then
        return 0
    end

    return cfg.TERRAIN_EDGE_PENALTY
end

function TerrainSense.scoreSurface(deps, grapple, result, screenScore, driveMode)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    if not (rootPart and result and result.Position) then
        return math.huge, "NoSurface"
    end

    local distance = (result.Position - rootPart.Position).Magnitude
    local verticalOffset = result.Position.Y - rootPart.Position.Y
    local kind = TerrainSense.getSurfaceKind(result.Normal)
    local voidDanger = deps.isVoidRescueWindowActive() or deps.isVoidRescueDanger(grapple)
    local score = (screenScore or 0) * cfg.TERRAIN_SURFACE_SCREEN_WEIGHT
        + distance * cfg.TERRAIN_SURFACE_DISTANCE_WEIGHT
        + TerrainSense.getEdgePenalty(deps, grapple, result)
    local reason = "Terrain" .. kind

    if kind == "Floor" or kind == "Slope" then
        score = score + cfg.TERRAIN_SAFE_FLOOR_BONUS
    elseif kind == "Wall" then
        score = score + cfg.TERRAIN_WALL_RESCUE_PENALTY
    elseif kind == "Ceiling" then
        score = score + cfg.TERRAIN_CEILING_PENALTY
    end

    if voidDanger then
        if verticalOffset >= -4 then
            score = score + cfg.TERRAIN_UPWARD_RESCUE_BONUS
            reason = reason .. ":VoidUpward"
        else
            score = score + cfg.TERRAIN_LOW_VOID_PENALTY
            reason = reason .. ":VoidLow"
        end
    elseif not driveMode and verticalOffset < -18 then
        score = score + 35
    end

    return score, reason
end

local function addProbePosition(positions, position)
    table.insert(positions, position)
end

local function getFlatNormalUnit(normal)
    local flat = normal and Vector3.new(normal.X, 0, normal.Z)
    if not flat or flat.Magnitude <= 0.05 then
        return nil
    end

    return flat.Unit
end

local function detectWallSlamRisk(deps, grapple, state, now, horizontalUnit, horizontalSpeed)
    local cfg = deps.CFG
    if not (deps.isWallSlamRescueEnabled and deps.isWallSlamRescueEnabled()) then
        return false, nil
    end
    if not (horizontalUnit and horizontalSpeed >= cfg.TERRAIN_WALL_SLAM_MIN_SPEED) then
        if state.LastWallSlamAt and now - state.LastWallSlamAt <= cfg.TERRAIN_WALL_SLAM_MEMORY then
            return true, state.LastWallSlamHit
        end
        return false, nil
    end

    local rootPart = grapple and grapple.RootPart
    local getWallHit = deps.getWallHit
    if not (rootPart and getWallHit) then
        return false, nil
    end

    local hit = getWallHit(rootPart.Position, horizontalUnit * cfg.TERRAIN_WALL_SLAM_PROBE_DISTANCE)
    local normal = hit and hit.Normal
    if not normal or math.abs(normal.Y) > cfg.TERRAIN_WALL_SLAM_NORMAL_Y_MAX then
        return false, nil
    end

    local flatNormal = getFlatNormalUnit(normal)
    if not flatNormal then
        return false, nil
    end

    local impactAlignment = horizontalUnit:Dot(-flatNormal)
    if impactAlignment < cfg.TERRAIN_WALL_SLAM_ALIGNMENT then
        return false, nil
    end

    state.LastWallSlamAt = now
    state.LastWallSlamHit = hit
    return true, hit
end

function TerrainSense.analyzeVoidFall(deps, grapple, previousState)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and velocity) then
        return nil
    end

    local now = deps.now()
    local floorHit = deps.getFloorHit(rootPart.Position)
    local state = previousState or {}
    if floorHit then
        state.LastSafeFloorAt = now
        state.LastSafePosition = rootPart.Position
        state.LastFloorHit = floorHit
        state.Danger = false
        state.Reason = "Grounded"
        state.UnsafeSamples = 0
        state.NoFloorBelow = false
        state.SinceSafeFloor = 0
        state.IntentGrace = false
        state.IntentGraceAllowsRescue = false
        state.LastWallSlamAt = nil
        state.LastWallSlamHit = nil
        state.WallSlamRisk = false
        state.LastEvaluatedAt = now
        return state
    end

    local sinceSafeFloor = state.LastSafeFloorAt and (now - state.LastSafeFloorAt) or math.huge
    local fallSpeed = math.max(-velocity.Y, 0)
    local recentGroundSlip = sinceSafeFloor <= cfg.TERRAIN_VOID_RECENT_GROUND_WINDOW
    local intentGrace = sinceSafeFloor <= cfg.TERRAIN_VOID_INTENT_GRACE
    local graceDropDistance = cfg.TERRAIN_VOID_GRACE_DROP_DISTANCE or cfg.TERRAIN_VOID_DROP_DISTANCE
    local graceFallSpeed = cfg.TERRAIN_VOID_GRACE_MIN_FALL_SPEED or cfg.TERRAIN_VOID_FULL_SCAN_FALL_SPEED
    local droppedBeyondGrace = state.LastSafePosition
        and rootPart.Position.Y <= state.LastSafePosition.Y - graceDropDistance
    local graceAllowsRescue = fallSpeed >= graceFallSpeed or droppedBeyondGrace == true
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local horizontalSpeed = horizontalVelocity.Magnitude
    local wallSlamScan = deps.isWallSlamRescueEnabled
        and deps.isWallSlamRescueEnabled()
        and horizontalSpeed >= cfg.TERRAIN_WALL_SLAM_MIN_SPEED
    local shouldFullScan = state.Danger == true
        or recentGroundSlip
        or fallSpeed >= cfg.TERRAIN_VOID_FULL_SCAN_FALL_SPEED
        or wallSlamScan
    if not shouldFullScan then
        state.Danger = false
        state.Reason = "AirborneLight"
        state.UnsafeSamples = 1
        state.NoFloorBelow = true
        state.SinceSafeFloor = sinceSafeFloor
        state.FallSpeed = fallSpeed
        state.HorizontalSpeed = horizontalSpeed
        state.WallSlamRisk = false
        state.IntentGrace = intentGrace and not graceAllowsRescue
        state.IntentGraceAllowsRescue = graceAllowsRescue
        state.LastEvaluatedAt = now
        return state
    end

    local horizontalUnit = horizontalSpeed > 0.05 and horizontalVelocity.Unit or nil
    local positions = {}
    if horizontalUnit then
        local sideUnit = horizontalUnit:Cross(Vector3.yAxis)
        addProbePosition(positions, rootPart.Position + horizontalUnit * cfg.TERRAIN_VOID_FORWARD_PROBE_DISTANCE)
        addProbePosition(positions, rootPart.Position - sideUnit * cfg.TERRAIN_VOID_SIDE_PROBE_DISTANCE)
        addProbePosition(positions, rootPart.Position + sideUnit * cfg.TERRAIN_VOID_SIDE_PROBE_DISTANCE)
    end
    for _, lookahead in ipairs(cfg.PANIC_RESCUE_LOOKAHEADS) do
        addProbePosition(positions, rootPart.Position + velocity * lookahead)
    end

    local unsafeSamples = 1
    for _, position in ipairs(positions) do
        if not deps.hasFloorBelow(position) then
            unsafeSamples = unsafeSamples + 1
        end
    end

    local falling = velocity.Y <= -cfg.TERRAIN_VOID_FALL_SPEED
    local droppedFromLastSafe = state.LastSafePosition
        and rootPart.Position.Y <= state.LastSafePosition.Y - cfg.TERRAIN_VOID_DROP_DISTANCE
    local terrainLost = unsafeSamples >= cfg.TERRAIN_VOID_MIN_UNSAFE_SAMPLES
    local noFloorBelow = unsafeSamples > 0
    local wallSlamRisk = detectWallSlamRisk(deps, grapple, state, now, horizontalUnit, horizontalSpeed)

    local danger = false
    local reason = "Airborne"
    local suppressForIntent = terrainLost and falling and intentGrace and not graceAllowsRescue
    if wallSlamRisk and terrainLost then
        danger = true
        reason = "WallSlamVoidRisk"
    elseif suppressForIntent then
        reason = "RecentGroundIntentGrace"
    elseif terrainLost and falling and recentGroundSlip then
        danger = true
        reason = "LedgeSlip"
    elseif terrainLost and falling and droppedFromLastSafe then
        danger = true
        reason = "TerrainVoidDrop"
    elseif terrainLost and falling and sinceSafeFloor <= cfg.TERRAIN_VOID_CONTEXT_TTL then
        danger = true
        reason = "TerrainNoFloor"
    end

    state.Danger = danger
    state.Reason = reason
    state.UnsafeSamples = unsafeSamples
    state.NoFloorBelow = noFloorBelow
    state.SinceSafeFloor = sinceSafeFloor
    state.FallSpeed = fallSpeed
    state.HorizontalSpeed = horizontalSpeed
    state.WallSlamRisk = wallSlamRisk
    state.IntentGrace = suppressForIntent
    state.IntentGraceAllowsRescue = graceAllowsRescue
    state.LastEvaluatedAt = now
    return state
end

return TerrainSense
