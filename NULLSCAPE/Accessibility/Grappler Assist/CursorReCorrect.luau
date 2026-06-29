--!nocheck
-- [[
--  NULLSCAPE - Grappler Cursor ReCorrect
--  Finds a grapple-safe target near the player's cursor instead of relying on a
--  single native ray or a single focus point on known targets.
-- ]]

local CursorReCorrect = {}

local DEFAULT_OFFSETS = {
	{ 0, 0 },
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
}

local SurfaceScanCache = {
	At = 0,
	RootPosition = nil,
	ScreenAnchorX = nil,
	ScreenAnchorY = nil,
	CursorLimit = nil,
	DriveMode = nil,
	HasValue = false,
	Result = nil,
	Decision = nil,
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

local function getCastOrigin(deps, grapple)
	if deps and deps.getCastOrigin then
		local origin = deps.getCastOrigin(grapple)
		if typeof(origin) == "Vector3" then
			return origin
		end
	end

	local character = grapple and grapple.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end

	local rootPart = grapple and grapple.RootPart
	return rootPart and rootPart.Position or nil
end

local function getInsetAxis(value, margin)
	if value <= margin then
		return value
	end
	return value - margin
end

function CursorReCorrect.getTargetSamplePositions(cfg, part, preferredPosition)
	local positions = {}
	addUniquePosition(positions, preferredPosition)
	if not (part and part:IsA("BasePart")) then
		return positions
	end

	local half = part.Size * 0.5
	local cframe = part.CFrame
	local safeMargin = cfg and cfg.CURSOR_TARGET_SAFE_MARGIN or 0.35
	local insetX = getInsetAxis(half.X, safeMargin)
	local insetY = getInsetAxis(half.Y, safeMargin)
	local insetZ = getInsetAxis(half.Z, safeMargin)
	addUniquePosition(positions, part.Position)

	local samples = {
		Vector3.new(insetX, 0, 0),
		Vector3.new(-insetX, 0, 0),
		Vector3.new(0, insetY, 0),
		Vector3.new(0, -insetY, 0),
		Vector3.new(0, 0, insetZ),
		Vector3.new(0, 0, -insetZ),
		Vector3.new(insetX, insetY, insetZ),
		Vector3.new(insetX, insetY, -insetZ),
		Vector3.new(insetX, -insetY, insetZ),
		Vector3.new(insetX, -insetY, -insetZ),
		Vector3.new(-insetX, insetY, insetZ),
		Vector3.new(-insetX, insetY, -insetZ),
		Vector3.new(-insetX, -insetY, insetZ),
		Vector3.new(-insetX, -insetY, -insetZ),
	}

	local limit = cfg and cfg.CURSOR_TARGET_SAMPLE_LIMIT or 18
	for _, localPoint in ipairs(samples) do
		if #positions >= limit then
			break
		end
		addUniquePosition(positions, cframe:PointToWorldSpace(localPoint))
	end

	return positions
end

local function isTargetHit(result, targetInstance, targetPart)
	if not (result and result.Instance) then
		return false
	end
	return result.Instance == targetPart or result.Instance:IsDescendantOf(targetInstance)
end

local function lineClear(deps, grapple, candidate, part, targetPosition, maxRange)
	local workspace = deps and deps.Workspace
	local origin = getCastOrigin(deps, grapple)
	if not (workspace and origin and grapple and grapple.grappleParams) then
		if deps and deps.isLineClear then
			return deps.isLineClear(grapple, candidate.Instance, part, targetPosition, maxRange)
		end
		return nil, nil
	end

	local offset = targetPosition - origin
	local distance = offset.Magnitude
	if distance <= 0 or distance > maxRange then
		return nil, nil
	end

	local result = workspace:Raycast(origin, offset, grapple.grappleParams)
	if isTargetHit(result, candidate.Instance, part) then
		return result, distance
	end

	return nil, nil
end

local function getCursorAnchor(deps, camera)
	if deps.getScreenAnchor then
		return deps.getScreenAnchor(camera, "Closest To Cursor")
	end
	return camera.ViewportSize * 0.5
end

local function getAnchorQualityScore(deps, grapple, result, distance)
	local cfg = deps.CFG
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and result and typeof(result.Position) == "Vector3") then
		return 0, "NoAnchorModel"
	end

	local targetPosition = result.Position
	local offset = targetPosition - rootPart.Position
	local vertical = offset.Y
	local score = 0

	local minDistance = cfg and cfg.CURSOR_OPTIMAL_DISTANCE_MIN or 26
	local idealDistance = cfg and cfg.CURSOR_OPTIMAL_DISTANCE_IDEAL or 72
	local maxDistance = cfg and cfg.CURSOR_OPTIMAL_DISTANCE_MAX or 120
	if distance < minDistance then
		score += (minDistance - distance) * 0.9
	elseif distance <= maxDistance then
		score += math.abs(distance - idealDistance) * 0.12
	else
		score += (distance - maxDistance) * 0.8
	end

	local minVertical = cfg and cfg.CURSOR_OPTIMAL_VERTICAL_MIN or -18
	local idealVertical = cfg and cfg.CURSOR_OPTIMAL_VERTICAL_IDEAL or 24
	local maxVertical = cfg and cfg.CURSOR_OPTIMAL_VERTICAL_MAX or 72
	if vertical < minVertical then
		score += (minVertical - vertical) * 1.1
	elseif vertical > maxVertical then
		score += (vertical - maxVertical) * 0.45
	else
		local verticalWindow = math.max(maxVertical - minVertical, 1)
		local idealRatio = 1 - math.min(math.abs(vertical - idealVertical) / verticalWindow, 1)
		score -= idealRatio * 12
	end

	local normal = result.Normal
	if typeof(normal) == "Vector3" then
		if normal.Y > 0.65 then
			score += cfg and cfg.CURSOR_OPTIMAL_FLOOR_PENALTY or 42
		elseif math.abs(normal.Y) <= 0.55 then
			score += cfg and cfg.CURSOR_OPTIMAL_WALL_BONUS or -16
		elseif normal.Y < -0.25 and vertical > 8 then
			score += cfg and cfg.CURSOR_OPTIMAL_HIGH_UNDERSIDE_BONUS or -10
		end
	end

	if deps.getAssistIntentDirections and deps.getAssistIntentPenalty then
		local inputDirection, velocityDirection = deps.getAssistIntentDirections(grapple)
		score += deps.getAssistIntentPenalty(rootPart, targetPosition, inputDirection, velocityDirection) * 0.28
		if deps.getWrongAnchorPenalty then
			score += deps.getWrongAnchorPenalty(rootPart, targetPosition, inputDirection, velocityDirection, false) * 0.25
		end
	end

	if deps.getRouteAssistBonus then
		score += deps.getRouteAssistBonus(rootPart, targetPosition) * 0.45
	end

	if deps.isVoidRescueActive and deps.isVoidRescueActive(grapple) then
		if vertical >= 0 then
			score -= 18
		else
			score += math.abs(vertical) * 0.8
		end
	end

	return score, "OptimalAnchor"
