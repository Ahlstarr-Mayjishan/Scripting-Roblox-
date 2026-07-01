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
local RailMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory.luau")
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

local MAX_SCAN_CANDIDATES = 350
local DEFAULT_RANGE = 90

local function getRange(controller)
	return math.clamp(tonumber(controller and controller.GrappleAssistRange) or DEFAULT_RANGE, 30, 140)
end

local function getCaptureAngle(controller)
	return math.clamp(tonumber(controller and controller.GrappleAssistCaptureAngle) or 9, 1, 30)
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
	if not (part and part:IsA("BasePart")) then
		return false
	end

	if getSpecialTargetName(part) then
		return true
	end

	return part.CanCollide == true and part.Transparency < 1
end

local function getCandidatePart(candidate)
	if typeof(candidate) == "table" then
		return candidate.Part
	end

	return candidate
end

local function getCandidateBonus(part, controller, intent)
	if AnchorProfile and typeof(AnchorProfile.score) == "function" then
		return AnchorProfile.score(part, controller, intent)
	end

	if RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part) then
		return tonumber(controller and controller.GrappleAssistRailPriority) or 42
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
	return instance == candidate or instance:IsDescendantOf(candidate) or candidate:IsDescendantOf(instance)
end

local function getCandidateHit(origin, aimDirection, candidate, controller, minDot, grapple, intent)
	local part = getCandidatePart(candidate)
	if not (part and part:IsA("BasePart")) then
		return nil, -math.huge
	end

	local offset = part.Position - origin
	local distance = offset.Magnitude
	if distance <= 3 then
		return nil, -math.huge
	end

	local direction = offset.Unit
	local dot = aimDirection:Dot(direction)
	if dot < minDot then
		return nil, -math.huge
	end

	local hit = Workspace:Raycast(origin, direction * distance, grapple.grappleParams)
	if not canUseHit(hit, part) then
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
	local memoryBonus = candidate and candidate.LastSuccessfulCast and time() - candidate.LastSuccessfulCast < 12 and 12
		or 0
	local failurePenalty = ((candidate and candidate.FailedAttempts) or 0) * 8
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

	return hit, score
end

local function pickBestFromCandidates(candidates, origin, aimDirection, controller, minDot, grapple, intent)
	local bestHit = nil
	local bestScore = -math.huge
	local secondScore = -math.huge

	for _, candidate in ipairs(candidates) do
		local hit, score = getCandidateHit(origin, aimDirection, candidate, controller, minDot, grapple, intent)
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
		local bell = enemies:FindFirstChild("Bell")
		if bell then
			table.insert(roots, bell)
		end
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
	local maxAngle = math.rad(getCaptureAngle(controller) * getStrength(controller))
	local minDot = math.cos(maxAngle)
	local scanned = 0

	AnchorMemory.refreshBudgeted(nil, controller)
	local cachedAnchors = AnchorMemory.getNearbyAnchors(origin, maxRange, controller)
	local bestHit, bestScore, secondScore =
		pickBestFromCandidates(cachedAnchors, origin, aimDirection, controller, minDot, grapple, intent)

	if shouldTargetRails(controller) and RailMemory and typeof(RailMemory.getNearbyRails) == "function" then
		local nearbyRails = RailMemory.getNearbyRails(origin, maxRange)
		local railHit, railScore, railSecondScore =
			pickBestFromCandidates(nearbyRails, origin, aimDirection, controller, minDot, grapple, intent)
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

			local offset = descendant.Position - origin
			local distance = offset.Magnitude
			if distance > 3 and distance <= maxRange then
				local hit, score =
					getCandidateHit(origin, aimDirection, descendant, controller, minDot, grapple, intent)
				if hit and score > bestScore then
					secondScore = bestScore
					bestScore = score
					bestHit = hit
				elseif hit and score > secondScore then
					secondScore = score
				end
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
