--!nocheck
-- [[
--  NULLSCAPE - Map Context Terrain Memory
--  Static terrain cache for technique helpers.
-- ]]

local Workspace = game:GetService("Workspace")
local SpatialIndex = getgenv().loadModule(
	"NULLSCAPE/Accessibility/Grappler assistments/Map Context/Spatial Index.luau"
)

local BUCKET_SIZE = 128
local DEFAULT_QUERY_RADIUS = 96
local partIds = setmetatable({}, { __mode = "k" })
local nextPartId = 0
local OBSERVER_PRUNE_INTERVAL = 2

local TerrainMemory = {
	Index = SpatialIndex.new(BUCKET_SIZE),
	Scanned = false,
	ObservedRoots = {},
	LastPruneAt = -1000,
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
	local id = getPartId(part)
	local wasKnown = TerrainMemory.Index.Entries[id] ~= nil

	local entry = {
		Part = part,
		Name = part.Name,
		Size = part.Size,
		CFrame = part.CFrame,
		Position = part.Position,
		LastSeen = time(),
	}

	SpatialIndex.insert(TerrainMemory.Index, id, entry, part.Position)
	if not wasKnown then
		TerrainMemory.SurfaceCount += 1
	end
end

local function removePart(part)
	local id = partIds[part]
	if id and TerrainMemory.Index.Entries[id] then
		SpatialIndex.remove(TerrainMemory.Index, id)
		TerrainMemory.SurfaceCount = math.max(0, TerrainMemory.SurfaceCount - 1)
	end
end

local function pruneDead()
	local now = time()
	if now - TerrainMemory.LastPruneAt < OBSERVER_PRUNE_INTERVAL then
		return
	end
	TerrainMemory.LastPruneAt = now
	for id, entry in pairs(TerrainMemory.Index.Entries) do
		if not isAlive(entry.Part) then
			SpatialIndex.remove(TerrainMemory.Index, id)
			TerrainMemory.SurfaceCount = math.max(0, TerrainMemory.SurfaceCount - 1)
		end
	end
end

local function disconnectRoot(root)
	local observer = TerrainMemory.ObservedRoots[root]
	if not observer then
		return
	end

	for _, connection in ipairs(observer.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	TerrainMemory.ObservedRoots[root] = nil
end

local function rootsChanged(roots)
	local count = 0
	for root in pairs(TerrainMemory.ObservedRoots) do
		if not root.Parent then
			return true
		end
		count += 1
	end
	if count ~= #roots then
		return true
	end
	for _, root in ipairs(roots) do
		if not TerrainMemory.ObservedRoots[root] then
			return true
		end
	end
	return false
end

local function observeRoot(root)
	local observer = {
		Connections = {},
	}
	TerrainMemory.ObservedRoots[root] = observer

	local function consider(instance)
		if isQueryable(instance) then
			rememberPart(instance)
		end
	end

	consider(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		consider(descendant)
	end

	table.insert(observer.Connections, root.DescendantAdded:Connect(consider))
	table.insert(observer.Connections, root.DescendantRemoving:Connect(removePart))
	table.insert(
		observer.Connections,
		root.AncestryChanged:Connect(function(_, parent)
			if not parent then
				disconnectRoot(root)
			end
		end)
	)
end

local function resetObservedRoots()
	for root in pairs(TerrainMemory.ObservedRoots) do
		disconnectRoot(root)
	end
	SpatialIndex.clear(TerrainMemory.Index)
	TerrainMemory.SurfaceCount = 0
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
	local roots = getMapRoots()
	if force or not TerrainMemory.Scanned or rootsChanged(roots) then
		resetObservedRoots()
		for _, root in ipairs(roots) do
			observeRoot(root)
		end
		TerrainMemory.Scanned = true
	end

	pruneDead()
	return true
end

function TerrainMemory.getNearbySurfaces(position, radius)
	TerrainMemory.ensureScanned(false)
	return SpatialIndex.query(TerrainMemory.Index, position, tonumber(radius) or DEFAULT_QUERY_RADIUS)
end

function TerrainMemory.getClosestSurface(position, radius)
	local surfaces = TerrainMemory.getNearbySurfaces(position, radius or DEFAULT_QUERY_RADIUS)
	return surfaces[1]
end

function TerrainMemory.clear()
	resetObservedRoots()
	TerrainMemory.Scanned = false
	TerrainMemory.LastPruneAt = -1000
end

return TerrainMemory