end

local function scoreCandidateSample(deps, grapple, result, distance, samplePosition, preferredPosition, candidate)
	local cfg = deps.CFG
	local score = distance * (cfg and cfg.CURSOR_INTENT_DISTANCE_WEIGHT or 0.015)
	if typeof(samplePosition) == "Vector3" and typeof(preferredPosition) == "Vector3" then
		score += (samplePosition - preferredPosition).Magnitude * 0.18
	end
	local anchorScore = getAnchorQualityScore(deps, grapple, result, distance)
	if deps.getAnchorMemoryScore and candidate then
		score += deps.getAnchorMemoryScore(candidate.Instance) or 0
	end
	return score + anchorScore
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
	local bestResult = nil
	local bestDistance = nil
	local bestPosition = preferredPosition
	local bestScore = math.huge
	for _, position in ipairs(CursorReCorrect.getTargetSamplePositions(cfg, part, preferredPosition)) do
		local result, distance = lineClear(deps, grapple, candidate, part, position, maxRange)
		if result and (not deps.isUsableResult or deps.isUsableResult(grapple, result)) then
			if
				not deps.isPathSafeForHitbox
				or deps.isPathSafeForHitbox(grapple, candidate.Instance, part, result.Position, maxRange)
			then
				local score = scoreCandidateSample(deps, grapple, result, distance, position, preferredPosition, candidate)
				if score < bestScore then
					bestResult = result
					bestDistance = distance
					bestPosition = result.Position
					bestScore = score
				end
			end
		end
	end

	return bestResult, bestDistance, bestPosition
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
	local anchorScore, anchorReason = getAnchorQualityScore(deps, grapple, result, distance)
	return screenScore * screenWeight + distance * distanceWeight + terrainScore + anchorScore, reason .. "/" .. anchorReason
