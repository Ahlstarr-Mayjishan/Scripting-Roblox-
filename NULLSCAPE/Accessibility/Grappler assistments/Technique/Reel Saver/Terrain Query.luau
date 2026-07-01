--!nocheck
-- [[
--  NULLSCAPE - Reel Saver Terrain Query
--  Terrain probe for upper-side grapple targets with a landable top.
-- ]]

local Workspace = game:GetService("Workspace")

local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")

local Probe = {}

local DEFAULT_SIDE_RANGE = 26
local DEFAULT_MIN_HEIGHT = 5
local DEFAULT_MAX_HEIGHT = 14
local DEFAULT_CLEARANCE = 5
local DEFAULT_LANDING_RADIUS = 2.75

local DECORATIVE_NAME_PATTERNS = {
	"billboard",
	"crate",
	"pipe",
	"window",
	"decal",
	"sign",
	"banner",
	"rail",
}

local function getNumber(value, fallback, minimum, maximum)
	local numberValue = tonumber(value) or fallback
	return math.clamp(numberValue, minimum, maximum)
end

local function horizontal(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function looksDecorative(part)
	if not part then
		return true
	end

	local lowerName = string.lower(part.Name)
	for _, pattern in ipairs(DECORATIVE_NAME_PATTERNS) do
		if string.find(lowerName, pattern, 1, true) then
			return true
		end
	end

	local size = part.Size
	if math.min(size.X, size.Y, size.Z) < 0.35 then
		return true
	end

	return false
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

local function isLandableTop(hitResult, rootPart, params, controller)
	if not hitResult or math.abs(hitResult.Normal.Y) > 0.45 then
		return nil
	end

	if looksDecorative(hitResult.Instance) then
		return nil
	end

	local clearance = getNumber(controller.GrappleReelSaverClearance, DEFAULT_CLEARANCE, 3, 12)
	local landingRadius = getNumber(controller.GrappleReelSaverLandingRadius, DEFAULT_LANDING_RADIUS, 1.5, 5)
	local probeOrigin = hitResult.Position + hitResult.Normal * 2 + Vector3.new(0, clearance, 0)
	local floorHit = Workspace:Raycast(probeOrigin, Vector3.new(0, -(clearance + 8), 0), params)
	if not floorHit or floorHit.Normal.Y < 0.65 then
		return nil
	end

	if looksDecorative(floorHit.Instance) then
		return nil
	end

	if floorHit.Position.Y < rootPart.Position.Y + 2.5 then
		return nil
	end

	local landingNormal = floorHit.Normal
	local sideA = horizontal(hitResult.Normal:Cross(Vector3.new(0, 1, 0)))
	local sideB = horizontal(sideA:Cross(landingNormal))
	local landingChecks = {
		Vector3.new(0, 0, 0),
		sideA * landingRadius,
		-sideA * landingRadius,
		sideB * landingRadius,
		-sideB * landingRadius,
	}

	for _, offset in ipairs(landingChecks) do
		local sampleOrigin = floorHit.Position + offset + Vector3.new(0, clearance, 0)
		local sampleFloor = Workspace:Raycast(sampleOrigin, Vector3.new(0, -(clearance + 4), 0), params)
		if not sampleFloor or sampleFloor.Normal.Y < 0.65 then
			return nil
		end

		if math.abs(sampleFloor.Position.Y - floorHit.Position.Y) > 2.5 then
			return nil
		end

		if looksDecorative(sampleFloor.Instance) then
			return nil
		end

		local headClearance =
			Workspace:Raycast(sampleFloor.Position + Vector3.new(0, 1, 0), Vector3.new(0, clearance, 0), params)
		if headClearance then
			return nil
		end
	end

	local rootClearance =
		Workspace:Raycast(rootPart.Position + Vector3.new(0, 2, 0), Vector3.new(0, clearance, 0), params)
	if rootClearance and rootClearance.Instance ~= hitResult.Instance then
		return nil
	end

	return floorHit
end

local function scoreCandidate(hitResult, floorHit, direction, rootPart)
	local heightGain = floorHit.Position.Y - rootPart.Position.Y
	local distance = (hitResult.Position - rootPart.Position).Magnitude
	local facingBonus = horizontal(rootPart.CFrame.LookVector):Dot(direction) * 4
	return heightGain * 4 + facingBonus - distance
end

function Probe.find(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	if not rootPart then
		return nil
	end

	TerrainMemory.ensureScanned(false)

	local params = makeParams(rootPart)
	local sideRange = getNumber(controller.GrappleReelSaverSideRange, DEFAULT_SIDE_RANGE, 8, 60)
	local minHeight = getNumber(controller.GrappleReelSaverMinHeight, DEFAULT_MIN_HEIGHT, 3, 18)
	local maxHeight = getNumber(controller.GrappleReelSaverMaxHeight, DEFAULT_MAX_HEIGHT, minHeight + 1, 28)
	local look = horizontal(rootPart.CFrame.LookVector)
	local right = horizontal(rootPart.CFrame.RightVector)

	local best = nil
	local bestScore = -math.huge
	for _, direction in ipairs({ look, right, -right, -look }) do
		for height = minHeight, maxHeight, 2 do
			local origin = rootPart.Position + Vector3.new(0, height, 0)
			local hit = Workspace:Raycast(origin, direction * sideRange, params)
			local floor = isLandableTop(hit, rootPart, params, controller)
			if floor then
				local score = scoreCandidate(hit, floor, direction, rootPart)
				if score > bestScore then
					bestScore = score
					best = {
						Hit = hit,
						Floor = floor,
					}
				end
			end
		end
	end

	return best
end

return Probe
