-- [[
--  NULLSCAPE - BackTrick (TeleFragger) Module
--  Vai trò: Đánh lừa hướng teleport của Telefragger bằng phương pháp Desync Vật lý siêu ngắn (Stealth Desync)
--  Không xoay camera spectator, không xoay hình ảnh trên màn hình Client, chỉ desync 180 độ vật lý trên server trong 60ms.
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

-- Kích hoạt cú đảo hướng BackTrick bằng Stealth Desync (Siêu ngắn, không xoay camera, không xoay visual)
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
	controller.FlickFakeSpectatorEnabled = false -- Không xoay camera spectator
	controller.RedirectRootJoint = rootJoint
	controller.RedirectOriginalC0 = rootJoint.C0

	local isR6 = (rootJoint.Parent == rootPart)
	local startTime = tick()
	local duration = 0.06 -- 60ms (đủ gửi gói tin vật lý desync, cực kỳ khó bị phát hiện)

	-- 1. Lưu CFrame gốc trước khi desync
	local originalCFrame = rootPart.CFrame

	-- 2. Ép xoay HumanoidRootPart vật lý 180 độ để đồng bộ lên Server
	rootPart.CFrame = originalCFrame * CFrame.Angles(0, math.pi, 0)

	-- 3. Bù trừ hình ảnh trên client ngay lập tức để người chơi nhìn thấy nhân vật vẫn di chuyển bình thường
	if isR6 then
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, 0, -math.pi)
	else
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, -math.pi, 0)
	end

	-- 4. Chạy vòng lặp duy trì desync trong 60ms để chống lại sự đè CFrame từ game
	local loopConn
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

		-- Giữ hướng xoay vật lý ngược mặt
		curRoot.CFrame = originalCFrame * CFrame.Angles(0, math.pi, 0)
	end)
end

-- Khôi phục trạng thái khớp xoay về trạng thái gốc trước khi tráo đổi
function BackTrick.revert(controller)
	if controller.WasRedirectingTelefragger then
		controller.WasRedirectingTelefragger = false
		controller.FlickFakeSpectatorEnabled = false
		controller.CurrentFlickAngle = nil

		local char = game.Players.LocalPlayer.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- Xoay thêm 180 độ để quay đầu về hướng cũ (giữ nguyên vị trí mới đã di chuyển)
			rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.pi, 0)
		end

		if controller.RedirectRootJoint and controller.RedirectOriginalC0 then
			pcall(function()
				controller.RedirectRootJoint.C0 = controller.RedirectOriginalC0
			end)
		end
	end
end

return BackTrick
