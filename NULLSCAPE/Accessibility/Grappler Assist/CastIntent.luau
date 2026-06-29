--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Cast Intent
--  Isolates cursor ray, native cast intent, and short-lived memory bypass policy.
-- ]]

local CastIntent = {}

function CastIntent.newState()
	return {
		FreshCursorCastUntil = 0,
	}
end

function CastIntent.clear(state)
	if state then
		state.FreshCursorCastUntil = 0
	end
end

function CastIntent.markFreshCursorCast(state, window)
	if not state then
		return
	end

	state.FreshCursorCastUntil = time() + math.max(tonumber(window) or 0, 0)
end

function CastIntent.shouldUseFreshCursor(state)
	return state and time() <= (state.FreshCursorCastUntil or 0)
end

function CastIntent.getMouseUnitRay(deps)
	local Players = deps and deps.Players
	local player = Players and Players.LocalPlayer
	if not player then
		return nil
	end

	local ok, mouse = pcall(function()
		return player:GetMouse()
	end)
	if not ok or not mouse then
		return nil
	end

	local unitRay = mouse.UnitRay
	if not unitRay then
		return nil
	end

	return unitRay
end

function CastIntent.getPartScreenFocus(camera, part, anchor, useCursorRay)
	if not (camera and part and part.Parent and part:IsA("BasePart")) then
		return nil, nil
	end

	local viewportScale = math.max(camera.ViewportSize.X, camera.ViewportSize.Y)
	local bestScore = math.huge
	local bestPosition = nil
	local half = part.Size * 0.5
	local cframe = part.CFrame
	local samples = {
		Vector3.new(0, 0, 0),
		Vector3.new(half.X, 0, 0),
		Vector3.new(-half.X, 0, 0),
		Vector3.new(0, half.Y, 0),
		Vector3.new(0, -half.Y, 0),
		Vector3.new(0, 0, half.Z),
		Vector3.new(0, 0, -half.Z),
		Vector3.new(half.X, half.Y, half.Z),
		Vector3.new(half.X, half.Y, -half.Z),
		Vector3.new(half.X, -half.Y, half.Z),
		Vector3.new(half.X, -half.Y, -half.Z),
		Vector3.new(-half.X, half.Y, half.Z),
		Vector3.new(-half.X, half.Y, -half.Z),
		Vector3.new(-half.X, -half.Y, half.Z),
		Vector3.new(-half.X, -half.Y, -half.Z),
	}

	if useCursorRay then
		local ray = camera:ViewportPointToRay(anchor.X, anchor.Y)
		local direction = ray.Direction.Unit
		local toCenter = part.Position - ray.Origin
		local along = math.max(0, toCenter:Dot(direction))
		local projected = ray.Origin + direction * along
		local localProjected = cframe:PointToObjectSpace(projected)
		table.insert(
			samples,
			Vector3.new(
				math.clamp(localProjected.X, -half.X, half.X),
				math.clamp(localProjected.Y, -half.Y, half.Y),
				math.clamp(localProjected.Z, -half.Z, half.Z)
			)
		)
	end

	for _, localPoint in ipairs(samples) do
		local worldPoint = cframe:PointToWorldSpace(localPoint)
		local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPoint)
		if onScreen and viewportPoint.Z > 0 then
			local score = (Vector2.new(viewportPoint.X, viewportPoint.Y) - anchor).Magnitude / viewportScale
			if score < bestScore then
				bestScore = score
				bestPosition = worldPoint
			end
		end
	end

	if bestPosition then
		return bestScore, bestPosition
	end

	return nil, nil
end

function CastIntent.getNativeCursorResult(deps, grapple)
	local Workspace = deps and deps.Workspace
	local getAssistRange = deps and deps.getAssistRange
	local getScreenAnchor = deps and deps.getScreenAnchor
	local getCameraScreenScore = deps and deps.getCameraScreenScore
	local rootPart = grapple and grapple.RootPart
	local camera = Workspace and Workspace.CurrentCamera
	if not (Workspace and grapple and rootPart and camera and grapple.grappleParams) then
		return nil, nil, nil
	end
	if not (getAssistRange and getScreenAnchor and getCameraScreenScore) then
		return nil, nil, nil
	end

	local unitRay = CastIntent.getMouseUnitRay(deps)
	if not unitRay then
		return nil, nil, nil
	end

	local cameraHit = Workspace:Raycast(unitRay.Origin, unitRay.Direction.Unit * 2048, grapple.grappleParams)
	if not cameraHit then
		return nil, unitRay.Direction.Unit, nil
	end

	local offset = cameraHit.Position - rootPart.Position
	if offset.Magnitude <= 0 or offset.Magnitude > getAssistRange(grapple, false) then
		return nil, unitRay.Direction.Unit, nil
	end

	local result = Workspace:Raycast(rootPart.Position, offset, grapple.grappleParams)
	if not result then
		return nil, unitRay.Direction.Unit, nil
	end

	local anchor = getScreenAnchor(camera, "Closest To Cursor")
	local screenScore = getCameraScreenScore(camera, result.Position, anchor)
	return result, unitRay.Direction.Unit, screenScore
end

function CastIntent.shouldUseCursorPreview(grapple, forceRefresh)
	local movement = grapple and grapple.Movement
	return forceRefresh == true
		and grapple
		and movement
		and grapple.specialHeld == true
		and movement.grappling ~= true
end

function CastIntent.getCursorPreviewResult(deps, grapple, forceRefresh)
	if not CastIntent.shouldUseCursorPreview(grapple, forceRefresh) then
		return nil
	end

	return CastIntent.getNativeCursorResult(deps, grapple)
end

return CastIntent
