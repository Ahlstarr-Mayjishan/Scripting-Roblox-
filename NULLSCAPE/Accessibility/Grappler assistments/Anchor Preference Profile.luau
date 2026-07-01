--!nocheck
--[[
	NULLSCAPE - Grappler Anchor Preference Profile
	Small scoring layer for user preference + current intent.
]]

local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")

local Profile = {}

local DEFAULTS = {
	TerrainPriority = 0,
	RailPriority = 42,
	SpecialPriority = 55,
	VoidRescueSpecialBoost = 18,
	ReelSaverTerrainBoost = 22,
	RailCaptureBoost = 38,
	MomentumRailBoost = 20,
}

local SPECIAL_FIELDS = {
	GrapplePoint = "GrappleAnchorPriorityGrapplePoint",
	JumpPad = "GrappleAnchorPriorityJumpPad",
	TriaOrb = "GrappleAnchorPriorityTriaOrb",
	Bell = "GrappleAnchorPriorityBell",
}

local function getNumber(value, fallback, minimum, maximum)
	return math.clamp(tonumber(value) or fallback, minimum, maximum)
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

function Profile.getSpecialName(part)
	if not (part and part:IsA("BasePart")) then
		return nil
	end

	if SPECIAL_FIELDS[part.Name] then
		return part.Name
	end

	if hasTag(part, "JumpPad") then
		return "JumpPad"
	end

	return nil
end

function Profile.getKind(part)
	if RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part) then
		return "Rail"
	end

	if Profile.getSpecialName(part) then
		return "Special"
	end

	return "Terrain"
end

local function getSpecialPriority(part, controller)
	local specialName = Profile.getSpecialName(part)
	if not specialName then
		return DEFAULTS.SpecialPriority
	end

	local field = SPECIAL_FIELDS[specialName]
	return getNumber(controller and controller[field], DEFAULTS.SpecialPriority, 0, 150)
end

function Profile.getBasePriority(part, controller)
	local kind = Profile.getKind(part)
	if kind == "Rail" then
		return getNumber(controller and controller.GrappleAssistRailPriority, DEFAULTS.RailPriority, 0, 150)
	end

	if kind == "Special" then
		if controller and controller.GrappleAssistSpecialPointPriority == false then
			return 25
		end
		return getSpecialPriority(part, controller)
	end

	return getNumber(controller and controller.GrappleAssistTerrainPriority, DEFAULTS.TerrainPriority, -50, 80)
end

function Profile.getIntentBonus(part, intent, controller)
	if not intent then
		return 0
	end

	local kind = Profile.getKind(part)
	local name = intent.Name

	if name == "VoidRescue" and kind == "Special" then
		return getNumber(
			controller and controller.GrappleIntentVoidSpecialBoost,
			DEFAULTS.VoidRescueSpecialBoost,
			0,
			80
		)
	end

	if name == "ReelSaver" and kind == "Terrain" then
		return getNumber(controller and controller.GrappleIntentReelTerrainBoost, DEFAULTS.ReelSaverTerrainBoost, 0, 80)
	end

	if name == "RailCapture" and kind == "Rail" then
		return getNumber(controller and controller.GrappleIntentRailBoost, DEFAULTS.RailCaptureBoost, 0, 100)
	end

	if name == "MomentumControl" and kind == "Rail" then
		return getNumber(controller and controller.GrappleIntentMomentumRailBoost, DEFAULTS.MomentumRailBoost, 0, 80)
	end

	return 0
end

function Profile.score(part, controller, intent)
	return Profile.getBasePriority(part, controller) + Profile.getIntentBonus(part, intent, controller)
end

return Profile
