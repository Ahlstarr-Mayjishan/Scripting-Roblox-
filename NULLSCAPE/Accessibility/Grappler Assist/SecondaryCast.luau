--!nocheck
-- [[
--  NULLSCAPE - Secondary Cast Skill (Adapt Drive / phim T) Module
-- ]]

local UserInputService = game:GetService("UserInputService")

local SecondaryCast = {}
local Logic
local CFG

function SecondaryCast.link(logicInstance)
	Logic = logicInstance
	CFG = Logic.CFG

	Logic.AdaptDriveActive = Logic.AdaptDriveActive or false
	Logic.AdaptDriveActiveUntil = Logic.AdaptDriveActiveUntil or 0
	Logic.LastAdaptInputPressed = Logic.LastAdaptInputPressed or 0
	Logic.AdaptInputHeld = Logic.AdaptInputHeld or false
	Logic.AdaptInputBeganAt = Logic.AdaptInputBeganAt or 0
	Logic.AdaptRecastPending = Logic.AdaptRecastPending or false
	Logic.AdaptRecastReleaseIssued = Logic.AdaptRecastReleaseIssued or false
	Logic.AdaptAwaitingAttachUntil = Logic.AdaptAwaitingAttachUntil or 0
	Logic.AdaptRetryAt = Logic.AdaptRetryAt or 0
	Logic.LastAdaptPulseAt = Logic.LastAdaptPulseAt or 0
	Logic.AdaptRecastRequestedAt = Logic.AdaptRecastRequestedAt or 0
	Logic.AdaptRecastReleaseAt = Logic.AdaptRecastReleaseAt or 0
	Logic.AdaptRecastToken = Logic.AdaptRecastToken or 0
	Logic.AdaptPreparedTarget = Logic.AdaptPreparedTarget or nil
	Logic.AdaptPreparedTargetAt = Logic.AdaptPreparedTargetAt or 0
	Logic.InputConnections = Logic.InputConnections or {}
end

function SecondaryCast.prepareDriveTarget(grapple, originalResult)
	if not (grapple and Logic.AdaptDriveActive == true) then
		return nil
	end

	local target = SecondaryCast.scanSecondaryCastTarget(grapple, originalResult, false)
	if not Logic.isUsableResult(grapple, target) and typeof(Logic.getNativeCastResult) == "function" then
		local nativeResult = Logic.getNativeCastResult(grapple, true)
		if Logic.isUsableResult(grapple, nativeResult) then
			target = nativeResult
			Logic.LastAssistDebug = {
				Reason = "SecondaryNativeFallback",
				Score = 0,
				Target = nativeResult.Instance and nativeResult.Instance.Name or "Native",
			}
		end
	end
	if not Logic.isUsableResult(grapple, target) then
		Logic.AdaptPreparedTarget = nil
		Logic.AdaptPreparedTargetAt = 0
		return nil
	end

	Logic.AdaptPreparedTarget = target
	Logic.AdaptPreparedTargetAt = time()
	return target
end

function SecondaryCast.consumePreparedDriveTarget(grapple)
	local target = Logic.AdaptPreparedTarget
	if not Logic.isUsableResult(grapple, target) then
		Logic.AdaptPreparedTarget = nil
		Logic.AdaptPreparedTargetAt = 0
		return nil
	end

	if time() - (Logic.AdaptPreparedTargetAt or 0) > CFG.ADAPT_PREPARED_TARGET_TTL then
		Logic.AdaptPreparedTarget = nil
		Logic.AdaptPreparedTargetAt = 0
		return nil
	end

	Logic.AdaptPreparedTarget = nil
	Logic.AdaptPreparedTargetAt = 0
	return target
end

function SecondaryCast.isAwaitingAdaptAttach(grapple)
	local movement = grapple and grapple.Movement
	if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
		Logic.AdaptAwaitingAttachUntil = 0
		Logic.AdaptRetryAt = 0
		return false
	end

	return time() <= (Logic.AdaptAwaitingAttachUntil or 0)
end

