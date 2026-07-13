--!nocheck
-- [[
--  NULLSCAPE - Grapple Dodge
--  Uses grapple targeting to evade incoming enemies while preserving user travel intent.
-- ]]

local Workspace = game:GetService("Workspace")

local EnemyMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Threat Context/Enemy Memory.luau")
local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local UpgradeGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Upgrade Gate.luau")
local CastTransaction = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Transaction.luau")
local PerformanceBudget = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Performance Budget.luau")
local ReleasePolicy = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Policy.luau")
local SharkTailWindow = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/SharkTail Window.luau")
local ThreatTargetPolicy =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Threat Target Policy.luau")

local Logic = {
	LastCastAt = -1000,
	LastSharkTailAt = -1000,
	LastThreat = nil,
	ActiveLift = nil,
	PendingLiftEndAt = nil,
}

local CAST_COOLDOWN = 0.42
local SHARKTAIL_COOLDOWN = 0.9
local EMERGENCY_LIFT_WINDOW = 0.7
local SHARKTAIL_WINDOW = 0.3
local DEFAULT_RANGE = 92
local DEFAULT_THREAT_RANGE = 42
local DEFAULT_DANGER_RADIUS = 10
local DEFAULT_HORIZON = 0.45
local DEFAULT_STRENGTH = 1
local DEFAULT_SHARK_ESCAPE_RANGE = 26
local DEFAULT_LIFT_REEL_HOLD = 0.12
local MAX_TERRAIN_CANDIDATES = 80
local SHARK_ESCAPE_FRONT_DOT = 0.72
local SHARK_ESCAPE_MIN_CLOSING_SPEED = 7
local SHARK_ESCAPE_MAX_IMPACT_TIME = 0.55
local MANUAL_FRONT_DOT = 0.78
local MANUAL_SCREEN_DOT = 0.42
local MANUAL_DODGE_DOT = 0.35

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

local function getFacingDirection(grapple)
	local rootPart = grapple and grapple.RootPart
	local camera = Workspace.CurrentCamera
	return safeUnit(rootPart and rootPart.CFrame.LookVector, camera and camera.CFrame.LookVector)
end

local function isManualMode(controller, fieldName)
	return controller and tostring(controller[fieldName] or "Auto") == "Manual"
end

local function canCast(grapple, controller, now)
	if
		not (
			controller
			and (controller.GrappleDodgeTechniqueEnabled == true or controller.GrappleSharkEscapeEnabled == true)
		)
	then
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

local function canSharkEscape(grapple, controller, now)
	if not (controller and controller.GrappleSharkEscapeEnabled == true) then
		return false
	end

	if now - (Logic.LastSharkTailAt or -1000) < SHARKTAIL_COOLDOWN then
		return false
	end

	local movement = grapple and grapple.Movement
	return UpgradeGate and UpgradeGate.hasAll(movement, { "NinjaBelt", "SharkBelt" })
end

