--!nocheck
-- [[
--  NULLSCAPE - Grapple Assist Targeting
--  Finds the best fallback grapple target near the player's aim direction.
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local IntentResolver = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Intent Resolver.luau")
local AnchorProfile =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Anchor Preference Profile.luau")
local CastSafety = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Safety Check.luau")
local BadAnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Bad Anchor Memory.luau")
local AnchorBias = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Anchor Bias Profile.luau")
local ConfidenceGate = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Assist Confidence Gate.luau")

local Targeting = {}

local SPECIAL_TARGETS = {
	JumpPad = true,
	GrapplePoint = true,
	Bell = true,
	TriaOrb = true,
}

local MAX_SCAN_CANDIDATES = 700
local DEFAULT_RANGE = 500
local DEFAULT_CAPTURE_ANGLE = 45
local MAX_FALLBACK_TRANSPARENCY = 0.72
local MAX_FALLBACK_AXIS = 160
local HIT_POINT_TOLERANCE = 6
local HIT_OVERSHOOT = 2

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
	return math.clamp(tonumber(controller and controller.GrappleAssistRange) or DEFAULT_RANGE, 30, 500)
end

local function getCaptureAngle(controller)
	return math.clamp(tonumber(controller and controller.GrappleAssistCaptureAngle) or DEFAULT_CAPTURE_ANGLE, 1, 45)
end

local function getStrength(controller)
	return math.clamp(tonumber(controller and controller.GrappleAssistStrength) or 1, 0.1, 3)
end

local function shouldPrioritizeSpecials(controller)
	return not (controller and controller.GrappleAssistSpecialPointPriority == false)
end

local function shouldTargetRails(controller)
	return not (controller and controller.GrappleAssistRailTargetingEnabled == false)
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

local function hasTag(instance, tagName)
	if not (instance and typeof(instance.HasTag) == "function") then
		return false
	end

	local success, result = pcall(function()
		return instance:HasTag(tagName)
	end)

	return success and result == true
end

local function getSpecialTargetName(part)
	if AnchorProfile and typeof(AnchorProfile.getSpecialName) == "function" then
		local specialName = AnchorProfile.getSpecialName(part)
		if specialName then
			return specialName
		end
	end

	if not (part and part:IsA("BasePart")) then
		return nil
	end

	if SPECIAL_TARGETS[part.Name] then
		return part.Name
	end

	if hasTag(part, "JumpPad") then
		return "JumpPad"
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

local function isCandidate(part)
	if not isAliveBasePart(part) then
		return false
	end

	if getSpecialTargetName(part) then
		return true
	end

	if hasBlockedFallbackName(part) then
		return false
	end

	if RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part) then
		return part.Transparency <= MAX_FALLBACK_TRANSPARENCY and part.CanCollide == true
	end

	local size = part.Size
	local maxAxis = math.max(size.X, size.Y, size.Z)
	if maxAxis > MAX_FALLBACK_AXIS then
		return false
	end

	if part.Transparency > MAX_FALLBACK_TRANSPARENCY then
		return false
	end

	return part.CanCollide == true and part.Transparency < 1
end

local function getCandidatePart(candidate)
	if type(candidate) == "table" then
		return rawget(candidate, "Part")
	end

	return candidate
end

local function getCandidateBonus(part, controller, intent)
	if AnchorProfile and typeof(AnchorProfile.score) == "function" then
		return AnchorProfile.score(part, controller, intent)
	end

	if RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part) then
		return tonumber(controller and controller.GrappleAssistRailPriority) or 500
	end

	local specialName = getSpecialTargetName(part)
	if specialName then
		if not shouldPrioritizeSpecials(controller) then
			return 25
		end

		if AnchorMemory and typeof(AnchorMemory.getPriority) == "function" then
			return AnchorMemory.getPriority(specialName, controller)
		end

		return 55
	end

	return 0
end

local function canUseHit(hit, candidate)
	if not (hit and candidate) then
		return false
	end

	local instance = hit.Instance
	if not isAliveBasePart(instance) then
		return false
	end

	return instance == candidate or instance:IsDescendantOf(candidate)
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

