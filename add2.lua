-- Script Path: game:GetService("StarterPlayer").StarterCharacterScripts.RadarSlop
-- Took 0.4s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local CollectionService = game:GetService("CollectionService")
local UpgradeHandler = require(game.ReplicatedFirst.ClientModules.UpgradeHandler)
local HumanoidRootPart = script.Parent:WaitForChild("HumanoidRootPart")
local Humanoid = script.Parent:WaitForChild("Humanoid")
local AltarColors = require(game.ReplicatedStorage.Altars.AltarColors)
local v1 = Random.new()

local function f2() --[[ Line: 13 | Upvalues: HumanoidRootPart (copy), v1 (copy) ]]
	for v12, v2 in game.Players:GetPlayers() do
		if v2 ~= game.Players.LocalPlayer then
			local Character = v2.Character

			if Character and Character.Parent then
				local HumanoidRootPart2 = Character:FindFirstChild("HumanoidRootPart")

				if HumanoidRootPart2 then
					local Magnitude = (HumanoidRootPart2.Position - HumanoidRootPart.Position).Magnitude

					if not (Magnitude > 1024) then
						task.delay(Magnitude / 1024, function() --[[ Line: 27 | Upvalues: Character (copy), v1 (ref) ]]
							local Highlight = Instance.new("Highlight")

							Highlight.FillTransparency = 1

							if Character.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
								Highlight.OutlineColor = Color3.new(255 / 255, 0 / 255, 0 / 255)
							end

							Highlight.Parent = Character
							game.TweenService
								:Create(Highlight, TweenInfo.new(8, Enum.EasingStyle.Linear), {
									OutlineTransparency = 1,
								})
								:Play()
							game.Debris:AddItem(Highlight, 8.1)
							game.SoundService.SFXFolder.Radar_Player.PlaybackSpeed = v1:NextNumber(0.9, 1.1)
							game.SoundService.SFXFolder.Radar_Player:Play()
						end)
					end
				end
			end
		end
	end
end

local function f3() --[[ Line: 47 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), AltarColors (copy), v1 (copy) ]]
	for k, v in pairs(CollectionService:GetTagged("Altar")) do
		local v12 = v:FindFirstChild("RealName") and v.RealName.Value or ""
		local v2 = v.Parent
		local HitBox = v2:FindFirstChild("HitBox")

		if HitBox and (v2:FindFirstChild("Altar") and not v2:GetAttribute("AltarUsed")) then
			local Magnitude = (v2.HitBox.Position - HumanoidRootPart.Position).Magnitude

			if not (Magnitude > 1024) then
				task.delay(
					Magnitude / 2048,
					function() --[[ Line: 58 | Upvalues: HitBox (copy), AltarColors (ref), v12 (copy), v1 (ref) ]]
						if not HitBox or HitBox.Parent == nil then
							return
						end

						local v13 = script:WaitForChild("AltarPing"):Clone()

						v13.Parent = HitBox
						v13.Tweened.ImageColor3 = AltarColors[v12] or Color3.new(0 / 255, 0 / 255, 0 / 255)
						v13.ImageLabel.ImageColor3 = AltarColors[v12] or Color3.new(0 / 255, 0 / 255, 0 / 255)
						v13.Enabled = true
						game.TweenService
							:Create(v13.Tweened, TweenInfo.new(1), {
								ImageTransparency = 1,
								Size = UDim2.fromScale(12, 12),
							})
							:Play()
						game.TweenService
							:Create(v13.ImageLabel, TweenInfo.new(10), {
								ImageTransparency = 1,
								Size = UDim2.fromScale(0, 0),
							})
							:Play()
						game.TweenService
							:Create(v13.Outline, TweenInfo.new(10), {
								ImageTransparency = 1,
								Size = UDim2.fromScale(0, 0),
							})
							:Play()
						game.Debris:AddItem(v13, 10.1)
						game.SoundService.SFXFolder.Radar_Altar.PlaybackSpeed = v1:NextNumber(0.97, 1.03)
						game.SoundService.SFXFolder.Radar_Altar:Play()
					end
				)
			end
		end
	end
end

