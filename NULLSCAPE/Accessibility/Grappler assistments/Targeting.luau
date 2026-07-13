--!nocheck
-- [[
--  NULLSCAPE - Grapple Assist Targeting
--  Finds the best fallback grapple target near the player's aim direction.
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")
local AnchorProfile =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Anchor Preference Profile.luau")
local GrappleRange = getgenv().loadModule("NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local IntentResolver = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Intent Resolver.luau")
local IntentTargetGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Intent Target Gate.luau")
local ConfidenceGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Assist Confidence Gate.luau")
local PilotState = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Pilot State.luau")
local AdaptiveStyle = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Adaptive Anchor Style.luau")
local AnchorBias = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Anchor Bias Profile.luau")
local DecisionGateway = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Decision Gateway.luau")
local PerformanceBudget = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Performance Budget.luau")
local AimLock = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Aim Target Lock.luau")
local NativeContext = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Native Context Sync.luau")
local PlayerIntent = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Player Intent State.luau")
local SpecialAnchorCapture =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchor Capture.luau")

local Targeting = {}

local DEFAULT_RANGE = 500
local DEFAULT_CAPTURE_ANGLE = 45
local DEFAULT_MANUAL_ANCHOR_ANGLE = 24
local DEFAULT_VOID_PROTECTION_HEIGHT = 24
local DEFAULT_VOID_PROTECTION_FALL_SPEED = 85
local MAX_FALLBACK_AXIS = 160
local HIT_OVERSHOOT = 2

local CandidateCache = {
	UpdatedAt = -1000,
	Origin = nil,
	Revision = -1,
	Candidates = {},
}

local VoidCache = {
	UpdatedAt = -1000,
	Y = nil,
}

local BLOCKED_FALLBACK_NAME_PATTERNS = {
	"void",
	"kill",
	"clip",
	"trigger",
	"hitbox",
	"hurtbox",
	"barrier",
	"boundary",
	"bounds",
	"zone",
	"volume",
}

local function getRange(controller)
	if GrappleRange and typeof(GrappleRange.getEffectiveRange) == "function" then
		local classRange = tonumber(GrappleRange.getEffectiveRange())
		if classRange then
			return math.clamp(classRange, 30, 5000)
		end
	end

	return math.clamp(tonumber(controller and controller.GrappleAssistRange) or DEFAULT_RANGE, 30, 500)
end

local function getCaptureAngle(controller)
	local baseAngle =
		math.clamp(tonumber(controller and controller.GrappleAssistCaptureAngle) or DEFAULT_CAPTURE_ANGLE, 1, 45)
	local strength = math.clamp(tonumber(controller and controller.GrappleAssistStrength) or 1, 0.1, 3)
	return math.clamp(baseAngle * strength, 1, 85)
end

local function getAssistStrength(controller)
	return math.clamp(tonumber(controller and controller.GrappleAssistStrength) or 1, 0.1, 3)
end

local function getManualAnchorAngle(controller)
	return math.clamp(
		tonumber(controller and controller.GrappleAssistManualAnchorAngle) or DEFAULT_MANUAL_ANCHOR_ANGLE,
		4,
		45
	)
end

local function getVoidY()
	local now = time()
	if now - VoidCache.UpdatedAt < 1 then
		return VoidCache.Y
	end
	VoidCache.UpdatedAt = now
	VoidCache.Y = nil

	if TerrainMemory and typeof(TerrainMemory.getVoidInfo) == "function" then
		local success, info = pcall(TerrainMemory.getVoidInfo)
		if success and info and tonumber(info.Y) then
			VoidCache.Y = info.Y
			return VoidCache.Y
		end
	end

	local killVoid = Workspace:FindFirstChild("KillVoid")
	if killVoid and killVoid:IsA("BasePart") then
		VoidCache.Y = killVoid.Position.Y
	end

	return VoidCache.Y
end

local function getTerrainScore(hit, origin)
	local score = 0
	local heightDiff = hit.Position.Y - origin.Y

	if heightDiff > 0 then
		score += heightDiff * 8
	end

	if hit.Normal and hit.Normal.Y > 0.5 then
		score += 6
	end

	return score
end

local function isAliveBasePart(part)
	return part and part:IsA("BasePart") and part.Parent ~= nil and part:IsDescendantOf(Workspace)
end

local function hasBlockedFallbackName(part)
	local cursor = part
	while cursor and cursor ~= Workspace do
		local lowerName = string.lower(cursor.Name or "")
		for _, pattern in ipairs(BLOCKED_FALLBACK_NAME_PATTERNS) do
			if string.find(lowerName, pattern, 1, true) then
				return true
			end
		end
		cursor = cursor.Parent
	end

	return false
end

local function getSpecialTargetName(part)
	if SpecialAnchors and typeof(SpecialAnchors.getName) == "function" then
		local specialName = SpecialAnchors.getName(part)
		if specialName then
			return specialName
		end
	end

	return nil
end

function Targeting.getAimDirection(grapple)
	local currentCamera = Workspace.CurrentCamera
	local rootPart = grapple and grapple.RootPart
	local movement = grapple and grapple.Movement
	if not (currentCamera and rootPart and movement) then
		return nil
	end

	local preferredInput = movement.preferredInput
	local useCamera = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or preferredInput ~= Enum.PreferredInput.KeyboardAndMouse

	if useCamera then
		return currentCamera.CFrame.LookVector
	end

	local mouse = LocalPlayer and LocalPlayer:GetMouse()
	local unitRay = mouse and mouse.UnitRay
	return unitRay and unitRay.Direction.Unit or currentCamera.CFrame.LookVector
end

local function usesCameraAim(grapple)
	local movement = grapple and grapple.Movement
	if not movement then
		return true
	end

	return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or movement.preferredInput ~= Enum.PreferredInput.KeyboardAndMouse
end

local function syncGrappleFilter(grapple)
	if
		grapple
		and grapple.grappleParams
		and grapple.Movement
		and grapple.Movement.moveCastParams
		and grapple.Movement.moveCastParams.FilterDescendantsInstances
	then
		grapple.grappleParams.FilterDescendantsInstances = grapple.Movement.moveCastParams.FilterDescendantsInstances
	end
end

local function isOptimalCandidate(part)
	if not isAliveBasePart(part) then
		return false
	end

	if LocalPlayer and LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character) then
		return false
	end

	if getSpecialTargetName(part) or part.Name == "_RailPart" then
		return true
	end

	if hasBlockedFallbackName(part) then
		return false
	end

	local size = part.Size
	local maxAxis = math.max(size.X, size.Y, size.Z)
	if maxAxis > MAX_FALLBACK_AXIS then
		return false
	end

	return part.CanCollide == true and part.Transparency < 0.95
end

local function canUseOptimalHit(hit, candidate)
	if not (hit and candidate) then
		return false
	end

	local instance = hit.Instance
	if not isAliveBasePart(instance) then
		return false
	end

	return instance == candidate or instance:IsDescendantOf(candidate) or candidate:IsDescendantOf(instance)
end

local function isProtectedAnchor(part)
	return getSpecialTargetName(part) ~= nil or part.Name == "_RailPart"
end

local function isPriorityCandidate(part)
	return getSpecialTargetName(part) ~= nil or part.Name == "_RailPart"
end

local function getVelocityY(rootPart)
	local velocity = rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity)
	return typeof(velocity) == "Vector3" and velocity.Y or 0