function SecondaryCast.requestAdaptRecast(grapple)
	if not Logic.hasClassCapability(grapple, "AimAssist") then
		return false
	end

	local now = time()
	if now - Logic.LastAdaptPulseAt < CFG.ADAPT_RECAST_COOLDOWN then
		return false
	end

	local movement = grapple and grapple.Movement
	if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
		Logic.AdaptRecastPending = true
		Logic.AdaptRecastReleaseIssued = Logic.fireSpecialAction(grapple, Enum.UserInputState.End) == true
		Logic.AdaptRecastRequestedAt = now
		Logic.AdaptRecastReleaseAt = now
		Logic.markGrappleBonkGrace(grapple, 0.5)
		return Logic.AdaptRecastReleaseIssued
	end

	if not SecondaryCast.prepareDriveTarget(grapple, nil) then
		Logic.LastAssistDebug = {
			Reason = "SecondaryNoDriveTarget",
			Score = math.huge,
			Target = "None",
		}
		Logic.AdaptDriveActive = false
		Logic.AdaptDriveActiveUntil = 0
		Logic.AdaptRetryAt = now + CFG.ADAPT_RETRY_DELAY
		return false
	end

	return Logic.pulseSpecialAction(grapple)
end

function SecondaryCast.beginAdaptDrive(grapple)
	Logic.AdaptDriveActive = true
	Logic.LastAdaptInputPressed = time()

	if grapple then
		return SecondaryCast.requestAdaptRecast(grapple)
	end

	return false
end

function SecondaryCast.applyGentleRecastAlignment(grapple, dt)
	local rootPart = grapple and grapple.RootPart
	if not rootPart then
		return false
	end

	local movement = grapple and grapple.Movement
	local inputDirection = Logic.getAssistFlatUnit(movement and movement.PlayerMoveDirection)
	local velocityDirection = Logic.getAssistFlatUnit(rootPart.Velocity)
	if inputDirection and velocityDirection and inputDirection:Dot(velocityDirection) >= CFG.INTENT_CONTROL_SUPPRESS_DOT then
		return false
	end

	local targetPosition = Logic.getActiveGrappleTargetPosition(grapple)
	local targetDirection = Logic.getAssistFlatUnit(targetPosition and (targetPosition - rootPart.Position))
	if not targetDirection then
		targetDirection = velocityDirection
	end
	if not targetDirection then
		return false
	end

	if targetPosition and (targetPosition - rootPart.Position).Magnitude < CFG.RECAST_ALIGNMENT_MIN_DISTANCE then
		return false
	end

	local currentLook = Logic.getAssistFlatUnit(rootPart.CFrame.LookVector)
	if not currentLook then
		return false
	end

	local alpha = math.clamp((tonumber(dt) or 1 / 60) * 8, 0, CFG.RECAST_ALIGNMENT_MAX_STEP)
	local blended = currentLook:Lerp(targetDirection, alpha)
	if blended.Magnitude <= 0.05 then
		return false
	end

	local position = rootPart.Position
	rootPart.CFrame = CFrame.lookAt(position, position + blended.Unit, Vector3.yAxis)
	return true
end

function SecondaryCast.updateAdaptRecast(grapple)
	if not Logic.AdaptRecastPending then
		return
	end
	if not Logic.isSuiteEnabled() then
		Logic.AdaptRecastPending = false
		Logic.AdaptRecastReleaseIssued = false
		return
	end

	local movement = grapple and grapple.Movement
	if not (grapple and movement) then
		return
	end

	local now = time()
	local releaseElapsed = now - Logic.AdaptRecastReleaseAt
	local requestElapsed = now - Logic.AdaptRecastRequestedAt
	local detached = movement.grappling ~= true and grapple.jumpPadReel ~= true
	local speed = Logic.getAdaptHorizontalSpeed(grapple)

	if speed > CFG.ADAPT_RECAST_SAFE_SPEED then
		Logic.clampAdaptRecastVelocity(grapple)
		Logic.markGrappleBonkGrace(grapple, 0.3)
		speed = Logic.getAdaptHorizontalSpeed(grapple)
	end

	SecondaryCast.applyGentleRecastAlignment(grapple, 1 / 60)

	if not Logic.AdaptRecastReleaseIssued then
		Logic.AdaptRecastReleaseIssued = Logic.fireSpecialAction(grapple, Enum.UserInputState.End) == true
		Logic.AdaptRecastReleaseAt = now
		return
	end

	if not detached then
		return
	end
	if releaseElapsed < CFG.ADAPT_RECAST_RELEASE_DELAY then
		return
	end
	if speed > CFG.ADAPT_RECAST_SAFE_SPEED and requestElapsed < CFG.ADAPT_RECAST_MAX_WAIT then
		return
	end

	Logic.AdaptRecastPending = false
	Logic.AdaptRecastReleaseIssued = false
	if not SecondaryCast.prepareDriveTarget(grapple, nil) then
		Logic.LastAssistDebug = {
			Reason = "SecondaryNoDriveTarget",
			Score = math.huge,
			Target = "None",
		}
		Logic.AdaptRetryAt = now + CFG.ADAPT_RETRY_DELAY
		return
	end
	Logic.pulseSpecialAction(grapple)
