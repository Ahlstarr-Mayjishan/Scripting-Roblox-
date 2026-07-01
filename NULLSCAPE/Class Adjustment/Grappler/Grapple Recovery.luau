--!nocheck
-- [[
--  NULLSCAPE - Grapple Recovery Adjustment
-- ]]

local Recovery = {}

local function getAccessibilityController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeAccessibilityController or nil
end

local function isInfiniteStaminaEnabled(controller)
	local mode = controller and (controller.StaminaMode or controller.GrapplerStaminaMode)
	return tostring(mode or "Off") == "Infinite Stamina"
end

function Recovery.apply(grapple, _dt, beforeTime)
	if not grapple or not beforeTime then
		return
	end

	local accessController = getAccessibilityController()
	if isInfiniteStaminaEnabled(accessController) then
		return
	end

	local speedMultiplier = accessController and accessController.GrapplerStaminaRecoverySpeed or 1

	-- If multiplier is 1x, return control completely to the game's original logic
	if speedMultiplier <= 1 then
		return
	end

	-- If energy is recovered and we are not actively grappling, scale the recovery speed
	if grapple.Time and not grapple.Movement.grappling and grapple.Time > beforeTime then
		local added = grapple.Time - beforeTime
		grapple.Time = math.clamp(grapple.Time + added * (speedMultiplier - 1), 0, grapple.usedGrappleTime)
	end
end

return Recovery
