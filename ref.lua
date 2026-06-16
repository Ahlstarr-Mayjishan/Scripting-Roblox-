-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Guardian.Guardian_ClientAI
-- Took 0.54s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local TweenService = game:GetService("TweenService")
local v1 = script.Parent
local sprite = v1:WaitForChild("head"):WaitForChild("sprite")
local CurseHandler = require(game.ReplicatedFirst.ClientModules.CurseHandler)
local v2 = Random.new()

local function f3(p1) --[[ Line: 8 | Upvalues: v2 (copy), sprite (copy), TweenService (copy) ]]
	if p1 then
		v2:NextNumber(2, 2.3)
	else
		v2:NextNumber(1.7, 2)
	end

	if p1 then
		local v22 = v2:NextNumber(8, 12)

		sprite.Rotation = v22 * math.sign(math.random() - 0.5)
	else
		local v5 = v2:NextNumber(30, 50)

		sprite.Rotation = v5 * math.sign(math.random() - 0.5)
	end

	TweenService
		:Create(sprite, TweenInfo.new(v2:NextNumber(1.7, 2), Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Rotation = 0,
		})
		:Play()
end

local function f4() --[[ Line: 27 | Upvalues: CurseHandler (copy), v1 (copy), TweenService (copy) ]]
	if not CurseHandler.IsCurseEnabled("Camouflage") then
		return
	end

	local head = v1.head

	if CurseHandler.IsCurseEnabled("CrayonEnemies") then
		head = v1.crayoner
	end

	for k, v in pairs(head:GetChildren()) do
		TweenService:Create(v, TweenInfo.new(0.5), {
			ImageTransparency = 1,
		}):Play()
		task.delay(2, function() --[[ Line: 35 | Upvalues: TweenService (ref), v (copy) ]]
			TweenService:Create(v, TweenInfo.new(0.2), {
				ImageTransparency = 0,
			}):Play()
		end)
	end
end

local function f5(p1) --[[ Line: 42 | Upvalues: v1 (copy), f3 (copy), TweenService (copy), f4 (copy) ]]
	v1.Position = p1.Start
	f3(false)
	TweenService:Create(v1, TweenInfo.new(p1.Speed), {
		Position = p1.End,
	}):Play()
	f4()
	task.wait(p1.Speed)
end

local v6 = false

local function f7(p1) --[[ Line: 60 | Upvalues: v6 (ref), v1 (copy) ]]
	v6 = true
	game.TweenService
		:Create(v1.AimAttachment.Beam, TweenInfo.new(0.2), {
			Brightness = 2,
		})
		:Play()

	repeat
		if not (p1 and (p1.Parent and p1:FindFirstChild("HumanoidRootPart"))) then
			break
		end

		v1.AimAttachment.Position = (p1.HumanoidRootPart.Position - v1.Position).Unit * 11
		task.wait()
	until v6 == false

	game.TweenService
		:Create(v1.AimAttachment.Beam, TweenInfo.new(0.2), {
			Brightness = 0,
		})
		:Play()
end

local function f8() --[[ Line: 84 | Upvalues: TweenService (copy), sprite (copy) ]]
	TweenService:Create(sprite.Parent, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Brightness = 1.36,
	}):Play()
end

script.Parent.ClientEvent.OnClientEvent:Connect(
	function(p1, p2) --[[ Line: 88 | Upvalues: f5 (copy), f7 (copy), v6 (ref), sprite (copy), f3 (copy), f8 (copy) ]]
		if p1 == "TweenBaby" then
			f5(p2)

			return
		end

		if p1 == "StartIndicator" then
			f7(p2.Target)

			return
		end

		if p1 == "EndIndicator" then
			v6 = false

			return
		end

		if p1 == "FrameReset" then
			if sprite:FindFirstChild("animationIndex") then
				sprite:WaitForChild("animationIndex").Value = 0
			end
		else
			if p1 == "Wobble" then
				f3(true)

				return
			end

			if p1 ~= "Brighten" then
				return
			end

			f8(true)
		end
	end
)

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.ShadowGuardian.ShadowGuardian_ClientAI
-- Took 0.42s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local TweenService = game:GetService("TweenService")
local v1 = script.Parent
local sprite = v1:WaitForChild("head"):WaitForChild("sprite")
local ClientEvent = v1:WaitForChild("ClientEvent")

require(game.ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)

local CurseHandler = require(game.ReplicatedFirst.ClientModules.CurseHandler)
local v2 = Random.new()

local function f3(p1) --[[ Line: 10 | Upvalues: v2 (copy), sprite (copy), TweenService (copy) ]]
	if p1 then
		v2:NextNumber(1.2, 1.85)
	else
		v2:NextNumber(1, 1.3)
	end

	if p1 then
		local v22 = v2:NextNumber(8, 12)

		sprite.Rotation = v22 * math.sign(math.random() - 0.5)
	else
		local v5 = v2:NextNumber(40, 60)

		sprite.Rotation = v5 * math.sign(math.random() - 0.5)
	end

	TweenService
		:Create(sprite, TweenInfo.new(v2:NextNumber(1, 1.3), Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Rotation = 0,
		})
		:Play()
end

local function f4() --[[ Line: 29 | Upvalues: CurseHandler (copy), v1 (copy), TweenService (copy) ]]
	if not CurseHandler.IsCurseEnabled("Camouflage") then
		return
	end

	local head = v1.head

	if CurseHandler.IsCurseEnabled("CrayonEnemies") then
		head = v1.crayoner
	end

	for k, v in pairs(head:GetChildren()) do
		TweenService:Create(v, TweenInfo.new(0.5), {
			ImageTransparency = 1,
		}):Play()
		task.delay(2, function() --[[ Line: 37 | Upvalues: TweenService (ref), v (copy) ]]
			TweenService:Create(v, TweenInfo.new(0.2), {
				ImageTransparency = 0,
			}):Play()
		end)
	end
end

local function f5(p1) --[[ Line: 44 | Upvalues: v1 (copy), f3 (copy), TweenService (copy), f4 (copy) ]]
	v1.Position = p1.Start
	f3(false)
	TweenService:Create(v1, TweenInfo.new(p1.Speed, Enum.EasingStyle.Cubic), {
		Position = p1.End,
	}):Play()
	f4()
	task.wait(p1.Speed)
end

local function f6() --[[ Line: 67 | Upvalues: sprite (copy), TweenService (copy) ]]
	if not sprite:FindFirstChild("animationIndex") then
		TweenService:Create(sprite, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			ImageColor3 = Color3.fromRGB(190, 190, 190),
		}):Play()

		return
	end

	sprite:WaitForChild("animationIndex").Value = 0
	TweenService:Create(sprite, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		ImageColor3 = Color3.fromRGB(190, 190, 190),
	}):Play()
end

ClientEvent.OnClientEvent:Connect(
	function(p1, p2) --[[ Line: 74 | Upvalues: f5 (copy), sprite (copy), f3 (copy), f6 (copy) ]]
		if p1 == "TweenBaby" then
			f5(p2)

			return
		end

		if p1 == "FrameReset" then
			if sprite:FindFirstChild("animationIndex") then
				sprite:WaitForChild("animationIndex").Value = 0
			end
		else
			if p1 == "Wobble" then
				f3(true)

				return
			end

			if p1 ~= "Darken" then
				return
			end

			f6(true)
		end
	end
)

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Kolona.Kolona_AI
-- Took 0.85s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local CurseHandler = require(game.ReplicatedFirst.ClientModules.CurseHandler)
local StatusEffectHandler = require(game.ReplicatedFirst.ClientModules.StatusEffectHandler)
local InventoryHandler = require(game.ReplicatedFirst.ClientModules.Core.PlayerData.InventoryHandler)
local SettingsHandler = require(game.ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local LocalPlayer = game.Players.LocalPlayer
local Main = LocalPlayer.PlayerGui.Kolona.Main
local Character = LocalPlayer.Character
local v1 = 0
local v2 = 0
local v3 = false
local v4 = false
local v5 = false
local v6 = false
local v7 = false
local v8 = false
local v9 = false
local v10 = false
local isValue = game.ReplicatedStorage.Difficulty.Value == 3
local v11 = if isValue then 40 else 60
local v12 = if isValue then 20 else 30
local v13 = false

Main:WaitForChild("Kolona")
Main:WaitForChild("Background")
Main:WaitForChild("Pillar")
Main:WaitForChild("Text")

local function f14() --[[ Line: 61 | Upvalues: v13 (ref), Character (ref), Main (ref) ]]
	v13 = Character:GetAttribute("Flesh")

	if v13 then
		Main.FleshBackground.ImageTransparency = Main.Background.ImageTransparency
	else
		Main.FleshBackground.ImageTransparency = 0.999
	end
end

local function f15() --[[ Line: 80 | Upvalues: v8 (ref), Character (ref), LocalPlayer (copy), v7 (ref), v9 (ref) ]]
	if not v8 then
		return
	end

	Character = LocalPlayer.Character

	if Character == nil then
		return
	end

	local v1 = Character.Humanoid:GetAttribute("UsingAbility")

	if v7 then
		v1 = not v1
	end

	if not v1 then
		return
	end

	print("ok .")
	v9 = true
end

local Number = Main:WaitForChild("Number")

LocalPlayer.CharacterAdded:Connect(
	function() --[[ Line: 98 | Upvalues: Main (ref), LocalPlayer (copy), Character (ref), Number (ref), v10 (ref), f14 (copy), f15 (copy) ]]
		Main = LocalPlayer.PlayerGui:WaitForChild("Kolona"):WaitForChild("Main")
		Character = LocalPlayer.Character
		Main:WaitForChild("Kolona")
		Main:WaitForChild("Background")
		Main:WaitForChild("Pillar")
		Number = Main:WaitForChild("Number")
		v10 = false
		Character:GetAttributeChangedSignal("Flesh"):Connect(f14)
		Character:GetAttributeChangedSignal("UsingAbility"):Connect(f15)
	end
)
function centered() --[[ centered | Line: 111 | Upvalues: SettingsHandler (copy) ]]
	return SettingsHandler.Get({ "Misc", "CenteredEnemies" })
end
Character:GetAttributeChangedSignal("Flesh"):Connect(f14)
Character:GetAttributeChangedSignal("UsingAbility"):Connect(f15)

local function f16(p1) --[[ Line: 129 | Upvalues: v7 (ref), CurseHandler (copy), Main (ref) ]]
	v7 = false

	if CurseHandler.IsCurseEnabled("Idiotware") then
		v7 = math.random(0, 1) == 0
	end

	if p1 then
		v7 = p1
	end

	if v7 then
		Main.Background.ImageColor3 = Color3.new(0 / 255, 0 / 255, 0 / 255)
	else
		Main.Background.ImageColor3 = Color3.new(255 / 255, 255 / 255, 255 / 255)
	end
end

local v17 = false

local function f18() --[[ Line: 150 | Upvalues: LocalPlayer (copy), v17 (ref), Main (ref) ]]
	local Dead = LocalPlayer.Dead.Value

	if not Dead then
		Dead = not (LocalPlayer.Character and LocalPlayer.Character.Parent)
	end

	if not Dead then
		v17 = false

		return Dead
	end

	if v17 then
		return Dead
	end

	v17 = true
	shared.KolonaActive = false
	Main.Parent.Enabled = false

	for v2, v3 in Main:GetChildren() do
		if v3:IsA("Sound") then
			v3.Volume = 0
		end
	end

	return Dead
end

local function kill() --[[ kill | Line: 172 | Upvalues: Main (ref), v4 (ref), v5 (ref), v6 (ref) ]]
	Main.Background.ImageColor3 = Color3.new(255 / 255, 0 / 255, 0 / 255)
	Main.killed:Play()
	v4 = game.ReplicatedStorage.Events.DiedFunc:InvokeServer("Kolona", nil, game.ReplicatedStorage.Level.Value)
	v5 = false
	v6 = false

	if v4 then
		return
	end

	Main.Background.ImageColor3 = Color3.new(255 / 255, 255 / 255, 255 / 255)

	if Main:FindFirstChild("dead") then
		Main.dead:Stop()
	end

	Main.rotateSound:Stop()
	Main.Background.ImageTransparency = 0.999
	Main.FleshBackground.ImageTransparency = 0.999
	Main.Pillar.ImageTransparency = 0.999
	Main.Kolona.ImageTransparency = 0.999
	Main.Eyes.ImageTransparency = 0.999
end

local function updateSprites() --[[ updateSprites | Line: 196 | Upvalues: v1 (ref), Main (ref), v2 (ref), v3 (ref) ]]
	local v32 = math.floor(v1 / 3)

	if not Main:FindFirstChild("Kolona") then
		return
	end

	if not Main:FindFirstChild("Text") then
		return
	end

	Main.Kolona.ImageRectOffset = Vector2.new(v1 % 3, v32) * 210
	Main.Text.ImageRectOffset = Vector2.new(0, v2) * 50
	v1 = v1 + 1
	v2 = v2 + 1

	if v1 > 5 then
		v1 = 1
	end

	if v2 > 2 then
		v2 = 0
	end

	if not v3 then
		Main.Text.Size = UDim2.fromScale(1.2, 0.186)
		Main.Text.Position = UDim2.fromScale(0.5, 1)

		return
	end

	if Main.Text.Size.Y.Scale < 0.186 then
		print("hide button")
		Main.Text.ImageTransparency = 0.999
		Main.Text.Position = UDim2.fromScale(0.5, 1)
		v3 = false
	else
		Main.Text.Size = UDim2.fromScale(1.2, 0.07)
		Main.Text.Position = UDim2.fromScale(0.5, 1.07)
	end
end

task.spawn(function() --[[ Line: 234 | Upvalues: f18 (copy), updateSprites (copy) ]]
	while task.wait(0.08333333333333333) do
		if f18() then
			continue
		end

		updateSprites()
	end
end)

if not game:GetService("RunService"):IsStudio() then
	task.wait(math.random(v12 / 1.5, v12))
end

while true do
	v9 = false
	v8 = false
	v3 = false
	v5 = false
	v6 = false
	shared.KolonaActive = false
	shared.KolonaWishSpawn = false

	if
		Main:FindFirstChild("dead")
		and (Main.dead.IsPlaying and (Main.dead.PlaybackSpeed == 0.5 and not Main:GetAttribute("WaitDontActually")))
	then
		Main.dead:Stop()
	end

	if not v4 then
		if f18() then
			task.wait()

			continue
		end

		if Main and Main.Parent then
			if shared.KolonaWishSpawn or shared.OperatorWishSpawn then
				repeat
					task.wait()
				until not (shared.KolonaWishSpawn or shared.OperatorWishSpawn)
			end

			shared.KolonaWishSpawn = true

			if not isValue and _G.VoidbreakerActive == true then
				repeat
					task.wait(0.5)
				until f18() or not _G.VoidbreakerActive

				task.wait(4)
			end

			if shared.OperatorActive then
				repeat
					task.wait()
				until f18() or not shared.OperatorActive

				task.wait(4)
			end

			if Character:GetAttribute("Flesh") then
				repeat
					task.wait()
				until f18() or not Character:GetAttribute("Flesh")
			end

			if not f18() then
				if InventoryHandler.GetEquipped("Class") == "class/Wicked" then
					task.wait()
				else
					if StatusEffectHandler.HasStatus("Medal") then
						task.wait()

						continue
					end

					shared.KolonaWishSpawn = false
					shared.KolonaActive = true
					Main.Parent.Enabled = true
					f16(false)

					if CurseHandler.IsCurseEnabled("BurningBoquet") then
						local Razorbloom = Character:FindFirstChild("Razorbloom")

						if Razorbloom then
							Razorbloom.ClientEvent:FireServer("ForceStart")
						end
					end

					local v19 = math.random(5, 15)

					if game.ReplicatedStorage.Difficulty.Value == 1 then
						v19 = math.random(8, 10)
					end

					Number.Text = v19
					Number.TextTransparency = 1
					Number.UIStroke.Transparency = 1
					Main.Background.ImageTransparency = 0.999
					Main.Pillar.ImageTransparency = 0.999
					Main.Kolona.ImageTransparency = 0.999
					Main.Text.ImageTransparency = 0.999
					Main.Background.Rotation = 179
					Main.Pillar.Rotation = -179
					Number.Rotation = -179
					Main.Size = UDim2.fromScale(0.23, 0.23)
					Number.Visible = true
					Main.Position = UDim2.fromScale(0.5, 0.5)

					if v13 then
						Main.FleshBackground.ImageTransparency = 0
					end

					local v21 = 0
					local v22 = 0

					if SettingsHandler.Get({ "Misc", "CenteredEnemies" }) then
						Main.Position = UDim2.fromScale(0.3, 0.55)
						Main.Parent.CenteredMain.Position = UDim2.fromScale(0.5, 0.55)
						Number.Parent = Main.Parent.CenteredMain
						v21 = 0.25
						v22 = 0.0625
					else
						Main.Position = UDim2.fromScale(0.16, 0.55)
						Number.Position = UDim2.fromScale(0.5, 0.5)
					end

					game.TweenService
						:Create(Main.Background, TweenInfo.new(0.3), {
							ImageTransparency = v21,
						})
						:Play()
					game.TweenService
						:Create(Main.Pillar, TweenInfo.new(0.3), {
							ImageTransparency = v21,
						})
						:Play()
					game.TweenService
						:Create(Number, TweenInfo.new(0.3), {
							TextTransparency = v22,
						})
						:Play()
					game.TweenService
						:Create(Number.UIStroke, TweenInfo.new(0.3), {
							Transparency = v22,
						})
						:Play()
					game.TweenService
						:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = UDim2.fromScale(0.3, 0.3),
						})
						:Play()
					game.TweenService
						:Create(
							Main.Parent.CenteredMain,
							TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{
								Size = UDim2.fromScale(0.3, 0.3),
							}
						)
						:Play()
					game.TweenService
						:Create(Main.Background, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
							Rotation = 0,
						})
						:Play()
					game.TweenService
						:Create(Main.Pillar, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
							Rotation = 0,
						})
						:Play()
					game.TweenService
						:Create(Number, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
							Rotation = 0,
						})
						:Play()
					task.wait(0.3)

					if not f18() then
						game.TweenService
							:Create(Main, TweenInfo.new(0.05), {
								Rotation = -math.random(300, 400) / 100,
							})
							:Play()

						if centered() then
							game.TweenService
								:Create(Main.Parent.CenteredMain, TweenInfo.new(0.05), {
									Rotation = -math.random(300, 400) / 100,
								})
								:Play()
						end

						task.delay(0.05, function() --[[ Line: 444 | Upvalues: Main (ref) ]]
							if not (Main and Main.Parent) then
								return
							end

							game.TweenService
								:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), {
									Rotation = 0,
								})
								:Play()

							if not centered() then
								return
							end

							game.TweenService
								:Create(Main.Parent.CenteredMain, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), {
									Rotation = 0,
								})
								:Play()
						end)
						Main.spawn:Play()
						Main.Text.Size = UDim2.fromScale(1.2, 0.12)
						Main.Text.ImageTransparency = v21
						Main.Kolona.ImageTransparency = v21
						task.wait(2.5)

						if not f18() then
							v3 = true
							task.wait(0.5)

							local v23 = true

							if not f18() then
								v9 = false
								Number.Parent = Main

								local v24 = false
								local v25 = 8
								local v26 = 0

								task.spawn(
									function() --[[ Line: 564 | Upvalues: v23 (ref), v5 (ref), v6 (ref), v25 (ref), v24 (ref), v26 (ref), Main (ref) ]]
										while v23 or v5 do
											local v1 = task.wait()

											if v6 then
												v25 = v25 + 6000 * v1
											end

											if v24 then
												continue
											end

											v26 = v26 - v25 * v1

											local Background = Main.Background

											Background.Rotation = Background.Rotation - v25 * v1

											if not v5 then
												continue
											end

											local Pillar = Main.Pillar

											Pillar.Rotation = Pillar.Rotation + v25 * v1
										end
									end
								)

								for i = 1, v19 do
									if not f18() then
										v24 = true

										if i == v19 then
											print("enable check window")
											v8 = true
										end

										Main.rotateSound:Play()
										Main.rotateSound.TimePosition = 0.15
										Main.tick:FindFirstChild(i):Play()
										game.TweenService
											:Create(
												Main.Pillar,
												TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
												{
													Rotation = i * 22.5,
												}
											)
											:Play()
										game.TweenService
											:Create(
												Main.Background,
												TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
												{
													Rotation = -i * 90 + v26,
												}
											)
											:Play()
										task.wait(0.3)
										v24 = false
										Main.rotateSound:Stop()
										game.TweenService
											:Create(Main, TweenInfo.new(0.05), {
												Rotation = math.random(200, 300) / 100,
											})
											:Play()

										if centered() then
											game.TweenService
												:Create(Main.Parent.CenteredMain, TweenInfo.new(0.05), {
													Rotation = math.random(200, 300) / 100,
												})
												:Play()
										end

										task.delay(0.05, function() --[[ Line: 629 | Upvalues: Main (ref) ]]
											if not (Main and Main.Parent) then
												return
											end

											game.TweenService
												:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), {
													Rotation = 0,
												})
												:Play()

											if not centered() then
												return
											end

											game.TweenService
												:Create(
													Main.Parent.CenteredMain,
													TweenInfo.new(0.35, Enum.EasingStyle.Elastic),
													{
														Rotation = 0,
													}
												)
												:Play()
										end)

										if CurseHandler.IsCurseEnabled("LostEmbers") then
											Number.Text = "?"
										else
											Number.Text = i
										end

										if i == v19 - 2 and CurseHandler.IsCurseEnabled("Idiotware") then
											f16()

											if v7 ~= v7 then
												task.spawn(function() --[[ Line: 663 | Upvalues: Main (ref) ]]
													for i = 1, 5 do
														Main.ticktick:Play()
														task.wait(0.1)
													end
												end)
											end
										end

										if i == v19 then
											if StatusEffectHandler.HasStatus("Medal") then
												task.wait(0.1)

												continue
											end

											task.spawn(
												function() --[[ Line: 684 | Upvalues: v8 (ref), Character (ref), LocalPlayer (copy), v7 (ref), v9 (ref), f18 (copy) ]]
													repeat
														if v8 then
															Character = LocalPlayer.Character

															if Character ~= nil then
																local v1 =
																	Character.Humanoid:GetAttribute("UsingAbility")

																if v7 then
																	v1 = not v1
																end

																if v1 then
																	print("ok .")
																	v9 = true
																end
															end
														end

														task.wait()
													until v8 == false or (v9 or f18())
												end
											)
											task.wait(0.3)
										elseif StatusEffectHandler.HasStatus("Medal") then
											task.wait(0.04)
										else
											task.wait(math.random(50, 90) / 100)
										end

										if not f18() then
											repeat
												task.wait()
											until not Character:GetAttribute("Flesh")
										end
									end
								end

								if not f18() then
									repeat
										task.wait()
									until not Character:GetAttribute("Flesh")

									Number.Visible = false
									v6 = true
									v5 = true
									Main.deathSpin:Play()
									Main.rotateSound:Play()
									Main.Eyes.ImageRectOffset = Vector2.zero
									Main.Eyes.ImageTransparency = 0
									task.spawn(function() --[[ Line: 737 | Upvalues: Main (ref) ]]
										for i = 0, 5 do
											Main.Eyes.ImageRectOffset = Vector2.new(i % 3, (math.floor(i / 3))) * 256
											task.wait(0.041666666666666664)
										end
									end)
									task.wait(0.4)
									v6 = false
									v8 = false

									if not f18() then
										if StatusEffectHandler.HasStatus("Medal") then
											v9 = true
										end

										if v9 then
											Main.deathSpin:Stop()
											Main.rotateSound:Stop()
											Main.Background.ImageTransparency = 0.999
											Main.FleshBackground.ImageTransparency = 0.999
											Main.Pillar.ImageTransparency = 0.999
											Main.Kolona.ImageTransparency = 0.999
											Main.Eyes.ImageTransparency = 0.999
										else
											kill()
										end

										shared.KolonaActive = false
										v9 = false

										local count = 0

										for v27, v28 in workspace.Enemies:GetChildren() do
											if v28.Name == "Kolona" then
												count = count + 1
											end
										end

										if count == 0 then
											warn("something has gone Very wrong with kolona LOL")
											count = 1
										end

										task.wait(math.random(v11 / 1.5, v11) / count)
									end
								end
							end
						end
					end

					continue
				end
			end

			continue
		end

		if not v10 then
			v10 = true
		end
	end

	task.wait()
