--!nocheck
-- [[
--  NULLSCAPE - Secondary Cast Skill (Adapt Drive / phím T) Module
-- ]]

local UserInputService = game:GetService("UserInputService")

local SecondaryCast = {}
local Logic
local CFG

function SecondaryCast.link(logicInstance)
	Logic = logicInstance
	CFG = Logic.CFG
	
	-- Khởi tạo các biến trên Logic nếu chưa tồn tại
	Logic.AdaptDriveActive = Logic.AdaptDriveActive or false
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
	Logic.InputConnections = Logic.InputConnections or {}
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
		if not Logic.hasReachedGrappleDestination(grapple) then
			return false
		end
		Logic.AdaptRecastPending = true
		Logic.AdaptRecastReleaseIssued = Logic.fireSpecialAction(grapple, Enum.UserInputState.End) == true
		Logic.AdaptRecastRequestedAt = now
		Logic.AdaptRecastReleaseAt = now
		Logic.markGrappleBonkGrace(grapple, 0.5)
		return Logic.AdaptRecastReleaseIssued
	end

	return Logic.pulseSpecialAction(grapple)
end

function SecondaryCast.beginAdaptDrive(grapple)
	if Logic.AdaptDriveActive then
		return false
	end

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
	if
		inputDirection
		and velocityDirection
		and inputDirection:Dot(velocityDirection) >= CFG.INTENT_CONTROL_SUPPRESS_DOT
	then
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
	if not (Logic.AdaptInputHeld and Logic.isSuiteEnabled()) then
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
	Logic.pulseSpecialAction(grapple)
end

function SecondaryCast.maintainAdaptInputHold(grapple)
	local movement = grapple and grapple.Movement
	local rootPart = grapple and grapple.RootPart
	if
		movement
		and rootPart
		and Logic.AdaptDriveActive
		and Logic.AdaptInputHeld
		and not (movement.grappling == true or grapple.jumpPadReel == true)
	then
		if Logic.AdaptRecastPending then
			return
		end
		if SecondaryCast.isAwaitingAdaptAttach(grapple) then
			return
		end
		if time() < (Logic.AdaptRetryAt or 0) then
			return
		end
		if time() - Logic.LastAdaptPulseAt < CFG.ADAPT_RECAST_COOLDOWN then
			return
		end

		local allowed = Logic.canRunAssist("AimAssist", grapple)
		if allowed then
			local now = time()
			Logic.LastAdaptPulseAt = now
			SecondaryCast.requestAdaptRecast(grapple)
		end
		if not Logic.hasAdaptDriveTarget(grapple) then
			Logic.AdaptRetryAt = time() + CFG.ADAPT_RETRY_DELAY
		end
	end
end

function SecondaryCast.updateAdaptInputMode(grapple)
	if not (Logic.AdaptInputHeld and Logic.isSuiteEnabled()) then
		return
	end
	if Logic.AdaptDriveActive then
		return
	end
	if time() - (Logic.AdaptInputBeganAt or 0) < CFG.ADAPT_TAP_THRESHOLD then
		return
	end

	SecondaryCast.beginAdaptDrive(grapple)
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
			Logic.AdaptDriveActive = false
			Logic.AdaptRecastPending = false
			Logic.AdaptRecastReleaseIssued = false
			Logic.AdaptAwaitingAttachUntil = 0
			Logic.AdaptRetryAt = 0
		end)
	)
end

function SecondaryCast.scanSecondaryCastTarget(grapple, originalResult)
	-- 1. Ưu tiên quét toàn bộ phạm vi Camera nhìn thấy (cursorLimit = 2.0)
	local mouseTarget = Logic.scanNamedTargets(grapple, {
		fullScan = true,
		forceCursor = true,
		cursorLimit = 2.0,
		rangeMode = "Closest To Cursor"
	})
	if mouseTarget then
		return mouseTarget
	end

	-- 2. Nếu người dùng đang nhắm vào một vị trí cụ thể trên bản đồ (như tường, sàn, trần nhà - originalResult hợp lệ)
	-- thì tôn trọng hướng nhắm cụ thể của họ
	if Logic.isUsableResult(grapple, originalResult) then
		return originalResult
	end

	-- 3. Chỉ khi chuột trỏ vào không khí thì mới tự động quét điểm bám tối ưu theo hệ thống
	return Logic.scanNamedTargets(grapple, {
		driveMode = true,
		fullScan = true,
		forceCursor = false
	})
end

function SecondaryCast.isAdaptInputHeld()
	return Logic.AdaptInputHeld == true
end

function SecondaryCast.getLastAdaptInputPressed()
	return Logic.LastAdaptInputPressed
end

return SecondaryCast
