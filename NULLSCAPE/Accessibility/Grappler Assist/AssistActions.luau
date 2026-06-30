--!nocheck
--[[
 NULLSCAPE - Grappler Assist Actions
 Shared action helpers for special-action pulses, recast windows, and target arrival checks.
]]

local AssistActions = {}

local function horizontal(vector)
	if typeof(vector) ~= "Vector3" then
		return Vector3.new(0, 0, 0)
	end
	return Vector3.new(vector.X, 0, vector.Z)
end

function AssistActions.fireSpecialAction(grapple, state)
	local movement = grapple and grapple.Movement
	if not (movement and typeof(movement.SpecialAction) == "function") then
		return false
	end

	local success = pcall(function()
		movement:SpecialAction(state)
	end)

	return success
end

function AssistActions.pulseSpecialAction(logic, cfg, grapple, getTrackedGrapple)
	if time() - logic.LastAdaptPulseAt < cfg.ADAPT_RECAST_COOLDOWN then
		return false
	end
	if not AssistActions.fireSpecialAction(grapple, Enum.UserInputState.Begin) then
		return false
	end

	logic.LastAdaptPulseAt = time()
	logic.AdaptAwaitingAttachUntil = logic.LastAdaptPulseAt + cfg.ADAPT_ATTACH_GRACE
	logic.AdaptRetryAt = logic.AdaptAwaitingAttachUntil + cfg.ADAPT_RETRY_DELAY

	local token = logic.AdaptRecastToken + 1
	logic.AdaptRecastToken = token

	task.delay(cfg.ADAPT_INPUT_PULSE_DURATION, function()
		if logic.AdaptRecastToken ~= token then
			return
		end

		local activeGrapple = grapple
		if not activeGrapple or typeof(activeGrapple) ~= "table" then
			activeGrapple = getTrackedGrapple and getTrackedGrapple() or nil
		end
		if not activeGrapple then
			return
		end

		AssistActions.fireSpecialAction(activeGrapple, Enum.UserInputState.End)
		if logic.AdaptInputHeld ~= true then
			logic.AdaptDriveActive = false
		end
	end)

	return true
end

function AssistActions.armAutoRescueWindow(logic, cfg)
	logic.AutoRescueUntil = time() + cfg.AUTO_RESCUE_WINDOW
end

function AssistActions.isAutoRescueWindowActive(logic)
	return time() <= (logic.AutoRescueUntil or 0)
end

function AssistActions.isEmergencyRescueRecastBlocked(logic, grapple, ignoreTimeLock)
	if not ignoreTimeLock and time() <= (logic.EmergencyRescueLockUntil or 0) then
		return true
	end

	if not ignoreTimeLock and logic.isJumpPadCommitGuardActive() then
		return true
	end

	local movement = grapple and grapple.Movement
	if movement and (movement.grappling == true or grapple.jumpPadReel == true or logic.isAwaitingAdaptAttach(grapple)) then
		return true
	end

	return false
end

function AssistActions.markEmergencyRescuePulse(logic, cfg)
	logic.EmergencyRescueLockUntil =
		math.max(logic.EmergencyRescueLockUntil or 0, time() + cfg.EMERGENCY_RESCUE_RECAST_LOCK)
end

function AssistActions.getAdaptHorizontalSpeed(grapple)
	local rootPart = grapple and grapple.RootPart
	local value = rootPart and rootPart.Velocity or nil
	local flat = horizontal(value)
	return flat.Magnitude, flat
end

function AssistActions.getActiveGrappleTargetPosition(grapple)
	local movement = grapple and grapple.Movement
	if movement and typeof(movement.grapplePoint) == "Vector3" then
		return movement.grapplePoint
	end

	local part = (movement and movement.grapplePart) or grapple and grapple.grapplePart
	if part and part.Parent and part:IsA("BasePart") then
		return part.Position
	end

	return nil
end

function AssistActions.getAdaptArrivalDistance(cfg, grapple)
	local movement = grapple and grapple.Movement
	local part = (movement and movement.grapplePart) or grapple and grapple.grapplePart
	if part and part.Parent and part.Name == "TriaOrb" then
		return cfg.ADAPT_RECAST_TRIA_ARRIVAL_DISTANCE
	elseif part and part.Parent and part.Name == "GrapplePoint" then
		return cfg.ADAPT_RECAST_GRAPPLEPOINT_DISTANCE
	elseif part and part.Parent and (part.Name == "JumpPad" or part.Name == "Bell") then
		return cfg.ADAPT_RECAST_BOUNCE_DISTANCE
	end

	local size = part and part.Parent and part:IsA("BasePart") and part.Size.Magnitude * 0.45 or 0
	return math.max(cfg.ADAPT_RECAST_ARRIVAL_DISTANCE, size)
end

function AssistActions.hasReachedGrappleDestination(cfg, grapple)
	local rootPart = grapple and grapple.RootPart
	local targetPosition = AssistActions.getActiveGrappleTargetPosition(grapple)
	if not (rootPart and targetPosition) then
		return true
	end

	local remainingDistance = (targetPosition - rootPart.Position).Magnitude
	if remainingDistance <= AssistActions.getAdaptArrivalDistance(cfg, grapple) then
		return true
	end

	local rootVelocity = rootPart.Velocity
	if not rootVelocity then
		return false
	end

	local toTarget = targetPosition - rootPart.Position
	if toTarget.Magnitude <= 0.001 then
		return true
	end

	return rootVelocity:Dot(toTarget.Unit) <= 0
end

function AssistActions.clampAdaptRecastVelocity(cfg, grapple)
	local rootPart = grapple and grapple.RootPart
	if not rootPart then
		return
	end

	local speed, flat = AssistActions.getAdaptHorizontalSpeed(grapple)
	if speed <= cfg.ADAPT_RECAST_SAFE_SPEED or speed <= 0 then
		return
	end

	local clampedHorizontal = flat.Unit * cfg.ADAPT_RECAST_CLAMP_SPEED
	rootPart.Velocity = Vector3.new(clampedHorizontal.X, rootPart.Velocity.Y, clampedHorizontal.Z)
end

return AssistActions
