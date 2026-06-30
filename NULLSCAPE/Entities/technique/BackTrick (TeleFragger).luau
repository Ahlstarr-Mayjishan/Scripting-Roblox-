-- [[
--  NULLSCAPE - BackTrick (TeleFragger) Module
--  Vai trò: Điều khiển hành vi xoay ngược CFrame vật lý, góc camera gửi lên server và bù trừ trực quan để né tránh Telefragger
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

-- Kích hoạt cú đảo hướng BackTrick vật lý, camera spectator mượt mà và bù trừ trực quan ở Client
-- Hỗ trợ chế độ xoay: 
--  - "180" (quay đầu ra sau rồi xoay lại, có xoay camera spectator đi kèm)
--  - "360" (chỉ xoay nhân vật 1 vòng khi ở trên không, camera spectator không bị xoay theo)
function BackTrick.trigger(controller, mode)
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

	-- Lấy chế độ xoay từ đối số truyền vào hoặc thuộc tính cấu hình (mặc định là "180")
	local activeMode = mode or controller.TelefraggerBackTrickMode or "180"

	-- Điều kiện riêng cho 360: Chỉ thực thi khi đang ở trên không (rơi tự do)
	if activeMode == "360" then
		local inAir = (humanoid.FloorMaterial == Enum.Material.Air) or (humanoid:GetState() == Enum.HumanoidStateType.Freefall)
		if not inAir then
			return
		end
	end

	controller.WasRedirectingTelefragger = true
	
	-- 360 độ KHÔNG cần xoay camera theo, chỉ xoay nhân vật (chỉ có 180 mới bật camera hook)
	if activeMode == "180" then
		controller.FlickFakeSpectatorEnabled = true
	else
		controller.FlickFakeSpectatorEnabled = false
	end
	
	controller.RedirectRootJoint = rootJoint
	controller.RedirectOriginalC0 = rootJoint.C0
	controller.OriginalAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	controller.CurrentFlickAngle = 0

	local isR6 = (rootJoint.Parent == rootPart)
	local startTime = tick()
	local loopConn

	if activeMode == "360" then
		-- Cấu hình xoay tròn 360 độ (0.25 giây)
		local duration = 0.25
		loopConn = RunService.Heartbeat:Connect(function()
			local now = tick()
			local elapsed = now - startTime

			local curChar = game.Players.LocalPlayer.Character
			local curHumanoid = curChar and curChar:FindFirstChildOfClass("Humanoid")
			local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")

			if elapsed > duration or not controller.WasRedirectingTelefragger or not (curHumanoid and curRoot and curHumanoid.Health > 0) then
				if loopConn then
					loopConn:Disconnect()
					loopConn = nil
				end
				BackTrick.revert(controller)
				return
			end

			-- Ease In Out Sine cho chuyển động xoay 360 độ rất mượt
			local t = elapsed / duration
			local alpha = (1 - math.cos(t * math.pi)) / 2
			local angle = (math.pi * 2) * alpha

			-- Đảo hướng vật lý trên Server
			local baseLook = getBaseLookDirection(curHumanoid)
			if baseLook.Magnitude > 0.1 then
				local rotatedCFrame = CFrame.lookAt(Vector3.zero, baseLook) * CFrame.Angles(0, angle, 0)
				curRoot.CFrame = CFrame.lookAt(curRoot.Position, curRoot.Position + rotatedCFrame.LookVector, Vector3.yAxis)
			end

			-- Bù trừ góc xoay ở client để hiển thị bình thường
			if isR6 then
				rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, 0, -angle)
			else
				rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, -angle, 0)
			end
		end)
	else
		-- Cấu hình xoay 180 độ (0.3 giây tổng cộng)
		local flickOutTime = 0.1
		local holdTime = 0.1
		local flickInTime = 0.1
		local totalDuration = flickOutTime + holdTime + flickInTime

		loopConn = RunService.Heartbeat:Connect(function()
			local now = tick()
			local elapsed = now - startTime

			local curChar = game.Players.LocalPlayer.Character
			local curHumanoid = curChar and curChar:FindFirstChildOfClass("Humanoid")
			local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")

			if elapsed > totalDuration or not controller.WasRedirectingTelefragger or not (curHumanoid and curRoot and curHumanoid.Health > 0) then
				if loopConn then
					loopConn:Disconnect()
					loopConn = nil
				end
				BackTrick.revert(controller)
				return
			end

			-- Nội suy góc xoay động cho 180 độ
			local angle = 0
			if elapsed < flickOutTime then
				local t = elapsed / flickOutTime
				angle = math.pi * math.sin(t * (math.pi / 2))
			elseif elapsed < (flickOutTime + holdTime) then
				angle = math.pi
			else
				local t = (elapsed - (flickOutTime + holdTime)) / flickInTime
				angle = math.pi * math.sin((1 - t) * (math.pi / 2))
			end

			controller.CurrentFlickAngle = angle

			-- Đảo hướng vật lý trên Server
			local baseLook = getBaseLookDirection(curHumanoid)
			if baseLook.Magnitude > 0.1 then
				local rotatedCFrame = CFrame.lookAt(Vector3.zero, baseLook) * CFrame.Angles(0, angle, 0)
				curRoot.CFrame = CFrame.lookAt(curRoot.Position, curRoot.Position + rotatedCFrame.LookVector, Vector3.yAxis)
			end

			-- Bù trừ góc xoay ở client để hiển thị bình thường
			if isR6 then
				rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, 0, -angle)
			else
				rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, -angle, 0)
			end
		end)
	end
end

-- Khôi phục trạng thái khớp xoay và AutoRotate về trạng thái gốc trước khi tráo đổi
function BackTrick.revert(controller)
	if controller.WasRedirectingTelefragger then
		controller.WasRedirectingTelefragger = false
		controller.FlickFakeSpectatorEnabled = false
		controller.CurrentFlickAngle = nil

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
end

return BackTrick