end

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Oblivion.Oblivion_ClientAI
-- Took 0.76s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
require(game.ReplicatedFirst.ClientModules.StatusEffectHandler)

local GreaterCurseHandler = require(game.ReplicatedFirst.ClientModules.GreaterCurseHandler)
local v1 = script.Parent
local LocalPlayer = game.Players.LocalPlayer
local Character = LocalPlayer.Character
local v2 = false
local v3 = false

tick()

local isValue = game.ReplicatedStorage.Difficulty.Value == 3
local v4 = game.ReplicatedStorage:FindFirstChild("OblivionAttack"):Clone()
local v5 = game.ReplicatedStorage:FindFirstChild("OblivionAmbient"):Clone()

v4.Parent = workspace.CurrentCamera
v5.Parent = workspace.CurrentCamera

local Rotation = v4.Rotation
local OblivionShake = Character:WaitForChild("Boioing"):WaitForChild("OblivionShake")
local v6 = game.TweenService:Create(
	game.Lighting.Oblivion,
	TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	{
		Brightness = 0.26,
		Contrast = 0.65,
		TintColor = Color3.fromRGB(223, 167, 167),
	}
)
local v7 = game.TweenService:Create(
	game.Lighting.Oblivion,
	TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	{
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
		TintColor = Color3.fromRGB(255, 255, 255),
	}
)
local v8 =
	game.TweenService:Create(game.Lighting.Oblivion, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		Brightness = 2,
		Contrast = 3,
		Saturation = 2,
	})
local v9 =
	game.TweenService:Create(game.Lighting.Oblivion, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		Brightness = 2,
		Contrast = 2.5,
		Saturation = 1,
	})
local v10 = game.TweenService:Create(OblivionShake, TweenInfo.new(13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	Value = 0.02,
})
local v11 = game.TweenService:Create(OblivionShake, TweenInfo.new(1), {
	Value = 0,
})

LocalPlayer.CharacterAdded:Connect(
	function() --[[ Line: 56 | Upvalues: Character (ref), LocalPlayer (copy), v4 (ref), v5 (ref), OblivionShake (ref), v10 (ref), v11 (ref) ]]
		Character = LocalPlayer.Character

		if v4 then
			v4:Destroy()
			v4 = nil
		end

		if v5 then
			v5:Destroy()
			v5 = nil
		end

		v4 = game.ReplicatedStorage:FindFirstChild("OblivionAttack"):Clone()
		v5 = game.ReplicatedStorage:FindFirstChild("OblivionAmbient"):Clone()
		v4.Parent = workspace.CurrentCamera
		v5.Parent = workspace.CurrentCamera
		OblivionShake = Character:WaitForChild("Boioing"):WaitForChild("OblivionShake")
		v10 =
			game.TweenService:Create(OblivionShake, TweenInfo.new(13, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Value = 0.02,
			})
		v11 = game.TweenService:Create(OblivionShake, TweenInfo.new(1), {
			Value = 0,
		})
	end
)

local function kill() --[[ kill | Line: 100 | Upvalues: v1 (copy), v3 (ref) ]]
	v1.Sounds.Layer1:Stop()
	v1.Sounds.Layer2:Stop()
	v1.Sounds.Kill:Play()
	v3 = game.ReplicatedStorage.Events.DiedFunc:InvokeServer("Oblivion", nil, game.ReplicatedStorage.Level.Value)
end

LocalPlayer.Dead.Changed:Connect(
	function() --[[ Line: 114 | Upvalues: v7 (copy), v4 (ref), v5 (ref), v1 (copy), LocalPlayer (copy) ]]
		v7:Play()

		if v4 then
			v4:Destroy()
			v4 = nil
		end

		if v5 then
			v5:Destroy()
			v5 = nil
		end

		v1.Sounds.Layer1:Stop()
		v1.Sounds.Layer2:Stop()

		if not LocalPlayer.PlayerGui:FindFirstChild("OblivionBar") then
			return
		end

		LocalPlayer.PlayerGui.OblivionBar:Destroy()
	end
)
game["Run Service"].RenderStepped:Connect(
	function() --[[ Line: 136 | Upvalues: v4 (ref), v5 (ref), LocalPlayer (copy) ]]
		if not (v4 and (v5 and (LocalPlayer.Character and LocalPlayer.Character.Parent))) then
			return
		end

		local HumanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

		if not HumanoidRootPart then
			return
		end

		v4.Position = HumanoidRootPart.Position + Vector3.new(0, -30, 0)
		v5.Position = HumanoidRootPart.Position + Vector3.new(0, -40, 0)
	end
)

local v12 = if game.ReplicatedStorage.Difficulty.Value == 3 then 3.5 else 2.5

v1.OblivionEvent.OnClientEvent:Connect(
	function() --[[ Line: 148 | Upvalues: v3 (ref), LocalPlayer (copy), GreaterCurseHandler (copy), v4 (ref), v5 (ref), v6 (copy), v2 (ref), v1 (copy), v7 (copy), Character (ref), v12 (copy), OblivionShake (ref), v11 (ref), v8 (copy), kill (copy), v9 (copy) ]]
		if v3 then
			return
		end

		if
			LocalPlayer.Dead.Value
			or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
		then
			return
		end

		local v22 = GreaterCurseHandler.IsCurseEnabled("RealisticOblivion")

		if v4 then
			for v32, v42 in v4:GetChildren() do
				if v42:IsA("ParticleEmitter") then
					v42.Enabled = true

					local Rate = v42.Rate

					v42.Rate = v42.Rate / 10

					if v42.Name == "Short" or v42.Name == "Long" then
						v42.Rate = 5
					end

					game.TweenService
						:Create(v42, TweenInfo.new(5, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
							Rate = Rate,
						})
						:Play()
				end
			end
		end

		if v5 then
			for v52, v62 in v5:GetChildren() do
				if v62:IsA("ParticleEmitter") then
					v62.Enabled = true
				end
			end
		end

		v6:Play()
		v2 = true

		local v72 = tick()
		local OblivionBar = game.ReplicatedStorage.Movement.Instances.BarUI:Clone()

		OblivionBar.Frame.Size = UDim2.fromScale(0, 0.5)
		OblivionBar.Frame.Position = UDim2.fromScale(0.05, 0.5)
		OblivionBar.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		OblivionBar.Frame.Bar.Size = UDim2.fromScale(1, 0)
		OblivionBar.Frame.Outline.Size = UDim2.fromScale(1, 1)
		OblivionBar.Frame.Bar.BackgroundColor3 = Color3.fromRGB(151, 130, 235)
		OblivionBar.Frame.Outline.UIStroke.Color = OblivionBar.Frame.Bar.BackgroundColor3
		OblivionBar.Frame.Outline.UIStroke.Transparency = 0.65
		OblivionBar.Name = "OblivionBar"
		OblivionBar.Parent = LocalPlayer.PlayerGui
		game.TweenService
			:Create(OblivionBar.Frame, TweenInfo.new(1), {
				Size = UDim2.fromScale(0.01, 0.5),
			})
			:Play()
		game.TweenService
			:Create(OblivionBar.Frame.Outline, TweenInfo.new(1), {
				Size = UDim2.new(1, 6, 1, 6),
			})
			:Play()
		v1.Sounds.Layer1.Volume = 0.4
		v1.Sounds.Layer2.Volume = 0
		v1.Sounds.Layer1:Play()
		v1.Sounds.Layer2:Play()

		local v82 = time()

		while true do
			task.wait()

			if
				LocalPlayer.Dead.Value
				or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
			then
				v6:Pause()
				v7:Play()
				v1.Sounds.Layer1:Stop()
				v1.Sounds.Layer2:Stop()

				if v4 then
					v4:Destroy()
					v4 = nil
				end

				if not v5 then
					OblivionBar:Destroy()

					return
				end

				v5:Destroy()
				v5 = nil
				OblivionBar:Destroy()

				return
			elseif time() - v82 > 1 then
				local v10 = tick()

				while task.wait() do
					if
						LocalPlayer.Dead.Value
						or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
					then
						break
					end

					local _ = tick() - v72
					local v122 = tick()

					if tick() - v10 > 6 then
						v72 = v122

						break
					end

					if Character:FindFirstChild("HumanoidRootPart") then
						local v132 = RaycastParams.new()

						v132.FilterDescendantsInstances =
							{ workspace.CurrentRooms, workspace.Spawn, workspace.JumpPads }
						v132.FilterType = Enum.RaycastFilterType.Include
						v132.CollisionGroup = "Player"

						if workspace:Raycast(Character.HumanoidRootPart.Position, Vector3.new(-0, -1024, -0), v132) then
							v72 = v122

							for v14, v15 in v4:GetChildren() do
								if v15:IsA("ParticleEmitter") and v15.Enabled then
									v15.Enabled = false
								end
							end

							continue
						end

						v72 = v122

						for v16, v17 in v4:GetChildren() do
							if v17:IsA("ParticleEmitter") and not v17.Enabled then
								v17.Enabled = true
							end
						end

						continue
					end

					v72 = v122
				end

				if
					LocalPlayer.Dead.Value
					or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
				then
					v7:Play()
					v1.Sounds.Layer1:Stop()
					v1.Sounds.Layer2:Stop()

					if v4 then
						v4:Destroy()
						v4 = nil
					end

					if not v5 then
						OblivionBar:Destroy()

						return
					end

					v5:Destroy()
					v5 = nil
					OblivionBar:Destroy()
				else
					game.TweenService
						:Create(OblivionBar.Frame.Outline.UIStroke, TweenInfo.new(0.5), {
							Transparency = 0.4,
						})
						:Play()

					local v19 = tick()

					v1.Sounds.Warning:Play()
					game.TweenService
						:Create(v1.Sounds.Layer1, TweenInfo.new(0.5), {
							Volume = 0.75,
						})
						:Play()

					local v20 = true
					local v21 = 0

					while task.wait() do
						local v222

						if
							LocalPlayer.Dead.Value
							or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
						then
							OblivionBar:Destroy()

							break
						end

						local v24 = tick() - v72
						local v25 = tick()

						if tick() - v19 >= 20 then
							break
						end

						if v21 == 1 then
							v20 = false

							break
						elseif Character:FindFirstChild("HumanoidRootPart") then
							local v26 = RaycastParams.new()

							v26.FilterDescendantsInstances =
								{ workspace.CurrentRooms, workspace.Spawn, workspace.JumpPads }
							v26.FilterType = Enum.RaycastFilterType.Include
							v26.CollisionGroup = "Player"

							if
								workspace:Raycast(
									Character.HumanoidRootPart.Position,
									Vector3.new(0, 1, 0) * (if v22 then 1024 else -1024),
									v26
								)
							then
								v222 = v21 - v24 / v12

								local Layer2 = v1.Sounds.Layer2

								Layer2.Volume = Layer2.Volume - v24 * 6
								v1.Sounds.Layer1.Volume = 0.5
								v72 = v25

								for v28, v29 in v4:GetChildren() do
									if v29:IsA("ParticleEmitter") and v29.Enabled then
										v29.Enabled = false
									end
								end
							else
								local Layer2 = v1.Sounds.Layer2

								Layer2.Volume = Layer2.Volume + v24 * 6
								v1.Sounds.Layer1.Volume = 0.75
								v222 = v21 + v24 / 2.5
								v72 = v25

								for v30, v31 in v4:GetChildren() do
									if v31:IsA("ParticleEmitter") and not v31.Enabled then
										v31.Enabled = true
									end
								end
							end

							v1.Sounds.Layer2.Volume =
								math.clamp(v1.Sounds.Layer2.Volume, math.clamp(tick() - v19, 0, 0.05), 0.75)
							OblivionShake.Value = v222 * 0.02

							local v34 = math.clamp(v222, 0, 1)

							if OblivionBar and OblivionBar.Parent then
								OblivionBar.Frame.Bar.Size = UDim2.fromScale(1, v34)
							end

							v21 = v34
							v1.Sounds.Warning.Volume = v34 ^ 0.5 * 2
							v1.Sounds.Warning.PlaybackSpeed = v34 ^ 4 * 0.5 + 1
						else
							v72 = v25
						end
					end

					if
						LocalPlayer.Dead.Value
						or (if LocalPlayer.Character == nil then true else LocalPlayer.Character.Parent == nil)
					then
						if OblivionBar and OblivionBar.Parent then
							OblivionBar:Destroy()
						end

						v1.Sounds.Layer1:Stop()
						v1.Sounds.Layer2:Stop()
						v1.Sounds.Warning:Stop()
						v7:Play()
						v11:Play()

						if v4 then
							v4:Destroy()
							v4 = nil
						end

						if not v5 then
							return
						end

						v5:Destroy()
						v5 = nil
					else
						v11:Play()
						v1.Sounds.Layer1:Stop()
						v1.Sounds.Layer2:Stop()
						v1.Sounds.Warning:Stop()

						if OblivionBar and OblivionBar.Parent then
							game.TweenService
								:Create(OblivionBar.Frame, TweenInfo.new(0.5), {
									Size = UDim2.fromScale(0, 0.5),
								})
								:Play()
							game.TweenService
								:Create(OblivionBar.Frame.Outline, TweenInfo.new(0.5), {
									Size = UDim2.new(1, 0, 1, 0),
								})
								:Play()
						end

						task.delay(0.5, function() --[[ Line: 391 | Upvalues: OblivionBar (copy) ]]
							if not (OblivionBar and OblivionBar.Parent) then
								return
							end

							OblivionBar:Destroy()
						end)

						if v20 then
							v9:Play()
							v1.OblivionEvent:FireServer()
							v1.Sounds.Survived:Play()
						else
							v8:Play()
							kill()
						end

						for v36, v37 in v4:GetChildren() do
							if v37:IsA("ParticleEmitter") then
								v37.Enabled = false
							end
						end

						for v38, v39 in v5:GetChildren() do
							if v39:IsA("ParticleEmitter") then
								v39.Enabled = false
							end
						end

						v7:Play()
					end
				end

				return
			end
		end
	end
)
-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Quartz.Quartz_ClientAI
-- Took 0.88s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Debris = game:GetService("Debris")
local HitboxHelper = require(script:WaitForChild("HitboxHelper"))

require(ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)

