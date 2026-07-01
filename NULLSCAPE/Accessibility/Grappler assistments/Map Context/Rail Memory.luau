--!nocheck
-- [[
--  NULLSCAPE - Map Context Rail Memory
--  Runtime cache for Highrise grind rails and other _RailPart paths.
-- ]]

local Workspace = game:GetService("Workspace")

local SpatialIndex = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Spatial Index.luau")

local BUCKET_SIZE = 128
local DEFAULT_SCAN_BUDGET = 450
local DEFAULT_QUERY_RADIUS = 110
local RESCAN_COOLDOWN = 0.75

local RailMemory = {
	Index = SpatialIndex.new(BUCKET_SIZE),
	ScanCursor = 1,
	LastRefreshAt = -1000,
}

local function isAlive(instance)
	return instance and instance.Parent ~= nil and instance:IsDescendantOf(Workspace)
end

local function isRailPart(part)
	return part and part:IsA("BasePart") and part.Name == "_RailPart"
end

local function getRailId(part)
	return part:GetDebugId(0)
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
	for id, entry in pairs(RailMemory.Index.Entries) do
		if not isAlive(entry.Part) then
			SpatialIndex.remove(RailMemory.Index, id)
		end
	end
end

local function collectDescendants()
	local descendants = {}
	for _, root in ipairs(getRailRoots()) do
		if isRailPart(root) then
			table.insert(descendants, root)
		end

		for _, descendant in ipairs(root:GetDescendants()) do
			table.insert(descendants, descendant)
		end
	end

	return descendants
end

function RailMemory.isRailPart(part)
	return isRailPart(part)
end

function RailMemory.refreshBudgeted(scanBudget)
	local now = time()
	if now - RailMemory.LastRefreshAt < RESCAN_COOLDOWN then
		return
	end
	RailMemory.LastRefreshAt = now
	pruneDead()

	local descendants = collectDescendants()
	if #descendants == 0 then
		RailMemory.ScanCursor = 1
		return
	end

	local budget = math.clamp(tonumber(scanBudget) or DEFAULT_SCAN_BUDGET, 50, 1800)
	for _ = 1, math.min(budget, #descendants) do
		if RailMemory.ScanCursor > #descendants then
			RailMemory.ScanCursor = 1
		end

		local descendant = descendants[RailMemory.ScanCursor]
		RailMemory.ScanCursor += 1
		if isRailPart(descendant) then
			rememberRail(descendant)
		end
	end
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
	SpatialIndex.clear(RailMemory.Index)
	RailMemory.ScanCursor = 1
	RailMemory.LastRefreshAt = -1000
end

return RailMemory