local function f4() --[[ Line: 79 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), v1 (copy) ]]
	for k, v in pairs(CollectionService:GetTagged("CadenceOrb")) do
		if v.CanTouch then
			local Magnitude = (v.Position - HumanoidRootPart.Position).Magnitude

			if not (Magnitude > 1024) then
				task.delay(Magnitude / 2048, function() --[[ Line: 89 | Upvalues: v (copy), v1 (ref) ]]
					local v12 = script:WaitForChild("CadencePing"):Clone()

					v12.Parent = v
					v12.Enabled = true
					game.TweenService
						:Create(v12.Tweened, TweenInfo.new(1), {
							ImageTransparency = 1,
							Size = UDim2.fromScale(12, 12),
						})
						:Play()
					game.TweenService
						:Create(v12.ImageLabel, TweenInfo.new(10), {
							ImageTransparency = 1,
							Size = UDim2.fromScale(0, 0),
						})
						:Play()
					game.Debris:AddItem(v12, 10.1)
					game.SoundService.SFXFolder.Radar_Instruments.PlaybackSpeed = v1:NextNumber(1.95, 2.05)
					game.SoundService.SFXFolder.Radar_Instruments:Play()
				end)
			end
		end
	end
end

while task.wait(12) and Humanoid:GetState() ~= Enum.HumanoidStateType.Dead do
	if UpgradeHandler.IsUpgradeEnabled("RadarPlayer") then
		task.spawn(f2)
	end

	if UpgradeHandler.IsUpgradeEnabled("RadarAltars") then
		task.spawn(f3)
	end

	if UpgradeHandler.IsUpgradeEnabled("RadarInstruments") then
		task.spawn(f4)
	end
end

-- Script Path: game:GetService("Workspace").Noriko_Ellen.RadarSlop
-- Took 0.41s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local CollectionService = game:GetService("CollectionService")
local UpgradeHandler = require(game.ReplicatedFirst.ClientModules.UpgradeHandler)
local HumanoidRootPart = script.Parent:WaitForChild("HumanoidRootPart")
local Humanoid = script.Parent:WaitForChild("Humanoid")
local AltarColors = require(game.ReplicatedStorage.Altars.AltarColors)
local v1 = Random.new()

local function f2() --[[ Line: 13 | Upvalues: HumanoidRootPart (copy), v1 (copy) ]]
	for v12, v2 in game.Players:GetPlayers() do
		if v2 ~= game.Players.LocalPlayer then
			local Character = v2.Character

			if Character and Character.Parent then
				local HumanoidRootPart2 = Character:FindFirstChild("HumanoidRootPart")

				if HumanoidRootPart2 then
					local Magnitude = (HumanoidRootPart2.Position - HumanoidRootPart.Position).Magnitude

					if not (Magnitude > 1024) then
						task.delay(Magnitude / 1024, function() --[[ Line: 27 | Upvalues: Character (copy), v1 (ref) ]]
							local Highlight = Instance.new("Highlight")

							Highlight.FillTransparency = 1

							if Character.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
								Highlight.OutlineColor = Color3.new(255 / 255, 0 / 255, 0 / 255)
							end

							Highlight.Parent = Character
							game.TweenService
								:Create(Highlight, TweenInfo.new(8, Enum.EasingStyle.Linear), {
									OutlineTransparency = 1,
								})
								:Play()
							game.Debris:AddItem(Highlight, 8.1)
							game.SoundService.SFXFolder.Radar_Player.PlaybackSpeed = v1:NextNumber(0.9, 1.1)
							game.SoundService.SFXFolder.Radar_Player:Play()
						end)
					end
				end
			end
		end
	end
end

