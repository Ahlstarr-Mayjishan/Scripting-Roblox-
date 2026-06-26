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

return TerrainSense
