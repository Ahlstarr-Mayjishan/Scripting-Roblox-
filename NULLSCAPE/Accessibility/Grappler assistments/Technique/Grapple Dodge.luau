--!nocheck
-- [[
--  NULLSCAPE - Grapple Dodge
--  Uses grapple targeting to evade incoming enemies while preserving user travel intent.
-- ]]

local Workspace = game:GetService("Workspace")

local EnemyMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Threat Context/Enemy Memory.luau")
local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")
local RailMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory.luau")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local Logic = {
	LastCastAt = -1000,
	LastThreat = nil,
}

local CAST_COOLDOWN = 0.42
local DEFAULT_RANGE = 92
local DEFAULT_THREAT_RANGE = 42
local DEFAULT_DANGER_RADIUS = 10
local DEFAULT_HORIZON = 0.45
local DEFAULT_STRENGTH = 1
local MAX_TERRAIN_CANDIDATES = 80

local function getNumber(value, fallback, minimum, maximum)
	local numberValue = tonumber(value) or fallback
	return math.clamp(numberValue, minimum, maximum)
end

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function safeUnit(vector, fallback)
	local flat = flatten(vector)
	if flat.Magnitude > 0.05 then
		return flat.Unit
	end

	local fallbackFlat = fallback and flatten(fallback) or Vector3.zero
	if fallbackFlat.Magnitude > 0.05 then
		return fallbackFlat.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function getRootVelocity(rootPart)
	if MomentumMemory and typeof(MomentumMemory.getState) == "function" then
		local success, state = pcall(function()
			return MomentumMemory.getState(rootPart, 0.25)
		end)
		if success and state and state.Velocity then
			return state.Velocity
		end
	end

	return rootPart.AssemblyLinearVelocity or rootPart.Velocity
end

local function getIntentDirection(grapple)
	local movement = grapple and grapple.Movement
	local rootPart = grapple and grapple.RootPart
	local humanoid = grapple and grapple.Humanoid
	local camera = Workspace.CurrentCamera

	if humanoid and humanoid.MoveDirection.Magnitude > 0.08 then
		return safeUnit(humanoid.MoveDirection)
	end

	local velocity = rootPart and flatten(getRootVelocity(rootPart)) or Vector3.zero
	if velocity.Magnitude > 8 then
		return velocity.Unit
	end

	if movement and movement.moveDirection and movement.moveDirection.Magnitude > 0.08 then
		return safeUnit(movement.moveDirection)
	end

	return safeUnit(camera and camera.CFrame.LookVector, rootPart and rootPart.CFrame.LookVector)
end

local function canCast(grapple, controller, now)
	if not (controller and controller.GrappleDodgeEnabled == true) then
		return false
	end

	if now - (Logic.LastCastAt or -1000) < CAST_COOLDOWN then
		return false
	end

	local movement = grapple and grapple.Movement
	local rootPart = grapple and grapple.RootPart
	if not (movement and rootPart and rootPart.Parent and typeof(grapple.Start) == "function") then
		return false
	end

	if movement.grappling or movement.diveBonked or movement.rail or movement.triaHold or rootPart.Anchored then
		return false
	end

	if tonumber(grapple.Time) == 0 or tonumber(grapple.Charges) == 0 then
		return false
	end

	return true
end

local function getThreat(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	if not rootPart then
		return nil
	end

	local threatRange = getNumber(controller.GrappleDodgeThreatRange, DEFAULT_THREAT_RANGE, 16, 90)
	local dangerRadius = getNumber(controller.GrappleDodgeDangerRadius, DEFAULT_DANGER_RADIUS, 4, 24)
	local horizon = getNumber(controller.GrappleDodgeHorizon, DEFAULT_HORIZON, 0.15, 0.9)
	local rootPosition = rootPart.Position
	local rootVelocity = getRootVelocity(rootPart)
	local bestThreat = nil
	local bestScore = 0
	local bestAway = nil

	for _, threat in ipairs(EnemyMemory.getNearbyThreats(rootPosition, threatRange)) do
		local offset = rootPosition - threat.Position
		if offset.Magnitude <= 0.05 then
			continue
		end

		local futureRoot = rootPosition + rootVelocity * horizon
		local futureEnemy = threat.Position + (threat.Velocity or Vector3.zero) * horizon
		local futureOffset = futureRoot - futureEnemy
		local futureDistance = futureOffset.Magnitude
		local awayDirection = safeUnit(futureOffset, offset)
		local closingSpeed = flatten((threat.Velocity or Vector3.zero) - rootVelocity):Dot(safeUnit(offset))
		local sizeBonus = math.max(threat.Size.X, threat.Size.Y, threat.Size.Z) * 0.3
		local score = math.max(0, dangerRadius + sizeBonus - futureDistance) + math.max(0, closingSpeed) * 0.035

		if score > bestScore then
			bestThreat = threat
			bestScore = score
			bestAway = awayDirection
		end
	end

	return bestThreat, bestScore, bestAway
end

local function getCandidatePart(candidate)
	return typeof(candidate) == "table" and candidate.Part or candidate
end

local function getCandidateBonus(part, controller)
	if AnchorMemory and typeof(AnchorMemory.isSpecialAnchor) == "function" and AnchorMemory.isSpecialAnchor(part) then
		local entry = AnchorMemory.remember(part, "grapple-dodge", controller)
		return entry and entry.Priority or 45
	end

	if RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part) then
		return tonumber(controller.GrappleDodgeRailBonus) or 34
	end

	return 0