end

local function isVoidProtectedHit(grapple, hit, part, origin, controller)
	if not (controller and controller.GrappleVoidProtectionEnabled == true) then
		return false
	end

	if isProtectedAnchor(part) then
		return false
	end

	local voidY = getVoidY()
	local height =
		math.clamp(tonumber(controller.GrappleVoidProtectionHeight) or DEFAULT_VOID_PROTECTION_HEIGHT, 5, 120)
	local fallSpeed =
		math.clamp(tonumber(controller.GrappleVoidProtectionFallSpeed) or DEFAULT_VOID_PROTECTION_FALL_SPEED, 20, 240)
	local target = hit and hit.Position
	if not target then
		return false
	end

	if voidY and target.Y - voidY <= height then
		return true
	end

	local rootPart = grapple and grapple.RootPart
	local fallingFast = getVelocityY(rootPart) <= -fallSpeed
	local pullsDown = target.Y < origin.Y - 6
	if fallingFast and pullsDown then
		return true
	end

	if voidY and origin.Y - voidY <= height and pullsDown then
		return true
	end

	return false
end

local function getSurfaceTargetPoint(part, origin)
	local localOrigin = part.CFrame:PointToObjectSpace(origin)
	local halfSize = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localOrigin.X, -halfSize.X, halfSize.X),
		math.clamp(localOrigin.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localOrigin.Z, -halfSize.Z, halfSize.Z)
	)

	return part.CFrame:PointToWorldSpace(clamped)
