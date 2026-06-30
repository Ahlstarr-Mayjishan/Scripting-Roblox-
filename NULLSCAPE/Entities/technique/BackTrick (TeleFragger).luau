-- [[
--  NULLSCAPE - BackTrick (TeleFragger) Module
--  Vai trò: Điều khiển hành vi xoay ngược CFrame vật lý và bù trừ trực quan để né tránh Telefragger
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

-- Kích hoạt cú đảo hướng BackTrick vật lý và bù trừ trực quan ở Client
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
	controller.RedirectRootJoint = rootJoint
	controller.RedirectOriginalC0 = rootJoint.C0
	controller.OriginalAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	-- Bù trừ góc xoay 180 độ ở client bằng RootJoint để hình ảnh hiển thị bình thường
	local isR6 = (rootJoint.Parent == rootPart)
	if isR6 then
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, 0, math.pi)
	else
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, math.pi, 0)
	end

	-- Ép CFrame quay ngược liên tục trên mỗi frame thông qua Heartbeat trong suốt 80ms
	local startTime = tick()
	local duration = 0.08
	local loopConn

	loopConn = RunService.Heartbeat:Connect(function()
		local now = tick()
		local curChar = game.Players.LocalPlayer.Character
		local curHumanoid = curChar and curChar:FindFirstChildOfClass("Humanoid")
		local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")

		-- Kiểm tra điều kiện dừng và dọn dẹp
		if now - startTime > duration or not controller.WasRedirectingTelefragger or not (curHumanoid and curRoot and curHumanoid.Health > 0) then
			if loopConn then
				loopConn:Disconnect()
				loopConn = nil
			end
			BackTrick.revert(controller)
			return
		end

		-- Tính toán hướng đối lập trên mỗi frame
		local moveDir = curHumanoid.MoveDirection
		local targetLook = Vector3.zero
		if moveDir.Magnitude > 0.1 then
			targetLook = -moveDir.Unit
		else
			local camera = workspace.CurrentCamera
			if camera then
				local camLook = camera.CFrame.LookVector
				targetLook = -Vector3.new(camLook.X, 0, camLook.Z).Unit
			end
		end

		if targetLook.Magnitude > 0.1 then
			curRoot.CFrame = CFrame.lookAt(curRoot.Position, curRoot.Position + targetLook, Vector3.yAxis)
		end
	end)
end

-- Khôi phục trạng thái khớp xoay và AutoRotate về trạng thái gốc trước khi tráo đổi
function BackTrick.revert(controller)
	if controller.WasRedirectingTelefragger then
		controller.WasRedirectingTelefragger = false
		local char = game.Players.LocalPlayer.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				humanoid.AutoRotate = controller.OriginalAutoRotate
			end)
		end
		if controller.RedirectRootJoint and controller.RedirectRootJoint.Parent then
			pcall(function()
				controller.RedirectRootJoint.C0 = controller.RedirectOriginalC0
			end)
		end
	end
end

return BackTrick
