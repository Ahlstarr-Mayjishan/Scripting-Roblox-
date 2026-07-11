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
local IntentResolver = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Intent Resolver.luau")
local IntentTargetGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Intent Target Gate.luau")
local ConfidenceGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Assist Confidence Gate.luau")
local PilotState = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Pilot State.luau")
local AdaptiveStyle = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Adaptive Anchor Style.luau")
local CastSafety = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Safety Check.luau")
local AnchorBias = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Anchor Bias Profile.luau")

local Targeting = {}

local MAX_OPTIMAL_CANDIDATES = 48
local MAX_CACHED_TERRAIN_CANDIDATES = 260
local CANDIDATE_CACHE_TTL = 3
local DEFAULT_RANGE = 500
local DEFAULT_CAPTURE_ANGLE = 45
local DEFAULT_MANUAL_ANCHOR_ANGLE = 24
local DEFAULT_VOID_PROTECTION_HEIGHT = 24
local DEFAULT_VOID_PROTECTION_FALL_SPEED = 85
local MAX_FALLBACK_AXIS = 160
local HIT_OVERSHOOT = 2

local CandidateCache = {
	UpdatedAt = -1000,
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

	if hit.Normal and hit.Normal.Y < -0.5 then
		score += 150
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

local function getScanRoots()
	local roots = {}
	local jumpPads = Workspace:FindFirstChild("JumpPads")
	local currentRooms = Workspace:FindFirstChild("CurrentRooms")
	local enemies = Workspace:FindFirstChild("Enemies")
	if jumpPads then
		table.insert(roots, jumpPads)
	end
	if enemies then
		table.insert(roots, enemies)
	end
	if currentRooms then
		table.insert(roots, currentRooms)
	end
	if #roots == 0 then
		table.insert(roots, Workspace)
	end

	return roots
end

local function refreshCandidateCache()
	local now = time()
	if now - CandidateCache.UpdatedAt < CANDIDATE_CACHE_TTL then
		return CandidateCache.Candidates
	end

	local specialCandidates = {}
	local terrainCandidates = {}
	for _, root in ipairs(getScanRoots()) do
		if isOptimalCandidate(root) then
			if getSpecialTargetName(root) or root.Name == "_RailPart" then
				table.insert(specialCandidates, root)
			elseif #terrainCandidates < MAX_CACHED_TERRAIN_CANDIDATES then
				table.insert(terrainCandidates, root)
			end
		end

		for _, descendant in ipairs(root:GetDescendants()) do
			local specialName = getSpecialTargetName(descendant)
			if specialName or descendant.Name == "_RailPart" then
				if isOptimalCandidate(descendant) then
					table.insert(specialCandidates, descendant)
				end
			elseif #terrainCandidates < MAX_CACHED_TERRAIN_CANDIDATES and isOptimalCandidate(descendant) then
				table.insert(terrainCandidates, descendant)
			end
		end
	end

	local candidates = {}
	for _, part in ipairs(specialCandidates) do
		table.insert(candidates, part)
	end
	for _, part in ipairs(terrainCandidates) do
		table.insert(candidates, part)
	end

	CandidateCache.UpdatedAt = now
	CandidateCache.Candidates = candidates
	return candidates
end

local function insertNearest(ranked, entry)
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

	if #ranked > MAX_OPTIMAL_CANDIDATES then
		table.remove(ranked)
	end
end

local function getOptimalCandidates(origin, maxRange)
	local priorityCandidates = {}
	local rankedTerrain = {}

	for _, part in ipairs(refreshCandidateCache()) do
		if isAliveBasePart(part) then
			local distance = (part.Position - origin).Magnitude
			if distance <= maxRange then
				if isPriorityCandidate(part) then
					table.insert(priorityCandidates, part)
				else
					insertNearest(rankedTerrain, {
						Part = part,
						Distance = distance,
					})
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

local function applySafety(grapple, hit, part, controller, intent)
	if controller and controller.GrappleAssistSafetyEnabled == false then
		return true, 0
	end

	if not (CastSafety and typeof(CastSafety.evaluate) == "function") then
		return true, 0
	end

	local success, result = pcall(function()
		return CastSafety.evaluate(grapple, hit, part, controller, intent)
	end)
	if not (success and result) then
		return true, 0
	end

	return result.Accept ~= false, tonumber(result.Penalty) or 0
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

	if IntentResolver and typeof(IntentResolver.resolve) == "function" then
		local success, intent = pcall(function()
			return IntentResolver.resolve(grapple, controller, context)
		end)
		if success and intent then
			if PilotState and typeof(PilotState.resolve) == "function" then
				intent.PilotMode = PilotState.resolve(grapple, intent, context)
			end
			return intent
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

	return fallbackIntent
end

local function isManualIntent(intent)
	return intent and intent.PilotMode == "Manual"
end

local function isPriorityAnchor(part, specialName)
	return specialName ~= nil or part.Name == "_RailPart"
end

local function getOptimalMinDot(part, controller, intent)
	local specialName = getSpecialTargetName(part)
	if isManualIntent(intent) and isPriorityAnchor(part, specialName) then
		return math.cos(math.rad(getManualAnchorAngle(controller)))
	end

	if specialName then
		local captureAngle = SpecialAnchors and SpecialAnchors.getCaptureAngle(specialName) or 70
		return math.cos(math.rad(captureAngle))
	end

	return math.cos(math.rad(getCaptureAngle(controller)))
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

	for _, part in ipairs(getOptimalCandidates(origin, maxRange)) do
		local targetPoint = getSurfaceTargetPoint(part, origin)
		local offset = targetPoint - origin
		local distance = offset.Magnitude

		if distance > 3 and distance <= maxRange then
			local direction = offset.Unit
			local dot = aimDirection:Dot(direction)

			if dot >= getOptimalMinDot(part, effectiveController, intent) then
				local hit = Workspace:Raycast(origin, direction * (distance + HIT_OVERSHOOT), grapple.grappleParams)
				local specialName = getSpecialTargetName(part)
				local acceptedByIntent = not IntentTargetGate
					or IntentTargetGate.accept(grapple, hit, part, origin, direction, intent, specialName)
				if
					acceptedByIntent
					and canUseOptimalHit(hit, part)
					and not isVoidProtectedHit(grapple, hit, part, origin, effectiveController)
				then
					local safe, safetyPenalty = applySafety(grapple, hit, part, effectiveController, intent)
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

	return bestHit
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
			return Workspace:Raycast(position, aimDirection * maxRange, grapple.grappleParams)
		end

		local rayOrigin = (currentCamera.CFrame * cameraOffset).Position
			+ currentCamera.CFrame.LookVector
				* (currentCamera.CFrame.Position - (position + humanoid.CameraOffset)).Magnitude
		return Workspace:Raycast(rayOrigin, aimDirection * maxRange, grapple.grappleParams)
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

	return Workspace:Raycast(
		position,
		CFrame.lookAt(position, mouseHit.Position).LookVector * maxRange,
		grapple.grappleParams
	)
end

function Targeting.findBestAssistHit(grapple, controller, context)
	return Targeting.findOptimalHit(grapple, controller, context)
end

return Targeting