local CurseHandler = require(ReplicatedFirst.ClientModules.CurseHandler)
local SpacialOperationHelper = require(ReplicatedStorage.Module.SpacialOperationHelper)
local t = {}
local v1 = script.Parent

v1.head.sprite:WaitForChild("spritesheet")
game:GetService("ServerScriptService")

local sigil = game:GetService("ReplicatedStorage"):WaitForChild("spritesheets"):WaitForChild("sigil")
local sigilAlternatePrismatic = sigil.sigilAlternatePrismatic
local sigilAlternatePrismatic2 = sigil.sigilAlternatePrismatic

v1:WaitForChild("ClientEvent")

local AnotherPoolManager = require(script.AnotherPoolManager)

AnotherPoolManager.CreatePool("SigilFire", v1.FireArea, v1, 40)

local Difficulty = game.ReplicatedStorage.Difficulty.Value
local v2 = nil
local v3 = RaycastParams.new()

v3.FilterType = Enum.RaycastFilterType.Include
v3.CollisionGroup = "Default"
v3.RespectCanCollide = true

local v4 = Color3.new(255 / 255, 255 / 255, 255 / 255)

task.spawn(function() --[[ Line: 40 | Upvalues: v4 (ref) ]]
	while script.Parent do
		v4 = Color3.fromHSV(tick() * 2 % 1, 0.5, 1)
		task.wait()
	end
end)

local function Lerp(p1, p2, p3) --[[ Lerp | Line: 47 ]]
	return p1 + (p2 - p1) * p3
end

local t2 = {}
local v5 = false
local v6 = false

function ApplyTransparency(p1) --[[ ApplyTransparency | Line: 54 | Upvalues: v5 (ref) ]]
	if v5 == true then
		p1.LocalTransparencyModifier = 0.8
	else
		p1.LocalTransparencyModifier = 0
	end
end
function AddTransparency(p1) --[[ AddTransparency | Line: 61 | Upvalues: t2 (copy) ]]
	t2[p1] = true
	ApplyTransparency(p1)

	for k, v in pairs(p1:QueryDescendants("ParticleEmitter,Beam")) do
		t2[v] = true
		ApplyTransparency(v)
	end
end
function AddTransparencyObjects(p1) --[[ AddTransparencyObjects | Line: 70 ]]
	if typeof(p1) ~= "table" then
		AddTransparency(p1)

		return
	end

	for k, v in pairs(p1) do
		AddTransparency(v)
	end
end

local v7 = nil

AddTransparencyObjects(v1)

local ReplicatedStorage2 = game:GetService("ReplicatedStorage")