end

function SecondaryCast.maintainAdaptInputHold(grapple)
	if not (Logic.AdaptInputHeld == true and Logic.AdaptDriveActive == true) then
		return
	end
	if not (grapple and Logic.isSuiteEnabled() and Logic.hasClassCapability(grapple, "AimAssist")) then
		return
	end
	if Logic.AdaptRecastPending or SecondaryCast.isAwaitingAdaptAttach(grapple) then
		return
	end

	local now = time()
	local movement = grapple.Movement
	if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
		local heldLongEnough = now - (Logic.AdaptInputBeganAt or 0) >= CFG.ADAPT_TAP_THRESHOLD
		local pulseReady = now - (Logic.LastAdaptPulseAt or 0) >= CFG.ADAPT_RECAST_COOLDOWN
		if heldLongEnough and pulseReady and Logic.hasReachedGrappleDestination(grapple) then
			SecondaryCast.requestAdaptRecast(grapple)
		else
			SecondaryCast.applyGentleRecastAlignment(grapple, 1 / 60)
		end
		return
	end

	if now >= (Logic.AdaptRetryAt or 0) then
		SecondaryCast.requestAdaptRecast(grapple)
	end
end

function SecondaryCast.updateAdaptInputMode(_grapple)
	if not Logic.AdaptInputHeld then
		return
	end
	if time() - (Logic.AdaptInputBeganAt or 0) >= CFG.ADAPT_TAP_THRESHOLD then
		Logic.AdaptDriveActive = true
	end
end

function SecondaryCast.watchAdaptInput()
	if #Logic.InputConnections > 0 then
		return
	end

	table.insert(
		Logic.InputConnections,
		UserInputService.InputBegan:Connect(function(input, _gameProcessed)
			if Logic.isTextBoxFocused() or input.KeyCode ~= Logic.getAdaptInputKeyCode() then
				return
			end

			Logic.AdaptInputHeld = true
			Logic.AdaptInputBeganAt = time()

			if Logic.isSuiteEnabled() then
				local grapple = Logic.getTrackedGrapple()
				if grapple then
					SecondaryCast.beginAdaptDrive(grapple)
				end
			end
		end)
	)

	table.insert(
		Logic.InputConnections,
		UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode ~= Logic.getAdaptInputKeyCode() then
				return
			end

			Logic.AdaptInputHeld = false
			Logic.AdaptInputBeganAt = 0
			if Logic.AdaptPreparedTarget then
				Logic.AdaptDriveActiveUntil = time() + CFG.ADAPT_TAP_DRIVE_GRACE
			else
				Logic.AdaptDriveActive = false
				Logic.AdaptDriveActiveUntil = 0
			end
		end)
	)
end

function SecondaryCast.scanSecondaryCastTarget(grapple, originalResult, allowOriginalFallback)
	local namedDecision = Logic.scanNamedTargets(grapple, {
		driveMode = true,
		fullScan = true,
		forceCursor = false,
		allowOffScreen = true,
		returnDecision = true,
	})

	local surfaceDecision
	if typeof(Logic.scanScreenSurface) == "function" then
		surfaceDecision = Logic.scanScreenSurface(grapple, {
			driveMode = true,
			returnDecision = true,
		})
	end

	if namedDecision and surfaceDecision then
		local namedScore = tonumber(namedDecision.Score) or math.huge
		local surfaceScore = tonumber(surfaceDecision.Score) or math.huge
		if namedScore <= surfaceScore + CFG.ADAPT_DRIVE_SPECIAL_COMMIT_MARGIN then
			return namedDecision.Result
		end
		if surfaceScore + CFG.ADAPT_DRIVE_SURFACE_OVERRIDE_MARGIN < namedScore then
			return surfaceDecision.Result
		end

		return namedDecision.Result
	end

	if namedDecision then
		return namedDecision.Result
	end

	if surfaceDecision then
		return surfaceDecision.Result
	end

	if allowOriginalFallback ~= false and Logic.isUsableResult(grapple, originalResult) then
		return originalResult
	end

	return nil
end

function SecondaryCast.isAdaptInputHeld()
	return Logic.AdaptInputHeld == true
end

function SecondaryCast.getLastAdaptInputPressed()
	return Logic.LastAdaptInputPressed
end

return SecondaryCast
