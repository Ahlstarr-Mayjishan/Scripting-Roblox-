--!nocheck
--[[
 NULLSCAPE - Grappler Assist Threat Model
 Cheap cached scoring for route, landing, and nearby enemy hazards.
]]

local ThreatModel = {}

local ENEMY_NAMES = {
    Springer = true,
    Skinwalker = true,
    Husk = true,
    Slicer = true,
    Telefragger = true,
}

local HAZARD_NAMES = {
    SpringerShockwave = true,
    DemonShockwave = true,
    CloudWave = true,
    Kill = true,
    Hit = true,
    CorrodedMetal = true,
    Tripmine = true,
    GoldTripmine = true,
}

local state = {
    LastScanAt = 0,
    Workspace = nil,
    Hazards = {},
    LastThreat = nil,
}

local function getNow(deps)
    return (deps and deps.now and deps.now()) or time()
end

local function getPart(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function isHazardInstance(instance)
    if not instance then
        return false
    end
    if HAZARD_NAMES[instance.Name] or ENEMY_NAMES[instance.Name] then
        return true
    end
    local parent = instance.Parent
    while parent do
        if ENEMY_NAMES[parent.Name] then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local function addHazard(hazards, seen, instance)
    if not (instance and instance.Parent) or seen[instance] or not isHazardInstance(instance) then
        return
    end

    local part = getPart(instance)
    if not part then
        return
    end

    seen[instance] = true
    table.insert(hazards, {
        Instance = instance,
        Part = part,
        Name = instance.Name,
    })
end

local function addTaggedHazards(deps, hazards, seen, maxHazards)
    local collectionService = deps and deps.CollectionService
    if not (collectionService and collectionService.GetTagged) then
        return
    end

    local tags = deps.ThreatTags or {
        "Springer",
        "Skinwalker",
        "Husk",
        "Slicer",
        "Telefragger",
        "SpringerShockwave",
        "DemonShockwave",
        "CloudWave",
        "Tripmine",
        "GoldTripmine",
        "CorrodedMetal",
    }

    for _, tag in ipairs(tags) do
        local success, tagged = pcall(function()
            return collectionService:GetTagged(tag)
        end)
        if success and tagged then
            for _, instance in ipairs(tagged) do
                addHazard(hazards, seen, instance)
                if #hazards >= maxHazards then
                    return
                end
            end
        end
    end
end

local function addRoot(roots, seenRoots, root)
    if root and root.Parent and not seenRoots[root] then
        seenRoots[root] = true
        table.insert(roots, root)
    end
end

local function buildThreatRoots(workspace)
    local roots = {}
    local seenRoots = {}
    addRoot(roots, seenRoots, workspace:FindFirstChild("Enemies"))
    addRoot(roots, seenRoots, workspace:FindFirstChild("Gifts"))
    addRoot(roots, seenRoots, workspace:FindFirstChild("Tripmines"))
    addRoot(roots, seenRoots, workspace:FindFirstChild("CurrentRooms"))
    addRoot(roots, seenRoots, workspace:FindFirstChild("Hazards"))

    for _, child in ipairs(workspace:GetChildren()) do
        if isHazardInstance(child) then
            addRoot(roots, seenRoots, child)
        end
    end

    return roots
end

function ThreatModel.refresh(deps, force)
    deps = deps or {}
    local workspace = deps.Workspace
    if not workspace then
        table.clear(state.Hazards)
        return state.Hazards
    end

    local now = getNow(deps)
    local interval = tonumber(deps.ScanInterval) or 0.65
    if not force and state.Workspace == workspace and now - (state.LastScanAt or 0) < interval then
        return state.Hazards
    end

    state.Workspace = workspace
    state.LastScanAt = now
    table.clear(state.Hazards)

    local seen = {}
    local maxDescendants = tonumber(deps.MaxDescendants) or 650
    local maxHazards = tonumber(deps.MaxHazards) or 120
    addTaggedHazards(deps, state.Hazards, seen, maxHazards)

    local roots = buildThreatRoots(workspace)
    local scanned = 0
    local stack = {}
    for _, root in ipairs(roots) do
        table.insert(stack, root)
    end

    while #stack > 0 and scanned < maxDescendants and #state.Hazards < maxHazards do
        local current = table.remove(stack)
        if current and current.Parent then
            scanned += 1
            addHazard(state.Hazards, seen, current)
            local children = current:GetChildren()
            for i = #children, 1, -1 do
                table.insert(stack, children[i])
            end
        end
    end

    return state.Hazards
end

local function distancePointToSegment(point, a, b)
    local ab = b - a
    local lengthSquared = ab:Dot(ab)
    if lengthSquared <= 0.001 then
        return (point - a).Magnitude
    end
    local t = math.clamp((point - a):Dot(ab) / lengthSquared, 0, 1)
    return (point - (a + ab * t)).Magnitude
end

local function getHazardRadius(hazard)
    local name = hazard and hazard.Name or ""
    if name == "SpringerShockwave" or name == "DemonShockwave" or name == "CloudWave" then
        return 18
    elseif name == "Telefragger" then
        return 22
    elseif name == "Slicer" or name == "Kill" then
        return 12
    elseif name == "Tripmine" or name == "GoldTripmine" then
        return 5
    elseif name == "CorrodedMetal" then
        return 7
    end
    return 10
end

local function getHazardWeight(hazard)
    local name = hazard and hazard.Name or ""
    if name == "Telefragger" then
        return 74
    elseif name == "SpringerShockwave" or name == "DemonShockwave" or name == "CloudWave" then
        return 86
    elseif name == "Slicer" or name == "Kill" then
        return 70
    elseif name == "Tripmine" or name == "GoldTripmine" then
        return 58
    elseif name == "CorrodedMetal" then
        return 42
    end
    return 32
end

function ThreatModel.getRouteThreat(deps, startPosition, endPosition, options)
    deps = deps or {}
    options = options or {}
    if typeof(startPosition) ~= "Vector3" or typeof(endPosition) ~= "Vector3" then
        return {
            Score = 0,
            Reason = "NoRoute",
        }
    end

    local hazards = ThreatModel.refresh(deps, false)
    local maxDistance = tonumber(options.MaxDistance) or 38
    local score = 0
    local nearest = math.huge
    local nearestName = nil

    for _, hazard in ipairs(hazards) do
        local part = hazard.Part
        if part and part.Parent then
            local radius = getHazardRadius(hazard)
            local distance = distancePointToSegment(part.Position, startPosition, endPosition)
            if distance <= math.max(maxDistance, radius) then
                local weight = getHazardWeight(hazard)
                local closeness = 1 - math.clamp(distance / math.max(radius, 1), 0, 1)
                score += weight * (0.35 + closeness * 0.65)
                if distance < nearest then
                    nearest = distance
                    nearestName = hazard.Name
                end
            end
        end
    end

    local result = {
        Score = score,
        Reason = nearestName and ("RouteThreat:" .. tostring(nearestName)) or "RouteClear",
        NearestDistance = nearest,
        NearestName = nearestName,
    }
    state.LastThreat = result
    return result
end

function ThreatModel.getLandingThreat(_deps, hitResult)
    if not (hitResult and hitResult.Instance) then
        return {
            Score = 0,
            Reason = "NoLanding",
        }
    end

    local instance = hitResult.Instance
    local name = instance.Name
    local score = 0
    local reason = "LandingClear"

    if name == "KillVoid" then
        score = 999
        reason = "KillVoid"
    elseif name == "CorrodedMetal" then
        score = 80
        reason = "CorrodedMetal"
    elseif name == "Tripmine" or name == "GoldTripmine" then
        score = 120
        reason = name
    elseif hitResult.Normal and hitResult.Normal.Y < 0.42 then
        score = 46
        reason = "BadLandingNormal"
    end

    return {
        Score = score,
        Reason = reason,
        Instance = instance,
    }
end

function ThreatModel.getNearbyEnemyThreat(deps, position, radius)
    deps = deps or {}
    if typeof(position) ~= "Vector3" then
        return {
            Score = 0,
            Reason = "NoPosition",
        }
    end

    radius = tonumber(radius) or 40
    local hazards = ThreatModel.refresh(deps, false)
    local score = 0
    local nearestName = nil
    local nearestDistance = math.huge
    for _, hazard in ipairs(hazards) do
        local part = hazard.Part
        if part and part.Parent then
            local distance = (part.Position - position).Magnitude
            if distance <= radius then
                score += getHazardWeight(hazard) * (1 - math.clamp(distance / radius, 0, 1))
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestName = hazard.Name
                end
            end
        end
    end

    return {
        Score = score,
        Reason = nearestName and ("NearbyThreat:" .. tostring(nearestName)) or "NearbyClear",
        NearestName = nearestName,
        NearestDistance = nearestDistance,
    }
end

function ThreatModel.snapshot()
    local threat = state.LastThreat
    if not threat then
        return "Threat:pending"
    end
    return tostring(threat.Reason) .. ":" .. string.format("%.1f", tonumber(threat.Score) or 0)
end

function ThreatModel.clear()
    table.clear(state.Hazards)
    state.LastScanAt = 0
    state.Workspace = nil
    state.LastThreat = nil
end

return ThreatModel
