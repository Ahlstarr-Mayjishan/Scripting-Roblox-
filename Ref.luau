-- Script Path: game:GetService("ReplicatedStorage").Movement.DoubleJump
-- Took 0.45s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}

t.__index = t

local t2 = { "Highrise", "MedalStatus", "DoubleJump", "PocketBell", "Wicked", "Spirit" }
local t3 = {
	Highrise = 35,
	MedalStatus = 35,
	DoubleJump = 35,
	PocketBell = 35,
	Wicked = 35,
	Spirit = 35,
}
local Movement = game.ReplicatedStorage.Movement
local v1 = workspace:GetAttribute("Null")

function t.new(p1, p2, p3) --[[ new | Line: 28 | Upvalues: Movement (copy), t (copy) ]]
	local t2 = {
		Movement = p1,
		Animator = p2,
		Status = p1.Status,
		Character = p1.Character,
		RootPart = p1.RootPart,
		Humanoid = p1.Humanoid,
		AvailableJumps = {},
		Tweens = {},
		SizeTweens = {},
		BarsEnabled = false,
		RealWingsEnabled = false,
		LastRefreshCount = 0,
		centered = false,
		ParticleAttachment = Instance.new("Attachment"),
	}

	t2.ParticleAttachment.Position = Vector3.new(0, -2.5, 0)
	t2.ParticleAttachment.Parent = t2.RootPart
	t2.UI = Movement.Instances.DoubleJumpUI:Clone()
	t2.Template = t2.UI.Jumps.Template
	t2.Template.Parent = nil
	t2.UI.Parent = game.Players.LocalPlayer.PlayerGui

	return setmetatable(t2, t)
end
function t.Initialise(p1) --[[ Initialise | Line: 61 | Upvalues: v1 (copy), t2 (copy) ]]
	if v1 then
		game.ReplicatedStorage.UpgradeFolder.Upgrades.ChildAdded:Connect(
			function(p12) --[[ Line: 64 | Upvalues: t2 (ref), p1 (copy) ]]
				if table.find(t2, p12.Name) ~= nil then
					p12.Changed:Connect(function() --[[ Line: 67 | Upvalues: p1 (ref) ]]
						p1:Refresh()
					end)
					p1:Refresh()
				end
			end
		)
		p1.Character:GetAttributeChangedSignal("Highrise"):Connect(function(p12) --[[ Line: 76 | Upvalues: p1 (copy) ]]
			local v1 = p1.Humanoid:GetState()

			if v1 ~= Enum.HumanoidStateType.Running and v1 ~= Enum.HumanoidStateType.Landed then
				return
			end

			p1:Refresh()
		end)
	end

	p1:Refresh()
end
function t.UsedDoubleJump(p1) --[[ UsedDoubleJump | Line: 88 | Upvalues: Movement (copy) ]]
	if not p1.Movement.SFX.legacy then
		p1.Movement.SFX:DoubleJump()
	end

	local v1 = Movement.Instances.DoubleJumpParticle:Clone()

	v1.Speed = NumberRange.new(4)
	v1.Parent = p1.ParticleAttachment
	v1:Emit(1)

	local v2 = Movement.Instances.DoubleJumpParticle:Clone()

	v2.EmissionDirection = Enum.NormalId.Top
	v2.Speed = NumberRange.new(7)
	v2.Lifetime = NumberRange.new(0.1)
	v2.Parent = p1.ParticleAttachment
	v2:Emit(1)
	game.Debris:AddItem(v1, v1.Lifetime.Max + 0.1)
	game.Debris:AddItem(v2, v2.Lifetime.Max + 0.1)
end
function t.UsedPocketBell(p1) --[[ UsedPocketBell | Line: 109 | Upvalues: Movement (copy) ]]
	if p1.Movement.SFX.legacy then
		Movement.Instances.BellSound:Play()
	else
		p1.Movement.SFX:PocketBell()
	end

	_G.RingBell(0.4)

	local v1 = Movement.Instances.PocketBellParticle:Clone()

	v1.Parent = p1.ParticleAttachment
	v1:Emit(math.random(18, 24))
	game.Debris:AddItem(v1, v1.Lifetime.Max + 0.1)
end
function t.UsedMedalStatus(p1) --[[ UsedMedalStatus | Line: 125 ]]
	if p1.Character:FindFirstChild("Medal") then
		p1.Character.Medal.Impulse:Fire()
	end

	p1:UsedDoubleJump()
end
function t.UsedHighrise(p1) --[[ UsedHighrise | Line: 132 ]]
	p1:UsedDoubleJump()
