-- Script Path: game:GetService("ReplicatedStorage").Movement.Specials.Grapple
-- Took 1.02s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}

t.__index = t

local v1 = script.Parent.Parent
local Events = v1.Events
local ReplicatedStorage = game.ReplicatedStorage
local v2 = workspace:GetAttribute("Null")
local MobileHandler = require(ReplicatedStorage.Mobile.MobileHandler)
local v3, v4

if v2 then
	v3 = 4.5
	v4 = 50
else
	v3 = (1 / 0)
	v4 = 1
end

function t.new(p1, p2) --[[ new | Line: 44 | Upvalues: t (copy) ]]
	local t2 = {
		Movement = p1,
		Animator = p2,
		UI = nil,
		SFX = p1.SFX,
		Status = p1.Status,
		Character = p1.Character,
		RootPart = p1.RootPart,
		Humanoid = p1.Humanoid,
		specialHeld = false,
		cameraOffset = CFrame.new(),
		grapplerCrosshair = nil,
		grappleCancelled = false,
		reelStart = -100,
		memoryUpdate = -1000,
		memoryPosition = Vector3.new(0, 0, 0),
		macro = false,
		macroChecks = 0,
		lastKeyPress = time(),
		grapplePart = nil,
		grappleOffset = nil,
		jumpPadReel = false,
		grappleReel = false,
		reelCooldown = false,
		rope = nil,
		ropeAttachment = nil,
		hook = nil,
		hookAttachment = nil,
		Charges = 3,
		Time = 5,
		TimeClamp = 5,
		usedGrappleTime = 10,
		TimeDrained = false,
		JumpPadCombo = 0,
		giftsCollected = 0,
		grappleDestroyedConnection = nil,
		collectedConnection = nil,
		allowSharkTail = false,
		sharkTailDisable = false,
		yVelBelowMin = false,
		lastGrappleRelease = -1000,
		lastReelStart = -1,
		grappleParams = RaycastParams.new(),
	}

	t2.grappleParams.FilterDescendantsInstances = p1.moveCastParams.FilterDescendantsInstances
	t2.grappleParams.RespectCanCollide = false
	t2.grappleParams.CollisionGroup = "Grappler"
	t2.grappleParams.FilterType = Enum.RaycastFilterType.Exclude
	t2.barOutlineGradient = nil

	return setmetatable(t2, t)
end
function t.Cast(p1, p2) --[[ Cast | Line: 108 ]]
	p1.grappleParams.FilterDescendantsInstances = p1.Movement.moveCastParams.FilterDescendantsInstances

	if not (time() - p1.memoryUpdate > 0.25 or p2) then
		local Position = p1.RootPart.Position

		return workspace:Raycast(Position, CFrame.lookAt(Position, p1.memoryPosition).LookVector * 90, p1.grappleParams)
	end

	local v3

	if
		if game.UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			then true
			elseif p1.Movement.preferredInput == Enum.PreferredInput.KeyboardAndMouse then false
			else true
	then
		local CurrentCamera = workspace.CurrentCamera
		local _ = Vector3.new(0, 0, 0)
			+ CurrentCamera.CFrame.RightVector * p1.cameraOffset.X
			+ CurrentCamera.CFrame.UpVector * p1.cameraOffset.Y
		local v6 = workspace:Raycast(
			(CurrentCamera.CFrame * p1.cameraOffset).Position
				+ CurrentCamera.CFrame.LookVector
					* (CurrentCamera.CFrame.Position - (p1.RootPart.Position + p1.Humanoid.CameraOffset)).magnitude,
			CurrentCamera.CFrame.LookVector * 90,
			p1.grappleParams
		)

		if v6 == nil then
			return
		end

		v3 = v6.Position
	else
		local UnitRay = game.Players.LocalPlayer:GetMouse().UnitRay
		local v7 = workspace:Raycast(UnitRay.Origin, UnitRay.Direction.Unit * 2048, p1.grappleParams)

		if v7 == nil then
			return nil, UnitRay.Direction.Unit
		end

		v3 = v7.Position
	end

	local Position = p1.RootPart.Position

	return workspace:Raycast(Position, CFrame.lookAt(Position, v3).LookVector * 90, p1.grappleParams)