local function f3() --[[ Line: 47 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), AltarColors (copy), v1 (copy) ]]
	for k, v in pairs(CollectionService:GetTagged("Altar")) do
		local v12 = v:FindFirstChild("RealName") and v.RealName.Value or ""
		local v2 = v.Parent
		local HitBox = v2:FindFirstChild("HitBox")

		if HitBox and (v2:FindFirstChild("Altar") and not v2:GetAttribute("AltarUsed")) then
			local Magnitude = (v2.HitBox.Position - HumanoidRootPart.Position).Magnitude

			if not (Magnitude > 1024) then
				task.delay(
					Magnitude / 2048,
					function() --[[ Line: 58 | Upvalues: HitBox (copy), AltarColors (ref), v12 (copy), v1 (ref) ]]
						if not HitBox or HitBox.Parent == nil then
							return
						end

						local v13 = script:WaitForChild("AltarPing"):Clone()

						v13.Parent = HitBox
						v13.Tweened.ImageColor3 = AltarColors[v12] or Color3.new(0 / 255, 0 / 255, 0 / 255)
						v13.ImageLabel.ImageColor3 = AltarColors[v12] or Color3.new(0 / 255, 0 / 255, 0 / 255)
						v13.Enabled = true
						game.TweenService
							:Create(v13.Tweened, TweenInfo.new(1), {
								ImageTransparency = 1,
								Size = UDim2.fromScale(12, 12),
							})
							:Play()
						game.TweenService
							:Create(v13.ImageLabel, TweenInfo.new(10), {
								ImageTransparency = 1,
								Size = UDim2.fromScale(0, 0),
							})
							:Play()
						game.TweenService
							:Create(v13.Outline, TweenInfo.new(10), {
								ImageTransparency = 1,
								Size = UDim2.fromScale(0, 0),
							})
							:Play()
						game.Debris:AddItem(v13, 10.1)
						game.SoundService.SFXFolder.Radar_Altar.PlaybackSpeed = v1:NextNumber(0.97, 1.03)
						game.SoundService.SFXFolder.Radar_Altar:Play()
					end
				)
			end
		end
	end
end

local function f4() --[[ Line: 79 | Upvalues: CollectionService (copy), HumanoidRootPart (copy), v1 (copy) ]]
	for k, v in pairs(CollectionService:GetTagged("CadenceOrb")) do
		if v.CanTouch then
			local Magnitude = (v.Position - HumanoidRootPart.Position).Magnitude

			if not (Magnitude > 1024) then
				task.delay(Magnitude / 2048, function() --[[ Line: 89 | Upvalues: v (copy), v1 (ref) ]]
					local v12 = script:WaitForChild("CadencePing"):Clone()

					v12.Parent = v
					v12.Enabled = true
					game.TweenService
						:Create(v12.Tweened, TweenInfo.new(1), {
							ImageTransparency = 1,
							Size = UDim2.fromScale(12, 12),
						})
						:Play()
					game.TweenService
						:Create(v12.ImageLabel, TweenInfo.new(10), {
							ImageTransparency = 1,
							Size = UDim2.fromScale(0, 0),
						})
						:Play()
					game.Debris:AddItem(v12, 10.1)
					game.SoundService.SFXFolder.Radar_Instruments.PlaybackSpeed = v1:NextNumber(1.95, 2.05)
					game.SoundService.SFXFolder.Radar_Instruments:Play()
				end)
			end
		end
	end
end

while task.wait(12) and Humanoid:GetState() ~= Enum.HumanoidStateType.Dead do
	if UpgradeHandler.IsUpgradeEnabled("RadarPlayer") then
		task.spawn(f2)
	end

	if UpgradeHandler.IsUpgradeEnabled("RadarAltars") then
		task.spawn(f3)
	end

	if UpgradeHandler.IsUpgradeEnabled("RadarInstruments") then
		task.spawn(f4)
	end
end

-- Script Path: game:GetService("Players").Noriko_Ellen.PlayerScripts.ArrowHandler
-- Took 0.45s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UpgradeHandler = require(game.ReplicatedFirst.ClientModules.UpgradeHandler)
local AltarColors = require(game.ReplicatedStorage.Altars.AltarColors)
local Enemies = workspace.Enemies
local Arrows = Instance.new("Folder")

Arrows.Name = "Arrows"
Arrows.Parent = workspace

local LocalPlayer = Players.LocalPlayer
local t = {}
local t2 = {}
local v1 = nil
local v2 = nil
local v3 = Vector3.new(0, 0, 0)

for v4, v5 in script.Arrows:GetChildren() do
	t[v5.Name] = v5
end

for k, v in pairs(AltarColors) do
	if not t[k] then
		local v6 = script.Template:Clone()

		v6.Name = k
		v6.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
		v6.Color = v
		t[k] = v6
	end
end

local t3 = {}
local v7 = 0
local v8 = false
local v9 = false
local CadenceArrow = t.CadenceArrow

CadenceArrow.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
CadenceArrow.Parent = Arrows
function CreateArrow(p1, p2) --[[ CreateArrow | Line: 52 | Upvalues: t (copy), Arrows (copy) ]]
	local v1 = t[p2]

	if v1 then
		local t2 = {
			Target = nil,
			Model = v1:Clone(),
			Rotation = CFrame.identity,
		}

		t2.Model.Parent = Arrows

		return t2
	end
