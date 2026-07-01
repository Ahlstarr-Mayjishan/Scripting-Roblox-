--!nocheck
-- [[
--  NULLSCAPE - Threat Context Dodge Planner
--  Chooses a terrain-aware horizontal dodge direction.
-- ]]

local Workspace = game:GetService("Workspace")

local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")

local DodgePlanner = {}

local FLOOR_CHECK_HEIGHT = 4
local FLOOR_CHECK_DEPTH = 18
local WALL_CLEARANCE_HEIGHT = 1.6

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function safeUnit(vector, fallback)
	local flat = flatten(vector)
	if flat.Magnitude > 0.05 then
		return flat.Unit
	end

	return fallback or Vector3.new(0, 0, -1)
end

local function rotateY(vector, radians)
	local c = math.cos(radians)
	local s = math.sin(radians)
	return Vector3.new(vector.X * c - vector.Z * s, 0, vector.X * s + vector.Z * c)
end

local function makeParams(rootPart)
	local params = RaycastParams.new()
	params.IgnoreWater = true

	local roots = TerrainMemory.getMapRoots()
	if #roots > 0 and roots[1] ~= Workspace then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = roots
		return params
	end

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		rootPart and rootPart.Parent,
		Workspace.CurrentCamera,
	}
	return params
end

local function scoreDirection(rootPart, direction, distance, params)
	local rootPosition = rootPart.Position
	local wallOrigin = rootPosition + Vector3.new(0, WALL_CLEARANCE_HEIGHT, 0)
	local wallHit = Workspace:Raycast(wallOrigin, direction * distance, params)
	if wallHit and (wallHit.Position - wallOrigin).Magnitude < math.max(3, distance * 0.55) then
		return -math.huge
	end

	local landing = rootPosition + direction * distance
	local floorOrigin = landing + Vector3.new(0, FLOOR_CHECK_HEIGHT, 0)
	local floorHit = Workspace:Raycast(floorOrigin, Vector3.new(0, -FLOOR_CHECK_DEPTH, 0), params)
	if not floorHit then
		return -35
	end

	local score = 20
	score -= math.max(0, rootPosition.Y - floorHit.Position.Y - 6) * 2
	score += math.clamp(floorHit.Normal.Y, 0, 1) * 12
	return score
end

function DodgePlanner.choose(rootPart, desiredDirection, options)
	if not (rootPart and rootPart.Parent) then
		return nil
	end

	TerrainMemory.ensureScanned(false)

	options = options or {}
	local distance = math.clamp(tonumber(options.Distance) or 10, 4, 24)
	local baseDirection = safeUnit(desiredDirection, safeUnit(rootPart.CFrame.RightVector))
	local params = makeParams(rootPart)
	local bestDirection = nil
	local bestScore = -math.huge

	for _, angle in ipairs({ 0, math.rad(35), math.rad(-35), math.rad(75), math.rad(-75), math.pi }) do
		local direction = safeUnit(rotateY(baseDirection, angle), baseDirection)
		local score = scoreDirection(rootPart, direction, distance, params)
		score += direction:Dot(baseDirection) * 18

		if score > bestScore then
			bestScore = score
			bestDirection = direction
		end
	end

	if bestScore <= -math.huge / 2 then
		return nil
	end

	return bestDirection, bestScore
end

return DodgePlanner