end
function t.Initialise(p1) --[[ Initialise | Line: 161 | Upvalues: ReplicatedStorage (copy), v1 (copy), MobileHandler (copy), v2 (copy) ]]
	p1.grapplerCrosshair = ReplicatedStorage.Movement.Instances.GrapplerCrosshair:Clone()
	p1.grapplerCrosshair.Parent = workspace
	p1.ropeAttachment = Instance.new("Attachment")
	p1.ropeAttachment.Name = "GrappleRopeAttachment"
	p1.ropeAttachment.Parent = workspace.Terrain
	p1.rope = Instance.new("RopeConstraint")
	p1.rope.Enabled = false
	p1.rope.Attachment0 = p1.ropeAttachment
	p1.rope.Attachment1 = p1.RootPart:WaitForChild("RootAttachment", 5)
	p1.rope.Parent = p1.RootPart
	p1.collectedConnection = v1.Events.CollectedGift.Event:Connect(function() --[[ Line: 175 | Upvalues: p1 (copy) ]]
		p1:OnGiftCollected()
	end)

	if p1.rope.Attachment1 == nil then
		if not p1.grapplerCrosshair then
			return
		end

		p1.grapplerCrosshair:Destroy()
		p1.grapplerCrosshair = nil
	else
		MobileHandler.SetButtonVisibility("SpecialAlt", p1.Movement:HasUpgrade("NinjaBelt"))
		p1.UI = v1.Instances.BarUI:Clone()
		p1.UI.Parent = game.Players.LocalPlayer.PlayerGui
		p1.UI.Frame.Visible = true
		p1.UI.Frame.Under.Visible = v2
		p1.barOutlineGradient = Instance.new("UIGradient")
		p1.barOutlineGradient.Parent = p1.UI.Frame.Outline.UIStroke
		p1.usedGrappleTime = 10
		p1.hookAttachment = Instance.new("Attachment")
		p1.hookAttachment.Parent = p1.Character:WaitForChild("Right Arm")
		p1.hookAttachment.Position = Vector3.new(0, -1, 0)
		p1.hook = ReplicatedStorage.Movement.Instances.GrappleHook:Clone()
		p1.hook.Beam.Attachment0 = p1.hookAttachment
		p1.grapplerCrosshair.Parent = nil
		v1.Events.GrappleReplicator.OnClientEvent:Connect(function(p12) --[[ Line: 228 | Upvalues: p1 (copy) ]]
			p1:OnClientEvent(p12)
		end)

		if v2 then
			if p1.Movement:HasUpgrade("TheOrb") then
				p1.usedGrappleTime = p1.usedGrappleTime + 2
			end

			game.ReplicatedStorage.UpgradeFolder.Upgrades.ChildAdded:Connect(
				function(p12) --[[ Line: 238 | Upvalues: p1 (copy) ]]
					if p1.Humanoid:GetState() == Enum.HumanoidStateType.Running then
						p1.usedGrappleTime = 11.5
					end

					if p1.Humanoid:GetState() ~= Enum.HumanoidStateType.Landed then
						return
					end

					p1.usedGrappleTime = 11.5
				end
			)

			if p1.Humanoid:GetState() == Enum.HumanoidStateType.Running then
				p1.usedGrappleTime = 11.5
			end

			if p1.Humanoid:GetState() == Enum.HumanoidStateType.Landed then
				p1.usedGrappleTime = 11.5
			end
		end

		p1.Time = p1.usedGrappleTime
		p1.TimeClamp = p1.usedGrappleTime

		if not v2 then
			return
		end

		ReplicatedStorage.Events.MovementGiftMagnet:Fire({
			Reset = "heeelp",
		})
	end
end
function t.OnClientEvent(p1, p2) --[[ OnClientEvent | Line: 277 ]]
	if not p2 then
		return
	end

	p2:Destroy()
end
function t.UpgradeChanged(p1, p2, p3) --[[ UpgradeChanged | Line: 283 | Upvalues: MobileHandler (copy) ]]
	if p2 ~= "NinjaBelt" then
		return
	end

	MobileHandler.SetButtonVisibility("SpecialAlt", p3 > 0)
end
function t.SharkTail(p1) --[[ SharkTail | Line: 289 ]]
	p1.allowSharkTail = false
	p1.sharkTailDisable = true
	p1.UI.Frame.Bar.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
	p1.UI.Frame.Outline.UIStroke.Color = p1.UI.Frame.Bar.BackgroundColor3

	local Velocity = p1.RootPart.Velocity

	p1.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	p1.RootPart.Velocity =
		Vector3.new(Velocity.X * 0.3, (Velocity * Vector3.new(1, 0, 1)).Magnitude ^ 0.95 * 1.3, Velocity.Z * 0.3)
