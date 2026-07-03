--!nocheck
-- [[
--  NULLSCAPE - Grapple Assist Secondary Cast
--  Executes a separate assisted grapple cast from a keybind.
-- ]]

local SecondaryCast = {}
local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")

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

	local hit = getNativeHit(grapple)
	if not hit and targeting and typeof(targeting.findBestAssistHit) == "function" then
		hit = targeting.findBestAssistHit(grapple, controller, {
			ManualCast = true,
		})
	end
	if not hit then
		return false
	end

	hideCrosshair(grapple)

	local success = pcall(function()
		grapple:Start(hit)
	end)
	if hit and hit.Instance and AnchorMemory and typeof(AnchorMemory.noteCastResult) == "function" then
		AnchorMemory.noteCastResult(hit.Instance, success == true)
	end

	return success == true
end

return SecondaryCast