end
function t.SetUIPosition(p1, p2) --[[ SetUIPosition | Line: 136 ]]
	if not (p1.UI and p1.UI.Parent) then
		return
	end

	if p2 then
		p1.UI.Jumps.Position = UDim2.fromScale(0.5, 0.375)
	else
		p1.UI.Jumps.Position = UDim2.fromScale(0.5, 0.8)
	end

	p1.centered = p2

	if p1.Movement.Humanoid:GetState() ~= Enum.HumanoidStateType.Running then
		return
	end

	p1:Refresh()
end
function t.TryDoubleJump(p1) --[[ TryDoubleJump | Line: 154 | Upvalues: t2 (copy), t3 (copy) ]]
	if p1.Movement.Status.HasStatus("Concussion") then
		return
	end

	if p1.Movement.grappling then
		return
	end

	if p1.Movement.diving then
		return
	end

	if p1.Movement.sliding then
		return
	end

	if p1.Movement.charging and not p1.Movement:HasUpgrade("NinjaBelt") then
		return
	end

	if p1.Movement.diveBonked then
		return
	end

	local JumpPower = p1.Humanoid.JumpPower

	for v1, v2 in t2 do
		if p1.AvailableJumps[v2] and p1.AvailableJumps[v2] > 0 then
			local v3 = p1.AvailableJumps[v2]
			local AvailableJumps = p1.AvailableJumps

			AvailableJumps[v2] = AvailableJumps[v2] - 1
			p1.Movement.isDoubleJumping = true
			p1.Humanoid.JumpPower = t3[v2]
			p1.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.wait()
			p1.Humanoid.JumpPower = JumpPower

			if p1.Movement.ActiveSpecial and p1.Movement.ActiveSpecial.OnDoubleJump then
				p1.Movement.ActiveSpecial:OnDoubleJump()
			end

			if p1.Movement.chargePound then
				p1.chargePound = false
				p1.Humanoid:SetAttribute("UsingAbility", false)
			end

			local v4 = p1.UI.Jumps:FindFirstChild(v2 .. v3)

			if v4 then
				if p1.SizeTweens[v4] then
					p1.SizeTweens[v4]:Cancel()
					p1.SizeTweens[v4]:Destroy()
					p1.SizeTweens[v4] = nil
				end

				v4.Bar.Size = UDim2.fromScale(0, 1)
			end

			if not p1.charging then
				p1.Animator:PlayAnimation("DoubleJump")
			end

			p1.Movement.usedDoubleJumpInAir = true

			if p1["Used" .. v2] then
				p1["Used" .. v2](p1)

				return
			end

			break
		end
	end
end
function t.OnStateChanged(p1, p2, p3) --[[ OnStateChanged | Line: 231 ]]
	if p3 == Enum.HumanoidStateType.Landed then
		p1:Refresh()
	end

	if p3 == Enum.HumanoidStateType.Freefall and not p1.BarsEnabled then
		p1.BarsEnabled = true

		for v1, v2 in p1.Tweens do
			v2:Pause()
			v2:Destroy()
		end

		if p1.UI and p1.UI:FindFirstChild("Jumps") then
			local v3 = if p1.centered then 0.25 else 0

			for v4, v5 in p1.UI.Jumps:GetChildren() do
				if v5:IsA("Frame") then
					local v6 = game.TweenService:Create(v5.Outline.UIStroke, TweenInfo.new(0.1), {
						Transparency = v3,
					})
					local v7 = game.TweenService:Create(v5.Bar, TweenInfo.new(0.1), {
						BackgroundTransparency = v3,
					})

					table.insert(p1.Tweens, v6)
					table.insert(p1.Tweens, v7)
					v6:Play()
					v7:Play()
				end
			end
		end
	end

	if p3 == Enum.HumanoidStateType.Freefall and (not p1.RealWingsEnabled and p1.Movement:HasUpgrade("RealWings")) then
		p1.RealWingsEnabled = true

		local v8 = game.TweenService:Create(p1.UI.RealWings.Outline.UIStroke, TweenInfo.new(0.1), {
			Transparency = 0,
		})
		local v9 = game.TweenService:Create(p1.UI.RealWings.Bar, TweenInfo.new(0.1), {
			BackgroundTransparency = 0,
		})

		v8:Play()
		v9:Play()
	end

	if
		not (
			(if p3 == Enum.HumanoidStateType.Running then true else p3 == Enum.HumanoidStateType.Landed)
			and p1.BarsEnabled
		)
	then
		return
	end

	p1.BarsEnabled = false

	for v11, v12 in p1.Tweens do
		v12:Pause()
		v12:Destroy()
	end

	if not (p1.UI and p1.UI:FindFirstChild("Jumps")) then
		return
	end

	for v13, v14 in p1.UI.Jumps:GetChildren() do
		if v14:IsA("Frame") then
			local v15 = 0.25 + p1.LastRefreshCount * 0.03
			local v16 = game.TweenService:Create(
				v14.Outline.UIStroke,
				TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, v15),
				{
					Transparency = 1,
				}
			)
			local v17 = game.TweenService:Create(
				v14.Bar,
				TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, v15),
				{
					BackgroundTransparency = 1,
				}
			)

			table.insert(p1.Tweens, v16)
			table.insert(p1.Tweens, v17)
			v16:Play()
			v17:Play()
		end
	end
