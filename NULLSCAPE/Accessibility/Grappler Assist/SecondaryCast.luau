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
	Logic.pulseSpecialAction(grapple)
end

function SecondaryCast.maintainAdaptInputHold(grapple)
	-- Vô hiệu hóa việc tự động giữ/lặp recast để tôn trọng quy tắc "1 bấm 1 lần phóng neo"
	return
end

function SecondaryCast.updateAdaptInputMode(grapple)
	-- Vô hiệu hóa việc tự động phân biệt tap/hold
	return
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
		end)
	)
end

function SecondaryCast.scanSecondaryCastTarget(grapple, originalResult)
	-- 1. Siêu blatant: Ưu tiên tối đa tự động tìm và snap 100% vào điểm neo đặc biệt (Bells, JumpPads...) trong 360 độ (kể cả sau lưng/ngoài màn hình)
	local blatantTarget = Logic.scanNamedTargets(grapple, {
		driveMode = true,
		fullScan = true,
		forceCursor = false,
		allowOffScreen = true
	})
	if blatantTarget then
		return blatantTarget
	end

	-- 2. Dự phòng 1: Nếu không có điểm đặc biệt nào xung quanh, tôn trọng hướng nhắm cụ thể của người chơi (vào tường, sàn, trần...)
	if Logic.isUsableResult(grapple, originalResult) then
		return originalResult
	end

	-- 3. Dự phòng 2: Nếu chỉ chuột vào khoảng không và không có điểm đặc biệt, tự quét bề mặt địa hình thường trên màn hình
	if typeof(Logic.scanScreenSurface) == "function" then
		return Logic.scanScreenSurface(grapple, {
			driveMode = true,
			returnDecision = true
		})
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