local function getSharkEscapeThreat(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	if not rootPart then
		return nil
	end

	local range = getNumber(controller.GrappleSharkEscapeRange, DEFAULT_SHARK_ESCAPE_RANGE, 10, 50)
	local horizon =
		math.min(getNumber(controller.GrappleDodgeHorizon, DEFAULT_HORIZON, 0.15, 0.9), SHARK_ESCAPE_MAX_IMPACT_TIME)
	local rootPosition = rootPart.Position
	local rootVelocity = flatten(getRootVelocity(rootPart))
	local forward = getIntentDirection(grapple)
	local bestThreat = nil
	local bestScore = 0
	local bestAway = nil

	for _, threat in ipairs(EnemyMemory.getNearbyThreats(rootPosition, range)) do
		if ThreatTargetPolicy and ThreatTargetPolicy.shouldIgnore(threat, controller, "SharkEscape") then
			continue
		end

		local flatToThreat = flatten(threat.Position - rootPosition)
		if flatToThreat.Magnitude <= 0.05 then
			continue
		end

		local frontDot = forward:Dot(flatToThreat.Unit)
		if frontDot < SHARK_ESCAPE_FRONT_DOT then
			continue
		end

		local forwardDistance = flatToThreat:Dot(forward)
		local lateralOffset = (flatToThreat - forward * forwardDistance).Magnitude
		local enemyRadius = math.max(threat.Size.X, threat.Size.Z) * 0.5
		local corridorRadius = math.max(4.5, enemyRadius + 3)
		if lateralOffset > corridorRadius then
			continue
		end

		local relativeVelocity = flatten(threat.Velocity or Vector3.zero) - rootVelocity
		local relativeSpeedSquared = relativeVelocity:Dot(relativeVelocity)
		if relativeSpeedSquared <= 0.01 then
			continue
		end

		local closingSpeed = -flatToThreat.Unit:Dot(relativeVelocity)
		if closingSpeed < SHARK_ESCAPE_MIN_CLOSING_SPEED then
			continue
		end

		local impactTime = math.clamp(-flatToThreat:Dot(relativeVelocity) / relativeSpeedSquared, 0, horizon)
		if impactTime <= 0 or impactTime > horizon then
			continue
		end

		local impactOffset = flatToThreat + relativeVelocity * impactTime
		local impactRadius = math.max(5.5, enemyRadius + 3.5)
		if impactOffset.Magnitude > impactRadius then
			continue
		end

		local score = frontDot * 3
			+ math.max(0, impactRadius - impactOffset.Magnitude) / impactRadius * 2
			+ math.max(0, horizon - impactTime) / horizon

		if score > bestScore then
			bestThreat = threat
			bestScore = score
			bestAway = safeUnit(-impactOffset, rootPosition - threat.Position)
		end
	end

	return bestThreat, bestScore, bestAway
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
		if ThreatTargetPolicy and ThreatTargetPolicy.shouldIgnore(threat, controller, "GrappleDodge") then
			continue
		end

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

local function getManualThreat(grapple, controller, sharkEscape)
	local rootPart = grapple and grapple.RootPart
	if not rootPart then
		return nil
	end

	local range = sharkEscape and getNumber(controller.GrappleSharkEscapeRange, DEFAULT_SHARK_ESCAPE_RANGE, 10, 50)
		or getNumber(controller.GrappleDodgeThreatRange, DEFAULT_THREAT_RANGE, 16, 90)
	local dangerRadius = getNumber(controller.GrappleDodgeDangerRadius, DEFAULT_DANGER_RADIUS, 4, 24)
	local facing = getFacingDirection(grapple)
	local origin = rootPart.Position
	local bestThreat = nil
	local bestScore = 0

	for _, threat in ipairs(EnemyMemory.getNearbyThreats(origin, range)) do
		local technique = sharkEscape and "SharkEscape" or "GrappleDodge"
		if ThreatTargetPolicy and ThreatTargetPolicy.shouldIgnore(threat, controller, technique) then
			continue
		end

		local offset = flatten(threat.Position - origin)
		if offset.Magnitude <= 0.05 then
			continue
		end

		local direction = offset.Unit
		local frontDot = facing:Dot(direction)
		if frontDot < MANUAL_FRONT_DOT then
			continue
		end

		local enemyRadius = math.max(threat.Size.X, threat.Size.Z) * 0.5
		local lateral = math.abs(facing.X * offset.Z - facing.Z * offset.X)
		local corridor = math.max(dangerRadius, enemyRadius + 3)
		if lateral > corridor then
			continue
		end

		local score = frontDot * 4 + math.max(0, corridor - lateral) / corridor * 2 - offset.Magnitude / range
		if score > bestScore then
			bestThreat = threat
			bestScore = score
		end
	end

	return bestThreat, bestScore, facing
end

local function getCandidatePart(candidate)
	return typeof(candidate) == "table" and candidate.Part or candidate
end

local function getCandidateKind(candidate)
	if typeof(candidate) ~= "table" then
		return "Terrain"
	end

	if candidate.Priority then
		return "Special"
	end

	if candidate.CFrame or candidate.Size then
		return "Terrain"
	end

	return "Rail"
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

local function getSharkEscapeBonus(candidate)
	local kind = getCandidateKind(candidate)
	if kind == "Terrain" then
		return 120
	end
	if kind == "Special" then
		return 35
	end
	return 12
end

local function canUseHit(hit, part)
	if not (hit and part) then
		return false
	end

	local instance = hit.Instance
	return instance == part or instance:IsDescendantOf(part) or part:IsDescendantOf(instance)
end

local function scoreCandidate(grapple, controller, candidate, intentDirection, awayDirection, sharkEscape)
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

	local verticalLift = math.clamp((part.Position.Y - origin.Y) / 22, -1, 2)

	local hit = Workspace:Raycast(origin, direction * distance, grapple.grappleParams)
	if not canUseHit(hit, part) then
		return nil, -math.huge
	end

	local strength = getNumber(controller.GrappleDodgeStrength, DEFAULT_STRENGTH, 0.25, 3)
	local score = intentDot * 70 * strength + awayDot * 60 + getCandidateBonus(part, controller) - distance * 0.22
	if sharkEscape then
		score += getSharkEscapeBonus(candidate) + verticalLift * 38
	end

	return hit, score
end

local function collectCandidates(origin, controller, sharkEscape)
	local range = getNumber(controller.GrappleDodgeRange, DEFAULT_RANGE, 30, 150)
	local candidates = {}

	local budget = PerformanceBudget
			and typeof(PerformanceBudget.get) == "function"
			and PerformanceBudget.get(sharkEscape and "Emergency" or nil)
		or nil
	local terrainLimit =
		math.min(MAX_TERRAIN_CANDIDATES, tonumber(budget and budget.CandidateLimit) or MAX_TERRAIN_CANDIDATES)
	local terrainCount = 0
	for _, entry in ipairs(TerrainMemory.getNearbySurfaces(origin, range)) do
		if terrainCount >= terrainLimit then
			break
		end
		terrainCount += 1
		table.insert(candidates, entry)
	end

	AnchorMemory.refreshBudgeted(budget and budget.AnchorScanBudget, controller)
	for _, entry in ipairs(AnchorMemory.getNearbyAnchors(origin, range, controller)) do
		table.insert(candidates, entry)
	end

	for _, entry in ipairs(RailMemory.getNearbyRails(origin, range)) do
		table.insert(candidates, entry)
	end

	if not sharkEscape then
		table.sort(candidates, function(a, b)
			return (a.Distance or math.huge) < (b.Distance or math.huge)
		end)
	end

	return candidates
end

local function findBestHit(grapple, controller, awayDirection, sharkEscape)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and grapple.grappleParams) then
		return nil
	end

	local intentDirection = getIntentDirection(grapple)
	local bestHit = nil
	local bestScore = -math.huge

	for _, candidate in ipairs(collectCandidates(rootPart.Position, controller, sharkEscape)) do
		local hit, score = scoreCandidate(grapple, controller, candidate, intentDirection, awayDirection, sharkEscape)
		if hit and score > bestScore then
			bestHit = hit
			bestScore = score
		end
	end

	return bestHit