end

local function canUseHit(hit, part)
	if not (hit and part) then
		return false
	end

	local instance = hit.Instance
	return instance == part or instance:IsDescendantOf(part) or part:IsDescendantOf(instance)
end

local function scoreCandidate(grapple, controller, candidate, intentDirection, awayDirection)
	local rootPart = grapple.RootPart
	local part = getCandidatePart(candidate)
	if not (part and part:IsA("BasePart") and part.Parent) then
		return nil, -math.huge
	end

	local origin = rootPart.Position
	local offset = part.Position - origin
	local distance = offset.Magnitude
	local range = getNumber(controller.GrappleDodgeRange, DEFAULT_RANGE, 30, 150)
	if distance <= 5 or distance > range then
		return nil, -math.huge
	end

	local direction = offset.Unit
	local intentDot = flatten(direction):Dot(intentDirection)
	local awayDot = flatten(direction):Dot(awayDirection)
	if intentDot < -0.2 or awayDot < -0.1 then
		return nil, -math.huge
	end

	local hit = Workspace:Raycast(origin, direction * distance, grapple.grappleParams)
	if not canUseHit(hit, part) then
		return nil, -math.huge
	end

	local strength = getNumber(controller.GrappleDodgeStrength, DEFAULT_STRENGTH, 0.25, 3)
	local score = intentDot * 70 * strength + awayDot * 60 + getCandidateBonus(part, controller) - distance * 0.22

	return hit, score
end

local function collectCandidates(origin, controller)
	local range = getNumber(controller.GrappleDodgeRange, DEFAULT_RANGE, 30, 150)
	local candidates = {}

	AnchorMemory.refreshBudgeted(nil, controller)
	for _, entry in ipairs(AnchorMemory.getNearbyAnchors(origin, range, controller)) do
		table.insert(candidates, entry)
	end

	for _, entry in ipairs(RailMemory.getNearbyRails(origin, range)) do
		table.insert(candidates, entry)
	end

	local terrainCount = 0
	for _, entry in ipairs(TerrainMemory.getNearbySurfaces(origin, range)) do
		if terrainCount >= MAX_TERRAIN_CANDIDATES then
			break
		end
		terrainCount += 1
		table.insert(candidates, entry)
	end

	return candidates
end

local function findBestHit(grapple, controller, awayDirection)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and grapple.grappleParams) then
		return nil
	end

	local intentDirection = getIntentDirection(grapple)
	local bestHit = nil
	local bestScore = -math.huge

	for _, candidate in ipairs(collectCandidates(rootPart.Position, controller)) do
		local hit, score = scoreCandidate(grapple, controller, candidate, intentDirection, awayDirection)
		if hit and score > bestScore then
			bestHit = hit
			bestScore = score
		end
	end

	return bestHit
end

function Logic.step(grapple, _dt, controller)
	local now = time()
	if not canCast(grapple, controller, now) then
		return false
	end

	local threat, score, awayDirection = getThreat(grapple, controller)
	if not threat or score <= 0 then
		Logic.LastThreat = nil
		return false
	end

	local hit = findBestHit(grapple, controller, awayDirection)
	if not hit then
		return false
	end

	local success = pcall(function()
		grapple:Start(hit)
	end)

	if hit.Instance and AnchorMemory and typeof(AnchorMemory.noteCastResult) == "function" then
		AnchorMemory.noteCastResult(hit.Instance, success == true)
	end

	if success then
		Logic.LastCastAt = now
		Logic.LastThreat = threat
	end

	return success == true
end

function Logic.reset()
	Logic.LastCastAt = -1000
	Logic.LastThreat = nil
end

return Logic
