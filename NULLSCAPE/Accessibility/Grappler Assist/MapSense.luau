--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Map Sense
--  Builds a lightweight map of rescue anchors for emergency/void grapples.
-- ]]

local MapSense = {
    Anchors = {},
    LastScanAt = 0,
    LastWorkspace = nil,
}

local TARGET_PRIORITY = {
    Bell = -120,
    JumpPad = -70,
    GrapplePoint = -42,
    TriaOrb = -18,
}

local function getNow(deps)
    if deps.now then
        return deps.now()
    end

    return os.clock()
end

local function getCandidateName(deps, instance, part)
    if instance and deps.VALID_TARGETS[instance.Name] then
        return instance.Name
    end
    if part and deps.VALID_TARGETS[part.Name] then
        return part.Name
    end

    return nil
end

local function getFlatUnit(vector)
    local flat = vector and Vector3.new(vector.X, 0, vector.Z)
    if not flat or flat.Magnitude <= 0.05 then
        return nil
    end

    return flat.Unit
end

local function isTargetHit(result, targetInstance, targetPart)
    if not result or not result.Instance then
        return false
    end

    return result.Instance == targetPart or result.Instance:IsDescendantOf(targetInstance)
end

local function addAnchor(deps, anchors, seen, instance)
    if not (instance and instance.Parent) or seen[instance] then
        return
    end

    local part = deps.getTargetPart(instance)
    local name = getCandidateName(deps, instance, part)
    if not (part and name) then
        return
    end

    seen[instance] = true
    table.insert(anchors, {
        Instance = instance,
        Part = part,
        Name = name,
    })
end

local function scanChildrenBudgeted(deps, anchors, seen, roots, maxDescendants, maxAnchors)
    local stack = {}
    for _, root in ipairs(roots) do
        table.insert(stack, root)
    end

    local scanned = 0
    while #stack > 0 and scanned < maxDescendants and #anchors < maxAnchors do
        local current = table.remove(stack)
        if current and current.Parent then
            scanned = scanned + 1
            addAnchor(deps, anchors, seen, current)
            if #anchors >= maxAnchors then
                break
            end

            local children = current:GetChildren()
            for i = #children, 1, -1 do
                table.insert(stack, children[i])
            end
        end
    end
end

function MapSense.refresh(deps, force)
    local workspace = deps.Workspace
    if not workspace then
        table.clear(MapSense.Anchors)
        return MapSense.Anchors
    end

    local now = getNow(deps)
    local cfg = deps.CFG
    local interval = cfg.MAP_ANCHOR_SCAN_INTERVAL or 1.25
    if not force and MapSense.LastWorkspace == workspace and now - MapSense.LastScanAt < interval then
        return MapSense.Anchors
    end

    MapSense.LastWorkspace = workspace
    MapSense.LastScanAt = now
    table.clear(MapSense.Anchors)

    local seen = {}
    local anchors = MapSense.Anchors
    local maxDescendants = cfg.MAP_ANCHOR_SCAN_MAX_DESCENDANTS or 9000
    local maxAnchors = cfg.MAP_ANCHOR_MAX_CANDIDATES or 320

    local workspaceChildren = workspace:GetChildren()
    for _, child in ipairs(workspaceChildren) do
        addAnchor(deps, anchors, seen, child)
        if #anchors >= maxAnchors then
            break
        end
    end

    if #anchors < maxAnchors then
        scanChildrenBudgeted(deps, anchors, seen, workspaceChildren, maxDescendants, maxAnchors)
    end

    return anchors
end

