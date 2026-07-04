--!nocheck
--[[
	NULLSCAPE - Grappler Anchor Preference Profile
	Small scoring layer for user preference + current intent.
]]

local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")

local Profile = {}

local DEFAULTS = {
	TerrainPriority = 140,
	RailPriority = 500,
	SpecialPriority = 700,
	VoidRescueSpecialBoost = 18,
	ReelSaverTerrainBoost = 22,
	RailCaptureBoost = 38,
	MomentumRailBoost = 20,
	RazorbloomEscapeAnchorBoost = 360,
	RazorbloomEscapeOtherSpecialPenalty = -80,
	RazorbloomEscapeTerrainBoost = 25,
}

local function getNumber(value, fallback, minimum, maximum)
	return math.clamp(tonumber(value) or fallback, minimum, maximum)
end

function Profile.getSpecialName(part)
	if SpecialAnchors and typeof(SpecialAnchors.getName) == "function" then
		return SpecialAnchors.getName(part)
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

	if SpecialAnchors and typeof(SpecialAnchors.getPriority) == "function" then
		return SpecialAnchors.getPriority(specialName, controller)
	end

	return getNumber(nil, DEFAULTS.SpecialPriority, 0, 1000)
end

function Profile.getBasePriority(part, controller)
	local kind = Profile.getKind(part)
	if kind == "Rail" then
		return getNumber(controller and controller.GrappleAssistRailPriority, DEFAULTS.RailPriority, 0, 1000)
	end

	if kind == "Special" then
		if controller and controller.GrappleAssistSpecialPointPriority == false then
			return 25
		end
		return getSpecialPriority(part, controller)
	end

	return getNumber(controller and controller.GrappleAssistTerrainPriority, DEFAULTS.TerrainPriority, -50, 300)
end

function Profile.getIntentBonus(part, intent, controller)
	if not intent then
		return 0
	end

	local kind = Profile.getKind(part)
	local name = intent.Name

	if name == "RazorbloomEscape" then
		local specialName = Profile.getSpecialName(part)
		if specialName == "JumpPad" or specialName == "GrapplePoint" then
			return getNumber(
				controller and controller.GrappleIntentRazorbloomAnchorBoost,
				DEFAULTS.RazorbloomEscapeAnchorBoost,
				0,
				700
			)
		end
		if kind == "Special" then
			return getNumber(
				controller and controller.GrappleIntentRazorbloomOtherSpecialPenalty,
				DEFAULTS.RazorbloomEscapeOtherSpecialPenalty,
				-500,
				0
			)
		end
		return getNumber(
			controller and controller.GrappleIntentRazorbloomTerrainBoost,
			DEFAULTS.RazorbloomEscapeTerrainBoost,
			0,
			80
		)
	end

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