end
function DestroyArrow(p1) --[[ DestroyArrow | Line: 68 ]]
	if not p1.Model then
		return
	end

	p1.Model:Destroy()
end
function EnemyAdded(p1) --[[ EnemyAdded | Line: 75 | Upvalues: t (copy), t2 (copy) ]]
	local v1 = p1.Name

	if not t[v1] then
		return
	end

	t2[p1] = {
		UseEnemyPosition = true,
		Arrows = {},
	}
	table.insert(t2[p1].Arrows, CreateArrow(p1, v1))
end
function EnemyRemoved(p1) --[[ EnemyRemoved | Line: 88 | Upvalues: t2 (copy) ]]
	local v1 = t2[p1]

	if not v1 then
		return
	end

	for k, v in pairs(v1.Arrows) do
		DestroyArrow(v)
	end

	t2[p1] = nil
end
function CharacterAdded(p1) --[[ CharacterAdded | Line: 99 | Upvalues: v1 (ref), v2 (ref) ]]
	v1 = p1
	v2 = p1:WaitForChild("Head", 9)
end
function GetClosestInstrument() --[[ GetClosestInstrument | Line: 104 | Upvalues: t3 (copy), v3 (ref) ]]
	local v1 = 99999999
	local v2 = nil

	for v32, v4 in t3 do
		local Position = v4.Position
		local Magnitude = (Position - v3).Magnitude

		if Magnitude < v1 then
			v1 = Magnitude
			v2 = Position
		end
	end

	return v2
end
function Render() --[[ Render | Line: 119 | Upvalues: v3 (ref), v2 (ref), v8 (ref), t2 (copy) ]]
	v3 = if v2 then v2.Position or Vector3.new(0, 1000000, 0) else Vector3.new(0, 1000000, 0)

	if v8 and v3 then
		debug.profilebegin("InstrumentArrow")

		local v22 = GetClosestInstrument()

		if v22 then
			t2.CadenceArrow.Arrows[1].Target = v22
		end

		debug.profileend()
	end

	debug.profilebegin("BossArrows")

	for v32, v4 in t2 do
		local v5 = if v4.UseEnemyPosition then v32.Position or Vector3.new(0, 0, 0) else Vector3.new(0, 0, 0)

		for v6, v7 in v4.Arrows do
			if not v4.UseEnemyPosition then
				v5 = v7.Target
			end

			if v7.Enabled then
				if v7.Enabled == 0 and v7.Visible then
					v7.Visible = false
					v7.Model.Transparency = 1
				elseif v7.Enabled > 0 and not v7.Visible then
					v7.Visible = true
					v7.Model.Transparency = 0
				end
			end

			if v7.Visible == nil or v7.Visible == true then
				local v82 = CFrame.lookAt(v3, v5) - v3

				v7.Rotation = v7.Rotation:Lerp(v82, 0.1)
				v7.Model.CFrame = v7.Rotation * CFrame.new(0, 0, -2 - math.min(1, (v3 - v5).Magnitude / 9)) + v3
			end
		end
	end

	debug.profileend()
end
function StartCadenceArrow(p1) --[[ StartCadenceArrow | Line: 169 | Upvalues: v8 (ref), v7 (ref), t2 (copy), v3 (ref), CadenceArrow (copy) ]]
	if not v8 and v7 ~= 0 then
		v8 = true
		t2.CadenceArrow = {
			UseEnemyPosition = false,
			Arrows = {
				{
					Target = p1,
					Rotation = CFrame.lookAt(v3, p1) - v3,
					Model = CadenceArrow,
				},
			},
		}
	end
end
function StopCadenceArrow() --[[ StopCadenceArrow | Line: 185 | Upvalues: v8 (ref), t2 (copy), CadenceArrow (copy) ]]
	if v8 then
		v8 = false
		t2.CadenceArrow = nil
		CadenceArrow.CFrame = CFrame.new(Vector3.new(0, 1000000, 0))
	end
