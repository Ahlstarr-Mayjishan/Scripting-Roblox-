-- Script Path: game:GetService("Workspace").Enemies.Operator.Operator_AI
-- Took 1.01s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local GreaterCurseHandler = require(game.ReplicatedFirst.ClientModules.GreaterCurseHandler)

require(game.ReplicatedFirst.ClientModules.CurseHandler)

local StatusEffectHandler = require(game.ReplicatedFirst.ClientModules.StatusEffectHandler)
local SettingsHandler = require(game.ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local LocalPlayer = game.Players.LocalPlayer
local OperatorGUI = LocalPlayer.PlayerGui.OperatorGUI
local Character = LocalPlayer.Character
local v1 = nil
local v2 = 0
local v3 = 0
local v4 = 0
local v5 = false

tick()

local v6 = Random.new()
local v7 = false
local v8 = false
local v9 = false
local v10 = 0
local v11 = false
local v12 = 1
local v13 = 0
local v14 = Vector2.new(0.2, 0.5)
local zero = Vector2.zero
local v15 = 0
local isValue = game.ReplicatedStorage.Difficulty.Value == 3
local BobEffect = OperatorGUI:WaitForChild("BobEffect")
local Sprite = BobEffect:WaitForChild("Sprite")
local tbl = {
	OperatorMessedUp = "rbxassetid://140571750770387",
	OperatorActive = "rbxassetid://122843005116254",
	OperatorNeutral = "rbxassetid://113707297395522",
	OperatorPeaceful = "rbxassetid://104632187819937",
	VBOperatorMessedUp = "rbxassetid://131865525179721",
	VBOperatorActive = "rbxassetid://126683265421685",
	VBOperatorNeutral = "rbxassetid://82814174247605",
}
local v16 = 0

for k, v in pairs(OperatorGUI:QueryDescendants("Sound")) do
	local v17 = v:Clone()

	v17.Volume = 0
	v17.Name = ""
	v17.Parent = OperatorGUI
	v17.Looped = true
	v17:Play()
end

for k, v in pairs(tbl) do
	local v18 = Sprite:Clone()

	v18.Image = v
	v18.ImageTransparency = 0.999
	v18.Visible = true
	v18.Parent = OperatorGUI
end

local v19 = "Operator"

function SetSprite(p1) --[[ SetSprite | Line: 72 | Upvalues: tbl (copy), v19 (ref), Sprite (ref) ]]
	local v1 = tbl[v19 .. p1]

	if v1 then
		Sprite.Image = v1
	else
		warn("no sprite for", v19 .. p1)
	end
end
LocalPlayer.Dead.Changed:Connect(function(p1) --[[ Line: 89 | Upvalues: OperatorGUI (ref), Sprite (ref) ]]
	if not p1 then
		return
	end

	OperatorGUI.Enabled = false
	Sprite.Visible = false

	for k, v in pairs(OperatorGUI:QueryDescendants("Sound:not([$Skip])")) do
		v:Stop()
		v.Volume = 0
	end
end)
Character.Destroying:Connect(function() --[[ Line: 100 | Upvalues: OperatorGUI (ref), Sprite (ref) ]]
	OperatorGUI.Enabled = false
	Sprite.Visible = false

	for k, v in pairs(OperatorGUI:QueryDescendants("Sound:not([$Skip])")) do
		v:Stop()
		v.Volume = 0
	end
end)
Sprite.Visible = false
LocalPlayer.CharacterAdded:Connect(
	function() --[[ Line: 124 | Upvalues: OperatorGUI (ref), LocalPlayer (copy), Character (ref), BobEffect (ref), Sprite (ref), v7 (ref), v5 (ref) ]]
		OperatorGUI = LocalPlayer.PlayerGui:WaitForChild("OperatorGUI")
		Character = LocalPlayer.Character
		OperatorGUI.Enabled = true
		BobEffect = OperatorGUI:WaitForChild("BobEffect")
		Sprite = BobEffect:WaitForChild("Sprite")
		v7 = false
		v5 = false
	end
)

local function kill() --[[ kill | Line: 140 | Upvalues: v11 (ref), LocalPlayer (copy), v3 (ref), v1 (ref), Character (ref), GreaterCurseHandler (copy), Sprite (ref), OperatorGUI (ref), v5 (ref) ]]
	v11 = false

	if
		LocalPlayer.Dead.Value or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
	then
		return
	end

	if LocalPlayer:FindFirstChild("IFRAMES") ~= nil or v3 ~= 1 then
		v3 = 0
		v1 = nil
		Sprite.Visible = false

		return
	end

	v1 = nil
	v3 = 0

	local _ = Character.Humanoid:GetAttribute("PlayerMoveDirection") or Vector3.new(0, 0, 0)

	Character.Humanoid:GetAttribute("UsingAbility")
	Character.Humanoid:GetAttribute("Sliding")

	local v2 = Vector3.new(0, 1, 0) * math.random(18, 24)

	if GreaterCurseHandler.IsCurseEnabled("VBOperator") then
		Sprite.ImageColor3 = Color3.new(255 / 255, 255 / 255, 255 / 255)
		OperatorGUI.VBKill:Play()
	else
		OperatorGUI.Kill:Play()
	end

	SetSprite("MessedUp")
	v5 = game.ReplicatedStorage.Events.DiedFunc:InvokeServer("Operator", v2, game.ReplicatedStorage.Level.Value)
	Sprite.Visible = false
end

local function isStationary() --[[ isStationary | Line: 177 | Upvalues: LocalPlayer (copy), Character (ref), StatusEffectHandler (copy) ]]
	if
		LocalPlayer.Dead.Value or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
	then
		return true
	end

	if not Character:FindFirstChild("Humanoid") then
		return true
	end

	if StatusEffectHandler.HasStatus("Fire") then
		return true
	end

	local v2 = Character.Humanoid:GetAttribute("PlayerMoveDirection") or Vector3.new(0, 0, 0)
	local v3 = Character.Humanoid:GetAttribute("UsingAbility")

	return if v2.Magnitude <= 0.1 then not v3 and not Character.Humanoid:GetAttribute("Sliding") else false
end

local function checkOperatorKill(p1, p2) --[[ checkOperatorKill | Line: 194 | Upvalues: v3 (ref), v1 (ref), OperatorGUI (ref), Sprite (ref), LocalPlayer (copy), v2 (ref), v4 (ref), kill (copy) ]]
	local function Survived() --[[ Survived | Line: 195 | Upvalues: v3 (ref), v1 (ref), OperatorGUI (ref), Sprite (ref) ]]
		v3 = 0
		v1 = nil
		OperatorGUI:WaitForChild("Tick"):Stop()
		SetSprite("Peaceful")
		OperatorGUI.End.Volume = 1
		OperatorGUI.End:Play()
		game:GetService("TweenService")
			:Create(Sprite, TweenInfo.new(2), {
				ImageTransparency = 1,
			})
			:Play()
		Sprite.Rotation = Random.new():NextNumber(-1, 1) * 15
		game:GetService("TweenService")
			:Create(Sprite, TweenInfo.new(1, Enum.EasingStyle.Quart), {
				Rotation = 0,
			})
			:Play()
		task.wait(2)
		Sprite.Visible = false
		OperatorGUI.End:Stop()
	end

	if v1 == nil or v3 ~= 0 then
		if v3 ~= 1 then
			return
		end

		if
			LocalPlayer.Dead.Value
			or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
		then
			return
		end

		if p2 then
			v2 = v2 + p1

			if v2 > 0.1 then
				Survived()
			end
		else
			if not (tick() - v4 > 0.15) then
				return
			end

			kill()
		end
	else
		if
			LocalPlayer.Dead.Value
			or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
		then
			return
		end

		local v32 = tick() - v1

		if v2 > 0.15 then
			Survived()
		elseif v32 > 3 then
			v2 = 0
			v3 = 1
			Sprite.Rotation = 0
			SetSprite("Active")
			v4 = tick()
		end

		if not (v32 > 0.55) then
			return
		end

		v2 = if p2 then v2 + p1 else 0
	end
end

local function checkLitanyKill(p1, p2) --[[ checkLitanyKill | Line: 258 | Upvalues: v8 (ref), v10 (ref), v9 (ref) ]]
	if v8 then
		if p2 then
			v10 = v10 + p1
		end

		if v10 > 0.05 then
			v9 = true
		end
	else
		v10 = 0
		v9 = false
	end
end

local function renderStepped(p1) --[[ renderStepped | Line: 274 | Upvalues: v16 (ref), LocalPlayer (copy), OperatorGUI (ref), v7 (ref), isStationary (copy), GreaterCurseHandler (copy), BobEffect (ref), v8 (ref), v10 (ref), v9 (ref), checkOperatorKill (copy) ]]
	v16 = v16 + p1

	if
		LocalPlayer.Dead.Value or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
	then
		return
	end

	if OperatorGUI and OperatorGUI.Parent then
		local v2 = isStationary()

		if GreaterCurseHandler.IsCurseEnabled("VBOperator") then
			BobEffect.Position = UDim2.fromScale(0, math.sin(v16 * 3) / 200)

			if not v8 then
				v10 = 0
				v9 = false

				return
			end

			if v2 then
				v10 = v10 + p1
			end

			if v10 > 0.05 then
				v9 = true
			end
		else
			BobEffect.Position = UDim2.fromScale(0, math.sin(v16 * 3) / 75)
			checkOperatorKill(p1, v2)
		end
	else
		if v7 then
			return
		end

		v7 = true
	end
end

game:GetService("RunService").RenderStepped:Connect(renderStepped)

local function f20() --[[ Line: 310 | Upvalues: v1 (ref), v2 (ref), Sprite (ref), SettingsHandler (copy), OperatorGUI (ref), LocalPlayer (copy), v5 (ref), v3 (ref) ]]
	v1 = nil
	v2 = 0
	Sprite.ImageTransparency = 0.2
	Sprite.Visible = true

	if SettingsHandler.Get({ "Misc", "CenteredEnemies" }) then
		Sprite.ImageTransparency = 0.45
		Sprite.Position = UDim2.fromScale(0.35, -1)
	else
		Sprite.Position = UDim2.fromScale(0.2, -1)
	end

	game:GetService("TweenService")
		:Create(Sprite, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {
			Position = UDim2.fromScale(Sprite.Position.X.Scale, 0.55),
		})
		:Play()
	OperatorGUI:WaitForChild("Start").Volume = 1
	OperatorGUI:WaitForChild("Start"):Play()
	SetSprite("Peaceful")
	v1 = tick()
	v2 = 0
	task.wait(0.6)

	if v2 >= 0.15 then
		return
	end

	if
		LocalPlayer.Dead.Value or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
	then
		return
	end

	SetSprite("Neutral")
	OperatorGUI:WaitForChild("Tick"):Play()
	OperatorGUI.Tick.Volume = 1

	local v22 = 2.5

	while task.wait(0.25) and (OperatorGUI and (OperatorGUI.Parent and (Sprite.Visible and not v5))) do
		if
			LocalPlayer.Dead.Value
			or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
		then
			break
		end

		v22 = -v22

		if v1 then
			game.TweenService
				:Create(Sprite, TweenInfo.new(0.25, Enum.EasingStyle.Elastic), {
					Rotation = v22,
				})
				:Play()
		end
	end
end

local v21 = 5
local v22 = 0
local v23 = false

local function f24() --[[ Line: 381 | Upvalues: v22 (ref), v21 (ref), v11 (ref), v13 (ref), zero (ref), v14 (ref), v23 (ref), Sprite (ref), v15 (ref), v12 (ref), v8 (ref) ]]
	local v1 = time()

	task.wait()
	v22 = tick()

	local v2 = v21

	while v11 do
		local v3 = time() - v1
		local v4 = time()
		local v5 = workspace.CurrentCamera.ViewportSize.Y / 785
		local v6 = math.noise(time() * 15 + 5384) * v13 * 2 + zero.X
		local v7 = math.noise(time() * 15 + 1813) * v13 * 2 + zero.Y
		local v82 = math.noise(time() * 15 + 591) * v13
		local v9 = UDim2.new(v14.X, v6, v14.Y, v7)
		local v112 = math.min((tick() - v22) / 0.25, 1)
		local v142 = math.lerp(
			v2,
			v21,
			(game:GetService("TweenService"):GetValue(v112, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out))
		)

		if tick() - v22 >= 0.25 and v23 then
			v22 = tick()
			v2 = v21
			v21 = -v21
		end

		Sprite.Position = v9
		Sprite.Rotation = v15 + v82 + v142
		v15 = v15 + math.noise(time() * 3 + 5713) * 0.14 * (v3 * 60)
		zero = zero
			+ Vector2.new(math.noise(time() * 3 + 493.1) * 0.8 * v5, math.noise(time() * 3 + 89314) * 0.5 * v5)
				* (v3 * 60)

		if v12 == 1 then
			v12 = 2
		elseif v12 == 2 then
			v12 = 1
		end

		v1 = v4

		if not v8 then
			v13 = v13 - v3 * 24
		end

		v13 = math.max(v13, 0)
		task.wait()
	end
end

local function f25() --[[ Line: 444 | Upvalues: GreaterCurseHandler (copy), v19 (ref), Sprite (ref), SettingsHandler (copy), v14 (ref), v15 (ref), v13 (ref), v23 (ref), v1 (ref), v2 (ref), zero (ref), v12 (ref), OperatorGUI (ref), v11 (ref), f24 (copy), isStationary (copy), LocalPlayer (copy), v8 (ref), v9 (ref), v3 (ref), kill (copy), v6 (copy) ]]
	if GreaterCurseHandler.IsCurseEnabled("VBOperator") then
		v19 = "VBOperator"
		Sprite.UIAspectRatioConstraint.AspectRatio = 1
		Sprite.Size = UDim2.fromScale(0.345, 0.497)
	end

	Sprite.Visible = true
	Sprite.ImageTransparency = 0.2
	SetSprite("Neutral")
	Sprite.ImageColor3 = Color3.new(255 / 255, 255 / 255, 255 / 255)

	if SettingsHandler.Get({ "Misc", "CenteredEnemies" }) then
		Sprite.ImageTransparency = 0.35
		v14 = Vector2.new(0.35, 0.5)
	else
		v14 = Vector2.new(0.2, 0.5)
	end

	v15 = 0
	v13 = 0
	v23 = true
	v1 = nil
	v2 = 0
	Sprite.Position = UDim2.fromScale(0.2, -1)

	local v16 = 0

	local function Animate(p1, p2) --[[ Animate | Line: 480 | Upvalues: v13 (ref), zero (ref), v14 (ref), Sprite (ref), v15 (ref), v12 (ref) ]]
		local v2 = math.lerp(
			-1,
			0.5,
			(game:GetService("TweenService"):GetValue(p1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))
		)
		local v3 = workspace.CurrentCamera.ViewportSize.Y / 785
		local v4 = math.noise(time() * 15 + 5384) * v13 * 2 + zero.X
		local v5 = math.noise(time() * 15 + 1813) * v13 * 2 + zero.Y
		local v6 = math.noise(time() * 15 + 591) * v13

		Sprite.Position = UDim2.new(v14.X, v4, v2, v5)
		Sprite.Rotation = v15 + v6
		v15 = v15 + math.noise(time() * 3 + 5713) * 0.14 * (p2 * 60) * p1

		local v7 = math.noise(time() * 3 + 493.1) * 0.8 * v3

		zero = zero + Vector2.new(v7, math.noise(time() * 3 + 89314) * 0.5 * v3) * (p2 * 60) * p1

		local v9

		if v12 == 1 then
			v12 = 2
		elseif v12 == 2 then
			v12 = 1
		end

		v9 = v13
		v13 = math.max(v9, 0)
	end

	OperatorGUI.VBStart:Play()
	task.spawn(
		function() --[[ Line: 516 | Upvalues: v11 (ref), Animate (copy), v16 (ref), f24 (ref), OperatorGUI (ref) ]]
			v11 = true
			Animate(0, 0)

			repeat
				local v1 = task.wait()

				v16 = v16 + v1
				Animate(v16 / 0.6, v1)
			until v16 / 0.6 >= 1

			Animate(1, 0)
			task.spawn(f24)
			OperatorGUI:WaitForChild("VBTick"):Play()
			OperatorGUI.VBTick.Volume = 1
		end
	)
	task.wait(0.6)

	local v22 = time()
	local sum = 1.5

	while true do
		task.wait()

		if sum <= time() - v22 and not isStationary() then
			sum = sum + 0.5
		end

		if
			isStationary() and sum <= time() - v22
			or time() - v22 >= 3
			or (
				LocalPlayer.Dead.Value
				or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
			)
		then
			local v32, v4, v5, v62, v7, v82, v92, v10, v112, v122, v132

			v32 = LocalPlayer.Dead.Value
				or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)

			if v32 then
				return
			end

			v4 = false

			for i = 1, 3 do
				v5 = LocalPlayer.Dead.Value
					or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)

				if v5 then
					break
				end

				task.wait(2)
				v62 = LocalPlayer.Dead.Value
					or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)

				if v62 then
					break
				end

				v8 = true
				v13 = 2
				SetSprite("Active")
				OperatorGUI.VBAlert.Volume = 1.5
				OperatorGUI.VBAlert:Play()
				v7 = time()

				repeat
					task.wait()
				until time() - v7 >= 0.5 or v9

				v82 = LocalPlayer.Dead.Value
					or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)

				if v82 then
					break
				end

				OperatorGUI.VBAlert:Stop()
				SetSprite("Neutral")
				v13 = 10
				v8 = false

				if isStationary() or v9 then
					OperatorGUI.VBEnd.Volume = 1
					OperatorGUI.VBEnd:Play()
					v92 = 0.5 - (time() - v7)

					if i ~= 3 then
						task.wait(0.25 + v92)
					end

					v10 = LocalPlayer.Dead.Value
						or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)

					if v10 then
						break
					end

					if SettingsHandler.Get({ "Misc", "CenteredEnemies" }) then
						v112 = v6:NextNumber(0.325, 0.375)
						v122 = v112
					else
						v132 = v6:NextNumber(0.19, 0.24)
						v122 = v132
					end

					v14 = Vector2.new(v122, v6:NextNumber(0.5, 0.6))
					v15 = math.random(-10, 10)

					if i ~= 3 then
						task.wait(0.25)
					end
				else
					v3 = 1
					kill()
					v4 = true

					break
				end
			end

			v23 = false
			OperatorGUI.VBEnd:Stop()

			if v4 then
				OperatorGUI.VBAlert:Stop()
				OperatorGUI.VBTick:Stop()
				game:GetService("TweenService")
					:Create(Sprite, TweenInfo.new(1), {
						ImageTransparency = 1,
					})
					:Play()
				task.wait(2)
				Sprite.Visible = false
				v11 = false
				task.delay(2, function() --[[ Line: 636 | Upvalues: OperatorGUI (ref) ]]
					OperatorGUI.End:Stop()
				end)

				return
			end

			OperatorGUI.VBSurvive:Play()
			OperatorGUI.VBAlert:Stop()
			OperatorGUI.VBTick:Stop()
			game:GetService("TweenService")
				:Create(Sprite, TweenInfo.new(1), {
					ImageTransparency = 1,
				})
				:Play()
			task.wait(2)
			Sprite.Visible = false
			v11 = false
			task.delay(2, function() --[[ Line: 636 | Upvalues: OperatorGUI (ref) ]]
				OperatorGUI.End:Stop()
			end)

			return
		end
	end