function PlaceFire(p1) --[[ PlaceFire | Line: 155 | Upvalues: CurseHandler (copy), AnotherPoolManager (copy), v1 (copy), TweenService (copy) ]]
	local v12 = if CurseHandler.IsCurseEnabled("Leo") then 6 else 3
	local v2 = AnotherPoolManager.GetItemFromPool("SigilFire")
	local v3 = false
	local v4 = v2.Touched:Connect(function(p1) --[[ Line: 165 | Upvalues: v3 (ref), v1 (ref) ]]
		if v3 then
			return
		end

		local v12 = game.Players:GetPlayerFromCharacter(p1.Parent)

		if v12 ~= game.Players.LocalPlayer then
			return
		end

		local Character = v12.Character
		local v2 = Character.Humanoid:GetAttribute("UsingAbility")

		if v2 and Character:GetAttribute("Class") == "class/Spirit" then
			return
		end

		v3 = true
		v1.ClientEvent:FireServer("Combust")
		task.wait(1)
		v3 = false
	end)

	v2.CanTouch = true
	v2.Smoke.Enabled = true
	v2.Sparkles.Enabled = true
	v2.Size = Vector3.new(0, 5.25, 0)
	v2.Position = p1 - Vector3.new(0, 3, 0) - Vector3.new(0, v2.Size.Y / 2, 0)
	v2.Decal.Transparency = 0.3
	TweenService:Create(v2, TweenInfo.new(0.75, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Size = Vector3.new(v12, 7.5, v12),
	}):Play()
	task.delay(
		12,
		function() --[[ Line: 197 | Upvalues: v2 (copy), v4 (copy), TweenService (ref), AnotherPoolManager (ref) ]]
			v2.Smoke.Enabled = false
			v2.Sparkles.Enabled = false
			v2.CanTouch = false
			v4:Disconnect()
			TweenService:Create(v2.Decal, TweenInfo.new(2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
			task.delay(2, function() --[[ Line: 208 | Upvalues: AnotherPoolManager (ref), v2 (ref) ]]
				AnotherPoolManager.ReturnItemToPool("SigilFire", v2)
			end)
		end
	)
end

local function LaserAura(p1) --[[ LaserAura | Line: 214 | Upvalues: v4 (ref), TweenService (copy), RunService (copy) ]]
	local v1 = p1:Clone()

	v1.CFrame = p1.CFrame
	v1.Size = p1.Size * Vector3.new(0.5, 0.5, 0.5)
	v1.Transparency = 0.35
	v1.Parent = workspace.Beacons

	local v2 = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0)

	task.spawn(function() --[[ Line: 222 | Upvalues: v1 (copy), v4 (ref) ]]
		while v1.Parent do
			v1.Color = v4
			task.wait()
		end
	end)
	TweenService:Create(v1, v2, {
		Transparency = 1,
		Size = p1.Size * Vector3.new(1.25, 1.25, 1.25),
	}):Play()
	AddTransparencyObjects(v1)

	local sum = 0

	repeat
		sum = sum + RunService.RenderStepped:Wait()
		v1.CFrame = p1.CFrame
	until sum >= 0.5

	v1:Destroy()
end

local v8 = 0

local function ChargeUp(p1) --[[ ChargeUp | Line: 247 | Upvalues: ReplicatedStorage (copy), Debris (copy), v1 (copy), v2 (ref) ]]
	local Character = p1.Character
	local v12 = ReplicatedStorage.JuneMarker:Clone()

	Debris:AddItem(v12, 5.75)

	local v22 = v1.SFX.Teleport:GetChildren()[math.random(1, 3)]:Clone()

	v22.Parent = v1
	v22:Play()
	v22.Ended:Once(function() --[[ Line: 255 | Upvalues: v22 (copy) ]]
		v22:Destroy()
	end)

	local v3 = if Character then Character:FindFirstChild("HumanoidRootPart") else Character

	if not v3 then
		return
	end

	local IndicatorWeld = v12.IndicatorWeld
	local start = v12.start
	local Particlets = v12.Particlets
	local circles = start.circles

	v12.Parent = v3
	IndicatorWeld.Part0 = v3
	IndicatorWeld.Part1 = v12
	Particlets.Enabled = true
	Particlets:Emit(math.random(3, 6))
	start.Flash.Enabled = true
	start.Flash:Emit(math.random(2, 3))
	start.ParticleEmitter.Enabled = true
	start.ParticleEmitter:Emit(1)
	start.ShineHorizontal.Enabled = true
	start.ShineHorizontal:Emit(1)
	start.ShineVertical.Enabled = true
	start.ShineVertical:Emit(1)
	circles.Enabled = true
	circles:Emit(1)
	v12.LockOn:Play()
end

local function Beam(p1, p2, p3, p4, p5, p6) --[[ Beam | Line: 279 | Upvalues: t (copy), HitboxHelper (copy), v1 (copy), v7 (ref), ReplicatedStorage2 (copy), RunService (copy), v2 (ref), v4 (ref), v8 (ref), LaserAura (copy), v3 (copy), v6 (ref), TweenService (copy), t2 (copy) ]]
	print(#t)

	if p1 ~= game.Players.LocalPlayer then
		table.insert(t, p1)
	end

	local v22 = p1 and p1.Character or p5 and nil
	local v32 = false
	local v42 = false
	local v5 = false
	local v62 = 1024

	if p1 ~= game.Players.LocalPlayer then
		v62 = v62 / 3
	end

	local v72, v82, v9, v10, v11 = HitboxHelper.CreateLaser(p2 or 7, v62 + 50)
	local Position = v1.Position

	v72.Position = Position
	v82.Position = Position
	v9.Position = Position

	if p1 ~= game.Players.LocalPlayer then
		for k, v in pairs(v10) do
			v.ParticleEmitter.Rate = 133.33333333333334
			v.ParticleEmitter2.Rate = 133.33333333333334
			v.Tears.Rate = 133.33333333333334
		end
	end

	v82.Size = Vector3.new(0, 0, 0)
	v9.Size = Vector3.new(0, 0, 0)
	v7 = v82

	local InRound = ReplicatedStorage2.InRound

	HitboxHelper.Debris(25, v72, HitboxHelper.poolPartGroup)
	HitboxHelper.Debris(25, v82, HitboxHelper.poolLaserBeamGroup)
	HitboxHelper.Debris(25, v9, HitboxHelper.poolBlastGroup)

	for k, v in pairs(v10) do
		HitboxHelper.Debris(25, v, HitboxHelper.poolPartGroup)
	end

	HitboxHelper.Debris(25, v11, HitboxHelper.poolPartGroup)
	AddTransparencyObjects({ v72, v82, v9 })

	if game.ReplicatedStorage.Difficulty.Value == 1 then
		p4 = p4 / 1.2
	end

	local sum = 0
	local v12 = if p5 then if math.random(1, 2) == 1 then -1 else 1 else nil
	local v14 = 51.2
	local sum2 = 25.6
	local count = 0
	local sum3 = 3
	local v15 = p4 or 0.75
	local sum4 = 0.2
	local v16 = v1.BeamEvent.OnClientEvent:Connect(
		function(p1) --[[ Line: 343 | Upvalues: v22 (ref), p5 (copy), v15 (ref), v1 (ref), RunService (ref), p4 (ref) ]]
			v22 = p1 and p1.Character or p5 and nil

			local HumanoidRootPart = v22:FindFirstChild("HumanoidRootPart")

			v15 = 0

			local v4 =
				math.min(
					((if HumanoidRootPart
						then HumanoidRootPart.Position or Vector3.new(0, 0, 0)
						else Vector3.new(0, 0, 0)) - v1.Position).Magnitude / 150,
					5
				)

			task.spawn(function() --[[ Line: 353 | Upvalues: RunService (ref), v4 (copy), v15 (ref), p4 (ref) ]]
				local sum = 0

				while true do
					local v1 = RunService.RenderStepped:Wait()

					v15 = 0 + ((p4 or 0.75) - 0) * math.clamp(sum / v4, 0, 1)

					if (p4 or 0.75) <= v15 then
						break
					end

					sum = sum + v1
				end
			end)
		end
	)
	local Start = Instance.new("Attachment")
	local End = Instance.new("Attachment")

	Start.Position = Vector3.new(0, 0, v72.Size.Z / 2)
	End.Position = Vector3.new(0, 0, -v72.Size.Z / 2)
	Start.Name = "Start"
	End.Name = "End"
	Start.Parent = v72
	End.Parent = v72

	local v19 = false
	local SavedQualityLevel = UserSettings().GameSettings.SavedQualityLevel.Value

	if SavedQualityLevel == 0 then
		SavedQualityLevel = 5
	end

	if SavedQualityLevel <= 4 then
		v19 = true
	end

	if v19 then
		for k, v in pairs(v10) do
			v.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
		end

		v11.Transparency = 0.75
	end

	task.spawn(function() --[[ Line: 397 | Upvalues: v2 (ref) ]]
		if v2 and v2.Parent then
			v2.Particlets.Enabled = false
			v2.start.Flash.Enabled = false
			v2.start.ParticleEmitter.Enabled = false
			v2.start.ShineHorizontal.Enabled = false
			v2.start.ShineVertical.Enabled = false
			v2.start.circles.Enabled = false
		end
	end)

	repeat
		local v21, v222, v23

		v82.Color = v4
		v9.Color = v4

		local v24 = RunService.RenderStepped:Wait()

		count = count + 1

		local v25 = v22 and v22:FindFirstChild("HumanoidRootPart") or p5 and nil

		if sum <= (p3 or 5) then
			if v25 or p5 then
				local Size = v72.Size
				local Size2 = v82.Size
				local Size3 = v9.Size
				local HumanoidRootPart = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local v26 = p5
						and CFrame.new(p5) * CFrame.fromAxisAngle(
							Vector3.new(0, 1, 0),
							v12 * 0.5 * sum * 1.5707963267948966
						)
					or CFrame.lookAt(v1.Position, v25.Position)

				if not v42 then
					v42 = true

					if not p5 then
						local v27 = v1.LaserCharge:Clone()

						v27.Parent = v25
						v27:Play()
						v27.Ended:Once(function() --[[ Line: 432 | Upvalues: v27 (copy) ]]
							v27:Destroy()
						end)
					end
				end

				local v28 = nil

				if sum <= 0.5 then
					v21 = if p5 and v26 then v26 else v72.CFrame:Lerp(v26, v24 * (v15 or 0.75) * 5)
					v28 = v21
					v72.CFrame = v21
				elseif sum >= 3 then
					v222 = if p5 and v26 then v26 else v72.CFrame:Lerp(v26, v24 * (v15 or 0.75))
					v28 = v222
					v72.CFrame = v222
					v14 = 51.2 + 460.8 * math.clamp((sum - 6) / 10, 0, 1)

					if
						tick() - v8 > 0.5
						and HumanoidRootPart
						and HitboxHelper.CheckBounds(
							HumanoidRootPart,
							v222 + v222.LookVector * Size2.Y / 2,
							(Vector3.new(Size.X - 5, Size.Y - 5, Size2.Y))
						)
					then
						v8 = tick()
						v1.ClientEvent:FireServer("Kill")
					end
				elseif sum >= 0.5 then
					v23 = if p5 and v26 then v26 else v72.CFrame:Lerp(v26, v24)
					v28 = v23
					v72.CFrame = v23
				end

				if v19 then
					v11.CFrame = (v28 + v28.LookVector * (v11.Size.X / 2)) * CFrame.Angles(0, 1.5707963267948966, 0)
				else
					for k, v in pairs(v10) do
						v.CFrame = (v28 + v28.LookVector * (v.Size.X / 2 + v.Size.X * (k - 1)))
							* CFrame.Angles(0, 1.5707963267948966, 0)
					end
				end

				v82.CFrame = (v28 + v28.LookVector * Size.Z / (Size.Z / Size2.Y) / 2)
					* CFrame.Angles(-1.5707963267948966, 0, 0)
					* CFrame.fromAxisAngle(Vector3.new(0, 1, 0), sum * 5 * 1.5707963267948966)
				v9.CFrame = (v28 + v28.LookVector * (Size.Z / (Size.Z / Size3.Z) / 2 - Size3.Z / 5))
					* CFrame.fromAxisAngle(Vector3.new(0, 0, 1), sum * 5 * 1.5707963267948966)

				if sum >= 3 then
					sum2 = sum2 + (v62 - sum2) * math.clamp(v24 * 2, 0, 1)
					End.Position =
						End.Position:Lerp(Vector3.new(0, 0, -v72.Size.Z / 2), (math.clamp((sum - 3) / 10, 0, 1)))
					v82.Size =
						v82.Size:Lerp(Vector3.new((p2 or 7) + 4, sum2, (p2 or 7) + 4), (math.clamp(v24 * 3, 0, 1)))
					v9.Size = v9.Size:Lerp(Vector3.new((p2 or 7) + 8, (p2 or 7) + 8, v14), (math.clamp(v24 * 3, 0, 1)))

					if count % 6 == 0 then
						task.spawn(LaserAura, v82)
					end

					if sum3 <= sum then
						sum3 = sum3 + 1.5
					end

					if p6 and sum4 <= 0 then
						sum4 = 0.2
						v3.FilterDescendantsInstances = { workspace.CurrentRooms }

						local v33 = Start.WorldPosition + v28.LookVector * 8
						local v34 = workspace:Raycast(v33, End.WorldPosition - v33, v3)

						if v34 and v34.Position then
							PlaceFire(v34.Position + Vector3.new(0, 3, 0))
						end
					elseif p6 then
						sum4 = sum4 - v24
					end

					if not v32 then
						v32 = true
						v6 = true
						shared.FX_Remote_Local:Fire(
							"Cast_Effects",
							"PrismaticExplosion",
							v1.Position,
							0,
							75,
							0.15,
							0.5,
							1,
							2
						)
						shared.FX_Remote_Local:Fire(
							"Cast_Effects",
							"PrismaticExplosion",
							v1.Position,
							0,
							60,
							0.5,
							0.5,
							1,
							2
						)
						shared.FX_Remote_Local:Fire("Cast_Effects", "Shake_Camera", 0.25, 2, 512, v1.Position)
						task.delay(2, function() --[[ Line: 537 | Upvalues: v6 (ref) ]]
							v6 = false
						end)
						v1.head.Brightness = 5
						TweenService
							:Create(v1.head, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Brightness = 1.1,
							})
							:Play()

						for v35, v36 in { v11, unpack(v10) } do
							if v36:FindFirstChild("ParticleEmitter") then
								v36.ParticleEmitter.Enabled = false
							end

							if v36:FindFirstChild("ParticleEmitter2") then
								v36.ParticleEmitter2.Enabled = false
							end

							if v36:FindFirstChild("Tears") then
								v36.Tears.Enabled = false
							end
						end

						if v19 then
							game:GetService("TweenService")
								:Create(v11, TweenInfo.new(1), {
									Transparency = 1,
								})
								:Play()
						end

						v1.LaserFire.TimePosition = 0

						if not p5 then
							v1.LaserFire:Play()
						end
					end
				end
			end
		else
			if not v5 then
				v5 = true
			end

			local v37 = v82.Size:Lerp(Vector3.new(0, 0, 0), (math.clamp(v24 * 10, 0, 1)))

			v82.Size = v37

			local v38 = v9.Size:Lerp(Vector3.new(0, 0, 0), (math.clamp(v24 * 10, 0, 1)))

			v9.Size = v38

			local v39 = v72.CFrame
			local Size = v72.Size

			v82.CFrame = (v39 + v39.LookVector * Size.Z / (Size.Z / v37.Y) / 2)
				* CFrame.Angles(-1.5707963267948966, 0, 0)
				* CFrame.fromAxisAngle(Vector3.new(0, 1, 0), sum * 5 * 1.5707963267948966)
			v9.CFrame = (v39 + v39.LookVector * (Size.Z / (Size.Z / v38.Z) / 2 - v38.Z / 5))
				* CFrame.fromAxisAngle(Vector3.new(0, 0, 1), sum * 5 * 1.5707963267948966)
		end

		sum = sum + v24
	until (p3 or 5) + 1 <= sum

	HitboxHelper.Destroy(v72, HitboxHelper.poolPartGroup)
	HitboxHelper.Destroy(v82, HitboxHelper.poolLaserBeamGroup)
	HitboxHelper.Destroy(v9, HitboxHelper.poolBlastGroup)

	for k, v in pairs(v10) do
		HitboxHelper.Destroy(v, HitboxHelper.poolPartGroup)
	end

	HitboxHelper.Destroy(v11, HitboxHelper.poolPartGroup)
	table.clear(t2)

	local v40 = table.find(t, p1)

	if p1 == game.Players.LocalPlayer or not v40 then
		v16:Disconnect()

		return
	end

	table.remove(t, v40)
	v16:Disconnect()
end

game:GetService("RunService").RenderStepped:Connect(
	function() --[[ Line: 602 | Upvalues: v1 (copy), v7 (ref), SpacialOperationHelper (copy), v5 (ref), t2 (copy) ]]
		local v12 = workspace.CurrentCamera.CFrame
		local v2 = false

		if
			(v12.p - v1.Position).Magnitude <= 50
			or v7
				and SpacialOperationHelper.OBBIntersectBoxes(
					CFrame.new(v12.p),
					Vector3.new(10, 10, 10),
					v7.CFrame,
					v7.Size
				)
		then
			v2 = true
		end

		if v5 == v2 then
			return
		end

		v5 = v2
		v1.head.sprite.ImageTransparency = if v2 then 0.5 else 0

		for k in pairs(t2) do
			ApplyTransparency(k)
		end
	end
)
v1.ClientEvent.OnClientEvent:Connect(
	function(p1, p2) --[[ Line: 622 | Upvalues: t (copy), CurseHandler (copy), Beam (copy), v1 (copy), ChargeUp (copy) ]]
		if p1 == "Beam" then
			if p2.Player ~= game.Players.LocalPlayer and #t > 8 then
				return
			end

			if CurseHandler.IsCurseEnabled("Celestigal") then
				Beam(
					p2.Player,
					40 + (if CurseHandler.IsCurseEnabled("Leo") then 10 else 0),
					18,
					1,
					false,
					CurseHandler.IsCurseEnabled("Aries")
				)
			else
				Beam(
					p2.Player,
					16 + (if CurseHandler.IsCurseEnabled("Leo") then 5 else 0),
					5,
					1.88,
					false,
					CurseHandler.IsCurseEnabled("Aries")
				)
			end
		elseif p1 == "BeamSweep" then
			Beam(
				nil,
				13 + (if CurseHandler.IsCurseEnabled("Leo") then 5 else 0),
				5,
				1.1,
				v1.Position,
				CurseHandler.IsCurseEnabled("Aries")
			)
		else
			if p1 ~= "ChargeUp" then
				return
			end

			ChargeUp(p2.Player)
		end
	end
)
task.spawn(function() --[[ Line: 640 | Upvalues: v6 (ref), v1 (copy) ]]
	while true do
		while true do
			local v12 = math.random(1, 8)
			local v2 = math.random(1, 8)
			local v3 = math.random(1, 8)
			local v4 = if math.random(1, 2) == 1 then v12 * -1 else v12
			local v5 = if math.random(1, 2) == 1 then v2 * -1 else v2

			if math.random(1, 2) == 1 then
				v3 = v3 * -1
			end

			if v6 then
				shared.FX_Remote_Local:Fire("Cast_Effects", "PrismaticExplosion", v1.Position, 0, 30, 0.75, 0.5, 1, 2)
				shared.FX_Remote_Local:Fire(
					"Cast_Effects",
					"PrismaticExplosionTall",
					v1.Position + Vector3.new(v4, v5, v3),
					0,
					21,
					0.5,
					0.5,
					1,
					2
				)
			end

			if v6 then
				break
			end

			task.wait(0.12)
		end

		task.wait(0.025)
	end
end)

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.ShadowBaby.ShadowBaby_ClientAI
-- Took 0.4s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local TweenService = game:GetService("TweenService")
local CurrentCamera = workspace.CurrentCamera
local v1 = Random.new()
local v2 = script.Parent
local sprite = v2:WaitForChild("head"):WaitForChild("sprite")
local ClientEvent = v2:WaitForChild("ClientEvent")
local v3 = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.3)
local v4 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3)
local SettingsHandler = require(game.ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local v5 = false

local function f6() --[[ Line: 20 | Upvalues: v2 (copy), CurrentCamera (copy), sprite (copy), v1 (copy), TweenService (copy) ]]
	if not (CurrentCamera.CFrame.LookVector:Dot(v2.CFrame.Position - CurrentCamera.CFrame.Position) < 0) then
		local v3 = v1:NextNumber(35, 45)

		sprite.Rotation = v3 * math.sign(math.random() - 0.5)
		TweenService
			:Create(
				sprite,
				TweenInfo.new(v1:NextNumber(0.4, 0.7), Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
				{
					Rotation = 0,
				}
			)
			:Play()
	end
end

local function f7(p1) --[[ Line: 33 | Upvalues: v2 (copy), SettingsHandler (copy), CurrentCamera (copy), v3 (copy), v4 (copy) ]]
	local Attachment = Instance.new("Attachment")
	local Attachment2 = Instance.new("Attachment")

	Attachment.Parent = v2.IndicatorPart
	Attachment2.Parent = v2.IndicatorPart
	Attachment.WorldPosition = p1.Start
	Attachment2.WorldPosition = p1.End

	local v1 = v2.Beam:Clone()

	v1.Transparency = NumberSequence.new(p1.Transparency)
	v1.Attachment0 = Attachment
	v1.Attachment1 = Attachment2
	v1.Parent = Attachment

	if SettingsHandler.Get({ "Graphics", "Colorblind" }) then
		v1.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
	end

	if not ((CurrentCamera.CFrame.Position - (p1.Start + p1.End) / 2).Magnitude < 512) then
		task.wait(1)
		Attachment:Destroy()
		Attachment2:Destroy()

		return
	end

	game.TweenService
		:Create(v1, v3, {
			Brightness = 0,
		})
		:Play()
	game.TweenService
		:Create(v1, v4, {
			Width0 = 0.01,
			Width1 = 0.01,
		})
		:Play()
	task.wait(1)
	Attachment:Destroy()
	Attachment2:Destroy()
end

local function f8(p1) --[[ Line: 71 | Upvalues: v5 (ref), v2 (copy), TweenService (copy), f6 (copy) ]]
	v5 = true
	v2.CFrame = CFrame.new(p1.Start)
	TweenService:Create(v2, TweenInfo.new(p1.Speed, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {
		CFrame = CFrame.new(p1.End),
	}):Play()
	task.wait(p1.Speed)
	v2.CFrame = CFrame.new(p1.End)
	v5 = false
	f6()
end

ClientEvent.OnClientEvent:Connect(function(p1, p2) --[[ Line: 88 | Upvalues: f7 (copy), f8 (copy) ]]
	if p1 == "Indicator" then
		f7(p2)

		return
	end

	if p1 ~= "TweenBaby" then
		return
	end

	f8(p2)
end)

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.ShadowBabyConcept.ShadowBabyConcept_ClientAI
-- Took 0.39s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local v1 = Random.new()
local v2 = script.Parent
local Died = ReplicatedStorage.Events.Died
local sprite = v2:WaitForChild("head"):WaitForChild("sprite")
local ClientEvent = v2:WaitForChild("ClientEvent")
local v3 = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.3)
local v4 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3)
local v5 = false

local function f6() --[[ Line: 24 | Upvalues: v2 (copy), CurrentCamera (copy), sprite (copy), v1 (copy), TweenService (copy) ]]
	if not (CurrentCamera.CFrame.LookVector:Dot(v2.CFrame.Position - CurrentCamera.CFrame.Position) < 0) then
		local v3 = v1:NextNumber(35, 45)

		sprite.Rotation = v3 * math.sign(math.random() - 0.5)
		TweenService
			:Create(
				sprite,
				TweenInfo.new(v1:NextNumber(0.4, 0.7), Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
				{
					Rotation = 0,
				}
			)
			:Play()
	end
end

local function f7(p1) --[[ Line: 37 | Upvalues: v2 (copy), CurrentCamera (copy), v3 (copy), v4 (copy) ]]
	local Attachment = Instance.new("Attachment")
	local Attachment2 = Instance.new("Attachment")

	Attachment.Parent = v2.IndicatorPart
	Attachment2.Parent = v2.IndicatorPart
	Attachment.WorldPosition = p1.Start
	Attachment2.WorldPosition = p1.End

	local v1 = v2.Beam:Clone()

	v1.Transparency = NumberSequence.new(p1.Transparency)
	v1.Attachment0 = Attachment
	v1.Attachment1 = Attachment2
	v1.Parent = Attachment

	if not ((CurrentCamera.CFrame.Position - (p1.Start + p1.End) / 2).Magnitude < 512) then
		task.wait(1)
		Attachment:Destroy()
		Attachment2:Destroy()

		return
	end

	game.TweenService
		:Create(v1, v3, {
			Brightness = 0,
		})
		:Play()
	game.TweenService
		:Create(v1, v4, {
			Width0 = 0.01,
			Width1 = 0.01,
		})
		:Play()
	task.wait(1)
	Attachment:Destroy()
	Attachment2:Destroy()
end

local function f8(p1) --[[ Line: 71 | Upvalues: v5 (ref), v2 (copy), TweenService (copy), f6 (copy) ]]
	v5 = true
	v2.CFrame = CFrame.new(p1.Start)
	TweenService:Create(v2, TweenInfo.new(p1.Speed, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {
		CFrame = CFrame.new(p1.End),
	}):Play()
	task.wait(p1.Speed)
	v2.CFrame = CFrame.new(p1.End)
	v5 = false
	f6()
end

local v9 = v2.CFrame

v2:GetPropertyChangedSignal("CFrame")
	:Connect(function() --[[ Line: 90 | Upvalues: LocalPlayer (copy), v2 (copy), v9 (ref), Died (copy) ]]
		local Character = LocalPlayer.Character
		local v1 = if Character then Character:FindFirstChild("Hitbox") else Character
		local v22 = v2.CFrame
		local Size = v2.Size

		if v1 then
			local v3 = RaycastParams.new()

			v3.FilterType = Enum.RaycastFilterType.Include
			v3.FilterDescendantsInstances = { v1 }

			local LookVector = CFrame.new(v9.p, v22.p).LookVector

			if (workspace:Spherecast(v9.p, Size.Z, LookVector * (v9.p - v22.p).Magnitude, v3) or {}).Instance then
				Died:FireServer("ShadowBaby", LookVector * 100, game.ReplicatedStorage.Level.Value)
			end
		end

		v9 = v22
	end)
ClientEvent.OnClientEvent:Connect(function(p1, p2) --[[ Line: 115 | Upvalues: f7 (copy), f8 (copy) ]]
	if p1 == "Indicator" then
		f7(p2)

		return
	end

	if p1 ~= "TweenBaby" then
		return
	end

	f8(p2)
end)

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Sigil.Sigil_ClientAI
-- Took 0.8s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Debris = game:GetService("Debris")
local HitboxHelper = require(script:WaitForChild("HitboxHelper"))
local SettingsHandler = require(ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local CurseHandler = require(ReplicatedFirst.ClientModules.CurseHandler)
local SpacialOperationHelper = require(ReplicatedStorage.Module.SpacialOperationHelper)
local v1 = script.Parent
local spritesheet = v1.head.sprite:WaitForChild("spritesheet")

game:GetService("ServerScriptService")

local sigil = game:GetService("ReplicatedStorage"):WaitForChild("spritesheets"):WaitForChild("sigil")
local sigil2 = sigil.sigil
local sigilAlternate = sigil.sigilAlternate

v1:WaitForChild("ClientEvent")

local AnotherPoolManager = require(script.AnotherPoolManager)

AnotherPoolManager.CreatePool("SigilFire", v1.FireArea, v1, 40)

local Difficulty = game.ReplicatedStorage.Difficulty.Value
local v2 = nil
local t = {}
local v3 = RaycastParams.new()

v3.FilterType = Enum.RaycastFilterType.Include
v3.CollisionGroup = "Default"
v3.RespectCanCollide = true

local function Lerp(p1, p2, p3) --[[ Lerp | Line: 35 ]]
	return p1 + (p2 - p1) * p3
end

local t2 = {}
local v4 = false
local v5 = false

function ApplyTransparency(p1, p2) --[[ ApplyTransparency | Line: 42 | Upvalues: v4 (ref) ]]
	if if p2 then p2 else v4 then
		p1.LocalTransparencyModifier = 0.8
	else
		p1.LocalTransparencyModifier = 0
	end
end
function AddTransparency(p1) --[[ AddTransparency | Line: 51 | Upvalues: t2 (copy) ]]
	t2[p1] = true
	ApplyTransparency(p1)

	for k, v in pairs(p1:QueryDescendants("ParticleEmitter,Beam")) do
		t2[v] = true
		ApplyTransparency(v)
	end
end
function AddTransparencyObjects(p1) --[[ AddTransparencyObjects | Line: 60 ]]
	if typeof(p1) ~= "table" then
		AddTransparency(p1)

		return
	end

	for k, v in pairs(p1) do
		AddTransparency(v)
	end
end
function RemoveTransparencyObjects(p1) --[[ RemoveTransparencyObjects | Line: 69 | Upvalues: t2 (copy) ]]
	if typeof(p1) ~= "table" then
		t2[p1] = nil
		ApplyTransparency(p1, false)

		return
	end

	for k, v in pairs(p1) do
		t2[v] = nil
		ApplyTransparency(v, false)
	end
end

local v6 = nil

function SetupTransparency() --[[ SetupTransparency | Line: 82 | Upvalues: t2 (copy), v1 (copy) ]]
	table.clear(t2)
	AddTransparencyObjects(v1)
end
SetupTransparency()

local ReplicatedStorage2 = game:GetService("ReplicatedStorage")

function PlaceFire(p1) --[[ PlaceFire | Line: 161 | Upvalues: CurseHandler (copy), AnotherPoolManager (copy), v1 (copy), TweenService (copy) ]]
	local v12 = if CurseHandler.IsCurseEnabled("Leo") then 6 else 3
	local v2 = AnotherPoolManager.GetItemFromPool("SigilFire")
	local v3 = false
	local v4 = v2.Touched:Connect(function(p1) --[[ Line: 171 | Upvalues: v3 (ref), v1 (ref) ]]
		if v3 then
			return
		end

		local v12 = game.Players:GetPlayerFromCharacter(p1.Parent)

		if v12 ~= game.Players.LocalPlayer then
			return
		end

		local Character = v12.Character
		local v2 = Character.Humanoid:GetAttribute("UsingAbility")

		if v2 and Character:GetAttribute("Class") == "class/Spirit" then
			return
		end

		v3 = true
		v1.ClientEvent:FireServer("Combust")
		task.wait(1)
		v3 = false
	end)

	v2.CanTouch = true
	v2.Smoke.Enabled = true
	v2.Sparkles.Enabled = true
	v2.Size = Vector3.new(0, 5.25, 0)
	v2.Position = p1 - Vector3.new(0, 3, 0) - Vector3.new(0, v2.Size.Y / 2, 0)
	v2.Decal.Transparency = 0.3
	TweenService:Create(v2, TweenInfo.new(0.75, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Size = Vector3.new(v12, 7.5, v12),
	}):Play()
	task.delay(
		12,
		function() --[[ Line: 203 | Upvalues: v2 (copy), v4 (copy), TweenService (ref), AnotherPoolManager (ref) ]]
			v2.Smoke.Enabled = false
			v2.Sparkles.Enabled = false
			v2.CanTouch = false
			v4:Disconnect()
			TweenService:Create(v2.Decal, TweenInfo.new(2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
			task.delay(2, function() --[[ Line: 214 | Upvalues: AnotherPoolManager (ref), v2 (ref) ]]
				AnotherPoolManager.ReturnItemToPool("SigilFire", v2)
			end)
		end
	)
end

local function LaserAura(p1) --[[ LaserAura | Line: 220 | Upvalues: v2 (ref), TweenService (copy), RunService (copy), t2 (copy) ]]
	local v1 = p1:Clone()

	v1.CFrame = p1.CFrame
	v1.Color = v2 and Color3.fromRGB(0, 255, 242) or Color3.fromRGB(255, 85, 0)
	v1.Size = p1.Size * Vector3.new(0.5, 0.5, 0.5)
	v1.Transparency = 0.35
	v1.Parent = workspace.Beacons
	TweenService:Create(v1, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0), {
		Transparency = 1,
		Size = p1.Size * Vector3.new(1.25, 1.25, 1.25),
	}):Play()
	AddTransparencyObjects(v1)

	local sum = 0

	repeat
		sum = sum + RunService.RenderStepped:Wait()
		v1.CFrame = p1.CFrame
	until sum >= 0.5

	t2[v1] = nil
	v1:Destroy()
end

local v7 = 0

local function ChargeUp(p1) --[[ ChargeUp | Line: 248 | Upvalues: ReplicatedStorage (copy), Debris (copy), v2 (ref), t (copy) ]]
	local Character = p1.Character
	local v1 = ReplicatedStorage.SigilMarker:Clone()

	Debris:AddItem(v1, 5.75)

	local v22 = Character and Character:FindFirstChild("HumanoidRootPart")

	if v22 then
		local IndicatorWeld = v1.IndicatorWeld
		local start = v1.start
		local Particlets = v1.Particlets
		local circles = start.circles

		v1.Parent = v22
		IndicatorWeld.Part0 = v22
		IndicatorWeld.Part1 = v1

		if v2 then
			Particlets.Color = ColorSequence.new(Color3.fromRGB(48, 255, 245))
			start.Flash.Color = ColorSequence.new(Color3.fromRGB(0, 172, 206))
			start.circles.Color = ColorSequence.new(Color3.fromRGB(0, 172, 206))
			start.ShineVertical.Color = ColorSequence.new(Color3.fromRGB(0, 172, 206))
			start.ShineHorizontal.Color = ColorSequence.new(Color3.fromRGB(0, 172, 206))
			start.ParticleEmitter.Color = ColorSequence.new(Color3.fromRGB(21, 188, 206))
		end

		local v3 = false
		local SavedQualityLevel = UserSettings().GameSettings.SavedQualityLevel.Value

		if SavedQualityLevel == 0 then
			SavedQualityLevel = 5
		end

		if SavedQualityLevel <= 4 then
			v3 = true
		end

		Particlets.Enabled = true
		Particlets:Emit(math.random(3, 6))
		start.Flash.Enabled = true
		start.Flash:Emit(math.random(2, 3))
		start.ParticleEmitter.Enabled = true
		start.ParticleEmitter:Emit(1)
		start.ShineHorizontal.Enabled = true
		start.ShineHorizontal:Emit(1)
		start.ShineVertical.Enabled = true
		start.ShineVertical:Emit(1)
		circles.Enabled = true
		circles:Emit(1)

		if p1 == game.Players.LocalPlayer then
			v1.LockOn:Play()
		end

		if v3 then
			task.spawn(function() --[[ Line: 295 | Upvalues: v1 (copy), v22 (copy), Particlets (copy) ]]
				local v12 = v1:QueryDescendants("ParticleEmitter")

				repeat
					task.wait(0.3)

					for k, v in pairs(v12) do
						v:Emit(1)
					end
				until not v1 or (v1.Parent ~= v22 or Particlets.Enabled == false)
			end)
		end
	end

	table.insert(t, v1)
end

local function Beam(p1, p2, p3, p4, p5, p6, p7) --[[ Beam | Line: 310 | Upvalues: HitboxHelper (copy), v1 (copy), v6 (ref), ReplicatedStorage2 (copy), t (copy), RunService (copy), Difficulty (copy), v7 (ref), LaserAura (copy), v3 (copy), v5 (ref), v2 (ref), TweenService (copy), t2 (copy) ]]
	local v12 = p1 and p1.Character or p5 and nil
	local v22 = false
	local v32 = false
	local v4 = false
	local v52 = 1024
	local v62 = false
	local SavedQualityLevel = UserSettings().GameSettings.SavedQualityLevel.Value

	if SavedQualityLevel == 0 then
		SavedQualityLevel = 5
	end

	if SavedQualityLevel <= 4 then
		v62 = true
	end

	local v72, v8, v9, v10, v11

	if p7 then
		v72 = nil
		v8 = nil
		v9 = nil
		v10 = nil
		v11 = nil
	else
		if p1 ~= game.Players.LocalPlayer then
			v52 = v52 / 3
		end

		local v122, v13, v14, v15, v16 = HitboxHelper.CreateLaser(p2 or 7, v52 + 50)

		v72 = v122
		v8 = v13
		v9 = v14
		v10 = v16
		v11 = v15
	end

	local Position = v1.Position
	local Start = Instance.new("Attachment")
	local End = Instance.new("Attachment")

	if v72 then
		v72.Position = Position
		v8.Position = Position
		v9.Position = Position

		if p1 ~= game.Players.LocalPlayer then
			for k, v in pairs(v11) do
				v.ParticleEmitter.Rate = 133.33333333333334
				v.ParticleEmitter2.Rate = 133.33333333333334
				v.Tears.Rate = 133.33333333333334
			end
		end

		v8.Size = Vector3.new(0, 0, 0)
		v9.Size = Vector3.new(0, 0, 0)
		v6 = v8
		HitboxHelper.Debris(25, v72, HitboxHelper.poolPartGroup)
		HitboxHelper.Debris(25, v8, HitboxHelper.poolLaserBeamGroup)
		HitboxHelper.Debris(25, v9, HitboxHelper.poolBlastGroup)

		for k, v in pairs(v11) do
			HitboxHelper.Debris(25, v, HitboxHelper.poolPartGroup)
		end

		HitboxHelper.Debris(25, v10, HitboxHelper.poolPartGroup)
		AddTransparencyObjects({ v72, v8, v9 })
		Start.Position = Vector3.new(0, 0, v72.Size.Z / 2)
		End.Position = Vector3.new(0, 0, -v72.Size.Z / 2)
		Start.Name = "Start"
		End.Name = "End"
		Start.Parent = v72
		End.Parent = v72

		if v62 then
			for k, v in pairs(v11) do
				v.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
			end

			v10.Transparency = 0.75
		else
			v10.Transparency = 0.85
		end
	end

	local InRound = ReplicatedStorage2.InRound

	if game.ReplicatedStorage.Difficulty.Value == 1 then
		p4 = p4 / 1.2
	end

	local sum = 0
	local v19 = if p5 then if math.random(1, 2) == 1 then -1 else 1 else nil

	task.spawn(function() --[[ Line: 418 | Upvalues: p7 (copy), v4 (ref), t (ref) ]]
		if p7 then
			repeat
				task.wait()
			until v4
		end

		for k, v in pairs(t) do
			if not (v and v.Parent) then
				return
			end

			v.Particlets.Enabled = false
			v.start.Flash.Enabled = false
			v.start.ParticleEmitter.Enabled = false
			v.start.ShineHorizontal.Enabled = false
			v.start.ShineVertical.Enabled = false
			v.start.circles.Enabled = false
		end

		table.clear(t)
	end)

	local count = 0
	local sum2 = 25.6
	local v21 = p4 or 0.75
	local v222 = 51.2
	local sum3 = 3
	local sum4 = 0.2

	repeat
		local v23 = RunService.RenderStepped:Wait()

		count = count + 1

		local v24 = v12 and v12:FindFirstChild("HumanoidRootPart") or p5 and nil

		if sum <= (p3 or 5) then
			if v24 or (p5 or p7) then
				local v25 = game.Players.LocalPlayer.Character
					and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

				if not v32 then
					v32 = true

					if not p5 and v24 then
						local v26 = v1.LaserCharge:Clone()

						v26.Parent = if p7 then v1 or v24 else v24

						if p7 then
							v26.Volume = v26.Volume / 1.75
						end

						v26:Play()
						v26.Ended:Once(function() --[[ Line: 481 | Upvalues: v26 (copy) ]]
							v26:Destroy()
						end)
					end
				end

				local v28 = nil

				if v72 then
					local Size = v72.Size
					local Size2 = v8.Size
					local Size3 = v9.Size
					local v29 = p5
							and CFrame.new(p5) * CFrame.fromAxisAngle(
								Vector3.new(0, 1, 0),
								v19 * 0.5 * sum * 1.5707963267948966
							)
						or CFrame.lookAt(v1.Position, v24.Position)

					if sum <= 0.5 then
						if not (p5 and v29) then
							v29 = v72.CFrame:Lerp(v29, v23 * (v21 or 0.75) * 5)
						end

						v28 = v29
						v72.CFrame = v29
					elseif sum >= 3 then
						if not (p5 and v29) then
							v29 = v72.CFrame:Lerp(v29, v23 * (v21 or 0.75))
						end

						v28 = v29
						v72.CFrame = v29
						v222 = 51.2 + 460.8 * math.clamp((sum - 6) / 10, 0, 1)

						if
							tick() - v7 > 0.5
							and v25
							and HitboxHelper.CheckBounds(
								v25,
								v29 + v29.LookVector * Size2.Y / 2,
								(Vector3.new(Size.X - 5, Size.Y - 5, Size2.Y))
							)
						then
							v7 = tick()
							v1.ClientEvent:FireServer("Kill")
						end
					elseif sum >= 0.5 then
						if not (p5 and v29) then
							v29 = v72.CFrame:Lerp(v29, v23)
						end

						v28 = v29
						v72.CFrame = v29
					end

					v10.CFrame = (v28 + v28.LookVector * (v10.Size.X / 2)) * CFrame.Angles(0, 1.5707963267948966, 0)

					if not v62 then
						for k, v in pairs(v11) do
							v.CFrame = (v28 + v28.LookVector * (v.Size.X / 2 + v.Size.X * (k - 1)))
								* CFrame.Angles(0, 1.5707963267948966, 0)
						end
					end

					v8.CFrame = (v28 + v28.LookVector * Size.Z / (Size.Z / Size2.Y) / 2)
						* CFrame.Angles(-1.5707963267948966, 0, 0)
						* CFrame.fromAxisAngle(Vector3.new(0, 1, 0), sum * 5 * 1.5707963267948966)
					v9.CFrame = (v28 + v28.LookVector * (Size.Z / (Size.Z / Size3.Z) / 2 - Size3.Z / 5))
						* CFrame.fromAxisAngle(Vector3.new(0, 0, 1), sum * 5 * 1.5707963267948966)
				end

				if sum >= 3 then
					if v72 then
						sum2 = sum2 + (math.min(v52, 9999) - sum2) * math.clamp(v23 * 2, 0, 1)
						End.Position =
							End.Position:Lerp(Vector3.new(0, 0, -v72.Size.Z / 2), (math.clamp((sum - 3) / 10, 0, 1)))
						v8.Size =
							v8.Size:Lerp(Vector3.new((p2 or 7) + 4, sum2, (p2 or 7) + 4), (math.clamp(v23 * 3, 0, 1)))
						v9.Size =
							v9.Size:Lerp(Vector3.new((p2 or 7) + 8, (p2 or 7) + 8, v222), (math.clamp(v23 * 3, 0, 1)))

						if count % 6 == 0 then
							task.spawn(LaserAura, v8)
						end

						if sum3 <= sum then
							sum3 = sum3 + 1.5
						end

						if p6 and sum4 <= 0 then
							sum4 = 0.2
							v3.FilterDescendantsInstances = { workspace.CurrentRooms }

							local v37 = Start.WorldPosition + v28.LookVector * 8
							local v38 = workspace:Raycast(v37, End.WorldPosition - v37, v3)

							if v38 and v38.Position then
								PlaceFire(v38.Position + Vector3.new(0, 3, 0))
							end
						elseif p6 then
							sum4 = sum4 - v23
						end
					end

					if not v22 then
						v22 = true
						v5 = true
						shared.FX_Remote_Local:Fire(
							"Cast_Effects",
							"Explosion",
							v1.Position,
							0,
							75,
							0.15,
							v2 and Color3.fromRGB(61, 190, 255) or Color3.fromRGB(255, 181, 61),
							v2 and Color3.fromRGB(61, 255, 213) or Color3.fromRGB(255, 190, 61)
						)
						shared.FX_Remote_Local:Fire(
							"Cast_Effects",
							"Explosion",
							v1.Position,
							0,
							60,
							0.5,
							Color3.fromRGB(255, 255, 255),
							v2 and Color3.fromRGB(71, 255, 224) or Color3.fromRGB(255, 188, 71)
						)
						shared.FX_Remote_Local:Fire("Cast_Effects", "Shake_Camera", 0.25, 2, 512, v1.Position)
						task.delay(2, function() --[[ Line: 588 | Upvalues: v5 (ref) ]]
							v5 = false
						end)
						v1.head.Brightness = 5
						TweenService
							:Create(v1.head, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Brightness = 1.1,
							})
							:Play()

						if v72 then
							for v53, v54 in { v10, unpack(v11) } do
								if v54:FindFirstChild("ParticleEmitter") then
									v54.ParticleEmitter.Enabled = false
								end

								if v54:FindFirstChild("ParticleEmitter2") then
									v54.ParticleEmitter2.Enabled = false
								end

								if v54:FindFirstChild("Tears") then
									v54.Tears.Enabled = false
								end
							end

							game:GetService("TweenService")
								:Create(v10, TweenInfo.new(1), {
									Transparency = 1,
								})
								:Play()
						end

						v1.LaserFire.TimePosition = 0

						if p7 then
							v1.LaserFire.Volume = 0.5714285714285714
						end

						if not p5 then
							v1.LaserFire:Play()
						end
					end
				end
			end
		else
			if not v4 then
				v4 = true
			end

			if v72 then
				local v55 = v8.Size:Lerp(Vector3.new(0, 0, 0), (math.clamp(v23 * 10, 0, 1)))

				v8.Size = v55

				local v56 = v9.Size:Lerp(Vector3.new(0, 0, 0), (math.clamp(v23 * 10, 0, 1)))

				v9.Size = v56

				local v57 = v72.CFrame
				local Size = v72.Size

				v8.CFrame = (v57 + v57.LookVector * Size.Z / (Size.Z / v55.Y) / 2)
					* CFrame.Angles(-1.5707963267948966, 0, 0)
					* CFrame.fromAxisAngle(Vector3.new(0, 1, 0), sum * 5 * 1.5707963267948966)
				v9.CFrame = (v57 + v57.LookVector * (Size.Z / (Size.Z / v56.Z) / 2 - v56.Z / 5))
					* CFrame.fromAxisAngle(Vector3.new(0, 0, 1), sum * 5 * 1.5707963267948966)
			end
		end

		sum = sum + v23
	until (p3 or 5) + 1 <= sum

	if not v72 then
		table.clear(t2)

		return
	end

	HitboxHelper.Destroy(v72, HitboxHelper.poolPartGroup)
	HitboxHelper.Destroy(v8, HitboxHelper.poolLaserBeamGroup)
	HitboxHelper.Destroy(v9, HitboxHelper.poolBlastGroup)

	for k, v in pairs(v11) do
		HitboxHelper.Destroy(v, HitboxHelper.poolPartGroup)
	end

	HitboxHelper.Destroy(v10, HitboxHelper.poolPartGroup)
	RemoveTransparencyObjects({ v72, v8, v9 })
	table.clear(t2)
end

game:GetService("RunService").RenderStepped:Connect(
	function() --[[ Line: 659 | Upvalues: v1 (copy), v6 (ref), SpacialOperationHelper (copy), v4 (ref), t2 (copy) ]]
		local v12 = workspace.CurrentCamera.CFrame
		local v2 = false

		if
			(v12.p - v1.Position).Magnitude <= 50
			or v6
				and SpacialOperationHelper.OBBIntersectBoxes(
					CFrame.new(v12.p),
					Vector3.new(10, 10, 10),
					v6.CFrame,
					v6.Size
				)
		then
			v2 = true
		end

		if v4 == v2 then
			return
		end

		v4 = v2
		v1.head.sprite.ImageTransparency = if v2 then 0.5 else 0

		for k in pairs(t2) do
			ApplyTransparency(k)
		end
	end
)
v1.ClientEvent.OnClientEvent:Connect(
	function(p1, p2) --[[ Line: 679 | Upvalues: CurseHandler (copy), Beam (copy), v1 (copy), ChargeUp (copy) ]]
		if p1 == "Beam" then
			if CurseHandler.IsCurseEnabled("Celestigal") then
				Beam(
					p2.Player,
					25 + (if CurseHandler.IsCurseEnabled("Leo") then 10 else 0),
					18,
					1,
					false,
					CurseHandler.IsCurseEnabled("Aries"),
					p2.SoundOnly
				)
			else
				Beam(
					p2.Player,
					7 + (if CurseHandler.IsCurseEnabled("Leo") then 5 else 0),
					5,
					1.85,
					false,
					CurseHandler.IsCurseEnabled("Aries"),
					p2.SoundOnly
				)
			end
		elseif p1 == "BeamSweep" then
			Beam(
				nil,
				13 + (if CurseHandler.IsCurseEnabled("Leo") then 5 else 0),
				5,
				1.1,
				v1.Position,
				CurseHandler.IsCurseEnabled("Aries"),
				p2.SoundOnly
			)
		else
			if p1 ~= "ChargeUp" then
				return
			end

			ChargeUp(p2.Player)
		end
	end
)
task.spawn(function() --[[ Line: 694 | Upvalues: v5 (ref), v2 (ref), v1 (copy) ]]
	while true do
		while true do
			local v12 = math.random(1, 8)
			local v22 = math.random(1, 8)
			local v3 = math.random(1, 8)
			local v4 = if math.random(1, 2) == 1 then v12 * -1 else v12
			local v52 = if math.random(1, 2) == 1 then v22 * -1 else v22

			if math.random(1, 2) == 1 then
				v3 = v3 * -1
			end

			if v5 then
				local v6 = v2 and Color3.fromRGB(52, 255, 245) or Color3.fromRGB(255, 133, 52)

				shared.FX_Remote_Local:Fire("Cast_Effects", "Explosion", v1.Position, 0, 30, 0.75, v6, v6)
				shared.FX_Remote_Local:Fire(
					"Cast_Effects",
					"ExplosionTall",
					v1.Position + Vector3.new(v4, v52, v3),
					0,
					21,
					0.5,
					v6,
					v6
				)
			end

			if v5 then
				break
			end

			task.wait(0.12)
		end

		task.wait(0.025)
	end
end)

local t3 = {
	[v1.PointLight] = {
		Alternate = Color3.fromRGB(48, 255, 245),
	},
	[v1.Boom] = {
		Alternate = ColorSequence.new(Color3.fromRGB(23, 192, 184)),
	},
	[v1.AfterimageStuff.Shockwave] = {
		Alternate = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(123, 255, 248)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(107, 192, 189)),
		}),
	},
	[v1.idle.ShineVertical] = {
		Alternate = ColorSequence.new(Color3.fromRGB(0, 189, 227)),
	},
	[v1.idle.ShineHorizontal] = {
		Alternate = ColorSequence.new(Color3.fromRGB(0, 189, 227)),
	},
	[v1.idle.Particlets] = {
		Alternate = ColorSequence.new(Color3.fromRGB(0, 242, 255)),
	},
	[v1.idle.Flash] = {
		Alternate = ColorSequence.new(Color3.fromRGB(0, 242, 255)),
	},
	[v1.idle.circles] = {
		Alternate = ColorSequence.new(Color3.fromRGB(0, 242, 255)),
	},
}

for v8, v9 in v1.idle.BeamContinuous:GetChildren() do
	t3[v9] = {
		Alternate = ColorSequence.new(Color3.fromRGB(0, 206, 206)),
	}
end

for v10, v11 in v1.idle.BeamStart:GetChildren() do
	t3[v11] = {
		Alternate = ColorSequence.new(Color3.fromRGB(0, 206, 206)),
	}
end

for v12, v13 in t3 do
	v13.Main = v12.Color
end

print(t3)

local function updatePalette(p1) --[[ updatePalette | Line: 767 | Upvalues: t3 (copy) ]]
	for v1, v2 in t3 do
		v1.Color = p1 and v2.Alternate or v2.Main
	end
end

local function onSettingChaned() --[[ onSettingChaned | Line: 773 | Upvalues: SettingsHandler (copy), spritesheet (copy), sigil2 (copy), t3 (copy), v2 (ref), sigilAlternate (copy) ]]
	if SettingsHandler.Get({ "Graphics", "Colorblind" }) then
		spritesheet.Value = sigilAlternate

		for v1, v22 in t3 do
			v1.Color = v22.Alternate or v22.Main
		end

		v2 = true
	else
		spritesheet.Value = sigil2

		for v4, v5 in t3 do
			v4.Color = v5.Main
		end

		v2 = false
	end
end

SettingsHandler.WaitForSettings()
SettingsHandler.OnSettingsChanged:Connect(onSettingChaned)
onSettingChaned()

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Slicer.Slicer_ClientAI
-- Took 0.39s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")
local v1 = script.Parent
local ClientEvent = v1:WaitForChild("ClientEvent")
local UpdatePosition = v1:WaitForChild("UpdatePosition")
local v2 = 0
local v3 = CFrame.new()
local v4 = "CHASE"
local v5 = v1.CFrame
local LookVector = v1.CFrame.LookVector
local v6 = 0
local v7 = nil
local v8 = nil
local v9 = nil
local v10 = time()
local v11 = 0

ClientEvent.OnClientEvent:Connect(function(p1) --[[ Line: 26 | Upvalues: v4 (ref) ]]
	v4 = p1
end)
UpdatePosition.OnClientEvent:Connect(
	function(p1, p2, p3) --[[ Line: 30 | Upvalues: v7 (ref), v5 (ref), v8 (ref), LookVector (ref), v9 (ref), v6 (ref), v10 (ref) ]]
		v7 = v5
		v8 = LookVector
		v9 = v6
		v5 = CFrame.new(p1)
		LookVector = p2
		v6 = p3
		v10 = time()
	end
)
RunService.Heartbeat:Connect(
	function(p1) --[[ Line: 44 | Upvalues: v10 (ref), v5 (ref), v7 (ref), v8 (ref), LookVector (ref), v9 (ref), v6 (ref), v11 (ref), v4 (ref), v2 (ref), v3 (ref), v1 (copy) ]]
		local v22 = math.clamp((time() - v10) / 0.0625, 0, 1)

		if not (v5 and v7) then
			return
		end

		local v32 = (v5.Position - v7.Position).Magnitude / 0.0625
		local Position = v7:Lerp(v5, v22).Position
		local v42 = v8:Lerp(LookVector, v22)
		local v72 = math.lerp(v9, v6, v22)

		v11 = v11 + p1 * (4 + v32 / 20 * 5)

		local v122 = CFrame.Angles(math.sin(v11) * (v32 / 20) * 0.55, 0, math.cos(v11) * (v32 / 20) * 0.55)
		local v14 = if v4 == "STUN" then v122 else CFrame.new()

		v2 = math.lerp(v2, if v4 == "CHASE" then v72 * 2 else 0, p1 * 5)
		v3 = v3:Lerp(v14, p1 * 5)
		v1.CFrame = CFrame.lookAlong(Position, v42) * CFrame.Angles(0, 0, v2) * v3
	end
)

repeat
	ClientEvent:FireServer()
	task.wait(0.1)
until v7
-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Telefragger.Telefragger_ClientAI
-- Took 0.37s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")

game:GetService("Debris")

local TweenService = game:GetService("TweenService")
local v1 = script.Parent
local ClientEvent = v1:WaitForChild("ClientEvent")
local UpdatePosition = v1:WaitForChild("UpdatePosition")
local v2 = v1.CFrame
local v3 = nil
local v4 = time()
local v5 = false
local v6 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.3)
local v7 = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3)