end

local function findManualDodgeHit(grapple, controller, threat, facing, sharkEscape)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and threat and facing) then
		return nil
	end

	local threatOffset = flatten(threat.Position - rootPart.Position)
	local right = Vector3.new(-facing.Z, 0, facing.X)
	local side = threatOffset:Dot(right) >= 0 and -right or right
	local desiredDirection = safeUnit(facing * 0.8 + side * 0.6, facing)
	local bestHit = nil
	local bestScore = -math.huge

	for _, candidate in ipairs(collectCandidates(rootPart.Position, controller, sharkEscape)) do
		local part = getCandidatePart(candidate)
		if not (part and part:IsA("BasePart") and part.Parent) then
			continue
		end

		local offset = part.Position - rootPart.Position
		local distance = offset.Magnitude
		local range = getNumber(controller.GrappleDodgeRange, DEFAULT_RANGE, 30, 150)
		if distance <= 5 or distance > range then
			continue
		end

		local direction = offset.Unit
		local flatDirection = safeUnit(direction, facing)
		local screenDot = facing:Dot(flatDirection)
		local dodgeDot = desiredDirection:Dot(flatDirection)
		if screenDot < MANUAL_SCREEN_DOT or dodgeDot < MANUAL_DODGE_DOT then
			continue
		end

		local hit = Workspace:Raycast(rootPart.Position, direction * distance, grapple.grappleParams)
		if not canUseHit(hit, part) then
			continue
		end

		local score = dodgeDot * 100 + screenDot * 35 + getCandidateBonus(part, controller) - distance * 0.2
		if sharkEscape then
			score += getSharkEscapeBonus(candidate)
		end
		if score > bestScore then
			bestScore = score
			bestHit = hit
		end
	end

	return bestHit