end
function t.Refresh(p1, p2, p3) --[[ Refresh | Line: 328 | Upvalues: t2 (copy) ]]
	p1.AvailableJumps = {}
	p1.Character:SetAttribute("Jumps", 3)

	if p1.Movement.ClassID == "class/Wicked" then
		return
	end

	if p1.Status.HasStatus("Medal") then
		p1.AvailableJumps.MedalStatus = 1
	end

	if p1.Character:GetAttribute("Highrise") then
		p1.AvailableJumps.Highrise = 1
	else
		p1.AvailableJumps.Highrise = nil
	end

	if p2 then
		for v1, v2 in p2 do
			p1.AvailableJumps[v1] = v2
		end
	end

	local count = 0
	local count2 = 0

	if not (p1.UI and p1.UI.Parent) then
		return
	end

	for i = #t2, 1, -1 do
		local v3 = t2[i]
		local v4, v5 = p1.Movement:HasUpgrade(v3)

		if p1.AvailableJumps[v3] then
			v5 = p1.AvailableJumps[v3]
			v4 = true
		end

		if v4 then
			if p1.Movement.ClassID == "class/Wanted" then
				v5 = v5 * 2
			end

			for j = 1, v5 do
				count = count + 1

				local v6 = p1.UI.Jumps:FindFirstChild(v3 .. j)

				if not v6 then
					local v7 = p1.Template:Clone()

					v7.Name = v3 .. j
					v7:SetAttribute("JustCreated", true)
					v7.Parent = p1.UI.Jumps

					if not p1.BarsEnabled then
						v7.Bar.BackgroundTransparency = 1
						v7.Outline.UIStroke.Transparency = 1
					end

					v6 = v7
				end

				v6.LayoutOrder = count

				if v6.Bar.Size == UDim2.fromScale(1, 1) then
					count2 = count2 + 1
				end
			end

			if not p3 then
				p1.AvailableJumps[v3] = v5
			end

			continue
		end

		if p1.AvailableJumps[v3] == nil or p1.AvailableJumps[v3] <= 0 then
			for v8, v9 in p1.UI.Jumps:GetChildren() do
				if string.find(v9.Name, v3) then
					v9:Destroy()
				end
			end
		end
	end

	local count3 = 0

	for k = #t2, 1, -1 do
		local v10 = t2[k]
		local v11, v12 = p1.Movement:HasUpgrade(v10)

		if p1.AvailableJumps[v10] then
			v12 = p1.AvailableJumps[v10]
			v11 = true
		end

		if v11 then
			for n = 1, v12 do
				local v13 = p1.UI.Jumps:FindFirstChild(v10 .. n)

				if v13 then
					v13.LayoutOrder = count3
					count3 = count3 + 1
				end
			end
		end
	end

	for v14, v15 in p1.UI.Jumps:GetChildren() do
		if v15:IsA("Frame") and (v15.Bar.Size ~= UDim2.fromScale(1, 1) or v15:GetAttribute("JustCreated")) then
			v15:SetAttribute("JustCreated", nil)

			local v16 = (v15.LayoutOrder - count2 - 1) * 0.03
			local v17 = game.TweenService:Create(
				v15.Bar,
				TweenInfo.new(0.07, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, v16),
				{
					Size = UDim2.fromScale(1, 1),
				}
			)

			p1.SizeTweens[v15] = v17
			v17:Play()
			task.delay(v16, function() --[[ Line: 452 | Upvalues: p1 (copy), v15 (copy) ]]
				if p1.SizeTweens[v15] then
					p1.Movement.SFX:PlaySound("Jump_Double_Recharge")
					v15.Size = UDim2.fromScale(1, 0.6)
					game.TweenService
						:Create(v15, TweenInfo.new(1, Enum.EasingStyle.Elastic), {
							Size = UDim2.fromScale(1, 1),
						})
						:Play()
				end
			end)
		end
	end

	p1.LastRefreshCount = count - count2

	if count > 1 then
		p1.UI.Jumps.Size = UDim2.fromScale((if p1.centered then 0.13 else 0.2) + (count - 1) * 0.04, 0.01)
	else
		p1.UI.Jumps.Size = UDim2.fromScale(if p1.centered then 0.13 else 0.2, 0.01)
	end

	p1.Character:SetAttribute("Jumps", count + 3)
end

return t