local function f8(p1) --[[ Line: 20 | Upvalues: v1 (copy), TweenService (copy), v6 (copy), v7 (copy) ]]
	v1.Alarm:Play()

	local Attachment = Instance.new("Attachment")
	local Attachment2 = Instance.new("Attachment")

	Attachment.Parent = v1.IndicatorPart
	Attachment2.Parent = v1.IndicatorPart
	Attachment.WorldPosition = p1.Start
	Attachment2.WorldPosition = p1.End

	local v12 = v1.Beam:Clone()

	v12.Transparency = NumberSequence.new(p1.Transparency)
	v12.Attachment0 = Attachment
	v12.Attachment1 = Attachment2
	v12.Parent = Attachment

	if (workspace.CurrentCamera.CFrame.Position - (p1.Start + p1.End) / 2).Magnitude < 512 then
		TweenService:Create(v12, v6, {
			Brightness = 0,
		}):Play()
		TweenService:Create(v12, v7, {
			Width0 = 0.01,
			Width1 = 0.01,
		}):Play()
	end

	task.wait(1)
	Attachment:Destroy()
	Attachment2:Destroy()
end

local function f9(p1) --[[ Line: 54 | Upvalues: v1 (copy), TweenService (copy), v4 (ref), v3 (ref), v2 (ref) ]]
	dashing = true
	v1.Scream:Play()
	v1.CFrame = CFrame.new(p1.Start)
	TweenService:Create(v1, TweenInfo.new(p1.Speed, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {
		CFrame = CFrame.new(p1.End),
	}):Play()
	task.wait(p1.Speed)
	v1.CFrame = CFrame.new(p1.End)
	v4 = time()
	v3 = CFrame.new(v1.Position)
	v2 = CFrame.new(v1.Position)
	dashing = false
end

UpdatePosition.OnClientEvent:Connect(
	function(p1, p2) --[[ Line: 75 | Upvalues: v3 (ref), v2 (ref), v4 (ref), v1 (copy), v5 (ref) ]]
		v3 = v2
		v2 = CFrame.new(p1)
		v4 = time()

		if not p2 then
			return
		end

		v3 = CFrame.new(p1)
		v1.CFrame = v2
		v5 = false
	end
)
RunService.Heartbeat:Connect(function(p1) --[[ Line: 90 | Upvalues: v4 (ref), v2 (ref), v3 (ref), v5 (ref), v1 (copy) ]]
	if dashing then
		return
	end

	local v22 = math.clamp((time() - v4) / 0.125, 0, 1)

	if not (v2 and v3) then
		return
	end

	if v5 and (v3.Position - v2.Position).Magnitude > 6 then
		return
	end

	v1.CFrame = v3:Lerp(v2, v22)
end)
ClientEvent.OnClientEvent:Connect(function(p1, p2) --[[ Line: 107 | Upvalues: f8 (copy), f9 (copy), v5 (ref) ]]
	if p1 == "Indicator" then
		f8(p2)

		return
	end

	if p1 == "TweenBaby" then
		f9(p2)

		return
	end

	if p1 ~= "SetTeleport" then
		return
	end

	v5 = true
end)

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Voidbreaker.Voidbreaker_AI
-- Took 0.68s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local v1 = script.Parent
local v2 = false

for v3, v4 in workspace.Enemies:GetChildren() do
	if v4.Name == v1.Name and (v4 ~= v1 and v4:GetAttribute("Active")) then
		v2 = true

		break
	end
end

if v2 then
	script:Destroy()

	return
end

script.Parent:SetAttribute("Active", true)

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character
local Dead = LocalPlayer:WaitForChild("Dead")
local v5 = script.Parent
local GreaterCurseHandler = require(ReplicatedFirst.ClientModules.GreaterCurseHandler)
local CurseHandler = require(ReplicatedFirst.ClientModules.CurseHandler)
local SettingsHandler = require(ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local v6 = GreaterCurseHandler.IsCurseEnabled("BalletOfBlades")
local v7 = GreaterCurseHandler.IsCurseEnabled("BladeBombardment")
local v8 = CurseHandler.IsCurseEnabled("BladeCarousel")
local t = {
	LungeLength = 1,
	AttackDelay = 0.4,
	AttackLength = 0.2,
	DisappearLength = 0.2,
}

if v6 then
	t.LungeLength = 0.6
	t.AttackDelay = 1
end

if v7 then
	t.LungeLength = 1.2
	t.AttackLength = 0.075
	t.AttackDelay = 0.8
end

local t2 = {}
local Sword = ReplicatedStorage:WaitForChild("Sword")

if v6 then
	Sword = ReplicatedStorage:WaitForChild("SwordFast")
end

if v7 then
	Sword = ReplicatedStorage:WaitForChild("SwordSlow")
end

local v9 = if ReplicatedStorage.Difficulty.Value == 3 then true else false
local count = 1

for v10, v11 in workspace.Enemies:GetChildren() do
	if v11.Name == "Voidbreaker" and v11 ~= script.Parent then
		count = count + 1
	end
end

workspace.Enemies.ChildAdded:Connect(function(p1) --[[ Line: 82 | Upvalues: count (ref) ]]
	if p1.Name ~= "Voidbreaker" then
		return
	end

	count = count + 1
end)
workspace.Enemies.ChildRemoved:Connect(function(p1) --[[ Line: 88 | Upvalues: count (ref) ]]
	if p1.Name ~= "Voidbreaker" then
		return
	end

	count = count - 1
end)

local CurrentCamera = workspace.CurrentCamera
local Camera = Instance.new("Camera", v5)

Camera.CFrame = CFrame.new(0, 0, 7)

local v12 = false
local Voidbreaker = LocalPlayer.PlayerGui:WaitForChild("Voidbreaker")

Voidbreaker.ViewportFrame.CurrentCamera = Camera

local Voidknight = Voidbreaker.ViewportFrame.World.Voidknight
local Animator = Voidknight.AnimationController.Animator
local v13 = Animator:LoadAnimation(ReplicatedStorage.Voidknight:WaitForChild("SpawnAnim"))
local v14 = Animator:LoadAnimation(ReplicatedStorage.Voidknight:WaitForChild("Idle"))

v14.Priority = Enum.AnimationPriority.Idle

local v15 = Animator:LoadAnimation(ReplicatedStorage.Voidknight:WaitForChild("Despawn"))
local v16 = Animator:LoadAnimation(ReplicatedStorage.Voidknight:WaitForChild("Attack"))
local Sounds = Instance.new("Folder", v5)

Sounds.Name = "Sounds"

local v17 = ReplicatedStorage.Assets.Voidbreaker:WaitForChild("Lighting"):Clone()

v17.Parent = v5
Voidbreaker.Adornee = v5
_G.VoidbreakerActive = false
shared.VoidbreakerWishSpawn = false

if not workspace:FindFirstChild("VoidbreakerVisualizers") then
	local VoidbreakerVisualizers = Instance.new("Folder")

	VoidbreakerVisualizers.Name = "VoidbreakerVisualizers"
	VoidbreakerVisualizers.Parent = workspace

	local Highlight = Instance.new("Highlight")

	Highlight.OutlineTransparency = 0
	Highlight.OutlineColor = Color3.new(0 / 255, 0 / 255, 0 / 255)
	Highlight.FillColor = Color3.new(0 / 255, 0 / 255, 0 / 255)
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.FillTransparency = 0
	Highlight.Parent = VoidbreakerVisualizers
end

local v18 = if v8 and v7 then 1.25 else 1.5
local v20 = if v7 then 2.25 else v18
local v21 = Vector3.new(1, 1, 1) * v20
local PlayerVoidbreakerHitbox = workspace:FindFirstChild("PlayerVoidbreakerHitbox")

if not PlayerVoidbreakerHitbox then
	PlayerVoidbreakerHitbox = Instance.new("Part")
	PlayerVoidbreakerHitbox.Size = v21
	PlayerVoidbreakerHitbox.Shape = Enum.PartType.Ball
	PlayerVoidbreakerHitbox.Anchored = true
	PlayerVoidbreakerHitbox.CanCollide = false
	PlayerVoidbreakerHitbox.CanTouch = false
	PlayerVoidbreakerHitbox.CanQuery = false
	PlayerVoidbreakerHitbox.Color = Color3.new(153 / 255, 0 / 255, 0 / 255)
	PlayerVoidbreakerHitbox.Material = Enum.Material.Neon
	PlayerVoidbreakerHitbox.Name = "PlayerVoidbreakerHitbox"
	PlayerVoidbreakerHitbox.Transparency = 1
	PlayerVoidbreakerHitbox.Parent = workspace
end

local v22 = if v6 then 16 else 8

local function chooseAngle(p1) --[[ chooseAngle | Line: 169 ]]
	if #p1 == 0 then
		return
	end

	local v1 = math.random(1, #p1)

	table.remove(p1, v1)

	return p1[v1]
end

local function attack(p1) --[[ attack | Line: 179 | Upvalues: Sword (ref), SettingsHandler (copy), t2 (copy) ]]
	if not p1 then
		return
	end

	local v1 = Sword:Clone()

	if SettingsHandler.Get({ "Graphics", "Colorblind" }) then
		v1.Model2.Color = Color3.fromRGB(255, 120, 0)
		v1.Color = Color3.fromRGB(180, 90, 0)
		v1.Model1.Highlight.OutlineColor = Color3.fromRGB(255, 120, 0)
		v1.Model1.Highlight.FillColor = Color3.fromRGB(180, 90, 0)
	end

	v1.Parent = script.Parent
	table.insert(t2, {
		elapsed = 0,
		spinRad = 0,
		target = Vector3.new(0, 0, 0),
		state = 0,
		sword = v1,
		time = os.clock(),
		rad = math.rad(p1),
		rand = math.random(),
	})
end

local v23 = if v7 or v6 then 1.5 else 2

local function shootSound(p1) --[[ shootSound | Line: 210 | Upvalues: v7 (copy), v6 (copy), ReplicatedStorage (copy), Sounds (copy) ]]
	if v7 and not v6 then
		local v1 = ReplicatedStorage.Assets.Voidbreaker.Sounds.Bombardment:GetChildren()[math.random(1, 2)]:Clone()

		v1.Parent = Sounds
		v1:Play()
		v1.Ended:Once(function() --[[ Line: 216 | Upvalues: v1 (copy) ]]
			v1:Destroy()
		end)

		return
	end

	if not v6 or v7 then
		local v2 = ReplicatedStorage.Assets.Voidbreaker.Sounds.Default:GetChildren()[math.random(1, 2)]:Clone()

		v2.Parent = Sounds
		v2:Play()
		v2.Ended:Once(function() --[[ Line: 241 | Upvalues: v2 (copy) ]]
			v2:Destroy()
		end)

		return
	end

	if p1 then
		local FinalBallet = ReplicatedStorage.Assets.Voidbreaker.Sounds.FinalBallet

		FinalBallet.Parent = Sounds
		FinalBallet:Play()
		FinalBallet.Ended:Once(function() --[[ Line: 232 | Upvalues: FinalBallet (copy) ]]
			FinalBallet:Destroy()
		end)
	else
		local v3 = ReplicatedStorage.Assets.Voidbreaker.Sounds.Ballet:GetChildren()[math.random(1, 4)]:Clone()

		v3.Parent = Sounds
		v3:Play()
		v3.Ended:Once(function() --[[ Line: 225 | Upvalues: v3 (copy) ]]
			v3:Destroy()
		end)
	end
end

local v24 = if v7 then -6 else -2.5
local Runes = v17.Runes

local function renderStepped(p1) --[[ renderStepped | Line: 249 | Upvalues: Character (copy), Dead (copy), Voidbreaker (copy), v14 (copy), v5 (copy), CurrentCamera (copy), PlayerVoidbreakerHitbox (ref), Camera (copy), t2 (copy), Sounds (copy), v12 (ref), Runes (copy), v16 (copy), SettingsHandler (copy), v8 (copy), t (copy), v23 (copy), v9 (copy), shootSound (copy), v24 (copy), ReplicatedStorage (copy) ]]
	local v1 = math.min(p1, 0.06666666666666667)
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

	if Dead.Value or (not Character or not HumanoidRootPart and Voidbreaker.Enabled) then
		Voidbreaker.Enabled = false

		if not v14.IsPlaying then
			return
		end

		v14:Stop()
	else
		if not (v5 and v5.Parent) then
			return
		end

		if not (HumanoidRootPart and (Character and Character.Parent)) then
			return
		end

		local Humanoid = Character:FindFirstChild("Humanoid")

		if not Humanoid then
			return
		end

		local RootPart = Humanoid.RootPart
		local Position = RootPart.Position
		local v2 = RootPart.Velocity * Vector3.new(1, 0, 1)
		local v3, v4

		if v2.Magnitude > 0.001 then
			v3 = v2.Unit
			v4 = v1

			if not v3 then
				v3 = Vector3.new(0, 0, 0)
			end
		else
			v4 = v1
			v3 = Vector3.new(0, 0, 0)
		end

		local v6 = math.clamp(v2.Magnitude / 5.333333333333333, -3, 3)
		local v7 = CurrentCamera.CFrame
		local v82 = v5.CFrame
		local v92 = CFrame.new(Position) + v3 * v6

		PlayerVoidbreakerHitbox.CFrame = v92
		PlayerVoidbreakerHitbox.CanQuery = true

		local v10 = CFrame.lookAt(v82.Position, v7.Position)
			- v82.Position
			+ (Character.HumanoidRootPart.Position + Vector3.new(0, 2, -13))

		v5.CFrame = v10

		local Position2 = v7.Position
		local v11 = CFrame.lookAt(Position2, v10.Position) - Position2
		local v122 = v11:Lerp(v11, 0.01)

		Camera.CFrame = v122 + v122.LookVector * -11
		os.clock()

		local t3 = {}

		for v13, v142 in t2 do
			local sword = v142.sword
			local Model1 = sword.Model1
			local Model2 = sword.Model2
			local Aura = Model1.Aura
			local Highlight = Model1.Highlight

			v142.elapsed = v142.elapsed + v4

			local elapsed = v142.elapsed

			if v142.state == 0 then
				local Unsheath = sword.Unsheath

				Unsheath.Parent = Sounds
				Unsheath:Play()
				Aura.Enabled = true
				sword.Rune.Runes:Emit(1)

				if not v12 then
					v12 = true
					Runes:Emit(1)
					v16:Play()
				end

				v142.state = 1
			end

			if SettingsHandler.Get({ "Misc", "VoidbreakerSwordOffset" }) then
				v142.target = Position + (Position - v92.Position)
			else
				v142.target = Position
			end

			local v162 = v142.rad + (if v8 then v142.spinRad else 0)
			local v19 = v142.target + Vector3.new(math.sin(v162), 0, (math.cos(v162))) * 8
			local v22 = Position + Vector3.new(math.sin(v162), 0, (math.cos(v162))) * 8
			local v232 = CFrame.Angles(-1.5707963267948966, v142.rand * math.pi + elapsed * math.pi / 2, 0)
			local v242 = t.LungeLength + t.AttackDelay

			if v142.state == 1 then
				local v26 = math.clamp(elapsed / t.LungeLength, 0, 1)

				sword.CFrame = CFrame.new(v19 - Vector3.new(0, 1, 0), v19)
					:Lerp(CFrame.new(v19, v142.target), (math.pow(v26, 2))) * v232

				local v27 = 1 - math.sqrt(v26)

				sword.LocalTransparencyModifier = v27
				Aura.TimeScale = v26 / 1.5
				Highlight.OutlineTransparency = v27
				Model1.LocalTransparencyModifier = v27
				Model2.LocalTransparencyModifier = v27
				v142.spinRad = elapsed * v23

				if v242 <= elapsed then
					v142.state = 2
					v142.spinRad = v242 * v23

					if not v9 then
						Model1.Fire.Aura:Emit(math.random(7, 10))
					end

					shootSound(false)
					Aura.Enabled = false
				end
			end

			if v142.state >= 2 then
				local v28 = elapsed - v242
				local v29 = CFrame.new(v19, v142.target)
				local v30 = CFrame.new(v22, Position)
				local v31 = v29 * CFrame.new(0, 0, -v28 * 8 / t.AttackLength)
				local v32 = v30 * CFrame.new(0, 0, -v28 * 8 / t.AttackLength)

				sword.CFrame = v31 * v232 * CFrame.Angles(0, v28 * math.pi * 2, 0)

				if t.AttackLength < v28 then
					local v34 = math.min((v28 - t.AttackLength) / t.DisappearLength, 1)
					local v35 = math.sqrt(v34)

					sword.LocalTransparencyModifier = v35
					Model1.LocalTransparencyModifier = v35
					Model2.LocalTransparencyModifier = v35
					Highlight.OutlineTransparency = v34

					if v34 == 1 then
						v142.state = 3
						table.insert(t3, v142)
					end

					continue
				end

				if v142.state == 2 then
					local v36 = RaycastParams.new()

					v36.FilterType = Enum.RaycastFilterType.Include
					v36.FilterDescendantsInstances = { PlayerVoidbreakerHitbox }
					v36.RespectCanCollide = false

					local v37 = workspace:Raycast(v32.Position + v32.ZVector * 2, v32.ZVector * v24, v36)

					if v37 and v37.Instance then
						v142.state = 3
						ReplicatedStorage.Events.Died:FireServer("Voidbreaker", nil, ReplicatedStorage.Level.Value)

						break
					end
				end
			end
		end

		for v38, v39 in t3 do
			local v40 = table.find(t2, v39)

			if v40 then
				table.remove(t2, v40)
				v39.sword:Destroy()
			end
		end

		PlayerVoidbreakerHitbox.CanQuery = false
	end
end

RunService:UnbindFromRenderStep("Voidbreaker")
RunService:BindToRenderStep("Voidbreaker", Enum.RenderPriority.Character.Value + 10, renderStepped)

local sum = if v9 then 30 else 35

if ReplicatedStorage.Solo.Value == true then
	sum = sum + 10
end

local function SpawnVoidknight() --[[ SpawnVoidknight | Line: 478 | Upvalues: v13 (copy), v15 (copy), v14 (copy), v17 (copy), Voidbreaker (copy), Voidknight (copy) ]]
	v13:Play(0)
	v15:Stop(0)
	v14:Play()
	v17.Boom.Enabled = true
	Voidbreaker.PixelsPerStud = 0
	Voidbreaker.Enabled = true
	task.spawn(function() --[[ Line: 485 | Upvalues: Voidknight (ref) ]]
		task.wait(0.217)
		Voidknight.Sword.Smear.Transparency = 0
		task.wait(0.1)
		Voidknight.Sword.Smear.Transparency = 1
	end)

	for i = 1, 50 do
		task.wait(0.018000000000000002)

		local v1 = Voidbreaker

		v1.PixelsPerStud = v1.PixelsPerStud + 1
	end
end

local function DespawnVoidknight() --[[ DespawnVoidknight | Line: 497 | Upvalues: v14 (copy), v15 (copy), v16 (copy), v17 (copy), Voidbreaker (copy), v12 (ref) ]]
	v14:Stop(0)
	v15:Play(0)
	v16:Stop(0)
	v17.Boom.Enabled = false

	for i = 1, 100 do
		task.wait(0.0075)

		local v1 = Voidbreaker

		v1.PixelsPerStud = v1.PixelsPerStud - 0.5
	end

	v12 = false
	Voidbreaker.Enabled = false
end

local v25 = false

if RunService:IsStudio() then
	sum = 2
end

local function deltaWait(p1) --[[ deltaWait | Line: 519 ]]
	local sum = 0

	repeat
		sum = sum + math.min(task.wait(), 0.06666666666666667)
	until p1 <= sum
end

local function f26() --[[ Line: 528 | Upvalues: v25 (ref), t2 (copy), Dead (copy), Character (copy), count (ref), t (copy), v6 (copy), sum (ref), v7 (copy), SoundService (copy), Debris (copy), SpawnVoidknight (copy), v9 (copy), v22 (ref), ReplicatedStorage (copy), attack (copy), chooseAngle (copy), PlayerVoidbreakerHitbox (ref), v18 (ref), DespawnVoidknight (copy) ]]
	if v25 then
		return
	end

	for v1, v2 in t2 do
		v2.sword:Destroy()
	end

	table.clear(t2)
	v25 = true
	shared.VoidbreakerWishSpawn = false
	_G.VoidbreakerActive = false

	while not Dead.Value and (Character and Character:IsDescendantOf(workspace)) do
		shared.VoidbreakerWishSpawn = false

		if not Character:FindFirstChild("HumanoidRootPart") then
			break
		end

		local v4 = t.LungeLength + t.AttackDelay
		local count2 = 1

		if v6 then
			v4 = t.LungeLength - 0.2
			count2 = count2 * 4
		end

		local v62 = math.clamp(sum / count, 4, 35)

		if v7 then
			v62 = v62 * 1.25
		end

		task.wait(math.random(v62 / 1.5, v62 * 1.25))

		if shared.VoidbreakerWishSpawn or (shared.OperatorWishSpawn or shared.ScrapmawWishSpawn) then
			repeat
				task.wait()
			until not (shared.VoidbreakerWishSpawn or (shared.OperatorWishSpawn or shared.ScrapmawWishSpawn))
		end

		shared.VoidbreakerWishSpawn = true

		if shared.OperatorActive then
			repeat
				task.wait(0.5)
			until not shared.OperatorActive

			task.wait(4)
		end

		if shared.ScrapmawActive then
			repeat
				task.wait(0.5)
			until not shared.ScrapmawActive

			task.wait(4)
		end

		_G.VoidbreakerActive = true
		shared.VoidbreakerWishSpawn = false

		local v72 = SoundService.SFXFolder.Warn:Clone()

		Debris:AddItem(v72, 4)
		v72.Parent = SoundService
		v72:Play()
		SpawnVoidknight()

		if v9 then
			count2 = count2 + 1
		end

		for i = 1, count2 do
			local t3 = {}

			for j = 1, v22 do
				table.insert(t3, j * (360 / v22))
			end

			local v92 = (i - 1) * v4
			local sum2 = 1

			if ReplicatedStorage.Difficulty.Value > 1 then
				sum2 = sum2 + 1
			end

			if v7 then
				sum2 = sum2 + 2
			end

			if v6 then
				sum2 = sum2 + 1
			end

			task.spawn(
				function() --[[ Line: 638 | Upvalues: v92 (copy), sum2 (ref), attack (ref), chooseAngle (ref), t3 (copy), v7 (ref), PlayerVoidbreakerHitbox (ref), v4 (ref), v18 (ref) ]]
					local sum = 0

					repeat
						sum = sum + math.min(task.wait(), 0.06666666666666667)
					until v92 <= sum

					for i = 1, sum2 do
						task.spawn(function() --[[ Line: 642 | Upvalues: attack (ref), chooseAngle (ref), t3 (ref) ]]
							attack(chooseAngle(t3))
						end)
					end

					if not v7 then
						return
					end

					task.spawn(
						function() --[[ Line: 648 | Upvalues: PlayerVoidbreakerHitbox (ref), v4 (ref), v18 (ref) ]]
							task.spawn(function() --[[ Line: 649 | Upvalues: PlayerVoidbreakerHitbox (ref) ]]
								local sum = 0

								repeat
									sum = sum + math.min(task.wait(), 0.06666666666666667)
								until sum >= 0.1

								PlayerVoidbreakerHitbox.Size = Vector3.new(2.25, 2.25, 2.25)
							end)

							local sum = 0

							repeat
								sum = sum + math.min(task.wait(), 0.06666666666666667)
							until v4 <= sum

							local function Update(p1) --[[ Update | Line: 657 | Upvalues: PlayerVoidbreakerHitbox (ref), v18 (ref) ]]
								PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v18, p1)
							end

							local v3 = v18

							PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v3, 0)

							local sum2 = 0
							local v42

							repeat
								sum2 = sum2 + task.wait()
								v42 = sum2 / 0.04
								PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v18, v42)
							until v42 > 1

							local v6 = v18

							PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v6, v42)
						end
					)
				end
			)
		end

		local sum2 = 0
		local v10 = count2 * v4

		repeat
			sum2 = sum2 + math.min(task.wait(), 0.06666666666666667)
		until v10 <= sum2

		local v12 = SoundService.SFXFolder.Disappear:Clone()

		Debris:AddItem(v12, 4)
		v12.Parent = SoundService
		v12:Play()
		DespawnVoidknight()
		_G.VoidbreakerActive = false
	end

	shared.VoidbreakerWishSpawn = false
	_G.VoidbreakerActive = false
	v25 = false
