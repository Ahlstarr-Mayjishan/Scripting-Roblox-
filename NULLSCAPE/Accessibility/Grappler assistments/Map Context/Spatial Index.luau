--!nocheck
-- [[
--  NULLSCAPE - Map Context Spatial Index
--  Small bucket index for static map surfaces.
-- ]]

local SpatialIndex = {}
local env = getgenv()
local sharedGlobals = env._NULLSCAPE_Globals or {}
env._NULLSCAPE_Globals = sharedGlobals

local DEFAULT_BUCKET_SIZE = 128

function SpatialIndex.new(bucketSize)
	return {
		BucketSize = tonumber(bucketSize) or DEFAULT_BUCKET_SIZE,
		Buckets = {},
		Entries = {},
	}
end

local function getBucketCoords(index, position)
	local bucketSize = index.BucketSize or DEFAULT_BUCKET_SIZE
	return math.floor(position.X / bucketSize), math.floor(position.Y / bucketSize), math.floor(position.Z / bucketSize)
end

local function makeKey(x, y, z)
	return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function getBucketKey(index, position)
	return makeKey(getBucketCoords(index, position))
end

local function removeFromBucket(index, key, id)
	local bucket = key and index.Buckets[key]
	if not bucket then
		return
	end

	bucket[id] = nil
	if not next(bucket) then
		index.Buckets[key] = nil
	end
end

function SpatialIndex.clear(index)
	table.clear(index.Buckets)
	table.clear(index.Entries)
end

function SpatialIndex.insert(index, id, entry, position)
	if not (index and id and entry and position) then
		return nil
	end

	local previous = index.Entries[id]
	if previous and previous.BucketKey then
		removeFromBucket(index, previous.BucketKey, id)
	end

	local bucketKey = getBucketKey(index, position)
	entry.Id = id
	entry.Position = position
	entry.BucketKey = bucketKey
	index.Entries[id] = entry

	index.Buckets[bucketKey] = index.Buckets[bucketKey] or {}
	index.Buckets[bucketKey][id] = entry
	return entry
end

function SpatialIndex.remove(index, id)
	local entry = index and index.Entries[id]
	if not entry then
		return
	end

	removeFromBucket(index, entry.BucketKey, id)
	index.Entries[id] = nil
end

function SpatialIndex.query(index, origin, radius)
	local results = {}
	if not (index and origin and radius) then
		return results
	end

	local bucketSize = index.BucketSize or DEFAULT_BUCKET_SIZE
	local centerX, centerY, centerZ = getBucketCoords(index, origin)
	local bucketRadius = math.max(1, math.ceil(radius / bucketSize))

	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = index.Buckets[makeKey(x, y, z)]
				if bucket then
					for _, entry in pairs(bucket) do
						local offset = entry.Position - origin
						local distance = offset.Magnitude
						if distance <= radius then
							entry.Distance = distance
							table.insert(results, entry)
						end
					end
				end
			end
		end
	end

	table.sort(results, function(a, b)
		return (a.Distance or math.huge) < (b.Distance or math.huge)
	end)

	return results
end

sharedGlobals.MapContextSpatialIndex = SpatialIndex

return SpatialIndex
