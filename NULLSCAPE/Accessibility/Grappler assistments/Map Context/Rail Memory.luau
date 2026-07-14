--!nocheck
-- [[
--  NULLSCAPE - Map Context Rail Memory
--  Runtime cache for Highrise grind rails and other _RailPart paths.
-- ]]

local Workspace = game:GetService("Workspace")
local SpatialIndex = getgenv().loadModule(
	"NULLSCAPE/Accessibility/Grappler assistments/Map Context/Spatial Index.luau"
)

local BUCKET_SIZE = 128
local DEFAULT_QUERY_RADIUS = 110
local RESCAN_COOLDOWN = 0.75
local railIds = setmetatable({}, { __mode = "k" })
local nextRailId = 0

local RailMemory = {
	Index = SpatialIndex.new(BUCKET_SIZE),
	LastRefreshAt = -1000,
	LastPruneAt = -1000,
	ObservedRoots = {},
}

local OBSERVER_PRUNE_INTERVAL = 2

local function isAlive(instance)
	return instance and instance.Parent ~= nil and instance:IsDescendantOf(Workspace)
end

local function isRailPart(part)
	return part and part:IsA("BasePart") and part.Name == "_RailPart"
end

local function getRailId(part)
	if not part then
		return nil
	end

	local existing = railIds[part]
	if existing then
		return existing
	end

	nextRailId += 1
	local id = "rail:" .. tostring(nextRailId)
	railIds[part] = id
	return id
end

local function addRoot(roots, instance)
	if instance then
		table.insert(roots, instance)
	end
end

local function getRailRoots()
	local roots = {}
	addRoot(roots, Workspace:FindFirstChild("JumpPads"))
	addRoot(roots, Workspace:FindFirstChild("CurrentRooms"))

	if #roots == 0 then
		addRoot(roots, Workspace)
	end

	return roots
end

local function rememberRail(part)
	if not isRailPart(part) then
		return nil
	end

	local entry = {
		Part = part,
		Name = part.Name,
		Position = part.Position,
		CFrame = part.CFrame,
		Size = part.Size,
		Direction = part.CFrame.LookVector,
		LastSeen = time(),
	}

	return SpatialIndex.insert(RailMemory.Index, getRailId(part), entry, part.Position)
end

local function pruneDead()
	local now = time()
	if now - RailMemory.LastPruneAt < OBSERVER_PRUNE_INTERVAL then
		return
	end
	RailMemory.LastPruneAt = now
	for id, entry in pairs(RailMemory.Index.Entries) do
		if not isAlive(entry.Part) then
			SpatialIndex.remove(RailMemory.Index, id)
		end
	end
end

local function removeRail(part)
	local id = railIds[part]
	if id then
		SpatialIndex.remove(RailMemory.Index, id)
	end
end

local function disconnectRoot(root)
	local observer = RailMemory.ObservedRoots[root]
	if not observer then
		return
	end

	for _, connection in ipairs(observer.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	RailMemory.ObservedRoots[root] = nil
end

local function observeRoot(root)
	if not (root and not RailMemory.ObservedRoots[root]) then
		return
	end

	local observer = {
		Connections = {},
	}
	RailMemory.ObservedRoots[root] = observer

	local function consider(instance)
		if isRailPart(instance) then
			rememberRail(instance)
		end
	end

	consider(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		consider(descendant)
	end

	table.insert(observer.Connections, root.DescendantAdded:Connect(consider))
	table.insert(observer.Connections, root.DescendantRemoving:Connect(removeRail))
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
	for root in pairs(RailMemory.ObservedRoots) do
		if not root.Parent then
			disconnectRoot(root)
		end
	end

	for _, root in ipairs(roots) do
		observeRoot(root)
	end
end

function RailMemory.isRailPart(part)
	return isRailPart(part)
end

function RailMemory.refreshBudgeted(_scanBudget)
	local now = time()
	if now - RailMemory.LastRefreshAt < RESCAN_COOLDOWN then
		return
	end
	RailMemory.LastRefreshAt = now
	pruneDead()

	observeRoots(getRailRoots())
end

function RailMemory.getNearbyRails(origin, radius)
	RailMemory.refreshBudgeted()
	pruneDead()

	local entries = SpatialIndex.query(RailMemory.Index, origin, tonumber(radius) or DEFAULT_QUERY_RADIUS)
	for _, entry in ipairs(entries) do
		local part = entry.Part
		if isAlive(part) then
			entry.Position = part.Position
			entry.CFrame = part.CFrame
			entry.Size = part.Size
			entry.Direction = part.CFrame.LookVector
			SpatialIndex.insert(RailMemory.Index, getRailId(part), entry, part.Position)
		end
	end

	return entries
end

function RailMemory.clear()
	for root in pairs(RailMemory.ObservedRoots) do
		disconnectRoot(root)
	end
	SpatialIndex.clear(RailMemory.Index)
	RailMemory.LastRefreshAt = -1000
	RailMemory.LastPruneAt = -1000
end

return RailMemory
