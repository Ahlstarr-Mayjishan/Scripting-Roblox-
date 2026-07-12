--!nocheck
--[[
	NULLSCAPE - Exit Corridor Guard
	Penalizes targets and releases that would immediately send a fast player into geometry.
]]

local Workspace = game:GetService("Workspace")

local Guard = {}

local function getVelocity(rootPart)
	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or Vector3.zero
end

local function getBrakeThreshold(controller)
	return math.clamp(tonumber(controller and controller.GrappleBrakeProfileSpeed) or 300, 200, 500)
end

function Guard.evaluateCast(grapple, hit, controller)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and hit and hit.Position and grapple.grappleParams) then
		return { Penalty = 0, Reason = "unavailable" }
	end

	local velocity = getVelocity(rootPart)
	local speed = velocity.Magnitude
	local threshold = getBrakeThreshold(controller)
	if speed < threshold then
		return { Penalty = 0, Reason = "below-brake-threshold" }
	end

	local offset = hit.Position - rootPart.Position
	if offset.Magnitude <= 0.001 then
		return { Penalty = 28, Reason = "zero-exit" }
	end

	local direction = offset.Unit
	local velocityDirection = velocity.Unit
	local alignment = velocityDirection:Dot(direction)
	local penalty = alignment < 0.15 and 32 or alignment < 0.45 and 14 or 0
	local probeDistance = math.clamp(speed * 0.13, 16, 52)
	local corridorHit = Workspace:Raycast(rootPart.Position, velocityDirection * probeDistance, grapple.grappleParams)
	if corridorHit and corridorHit.Instance ~= hit.Instance then
		penalty += 26
	end

	return {
		Penalty = penalty,
		Reason = penalty > 0 and "high-speed-brake" or "high-speed-flow",
		Speed = speed,
		Alignment = alignment,
	}
end

function Guard.canRelease(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and grapple and grapple.grappleParams) then
		return true, "unavailable"
	end

	local velocity = getVelocity(rootPart)
	local speed = velocity.Magnitude
	if speed < getBrakeThreshold(controller) then
		return true, "below-brake-threshold"
	end

	local direction = velocity.Magnitude > 0.001 and velocity.Unit or Vector3.zero
	local hit = direction.Magnitude > 0
		and Workspace:Raycast(rootPart.Position, direction * math.clamp(speed * 0.1, 12, 42), grapple.grappleParams)
	if
		hit
		and grapple.grapplePart
		and (hit.Instance == grapple.grapplePart or hit.Instance:IsDescendantOf(grapple.grapplePart))
	then
		return true, "current-anchor"
	end
	return hit == nil, hit and "exit-blocked" or "clear"
end

return Guard
