--!nocheck
-- [[
--  NULLSCAPE - Grappler Cast Safety Check
--  Scores candidate grapple hits for obvious pull traps before targeting commits to them.
-- ]]

local Workspace = game:GetService("Workspace")

local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")

local Safety = {}

local function isSpecial(part)
	return SpecialAnchors and typeof(SpecialAnchors.isSpecial) == "function" and SpecialAnchors.isSpecial(part)
end

local function isRail(part)
	return RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part)
end

local function getVoidY()
	if TerrainMemory and typeof(TerrainMemory.getVoidInfo) == "function" then
		local info = TerrainMemory.getVoidInfo()
		return info and info.Y or nil
	end

	local killVoid = Workspace:FindFirstChild("KillVoid")
	return killVoid and killVoid:IsA("BasePart") and killVoid.Position.Y or nil
end

local function addIssue(result, reason, penalty)
	table.insert(result.Reasons, reason)
	result.Penalty += penalty
end

function Safety.evaluate(grapple, hit, candidatePart, controller, intent)
	local result = {
		Accept = true,
		Penalty = 0,
		Reasons = {},
	}

	local rootPart = grapple and grapple.RootPart
	if not (rootPart and hit and hit.Position and candidatePart) then
		result.Accept = false
		result.Penalty = 100
		table.insert(result.Reasons, "invalid")
		return result
	end

	if isSpecial(candidatePart) or isRail(candidatePart) then
		return result
	end

	local origin = rootPart.Position
	local target = hit.Position
	local offset = target - origin
	local distance = offset.Magnitude
	if distance <= 0.001 then
		result.Accept = false
		result.Penalty = 100
		table.insert(result.Reasons, "zero-distance")
		return result
	end

	local direction = offset.Unit
	local normal = hit.Normal
	local intentName = intent and intent.Name or ""

	if distance < 7 then
		addIssue(result, "too-close", 18)
	end

	if typeof(normal) == "Vector3" then
		if normal.Y < -0.45 then
			addIssue(result, "ceiling-underhit", 36)
		elseif normal.Y < -0.15 and intentName ~= "VoidRescue" then
			addIssue(result, "underside-angle", 18)
		end

		local approachFace = normal:Dot(-direction)
		if approachFace < -0.25 then
			addIssue(result, "backface-pull", 22)
		end
	end

	local voidY = getVoidY()
	if voidY and target.Y - voidY < 10 and intentName ~= "VoidRescue" then
		addIssue(result, "near-void-target", 28)
	end

	local velocity = rootPart.Velocity
	if typeof(velocity) == "Vector3" and velocity.Magnitude > 95 then
		local velocityDirection = velocity.Unit
		if velocityDirection:Dot(direction) < -0.15 then
			addIssue(result, "against-high-momentum", 20)
		end
	end

	local hardReject = tonumber(controller and controller.GrappleAssistSafetyRejectPenalty) or 74
	if result.Penalty >= hardReject then
		result.Accept = false
	end

	return result
end

return Safety