end

local function getBudget(intent)
	local urgency = intent and (intent.Name == "VoidRescue" or intent.Name == "RazorbloomEscape") and "Emergency" or nil
	if PerformanceBudget and typeof(PerformanceBudget.get) == "function" then
		return PerformanceBudget.get(urgency)
	end

	return {
		CandidateLimit = 40,
		TerrainCacheLimit = 220,
		CandidateCacheTTL = 3,
	}
end

local function refreshCandidateCache(origin, maxRange, budget)
	local now = time()
	local cacheTTL = tonumber(budget and budget.CandidateCacheTTL) or 3
	local runtime = NativeContext and typeof(NativeContext.getSnapshot) == "function" and NativeContext.getSnapshot()
		or nil
	local revision = tonumber(runtime and runtime.Revision) or -1
	if
		now - CandidateCache.UpdatedAt < cacheTTL
		and CandidateCache.Origin
		and CandidateCache.Revision == revision
		and (CandidateCache.Origin - origin).Magnitude <= 64
	then
		return CandidateCache.Candidates
	end

	local candidates = {}
	local seen = {}
	local terrainLimit = tonumber(budget and budget.TerrainCacheLimit) or 220
	local function addCandidate(part)
		if not (part and not seen[part] and isOptimalCandidate(part)) then
			return
		end
		seen[part] = true
		table.insert(candidates, part)
	end

	if TerrainMemory and typeof(TerrainMemory.getNearbySurfaces) == "function" then
		for _, entry in ipairs(TerrainMemory.getNearbySurfaces(origin, maxRange)) do
			if #candidates >= terrainLimit then
				break
			end
			addCandidate(entry.Part)
		end
	end

	local scanBudget = tonumber(budget and budget.AnchorScanBudget)
	if AnchorMemory and typeof(AnchorMemory.refreshBudgeted) == "function" then
		AnchorMemory.refreshBudgeted(scanBudget)
	end
	if AnchorMemory and typeof(AnchorMemory.getNearbyAnchors) == "function" then
		for _, entry in ipairs(AnchorMemory.getNearbyAnchors(origin, maxRange)) do
			addCandidate(entry.Part)
		end
	end

	if RailMemory and typeof(RailMemory.refreshBudgeted) == "function" then
		RailMemory.refreshBudgeted(scanBudget)
	end
	if RailMemory and typeof(RailMemory.getNearbyRails) == "function" then
		for _, entry in ipairs(RailMemory.getNearbyRails(origin, maxRange)) do
			addCandidate(entry.Part)
		end
	end

	CandidateCache.UpdatedAt = now
	CandidateCache.Origin = origin
	CandidateCache.Revision = revision
	CandidateCache.Candidates = candidates
	return candidates
end

local function insertNearest(ranked, entry, limit)
	local inserted = false
	for index = 1, #ranked do
		if entry.Distance < ranked[index].Distance then
			table.insert(ranked, index, entry)
			inserted = true
			break
		end
	end

	if not inserted then
		table.insert(ranked, entry)
	end

	if #ranked > limit then
		table.remove(ranked)
	end
end

local function getOptimalCandidates(origin, maxRange, budget)
	local priorityCandidates = {}
	local rankedTerrain = {}

	local candidateLimit = tonumber(budget and budget.CandidateLimit) or 40
	for _, part in ipairs(refreshCandidateCache(origin, maxRange, budget)) do
		if isAliveBasePart(part) then
			local distance = (part.Position - origin).Magnitude
			if distance <= maxRange then
				if isPriorityCandidate(part) then
					table.insert(priorityCandidates, part)
				else
					insertNearest(rankedTerrain, {
						Part = part,
						Distance = distance,
					}, candidateLimit)
				end
			end
		end
	end

	local candidates = {}
	for _, part in ipairs(priorityCandidates) do
		table.insert(candidates, part)
	end
	for _, entry in ipairs(rankedTerrain) do
		table.insert(candidates, entry.Part)
	end

	return candidates
end

