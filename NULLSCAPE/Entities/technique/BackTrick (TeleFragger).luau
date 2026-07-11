-- [[
--  NULLSCAPE - BackTrick (TeleFragger) Module (Stealth Edition)
--  Vai trò: Đánh lừa hướng teleport của Telefragger bằng cơ chế Desync Vật lý siêu ngắn (Stealth Desync)
--  Không sử dụng easing/flick chậm, xoay tức thời 180 độ vật lý và bù trừ trực quan trên client ngay lập tức.
--  Giúp qua mặt spectator nhờ bộ lọc nội suy (interpolation) của Roblox client khác, giảm thiểu tối đa việc bị lộ.
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

-- Kích hoạt cú đảo hướng BackTrick bằng Stealth Desync (Xoay vật lý tức thời, bù trừ client lập tức)
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

	-- Bù trừ góc xoay 180 độ ở client bằng RootJoint để hình ảnh hiển thị bình thường ngay lập tức
	local isR6 = (rootJoint.Parent == rootPart)
	if isR6 then
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, 0, math.pi)
	else
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, math.pi, 0)
	end

	-- Tính toán hướng đối lập dựa trên hướng nhìn cơ sở
	local baseLook = getBaseLookDirection(humanoid)
	local targetLook = -baseLook

	-- Thực hiện quay vật lý tức thời 180 độ
	if targetLook.Magnitude > 0.1 then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + targetLook, Vector3.yAxis)
	end

	-- Chạy vòng lặp duy trì hướng quay ngược trên server chống game đè CFrame cho tới khi revert được gọi
	controller.BackTrickConnection = RunService.Heartbeat:Connect(function()
		local curChar = game.Players.LocalPlayer.Character
		local curHumanoid = curChar and curChar:FindFirstChildOfClass("Humanoid")
		local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")

		if not controller.WasRedirectingTelefragger or not (curHumanoid and curRoot and curHumanoid.Health > 0) then
			BackTrick.revert(controller)
			return
		end

		if targetLook.Magnitude > 0.1 then
			curRoot.CFrame = CFrame.lookAt(curRoot.Position, curRoot.Position + targetLook, Vector3.yAxis)
		end
	end)
end

-- Khôi phục trạng thái khớp xoay về trạng thái gốc
function BackTrick.revert(controller)
	BackTrick.cleanup(controller)
end

-- Dọn dẹp thực sự khi hoàn tất cả quá trình
function BackTrick.cleanup(controller)
	if not controller then
		return
	end

	if controller.BackTrickConnection then
		pcall(function()
			controller.BackTrickConnection:Disconnect()
		end)
		controller.BackTrickConnection = nil
	end

	local char = game.Players.LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			if controller.OriginalAutoRotate ~= nil then
				humanoid.AutoRotate = controller.OriginalAutoRotate
			else
				humanoid.AutoRotate = true
			end
		end)
	end

	if controller.RedirectRootJoint and controller.RedirectOriginalC0 then
		pcall(function()
			controller.RedirectRootJoint.C0 = controller.RedirectOriginalC0
		end)
	end

	controller.WasRedirectingTelefragger = false
	controller.FlickFakeSpectatorEnabled = false
	controller.CurrentFlickAngle = nil
	controller.BackTrickState = nil
	controller.FlickInStartTime = nil
	controller.OriginalAutoRotate = nil
	controller.RedirectRootJoint = nil
	controller.RedirectOriginalC0 = nil
end

return BackTrick

