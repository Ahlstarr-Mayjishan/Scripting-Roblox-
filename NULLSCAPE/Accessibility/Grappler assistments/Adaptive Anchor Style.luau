--!nocheck
--[[
	NULLSCAPE - Adaptive Anchor Style
	Builds a temporary targeting profile from the current grapple intent.
]]

local AdaptiveStyle = {}

local STYLE_OVERRIDES = {
	Manual = {
		ManualAngle = 18,
		GrapplePoint = 620,
		JumpPad = 520,
		TriaOrb = 520,
		Bell = 460,
		Terrain = 170,
		Rail = 520,
	},
	Pilot = {
		ManualAngle = 26,
		GrapplePoint = 730,
		JumpPad = 690,
		TriaOrb = 660,
		Bell = 580,
		Terrain = 145,
		Rail = 560,
	},
	Emergency = {
		ManualAngle = 32,
		GrapplePoint = 880,
		JumpPad = 840,
		TriaOrb = 800,
		Bell = 760,
		Terrain = 190,
		Rail = 620,
	},
	ReelSaver = {
		ManualAngle = 22,
		GrapplePoint = 540,
		JumpPad = 480,
		TriaOrb = 500,
		Bell = 430,
		Terrain = 240,
		Rail = 520,
	},
	RailCapture = {
		ManualAngle = 24,
		GrapplePoint = 600,
		JumpPad = 560,
		TriaOrb = 560,
		Bell = 500,
		Terrain = 150,
		Rail = 760,
	},
	Momentum = {
		ManualAngle = 20,
		GrapplePoint = 570,
		JumpPad = 520,
		TriaOrb = 520,
		Bell = 460,
		Terrain = 190,
		Rail = 680,
	},
	RazorbloomEscape = {
		ManualAngle = 34,
		GrapplePoint = 980,
		JumpPad = 1000,
		TriaOrb = 500,
		Bell = 470,
		Terrain = 150,
		Rail = 520,
	},
}

local function isAuto(controller)
	return not controller or tostring(controller.GrappleAnchorTargetingStyle or "Auto") == "Auto"
end

local function getMode(intent)
	local name = intent and intent.Name
	local pilotMode = intent and intent.PilotMode

	if pilotMode == "Emergency" or name == "VoidRescue" then
		return "Emergency"
	end
	if name == "ReelSaver" then
		return "ReelSaver"
	end
	if name == "RazorbloomEscape" then
		return "RazorbloomEscape"
	end
	if name == "RailCapture" then
		return "RailCapture"
	end
	if name == "MomentumControl" then
		return "Momentum"
	end
	if pilotMode == "Pilot" then
		return "Pilot"
	end

	return "Manual"
end

local function overlay(controller, mode, style)
	local proxy = {
		GrappleAnchorAdaptiveMode = mode,
		GrappleAssistManualAnchorAngle = style.ManualAngle,
		GrappleAnchorPriorityGrapplePoint = style.GrapplePoint,
		GrappleAnchorPriorityJumpPad = style.JumpPad,
		GrappleAnchorPriorityTriaOrb = style.TriaOrb,
		GrappleAnchorPriorityBell = style.Bell,
		GrappleAssistTerrainPriority = style.Terrain,
		GrappleAssistRailPriority = style.Rail,
	}

	return setmetatable(proxy, {
		__index = controller,
	})
end

function AdaptiveStyle.resolve(controller, intent)
	if not isAuto(controller) then
		return controller, nil
	end

	local mode = getMode(intent)
	local style = STYLE_OVERRIDES[mode] or STYLE_OVERRIDES.Manual
	return overlay(controller, mode, style), mode
end

return AdaptiveStyle
