--!nocheck

local Distance = {}

local Y_SCALE = 0.8
local ROOT_OFFSET = Vector3.new(0, 3, 0)

local function scaleOffset(offset)
	return Vector3.new(offset.X, offset.Y * Y_SCALE, offset.Z)
end

function Distance.nativeDistanceSq(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		return math.huge
	end

	local offset = scaleOffset(a - b)
	return offset:Dot(offset)
end

function Distance.collectDistanceSq(giftPosition, targetPosition)
	if typeof(targetPosition) ~= "Vector3" then
		return math.huge
	end

	return Distance.nativeDistanceSq(giftPosition, targetPosition + ROOT_OFFSET)
end

function Distance.getRootPosition(targetPosition)
	if typeof(targetPosition) ~= "Vector3" then
		return targetPosition
	end

	local rootPos = targetPosition + ROOT_OFFSET

	local beacon = workspace:FindFirstChild("Beacon")
	if beacon and beacon:IsA("BasePart") then
		local beaconPos = beacon.Position
		local offset = rootPos - beaconPos
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		local dist = flatOffset.Magnitude
		local minSafeDistance = 15
		if dist < minSafeDistance then
			if dist > 0.1 then
				rootPos = beaconPos + flatOffset.Unit * minSafeDistance + Vector3.new(0, offset.Y, 0)
			else
				rootPos = beaconPos + Vector3.new(minSafeDistance, offset.Y, 0)
			end
		end
	end

	return rootPos
end

function Distance.isWithinRange(giftPosition, rootPosition, range)
	local numericRange = tonumber(range) or 0
	if numericRange <= 0 then
		return false
	end

	return Distance.nativeDistanceSq(giftPosition, rootPosition) <= numericRange * numericRange
end

return Distance