end

local function playReelSound(grapple)
	local sfx = grapple and (grapple.SFX or grapple.Movement and grapple.Movement.SFX)
	if sfx and typeof(sfx.PlaySound) == "function" then
		pcall(function()
			sfx:PlaySound("GrapplerReel")
		end)
	end
end

local function startSharkEscapeReel(grapple, controller, now)
	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true) then
		return false
	end

	if grapple.jumpPadReel or grapple.grappleReel or grapple.reelCooldown or grapple.sharkTailDisable then
		return false
	end

	if not (UpgradeGate and UpgradeGate.hasAll(movement, { "NinjaBelt", "SharkBelt" })) then
		return false
	end

	grapple.jumpPadReel = true
	grapple.reelStart = now
	grapple.grappleReel = true
	Logic.PendingLiftEndAt = now
		+ getNumber(controller.GrappleSharkEscapeReelHoldTime, DEFAULT_LIFT_REEL_HOLD, 0.05, 0.22)
	if MomentumMemory and typeof(MomentumMemory.record) == "function" then
		pcall(MomentumMemory.record, grapple.RootPart, "SharkEscapeReel")
	end
	playReelSound(grapple)
	return true
end

local function trySharkEscapeTail(grapple, now)
	if not (SharkTailWindow and typeof(SharkTailWindow.isArmed) == "function") then
		return false
	end
	if not SharkTailWindow.isArmed(grapple, "SharkEscape", now) then
		Logic.ActiveLift = nil
		return false
	end

	local success = SharkTailWindow.trigger(grapple, "SharkEscape", now)
	if success then
		Logic.LastSharkTailAt = now
		Logic.ActiveLift = nil
		if MomentumMemory and typeof(MomentumMemory.record) == "function" then
			pcall(MomentumMemory.record, grapple.RootPart, "SharkEscape")
		end
		return true
	end

	return false
end

local function serviceSharkEscape(grapple, controller, now)
	local tailArmed = SharkTailWindow
		and typeof(SharkTailWindow.isArmed) == "function"
		and SharkTailWindow.isArmed(grapple, "SharkEscape", now)
	if not Logic.ActiveLift and not tailArmed then
		return false
	end

	if trySharkEscapeTail(grapple, now) then
		return true
	end

	if Logic.ActiveLift and now - (Logic.ActiveLift.StartedAt or now) > EMERGENCY_LIFT_WINDOW then
		Logic.ActiveLift = nil
		Logic.PendingLiftEndAt = nil
		return false
	end

	startSharkEscapeReel(grapple, controller, now)

	if Logic.PendingLiftEndAt and now >= Logic.PendingLiftEndAt and grapple then
		local success = ReleasePolicy
			and typeof(ReleasePolicy.release) == "function"
			and ReleasePolicy.release(grapple, "SharkEscape", {
				EndWasCancelled = false,
				OnReleased = function(releasedGrapple)
					if SharkTailWindow and typeof(SharkTailWindow.arm) == "function" then
						SharkTailWindow.arm(releasedGrapple, "SharkEscape", time(), SHARKTAIL_WINDOW)
					end
				end,
			})
		if success then
			Logic.PendingLiftEndAt = nil
			return true
		end
	end

	return Logic.ActiveLift ~= nil
		or (
			SharkTailWindow
			and typeof(SharkTailWindow.isArmed) == "function"
			and SharkTailWindow.isArmed(grapple, "SharkEscape", now)
		)
end

