-- [[
--  NULLSCAPE - BackTrick (TeleFragger) Module (Stealth Edition)
--  Applies a short physical facing desync with local joint compensation.
-- ]]

local BackTrick = {}

local RunService = game:GetService("RunService")

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

	if controller.WasRedirectingTelefragger then
		return
	end

	controller.WasRedirectingTelefragger = true
	controller.RedirectRootJoint = rootJoint
	controller.RedirectOriginalC0 = rootJoint.C0
	controller.OriginalAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local isR6 = (rootJoint.Parent == rootPart)
	if isR6 then
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, 0, math.pi)
	else
		rootJoint.C0 = controller.RedirectOriginalC0 * CFrame.Angles(0, math.pi, 0)
	end

	local baseLook = getBaseLookDirection(humanoid)
	local targetLook = -baseLook

	if targetLook.Magnitude > 0.1 then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + targetLook, Vector3.yAxis)
	end

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

function BackTrick.revert(controller)
	BackTrick.cleanup(controller)
end

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
