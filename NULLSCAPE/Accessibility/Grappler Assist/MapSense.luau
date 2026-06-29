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

local function getAnchorSamplePositions(part, preferredPosition)
    local positions = {}
    local function add(position)
        if typeof(position) ~= "Vector3" then
            return
        end
        for _, existing in ipairs(positions) do
            if (existing - position).Magnitude <= 0.1 then
                return
            end
        end
        table.insert(positions, position)
    end

    add(preferredPosition)
    if not (part and part:IsA("BasePart")) then
        return positions
    end

    local half = part.Size * 0.5
    local cframe = part.CFrame
    add(part.Position)
    local samples = {
        Vector3.new(half.X, 0, 0),
        Vector3.new(-half.X, 0, 0),
        Vector3.new(0, half.Y, 0),
        Vector3.new(0, -half.Y, 0),
        Vector3.new(0, 0, half.Z),
        Vector3.new(0, 0, -half.Z),
        Vector3.new(half.X, half.Y, half.Z),
        Vector3.new(half.X, half.Y, -half.Z),
        Vector3.new(-half.X, half.Y, half.Z),
        Vector3.new(-half.X, half.Y, -half.Z),
    }

    for _, localPoint in ipairs(samples) do
        add(cframe:PointToWorldSpace(localPoint))
    end

    return positions
end

local function findAnchorLineClear(deps, grapple, candidate, preferredPosition, maxRange)
    for _, position in ipairs(getAnchorSamplePositions(candidate.Part, preferredPosition)) do
        local result, distance = deps.isLineClear(grapple, candidate.Instance, candidate.Part, position, maxRange)
        if result and deps.isUsableResult(grapple, result) then
            return result, distance, position
        end
    end

    return nil, nil, preferredPosition
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

local function getAnchorSurfaceScore(deps, grapple, position, result, options)
    local cfg = deps.CFG
    local normal = result and result.Normal
    if not normal then
        return 0
    end

    if normal.Y <= -0.25 then
        local allowUnderside = typeof(options) == "table" and options.allowUnderside == true
        local rootPart = grapple and grapple.RootPart
        local verticalOffset = rootPart and (position.Y - rootPart.Position.Y) or -math.huge
        if allowUnderside and verticalOffset >= (cfg.MAP_ANCHOR_VOID_UNDERSIDE_MIN_VERTICAL or 12) then
            return cfg.MAP_ANCHOR_VOID_UNDERSIDE_BONUS or -8
        end

        return cfg.MAP_ANCHOR_SWING_UNDERSIDE_PENALTY or 105
    elseif math.abs(normal.Y) <= 0.45 then
        return cfg.MAP_ANCHOR_SWING_WALL_BONUS or -14
    end

    return 0
end

local function getSwingRoomScore(deps, grapple, candidate, position, distance, result, options)
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
        + getAnchorSurfaceScore(deps, grapple, position, result, options)
        + getSwingClearanceScore(deps, grapple, candidate, position, anchorUnit)
end

local function addBreakdown(breakdown, name, value)
    value = tonumber(value) or 0
    breakdown.Total = (breakdown.Total or 0) + value
    breakdown[name] = value
    return value
end

local function getMomentumRoomScore(deps, grapple, position)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and velocity) then
        return 0, "NoMomentum"
    end

    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    local speed = horizontal.Magnitude
    if speed < (cfg.MAP_ANCHOR_OPT_MIN_MOMENTUM_SPEED or 28) then
        return cfg.MAP_ANCHOR_OPT_LOW_MOMENTUM_PENALTY or 18, "LowMomentum"
    end

    local targetOffset = position - rootPart.Position
    local targetFlat = Vector3.new(targetOffset.X, 0, targetOffset.Z)
    if targetFlat.Magnitude <= 0.05 then
        return cfg.MAP_ANCHOR_OPT_NO_FLAT_ROOM_PENALTY or 55, "NoFlatRoom"
    end

    local velocityUnit = horizontal.Unit
    local targetUnit = targetFlat.Unit
    local forwardDot = targetUnit:Dot(velocityUnit)
    local lateral = math.abs(targetFlat:Dot(velocityUnit:Cross(Vector3.yAxis).Unit))
    local flatDistance = targetFlat.Magnitude
    local idealLead = math.clamp(speed * (cfg.MAP_ANCHOR_OPT_LEAD_TIME or 0.42), 28, 96)
    local leadPenalty = math.abs(flatDistance - idealLead) * (cfg.MAP_ANCHOR_OPT_LEAD_WEIGHT or 0.22)
    local lateralMin = cfg.MAP_ANCHOR_OPT_LATERAL_MIN or 18
    local lateralIdeal = cfg.MAP_ANCHOR_OPT_LATERAL_IDEAL or 48
    local lateralPenalty
    if lateral < lateralMin then
        lateralPenalty = (lateralMin - lateral) * (cfg.MAP_ANCHOR_OPT_LATERAL_WEIGHT or 0.74)
    else
        lateralPenalty = math.abs(lateral - lateralIdeal) * (cfg.MAP_ANCHOR_OPT_LATERAL_WEIGHT or 0.74) * 0.18
    end

    local forwardBonus = 0
    if forwardDot > 0.15 then
        forwardBonus = (cfg.MAP_ANCHOR_OPT_FORWARD_BONUS or -22) * math.clamp(forwardDot, 0, 1)
    elseif forwardDot < -0.25 then
        forwardBonus = (cfg.MAP_ANCHOR_OPT_BACKWARD_PENALTY or 62) * math.clamp(math.abs(forwardDot), 0, 1)
    end

    return leadPenalty + lateralPenalty + forwardBonus, "MomentumRoom"
