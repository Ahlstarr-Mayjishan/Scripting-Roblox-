--!nocheck
-- [[
--  NULLSCAPE - Grapple Assist Secondary Cast
--  Executes a separate assisted grapple cast from a keybind.
-- ]]

local SecondaryCast = {}
local CastTransaction = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Transaction.luau")
local BellContact =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/Bell Contact Assist.luau")

local function hasBlockedStatus(grapple, statusName)
	local status = grapple and grapple.Status
	if not (status and typeof(status.HasStatus) == "function") then
		return false
	end

	local success, result = pcall(function()
		return status.HasStatus(statusName)
	end)
	return success and result == true
end

local function isEnabled(controller)
	return controller
		and controller.GrappleAssistEnabled == true
		and controller.GrappleAssistSecondaryCastEnabled == true
end

local function canCast(grapple, controller)
	local movement = grapple and grapple.Movement
	if not (grapple and movement and typeof(grapple.Start) == "function") then
		return false
	end
	if not isEnabled(controller) then
		return false
	end
	if movement.grappling or movement.diveBonked or movement.rail or movement.triaHold or movement.Anchored then
		return false
	end
	if hasBlockedStatus(grapple, "Flesh") or hasBlockedStatus(grapple, "Medal") then
		return false
	end
	if tonumber(grapple.Time) == 0 or tonumber(grapple.Charges) == 0 then
		return false
	end

	return true
end

local function getNativeHit(grapple)
	local success, result = pcall(function()
		return grapple:Cast(true)
	end)
	if success then
		return result
	end

	return nil
end

local function hideCrosshair(grapple)
	if not (grapple.Movement and grapple.Movement.toggleAbility == true) then
		grapple.specialHeld = false
	end
	grapple.grappleCancelled = false
	if grapple.grapplerCrosshair then
		grapple.grapplerCrosshair.Parent = nil
	end
end

function SecondaryCast.cast(grapple, controller, targeting)
	if not canCast(grapple, controller) then
		return false
	end

	local context = {
		Technique = "SecondaryCast",
		ManualCast = true,
		AssistiveManual = true,
		SpecialAnchorCapture = true,
	}

	local hit = targeting
			and typeof(targeting.findSpecialAnchorHit) == "function"
			and targeting.findSpecialAnchorHit(grapple, controller, context)
		or nil
	if not hit and targeting and typeof(targeting.fallbackCast) == "function" then
		hit = targeting.fallbackCast(grapple, controller)
	end
	if not hit and targeting and typeof(targeting.findBestAssistHit) == "function" then
		hit = targeting.findBestAssistHit(grapple, controller, {
			Technique = "SecondaryCast",
			ManualCast = true,
			AssistiveManual = true,
		})
	end
	if not hit then
		hit = getNativeHit(grapple)
	end
	if not hit then
		return false
	end

	hideCrosshair(grapple)
	if BellContact and typeof(BellContact.armCast) == "function" then
		pcall(BellContact.armCast, hit)
	end

	local success = CastTransaction
		and typeof(CastTransaction.start) == "function"
		and CastTransaction.start(grapple, hit, controller, "SecondaryCast", {
			ManualCast = true,
			AssistiveManual = true,
		})
	if not success and BellContact and typeof(BellContact.disarm) == "function" then
		pcall(BellContact.disarm)
	end
	return success == true
end

return SecondaryCast
