--!nocheck
--[[
	NULLSCAPE - Special Anchor Capture
	Builds a forgiving, line-of-aim capture point for native special grapple anchors.
	The returned hit is always a real workspace raycast result, so Grapple.Start
	keeps its native target, distance, and special-action behavior.
]]

local Workspace = game:GetService("Workspace")

local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")

local Capture = {}

local HIT_OVERSHOOT = 2
local MIN_CAPTURE_RADIUS = 3.5

local EXTRA_RADIUS = {
	JumpPad = 6,
	GrapplePoint = 4,
	TriaOrb = 4,
	Bell = 3,
}

local function getNearestPoint(part, worldPoint)
	local localPoint = part.CFrame:PointToObjectSpace(worldPoint)
	local halfSize = part.Size * 0.5
	return part.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(localPoint.X, -halfSize.X, halfSize.X),
			math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
			math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
		)
	)
end

local function getRadius(part, anchorName)
	local halfSize = part.Size * 0.5
	return math.clamp(halfSize.Magnitude + (EXTRA_RADIUS[anchorName] or 3), MIN_CAPTURE_RADIUS, 16)
end

function Capture.resolve(part, origin, aimDirection, grappleParams, manualAngle)
	if
		not (
			part
			and part:IsA("BasePart")
			and part.Parent
			and part.CanQuery ~= false
			and typeof(origin) == "Vector3"
			and typeof(aimDirection) == "Vector3"
			and aimDirection.Magnitude > 0.001
			and grappleParams
		)
	then
		return nil
	end

	local anchorName = SpecialAnchors and SpecialAnchors.getName(part)
	if not anchorName then
		return nil
	end

	local direction = aimDirection.Unit
	local centerOffset = part.Position - origin
	local forwardDistance = centerOffset:Dot(direction)
	if forwardDistance <= 3 then
		return nil
	end

	local captureAngle = SpecialAnchors.getCaptureAngle(anchorName)
	if manualAngle then
		-- Manual casts stay deliberate, but special anchors should not require pixel-perfect aim.
		captureAngle = math.max(math.min(captureAngle, 52), manualAngle)
	end

	local centerDirection = centerOffset.Unit
	if direction:Dot(centerDirection) < math.cos(math.rad(captureAngle)) then
		return nil
	end

	local aimPoint = origin + direction * forwardDistance
	local targetPoint = getNearestPoint(part, aimPoint)
	local missDistance = (targetPoint - aimPoint).Magnitude
	local radius = getRadius(part, anchorName)
	if missDistance > radius then
		return nil
	end

	local offset = targetPoint - origin
	local distance = offset.Magnitude
	if distance <= 3 then
		return nil
	end

	local hit = Workspace:Raycast(origin, offset.Unit * (distance + HIT_OVERSHOOT), grappleParams)
	if not (hit and hit.Instance) then
		return nil
	end

	local instance = hit.Instance
	if not (instance == part or instance:IsDescendantOf(part) or part:IsDescendantOf(instance)) then
		return nil
	end

	return hit, offset.Unit, distance, direction:Dot(offset.Unit), anchorName
end

return Capture