local function appendLiveSpecialCandidates(candidates, origin, maxRange)
	local seen = {}
	for _, part in ipairs(candidates) do
		seen[part] = true
	end

	-- GrapplePoints are spawned directly under JumpPads during a round. Read those
	-- live on a manual cast so cache throttling cannot make a fresh point invisible.
	for _, rootName in ipairs({ "JumpPads", "Enemies" }) do
		local root = Workspace:FindFirstChild(rootName)
		if root then
			for _, part in ipairs(root:GetChildren()) do
				if
					not seen[part]
					and isAliveBasePart(part)
					and getSpecialTargetName(part)
					and (part.Position - origin).Magnitude <= maxRange
				then
					seen[part] = true
					table.insert(candidates, part)
				end
			end
		end
	end

	return candidates
end

local function scoreOptimalHit(hit, part, origin, distance, dot, controller, intent)
	local score = 0
	local specialName = getSpecialTargetName(part)

	if AnchorProfile and typeof(AnchorProfile.score) == "function" then
		score += AnchorProfile.score(part, controller, intent)
	else
		if specialName then
			score += SpecialAnchors and SpecialAnchors.getPriority(specialName, controller) or 900
		elseif part.Name == "_RailPart" then
			score += 500
		else
			score += tonumber(controller and controller.GrappleAssistTerrainPriority) or 140
		end
	end

	if not specialName and part.Name ~= "_RailPart" then
		score += getTerrainScore(hit, origin)
	end
	score -= distance * 0.4
	score -= math.deg(math.acos(math.clamp(dot, -1, 1))) * (6 / getAssistStrength(controller))

	return score
end

local function applySafety(grapple, hit, part, controller, intent, context)
	if DecisionGateway and typeof(DecisionGateway.evaluate) == "function" then
		local success, result = pcall(DecisionGateway.evaluate, grapple, hit, controller, {
			Intent = intent,
			Technique = context and context.Technique,
			EntityIntent = context and context.EntityIntent,
		})
		if success and result then
			return result.Accept ~= false, tonumber(result.Penalty) or 0, result
		end
	end

	return true, 0, nil
end

local function getBiasScore(grapple, hit, part, origin, aimDirection, controller, intent)
	if controller and controller.GrappleAssistAnchorBiasEnabled == false then
		return 0
	end

	if not (AnchorBias and typeof(AnchorBias.score) == "function") then
		return 0
	end

	local success, score = pcall(function()
		return AnchorBias.score(grapple, hit, part, origin, aimDirection, controller, intent)
	end)

	return success and tonumber(score) or 0
end

local function getIntent(grapple, controller, aimDirection, context)
	context = context or {}
	context.AimDirection = context.AimDirection or aimDirection
	local playerState = PlayerIntent
		and typeof(PlayerIntent.observe) == "function"
		and PlayerIntent.observe(grapple, aimDirection)

	local function enrich(intent)
		intent = intent or {}
		if playerState then
			intent.PlayerState = playerState.Mode
			intent.PlayerIntentConfidence = playerState.Confidence
			intent.PlayerCommitment = playerState.IsUserCommitting == true
		end
		return intent
	end

	if IntentResolver and typeof(IntentResolver.resolve) == "function" then
		local success, intent = pcall(function()
			return IntentResolver.resolve(grapple, controller, context)
		end)
		if success and intent then
			if PilotState and typeof(PilotState.resolve) == "function" then
				intent.PilotMode = PilotState.resolve(grapple, intent, context)
			end
			return enrich(intent)
		end
	end

	local fallbackIntent = {
		Name = "AnchorAssist",
		Confidence = 0.5,
		AimDirection = aimDirection,
	}
	if PilotState and typeof(PilotState.resolve) == "function" then
		fallbackIntent.PilotMode = PilotState.resolve(grapple, fallbackIntent, context)
	end

	return enrich(fallbackIntent)
end

local function isManualIntent(intent)
	return intent and (intent.PilotMode == "Manual" or intent.PilotMode == "AssistiveManual")
end

local function isAllowedSpecialForIntent(specialName, intent, specialOnly)
	if not specialName then
		return not specialOnly
	end

	if specialOnly and intent and intent.Name == "RazorbloomEscape" then
		-- MovementCore only disables Razorbloom when the player touches one of
		-- these two native targets. Bell, TriaOrb, and rails are unrelated.
		return specialName == "JumpPad" or specialName == "GrapplePoint"
	end

	return true
end