end

function restart() --[[ restart | Line: 693 | Upvalues: v1 (copy) ]]
	script.Parent = nil

	for k, v in pairs(v1:GetChildren()) do
		if v.Name ~= "TEMP" then
			v:Destroy()
		end
	end

	script:Clone().Parent = v1
	script:Destroy()
end
LocalPlayer.CharacterAdded:Connect(function(p1) --[[ Line: 707 ]]
	restart()
end)
f26()

local function _() --[[ Unreferenced function | Upvalues: v1 (ref) ]]
	v1:Destroy()
end

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Voidbreaker.test
-- Took 0.74s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local v1 = script.Parent
local v2 = false

for v3, v4 in workspace.Enemies:GetChildren() do
	if v4.Name == v1.Name and (v4 ~= v1 and v4:GetAttribute("Active")) then
		v2 = true

		break
	end
end

if v2 then
	script:Destroy()

	return
end

script.Parent:SetAttribute("Active", true)

local LocalPlayer = game.Players.LocalPlayer
local Character = LocalPlayer.Character
local Dead = LocalPlayer:WaitForChild("Dead")
local v5 = script.Parent
local GreaterCurseHandler = require(game.ReplicatedFirst.ClientModules.GreaterCurseHandler)
local CurseHandler = require(game.ReplicatedFirst.ClientModules.CurseHandler)
local SettingsHandler = require(game.ReplicatedFirst.ClientModules.Core.PlayerData.SettingsHandler)
local v6 = GreaterCurseHandler.IsCurseEnabled("BalletOfBlades")
local v7 = GreaterCurseHandler.IsCurseEnabled("BladeBombardment")
local v8 = CurseHandler.IsCurseEnabled("BladeCarousel")
local t = {
	LungeLength = 1,
	AttackDelay = 0.4,
	AttackLength = 0.2,
	DisappearLength = 0.2,
}

