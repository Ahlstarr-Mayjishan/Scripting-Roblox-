--!nocheck
-- [[
--  NULLSCAPE - Grappler Cursor ReCorrect
--  Finds a grapple-safe target near the player's cursor instead of relying on a
--  single native ray or a single focus point on known targets.
-- ]]

local CursorReCorrect = {}

local DEFAULT_OFFSETS = {
	{ 0, 0 },
	{ 0.018, 0 },
	{ -0.018, 0 },
	{ 0, 0.018 },
	{ 0, -0.018 },
	{ 0.04, 0 },
	{ -0.04, 0 },
	{ 0, 0.04 },
	{ 0, -0.04 },
	{ 0.04, 0.04 },
	{ 0.04, -0.04 },
	{ -0.04, 0.04 },
	{ -0.04, -0.04 },
	{ 0.075, 0 },
	{ -0.075, 0 },
	{ 0, 0.075 },
	{ 0, -0.075 },
	{ 0.075, 0.075 },
	{ 0.075, -0.075 },
	{ -0.075, 0.075 },
	{ -0.075, -0.075 },
	{ 0.12, 0 },
	{ -0.12, 0 },
	{ 0, 0.12 },
	{ 0, -0.12 },
}

local function addUniquePosition(positions, position)
	if typeof(position) ~= "Vector3" then
		return
	end
	for _, existing in ipairs(positions) do
		if (existing - position).Magnitude <= 0.1 then
			return
		end
	end
	table.insert(positions, position)
end

function CursorReCorrect.getTargetSamplePositions(cfg, part, preferredPosition)
	local positions = {}
	addUniquePosition(positions, preferredPosition)
	if not (part and part:IsA("BasePart")) then
		return positions
	end

	local half = part.Size * 0.5
	local cframe = part.CFrame
	addUniquePosition(positions, part.Position)

	local samples = {
		Vector3.new(half.X, 0, 0),
		Vector3.new(-half.X, 0, 0),
		Vector3.new(0, half.Y, 0),
		Vector3.new(0, -half.Y, 0),
		Vector3.new(0, 0, half.Z),
		Vector3.new(0, 0, -half.Z),
		Vector3.new(half.X, half.Y, half.Z),
		Vector3.new(half.X, half.Y, -half.Z),
		Vector3.new(-half.X, half.Y, half.Z),
		Vector3.new(-half.X, half.Y, -half.Z),
	}

	local limit = cfg and cfg.CURSOR_TARGET_SAMPLE_LIMIT or 9
	for _, localPoint in ipairs(samples) do
		if #positions >= limit then
			break
		end
		addUniquePosition(positions, cframe:PointToWorldSpace(localPoint))
	end

	return positions
end

function CursorReCorrect.findCandidateLineClear(deps, grapple, candidate, part, preferredPosition, maxRange, trySamples)
	if not (deps and deps.isLineClear and candidate) then
		return nil, nil, preferredPosition
	end

	if not trySamples then
		local result, distance = deps.isLineClear(grapple, candidate.Instance, part, preferredPosition, maxRange)
		return result, distance, preferredPosition
	end

	local cfg = deps.CFG
	for _, position in ipairs(CursorReCorrect.getTargetSamplePositions(cfg, part, preferredPosition)) do
		local result, distance = deps.isLineClear(grapple, candidate.Instance, part, position, maxRange)
		if result and (not deps.isUsableResult or deps.isUsableResult(grapple, result)) then
			return result, distance, position
		end
	end

	return nil, nil, preferredPosition
end

local function getCursorAnchor(deps, camera)
	if deps.getScreenAnchor then
		return deps.getScreenAnchor(camera, "Closest To Cursor")
	end
	return camera.ViewportSize * 0.5
end