end

local function getArcApexScore(deps, grapple, position)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return 0, "NoApex"
    end

    local verticalOffset = position.Y - rootPart.Position.Y
    local idealMin = cfg.MAP_ANCHOR_OPT_VERTICAL_MIN or 8
    local idealMax = cfg.MAP_ANCHOR_OPT_VERTICAL_MAX or 54
    if verticalOffset < idealMin then
        return (idealMin - verticalOffset) * (cfg.MAP_ANCHOR_OPT_LOW_APEX_WEIGHT or 1.15), "LowApex"
    elseif verticalOffset > idealMax then
        return (verticalOffset - idealMax) * (cfg.MAP_ANCHOR_OPT_HIGH_APEX_WEIGHT or 0.55), "HighApex"
    end

    return cfg.MAP_ANCHOR_OPT_APEX_BONUS or -18, "GoodApex"
end

local function getPathWidthScore(deps, grapple, candidate, position)
    local cfg = deps.CFG
    local workspace = deps.Workspace
    local rootPart = grapple and grapple.RootPart
    if not (workspace and rootPart and candidate and candidate.Part) then
        return 0, "NoPathWidth"
    end

    local targetOffset = position - rootPart.Position
    local targetUnit = getFlatUnit(targetOffset)
    if not targetUnit then
        return cfg.MAP_ANCHOR_OPT_NO_FLAT_ROOM_PENALTY or 55, "NoPathWidth"
    end

    local side = targetUnit:Cross(Vector3.yAxis)
    if side.Magnitude <= 0.05 then
        return 0, "NoSide"
    end
    side = side.Unit

    local clear = 0
    local offsets = {
        -(cfg.MAP_ANCHOR_OPT_PATH_WIDTH or 10),
        0,
        cfg.MAP_ANCHOR_OPT_PATH_WIDTH or 10,
    }
    for _, offsetValue in ipairs(offsets) do
        local offset = side * offsetValue
        local origin = rootPart.Position + offset + Vector3.new(0, 2, 0)
        local direction = position + offset - origin
        local result = workspace:Raycast(origin, direction, grapple.grappleParams)
        if not result or isTargetHit(result, candidate.Instance, candidate.Part) then
            clear = clear + 1
        end
    end

    if clear >= 3 then
        return cfg.MAP_ANCHOR_OPT_WIDE_PATH_BONUS or -24, "WidePath"
    elseif clear == 2 then
        return cfg.MAP_ANCHOR_OPT_PARTIAL_PATH_PENALTY or 10, "PartialPath"
    end

    return cfg.MAP_ANCHOR_OPT_NARROW_PATH_PENALTY or 80, "NarrowPath"
end