if v6 then
	t.LungeLength = 0.6
	t.AttackDelay = 1
end

if v7 then
	t.LungeLength = 1.2
	t.AttackLength = 0.075
	t.AttackDelay = 0.8
end

local t2 = {}
local Sword = game.ReplicatedStorage:WaitForChild("Sword")

if v6 then
	Sword = game.ReplicatedStorage:WaitForChild("SwordFast")
end

if v7 then
	Sword = game.ReplicatedStorage:WaitForChild("SwordSlow")
end

local v9 = if game.ReplicatedStorage.Difficulty.Value == 3 then true else false
local count = 1

for k, v in pairs(workspace.Enemies:GetChildren()) do
	if v.Name == "Voidbreaker" and v ~= script.Parent then
		count = count + 1
	end
end

workspace.Enemies.ChildAdded:Connect(function(p1) --[[ Line: 75 | Upvalues: count (ref) ]]
	if p1.Name ~= "Voidbreaker" then
		return
	end

	count = count + 1
end)
workspace.Enemies.ChildRemoved:Connect(function(p1) --[[ Line: 81 | Upvalues: count (ref) ]]
	if p1.Name ~= "Voidbreaker" then
		return
	end

	count = count - 1
end)

local CurrentCamera = workspace.CurrentCamera
local Camera = Instance.new("Camera", v5)

Camera.CFrame = CFrame.new(0, 0, 7)

local v10 = false
local Voidbreaker = LocalPlayer.PlayerGui:WaitForChild("Voidbreaker")

Voidbreaker.ViewportFrame.CurrentCamera = Camera

local Voidknight = Voidbreaker.ViewportFrame.World.Voidknight
local Animator = Voidknight.AnimationController.Animator
local v11 = Animator:LoadAnimation(game.ReplicatedStorage.Voidknight:WaitForChild("SpawnAnim"))
local v12 = Animator:LoadAnimation(game.ReplicatedStorage.Voidknight:WaitForChild("Idle"))

v12.Priority = Enum.AnimationPriority.Idle

local v13 = Animator:LoadAnimation(game.ReplicatedStorage.Voidknight:WaitForChild("Despawn"))
local v14 = Animator:LoadAnimation(game.ReplicatedStorage.Voidknight:WaitForChild("Attack"))
local Sounds = Instance.new("Folder", v5)

Sounds.Name = "Sounds"

local v15 = game.ReplicatedStorage.Assets.Voidbreaker:WaitForChild("Lighting"):Clone()

v15.Parent = v5
Voidbreaker.Adornee = v5
_G.VoidbreakerActive = false
shared.VoidbreakerWishSpawn = false

if not workspace:FindFirstChild("VoidbreakerVisualizers") then
	local VoidbreakerVisualizers = Instance.new("Folder")

	VoidbreakerVisualizers.Name = "VoidbreakerVisualizers"
	VoidbreakerVisualizers.Parent = workspace

	local Highlight = Instance.new("Highlight")

	Highlight.OutlineTransparency = 0
	Highlight.OutlineColor = Color3.new(0 / 255, 0 / 255, 0 / 255)
	Highlight.FillColor = Color3.new(0 / 255, 0 / 255, 0 / 255)
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.FillTransparency = 0
	Highlight.Parent = VoidbreakerVisualizers
end

local v16 = if v8 and v7 then 1.25 else 1.5
local v18 = if v7 then 2.25 else v16
local v19 = Vector3.new(1, 1, 1) * v18
local PlayerVoidbreakerHitbox = workspace:FindFirstChild("PlayerVoidbreakerHitbox")

if not PlayerVoidbreakerHitbox then
	PlayerVoidbreakerHitbox = Instance.new("Part")
	PlayerVoidbreakerHitbox.Size = v19
	PlayerVoidbreakerHitbox.Shape = Enum.PartType.Ball
	PlayerVoidbreakerHitbox.Anchored = true
	PlayerVoidbreakerHitbox.CanCollide = false
	PlayerVoidbreakerHitbox.CanTouch = false
	PlayerVoidbreakerHitbox.CanQuery = false
	PlayerVoidbreakerHitbox.Color = Color3.new(153 / 255, 0 / 255, 0 / 255)
	PlayerVoidbreakerHitbox.Material = Enum.Material.Neon
	PlayerVoidbreakerHitbox.Name = "PlayerVoidbreakerHitbox"
	PlayerVoidbreakerHitbox.Transparency = 1
	PlayerVoidbreakerHitbox.Parent = workspace
end

local v20 = if v6 then 16 else 8

