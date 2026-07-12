--!nocheck
-- [[
--  NULLSCAPE - Grapple Assist Anchor Memory
--  Runtime cache for special grapple anchors observed in the active map.
-- ]]

local Workspace = game:GetService("Workspace")

local AnchorMemory = {}
local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")
local PerformanceBudget = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Performance Budget.luau")

local DEFAULT_SCAN_BUDGET = 250
local RESCAN_COOLDOWN = 0.75
local BUCKET_SIZE = 96

local anchors = {}
local buckets = {}
local lastRefreshAt = -1000
local lastPruneAt = -1000
local observedRoots = {}
local OBSERVER_PRUNE_INTERVAL = 2

local function isBasePart(part)
	return typeof(part) == "Instance" and part:IsA("BasePart")
end

local function getAnchorName(part)
	if not (isBasePart(part) and SpecialAnchors and typeof(SpecialAnchors.getName) == "function") then
		return nil
	end

	return SpecialAnchors.getName(part)
end

local function isSpecialAnchor(part)
	return getAnchorName(part) ~= nil
end

function AnchorMemory.getPriority(anchorName, controller)
	if SpecialAnchors and typeof(SpecialAnchors.getPriority) == "function" then
		return SpecialAnchors.getPriority(anchorName, controller)
	end

	return 0
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

local function disconnectRoot(root)
	local observer = observedRoots[root]
	if not observer then
		return
	end

	for _, connection in ipairs(observer.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	observedRoots[root] = nil
end

local function observeRoot(root)
	if not (root and not observedRoots[root]) then
		return
	end

	local observer = {
		Connections = {},
	}
	observedRoots[root] = observer

	local function consider(instance)
		if isSpecialAnchor(instance) then
			AnchorMemory.remember(instance, "incremental-scan")
		end
	end

	consider(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		consider(descendant)
	end

	table.insert(observer.Connections, root.DescendantAdded:Connect(consider))
	table.insert(observer.Connections, root.DescendantRemoving:Connect(remove))
	table.insert(
		observer.Connections,
		root.AncestryChanged:Connect(function(_, parent)
			if not parent then
				disconnectRoot(root)
			end
		end)
	)
end

local function observeRoots(roots)
	for root in pairs(observedRoots) do
		if not root.Parent then
			disconnectRoot(root)
		end
	end

	for _, root in ipairs(roots) do
		observeRoot(root)
	end
end

local function pruneDead()
	local now = time()
	if now - lastPruneAt < OBSERVER_PRUNE_INTERVAL then
		return
	end
	lastPruneAt = now
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

function AnchorMemory.refreshBudgeted(_scanBudget, controller)
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

	observeRoots(roots)
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
	for root in pairs(observedRoots) do
		disconnectRoot(root)
	end
	table.clear(anchors)
	table.clear(buckets)
	lastRefreshAt = -1000
	lastPruneAt = -1000
end

return AnchorMemory
