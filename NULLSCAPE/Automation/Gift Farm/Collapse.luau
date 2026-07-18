--!nocheck

local CollectionService = game:GetService("CollectionService")

local Collapse = {}

local MAX_TRACKED_TILES = 80
local DEFAULT_RADIUS = 48
local CELL_SIZE = 64
local MAX_CELLS_PER_TILE = 64
local SAFETY_REFRESH_INTERVAL = 1
local TAG_URGENCY = {
	TileDestroy = 3,
	TileDestroyed = 3,
	TileCrack = 2,
}

local trackedInstances = {}
local connections = {}
local destroyFolderConnections = {}
local cachedIndex = { Grid = {}, Global = {}, Count = 0 }
local lastRefresh = 0
local dirty = true
local trackingStarted = false

local function getModelBounds(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position, instance.Size
	end
	if instance:IsA("Model") then
		local ok, cframe, size = pcall(function()
			local cf, extents = instance:GetBoundingBox()
			return cf, extents
		end)
		if ok and cframe and size then
			return cframe.Position, size
		end
		local part = instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position, part.Size
		end
	end
	return nil
end

local function mark(instance, urgency)
	if instance and instance.Parent then
		local nextUrgency = math.max(tonumber(trackedInstances[instance]) or 0, tonumber(urgency) or 0)
		if trackedInstances[instance] ~= nextUrgency then
			trackedInstances[instance] = nextUrgency
			dirty = true
		end
	end
end

local function unmark(instance)
	if trackedInstances[instance] ~= nil then
		trackedInstances[instance] = nil
		dirty = true
	end
end

local function getTaggedUrgency(instance)
	local urgency = 0
	for tag, tagUrgency in pairs(TAG_URGENCY) do
		if CollectionService:HasTag(instance, tag) then
			urgency = math.max(urgency, tagUrgency)
		end
	end
	return urgency
end

local function getBucket(grid, x, y, z, create)
	local xGrid = grid[x]
	if not xGrid and create then
		xGrid = {}
		grid[x] = xGrid
	end
	local yGrid = xGrid and xGrid[y]
	if not yGrid and create then
		yGrid = {}
		xGrid[y] = yGrid
	end
	local bucket = yGrid and yGrid[z]
	if not bucket and create then
		bucket = {}
		yGrid[z] = bucket
	end
	return bucket
end

local function indexTile(index, tile)
	local half = tile.Size * 0.5 + Vector3.new(DEFAULT_RADIUS, DEFAULT_RADIUS, DEFAULT_RADIUS)
	local minimum = tile.Position - half
	local maximum = tile.Position + half
	local minX, minY, minZ =
		math.floor(minimum.X / CELL_SIZE), math.floor(minimum.Y / CELL_SIZE), math.floor(minimum.Z / CELL_SIZE)
	local maxX, maxY, maxZ =
		math.floor(maximum.X / CELL_SIZE), math.floor(maximum.Y / CELL_SIZE), math.floor(maximum.Z / CELL_SIZE)
	local cellCount = (maxX - minX + 1) * (maxY - minY + 1) * (maxZ - minZ + 1)
	if cellCount > MAX_CELLS_PER_TILE then
		index.Global[#index.Global + 1] = tile
		return
	end
	for x = minX, maxX do
		for y = minY, maxY do
			for z = minZ, maxZ do
				local bucket = getBucket(index.Grid, x, y, z, true)
				bucket[#bucket + 1] = tile
			end
		end
	end
end

local function rebuild()
	local index = { Grid = {}, Global = {}, Count = 0 }
	local stale = {}
	for instance, urgency in pairs(trackedInstances) do
		if index.Count >= MAX_TRACKED_TILES then
			break
		end
		if not (instance and instance.Parent) then
			stale[#stale + 1] = instance
		else
			local position, size = getModelBounds(instance)
			if position then
				local tile = {
					Instance = instance,
					Position = position,
					Size = size or Vector3.new(DEFAULT_RADIUS, DEFAULT_RADIUS, DEFAULT_RADIUS),
					Urgency = urgency,
				}
				indexTile(index, tile)
				index.Count += 1
			end
		end
	end
	for _, instance in ipairs(stale) do
		trackedInstances[instance] = nil
	end
	cachedIndex = index
	lastRefresh = os.clock()
	dirty = false
end

local function disconnectFolderConnections()
	for _, connection in ipairs(destroyFolderConnections) do
		connection:Disconnect()
	end
	table.clear(destroyFolderConnections)
end

local function bindDestroyFolder(folder)
	disconnectFolderConnections()
	if not folder then
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		mark(child, 3)
	end
	destroyFolderConnections[#destroyFolderConnections + 1] = folder.ChildAdded:Connect(function(child)
		mark(child, 3)
	end)
	destroyFolderConnections[#destroyFolderConnections + 1] = folder.ChildRemoved:Connect(function(child)
		local urgency = getTaggedUrgency(child)
		if urgency > 0 then
			trackedInstances[child] = urgency
			dirty = true
		else
			unmark(child)
		end
	end)
end

local function startTracking()
	if trackingStarted then
		return
	end
	trackingStarted = true
	for tag, urgency in pairs(TAG_URGENCY) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			mark(instance, urgency)
		end
		connections[#connections + 1] = CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			mark(instance, urgency)
		end)
		connections[#connections + 1] = CollectionService:GetInstanceRemovedSignal(tag):Connect(unmark)
	end
	bindDestroyFolder(workspace:FindFirstChild("DestroyFolder"))
	connections[#connections + 1] = workspace.ChildAdded:Connect(function(child)
		if child.Name == "DestroyFolder" then
			bindDestroyFolder(child)
		end
	end)
	connections[#connections + 1] = workspace.ChildRemoved:Connect(function(child)
		if child.Name == "DestroyFolder" then
			bindDestroyFolder(nil)
		end
	end)
end

local function distanceOutsideBoundsSq(pos, center, size)
	local half = size * 0.5
	local dx = math.max(math.abs(pos.X - center.X) - half.X, 0)
	local dy = math.max(math.abs(pos.Y - center.Y) - half.Y, 0)
	local dz = math.max(math.abs(pos.Z - center.Z) - half.Z, 0)
	return dx * dx + dy * dy + dz * dz
end

function Collapse.reset()
	dirty = true
	lastRefresh = 0
end

function Collapse.prepareScan()
	startTracking()
	if dirty or os.clock() - lastRefresh >= SAFETY_REFRESH_INTERVAL then
		rebuild()
	end
	return cachedIndex
end

function Collapse.getGiftUrgency(position, scanIndex)
	if typeof(position) ~= "Vector3" then
		return 0
	end
	local index = scanIndex or Collapse.prepareScan()
	local x, y, z =
		math.floor(position.X / CELL_SIZE), math.floor(position.Y / CELL_SIZE), math.floor(position.Z / CELL_SIZE)
	local bucket = getBucket(index.Grid, x, y, z, false) or {}
	local best = 0
	local radiusSq = DEFAULT_RADIUS * DEFAULT_RADIUS
	local function scoreTiles(tiles)
		for _, tile in ipairs(tiles) do
			local distanceSq = distanceOutsideBoundsSq(position, tile.Position, tile.Size)
			if distanceSq <= radiusSq then
				local proximity = 1 - math.clamp(math.sqrt(distanceSq) / DEFAULT_RADIUS, 0, 1)
				best = math.max(best, tile.Urgency * (1 + proximity))
			end
		end
	end
	scoreTiles(bucket)
	scoreTiles(index.Global)
	return best
end

function Collapse.stop()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	disconnectFolderConnections()
	table.clear(trackedInstances)
	cachedIndex = { Grid = {}, Global = {}, Count = 0 }
	trackingStarted = false
	dirty = true
end

return Collapse