local function getSwingClearanceScore(deps, grapple, candidate, position, anchorUnit)
    local cfg = deps.CFG
    local workspace = deps.Workspace
    local rootPart = grapple and grapple.RootPart
    if not (workspace and rootPart and anchorUnit) then
        return 0
    end

    local side = anchorUnit:Cross(Vector3.yAxis)
    if side.Magnitude <= 0.05 then
        return 0
    end

    side = side.Unit
    local function isOffsetClear(sideSign)
        local offset = side * (cfg.MAP_ANCHOR_SWING_CLEARANCE or 7) * sideSign
        local origin = rootPart.Position + offset
        local direction = position + offset - origin
        local result = workspace:Raycast(origin, direction, grapple.grappleParams)
        return not result or isTargetHit(result, candidate.Instance, candidate.Part)
    end

    local clearRays = (isOffsetClear(-1) and 1 or 0) + (isOffsetClear(1) and 1 or 0)
    if clearRays >= 2 then
        return cfg.MAP_ANCHOR_SWING_CLEARANCE_BONUS or -18
    elseif clearRays == 1 then
        return 0
    end

    return cfg.MAP_ANCHOR_SWING_NARROW_PENALTY or 55
end

local function getAnchorSurfaceScore(deps, result)
    local cfg = deps.CFG
    local normal = result and result.Normal
    if not normal then
        return 0
    end

    if normal.Y <= -0.25 then
        return cfg.MAP_ANCHOR_SWING_UNDERSIDE_PENALTY or 105
    elseif math.abs(normal.Y) <= 0.45 then
        return cfg.MAP_ANCHOR_SWING_WALL_BONUS or -14
    end

    return 0
end

local function getSwingRoomScore(deps, grapple, candidate, position, distance, result)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and velocity) then
        return 0
    end

    local anchorOffset = position - rootPart.Position
    local anchorUnit = getFlatUnit(anchorOffset)
    if not anchorUnit then
        return 0
    end

    local velocityUnit = getFlatUnit(velocity)
    local score = 0
    local flatDistance = Vector3.new(anchorOffset.X, 0, anchorOffset.Z).Magnitude
    local flatMin = cfg.MAP_ANCHOR_SWING_FLAT_MIN or 28
    local flatIdeal = cfg.MAP_ANCHOR_SWING_FLAT_IDEAL or 58
    if flatDistance < flatMin then
        score = score + (flatMin - flatDistance) * (cfg.MAP_ANCHOR_SWING_FLAT_WEIGHT or 1.15)
    else
        score = score + math.abs(flatDistance - flatIdeal) * (cfg.MAP_ANCHOR_SWING_FLAT_WEIGHT or 1.15) * 0.16
    end

    local verticalRatio = math.abs(anchorOffset.Y) / math.max(flatDistance, 1)
    local maxVerticalRatio = cfg.MAP_ANCHOR_SWING_VERTICAL_RATIO_MAX or 1.35
    if verticalRatio > maxVerticalRatio then
        score = score + (verticalRatio - maxVerticalRatio) * (cfg.MAP_ANCHOR_SWING_VERTICAL_RATIO_PENALTY or 82)
    end

    local minDistance = cfg.MAP_ANCHOR_SWING_MIN_DISTANCE or 38
    local idealDistance = cfg.MAP_ANCHOR_SWING_IDEAL_DISTANCE or 72
    if distance < minDistance then
        score = score + (minDistance - distance) * (cfg.MAP_ANCHOR_SWING_DISTANCE_WEIGHT or 0.42)
    else
        score = score + math.abs(distance - idealDistance) * (cfg.MAP_ANCHOR_SWING_DISTANCE_WEIGHT or 0.42) * 0.25
    end

    if velocityUnit then
        local forwardDot = anchorUnit:Dot(velocityUnit)
        if forwardDot >= 0.18 then
            score = score + (cfg.MAP_ANCHOR_SWING_FORWARD_BONUS or -24) * math.min(forwardDot, 1)
        elseif forwardDot < -0.15 then
            score = score + (cfg.MAP_ANCHOR_SWING_BEHIND_PENALTY or 70) * math.min(math.abs(forwardDot), 1)
        end

        local lateral = math.abs(anchorOffset:Dot(velocityUnit:Cross(Vector3.yAxis).Unit))
        local lateralMin = cfg.MAP_ANCHOR_SWING_LATERAL_MIN or 16
        local lateralIdeal = cfg.MAP_ANCHOR_SWING_LATERAL_IDEAL or 42
        if lateral < lateralMin then
            score = score + (lateralMin - lateral) * (cfg.MAP_ANCHOR_SWING_LATERAL_WEIGHT or 0.65)
        else
            score = score + math.abs(lateral - lateralIdeal) * (cfg.MAP_ANCHOR_SWING_LATERAL_WEIGHT or 0.65) * 0.18
        end
    end

    return score
        + getAnchorSurfaceScore(deps, result)
        + getSwingClearanceScore(deps, grapple, candidate, position, anchorUnit)
