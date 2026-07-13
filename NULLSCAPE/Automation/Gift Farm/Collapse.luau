--!nocheck

local CollectionService = game:GetService("CollectionService")

local Collapse = {}

local REFRESH_INTERVAL = 0.18
local MAX_TRACKED_TILES = 80
local DEFAULT_RADIUS = 48
local lastRefresh = 0
local cachedTiles = {}

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

local function addTile(tiles, instance, urgency)
	if #tiles >= MAX_TRACKED_TILES then
		return
	end
	if not (instance and instance.Parent) then
		return
	end

	local position, size = getModelBounds(instance)
	if not position then
		return
	end

	table.insert(tiles, {
		Instance = instance,
		Position = position,
		Size = size or Vector3.new(DEFAULT_RADIUS, DEFAULT_RADIUS, DEFAULT_RADIUS),
		Urgency = urgency,
	})
end

local function addTagged(tiles, tag, urgency)
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		addTile(tiles, instance, urgency)
		if #tiles >= MAX_TRACKED_TILES then
			return
		end
	end
end

local function refresh()
	local tiles = {}

	addTagged(tiles, "TileDestroy", 3)
	addTagged(tiles, "TileDestroyed", 3)
	addTagged(tiles, "TileCrack", 2)

	local destroyFolder = workspace:FindFirstChild("DestroyFolder")
	if destroyFolder then
		for _, child in ipairs(destroyFolder:GetChildren()) do
			addTile(tiles, child, 3)
			if #tiles >= MAX_TRACKED_TILES then
				break
			end
		end
	end

	cachedTiles = tiles
	lastRefresh = os.clock()
end

local function distanceOutsideBoundsSq(pos, center, size)
	local half = size * 0.5
	local dx = math.max(math.abs(pos.X - center.X) - half.X, 0)
	local dy = math.max(math.abs(pos.Y - center.Y) - half.Y, 0)
	local dz = math.max(math.abs(pos.Z - center.Z) - half.Z, 0)
	return dx * dx + dy * dy + dz * dz
end

function Collapse.reset()
	cachedTiles = {}
	lastRefresh = 0
end

function Collapse.prepareScan()
	if os.clock() - lastRefresh >= REFRESH_INTERVAL then
		refresh()
	end
	return cachedTiles
end

function Collapse.getGiftUrgency(position, scanTiles)
	if typeof(position) ~= "Vector3" then
		return 0
	end

	local best = 0
	local radiusSq = DEFAULT_RADIUS * DEFAULT_RADIUS
	for _, tile in ipairs(scanTiles or Collapse.prepareScan()) do
		local distanceSq = distanceOutsideBoundsSq(position, tile.Position, tile.Size)
		if distanceSq <= radiusSq then
			local distance = math.sqrt(distanceSq)
			local proximity = 1 - math.clamp(distance / DEFAULT_RADIUS, 0, 1)
			local score = tile.Urgency * (1 + proximity)
			if score > best then
				best = score
			end
		end
	end

	return best
end

return Collapse
