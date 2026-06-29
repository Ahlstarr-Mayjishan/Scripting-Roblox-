--!nocheck
--[[
 NULLSCAPE - Grappler Assist Map Model
 Chunk-based local map cache for landing, void, and anchor decisions.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MapModel = {
    Running = false,
    Chunks = {},
    LastStepAt = 0,
    LastCenterKey = nil,
    LastInRound = nil,
    Debug3DEnabled = false,
    Debug3DFolder = nil,
    Debug3DGui = nil,
    Debug3DViewport = nil,
    Debug3DWorld = nil,
    Debug3DCamera = nil,
    LastDebug3DRenderAt = 0,
}

local DEFAULTS = {
    CHUNK_SIZE = 64,
    ACTIVE_RADIUS = 2,
    KEEP_RADIUS = 4,
    STEP_INTERVAL = 0.28,
    RESCAN_INTERVAL = 2.5,
    MOVE_REFRESH_DISTANCE = 20,
    SCAN_HEIGHT = 260,
    FLOOR_DEPTH = 280,
    FLOOR_NORMAL_Y = 0.42,
    KILL_MARGIN = 12,
    MAX_PARTS_PER_CHUNK = 90,
    MAX_ANCHORS_PER_CHUNK = 36,
    DEBUG_3D_RENDER_INTERVAL = 0.24,
    DEBUG_3D_MAX_MARKERS = 160,
    DEBUG_3D_CHUNK_HEIGHT = 4,
    DEBUG_3D_MINIMAP_SIZE = 220,
    DEBUG_3D_MINIMAP_SCALE = 0.055,
    DEBUG_3D_MINIMAP_CAMERA_HEIGHT = 18,
}

local ANCHOR_NAMES = {
    GrapplePoint = true,
    JumpPad = true,
    Bell = true,
    TriaOrb = true,
}

local function now()
    return os.clock()
end

local function getCfg(deps, key)
    local cfg = deps and deps.CFG
    return (cfg and cfg["MAP_MODEL_" .. key]) or DEFAULTS[key]
end

local function getInRound()
    local inRound = ReplicatedStorage:FindFirstChild("InRound")
    if inRound and inRound:IsA("BoolValue") then
        return inRound.Value
    end

    return Workspace:FindFirstChild("CurrentRooms") ~= nil or Workspace:FindFirstChild("Enemies") ~= nil
end

local function getKillY(deps)
    if deps and deps.getVoidKillPlaneY then
        local killY = deps.getVoidKillPlaneY()
        if killY then
            return killY
        end
    end

    local killVoid = Workspace:FindFirstChild("KillVoid")
    if killVoid and killVoid:IsA("BasePart") then
        return killVoid.Position.Y
    end

    return tonumber(Workspace.FallenPartsDestroyHeight)
end

local function getChunkCoord(value, chunkSize)
    return math.floor((value / chunkSize) + 0.5)
end

local function getChunkKey(cx, cz)
    return tostring(cx) .. ":" .. tostring(cz)
end

local function getChunkCenter(cx, cz, chunkSize, y)
    return Vector3.new(cx * chunkSize, y, cz * chunkSize)
end

local function clearChildren(parent)
    if not parent then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        child:Destroy()
    end
end

local function isLegacy2DDebugGui(gui)
    if not (gui and gui:IsA("ScreenGui")) then
        return false
    end

    local name = string.lower(tostring(gui.Name or ""))
    if name == "grapplemapmodeldebug" or name == "nullscape_grapplemapmodeldebug" then
        return true
    end
    if name == "nullscape_mapmodeldebug" or name == "nullscape_mapmodelminimap" then
        return true
    end

    return string.find(name, "mapmodel", 1, true) ~= nil
        and (string.find(name, "mini", 1, true) ~= nil or string.find(name, "debug", 1, true) ~= nil)
        and (string.find(name, "nullscape", 1, true) ~= nil or string.find(name, "grapple", 1, true) ~= nil)
end

local function cleanupLegacy2DDebugGui()
    local containers = {}
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(containers, playerGui)
    end

    local success, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if success and coreGui then
        table.insert(containers, coreGui)
    end

    for _, container in ipairs(containers) do
        for _, child in ipairs(container:GetChildren()) do
            if isLegacy2DDebugGui(child) then
                child:Destroy()
            end
        end
    end
end

local function makeDebugPart(parent, name, cframe, size, color, transparency)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = transparency or 0.5
    part.Size = size
    part.CFrame = cframe
    part.Parent = parent
    return part
end

local function ensureDebug3DFolder()
    if MapModel.Debug3DFolder and MapModel.Debug3DFolder.Parent then
        return MapModel.Debug3DFolder
    end

    local folder = Instance.new("Folder")
    folder.Name = "NULLSCAPE_MapModel3D"
    folder.Parent = Workspace
    MapModel.Debug3DFolder = folder
    return folder
end

local function ensureDebug3DViewport(deps)
    if MapModel.Debug3DGui and MapModel.Debug3DGui.Parent and MapModel.Debug3DWorld and MapModel.Debug3DCamera then
        return MapModel.Debug3DWorld, MapModel.Debug3DCamera
    end

    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil, nil
    end

    local size = getCfg(deps, "DEBUG_3D_MINIMAP_SIZE")
    local gui = Instance.new("ScreenGui")
    gui.Name = "NULLSCAPE_MapModel3DViewport"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.AnchorPoint = Vector2.new(1, 0)
    viewport.Position = UDim2.new(1, -18, 0, 84)
    viewport.Size = UDim2.fromOffset(size, size)
    viewport.BackgroundColor3 = Color3.fromRGB(4, 8, 10)
    viewport.BackgroundTransparency = 0.18
    viewport.BorderSizePixel = 1
    viewport.BorderColor3 = Color3.fromRGB(80, 245, 190)
    viewport.Ambient = Color3.fromRGB(180, 210, 210)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-0.4, -1, -0.25)
    viewport.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = viewport

    local world = Instance.new("WorldModel")
    world.Name = "World"
    world.Parent = viewport

    local camera = Instance.new("Camera")
    camera.Name = "Camera"
    camera.FieldOfView = 42
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    gui.Parent = playerGui
    MapModel.Debug3DGui = gui
    MapModel.Debug3DViewport = viewport
    MapModel.Debug3DWorld = world
    MapModel.Debug3DCamera = camera
    return world, camera
end

local function destroyDebug3DViewport()
    if MapModel.Debug3DGui then
        MapModel.Debug3DGui:Destroy()
    end
    MapModel.Debug3DGui = nil
    MapModel.Debug3DViewport = nil
    MapModel.Debug3DWorld = nil
    MapModel.Debug3DCamera = nil
end

local function mapToViewport(position, origin, scale)
    local offset = position - origin
    return Vector3.new(offset.X * scale, offset.Y * scale, offset.Z * scale)
end

local function getChunkDisplayY(chunk, fallbackY)
    local total = 0
    local count = 0
    for _, landing in ipairs(chunk.Landings or {}) do
        if landing.Position then
            total = total + landing.Position.Y
            count = count + 1
        end
    end
    if count > 0 then
        return total / count
    end
    return fallbackY
end

local function render3DModel(deps, position)
    if not MapModel.Debug3DEnabled then
        return
    end

    local currentTime = now()
    if currentTime - (MapModel.LastDebug3DRenderAt or 0) < getCfg(deps, "DEBUG_3D_RENDER_INTERVAL") then
        return
    end
    MapModel.LastDebug3DRenderAt = currentTime

    local folder = ensureDebug3DFolder()
    local world, camera = ensureDebug3DViewport(deps)
    clearChildren(folder)
    clearChildren(world)

    local chunkSize = getCfg(deps, "CHUNK_SIZE")
    local chunkHeight = getCfg(deps, "DEBUG_3D_CHUNK_HEIGHT")
    local maxMarkers = getCfg(deps, "DEBUG_3D_MAX_MARKERS")
    local minimapScale = getCfg(deps, "DEBUG_3D_MINIMAP_SCALE")
    local markers = 0

    for _, chunk in pairs(MapModel.Chunks) do
        local chunkY = getChunkDisplayY(chunk, position.Y)
        local hasLanding = #(chunk.Landings or {}) > 0
        local hasAnchor = #(chunk.Anchors or {}) > 0
        local color = Color3.fromRGB(190, 50, 65)
        local transparency = 0.84
        if hasLanding and hasAnchor then
            color = Color3.fromRGB(65, 200, 160)
            transparency = 0.78
        elseif hasLanding then
            color = Color3.fromRGB(70, 210, 115)
            transparency = 0.8
        elseif hasAnchor then
            color = Color3.fromRGB(255, 210, 75)
            transparency = 0.78
        end

        makeDebugPart(
            folder,
            "Chunk_" .. tostring(chunk.Key),
            CFrame.new(chunk.Center.X, chunkY + 0.4, chunk.Center.Z),
            Vector3.new(chunkSize, chunkHeight, chunkSize),
            color,
            transparency
        )
        if world then
            makeDebugPart(
                world,
                "Chunk_" .. tostring(chunk.Key),
                CFrame.new(mapToViewport(Vector3.new(chunk.Center.X, chunkY + 0.4, chunk.Center.Z), position, minimapScale)),
                Vector3.new(chunkSize * minimapScale, math.max(chunkHeight * minimapScale, 0.12), chunkSize * minimapScale),
                color,
                transparency * 0.65
            )
        end

        for _, landing in ipairs(chunk.Landings or {}) do
            if markers >= maxMarkers then
                break
            end
            markers = markers + 1
            makeDebugPart(
                folder,
                "Landing",
                CFrame.new(landing.Position + Vector3.new(0, 1.2, 0)),
                Vector3.new(4.5, 0.35, 4.5),
                Color3.fromRGB(85, 255, 145),
                0.16
            )
            if world then
                makeDebugPart(
                    world,
                    "Landing",
                    CFrame.new(mapToViewport(landing.Position + Vector3.new(0, 1.2, 0), position, minimapScale)),
                    Vector3.new(0.34, 0.08, 0.34),
                    Color3.fromRGB(85, 255, 145),
                    0.04
                )
            end
        end

        for _, anchor in ipairs(chunk.Anchors or {}) do
            if markers >= maxMarkers then
                break
            end
            markers = markers + 1
            makeDebugPart(
                folder,
                "Anchor_" .. tostring(anchor.Name),
                CFrame.new(anchor.Position),
                Vector3.new(3.2, 3.2, 3.2),
                Color3.fromRGB(255, 220, 85),
                0.08
            )
            if world then
                makeDebugPart(
                    world,
                    "Anchor_" .. tostring(anchor.Name),
                    CFrame.new(mapToViewport(anchor.Position, position, minimapScale)),
                    Vector3.new(0.28, 0.28, 0.28),
                    Color3.fromRGB(255, 220, 85),
                    0.02
                )
            end
        end
    end

    makeDebugPart(
        folder,
        "PlayerProjection",
        CFrame.new(position.X, position.Y - 2.8, position.Z),
        Vector3.new(5.5, 0.35, 5.5),
        Color3.fromRGB(245, 245, 245),
        0.08
    )
    if world then
        makeDebugPart(
            world,
            "PlayerProjection",
            CFrame.new(0, -0.12, 0),
            Vector3.new(0.5, 0.18, 0.5),
            Color3.fromRGB(245, 245, 245),
            0
        )
    end
    if camera then
        local height = getCfg(deps, "DEBUG_3D_MINIMAP_CAMERA_HEIGHT")
        camera.CFrame = CFrame.lookAt(Vector3.new(0, height, height * 0.82), Vector3.new(0, 0, 0))
    end
end

local function getTerrainRoots()
    local roots = {}
    local names = {
        "CurrentRooms",
        "Rooms",
        "Map",
        "Tiles",
        "GeneratedRooms",
        "GeneratedMap",
    }

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        table.insert(roots, terrain)
    end

    for _, name in ipairs(names) do
        local child = Workspace:FindFirstChild(name)
        if child then
            table.insert(roots, child)
        end
    end

    if #roots == 0 then
        table.insert(roots, Workspace)
    end

    return roots
end

local function makeOverlapParams()
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = getTerrainRoots()
    params.RespectCanCollide = true
    return params
end

local function makeRaycastParams(character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    local filter = {}
    if character then
        table.insert(filter, character)
    end
    params.FilterDescendantsInstances = filter
    return params
end

local function isSafeFloor(result, deps)
    if not (result and result.Position and result.Instance) then
        return false
    end
    if result.Instance.Name == "KillVoid" then
        return false
    end
    if result.Normal and result.Normal.Y < getCfg(deps, "FLOOR_NORMAL_Y") then
        return false
    end
    local killY = getKillY(deps)
    if killY and result.Position.Y <= killY + getCfg(deps, "KILL_MARGIN") then
        return false
    end

    return true
end

local function isAnchorPart(part)
    if not (part and part:IsA("BasePart")) then
        return false
    end
    if ANCHOR_NAMES[part.Name] then
        return true
    end
    local parent = part.Parent
    return parent and ANCHOR_NAMES[parent.Name] == true
end

local function getAnchorRoot(part)
    local parent = part and part.Parent
    if parent and ANCHOR_NAMES[parent.Name] then
        return parent, parent.Name
    end
    return part, part and part.Name
end

local function trimOldChunks(centerCx, centerCz, keepRadius)
    for key, chunk in pairs(MapModel.Chunks) do
        if math.abs(chunk.CX - centerCx) > keepRadius or math.abs(chunk.CZ - centerCz) > keepRadius then
            MapModel.Chunks[key] = nil
        end
    end
end

local function scanLandings(chunk, deps, center, chunkSize, character)
    local rayParams = makeRaycastParams(character)
    local half = chunkSize * 0.35
    local offsets = {
        Vector3.new(0, 0, 0),
        Vector3.new(half, 0, 0),
        Vector3.new(-half, 0, 0),
        Vector3.new(0, 0, half),
        Vector3.new(0, 0, -half),
        Vector3.new(half, 0, half),
        Vector3.new(-half, 0, half),
        Vector3.new(half, 0, -half),
        Vector3.new(-half, 0, -half),
    }
    local scanHeight = getCfg(deps, "SCAN_HEIGHT")
    local floorDepth = getCfg(deps, "FLOOR_DEPTH")

    for _, offset in ipairs(offsets) do
        local origin = center + offset + Vector3.new(0, scanHeight * 0.5, 0)
        local result = Workspace:Raycast(origin, Vector3.new(0, -floorDepth, 0), rayParams)
        if isSafeFloor(result, deps) then
            table.insert(chunk.Landings, {
                Position = result.Position,
                Normal = result.Normal,
                Instance = result.Instance,
                Result = result,
            })
        end
    end
end

local function scanParts(chunk, deps, center)
    local chunkSize = getCfg(deps, "CHUNK_SIZE")
    local overlapParams = makeOverlapParams()
    local parts = Workspace:GetPartBoundsInBox(
        CFrame.new(center),
        Vector3.new(chunkSize + 8, getCfg(deps, "SCAN_HEIGHT"), chunkSize + 8),
        overlapParams
    )

    local maxParts = getCfg(deps, "MAX_PARTS_PER_CHUNK")
    local maxAnchors = getCfg(deps, "MAX_ANCHORS_PER_CHUNK")
    local seenAnchors = {}
    for _, part in ipairs(parts) do
        if #chunk.Parts >= maxParts then
            break
        end
        if part and part:IsA("BasePart") then
            table.insert(chunk.Parts, part)
            if #chunk.Anchors < maxAnchors and isAnchorPart(part) then
                local root, name = getAnchorRoot(part)
                if root and not seenAnchors[root] then
                    seenAnchors[root] = true
                    table.insert(chunk.Anchors, {
                        Instance = root,
                        Part = part,
                        Name = name,
                        Position = part.Position,
                    })
                end
            end
        end
    end
end

local function scanChunk(deps, cx, cz, centerY, character)
    local chunkSize = getCfg(deps, "CHUNK_SIZE")
    local key = getChunkKey(cx, cz)
    local center = getChunkCenter(cx, cz, chunkSize, centerY)
    local chunk = {
        Key = key,
        CX = cx,
        CZ = cz,
        Center = center,
        ScannedAt = now(),
        Landings = {},
        Anchors = {},
        Parts = {},
    }

    scanLandings(chunk, deps, center, chunkSize, character)
    scanParts(chunk, deps, center)
    MapModel.Chunks[key] = chunk
    return chunk
end

local function ensureChunk(deps, cx, cz, centerY, character, force)
    local key = getChunkKey(cx, cz)
    local chunk = MapModel.Chunks[key]
    local stale = not chunk or now() - (chunk.ScannedAt or 0) > getCfg(deps, "RESCAN_INTERVAL")
    if force or stale then
        return scanChunk(deps, cx, cz, centerY, character)
    end
    return chunk
end

function MapModel.start()
    cleanupLegacy2DDebugGui()
    MapModel.Running = true
end

function MapModel.stop()
    MapModel.Running = false
    MapModel.clear()
    MapModel.setDebug3DEnabled(false)
end

function MapModel.clear()
    cleanupLegacy2DDebugGui()
    table.clear(MapModel.Chunks)
    MapModel.LastStepAt = 0
    MapModel.LastCenterKey = nil
    MapModel.LastInRound = nil
    if MapModel.Debug3DFolder then
        clearChildren(MapModel.Debug3DFolder)
    end
    if MapModel.Debug3DWorld then
        clearChildren(MapModel.Debug3DWorld)
    end
end

function MapModel.step(deps, position, character, force)
    if not position then
        return false
    end

    local inRound = getInRound()
    if inRound ~= MapModel.LastInRound then
        MapModel.LastInRound = inRound
        if not inRound then
            MapModel.clear()
            MapModel.LastInRound = false
            return false
        end
    end
    if not inRound then
        return false
    end

    MapModel.Running = true
    local currentTime = now()
    if not force and currentTime - (MapModel.LastStepAt or 0) < getCfg(deps, "STEP_INTERVAL") then
        render3DModel(deps, position)
        return true
    end

    local chunkSize = getCfg(deps, "CHUNK_SIZE")
    local cx = getChunkCoord(position.X, chunkSize)
    local cz = getChunkCoord(position.Z, chunkSize)
    local centerKey = getChunkKey(cx, cz)
    local movedChunk = centerKey ~= MapModel.LastCenterKey
    if not force and not movedChunk and currentTime - (MapModel.LastStepAt or 0) < getCfg(deps, "RESCAN_INTERVAL") then
        render3DModel(deps, position)
        return true
    end

    MapModel.LastStepAt = currentTime
    MapModel.LastCenterKey = centerKey
    local radius = getCfg(deps, "ACTIVE_RADIUS")
    for x = cx - radius, cx + radius do
        for z = cz - radius, cz + radius do
            ensureChunk(deps, x, z, position.Y, character, force)
        end
    end
    trimOldChunks(cx, cz, getCfg(deps, "KEEP_RADIUS"))
    render3DModel(deps, position)
    return true
end

function MapModel.getChunkAt(deps, position)
    if not position then
        return nil
    end
    local chunkSize = getCfg(deps, "CHUNK_SIZE")
    local cx = getChunkCoord(position.X, chunkSize)
    local cz = getChunkCoord(position.Z, chunkSize)
    return MapModel.Chunks[getChunkKey(cx, cz)]
end

function MapModel.getNearbyChunks(deps, position, radius)
    local chunks = {}
    if not position then
        return chunks
    end
    local chunkSize = getCfg(deps, "CHUNK_SIZE")
    local chunkRadius = math.max(1, math.ceil((radius or chunkSize) / chunkSize))
    local cx = getChunkCoord(position.X, chunkSize)
    local cz = getChunkCoord(position.Z, chunkSize)
    for x = cx - chunkRadius, cx + chunkRadius do
        for z = cz - chunkRadius, cz + chunkRadius do
            local chunk = MapModel.Chunks[getChunkKey(x, z)]
            if chunk then
                table.insert(chunks, chunk)
            end
        end
    end
    return chunks
end

function MapModel.findLandingBelow(deps, position, velocity, options)
    options = options or {}
    if not position then
        return nil
    end
    MapModel.step(deps, position, options.Character, false)

    local horizontal = typeof(velocity) == "Vector3" and Vector3.new(velocity.X, 0, velocity.Z) or Vector3.zero
    local horizon = tonumber(options.Horizon) or 0.6
    local maxRadius = tonumber(options.Radius) or math.max(48, horizontal.Magnitude * horizon)
    local maxDrop = tonumber(options.Depth) or getCfg(deps, "FLOOR_DEPTH")
    local best = nil
    local bestScore = math.huge
    for _, chunk in ipairs(MapModel.getNearbyChunks(deps, position, maxRadius + getCfg(deps, "CHUNK_SIZE"))) do
        for _, landing in ipairs(chunk.Landings) do
            local offset = landing.Position - position
            local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
            local drop = position.Y - landing.Position.Y
            if drop >= -4 and drop <= maxDrop and flatDistance <= maxRadius then
                local projected = position + horizontal * horizon
                local projectedFlat = Vector3.new(landing.Position.X - projected.X, 0, landing.Position.Z - projected.Z).Magnitude
                local score = projectedFlat + math.max(drop, 0) * 0.08
                if score < bestScore then
                    best = landing
                    bestScore = score
                end
            end
        end
    end

    return best
end

function MapModel.getVoidRisk(deps, position, velocity, options)
    options = options or {}
    if not position then
        return {
            Danger = false,
            Reason = "NoPosition",
        }
    end

    local killY = getKillY(deps)
    if killY and position.Y <= killY + (tonumber(options.HardBuffer) or 10) then
        return {
            Danger = true,
            Reason = "MapModelBelowKillPlane",
            KillY = killY,
        }
    end

    local landing = MapModel.findLandingBelow(deps, position, velocity, options)
    if landing then
        return {
            Danger = false,
            Reason = "MapModelLanding",
            Landing = landing,
            KillY = killY,
        }
    end

    local fallSpeed = typeof(velocity) == "Vector3" and -velocity.Y or 0
    local falling = fallSpeed >= (tonumber(options.MinFallSpeed) or 24)
    return {
        Danger = falling,
        Reason = falling and "MapModelNoLanding" or "MapModelAirborne",
        KillY = killY,
    }
end

local function scoreAnchor(position, velocity, anchor)
    local offset = anchor.Position - position
    local flat = Vector3.new(offset.X, 0, offset.Z)
    local horizontal = typeof(velocity) == "Vector3" and Vector3.new(velocity.X, 0, velocity.Z) or Vector3.zero
    local score = flat.Magnitude * 0.08
    if offset.Y >= 4 then
        score = score - 24
    else
        score = score + 38
    end
    if horizontal.Magnitude > 0.05 and flat.Magnitude > 0.05 then
        local dot = flat.Unit:Dot(horizontal.Unit)
        score = score - math.max(dot, 0) * 24 + math.max(-dot, 0) * 42
    end
    return score
end

function MapModel.findBestAnchor(deps, grapple, options)
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return nil
    end
    options = options or {}
    MapModel.step(deps, rootPart.Position, grapple.Character, false)

    local maxRange = deps.getAssistRange and deps.getAssistRange(grapple, options.driveMode == true) or 120
    local bestDecision = nil
    local bestScore = math.huge
    for _, chunk in ipairs(MapModel.getNearbyChunks(deps, rootPart.Position, maxRange)) do
        for _, anchor in ipairs(chunk.Anchors) do
            local part = anchor.Part
            local instance = anchor.Instance
            if part and part.Parent and instance and instance.Parent then
                local position = part.Position
                local result = nil
                local distance = nil
                if deps.isLineClear then
                    result, distance = deps.isLineClear(grapple, instance, part, position, maxRange)
                end
                if result and (not deps.isUsableResult or deps.isUsableResult(grapple, result)) then
                    local score = scoreAnchor(rootPart.Position, rootPart.Velocity, anchor) + (distance or 0) * 0.02
                    if score < bestScore then
                        bestScore = score
                        bestDecision = {
                            Result = result,
                            Instance = instance,
                            Name = anchor.Name,
                            Distance = distance,
                            ScreenScore = 0,
                            Score = score,
                            Reason = "MapModelAnchor",
                        }
                    end
                end
            end
        end
    end

    if options.returnDecision == true then
        return bestDecision
    end
    return bestDecision and bestDecision.Result or nil
end

function MapModel.snapshot()
    local count = 0
    local landings = 0
    local anchors = 0
    for _, chunk in pairs(MapModel.Chunks) do
        count = count + 1
        landings = landings + #(chunk.Landings or {})
        anchors = anchors + #(chunk.Anchors or {})
    end
    return string.format("MapModel:%d chunks/%d landings/%d anchors", count, landings, anchors)
end

function MapModel.setDebug3DEnabled(value)
    cleanupLegacy2DDebugGui()
    MapModel.Debug3DEnabled = value == true
    MapModel.LastDebug3DRenderAt = 0
    if not MapModel.Debug3DEnabled then
        if MapModel.Debug3DFolder then
            MapModel.Debug3DFolder:Destroy()
        end
        MapModel.Debug3DFolder = nil
        destroyDebug3DViewport()
    end
end

return MapModel