local function cancelSharkEscape(grapple)
	Logic.ActiveLift = nil
	Logic.PendingLiftEndAt = nil
	if SharkTailWindow and typeof(SharkTailWindow.cancel) == "function" then
		SharkTailWindow.cancel(grapple, "SharkEscape")
	end
end

function Logic.getManualCastHit(grapple, controller)
	local dodgeManual = controller
		and controller.GrappleDodgeTechniqueEnabled == true
		and isManualMode(controller, "GrappleDodgeMode")
	local sharkManual = controller
		and controller.GrappleSharkEscapeEnabled == true
		and isManualMode(controller, "GrappleSharkEscapeMode")
	if not (dodgeManual or sharkManual) then
		return nil
	end

	local now = time()
	if not canCast(grapple, controller, now) then
		return nil
	end

	local threat, score, facing = getManualThreat(grapple, controller, sharkManual)
	if not threat or score <= 0 then
		return nil
	end

	local hit = findManualDodgeHit(grapple, controller, threat, facing, sharkManual)
	if not hit then
		return nil
	end

	Logic.LastCastAt = now
	Logic.LastThreat = threat
	if sharkManual then
		Logic.ActiveLift = {
			StartedAt = now,
			Hit = hit,
		}
		Logic.PendingLiftEndAt = nil
	end

	return hit, sharkManual and "SharkEscape" or "GrappleDodge"
end

function Logic.step(grapple, _dt, controller)
	local now = time()
	if not (controller and controller.GrappleSharkEscapeEnabled == true) then
		cancelSharkEscape(grapple)
	end
	if serviceSharkEscape(grapple, controller, now) then
		return true
	end
	if
		PerformanceBudget
		and typeof(PerformanceBudget.shouldRun) == "function"
		and not PerformanceBudget.shouldRun(grapple, "GrappleDodgeThreat", 0.06)
	then
		return false
	end

	if not canCast(grapple, controller, now) then
		return false
	end

	local sharkThreat, sharkScore, sharkAway = nil, 0, nil
	if canSharkEscape(grapple, controller, now) and not isManualMode(controller, "GrappleSharkEscapeMode") then
		sharkThreat, sharkScore, sharkAway = getSharkEscapeThreat(grapple, controller)
	end

	local threat, score, awayDirection = nil, 0, nil
	if
		controller
		and controller.GrappleDodgeTechniqueEnabled == true
		and not isManualMode(controller, "GrappleDodgeMode")
	then
		threat, score, awayDirection = getThreat(grapple, controller)
	end
	if sharkThreat and sharkScore > 0 then
		threat = sharkThreat
		score = math.max(score, sharkScore)
		awayDirection = sharkAway or awayDirection
	end

	if not threat or score <= 0 then
		Logic.LastThreat = nil
		return false
	end

	local sharkEscape = sharkThreat ~= nil and sharkScore > 0
	local hit = findBestHit(grapple, controller, awayDirection, sharkEscape)
	if not hit then
		return false
	end

	local success = CastTransaction
		and typeof(CastTransaction.start) == "function"
		and CastTransaction.start(grapple, hit, controller, sharkEscape and "SharkEscape" or "GrappleDodge", {
			Technique = sharkEscape and "SharkEscape" or "ThreatDodge",
		})

	if success then
		Logic.LastCastAt = now
		Logic.LastThreat = threat
		if sharkEscape then
			Logic.ActiveLift = {
				StartedAt = now,
				Hit = hit,
			}
			Logic.PendingLiftEndAt = nil
			if SharkTailWindow and typeof(SharkTailWindow.cancel) == "function" then
				SharkTailWindow.cancel(grapple, "SharkEscape")
			end
		end
	end

	return success == true
end

function Logic.reset()
	Logic.LastCastAt = -1000
	Logic.LastSharkTailAt = -1000
	Logic.LastThreat = nil
	Logic.ActiveLift = nil
	Logic.PendingLiftEndAt = nil
	if SharkTailWindow and typeof(SharkTailWindow.reset) == "function" then
		SharkTailWindow.reset("SharkEscape")
	end
	if ThreatTargetPolicy and typeof(ThreatTargetPolicy.reset) == "function" then
		ThreatTargetPolicy.reset()
	end
end

return Logic
