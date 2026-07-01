--!nocheck
-- [[
--  NULLSCAPE - Map Context Ray Sampler
--  Samples stable terrain directions around the player.
-- ]]

local Workspace = game:GetService("Workspace")

local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")

local RaySampler = {}

local DEFAULT_SIDE_RANGE = 28
local DEFAULT_FLOOR_RANGE = 80
local HEIGHT_OFFSETS = { -2.4, 0, 2.4 }

local function getNumber(value, fallback, minimum, maximum)
	local numberValue = tonumber(value) or fallback
	return math.clamp(numberValue, minimum, maximum)
end

local function getCharacter(rootPart)
	return rootPart and rootPart.Parent
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
		getCharacter(rootPart),
		Workspace.CurrentCamera,
	}
	return params
end

local function toHitInfo(result, origin, direction, label)
	if not result then
		return nil
	end

	return {
		Label = label,
		Instance = result.Instance,
		Position = result.Position,
		Normal = result.Normal,
		Distance = (result.Position - origin).Magnitude,
		Direction = direction,
		SampledAt = time(),
	}
end

local function cast(origin, direction, range, params, label)
	local result = Workspace:Raycast(origin, direction.Unit * range, params)
	return toHitInfo(result, origin, direction.Unit, label)
end

local function castMultiHeight(rootPosition, direction, range, params, label)
	local bestHit = nil

	for _, offsetY in ipairs(HEIGHT_OFFSETS) do
		local origin = rootPosition + Vector3.new(0, offsetY, 0)
		local hit = cast(origin, direction, range, params, label)
		if hit and (not bestHit or hit.Distance < bestHit.Distance) then
			bestHit = hit
		end
	end

	return bestHit
end

local function horizontal(unit)
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

function RaySampler.sampleFourSides(rootPart, options)
	if not (rootPart and rootPart.Parent) then
		return nil
	end

	TerrainMemory.ensureScanned(false)

	options = options or {}
	local sideRange = getNumber(options.SideRange, DEFAULT_SIDE_RANGE, 6, 120)
	local floorRange = getNumber(options.FloorRange, DEFAULT_FLOOR_RANGE, 12, 260)
	local params = makeParams(rootPart)
	local rootPosition = rootPart.Position
	local look = horizontal(rootPart.CFrame.LookVector)
	local right = horizontal(rootPart.CFrame.RightVector)

	local playerSides = {
		front = castMultiHeight(rootPosition, look, sideRange, params, "front"),
		back = castMultiHeight(rootPosition, -look, sideRange, params, "back"),
		right = castMultiHeight(rootPosition, right, sideRange, params, "right"),
		left = castMultiHeight(rootPosition, -right, sideRange, params, "left"),
	}

	local worldSides = {
		posX = castMultiHeight(rootPosition, Vector3.new(1, 0, 0), sideRange, params, "posX"),
		negX = castMultiHeight(rootPosition, Vector3.new(-1, 0, 0), sideRange, params, "negX"),
		posZ = castMultiHeight(rootPosition, Vector3.new(0, 0, 1), sideRange, params, "posZ"),
		negZ = castMultiHeight(rootPosition, Vector3.new(0, 0, -1), sideRange, params, "negZ"),
	}

	local floor = cast(rootPosition, Vector3.new(0, -1, 0), floorRange, params, "floor")
	local ceiling = cast(rootPosition, Vector3.new(0, 1, 0), floorRange, params, "ceiling")
	local voidInfo = TerrainMemory.getVoidInfo()

	return {
		RootPosition = rootPosition,
		PlayerSides = playerSides,
		WorldSides = worldSides,
		Floor = floor,
		Ceiling = ceiling,
		Void = voidInfo,
		NearVoid = voidInfo and rootPosition.Y - voidInfo.Y <= getNumber(options.VoidHeight, 45, 10, 160) or false,
		SampledAt = time(),
	}
end

function RaySampler.getClosestWall(context)
	if not context then
		return nil
	end

	local closest = nil
	for _, group in ipairs({ context.PlayerSides, context.WorldSides }) do
		for _, hit in pairs(group) do
			if hit and math.abs(hit.Normal.Y) < 0.45 and (not closest or hit.Distance < closest.Distance) then
				closest = hit
			end
		end
	end

	return closest
end

return RaySampler