local function isPriorityAnchor(part, specialName)
	return specialName ~= nil or part.Name == "_RailPart"
end

local function getOptimalMinDot(part, controller, intent)
	local specialName = getSpecialTargetName(part)
	if isManualIntent(intent) and isPriorityAnchor(part, specialName) then
		if specialName then
			local captureAngle = SpecialAnchors and SpecialAnchors.getCaptureAngle(specialName) or 45
			return math.cos(math.rad(math.max(getManualAnchorAngle(controller), math.min(captureAngle, 52))))
		end
		return math.cos(math.rad(getManualAnchorAngle(controller)))
	end

	if specialName then
		local captureAngle = SpecialAnchors and SpecialAnchors.getCaptureAngle(specialName) or 70
		return math.cos(math.rad(captureAngle))
	end

	return math.cos(math.rad(getCaptureAngle(controller)))
end

local function resolveCandidateHit(part, origin, aimDirection, grappleParams, controller, intent)
	local specialName = getSpecialTargetName(part)
	if specialName and SpecialAnchorCapture and typeof(SpecialAnchorCapture.resolve) == "function" then
		return SpecialAnchorCapture.resolve(
			part,
			origin,
			aimDirection,
			grappleParams,
			isManualIntent(intent) and getManualAnchorAngle(controller) or nil
		)
	end

	local targetPoint = getSurfaceTargetPoint(part, origin)
	local offset = targetPoint - origin
	local distance = offset.Magnitude
	if distance <= 3 then
		return nil
	end

	local direction = offset.Unit
	return Workspace:Raycast(origin, direction * (distance + HIT_OVERSHOOT), grappleParams),
		direction,
		distance,
		aimDirection:Dot(direction),
		specialName
end

function Targeting.findOptimalHit(grapple, controller, context)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and grapple.grappleParams) then
		return nil
	end

	syncGrappleFilter(grapple)

	local aimDirection = Targeting.getAimDirection(grapple)
	if not aimDirection or aimDirection.Magnitude <= 0.001 then
		return nil
	end

	local origin = rootPart.Position
	local maxRange = getRange(controller)
	local intent = getIntent(grapple, controller, aimDirection, context)
	local budget = getBudget(intent)
	local effectiveController = controller
	if AdaptiveStyle and typeof(AdaptiveStyle.resolve) == "function" then
		local success, styledController = pcall(function()
			return AdaptiveStyle.resolve(controller, intent)
		end)
		if success and styledController then
			effectiveController = styledController
		end
	end
	local bestHit = nil
	local bestScore = -math.huge
	local secondScore = -math.huge
	local lockedHit = AimLock and typeof(AimLock.resolve) == "function" and AimLock.resolve(grapple, aimDirection)
	if
		(not context or context.SpecialOnly ~= true)
		and lockedHit
		and canUseOptimalHit(lockedHit, lockedHit.Instance)
	then
		local lockedPart = lockedHit.Instance
		local lockedOffset = lockedHit.Position - origin
		local lockedDirection = lockedOffset.Magnitude > 0.001 and lockedOffset.Unit or nil
		local lockedSpecial = getSpecialTargetName(lockedPart)
		local acceptedByIntent = not IntentTargetGate
			or IntentTargetGate.accept(grapple, lockedHit, lockedPart, origin, lockedDirection, intent, lockedSpecial)
		if
			lockedDirection
			and acceptedByIntent
			and not isVoidProtectedHit(grapple, lockedHit, lockedPart, origin, effectiveController)
		then
			local safe = applySafety(grapple, lockedHit, lockedPart, effectiveController, intent, context)
			if safe then
				return lockedHit
			end
		end
	end

	local specialOnly = context and context.SpecialOnly == true
	local candidates = getOptimalCandidates(origin, maxRange, budget)
	if specialOnly then
		candidates = appendLiveSpecialCandidates(candidates, origin, maxRange)
	end

	for _, part in ipairs(candidates) do
		local specialName = getSpecialTargetName(part)
		local specialDisabled = specialName
			and effectiveController
			and effectiveController.GrappleAssistSpecialPointPriority == false
		if isAllowedSpecialForIntent(specialName, intent, specialOnly) and not specialDisabled then
			local hit, direction, distance, dot, resolvedSpecialName =
				resolveCandidateHit(part, origin, aimDirection, grapple.grappleParams, effectiveController, intent)
			specialName = resolvedSpecialName or specialName

			if hit and distance <= maxRange and dot >= getOptimalMinDot(part, effectiveController, intent) then
				local acceptedByIntent = not IntentTargetGate
					or IntentTargetGate.accept(grapple, hit, part, origin, direction, intent, specialName)
				if
					acceptedByIntent
					and canUseOptimalHit(hit, part)
					and not isVoidProtectedHit(grapple, hit, part, origin, effectiveController)
				then
					local safe, safetyPenalty = applySafety(grapple, hit, part, effectiveController, intent, context)
					if safe then
						local score = scoreOptimalHit(hit, part, origin, distance, dot, effectiveController, intent)
							+ getBiasScore(grapple, hit, part, origin, aimDirection, effectiveController, intent)
							- safetyPenalty
						if score > bestScore then
							secondScore = bestScore
							bestScore = score
							bestHit = hit
						elseif score > secondScore then
							secondScore = score
						end
					end
				end
			end
		end
	end

	if ConfidenceGate and not ConfidenceGate.accept(bestHit, bestScore, secondScore, controller, intent) then
		return nil
	end
	if bestHit and AimLock and typeof(AimLock.remember) == "function" then
		AimLock.remember(grapple, bestHit)
	end

	return bestHit