end
function t.Reset(p1) --[[ Reset | Line: 306 | Upvalues: v2 (copy), ReplicatedStorage (copy), MobileHandler (copy), Events (copy) ]]
	if p1.grappleDestroyedConnection then
		p1.grappleDestroyedConnection:Disconnect()
	end

	if p1.collectedConnection then
		p1.collectedConnection:Disconnect()
	end

	if v2 then
		ReplicatedStorage.Events.MovementGiftMagnet:Fire({
			Reset = "Bonk puzzle",
		})
	end

	MobileHandler.SetButtonVisibility("SpecialAlt", false)
	p1.usedGrappleTime = 10
	p1.Animator.specialOffset = Vector3.new(0, 0, 0)
	p1.jumpPadReel = false
	p1.grappleReel = false
	p1.reelCooldown = false
	p1.Humanoid.PlatformStand = false
	p1.Movement.grappling = false
	p1.Movement.grapplePoint = nil
	p1.Movement.grapplePart = nil
	p1.Movement.grappleSpeed = 0
	p1.Movement.grappleJumpCancel = false
	p1.Movement.faceGrapplePoint = false
	p1.Animator:StopAnimation("GrappleStart")
	p1.Animator:StopAnimation("GrappleThrow")
	p1.Animator:StopAnimation("GrappleLoop")

	if p1.grapplerCrosshair then
		p1.grapplerCrosshair:Destroy()
		p1.grapplerCrosshair = nil
	end

	if p1.ropeAttachment then
		p1.ropeAttachment:Destroy()
		p1.ropeAttachment = nil
	end

	if p1.rope then
		p1.rope:Destroy()
		p1.rope = nil
	end

	if p1.hook then
		p1.hook:Destroy()
		p1.hook = nil
	end

	if p1.hookAttachment then
		p1.hookAttachment:Destroy()
		p1.hookAttachment = nil
	end

	if not p1.UI then
		Events.GrappleReplicator:FireServer("DestroyHook")

		return
	end

	p1.UI:Destroy()
	p1.UI = nil
	p1.barOutlineGradient = nil
	Events.GrappleReplicator:FireServer("DestroyHook")
end
function t.OnGiftCollected(p1) --[[ OnGiftCollected | Line: 373 ]]
	p1.Time = math.clamp(p1.Time + 0.5, 0, p1.TimeClamp)
end
function t.OnRootAnchored(p1) --[[ OnRootAnchored | Line: 377 ]]
	p1.Time = p1.TimeClamp