end
function OrbAdded(p1) --[[ OrbAdded | Line: 194 | Upvalues: t3 (copy), v7 (ref), v9 (ref) ]]
	if t3[p1] then
		return
	end

	v7 = v7 + 1
	t3[p1] = p1

	if v9 and v7 == 1 then
		StartCadenceArrow(t3[p1].Position)
	end

	p1:GetPropertyChangedSignal("CanTouch"):Connect(function() --[[ Line: 204 | Upvalues: p1 (copy) ]]
		OrbRemoved(p1)
	end)
end
function OrbRemoved(p1) --[[ OrbRemoved | Line: 209 | Upvalues: t3 (copy), v7 (ref), v9 (ref) ]]
	if not t3[p1] then
		return
	end

	v7 = v7 - 1
	t3[p1] = nil

	if not v9 or v7 ~= 0 then
		return
	end

	StopCadenceArrow()
end

local function AltarAdded(p1) --[[ AltarAdded | Line: 220 | Upvalues: t2 (copy), t (copy), Arrows (copy), v3 (ref) ]]
	local v1 = p1:GetAttribute("Name") or ""
	local Position = p1:WaitForChild("Hitbox").Position
	local v2 = t2[v1]

	if not v2 then
		local t3 = {
			UseEnemyPosition = false,
			Count = 0,
			Arrows = {},
		}

		t2[v1] = t3
		v2 = t3
	end

	local v32 = t[v1]

	if not v32 then
		return
	end

	local v4 = v32:Clone()

	v4.Parent = Arrows
	v2.Count = v2.Count + 1

	local t3 = {
		Visible = false,
		Target = Position,
		Rotation = CFrame.lookAt(v3, Position) - v3,
		Model = v4,
	}

	t3.Enabled = if p1:HasTag("Voting") then 1 else 0
	v2.Arrows[p1] = t3
end

local function AltarRemoved(p1) --[[ AltarRemoved | Line: 252 | Upvalues: t2 (copy) ]]
	local v1 = p1:GetAttribute("Name") or ""
	local v2 = t2[v1]

	if not v2 then
		return
	end

	local v3 = v2.Arrows[p1]

	if v3 then
		DestroyArrow(v3)
		v2.Arrows[p1] = nil
		v2.Count = v2.Count - 1
	end

	if not (v2.Count <= 0) then
		return
	end

	t2[v1] = nil
end

UpgradeHandler.GetUpgradeChangedSignal("RadarInstruments"):Connect(function(p1) --[[ Line: 271 | Upvalues: v9 (ref) ]]
	if p1 == 0 then
		v9 = false
		StopCadenceArrow()
	else
		v9 = true
		StartCadenceArrow(GetClosestInstrument() or Vector3.new(0, 1000000, 0))
	end
end)
CollectionService:GetInstanceAddedSignal("CadenceOrb"):Connect(OrbAdded)
CollectionService:GetInstanceRemovedSignal("CadenceOrb"):Connect(OrbRemoved)
CollectionService:GetInstanceAddedSignal("Altar"):Connect(AltarAdded)
CollectionService:GetInstanceRemovedSignal("Altar"):Connect(AltarRemoved)
CollectionService:GetInstanceAddedSignal("Voting")
	:Connect(function(p1) --[[ Line: 289 | Upvalues: UpgradeHandler (copy), t2 (copy) ]]
		if not UpgradeHandler.IsUpgradeEnabled("RadarAltars") then
			return
		end

		local v1 = t2[p1:GetAttribute("Name") or ""]

		if not v1 then
			return
		end

		local v2 = v1.Arrows[p1]

		if not v2 then
			return
		end

		v2.Enabled = v2.Enabled + 1
	end)
CollectionService:GetInstanceRemovedSignal("Voting"):Connect(function(p1) --[[ Line: 305 | Upvalues: t2 (copy) ]]
	local v1 = t2[p1:GetAttribute("Name") or ""]

	if not v1 then
		return
	end

	local v2 = v1.Arrows[p1]

	if not (v2 and v2.Enabled > 0) then
		return
	end

	v2.Enabled = v2.Enabled - 1
end)
Enemies.ChildAdded:Connect(EnemyAdded)
Enemies.ChildRemoved:Connect(EnemyRemoved)
LocalPlayer.CharacterAdded:Connect(CharacterAdded)

if not LocalPlayer.Character then
	RunService.RenderStepped:Connect(Render)

	return
end

CharacterAdded(LocalPlayer.Character)
RunService.RenderStepped:Connect(Render)