end

function Targeting.findSpecialAnchorHit(grapple, controller, context)
	context = context or {}
	context.SpecialOnly = true
	context.ManualCast = context.ManualCast ~= false
	context.AssistiveManual = context.AssistiveManual ~= false
	return Targeting.findOptimalHit(grapple, controller, context)
end

local function validateFallbackHit(grapple, hit, controller, aimDirection)
	if not hit then
		return nil, aimDirection, false
	end

	local intent = getIntent(grapple, controller, aimDirection, {
		ManualCast = true,
		AssistiveManual = true,
		AimDirection = aimDirection,
	})
	local safe = applySafety(grapple, hit, hit.Instance, controller, intent, {
		ManualCast = true,
		AssistiveManual = true,
	})
	if safe and AimLock and typeof(AimLock.remember) == "function" then
		AimLock.remember(grapple, hit)
	end
	return safe and hit or nil, aimDirection, safe ~= true
end

function Targeting.fallbackCast(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	local currentCamera = Workspace.CurrentCamera
	if not (rootPart and currentCamera and grapple.grappleParams) then
		return nil
	end

	syncGrappleFilter(grapple)

	local maxRange = getRange(controller)
	local position = rootPart.Position
	local aimDirection = Targeting.getAimDirection(grapple)
	if not aimDirection then
		return nil
	end

	if usesCameraAim(grapple) then
		local humanoid = grapple.Humanoid
		local cameraOffset = grapple.cameraOffset
		if not (humanoid and cameraOffset) then
			local hit = Workspace:Raycast(position, aimDirection * maxRange, grapple.grappleParams)
			return validateFallbackHit(grapple, hit, controller, aimDirection)
		end

		local rayOrigin = (currentCamera.CFrame * cameraOffset).Position
			+ currentCamera.CFrame.LookVector
				* (currentCamera.CFrame.Position - (position + humanoid.CameraOffset)).Magnitude
		local hit = Workspace:Raycast(rayOrigin, aimDirection * maxRange, grapple.grappleParams)
		return validateFallbackHit(grapple, hit, controller, aimDirection)
	end

	local mouse = LocalPlayer and LocalPlayer:GetMouse()
	local unitRay = mouse and mouse.UnitRay
	if not unitRay then
		return nil, aimDirection
	end

	local mouseHit = Workspace:Raycast(unitRay.Origin, aimDirection * 2048, grapple.grappleParams)
	if not mouseHit then
		return nil, aimDirection
	end

	local hit = Workspace:Raycast(
		position,
		CFrame.lookAt(position, mouseHit.Position).LookVector * maxRange,
		grapple.grappleParams
	)
	return validateFallbackHit(grapple, hit, controller, aimDirection)
end

function Targeting.findBestAssistHit(grapple, controller, context)
	return Targeting.findOptimalHit(grapple, controller, context)
end

function Targeting.resetCache()
	CandidateCache.UpdatedAt = -1000
	CandidateCache.Origin = nil
	CandidateCache.Revision = -1
	table.clear(CandidateCache.Candidates)
end

return Targeting
