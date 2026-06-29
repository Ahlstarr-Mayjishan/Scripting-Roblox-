--!nocheck
-- [[
--  NULLSCAPE - Grappler Target Roles
--  Scores known grapple targets by their gameplay role instead of treating every
--  valid part as the same kind of anchor.
-- ]]

local TargetRoles = {}

local ROLE_LIMITS = {
	GrapplePoint = 0.42,
	JumpPad = 0.48,
	Bell = 0.44,
	TriaOrb = 0.46,
}

local ROLE_FORCE_LIMITS = {
	GrapplePoint = 0.5,
	JumpPad = 0.56,
	Bell = 0.52,
	TriaOrb = 0.54,
}

local function getVelocity(grapple)
	local rootPart = grapple and grapple.RootPart
	return rootPart and rootPart.Velocity or Vector3.zero
end

local function getHorizontalSpeed(velocity)
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

function TargetRoles.getCursorLimit(_, targetName, forceCursor, baseLimit)
	local roleLimit = (forceCursor and ROLE_FORCE_LIMITS[targetName]) or ROLE_LIMITS[targetName]
	if not roleLimit then
		return baseLimit
	end
	return math.max(baseLimit or 0, roleLimit)
end

function TargetRoles.getCursorBonus(cfg, targetName, screenScore)
	if not targetName or not ROLE_LIMITS[targetName] then
		return 0
	end
	local limit = cfg and cfg.CURSOR_SPECIAL_TARGET_LIMIT or ROLE_LIMITS[targetName]
	if screenScore and screenScore <= limit then
		return cfg and cfg.CURSOR_SPECIAL_TARGET_BONUS or -65
	end
	return 0
end

function TargetRoles.score(deps, grapple, targetName, targetPosition, context)
	local cfg = deps and deps.CFG
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and targetName and typeof(targetPosition) == "Vector3") then
		return 0, "NoRole"
	end

	local velocity = getVelocity(grapple)
	local horizontalSpeed = getHorizontalSpeed(velocity)
	local vertical = targetPosition.Y - rootPart.Position.Y
	local score = 0
	local reason = targetName

	if targetName == "JumpPad" then
		if velocity.Y <= (cfg and cfg.ASSIST_SPECIAL_JUMPPAD_FALL_SPEED or -70) then
			score -= 46
			reason = "JumpPadRescue"
		elseif vertical >= -8 and vertical <= 28 then
			score -= 18
			reason = "JumpPadRoute"
		else
			score += 20
			reason = "JumpPadOffRoute"
		end
	elseif targetName == "TriaOrb" then
		if horizontalSpeed >= (cfg and cfg.ASSIST_SPECIAL_TRIA_SPEED or 120) then
			score -= 42
			reason = "TriaMomentum"
		else
			score += 12
			reason = "TriaLowSpeed"
		end
	elseif targetName == "Bell" then
		if velocity.Y <= (cfg and cfg.ASSIST_SPECIAL_BELL_FALL_SPEED or -45) then
			score -= 52
			reason = "BellRescue"
		elseif context and context.RescueMode then
			score -= 34
			reason = "BellFallback"
		else
			score += 26
			reason = "BellConservative"
		end
	elseif targetName == "GrapplePoint" then
		if vertical >= 6 and vertical <= 64 then
			score -= 28
			reason = "GrappleSwing"
		elseif vertical < -18 then
			score += 34
			reason = "GrappleTooLow"
		else
			score -= 8
			reason = "GrappleNeutral"
		end
	end

	if context and context.PanicMode and (targetName == "Bell" or targetName == "JumpPad") then
		score -= 24
		reason = reason .. "/Panic"
	end

	return score, reason
end

return TargetRoles
