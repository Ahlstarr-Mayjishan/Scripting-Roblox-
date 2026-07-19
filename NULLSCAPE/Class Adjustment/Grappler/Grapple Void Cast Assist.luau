--!nocheck
-- [[
--  NULLSCAPE - Grapple Void Cast Assist
--  Widens client-side grapple acquisition for KillVoid without changing normal terrain casts.
-- ]]

local Workspace = game:GetService("Workspace")

local VoidCastAssist = {}

local ASSIST_EASE_STUDS = 64
local MAX_VOID_CAST_DISTANCE = 160
local DEFAULT_EMERGENCY_LATERAL_OFFSET = 64

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
	local killVoid = Workspace:FindFirstChild("KillVoid", true)
	if killVoid and killVoid:IsA("BasePart") then
		return killVoid
	end
	return nil
end

function VoidCastAssist.isEnabled()
	return getEase() > 0
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

local function getHorizontalDirection(rootPart)
	local velocity = rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	if velocity.Magnitude > 1 then
		return velocity.Unit
	end

	local camera = Workspace.CurrentCamera
	local look = camera and camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look and look.Magnitude > 0.01 then
		return look.Unit
	end

	return Vector3.new(1, 0, 0)
end

function VoidCastAssist.find(grapple, direction, _maxRange)
	local ease = getEase()
	if ease <= 0 then
		return nil
	end

	local rootPart = grapple and grapple.RootPart
	if not (rootPart and typeof(direction) == "Vector3" and direction.Magnitude > 0.01) then
		return nil
	end

	direction = direction.Unit
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
	local distanceLimit = MAX_VOID_CAST_DISTANCE
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

-- Used by emergency systems after the player is already falling toward KillVoid.
-- It deliberately does not require a camera ray to strike the non-collidable void part.
function VoidCastAssist.findEmergency(grapple, maxRange, options)
	options = typeof(options) == "table" and options or {}
	if options.Force ~= true and getEase() <= 0 then
		return nil
	end

	local rootPart = grapple and grapple.RootPart
	local killVoid = getKillVoid()
	if not (rootPart and rootPart.Parent and killVoid) then
		return nil
	end

	local origin = rootPart.Position
	local localOrigin = killVoid.CFrame:PointToObjectSpace(origin)
	local halfSize = killVoid.Size * 0.5
	local distanceLimit = math.min(math.max(tonumber(maxRange) or MAX_VOID_CAST_DISTANCE, 30), MAX_VOID_CAST_DISTANCE)
	local verticalDistance = math.abs(localOrigin.Y - halfSize.Y)
	if verticalDistance > distanceLimit then
		return nil
	end

	local worldDirection = getHorizontalDirection(rootPart)
	local localDirection = killVoid.CFrame:VectorToObjectSpace(worldDirection)
	local requestedOffset = math.max(tonumber(options.LateralOffset) or DEFAULT_EMERGENCY_LATERAL_OFFSET, 0)
	local availableOffset = math.sqrt(math.max(distanceLimit * distanceLimit - verticalDistance * verticalDistance, 0))
	local lateralOffset = math.min(requestedOffset, availableOffset)
	local snappedLocal = Vector3.new(
		clamp(localOrigin.X + localDirection.X * lateralOffset, -halfSize.X, halfSize.X),
		halfSize.Y,
		clamp(localOrigin.Z + localDirection.Z * lateralOffset, -halfSize.Z, halfSize.Z)
	)
	local snappedWorld = killVoid.CFrame:PointToWorldSpace(snappedLocal)
	local distance = (snappedWorld - origin).Magnitude
	if distance <= 3 or distance > distanceLimit then
		return nil
	end

	return makeHit(killVoid, snappedWorld, origin)
end

return VoidCastAssist
