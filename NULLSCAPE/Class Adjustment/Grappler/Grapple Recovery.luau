--!nocheck
-- [[
--  NULLSCAPE - Grapple Recovery Adjustment
-- ]]

local Recovery = {}

function Recovery.apply(grapple, _dt, beforeTime)
	if not grapple or not beforeTime then
		return
	end

	-- Check if Infinite Stamina is active
	local StaminaAssist = getgenv().loadModule("NULLSCAPE/Accessibility/Stamina Assist.luau")
	if StaminaAssist and typeof(StaminaAssist.isEnabled) == "function" and StaminaAssist.isEnabled() then
		-- Infinite Stamina is running, let it take control
		return
	end

	local accessController = getgenv().loadModule("NULLSCAPE/Accessibility/controller.luau")
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