local function getCandidateHit(origin, aimDirection, candidate, controller, minDot, maxRange, grapple, intent)
	local part = getCandidatePart(candidate)
	if not isCandidate(part) then
		return nil, -math.huge
	end

	local targetPoint = getSurfaceTargetPoint(part, origin)
	local offset = targetPoint - origin
	local distance = offset.Magnitude
	if distance <= 3 then
		return nil, -math.huge
	end
	if distance > maxRange then
		return nil, -math.huge
	end

	local direction = offset.Unit
	local dot = aimDirection:Dot(direction)
	if dot < minDot then
		return nil, -math.huge
	end

	local hit = Workspace:Raycast(origin, direction * (distance + HIT_OVERSHOOT), grapple.grappleParams)
	if not canUseHit(hit, part) then
		return nil, -math.huge
	end
	if (hit.Position - targetPoint).Magnitude > HIT_POINT_TOLERANCE then
		return nil, -math.huge
	end

	local safetyPenalty = 0
	if CastSafety and typeof(CastSafety.evaluate) == "function" then
		local safety = CastSafety.evaluate(grapple, hit, part, controller, intent)
		if safety and safety.Accept == false then
			if BadAnchorMemory and typeof(BadAnchorMemory.note) == "function" then
				BadAnchorMemory.note(part, table.concat(safety.Reasons or {}, ","), safety.Penalty or 20)
			end
			return nil, -math.huge
		end

		safetyPenalty = safety and tonumber(safety.Penalty) or 0
		if safetyPenalty >= 24 and BadAnchorMemory and typeof(BadAnchorMemory.note) == "function" then
			BadAnchorMemory.note(part, table.concat(safety.Reasons or {}, ","), safetyPenalty * 0.45)
		end
	end

	local biasScore = 0
	if AnchorBias and typeof(AnchorBias.score) == "function" then
		local success, score = pcall(AnchorBias.score, grapple, hit, part, origin, aimDirection, controller, intent)
		if success then
			biasScore = tonumber(score) or 0
		end
	end

	local anglePenalty = math.deg(math.acos(math.clamp(dot, -1, 1))) * 6
	local distancePenalty = distance * 0.35
	local candidateEntry = type(candidate) == "table" and candidate or nil
	local lastSuccessfulCast = candidateEntry and tonumber(rawget(candidateEntry, "LastSuccessfulCast")) or nil
	local failedAttempts = candidateEntry and tonumber(rawget(candidateEntry, "FailedAttempts")) or 0
	local memoryBonus = lastSuccessfulCast and time() - lastSuccessfulCast < 12 and 12 or 0
	local failurePenalty = failedAttempts * 8
	local badAnchorPenalty = BadAnchorMemory
			and typeof(BadAnchorMemory.getPenalty) == "function"
			and BadAnchorMemory.getPenalty(part)
		or 0
	local confidenceBonus = intent and (tonumber(intent.Confidence) or 0) * 8 or 0
	local score = getCandidateBonus(part, controller, intent)
		+ confidenceBonus
		+ memoryBonus
		+ biasScore
		- anglePenalty
		- distancePenalty
		- failurePenalty
		- safetyPenalty
		- badAnchorPenalty
	local isRail = RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part)
	if not getSpecialTargetName(part) and not isRail then
		score += getTerrainScore(hit, origin)
	end

	return hit, score
end

local function pickBestFromCandidates(candidates, origin, aimDirection, controller, minDot, maxRange, grapple, intent)
	local bestHit = nil
	local bestScore = -math.huge
	local secondScore = -math.huge

	for _, candidate in ipairs(candidates) do
		local hit, score =
			getCandidateHit(origin, aimDirection, candidate, controller, minDot, maxRange, grapple, intent)
		if hit and score > bestScore then
			secondScore = bestScore
			bestScore = score
			bestHit = hit
		elseif hit and score > secondScore then
			secondScore = score
		end
	end

	return bestHit, bestScore, secondScore
end

local function collectFallbackDescendants()
	local roots = {}
	local jumpPads = Workspace:FindFirstChild("JumpPads")
	local currentRooms = Workspace:FindFirstChild("CurrentRooms")
	local enemies = Workspace:FindFirstChild("Enemies")
	if jumpPads then
		table.insert(roots, jumpPads)
	end
	if currentRooms then
		table.insert(roots, currentRooms)
	end
	if enemies then
		table.insert(roots, enemies)
	end
	if #roots == 0 then
		table.insert(roots, Workspace)
	end

	local descendants = {}
	for _, root in ipairs(roots) do
		if isCandidate(root) then
			table.insert(descendants, root)
		end
		for _, descendant in ipairs(root:GetDescendants()) do
			table.insert(descendants, descendant)
		end
	end

	return descendants
end

function Targeting.findBestAssistHit(grapple, controller)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and grapple.grappleParams) then
		return nil
	end

	local aimDirection = Targeting.getAimDirection(grapple)
	if not aimDirection or aimDirection.Magnitude <= 0.001 then
		return nil
	end

	local origin = rootPart.Position
	local intent = IntentResolver
			and typeof(IntentResolver.resolve) == "function"
			and IntentResolver.resolve(grapple, controller, {
				AimDirection = aimDirection,
			})
		or nil
	local maxRange = getRange(controller)
	local maxAngle = math.rad(math.clamp(getCaptureAngle(controller) * getStrength(controller), 1, 75))
	local minDot = math.cos(maxAngle)
	local scanned = 0

	AnchorMemory.refreshBudgeted(nil, controller)
	local cachedAnchors = AnchorMemory.getNearbyAnchors(origin, maxRange, controller)
	local bestHit, bestScore, secondScore =
		pickBestFromCandidates(cachedAnchors, origin, aimDirection, controller, minDot, maxRange, grapple, intent)

	if shouldTargetRails(controller) and RailMemory and typeof(RailMemory.getNearbyRails) == "function" then
		local nearbyRails = RailMemory.getNearbyRails(origin, maxRange)
		local railHit, railScore, railSecondScore =
			pickBestFromCandidates(nearbyRails, origin, aimDirection, controller, minDot, maxRange, grapple, intent)
		if railSecondScore and railSecondScore > secondScore then
			secondScore = railSecondScore
		end
		if railHit and railScore > bestScore then
			secondScore = bestScore
			bestHit = railHit
			bestScore = railScore
		elseif railHit and railScore > secondScore then
			secondScore = railScore
		end
	end

	for _, descendant in ipairs(collectFallbackDescendants()) do
		if scanned >= MAX_SCAN_CANDIDATES then
			break
		end
		if isCandidate(descendant) then
			scanned += 1
			if AnchorMemory.isSpecialAnchor(descendant) then
				AnchorMemory.remember(descendant, "targeting-scan", controller)
			end

			local hit, score =
				getCandidateHit(origin, aimDirection, descendant, controller, minDot, maxRange, grapple, intent)
			if hit and score > bestScore then
				secondScore = bestScore
				bestScore = score
				bestHit = hit
			elseif hit and score > secondScore then
				secondScore = score
			end
		end
	end

	if ConfidenceGate and typeof(ConfidenceGate.accept) == "function" then
		local success, accepted = pcall(ConfidenceGate.accept, bestHit, bestScore, secondScore, controller, intent)
		if success and accepted == false then
			return nil
		end
	end

	return bestHit
end

return Targeting
