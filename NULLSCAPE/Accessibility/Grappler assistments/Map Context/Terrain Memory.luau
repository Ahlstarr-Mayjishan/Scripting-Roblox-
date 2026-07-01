--!nocheck
-- [[
--  NULLSCAPE - Map Context Terrain Memory
--  Static terrain cache for technique helpers.
-- ]]

local Workspace = game:GetService("Workspace")

local SpatialIndex = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Spatial Index.luau")

local BUCKET_SIZE = 128
local DEFAULT_QUERY_RADIUS = 96
local RESCAN_COOLDOWN = 2
local partIds = setmetatable({}, { __mode = "k" })
local nextPartId = 0

local TerrainMemory = {
	Index = SpatialIndex.new(BUCKET_SIZE),
	Scanned = false,
	LastScanAt = -1000,
	LastRootSignature = "",
	SurfaceCount = 0,
}

local function isAlive(instance)
	return instance and instance.Parent ~= nil and instance:IsDescendantOf(Workspace)
end

local function isQueryable(part)
	if not (part and part:IsA("BasePart")) then
		return false
	end

	if part.Name == "KillVoid" then
		return false
	end

	if part.CanCollide == false and part.CanTouch == false then
		return false
	end

	if part.CanQuery == false then
		return false
	end

	return true
end

local function addRoot(roots, instance)
	if instance then
		table.insert(roots, instance)
	end
end

local function getMapRoots()
	local roots = {}
	addRoot(roots, Workspace:FindFirstChild("CurrentRooms"))
	addRoot(roots, Workspace:FindFirstChild("Spawn"))

	if #roots == 0 then
		addRoot(roots, Workspace)
	end

	return roots
end

local function makeRootSignature(roots)
	local chunks = {}
	for _, root in ipairs(roots) do
		local count = 0
		local success, descendants = pcall(function()
			return root:GetDescendants()
		end)
		if success then
			count = #descendants
		end
		table.insert(chunks, root:GetFullName() .. "#" .. tostring(count))
	end

	return table.concat(chunks, "|")
end

local function getPartId(part)
	if not part then
		return nil
	end

	local existing = partIds[part]
	if existing then
		return existing
	end

	nextPartId += 1
	local id = "terrain:" .. tostring(nextPartId)
	partIds[part] = id
	return id
end

local function rememberPart(part)
	if not isQueryable(part) then
		return
	end

	local entry = {
		Part = part,
		Name = part.Name,
		Size = part.Size,
		CFrame = part.CFrame,
		Position = part.Position,
		LastSeen = time(),
	}

	SpatialIndex.insert(TerrainMemory.Index, getPartId(part), entry, part.Position)
	TerrainMemory.SurfaceCount += 1
end

local function pruneDead()
	for id, entry in pairs(TerrainMemory.Index.Entries) do
		if not isAlive(entry.Part) then
			SpatialIndex.remove(TerrainMemory.Index, id)
		end
	end
end

function TerrainMemory.getMapRoots()
	return getMapRoots()
end

function TerrainMemory.getVoidInfo()
	local killVoid = Workspace:FindFirstChild("KillVoid")
	if not (killVoid and killVoid:IsA("BasePart")) then
		return nil
	end

	return {
		Part = killVoid,
		Position = killVoid.Position,
		Y = killVoid.Position.Y,
		Size = killVoid.Size,
	}
end

function TerrainMemory.ensureScanned(force)
	local now = time()

	if not force and TerrainMemory.Scanned and now - TerrainMemory.LastScanAt < RESCAN_COOLDOWN then
		pruneDead()
		return true
	end

	local roots = getMapRoots()
	local signature = makeRootSignature(roots)

	if not force and TerrainMemory.Scanned and signature == TerrainMemory.LastRootSignature then
		TerrainMemory.LastScanAt = now
		pruneDead()
		return true
	end

	SpatialIndex.clear(TerrainMemory.Index)
	TerrainMemory.SurfaceCount = 0

	for _, root in ipairs(roots) do
		if isQueryable(root) then
			rememberPart(root)
		end

		for _, descendant in ipairs(root:GetDescendants()) do
			if isQueryable(descendant) then
				rememberPart(descendant)
			end
		end
	end

	TerrainMemory.Scanned = true
	TerrainMemory.LastScanAt = now
	TerrainMemory.LastRootSignature = signature
	return true
end

function TerrainMemory.getNearbySurfaces(position, radius)
	TerrainMemory.ensureScanned(false)
	pruneDead()
	return SpatialIndex.query(TerrainMemory.Index, position, tonumber(radius) or DEFAULT_QUERY_RADIUS)
end

function TerrainMemory.getClosestSurface(position, radius)
	local surfaces = TerrainMemory.getNearbySurfaces(position, radius or DEFAULT_QUERY_RADIUS)
	return surfaces[1]
end

function TerrainMemory.clear()
	SpatialIndex.clear(TerrainMemory.Index)
	TerrainMemory.Scanned = false
	TerrainMemory.LastScanAt = -1000
	TerrainMemory.LastRootSignature = ""
	TerrainMemory.SurfaceCount = 0
end

return TerrainMemory