local function getAnchorScore(deps, grapple, candidate, position, distance, screenScore, result, routeThreat, options)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return math.huge, {
            Total = math.huge,
            Reason = "NoRoot",
        }
    end

    local verticalOffset = position.Y - rootPart.Position.Y
    local breakdown = {
        Total = 0,
        Name = candidate.Name,
    }
    addBreakdown(breakdown, "Target", TARGET_PRIORITY[candidate.Name] or 0)
    addBreakdown(breakdown, "Distance", distance * (cfg.MAP_ANCHOR_DISTANCE_WEIGHT or 0.03))
    addBreakdown(breakdown, "Screen", (screenScore or 0) * (cfg.MAP_ANCHOR_SCREEN_WEIGHT or 36))

    if verticalOffset >= -4 then
        addBreakdown(breakdown, "Vertical", cfg.MAP_ANCHOR_UPWARD_BONUS or -62)
    else
        addBreakdown(breakdown, "Vertical", cfg.MAP_ANCHOR_LOW_PENALTY or 135)
    end

    if candidate.Name == "Bell" then
        addBreakdown(breakdown, "Special", -28)
    elseif candidate.Name == "JumpPad" and verticalOffset >= -8 then
        addBreakdown(breakdown, "Special", -22)
    elseif candidate.Name == "GrapplePoint" and verticalOffset >= -16 then
        addBreakdown(breakdown, "Special", -14)
    end

    if routeThreat or deps.getRouteThreat then
        local threat = routeThreat or deps.getRouteThreat(rootPart.Position, position)
        local threatScore = tonumber(threat and threat.Score) or 0
        if threatScore > 0 then
            addBreakdown(breakdown, "Threat", threatScore)
        end
    end

    addBreakdown(breakdown, "SwingRoom", getSwingRoomScore(deps, grapple, candidate, position, distance, result, options))
    local momentumScore, momentumReason = getMomentumRoomScore(deps, grapple, position)
    addBreakdown(breakdown, "MomentumRoom", momentumScore)
    local apexScore, apexReason = getArcApexScore(deps, grapple, position)
    addBreakdown(breakdown, "Apex", apexScore)
    local pathWidthScore, pathReason = getPathWidthScore(deps, grapple, candidate, position)
    addBreakdown(breakdown, "PathWidth", pathWidthScore)
    breakdown.Reason = table.concat({
        tostring(momentumReason),
        tostring(apexReason),
        tostring(pathReason),
    }, "/")

    return breakdown.Total, breakdown
end

function MapSense.findBestVoidAnchor(deps, grapple, options)
    local camera = deps.Workspace and deps.Workspace.CurrentCamera
    local rootPart = grapple and grapple.RootPart
    if not (camera and rootPart) then
        return nil
    end

    local driveMode = typeof(options) == "table" and options.driveMode == true
    local returnDecision = typeof(options) == "table" and options.returnDecision == true
    local allowUnderside = not (typeof(options) == "table") or options.allowUnderside ~= false
    local anchors = MapSense.refresh(deps, false)
    if #anchors == 0 then
        return nil
    end

    local maxRange = deps.getAssistRange(grapple, driveMode)
    local detectorRadius = typeof(options) == "table" and tonumber(options.detectorRadius) or nil
    detectorRadius = detectorRadius or (deps.CFG.MAP_ANCHOR_VOID_DETECTOR_RADIUS or maxRange)
    local viewportSize = camera.ViewportSize
    local screenAnchor = viewportSize * 0.5
    local bestResult = nil
    local bestInstance = nil
    local bestName = nil
    local bestDistance = nil
    local bestScreenScore = nil
    local bestScore = math.huge
    local bestThreat = nil
    local bestBreakdown = nil
    local evaluated = 0

    for _, candidate in ipairs(anchors) do
        local part = candidate.Part
        if part and part.Parent then
            evaluated = evaluated + 1
            local position = part.Position
            local roughDistance = (position - rootPart.Position).Magnitude
            if roughDistance > detectorRadius then
                continue
            end

            local result, distance, hitPosition = findAnchorLineClear(deps, grapple, candidate, position, maxRange)
            local scorePosition = hitPosition or position
            local viewportPoint, onScreen = camera:WorldToViewportPoint(scorePosition)
            local screenScore = 0.75
            if onScreen then
                screenScore = (Vector2.new(viewportPoint.X, viewportPoint.Y) - screenAnchor).Magnitude / math.max(viewportSize.X, viewportSize.Y)
            end

            if result and deps.isUsableResult(grapple, result) and deps.isPathSafeForHitbox(grapple, candidate.Instance, part, scorePosition, maxRange) then
                local threat = deps.getRouteThreat and deps.getRouteThreat(rootPart.Position, scorePosition) or nil
                local score, breakdown = getAnchorScore(
                    deps,
                    grapple,
                    candidate,
                    scorePosition,
                    distance,
                    screenScore,
                    result,
                    threat,
                    {
                        allowUnderside = allowUnderside,
                    }
                )
                if score < bestScore then
                    bestResult = result
                    bestInstance = candidate.Instance
                    bestName = candidate.Name
                    bestDistance = distance
                    bestScreenScore = screenScore
                    bestScore = score
                    bestThreat = threat
                    bestBreakdown = breakdown
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
            Threat = bestThreat,
            Breakdown = bestBreakdown,
            Evaluated = evaluated,
            Reason = bestBreakdown and ("OptimizedAnchor:" .. tostring(bestBreakdown.Reason)) or "MapVoidAnchor",
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