end

local function getAnchorScore(deps, grapple, candidate, position, distance, screenScore, result)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return math.huge
    end

    local verticalOffset = position.Y - rootPart.Position.Y
    local score = (TARGET_PRIORITY[candidate.Name] or 0)
        + distance * (cfg.MAP_ANCHOR_DISTANCE_WEIGHT or 0.03)
        + (screenScore or 0) * (cfg.MAP_ANCHOR_SCREEN_WEIGHT or 36)

    if verticalOffset >= -4 then
        score = score + (cfg.MAP_ANCHOR_UPWARD_BONUS or -62)
    else
        score = score + (cfg.MAP_ANCHOR_LOW_PENALTY or 135)
    end

    if candidate.Name == "Bell" then
        score = score - 28
    elseif candidate.Name == "JumpPad" and verticalOffset >= -8 then
        score = score - 22
    elseif candidate.Name == "GrapplePoint" and verticalOffset >= -16 then
        score = score - 14
    end

    return score + getSwingRoomScore(deps, grapple, candidate, position, distance, result)
end

function MapSense.findBestVoidAnchor(deps, grapple, options)
    local camera = deps.Workspace and deps.Workspace.CurrentCamera
    local rootPart = grapple and grapple.RootPart
    if not (camera and rootPart) then
        return nil
    end

    local driveMode = typeof(options) == "table" and options.driveMode == true
    local returnDecision = typeof(options) == "table" and options.returnDecision == true
    local anchors = MapSense.refresh(deps, false)
    if #anchors == 0 then
        return nil
    end

    local maxRange = deps.getAssistRange(grapple, driveMode)
    local viewportSize = camera.ViewportSize
    local screenAnchor = viewportSize * 0.5
    local bestResult = nil
    local bestInstance = nil
    local bestName = nil
    local bestDistance = nil
    local bestScreenScore = nil
    local bestScore = math.huge

    for _, candidate in ipairs(anchors) do
        local part = candidate.Part
        if part and part.Parent then
            local position = part.Position
            local viewportPoint, onScreen = camera:WorldToViewportPoint(position)
            local screenScore = 0.75
            if onScreen then
                screenScore = (Vector2.new(viewportPoint.X, viewportPoint.Y) - screenAnchor).Magnitude / math.max(viewportSize.X, viewportSize.Y)
            end

            local result, distance = deps.isLineClear(grapple, candidate.Instance, part, position, maxRange)
            if result and deps.isUsableResult(grapple, result) and deps.isPathSafeForHitbox(grapple, candidate.Instance, part, position, maxRange) then
                local score = getAnchorScore(deps, grapple, candidate, position, distance, screenScore, result)
                if score < bestScore then
                    bestResult = result
                    bestInstance = candidate.Instance
                    bestName = candidate.Name
                    bestDistance = distance
                    bestScreenScore = screenScore
                    bestScore = score
                end
            end
        end
    end

    if returnDecision then
        return bestResult and {
            Result = bestResult,
            Instance = bestInstance,
            Name = bestName,
            Distance = bestDistance,
            ScreenScore = bestScreenScore,
            Score = bestScore,
            Reason = "MapVoidAnchor",
        } or nil
    end

    return bestResult
end

function MapSense.clear()
    table.clear(MapSense.Anchors)
    MapSense.LastWorkspace = nil
    MapSense.LastScanAt = 0
end

return MapSense