end

local function getCachedSurfaceScan(cfg, rootPart, screenAnchor, cursorLimit, driveMode, returnDecision)
	local now = time()
	local interval = cfg and cfg.CURSOR_RECORRECT_SCAN_INTERVAL or 0.05
	if not SurfaceScanCache.HasValue or now - (SurfaceScanCache.At or 0) > interval then
		return false, nil
	end

	local result = SurfaceScanCache.Result
	if result and not (result.Instance and result.Instance.Parent) then
		return false, nil
	end

	local rootPosition = SurfaceScanCache.RootPosition
	local moveEpsilon = cfg and cfg.CURSOR_RECORRECT_CACHE_MOVE_EPSILON or 3
	if not rootPosition or (rootPart.Position - rootPosition).Magnitude > moveEpsilon then
		return false, nil
	end

	local screenEpsilon = cfg and cfg.CURSOR_RECORRECT_CACHE_SCREEN_EPSILON or 8
	if
		math.abs((SurfaceScanCache.ScreenAnchorX or 0) - screenAnchor.X) > screenEpsilon
		or math.abs((SurfaceScanCache.ScreenAnchorY or 0) - screenAnchor.Y) > screenEpsilon
		or math.abs((SurfaceScanCache.CursorLimit or 0) - cursorLimit) > 0.001
		or SurfaceScanCache.DriveMode ~= driveMode
	then
		return false, nil
	end

	if returnDecision then
		return true, SurfaceScanCache.Decision
	end
	return true, result
end

local function setCachedSurfaceScan(rootPart, screenAnchor, cursorLimit, driveMode, decision)
	SurfaceScanCache.At = time()
	SurfaceScanCache.RootPosition = rootPart.Position
	SurfaceScanCache.ScreenAnchorX = screenAnchor.X
	SurfaceScanCache.ScreenAnchorY = screenAnchor.Y
	SurfaceScanCache.CursorLimit = cursorLimit
	SurfaceScanCache.DriveMode = driveMode
	SurfaceScanCache.HasValue = true
	SurfaceScanCache.Result = decision and decision.Result or nil
	SurfaceScanCache.Decision = decision
end

function CursorReCorrect.scanSurfaceAroundCursor(deps, grapple, options)
	local workspace = deps and deps.Workspace
	local camera = workspace and workspace.CurrentCamera
	local rootPart = grapple and grapple.RootPart
	local originPosition = getCastOrigin(deps, grapple)
	if not (workspace and camera and rootPart and originPosition and grapple and grapple.grappleParams) then
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
	local cacheHit, cached = getCachedSurfaceScan(cfg, rootPart, screenAnchor, cursorLimit, driveMode, returnDecision)
	if cacheHit then
		return cached
	end

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

		local screenPointX = screenAnchor.X + offsetX * viewportSize.X
		local screenPointY = screenAnchor.Y + offsetY * viewportSize.Y
		if screenPointX < 0 or screenPointY < 0 or screenPointX > viewportSize.X or screenPointY > viewportSize.Y then
			continue
		end

		local ray = camera:ViewportPointToRay(screenPointX, screenPointY)
		local cameraHit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 2048, grapple.grappleParams)
		if not cameraHit then
			continue
		end

		local offsetToHit = cameraHit.Position - originPosition
		local distance = offsetToHit.Magnitude
		if distance <= 0 or distance > maxRange then
			continue
		end

		local directHit = workspace:Raycast(originPosition, offsetToHit, grapple.grappleParams)
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
				if screenScore <= 0.04 and score <= (cfg and cfg.CURSOR_RECORRECT_EARLY_SCORE or 12) then
					break
				end
			end
		end
	end

	local decision = bestResult and {
		Result = bestResult,
		Instance = bestResult.Instance,
		Name = nil,
		Position = bestResult.Position,
		Distance = bestDistance,
		ScreenScore = bestScreenScore,
		Score = bestScore,
		Reason = bestReason or "CursorSurfaceDetector",
	} or nil
	setCachedSurfaceScan(rootPart, screenAnchor, cursorLimit, driveMode, decision)

	if returnDecision then
		return decision
	end

	return bestResult
end

return CursorReCorrect