local function scoreSurface(deps, grapple, result, screenScore, driveMode, distance)
	local cfg = deps.CFG
	local terrainScore = 0
	local reason = "CursorSurface"
	if deps.getTerrainSurfaceScore then
		terrainScore, reason = deps.getTerrainSurfaceScore(grapple, result, screenScore, driveMode)
	end

	local distanceWeight = cfg and cfg.CURSOR_INTENT_DISTANCE_WEIGHT or 0.015
	local screenWeight = cfg and cfg.CURSOR_INTENT_SCREEN_WEIGHT or 1000
	return screenScore * screenWeight + distance * distanceWeight + terrainScore, reason
end

function CursorReCorrect.scanSurfaceAroundCursor(deps, grapple, options)
	local workspace = deps and deps.Workspace
	local camera = workspace and workspace.CurrentCamera
	local rootPart = grapple and grapple.RootPart
	if not (workspace and camera and rootPart and grapple and grapple.grappleParams) then
		return nil
	end

	local cfg = deps.CFG
	local driveMode = typeof(options) == "table" and options.driveMode == true
	local returnDecision = typeof(options) == "table" and options.returnDecision == true
	local forceCursor = not (typeof(options) == "table") or options.forceCursor ~= false
	local maxRange = deps.getAssistRange(grapple, driveMode)
	local viewportSize = camera.ViewportSize
	local screenAnchor = forceCursor and getCursorAnchor(deps, camera) or viewportSize * 0.5
	local cursorLimit = typeof(options) == "table" and tonumber(options.cursorLimit) or nil
	cursorLimit = cursorLimit or (cfg and cfg.CURSOR_SURFACE_DETECTOR_LIMIT) or 0.24
	local maxSurfaceNormalY = cfg and cfg.CURSOR_RECORRECT_SURFACE_NORMAL_Y_MAX or 0.55

	local bestResult = nil
	local bestScore = math.huge
	local bestReason = nil
	local bestScreenScore = nil
	local bestDistance = nil

	for _, offset in ipairs(DEFAULT_OFFSETS) do
		local offsetX = offset[1]
		local offsetY = offset[2]
		local screenScore = math.sqrt(offsetX * offsetX + offsetY * offsetY)
		if screenScore > cursorLimit then
			continue
		end

		local screenPoint = screenAnchor + Vector2.new(offsetX * viewportSize.X, offsetY * viewportSize.Y)
		if screenPoint.X < 0 or screenPoint.Y < 0 or screenPoint.X > viewportSize.X or screenPoint.Y > viewportSize.Y then
			continue
		end

		local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
		local cameraHit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 2048, grapple.grappleParams)
		if not cameraHit then
			continue
		end

		local offsetToHit = cameraHit.Position - rootPart.Position
		local distance = offsetToHit.Magnitude
		if distance <= 0 or distance > maxRange then
			continue
		end

		local directHit = workspace:Raycast(rootPart.Position, offsetToHit, grapple.grappleParams)
		if
			directHit
			and (not directHit.Normal or directHit.Normal.Y <= maxSurfaceNormalY)
			and (not deps.isUsableResult or deps.isUsableResult(grapple, directHit))
			and (
				not deps.isPathSafeForHitbox
				or deps.isPathSafeForHitbox(grapple, directHit.Instance, directHit.Instance, directHit.Position, maxRange)
			)
		then
			local realScreenScore = screenScore
			if deps.getCameraScreenScore then
				realScreenScore = deps.getCameraScreenScore(camera, directHit.Position, screenAnchor) or screenScore
			end
			if realScreenScore > cursorLimit then
				continue
			end

			local score, reason = scoreSurface(deps, grapple, directHit, realScreenScore, driveMode, distance)
			if score < bestScore then
				bestResult = directHit
				bestScore = score
				bestReason = reason or "CursorSurface"
				bestScreenScore = realScreenScore
				bestDistance = distance
			end
		end
	end

	if returnDecision then
		return bestResult and {
			Result = bestResult,
			Instance = bestResult.Instance,
			Name = nil,
			Position = bestResult.Position,
			Distance = bestDistance,
			ScreenScore = bestScreenScore,
			Score = bestScore,
			Reason = bestReason or "CursorSurfaceDetector",
		} or nil
	end

	return bestResult
end

return CursorReCorrect
