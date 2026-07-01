--!nocheck
-- [[
--  NULLSCAPE - Grapple Void Cast Assist
--  Widens client-side grapple acquisition for KillVoid without changing normal terrain casts.
-- ]]

local Workspace = game:GetService("Workspace")

local VoidCastAssist = {}

local ASSIST_EASE_STUDS = 32
local MIN_DOWNWARD_DOT = -0.02

local function getControl()
	return getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
end

local function getEase()
	local Control = getControl()
	if not (Control and Control.GrappleEasierVoidCast == true) then
		return 0
	end
	return ASSIST_EASE_STUDS
end

local function getKillVoid()
	local killVoid = Workspace:FindFirstChild("KillVoid")
	if killVoid and killVoid:IsA("BasePart") then
		return killVoid
	end
	return nil
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function makeHit(part, position, origin)
	return {
		Instance = part,
		Position = position,
		Distance = (position - origin).Magnitude,
		Normal = part.CFrame.UpVector,
		Material = part.Material,
	}
end

function VoidCastAssist.find(grapple, direction, maxRange)
	local ease = getEase()
	if ease <= 0 then
		return nil
	end

	local rootPart = grapple and grapple.RootPart
	if not (rootPart and typeof(direction) == "Vector3" and direction.Magnitude > 0.01) then
		return nil
	end

	direction = direction.Unit
	if direction.Y > MIN_DOWNWARD_DOT then
		return nil
	end

	local killVoid = getKillVoid()
	if not killVoid then
		return nil
	end

	local origin = rootPart.Position
	local localOrigin = killVoid.CFrame:PointToObjectSpace(origin)
	local localDirection = killVoid.CFrame:VectorToObjectSpace(direction)
	if math.abs(localDirection.Y) <= 0.001 then
		return nil
	end

	local topY = killVoid.Size.Y * 0.5
	local travel = (topY - localOrigin.Y) / localDirection.Y
	local distanceLimit = (tonumber(maxRange) or 90) + ease
	if travel <= 0 or travel > distanceLimit then
		return nil
	end

	local localHit = localOrigin + localDirection * travel
	local halfX = killVoid.Size.X * 0.5
	local halfZ = killVoid.Size.Z * 0.5
	if math.abs(localHit.X) > halfX + ease or math.abs(localHit.Z) > halfZ + ease then
		return nil
	end

	local snappedLocal = Vector3.new(clamp(localHit.X, -halfX, halfX), topY, clamp(localHit.Z, -halfZ, halfZ))
	local snappedWorld = killVoid.CFrame:PointToWorldSpace(snappedLocal)
	return makeHit(killVoid, snappedWorld, origin)
end

return VoidCastAssist
