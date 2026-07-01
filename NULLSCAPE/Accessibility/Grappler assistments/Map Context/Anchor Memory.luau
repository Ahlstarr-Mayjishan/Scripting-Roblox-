--!nocheck
-- [[
--  NULLSCAPE - Grapple Assist Anchor Memory
--  Runtime cache for special grapple anchors observed in the active map.
-- ]]

local Workspace = game:GetService("Workspace")

local AnchorMemory = {}

local SPECIAL_ANCHORS = {
	JumpPad = {
		Priority = 1000,
		Field = "GrappleAnchorPriorityJumpPad",
	},
	GrapplePoint = {
		Priority = 900,
		Field = "GrappleAnchorPriorityGrapplePoint",
	},
	Bell = {
		Priority = 800,
		Field = "GrappleAnchorPriorityBell",
	},
	TriaOrb = {
		Priority = 850,
		Field = "GrappleAnchorPriorityTriaOrb",
	},
}

local DEFAULT_SCAN_BUDGET = 250
local RESCAN_COOLDOWN = 0.75
local BUCKET_SIZE = 96

local anchors = {}
local buckets = {}
local scanCursor = 1
local lastRefreshAt = -1000

local function hasTag(instance, tagName)
	if not (instance and typeof(instance.HasTag) == "function") then
		return false
	end

	local success, result = pcall(function()
		return instance:HasTag(tagName)
	end)

	return success and result == true
end

local function isBasePart(part)
	return typeof(part) == "Instance" and part:IsA("BasePart")
end

local function getAnchorName(part)
	if not isBasePart(part) then
		return nil
	end

	if SPECIAL_ANCHORS[part.Name] then
		return part.Name
	end

	if hasTag(part, "JumpPad") then
		return "JumpPad"
	end

	return nil
end

local function isSpecialAnchor(part)
	return getAnchorName(part) ~= nil
end

function AnchorMemory.getPriority(anchorName, controller)
	local config = SPECIAL_ANCHORS[anchorName]
	if not config then
		return 0
	end

	local value = controller and tonumber(controller[config.Field])
	return math.clamp(value or config.Priority, 0, 1000)
end

local function isAlive(part)
	return isBasePart(part) and part.Parent ~= nil and part:IsDescendantOf(Workspace)
end

local function getBucketKey(position)
	local x = math.floor(position.X / BUCKET_SIZE)
	local y = math.floor(position.Y / BUCKET_SIZE)
	local z = math.floor(position.Z / BUCKET_SIZE)
	return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z), x, y, z
end

local function removeFromBucket(part, bucketKey)
	local bucket = bucketKey and buckets[bucketKey]
	if not bucket then
		return
	end

	bucket[part] = nil
	if not next(bucket) then
		buckets[bucketKey] = nil
	end
end

local function indexEntry(entry)
	local bucketKey = getBucketKey(entry.Position)
	if entry.BucketKey and entry.BucketKey ~= bucketKey then
		removeFromBucket(entry.Part, entry.BucketKey)
	end

	entry.BucketKey = bucketKey
	buckets[bucketKey] = buckets[bucketKey] or {}
	buckets[bucketKey][entry.Part] = entry
end

local function remove(part)
	local entry = anchors[part]
	if entry then
		removeFromBucket(part, entry.BucketKey)
	end
	anchors[part] = nil
end

local function pruneDead()
	for part in pairs(anchors) do
		if not isAlive(part) then
			remove(part)
		end
	end
end

function AnchorMemory.isSpecialAnchor(part)
	return isSpecialAnchor(part)
end

function AnchorMemory.remember(part, source, controller)
	local anchorName = getAnchorName(part)
	if not anchorName then
		return nil
	end

	local priority = AnchorMemory.getPriority(anchorName, controller)
	local entry = anchors[part]
	if type(entry) ~= "table" then
		entry = {
			Part = part,
			Name = anchorName,
			Priority = priority,
			Position = part.Position,
			LastSeen = time(),
			LastSuccessfulCast = -1000,
			FailedAttempts = 0,
			Source = source or "scan",
		}
		anchors[part] = entry
	else
		entry.Name = anchorName
		entry.Priority = priority
		entry.Position = part.Position
		entry.LastSeen = time()
		entry.Source = source or entry.Source
	end

	indexEntry(entry)

	return entry
end

function AnchorMemory.noteCastResult(part, success)
	if not isBasePart(part) then
		return
	end

	local entry = anchors[part]
	if type(entry) ~= "table" then
		entry = AnchorMemory.remember(part, "cast-result")
	end
	if not entry then
		return
	end

	if success then
		entry.LastSuccessfulCast = time()
		entry.FailedAttempts = 0
	else
		entry.FailedAttempts = (entry.FailedAttempts or 0) + 1
	end
end

function AnchorMemory.refreshBudgeted(scanBudget, controller)
	local now = time()
	if now - lastRefreshAt < RESCAN_COOLDOWN then
		return
	end
	lastRefreshAt = now
	pruneDead()

	local roots = {}
	local jumpPads = Workspace:FindFirstChild("JumpPads")
	local currentRooms = Workspace:FindFirstChild("CurrentRooms")
	local enemies = Workspace:FindFirstChild("Enemies")
	if jumpPads then
		table.insert(roots, jumpPads)
	end
	if currentRooms then
		table.insert(roots, currentRooms)
	end
	if enemies then
		table.insert(roots, enemies)
	end
	if #roots == 0 then
		table.insert(roots, Workspace)
	end

	local descendants = {}
	for _, root in ipairs(roots) do
		if isSpecialAnchor(root) then
			table.insert(descendants, root)
		end
		for _, descendant in ipairs(root:GetDescendants()) do
			table.insert(descendants, descendant)
		end
	end

	local budget = math.clamp(tonumber(scanBudget) or DEFAULT_SCAN_BUDGET, 25, 1500)
	if #descendants == 0 then
		scanCursor = 1
		return
	end

	for _ = 1, math.min(budget, #descendants) do
		if scanCursor > #descendants then
			scanCursor = 1
		end

		local descendant = descendants[scanCursor]
		scanCursor += 1
		if isSpecialAnchor(descendant) then
			AnchorMemory.remember(descendant, "budgeted-scan", controller)
		end
	end
end

function AnchorMemory.getNearbyAnchors(origin, maxRange, controller)
	pruneDead()

	local results = {}
	local _, centerX, centerY, centerZ = getBucketKey(origin)
	local radius = math.max(1, math.ceil(maxRange / BUCKET_SIZE))

	for x = centerX - radius, centerX + radius do
		for y = centerY - radius, centerY + radius do
			for z = centerZ - radius, centerZ + radius do
				local bucket = buckets[tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)]
				if bucket then
					for part, entry in pairs(bucket) do
						if not isAlive(part) then
							remove(part)
							continue
						end

						local offset = part.Position - origin
						local distance = offset.Magnitude
						if distance <= maxRange then
							entry.Position = part.Position
							entry.Priority = AnchorMemory.getPriority(entry.Name, controller)
							entry.Distance = distance
							indexEntry(entry)
							table.insert(results, entry)
						end
					end
				end
			end
		end
	end

	table.sort(results, function(a, b)
		if a.Priority == b.Priority then
			return (a.Distance or math.huge) < (b.Distance or math.huge)
		end
		return (a.Priority or 0) > (b.Priority or 0)
	end)

	return results
end

function AnchorMemory.clear()
	table.clear(anchors)
	table.clear(buckets)
	scanCursor = 1
	lastRefreshAt = -1000
end

return AnchorMemory