end
function t.End(p1, p2) --[[ End | Line: 400 | Upvalues: v2 (copy), ReplicatedStorage (copy), Events (copy) ]]
	if p1.grappleDestroyedConnection then
		p1.grappleDestroyedConnection:Disconnect()
	end

	if v2 then
		task.delay(
			if p1.Movement:HasUpgrade("MiniatureHourglass") then 0.25 else 0.5,
			function() --[[ Line: 411 | Upvalues: p1 (copy), ReplicatedStorage (ref) ]]
				if not p1.Movement.grappling then
					ReplicatedStorage.Events.MovementGiftMagnet:Fire({
						Reset = "Solve my puzzle",
					})
				end
			end
		)
	end

	if p1.grappleReel then
		p1.reelCooldown = true

		local v22 = 3

		if p1.Movement:HasUpgrade("SharkTail") then
			v22 = v22 * 0.75
		end

		if p1.Movement:HasUpgrade("SharkTail") and not p1.sharkTailDisable then
			p1.allowSharkTail = true
			p1.UI.Frame.Bar.BackgroundColor3 = Color3.fromRGB(255, 255, 130)
			task.delay(0.25, function() --[[ Line: 428 | Upvalues: p1 (copy) ]]
				if p1.allowSharkTail then
					p1.allowSharkTail = false
					p1.UI.Frame.Bar.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
					p1.UI.Frame.Outline.UIStroke.Color = p1.UI.Frame.Bar.BackgroundColor3
				end
			end)
		else
			p1.UI.Frame.Bar.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
		end

		p1.UI.Frame.Outline.UIStroke.Color = p1.UI.Frame.Bar.BackgroundColor3
		task.delay(v22, function() --[[ Line: 440 | Upvalues: p1 (copy) ]]
			if not p1.UI then
				return
			end

			p1.reelCooldown = false

			if not p1.sharkTailDisable then
				p1.UI.Frame.Bar.BackgroundColor3 = Color3.new(255 / 255, 255 / 255, 255 / 255)
				p1.UI.Frame.Outline.UIStroke.Color = p1.UI.Frame.Bar.BackgroundColor3
			end
		end)
	end

	p1.jumpPadReel = false
	p1.grappleReel = false
	p1.SFX:StopSound("GrapplerReel")
	p1.grapplePart = nil
	p1.grappleOffset = nil
	p1.Movement.grappling = false
	p1.grappleCancelled = p2 ~= false

	if p2 then
		p1.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
	else
		p1.lastGrappleRelease = time()
	end

	if p1.hook and p1.hook.Parent then
		p1.hook.Timer:Stop()
		p1.rope.Enabled = false
		p1.hook.Anchored = true

		if p1.hook:FindFirstChildOfClass("Weld") then
			p1.hook:FindFirstChildOfClass("Weld"):Destroy()
		end

		p1.hook.Transparency = 1
		p1.hook.Beam.Enabled = false
	end

	Events.GrappleReplicator:FireServer("DestroyHook")
	p1.Movement.grappleJumpCancel = true
	p1.Movement.grappleSpeed = (p1.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude
		/ (2.5 + p1.Movement.grappleSpeed / 40)
	p1.Animator:StopAnimation("GrappleStart")
	p1.Animator:StopAnimation("GrappleThrow")
	p1.Animator:StopAnimation("GrappleLoop")

	local Y = p1.RootPart.Velocity.Y

	p1.Humanoid.PlatformStand = false

	if Y > 15 and p1.yVelBelowMin then
		p1.Movement.grappleJumping = true
		p1.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

		local v5 = 1 - math.clamp(Y / 300, 0.2, 1)
		local RootPart = p1.RootPart

		RootPart.Velocity = RootPart.Velocity + Vector3.new(0, 1, 0) * Y / 2 * v5
		p1.Movement.jumpPadAirControl = true
		p1.Movement:FlipFlop()
	else
		p1.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	local Unit = (p1.RootPart.Velocity * Vector3.new(1, 0, 1)).Unit

	if Unit ~= Unit then
		Unit = Vector3.new(0, 0, 0)
	end

	p1.Movement:SetMoveDirection(Unit)

	if p1.RootPart.Velocity.Magnitude < 20 then
		p1.SFX:PlaySound("GrapplerRelease1")
	elseif p1.RootPart.Velocity.Magnitude < 40 then
		p1.SFX:PlaySound("GrapplerRelease2")
	else
		p1.SFX:PlaySound("GrapplerRelease3")
	end

	p1.yVelBelowMin = false
	p1.Movement.grapplePoint = nil
	p1.Humanoid:SetAttribute("UsingAbility", false)
end
function t.Start(p1, p2) --[[ Start | Line: 536 | Upvalues: Events (copy), v2 (copy) ]]
	if p1.Humanoid:GetState() == Enum.HumanoidStateType.Running and p2.Instance.Name ~= "JumpPad" then
		return
	end

	if p1.Charges == 0 then
		return
	end

	local isName = p2.Instance.Name == "JumpPad"

	if p2.Instance.Name == "JumpPad" then
		if p2.Instance:GetAttribute("Uses") then
			p2.Instance:SetAttribute("Uses", 2)
			p2.Instance.CanQuery = false
			p2.Instance.Color = Color3.fromRGB(152, 24, 24)

			for v1, v22 in p2.Instance:GetChildren() do
				if v22:IsA("Texture") then
					v22.Color3 = Color3.fromRGB(255, 255, 255)
					v22:SetAttribute("Speed", 0.2)
				end
			end
		else
			p2.Instance:SetAttribute("Uses", 1)
			p2.Instance.Color = Color3.fromRGB(255, 44, 206)

			for v3, v4 in p2.Instance:GetChildren() do
				if v4:IsA("Texture") then
					v4.Color3 = Color3.fromRGB(191, 0, 255)
					v4:SetAttribute("Speed", 2)
				end
			end
		end
	end

	p1.Humanoid.PlatformStand = true
	p1.reelStart = time()
	p1.grapplePart = p2.Instance
	p1.grappleOffset = p2.Instance.CFrame:ToObjectSpace(CFrame.new(p2.Position))
	p1.ropeAttachment.WorldPosition = (p1.grapplePart.CFrame * p1.grappleOffset).Position
	p1.rope.Length = p2.Distance
	p1.rope.Enabled = true
	p1.hook.Timer.SoundGroup = game.SoundService.Master.SFX
	p1.hook.Timer:Play()
	p1.Movement.usedGrappleInAir = true
	p1.hook.Parent = workspace
	p1.hook.Transparency = 0
	p1.hook.Beam.Enabled = true
	p1.hook.Anchored = true
	p1.hook.CFrame = CFrame.lookAt(p1.hookAttachment.WorldPosition, p2.Position)
		* CFrame.Angles(-1.5707963267948966, 0, 0)
	p1.yVelBelowMin = false
	p1.hook.Beam.CurveSize0 = 5
	p1.hook.Beam.CurveSize1 = 5
	Events.GrappleReplicator:FireServer("CreateHook", {
		HookCFrame = CFrame.lookAlong(p2.Position, p1.hook.CFrame.LookVector),
	})

	local v5 = p2.Instance.Name

	if
		if v5 == "JumpPad" or (v5 == "GrapplePoint" or v5 == "Bell")
			then true
			elseif v5 == "TriaOrb" then true
			else false
	then
		p1.jumpPadReel = true
		p1.SFX:PlaySound("GrapplerReel")
		p1.Movement.faceGrapplePoint = false
	else
		p1.Movement.faceGrapplePoint = true
		p1.jumpPadReel = false
		p1.Animator:PlayAnimation("GrappleThrow")
	end

	p1.grappleReel = false
	p1.Animator:StopAnimation("GrappleStart")
	p1.Animator:PlayAnimation("GrappleLoop")
	p1.SFX:PlaySound("GrapplerThrow")
	p1.Animator:TimeAnimation("GrappleLoop", 0.5)
	p1.Animator:SpeedAnimation("GrappleLoop", 0)

	local Magnitude = (p1.RootPart.Position - p2.Position).Magnitude
	local v8 = game.TweenService:Create(p1.hook, TweenInfo.new(Magnitude / 90 * 0.2, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAlong(p2.Position - p1.hook.CFrame.UpVector, p1.hook.CFrame.LookVector),
	})
	local v9 = game.TweenService:Create(p1.hook.Beam, TweenInfo.new(1, Enum.EasingStyle.Elastic), {
		CurveSize0 = 0,
	})
	local v10 = game.TweenService:Create(p1.hook.Beam, TweenInfo.new(1, Enum.EasingStyle.Elastic), {
		CurveSize1 = 0,
	})
	local v11 = math.random(1, 2)

	v8:Play()

	if v11 == 1 then
		v9:Play()
		task.delay(0.1, function() --[[ Line: 658 | Upvalues: v10 (copy) ]]
			v10:Play()
		end)
	else
		v10:Play()
		task.delay(0.1, function() --[[ Line: 663 | Upvalues: v9 (copy) ]]
			v9:Play()
		end)
	end

	local v12 = p2.Instance.CFrame

	task.delay(Magnitude / 90 * 0.2, function() --[[ Line: 670 | Upvalues: p1 (copy), v12 (copy), p2 (copy) ]]
		if not p1.Movement.grappling then
			return
		end

		p1.hook.Anchored = false

		local Weld = Instance.new("Weld")

		Weld.C0 = v12:Inverse() * p1.hook.CFrame
		Weld.Part0 = p2.Instance
		Weld.Part1 = p1.hook
		Weld.Parent = p1.hook
	end)
	p1.hook.Attachment.Lines.Enabled = true
	p1.hook.Smoke.Enabled = true
	v8.Completed:Once(function() --[[ Line: 684 | Upvalues: p1 (copy), v5 (copy), v8 (copy) ]]
		p1.SFX:StopSound("GrapplerThrow")

		if not (p1.hook and p1.hook.Parent) then
			return
		end

		if v5 == "GrapplePoint" then
			p1.hook.PointHook.SoundGroup = game.SoundService.Master.SFX
			p1.hook.PointHook:Play()
		elseif p1.Charges <= 0 then
			p1.hook.Warn.SoundGroup = game.SoundService.Master.SFX
			p1.hook.Warn:Play()
		else
			p1.hook.Land.SoundGroup = game.SoundService.Master.SFX
			p1.hook.Land:Play()
		end

		p1.hook.Attachment.Hook:Emit(1)
		p1.hook.Attachment.Lines.Enabled = false
		p1.hook.Smoke.Enabled = false
		v8:Destroy()
	end)
	v9.Completed:Once(function() --[[ Line: 704 | Upvalues: v9 (copy) ]]
		v9:Destroy()
	end)
	v10.Completed:Once(function() --[[ Line: 707 | Upvalues: v10 (copy) ]]
		v10:Destroy()
	end)
	task.delay(0.0834, function() --[[ Line: 711 | Upvalues: p1 (copy) ]]
		p1.Movement.faceGrapplePoint = false
	end)
	p1.Movement.grappling = true
	p1.Movement.grapplePoint = p2.Position
	p1.Movement.grapplePart = p2.Instance

	if v2 and not p2.Instance:IsDescendantOf(workspace.DestroyFolder) then
		p1.grappleDestroyedConnection = p2.Instance.AncestryChanged:Once(
			function() --[[ Line: 720 | Upvalues: p2 (copy), p1 (copy) ]]
				repeat
					task.wait()
				until p2.Instance.Anchored == false or p1.Movement.grappling == false

				if not p1.Movement.grappling then
					return
				end

				p1:End()
			end
		)
	else
		task.spawn(function() --[[ Line: 727 | Upvalues: p2 (copy), p1 (copy) ]]
			repeat
				task.wait()
			until p2.Instance.Anchored == false or p1.Movement.grappling == false

			if not p1.Movement.grappling then
				return
			end

			p1:End()
		end)
	end

	p1.Humanoid:SetAttribute("UsingAbility", true)
end
function t.SpecialAction(p1, p2) --[[ SpecialAction | Line: 746 | Upvalues: v2 (copy), ReplicatedStorage (copy) ]]
	if p1.Time == 0 then
		return
	end

	if p2 ~= Enum.UserInputState.Begin then
		local isEnd = p2 == Enum.UserInputState.End
	end

	if p2 == Enum.UserInputState.Begin then
		if p1.Movement.diveBonked then
			return
		end

		if p1.Status.HasStatus("Flesh") then
			return
		end

		if p1.Status.HasStatus("Medal") then
			return
		end

		if p1.Movement.rail then
			return
		end

		if p1.Movement.triaHold then
			return
		end

		if p1.Movement.Anchored then
			return
		end

		if p1.allowSharkTail and not p1.sharkTailDisable then
			p1:SharkTail()

			return
		end

		if p1.Movement.grappling then
			if p1.jumpPadReel then
				return
			end

			if p1.Movement:HasUpgrade("NinjaBelt") and not p1.sharkTailDisable then
				if p1.reelCooldown then
					return
				end

				p1.jumpPadReel = true
				p1.reelStart = time()
				p1.SFX:PlaySound("GrapplerReel")
				p1.grappleReel = true

				if v2 then
					ReplicatedStorage.Events.MovementGiftMagnet:Fire({
						Add = 1.75,
					})
				end
			else
				p1:End()
			end
		else
			p1.specialHeld = true
			p1.grapplerCrosshair.Parent = workspace
			p1.grappleCancelled = false

			if p1.Humanoid:GetState() ~= Enum.HumanoidStateType.Running then
				p1.Animator:PlayAnimation("GrappleStart")
			end

			p1.Animator:StopAnimation("GrappleThrow")
			p1.Animator:StopAnimation("GrappleLoop")
		end
	else
		if p2 ~= Enum.UserInputState.End then
			return
		end

		p1.specialHeld = false
		p1.grapplerCrosshair.Parent = nil
		p1.Animator:StopAnimation("GrappleStart")

		if p1.Movement.diveBonked then
			return
		end

		if p1.grappleCancelled then
			p1.grappleCancelled = false

			return
		end

		if p1.Movement.grappling then
			p1:End()
		else
			if p1.Status.HasStatus("Flesh") then
				return
			end

			if p1.Status.HasStatus("Medal") then
				return
			end

			if p1.Movement.rail then
				return
			end

			if p1.Movement.triaHold then
				return
			end

			if p1.Movement.Anchored then
				return
			end

			local v1 = p1:Cast()

			if not v1 then
				return
			end

			if not (p1.macroChecks >= 7) then
				p1:Start(v1)
			end
		end
	end
end
function t.AltSpecialAction(p1, p2) --[[ AltSpecialAction | Line: 840 | Upvalues: v2 (copy), ReplicatedStorage (copy) ]]
	if not p1.Movement.grappling then
		return
	end

	if p1.Time == 0 then
		return
	end

	if p2 == Enum.UserInputState.Begin then
		if not p1.Movement:HasUpgrade("NinjaBelt") or (p1.jumpPadReel or p1.reelCooldown) then
			return
		end

		p1.jumpPadReel = true
		p1.reelStart = time()
		p1.SFX:PlaySound("GrapplerReel")
		p1.grappleReel = true

		if v2 then
			ReplicatedStorage.Events.MovementGiftMagnet:Fire({
				Add = 1.75,
			})
		end
	else
		if p2 ~= Enum.UserInputState.End or not p1.grappleReel then
			return
		end

		p1:End()
	end
end
function t.RefreshStaminaUI(p1) --[[ RefreshStaminaUI | Line: 865 ]]
end
function t.OnStateChanged(p1, p2, p3) --[[ OnStateChanged | Line: 879 ]]
	if p3 == Enum.HumanoidStateType.Running or p3 == Enum.HumanoidStateType.Landed then
		p1.lastGrappleRelease = -1000
		p1.JumpPadCombo = 0

		local Movement = p1.Movement

		Movement.grappleSpeed = Movement.grappleSpeed - 4

		if p1.sharkTailDisable then
			p1.sharkTailDisable = false
		end

		if p1.reelCooldown then
			p1.UI.Frame.Bar.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
		else
			p1.UI.Frame.Bar.BackgroundColor3 = Color3.new(255 / 255, 255 / 255, 255 / 255)
		end

		p1.UI.Frame.Outline.UIStroke.Color = p1.UI.Frame.Bar.BackgroundColor3
		p1.allowSharkTail = false
		p1.Animator:StopAnimation("GrappleStart")
	else
		if not p1.specialHeld then
			return
		end

		p1.Animator:PlayAnimation("GrappleStart")
	end
end
function t.Step(p1, p2) --[[ Step | Line: 931 | Upvalues: v2 (copy), v3 (ref), v4 (ref) ]]
	local Time = p1.Time

	if p1.specialHeld and not p1.Movement.grappling then
		local CurrentCamera = workspace.CurrentCamera
		local v1 = if game.UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			then true
			elseif p1.Movement.preferredInput == Enum.PreferredInput.KeyboardAndMouse then false
			else true
		local v22 = CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)

		if v1 then
			p1.cameraOffset = p1.cameraOffset:Lerp(CFrame.new(2, 0.5, 0), p2 * 6)
		else
			p1.cameraOffset = p1.cameraOffset:Lerp(CFrame.new(), p2 * 6)
		end

		local v32, v42 = p1:Cast(true)

		if v32 then
			p1.memoryPosition = v32.Position
			p1.memoryUpdate = time()

			if p1.grapplerCrosshair then
				p1.grapplerCrosshair.Position = v32.Position
				p1.grapplerCrosshair.Size = p1.grapplerCrosshair.Size:Lerp(Vector3.new(0.3, 0.3, 0.3), p2 * 7)
			end

			if not v1 then
				v22 = (v32.Position - p1.RootPart.Position) * Vector3.new(1, 0, 1)
			end
		else
			if p1.grapplerCrosshair then
				if time() - p1.memoryUpdate < 0.25 then
					p1.grapplerCrosshair.Position = p1.memoryPosition
				else
					p1.memoryUpdate = -1000

					if v1 then
						p1.grapplerCrosshair.Position = CurrentCamera.CFrame.Position
							+ CurrentCamera.CFrame.LookVector * 2048
					end
				end

				p1.grapplerCrosshair.Size = p1.grapplerCrosshair.Size:Lerp(Vector3.new(0, 0, 0), p2 * 7)
			end

			if v42 then
				v22 = v42 * Vector3.new(1, 0, 1)
			end
		end

		if p1.grapplerCrosshair then
			local Frame = p1.grapplerCrosshair.BillboardGui.Frame

			if v32 or time() - p1.memoryUpdate < 0.25 then
				Frame.BackgroundColor3 = Color3.new(255 / 255, 255 / 255, 255 / 255)
			else
				Frame.BackgroundColor3 = Color3.new(255 / 255, 0 / 255, 0 / 255)
			end
		end

		if v22.Magnitude > 0.01 then
			p1.RootPart.CFrame = p1.RootPart.CFrame:Lerp(CFrame.lookAlong(p1.RootPart.Position, v22), p2 * 20)
		end
	else
		p1.memoryUpdate = -1000

		if p1.grapplerCrosshair then
			p1.grapplerCrosshair.Size = Vector3.new(0, 0, 0)
		end

		p1.cameraOffset = p1.cameraOffset:Lerp(CFrame.new(), p2 * 6)
	end

	local CurrentCamera = workspace.CurrentCamera

	CurrentCamera.CFrame = CurrentCamera.CFrame * p1.cameraOffset

	local v6 = 1

	if v2 then
		local Gift = game.ReplicatedStorage.GiftCounters.Gift
		local v7 = Gift:GetAttribute("MaxGifts") or 1
		local v8 = v7 - Gift.Value

		if not game.ReplicatedStorage.InRound.Value then
			v7 = 1
			v8 = 0
		end

		if v7 == 0 and v8 == 0 then
			v7 = 1
			v8 = 0
		end

		if v7 then
			v6 = math.clamp(v8 / v7 / 1 + 1, 1, 2)
		end

		p1.UI.Frame.Under.Text = string.format("%.2f", v6) .. "x regen"
		p1.UI.Frame.Under.Visible = game.ReplicatedStorage.InRound.Value
	end

	if p1.Movement.grappling then
		if p1.grapplePart and p1.grapplePart.Parent then
			if p1.grapplePart.Name == "Bell" and not p1.grapplePart.CanTouch then
				p1:End()

				return
			end

			p1.ropeAttachment.WorldPosition = (p1.grapplePart.CFrame * p1.grappleOffset).Position
			p1.Movement.grapplePoint = p1.ropeAttachment.WorldPosition

			if workspace:Raycast(p1.RootPart.Position, Vector3.new(0, -2.9, 0), p1.grappleParams) then
				p1:End(true)

				return
			end

			if p1.jumpPadReel then
				local Unit = (-p1.RootPart.Position + p1.Movement.grapplePoint).Unit

				if Unit ~= Unit then
					Unit = Vector3.new(0, 0, 0)
				end

				local v10 = p1.Humanoid.WalkSpeed * 2 * ((time() - p1.reelStart) * 0.5 + 1)

				p1.Movement:SetMoveDirection(Unit * Vector3.new(1, 0, 1))
				p1.RootPart.Velocity = Unit * v10
				p1.SFX:SetSpeed("GrapplerReel", (math.clamp(p1.RootPart.Velocity.Magnitude / 24, 0.5, 3)))

				if (p1.RootPart.Position - p1.Movement.grapplePoint).Magnitude < 3 then
					p1:End(true)

					return
				end

				if
					Unit:Dot((-(p1.RootPart.Position + p1.RootPart.Velocity * p2 * 2) + p1.Movement.grapplePoint).Unit)
					< 0
				then
					print("dot product ungrapple. very interesting")
					p1:End(true)

					return
				end
			end

			local v13 = math.map(
				math.clamp((p1.RootPart.Position - p1.Movement.grapplePoint).Magnitude, 24, 90),
				24,
				90,
				1,
				0.85
			)
			local sum = if p1.jumpPadReel and not p1.grappleReel then v3 / 1.5 else v3
			local v14 = v13

			if p1.Movement:HasUpgrade("TheOrb") then
				sum = sum + 3
			end

			if game.ReplicatedStorage.InRound.Value then
				p1.Time = p1.Time - p2 / sum * p1.usedGrappleTime * v14
			end

			if p1.Time <= 0 then
				p1.SFX:PlaySound("Deplete")
				p1:End(true)
				p1.TimeDrained = true
				task.delay(0.25, function() --[[ Line: 1119 | Upvalues: p1 (copy) ]]
					p1.TimeDrained = false
				end)
				p1.hook.Warn:Play()

				return
			end

			p1.hook.Timer.Volume = (1 - p1.Time / p1.usedGrappleTime) ^ 2 * 0.5

			if p1.RootPart.Velocity.Y < 15 then
				p1.yVelBelowMin = true
			end

			local Unit = (p1.RootPart.Velocity * Vector3.new(1, 0, 1)).Unit

			if Unit ~= Unit then
				Unit = Vector3.new(0, 0, 0)
			end

			local v15 = if p1.Movement:HasUpgrade("GraceWings") then 1.5 else 1
			local RootPart = p1.RootPart

			RootPart.Velocity = RootPart.Velocity
				+ p1.Movement.PlayerMoveDirection * 12 * v15 * p2 * p1.Movement.movementSpeedMulti
			p1.RootPart.RotVelocity = Vector3.new(0, 0, 0)

			if p1.Movement.faceGrapplePoint then
				p1.Animator:FaceDirection((-p1.RootPart.Position + p1.Movement.grapplePoint) * Vector3.new(1, 0, 1))
			elseif Unit ~= Vector3.new(0, 0, 0) then
				p1.Animator:FaceDirection(Unit)
			end

			p1.Movement:SetMoveDirection(Unit)
		else
			p1:End()

			return
		end
	elseif not p1.TimeDrained then
		local v17 = 1

		if p1.Movement:HasUpgrade("MiniatureHourglass") then
			v17 = v17 * 1.3
		end

		local v18 = v17 * v6

		if p1.Humanoid:GetState() == Enum.HumanoidStateType.Running then
			p1.Time = p1.Time + p2 / 60 * p1.usedGrappleTime * v18
			p1.TimeClamp = math.clamp(p1.TimeClamp, 0, p1.usedGrappleTime)
		else
			p1.Time = p1.Time + p2 / v4 * p1.usedGrappleTime * v18
		end
	end

	if p1.Movement.grappling or time() - p1.lastGrappleRelease < 1.5 then
		local v20 = if p1.Movement:HasUpgrade("Helmet") then 1000000 else 110

		if
			v20 < p1.RootPart.Velocity.Magnitude
			or p1.jumpPadReel
				and not (if time() - p1.reelStart < 0.2 then p1.Movement:HasUpgrade("Helmet") else false)
		then
			local v22 = p1.RootPart.Velocity.Unit * 2

			if (p1.RootPart.Velocity * p2 * 2).Magnitude > 2 then
				v22 = p1.RootPart.Velocity * p2 * 2
			end

			local v23 = workspace:Shapecast(p1.Movement.Hitbox, v22, p1.Movement.moveCastParams)

			if v23 then
				if v23.Normal.Y < 0.7 then
					p1.Movement:DiveBonk(v23)
				end

				p1:End(true)

				return
			end
		end
	end

	if p1.TimeClamp > 0 then
		p1.Time = math.clamp(p1.Time, 0, p1.TimeClamp)

		if p1.Time == p1.TimeClamp and p1.Time ~= Time then
			p1.SFX:PlaySound("Recharge")
		end
	else
		p1.Time = 0
	end

	if p1.UI then
		math.clamp(p1.Time / p1.usedGrappleTime, 0, 1)
		p1.UI.Frame.Bar.Size = UDim2.fromScale(p1.Time / p1.usedGrappleTime, 1)
	end

	if p1.Humanoid:GetState() == Enum.HumanoidStateType.Running then
		p1.Movement.grappleSpeed = math.max(0, p1.Movement.grappleSpeed - p2 * 120)
	else
		p1.Movement.grappleSpeed = math.max(0, p1.Movement.grappleSpeed - p2 * 5)
	end
end

return t