end

local v26 = if isValue then 35 else 50

if shared.Trailer then
	v26 = 3
end

OperatorGUI:WaitForChild("Tick"):Play()
OperatorGUI.Tick.Volume = 0.00001
OperatorGUI:WaitForChild("VBTick"):Play()
OperatorGUI.VBTick.Volume = 0.00001
OperatorGUI:WaitForChild("VBAlert"):Play()
OperatorGUI.VBAlert.Volume = 0.00001
OperatorGUI:WaitForChild("End"):Play()
OperatorGUI.End.Volume = 0.00001

while true do
	shared.OperatorActive = false
	shared.OperatorWishSpawn = false

	if
		v5
		or (
			LocalPlayer.Dead.Value
			or (
				if LocalPlayer.Character == nil then true elseif LocalPlayer.Character.Parent == nil then true else false
			)
		)
	then
		task.wait()
	else
		if GreaterCurseHandler.IsCurseEnabled("VBOperator") then
			v19 = "VBOperator"
			Sprite.UIAspectRatioConstraint.AspectRatio = 1
			Sprite.Size = UDim2.fromScale(0.345, 0.497)
		end

		task.wait(math.random(v26 / 1.5, v26))

		if not StatusEffectHandler.HasStatus("Fire") then
			if shared.VoidbreakerWishSpawn or (shared.KolonaWishSpawn or shared.OperatorWishSpawn) then
				repeat
					task.wait()
				until not (shared.VoidbreakerWishSpawn or (shared.KolonaWishSpawn or shared.OperatorWishSpawn))
			end

			shared.OperatorWishSpawn = true

			if _G.VoidbreakerActive == true then
				repeat
					task.wait(0.5)
				until not _G.VoidbreakerActive

				task.wait(4)
			end

			if shared.KolonaActive then
				repeat
					task.wait(0.5)
				until not shared.KolonaActive

				task.wait(4)
			end

			if
				LocalPlayer.Dead.Value
				or (
					if LocalPlayer.Character == nil
						then true
						elseif LocalPlayer.Character.Parent == nil then true
						else false
				)
			then
				task.wait()
			else
				shared.OperatorWishSpawn = false
				shared.OperatorActive = true

				local _ = tick()

				if GreaterCurseHandler.IsCurseEnabled("VBOperator") then
					f25()
				else
					f20()
				end

				shared.OperatorActive = false
				task.wait(1)
			end
		end

		continue
	end
end
