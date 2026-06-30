-- [[
--  NULLSCAPE - BackTrick (TeleFragger) Module
--  Vai trò: Đánh lừa hướng teleport của Telefragger bằng cơ chế Flick nhanh phản xạ (Reflex Flick) ở cuối SetTeleport
--  Gồm 3 giai đoạn: Flick ra sau (60ms) -> Giữ nguyên (chờ Server chốt vị trí) -> Flick trở lại trước (60ms) khi nhận Indicator.
-- ]]

local BackTrick = {}

local RunService = game:GetService("RunService")

-- Helper: Lấy khớp nối xoay nhân vật (RootJoint Motor6D) cho R6/R15
local function getRootJoint(char)
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end
	local r6Joint = rootPart:FindFirstChild("RootJoint")
	if r6Joint and r6Joint:IsA("Motor6D") then
		return r6Joint
	end
	local lowerTorso = char:FindFirstChild("LowerTorso")
	if lowerTorso then
		local r15Joint = lowerTorso:FindFirstChild("RootJoint")
		if r15Joint and r15Joint:IsA("Motor6D") then
			return r15Joint
		end
	end
	return nil
end

-- Helper: Tính hướng nhìn cơ sở dựa theo di chuyển hoặc hướng camera của Client
local function getBaseLookDirection(humanoid)
	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude > 0.1 then
		return moveDir.Unit
	else
		local camera = workspace.CurrentCamera
		if camera then
			local camLook = camera.CFrame.LookVector
			return Vector3.new(camLook.X, 0, camLook.Z).Unit
		end
	end
	return Vector3.zero
end

-- Kích hoạt cú đảo hướng BackTrick bằng Reflex Flick (Flick phản xạ ở cuối, có giả lập xoay camera spectator)
function BackTrick.trigger(controller)
	if not controller.TelefraggerBackTrick then
		return
	end

	local char = game.Players.LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	if not (humanoid and rootPart and humanoid.Health > 0) then
		return
	end

	local rootJoint = getRootJoint(char)
	if not rootJoint then
		return
	end

	-- Tránh kích hoạt chồng chéo nếu đang chạy
	if controller.WasRedirectingTelefragger then
		return
	end

	controller.WasRedirectingTelefragger = true
	controller.FlickFakeSpectatorEnabled = true -- Bật giả lập xoay camera spectator
	controller.RedirectRootJoint = rootJoint
	controller.RedirectOriginalC0 = rootJoint.C0
	controller.OriginalAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	controller.CurrentFlickAngle = 0
	controller.BackTrickState = "FlickingOut"

	local flickOutTime = 0.06 -- 60ms để xoay ra sau
	local flickInTime = 0.06  -- 60ms để xoay trở lại trước
	local isR6 = (rootJoint.Parent == rootPart)
	local startTime = tick()

	-- Lưu hướng nhìn cơ sở tại thời điểm bắt đầu flick để chuyển động xoay được cố định và mượt mà
	local baseLook = getBaseLookDirection(humanoid)

	controller.BackTrickConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		local curChar = game.Players.LocalPlayer.Character
		local curHumanoid = curChar and curChar:FindFirstChildOfClass("Humanoid")
		local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")

		if not (curHumanoid and curRoot and curHumanoid.Health > 0) then
			BackTrick.cleanup(controller)
			return
		end

		local state = controller.BackTrickState
		local angle = 0

		if state == "FlickingOut" then
			local elapsed = now - startTime
			if elapsed >= flickOutTime then
				controller.BackTrickState = "Holding"
				angle = math.pi
			else
				local t = elapsed / flickOutTime
				angle = math.pi * math.sin(t * (math.pi / 2)) -- Ease Out Sine
			end
		elseif state == "Holding" then
			angle = math.pi
		elseif state == "FlickingIn" then
			local elapsed = now - controller.FlickInStartTime
			if elapsed >= flickInTime then
				BackTrick.cleanup(controller)
				return
			else
				local t = elapsed / flickInTime
				angle = math.pi * math.sin((1 - t) * (math.pi / 2)) -- Ease In Sine
			end
		end

		controller.CurrentFlickAngle = angle

		-- 1. Đảo hướng vật lý trên Server
		if baseLook.Magnitude > 0.1 then
			local rotatedCFrame = CFrame.lookAt(Vector3.zero, baseLook) * CFrame.Angles(0, angle, 0)
			curRoot.CFrame = CFrame.lookAt(curRoot.Position, curRoot.Position + rotatedCFrame.LookVector, Vector3.yAxis)
		end

		-- 2. Bù trừ góc xoay ở client để hiển thị bình thường
		if isR6 then
			rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, 0, -angle)
		else
			rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, -angle, 0)
		end
	end)
end

-- Khởi đầu tiến trình flick trở lại trước khi nhận tín hiệu Indicator hoặc kết thúc
function BackTrick.revert(controller)
	if controller.WasRedirectingTelefragger and controller.BackTrickState ~= "FlickingIn" then
		controller.FlickInStartTime = tick()
		controller.BackTrickState = "FlickingIn"
	end
end

-- Dọn dẹp thực sự khi hoàn tất cả quá trình
function BackTrick.cleanup(controller)
	if controller.BackTrickConnection then
		controller.BackTrickConnection:Disconnect()
		controller.BackTrickConnection = nil
	end

	controller.WasRedirectingTelefragger = false
	controller.FlickFakeSpectatorEnabled = false
	controller.CurrentFlickAngle = nil
	controller.BackTrickState = nil
	controller.FlickInStartTime = nil

	local char = game.Players.LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.AutoRotate = controller.OriginalAutoRotate
		end)
	end
	if controller.RedirectRootJoint and controller.RedirectOriginalC0 then
		pcall(function()
			controller.RedirectRootJoint.C0 = controller.RedirectOriginalC0
		end)
	end
end

return BackTrick
