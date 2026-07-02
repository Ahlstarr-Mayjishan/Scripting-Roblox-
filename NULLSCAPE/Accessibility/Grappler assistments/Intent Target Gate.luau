--!nocheck
--[[
	NULLSCAPE - Grappler Intent Target Gate
	Rejects grapple targets that do not match the currently inferred movement intent.
]]

local Gate = {}

local function horizontal(vector)
	if typeof(vector) ~= "Vector3" then
		return Vector3.zero
	end

	local flattened = Vector3.new(vector.X, 0, vector.Z)
	if flattened.Magnitude <= 0.001 then
		return Vector3.zero
	end

	return flattened.Unit
end

local function getKind(part, specialName)
	if specialName then
		return "Special"
	end

	if part and part.Name == "_RailPart" then
		return "Rail"
	end

	return "Terrain"
end

local function isBehindMomentum(direction, intent)
	local velocity = horizontal(intent and intent.Velocity)
	local targetDirection = horizontal(direction)
	if velocity.Magnitude <= 0.001 or targetDirection.Magnitude <= 0.001 then
		return false
	end

	return velocity:Dot(targetDirection) < -0.15
end

function Gate.accept(grapple, hit, part, origin, direction, intent, specialName)
	if not (hit and part and intent) then
		return false
	end

	local intentName = intent.Name or "AnchorAssist"
	if intentName == "None" then
		return false
	end

	local kind = getKind(part, specialName)
	local target = hit.Position

	if intentName == "VoidRescue" then
		return target.Y >= origin.Y - 4 or kind ~= "Terrain"
	end

	if intentName == "RailCapture" then
		return kind == "Rail" or kind == "Special"
	end

	if intentName == "ReelSaver" then
		return kind == "Terrain"
	end

	if intentName == "MomentumControl" and isBehindMomentum(direction, intent) then
		return false
	end

	local rootPart = grapple and grapple.RootPart
	if rootPart and rootPart.Parent and target.Y < rootPart.Position.Y - 18 and kind == "Terrain" then
		return false
	end

	return true
end

return Gate
