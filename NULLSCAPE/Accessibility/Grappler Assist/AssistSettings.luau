--!nocheck
--[[
 NULLSCAPE - Grappler Assist Settings
 Centralizes controller reads and mode normalization for Grappler Assist.
]]

local AssistSettings = {}

function AssistSettings.getController(globals)
	return globals and globals.activeAccessibilityController or nil
end

function AssistSettings.normalizeMode(value)
	value = tostring(value or "Manual")
	if value == "Automatic" then
		return "Automatic"
	end
	return "Manual"
end

function AssistSettings.normalizeEmergencyMode(value)
	value = tostring(value or "Manual")
	if value == "Smart Auto" then
		return "Smart Auto"
	end
	if value == "Automatic" then
		return "Automatic"
	end
	return "Manual"
end

function AssistSettings.normalizeStyle(value, styleConfig)
	value = tostring(value or "Balanced")
	if styleConfig and styleConfig[value] then
		return value
	end
	return "Balanced"
end

function AssistSettings.isSuiteEnabled(controller)
	return controller and controller.GrappleAssistSuiteEnabled == true
end

function AssistSettings.isAimAssistEnabled(controller)
	return AssistSettings.isSuiteEnabled(controller) and controller.GrappleAimAssistEnabled == true
end

function AssistSettings.isRescueEnabled(controller)
	return AssistSettings.isSuiteEnabled(controller) and controller.GrappleRescueAssistEnabled == true
end

function AssistSettings.isEmergencyProtectionEnabled(controller)
	return AssistSettings.isSuiteEnabled(controller) and controller.GrappleEmergencyProtectionEnabled == true
end

function AssistSettings.isVoidRescueEnabled(controller)
	return AssistSettings.isEmergencyProtectionEnabled(controller) and controller.GrappleVoidRescueEnabled ~= false
end

function AssistSettings.isWallSlamRescueEnabled(controller)
	return AssistSettings.isEmergencyProtectionEnabled(controller) and controller.GrappleWallSlamRescueEnabled == true
end

function AssistSettings.isAntiBonkEnabled(controller)
	return controller and controller.AntiBonkEnabled == true
end

function AssistSettings.isSmartReelEnabled(controller)
	return AssistSettings.isSuiteEnabled(controller) and controller.GrappleSmartReelEnabled == true
end

function AssistSettings.isSharkTailHelperEnabled(controller)
	return AssistSettings.isSuiteEnabled(controller) and controller.GrappleSharkTailHelperEnabled == true
end

function AssistSettings.isMomentumGuardEnabled(controller)
	return AssistSettings.isSuiteEnabled(controller) and controller.GrappleMomentumGuardEnabled == true
end

function AssistSettings.isAntiDetachEnabled(controller)
	return AssistSettings.isSuiteEnabled(controller) and controller.GrappleAntiDetachEnabled == true
end

function AssistSettings.getEmergencyProtectionMode(controller)
	return AssistSettings.normalizeEmergencyMode(controller and controller.GrappleEmergencyProtectionMode)
end

function AssistSettings.getEmergencySpeedThreshold(controller)
	return math.clamp(tonumber(controller and controller.GrappleEmergencySpeedThreshold) or 220, 150, 320)
end

function AssistSettings.getEmergencyFallThreshold(controller)
	return math.clamp(tonumber(controller and controller.GrappleEmergencyFallThreshold) or 125, 80, 220)
end

function AssistSettings.getAdaptInputKeyCode(controller)
	local keyName = tostring(controller and controller.GrappleAdaptInputKey or "T")
	return Enum.KeyCode[keyName] or Enum.KeyCode.T
end

function AssistSettings.getModeValue(controller, key)
	return AssistSettings.normalizeMode(controller and controller[key])
end

function AssistSettings.getSharkTailStyle(controller, styleConfig)
	return AssistSettings.normalizeStyle(controller and controller.GrappleSharkTailStyle, styleConfig)
end

function AssistSettings.getAimAssistStrengthScale(controller)
	local value = tostring(controller and controller.GrappleAimAssistStrength or "Balanced")
	if value == "Light" then
		return 1.2
	elseif value == "Strong" then
		return 3.0
	elseif value == "Motor Accessibility" then
		return 6.0
	end

	return 1.8
end

return AssistSettings