local function chooseAngle(p1) --[[ chooseAngle | Line: 162 ]]
	if #p1 == 0 then
		return
	end

	local v1 = math.random(1, #p1)

	table.remove(p1, v1)

	return p1[v1]
end

local function attack(p1) --[[ attack | Line: 172 | Upvalues: Sword (ref), SettingsHandler (copy), t2 (copy) ]]
	if not p1 then
		return
	end

	local v1 = Sword:Clone()

	if SettingsHandler.Get({ "Graphics", "Colorblind" }) then
		v1.Model2.Color = Color3.fromRGB(255, 120, 0)
		v1.Color = Color3.fromRGB(180, 90, 0)
		v1.Model1.Highlight.OutlineColor = Color3.fromRGB(255, 120, 0)
		v1.Model1.Highlight.FillColor = Color3.fromRGB(180, 90, 0)
	end

	v1.Parent = script.Parent
	table.insert(t2, {
		elapsed = 0,
		spinRad = 0,
		target = Vector3.new(0, 0, 0),
		state = 0,
		sword = v1,
		time = os.clock(),
		rad = math.rad(p1),
		rand = math.random(),
	})
end

local v21 = if v7 or v6 then 1.5 else 2

local function shootSound(p1) --[[ shootSound | Line: 203 | Upvalues: v7 (copy), v6 (copy), Sounds (copy) ]]
	if v7 and not v6 then
		local v1 = game.ReplicatedStorage.Assets.Voidbreaker.Sounds.Bombardment:GetChildren()[math.random(1, 2)]:Clone()

		v1.Parent = Sounds
		v1:Play()
		v1.Ended:Once(function() --[[ Line: 209 | Upvalues: v1 (copy) ]]
			v1:Destroy()
		end)

		return
	end

	if not v6 or v7 then
		local v2 = game.ReplicatedStorage.Assets.Voidbreaker.Sounds.Default:GetChildren()[math.random(1, 2)]:Clone()

		v2.Parent = Sounds
		v2:Play()
		v2.Ended:Once(function() --[[ Line: 234 | Upvalues: v2 (copy) ]]
			v2:Destroy()
		end)

		return
	end

	if p1 then
		local FinalBallet = game.ReplicatedStorage.Assets.Voidbreaker.Sounds.FinalBallet

		FinalBallet.Parent = Sounds
		FinalBallet:Play()
		FinalBallet.Ended:Once(function() --[[ Line: 225 | Upvalues: FinalBallet (copy) ]]
			FinalBallet:Destroy()
		end)
	else
		local v3 = game.ReplicatedStorage.Assets.Voidbreaker.Sounds.Ballet:GetChildren()[math.random(1, 4)]:Clone()

		v3.Parent = Sounds
		v3:Play()
		v3.Ended:Once(function() --[[ Line: 218 | Upvalues: v3 (copy) ]]
			v3:Destroy()
		end)
	end
end

local v22 = if v7 then -6 else -2.5

local function renderStepped(p1) --[[ renderStepped | Line: 242 | Upvalues: Dead (copy), Character (copy), Voidbreaker (copy), v12 (copy), v5 (copy), CurrentCamera (copy), PlayerVoidbreakerHitbox (ref), Camera (copy), t2 (copy), Sounds (copy), v10 (ref), v15 (copy), v14 (copy), v8 (copy), t (copy), v21 (copy), v9 (copy), shootSound (copy), v22 (copy) ]]
	local v1 = math.min(p1, 0.06666666666666667)

	if Dead.Value or (not Character or not Character:FindFirstChild("HumanoidRootPart") and Voidbreaker.Enabled) then
		Voidbreaker.Enabled = false

		if not v12.IsPlaying then
			return
		end

		v12:Stop()
	else
		if not (v5 and v5.Parent) then
			return
		end

		if not (Character:FindFirstChild("HumanoidRootPart") and (Character and Character.Parent)) then
			return
		end

		local Humanoid = Character:FindFirstChild("Humanoid")

		if not Humanoid then
			return
		end

		local RootPart = Humanoid.RootPart
		local Position = RootPart.Position
		local v2 = RootPart.Velocity * Vector3.new(1, 0, 1)
		local v3, v4

		if v2.Magnitude > 0.001 then
			v3 = v2.Unit
			v4 = v1

			if not v3 then
				v3 = Vector3.new(0, 0, 0)
			end
		else
			v4 = v1
			v3 = Vector3.new(0, 0, 0)
		end

		local v6 = math.clamp(v2.Magnitude / 5.333333333333333, -3, 3)
		local v7 = CurrentCamera.CFrame
		local v82 = v5.CFrame
		local v92 = CFrame.new(RootPart.Position) + v3 * v6

		PlayerVoidbreakerHitbox.CFrame = v92
		PlayerVoidbreakerHitbox.CanQuery = true

		local v102 = CFrame.lookAt(v82.Position, v7.Position)
			- v82.Position
			+ (Character.HumanoidRootPart.Position + Vector3.new(0, 2, -13))

		v5.CFrame = v102

		local Position2 = v7.Position
		local v11 = CFrame.lookAt(Position2, v102.Position) - Position2
		local v122 = v11:Lerp(v11, 0.01)

		Camera.CFrame = v122 + v122.LookVector * -11
		os.clock()

		local t3 = {}

		for v13, v142 in t2 do
			local sword = v142.sword

			v142.elapsed = v142.elapsed + v4

			local elapsed = v142.elapsed

			if v142.state == 0 then
				local Unsheath = sword.Unsheath

				Unsheath.Parent = Sounds
				Unsheath:Play()
				sword.Model1.Aura.Enabled = true
				sword.Rune.Runes:Emit(1)

				if not v10 then
					v10 = true
					v15.Runes:Emit(1)
					v14:Play()
				end

				v142.state = 1
			end

			v142.target = Position

			local Position3 = (RootPart.CFrame * (v92:Inverse() * RootPart.CFrame)).Position
			local v16 = v142.rad + (if v8 then v142.spinRad else 0)
			local v19 = Position3 + Vector3.new(math.sin(v16), 0, (math.cos(v16))) * 8
			local v20 = CFrame.Angles(-1.5707963267948966, v142.rand * math.pi + elapsed * math.pi / 2, 0)
			local v212 = t.LungeLength + t.AttackDelay

			if v142.state == 1 then
				local v23 = math.clamp(elapsed / t.LungeLength, 0, 1)

				sword.CFrame = CFrame.new(v19 - Vector3.new(0, 1, 0), v19)
					:Lerp(CFrame.new(v19, Position3), (math.pow(v23, 2))) * v20

				local v24 = 1 - math.sqrt(v23)

				sword.LocalTransparencyModifier = v24
				sword.Model1.Aura.TimeScale = v23 / 1.5
				sword.Model1.Highlight.OutlineTransparency = v24
				sword.Model1.LocalTransparencyModifier = v24
				sword.Model2.LocalTransparencyModifier = v24
				v142.spinRad = elapsed * v21

				if v212 <= elapsed then
					v142.state = 2
					v142.spinRad = v212 * v21

					if not v9 then
						sword.Model1.Fire.Aura:Emit(math.random(7, 10))
					end

					shootSound(false)
					sword.Model1.Aura.Enabled = false
				end
			end

			if v142.state >= 2 then
				local v25 = elapsed - v212
				local v26 = CFrame.new(v19, Position3) * CFrame.new(0, 0, -v25 * 8 / t.AttackLength)

				sword.CFrame = v26 * v20 * CFrame.Angles(0, v25 * math.pi * 2, 0)

				if t.AttackLength < v25 then
					local v28 = math.min((v25 - t.AttackLength) / t.DisappearLength, 1)
					local v29 = math.sqrt(v28)

					sword.LocalTransparencyModifier = v29
					sword.Model1.LocalTransparencyModifier = v29
					sword.Model2.LocalTransparencyModifier = v29
					sword.Model1.Highlight.OutlineTransparency = v28

					if v28 == 1 then
						v142.state = 3
						table.insert(t3, v142)
					end

					continue
				end

				if v142.state == 2 then
					local v30 = RaycastParams.new()

					v30.FilterType = Enum.RaycastFilterType.Include
					v30.FilterDescendantsInstances = { PlayerVoidbreakerHitbox }
					v30.RespectCanCollide = false

					local v31 = workspace:Raycast(v26.Position + v26.ZVector * 2, v26.ZVector * v22, v30)

					if v31 and v31.Instance then
						v142.state = 3
						game.ReplicatedStorage.Events.Died:FireServer(
							"Voidbreaker",
							nil,
							game.ReplicatedStorage.Level.Value
						)

						break
					end
				end
			end
		end

		for v32, v33 in t3 do
			local v34 = table.find(t2, v33)

			if v34 then
				table.remove(t2, v34)
				v33.sword:Destroy()
			end
		end

		PlayerVoidbreakerHitbox.CanQuery = false
	end
end

game:GetService("RunService"):UnbindFromRenderStep("Voidbreaker")
game:GetService("RunService"):BindToRenderStep("Voidbreaker", Enum.RenderPriority.Character.Value + 10, renderStepped)

local sum = if v9 then 30 else 35

if game.ReplicatedStorage.Solo.Value == true then
	sum = sum + 10
end

local function SpawnVoidknight() --[[ SpawnVoidknight | Line: 458 | Upvalues: v11 (copy), v13 (copy), v12 (copy), v15 (copy), Voidbreaker (copy), Voidknight (copy) ]]
	v11:Play(0)
	v13:Stop(0)
	v12:Play()
	v15.Boom.Enabled = true
	Voidbreaker.PixelsPerStud = 0
	Voidbreaker.Enabled = true
	task.spawn(function() --[[ Line: 465 | Upvalues: Voidknight (ref) ]]
		task.wait(0.217)
		Voidknight.Sword.Smear.Transparency = 0
		task.wait(0.1)
		Voidknight.Sword.Smear.Transparency = 1
	end)

	for i = 1, 50 do
		task.wait(0.018000000000000002)

		local v1 = Voidbreaker

		v1.PixelsPerStud = v1.PixelsPerStud + 1
	end
end

local function DespawnVoidknight() --[[ DespawnVoidknight | Line: 477 | Upvalues: v12 (copy), v13 (copy), v14 (copy), v15 (copy), Voidbreaker (copy), v10 (ref) ]]
	v12:Stop(0)
	v13:Play(0)
	v14:Stop(0)
	v15.Boom.Enabled = false

	for i = 1, 100 do
		task.wait(0.0075)

		local v1 = Voidbreaker

		v1.PixelsPerStud = v1.PixelsPerStud - 0.5
	end

	v10 = false
	Voidbreaker.Enabled = false
end

local v23 = false

game:GetService("RunService"):IsStudio()

local function deltaWait(p1) --[[ deltaWait | Line: 499 ]]
	local sum = 0

	repeat
		sum = sum + math.min(task.wait(), 0.06666666666666667)
	until p1 <= sum
end

local function f24() --[[ Line: 508 | Upvalues: v23 (ref), t2 (copy), Dead (copy), Character (copy), count (ref), t (copy), v6 (copy), sum (ref), v7 (copy), SpawnVoidknight (copy), v9 (copy), v20 (ref), attack (copy), chooseAngle (copy), PlayerVoidbreakerHitbox (ref), v16 (ref), DespawnVoidknight (copy) ]]
	if v23 then
		return
	end

	for v1, v2 in t2 do
		v2.sword:Destroy()
	end

	table.clear(t2)
	v23 = true
	shared.VoidbreakerWishSpawn = false
	_G.VoidbreakerActive = false

	while not Dead.Value and Character:IsDescendantOf(workspace) do
		shared.VoidbreakerWishSpawn = false

		if not Character:FindFirstChild("HumanoidRootPart") then
			break
		end

		local v4 = t.LungeLength + t.AttackDelay
		local count2 = 1

		if v6 then
			v4 = t.LungeLength - 0.2
			count2 = count2 * 4
		end

		local v62 = math.clamp(sum / count, 4, 35)

		if v7 then
			v62 = v62 * 1.25
		end

		task.wait(math.random(v62 / 1.5, v62 * 1.25))

		if shared.VoidbreakerWishSpawn or (shared.OperatorWishSpawn or shared.ScrapmawWishSpawn) then
			repeat
				task.wait()
			until not (shared.VoidbreakerWishSpawn or (shared.OperatorWishSpawn or shared.ScrapmawWishSpawn))
		end

		shared.VoidbreakerWishSpawn = true

		if shared.OperatorActive then
			repeat
				task.wait(0.5)
			until not shared.OperatorActive

			task.wait(4)
		end

		if shared.ScrapmawActive then
			repeat
				task.wait(0.5)
			until not shared.ScrapmawActive

			task.wait(4)
		end

		_G.VoidbreakerActive = true
		shared.VoidbreakerWishSpawn = false

		local v72 = game.SoundService.SFXFolder.Warn:Clone()

		game:GetService("Debris"):AddItem(v72, 4)
		v72.Parent = game.SoundService
		v72:Play()
		SpawnVoidknight()

		if v9 then
			count2 = count2 + 1
		end

		for i = 1, count2 do
			local t3 = {}

			for j = 1, v20 do
				table.insert(t3, j * (360 / v20))
			end

			local v92 = (i - 1) * v4
			local sum2 = 1

			if game.ReplicatedStorage.Difficulty.Value > 1 then
				sum2 = sum2 + 1
			end

			if v7 then
				sum2 = sum2 + 2
			end

			if v6 then
				sum2 = sum2 + 1
			end

			task.spawn(
				function() --[[ Line: 618 | Upvalues: v92 (copy), sum2 (ref), attack (ref), chooseAngle (ref), t3 (copy), v7 (ref), PlayerVoidbreakerHitbox (ref), v4 (ref), v16 (ref) ]]
					local sum = 0

					repeat
						sum = sum + math.min(task.wait(), 0.06666666666666667)
					until v92 <= sum

					for i = 1, sum2 do
						task.spawn(function() --[[ Line: 622 | Upvalues: attack (ref), chooseAngle (ref), t3 (ref) ]]
							attack(chooseAngle(t3))
						end)
					end

					if not v7 then
						return
					end

					task.spawn(
						function() --[[ Line: 628 | Upvalues: PlayerVoidbreakerHitbox (ref), v4 (ref), v16 (ref) ]]
							task.spawn(function() --[[ Line: 629 | Upvalues: PlayerVoidbreakerHitbox (ref) ]]
								local sum = 0

								repeat
									sum = sum + math.min(task.wait(), 0.06666666666666667)
								until sum >= 0.1

								PlayerVoidbreakerHitbox.Size = Vector3.new(2.25, 2.25, 2.25)
							end)

							local sum = 0

							repeat
								sum = sum + math.min(task.wait(), 0.06666666666666667)
							until v4 <= sum

							local function Update(p1) --[[ Update | Line: 637 | Upvalues: PlayerVoidbreakerHitbox (ref), v16 (ref) ]]
								PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v16, p1)
							end

							local v3 = v16

							PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v3, 0)

							local sum2 = 0
							local v42

							repeat
								sum2 = sum2 + task.wait()
								v42 = sum2 / 0.04
								PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v16, v42)
							until v42 > 1

							local v6 = v16

							PlayerVoidbreakerHitbox.Size = Vector3.new(1, 1, 1) * math.lerp(2.25, v6, v42)
						end
					)
				end
			)
		end

		local sum2 = 0
		local v10 = count2 * v4

		repeat
			sum2 = sum2 + math.min(task.wait(), 0.06666666666666667)
		until v10 <= sum2

		local v12 = game.SoundService.SFXFolder.Disappear:Clone()

		game:GetService("Debris"):AddItem(v12, 4)
		v12.Parent = game.SoundService
		v12:Play()
		DespawnVoidknight()
		_G.VoidbreakerActive = false
	end

	shared.VoidbreakerWishSpawn = false
	_G.VoidbreakerActive = false
	v23 = false
end

function restart() --[[ restart | Line: 673 | Upvalues: v1 (copy) ]]
	script.Parent = nil

	for k, v in pairs(v1:GetChildren()) do
		if v.Name ~= "TEMP" then
			v:Destroy()
		end
	end

	script:Clone().Parent = v1
	script:Destroy()
end
LocalPlayer.CharacterAdded:Connect(function(p1) --[[ Line: 687 ]]
	restart()
end)
f24()

local function _() --[[ Unreferenced function | Upvalues: v1 (ref) ]]
	v1:Destroy()
end

-- Script Path: game:GetService("ReplicatedStorage").EnemyFolder.Enemies.Cadence.Cadence_ClientAI
-- Took 0.6s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local v1 = script.Parent
local Assets = ReplicatedStorage.Assets
local sprite = v1:WaitForChild("SpritePart", 1000):WaitForChild("SurfaceGui", 1000):WaitForChild("sprite", 1000)
local ClientEvent = v1:WaitForChild("ClientEvent")
local UpdatePosition = v1:WaitForChild("UpdatePosition")
local v2 = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local v3 = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local v4 = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local v5 = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local v6 = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local v7 = TweenInfo.new(0.75, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local v8 = TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local v9 = TweenInfo.new(1.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

local function f10() --[[ Line: 64 | Upvalues: TweenService (copy), v1 (copy), v3 (copy), v6 (copy), v2 (copy) ]]
	TweenService:Create(v1.Layers.TickStage1, v3, {
		Volume = 0,
	}):Play()
	TweenService:Create(v1.Layers.TickStage2, v3, {
		Volume = 0,
	}):Play()
	TweenService:Create(v1.Layers.TickStage3, v3, {
		Volume = 0,
	}):Play()
	TweenService:Create(v1.Layers.AlarmStage1, v3, {
		Volume = 0,
	}):Play()
	TweenService:Create(v1.Layers.AlarmStage2, v3, {
		Volume = 0,
	}):Play()
	TweenService:Create(v1.Layers.BellsStage1, v3, {
		Volume = 0,
	}):Play()
	TweenService:Create(v1.Layers.ChoirStage1, v3, {
		Volume = 0,
	}):Play()
	v1.Chase.PlaybackSpeed = 0
	v1.Chase.Volume = 0
	v1.Chase:Play()
	v1.rage.sprite.Rotation = 0
	v1.rage.sprite.scale.Value = 0
	v1.hands.sprite.scale.Value = 0
	v1.hands.sprite.Rotation = 45
	TweenService:Create(v1.hands.sprite.scale, v6, {
		Value = 58,
	}):Play()
	TweenService:Create(v1.rage.sprite.scale, v6, {
		Value = 16,
	}):Play()
	TweenService:Create(v1.hands.sprite, v3, {
		ImageTransparency = 0,
		Rotation = 0,
	}):Play()
	TweenService:Create(v1.rage.sprite, v3, {
		ImageTransparency = 0,
	}):Play()
	task.wait(1)

	if not v1.Chase.IsPlaying then
		return
	end

	TweenService:Create(v1.Chase, v2, {
		PlaybackSpeed = 1,
		Volume = 1,
	}):Play()
end

local function f11() --[[ Line: 91 | Upvalues: sprite (copy), TweenService (copy), v9 (copy), v1 (copy), v6 (copy) ]]
	local v2 = math.random(25, 45)

	sprite.Rotation = v2 * math.sign(math.random() - 0.5)
	TweenService:Create(sprite, v9, {
		Rotation = 0,
	}):Play()
	TweenService:Create(v1.hands.sprite.scale, v6, {
		Value = 0,
	}):Play()
	TweenService:Create(v1.rage.sprite.scale, v6, {
		Value = 0,
	}):Play()
	TweenService:Create(v1.hands.sprite, v6, {
		ImageTransparency = 1,
		Rotation = 90,
	}):Play()
	TweenService:Create(v1.rage.sprite, v6, {
		ImageTransparency = 1,
		Rotation = -90,
	}):Play()
	v1.Chase:Stop()
end

local function f12(p1) --[[ Line: 101 | Upvalues: TweenService (copy), v7 (copy), v5 (copy), v6 (copy) ]]
	TweenService:Create(p1, v7, {
		TextureSpeed = -13,
	}):Play()
	TweenService:Create(p1, v5, {
		Width0 = 0,
		Width1 = 0,
		Brightness = 0,
	}):Play()
	TweenService:Create(p1, v6, {
		CurveSize0 = 35,
		CurveSize1 = 30,
	}):Play()
end

local function f13(p1) --[[ Line: 107 | Upvalues: TweenService (copy) ]]
	TweenService:Create(p1, TweenInfo.new(1.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		TextureSpeed = 1,
	}):Play()
	TweenService:Create(p1, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Width0 = 20,
	}):Play()
	TweenService:Create(p1, TweenInfo.new(0.37, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Width1 = 20,
	}):Play()
	TweenService:Create(p1, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 6,
	}):Play()
	TweenService:Create(p1, TweenInfo.new(1.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		CurveSize0 = 0,
	}):Play()
	TweenService:Create(p1, TweenInfo.new(0.75, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		CurveSize1 = 0,
	}):Play()
end

local function f14(p1) --[[ Line: 118 | Upvalues: TweenService (copy), v8 (copy), v6 (copy) ]]
	local v1 = math.random(30, 40)

	p1.Rotation = v1 * math.sign(math.random() - 0.5)
	p1.ImageTransparency = 1
	TweenService:Create(p1, v8, {
		Rotation = 0,
	}):Play()
	TweenService:Create(p1, v6, {
		ImageTransparency = 0,
	}):Play()
end

local t = {
	function() --[[ Line: 24 | Upvalues: TweenService (copy), v1 (copy), v2 (copy) ]]
		TweenService:Create(v1.Layers.TickStage1, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.TickStage2, v2, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.TickStage3, v2, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage1, v2, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage2, v2, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.BellsStage1, v2, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.ChoirStage1, v2, {
			Volume = 0,
		}):Play()
	end,
	function() --[[ Line: 34 | Upvalues: TweenService (copy), v1 (copy), v2 (copy), v4 (copy) ]]
		TweenService:Create(v1.Layers.TickStage1, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.TickStage2, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.TickStage3, v2, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage1, v4, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage2, v4, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.BellsStage1, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.ChoirStage1, v2, {
			Volume = 0.2,
			PlaybackSpeed = 0.8,
		}):Play()
	end,
	function() --[[ Line: 44 | Upvalues: TweenService (copy), v1 (copy), v2 (copy), v4 (copy) ]]
		TweenService:Create(v1.Layers.TickStage1, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.TickStage2, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.TickStage3, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage1, v4, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage2, v4, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.BellsStage1, v2, {
			Volume = 2,
		}):Play()
		TweenService:Create(v1.Layers.ChoirStage1, v2, {
			Volume = 0.4,
			PlaybackSpeed = 0.9,
		}):Play()
	end,
	function() --[[ Line: 54 | Upvalues: TweenService (copy), v1 (copy), v2 (copy), v3 (copy) ]]
		TweenService:Create(v1.Layers.TickStage1, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.TickStage2, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.TickStage3, v2, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage1, v3, {
			Volume = 0,
		}):Play()
		TweenService:Create(v1.Layers.AlarmStage2, v3, {
			Volume = 1,
		}):Play()
		TweenService:Create(v1.Layers.BellsStage1, v2, {
			Volume = 2.5,
		}):Play()
		TweenService:Create(v1.Layers.ChoirStage1, v2, {
			Volume = 0.6,
			PlaybackSpeed = 0.95,
		}):Play()
	end,
}

ClientEvent.OnClientEvent:Connect(
	function(p1, p2) --[[ Line: 130 | Upvalues: t (copy), f10 (copy), f12 (copy), f14 (copy), f13 (copy), TweenService (copy), v6 (copy), f11 (copy) ]]
		if p1 == "Stage" then
			t[p2.Stage]()

			return
		end

		if p1 == "Chase" then
			f10()

			return
		end

		if p1 == "ChainBreak" then
			f12(p2.Chain)

			return
		end

		if p1 == "SpawnSprite" then
			f14(p2.Sprite)

			return
		end

		if p1 == "SpawnBeam" then
			f13(p2.Beam)

			return
		end

		if p1 == "FadeSprite" then
			TweenService:Create(p2.Sprite, v6, {
				ImageTransparency = 1,
			}):Play()

			return
		end

		if p1 ~= "ElasticStop" then
			return
		end

		f11()
	end
)

local v15 = script.Parent
local v16 = v15.CFrame
local v17 = nil
local v18 = time()

UpdatePosition.OnClientEvent:Connect(function(p1) --[[ Line: 157 | Upvalues: v17 (ref), v16 (ref), v18 (ref) ]]
	v17 = v16
	v16 = CFrame.new(p1)
	v18 = time()
end)
RunService.Heartbeat:Connect(
	function(p1) --[[ Line: 165 | Upvalues: v15 (copy), Assets (copy), TweenService (copy), Debris (copy), v18 (ref), v16 (ref), v17 (ref) ]]
		task.spawn(function() --[[ Line: 166 | Upvalues: v15 (ref), Assets (ref), TweenService (ref), Debris (ref) ]]
			if v15:GetAttribute("Active") ~= true then
				return
			end

			task.wait(0.15)

			local v1 = math.random(5, 12)
			local v2 = math.random(5, 12)
			local v3 = math.random(6, 12)
			local v4 = if math.random(1, 2) == 1 then v1 * -1 else v1
			local v5 = if math.random(1, 2) == 1 then v2 * -1 else v2

			if math.random(1, 2) == 1 then
				v3 = v3 * -1
			end

			local v6 = math.random(0.5, 1.25)
			local v7 = math.random(0.5, 1.25)
			local v8 = math.random(0.5, 1.25)
			local v9 = if math.random(1, 2) == 1 then v6 * -1 else v6
			local v10 = if math.random(1, 2) == 1 then v7 * -1 else v7

			if math.random(1, 2) == 1 then
				v8 = v8 * -1
			end

			local v11 = Assets.Icosphere:Clone()
			local v12 = Assets.Icosphere:Clone()

			v11.Parent = workspace.CadenceDebris
			v11.Color = Color3.fromRGB(0, 0, 0)
			v11.Size = Vector3.new(44, 44, 44)
			v11.Position = v15.Position + Vector3.new(v9, v10, v8)
			TweenService:Create(v11, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = Vector3.new(0, 0, 0),
			}):Play()
			v12.Parent = workspace.CadenceDebris
			v12.Color = Color3.fromRGB(0, 0, 0)
			v12.Size = Vector3.new(29, 31, 29)
			v12.Position = v15.Position + Vector3.new(v4, v5, v3)
			TweenService:Create(v12, TweenInfo.new(1.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Size = Vector3.new(0, 0, 0),
			}):Play()
			Debris:AddItem(v11, 2)
			Debris:AddItem(v12, 1.5)
		end)

		local v2 = math.clamp((time() - v18) / 0.0625, 0, 1)

		if not (v16 and v17) then
			return
		end

		v15.CFrame = v17:Lerp(v16, v2)
	end
)
