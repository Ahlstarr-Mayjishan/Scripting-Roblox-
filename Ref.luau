-- Script Path: game:GetService("ReplicatedStorage").Movement.MovementCore
-- Took 1.59s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}

t.__index = t

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ClientModules = ReplicatedFirst.ClientModules
local Cosmetics = require(ReplicatedStorage.Cosmetics)

require(ReplicatedStorage.Cosmetics.Types)

local InventoryHandler = require(ClientModules.Core.PlayerData.InventoryHandler)
local SettingsHandler = require(ClientModules.Core.PlayerData.SettingsHandler)
local MobileHandler = require(ReplicatedStorage.Mobile.MobileHandler)
local AchievementHandler = require(game.ReplicatedFirst.ClientModules.Core.PlayerData.AchievementHandler)
local v1 = workspace:GetAttribute("Null")
local v2, v3, v4, v5

if v1 then
	v2 = require(ClientModules.UpgradeHandler)
	v3 = require(ClientModules.CurseHandler)
	v4 = require(ClientModules.GreaterCurseHandler)
	v5 = require(ReplicatedStorage.Module.Bezier)
else
	v4 = nil
	v5 = nil
	v3 = nil
	v2 = nil
end

local v6 = script.Parent
local Specials = v6.Specials
local AnimationManager = require(v6.AnimationManager)
local HumanoidMovement = require(v6.HumanoidMovement)
local SlideManager = require(v6.SlideManager)
local SoundManager = require(v6.SoundManager)
local DoubleJump = require(v6.DoubleJump)
local LocalPlayer = Players.LocalPlayer
local v7 = Random.new()

t.WickedIgnoreList =
	{ "IceSkates", "MatrixTetrahedron", "RealWings", "GraceWings", "AdvancedGravityCoil", "BetterJumpPad" }
function t.new(p1) --[[ new | Line: 64 | Upvalues: Players (copy), v1 (copy), ReplicatedFirst (copy), ReplicatedStorage (copy), SoundManager (copy), AnimationManager (copy), HumanoidMovement (copy), SlideManager (copy), DoubleJump (copy), UserInputService (copy), t (copy) ]]
	local t2 = {
		Character = p1.Character,
		Player = p1,
	}

	t2.IsLocalPlayer = t2.Player == Players.LocalPlayer
	t2.RootPart = nil
	t2.Humanoid = nil
	t2.Initialised = false

	repeat
		task.wait()

		if not (t2.Character and t2.Character.Parent) then
			return
		end
	until t2.Character:FindFirstChild("HumanoidRootPart") and t2.Character:FindFirstChild("Humanoid")

	t2.RootPart = t2.Character.HumanoidRootPart
	t2.Humanoid = t2.Character.Humanoid
	t2.Hitbox = Instance.new("Part")
	t2.Camera = workspace.CurrentCamera

	if v1 then
		t2.Status = require(ReplicatedFirst.ClientModules.StatusEffectHandler)
		t2.ClientUpgrades = require(ReplicatedFirst.ClientModules.UpgradeHandler)
		t2.ClientUpgradeIndex = require(ReplicatedStorage.Index.ClientUpgradeIndex)
	else
		t2.Status = {
			HasStatus = function() --[[ HasStatus | Line: 102 ]]
				return false
			end,
		}
	end

	t2.SFX = SoundManager.new(t2)
	t2.Animator = AnimationManager.new(t2)
	t2.HumanoidMovement = HumanoidMovement.new(t2, t2.Animator)
	t2.SlideManager = SlideManager.new(t2, t2.Animator)
	t2.DoubleJump = DoubleJump.new(t2, t2.Animator, t2.SFX)
	t2.ControlModule = require(p1:WaitForChild("PlayerScripts").PlayerModule:WaitForChild("ControlModule"))
	t2.ActiveSpecial = nil
	t2.SpecialID = nil
	t2.ClassCosmetic = nil
	t2.ClassID = nil
	t2.PlayerMoveDirection = Vector3.new(0, 0, 0)
	t2.TrueMoveDirection = Vector3.new(0, 0, 0)
	t2.TrueMoveUnit = Vector3.new(0, 0, 1)
	t2.WantDirection = Vector3.new(0, 0, 0)
	t2.autoSprint = false
	t2.toggleSprint = false
	t2.toggleAbility = false
	t2.jumpToRail = false
	t2.floorIndicator = nil
	t2.hameUpgradeSettings = {
		MatrixTetrahedron = true,
		SportShoes = true,
		NinjaBelt = true,
	}
	t2.jumpPressed = false
	t2.sprintHeld = false
	t2.specialHeld = false
	t2.altSpecialHeld = false
	t2.preferredInput = UserInputService.PreferredInput
	t2.sprintSpeed = 0
	t2.movementSpeedMulti = 1
	t2.classSpeedMulti = 0
	t2.friction = 20
	t2.doingQuickTurn = false
	t2.diveBonked = false
	t2.lastMan = false
	t2.slideJumpSpeed = 0
	t2.slideSlopeSpeed = 0
	t2.railJumpSpeed = 0
	t2.spiritSlingshotSpeed = 0
	t2.iceSkateSpeed = 0
	t2.iceSkateMulti = 0
	t2.sliding = false
	t2.slideJumped = false
	t2.slideDir = Vector3.new(0, 0, 0)
	t2.slideNormal = Vector3.new(0, 1, 0)
	t2.storedSlideVel = Vector3.new(0, 0, 0)
	t2.isDoubleJumping = false
	t2.usedDoubleJumpInAir = false
	t2.diveTime = 0
	t2.diving = false
	t2.diveType = nil
	t2.poweredDive = false
	t2.diveSharkTech = false
	t2.grappling = false
	t2.grapplePoint = nil
	t2.grappleSpeed = 0
	t2.grappleJumpCancel = false
	t2.faceGrapplePoint = false
	t2.grappleJumping = false
	t2.usedGrappleInAir = false
	t2.charging = false
	t2.chargeSlowing = false
	t2.chargePound = false
	t2.antiJumpPadClipMethod = false
	t2.gliding = false
	t2.glideSpeed = 0
	t2.spirit = false
	t2.jumpPadDebounce = false
	t2.jumpPadAirControl = false
	t2.jumpPadTweens = {}
	t2.activeFloorIndicator = nil
	t2.rail = false
	t2.railJumped = false
	t2.railDebounce = false
	t2.railSpiritCancel = false
	t2.insideFlipFlop = {}
	t2.Anchored = false
	t2.realWingsTime = 3
	t2.realWingsEnabled = false
	t2.realWingsGrace = -1
	t2.realWingsVel = ReplicatedStorage.stuff.RealWingsVelocity:Clone()
	t2.realWingsVel.Attachment0 = t2.RootPart.RootAttachment
	t2.realWingsVel.Parent = t2.RootPart
	t2.triaHold = false
	t2.agcJumped = false
	t2.advancedCoilTask = nil
	t2.springerDebounce = false
	t2.martSlideDebounce = false
	t2.bonkedOffPlayer = false
	t2.hitBySpringer = false
	t2.leftGroundWhileFleshed = false
	t2.lastBellTime = -100
	t2.leftGroundWithinBell = false
	t2.lastStunTime = -100
	t2.antiRandomSpawnVoidBecauseTheClientMethod = nil
	t2.antiRandomSpawnVoidTime = -1
	t2.moveCastParams = RaycastParams.new()

	if v1 then
		t2.moveCastParams.FilterDescendantsInstances = { t2.Character, workspace.CurrentCamera }
		workspace:WaitForChild("Enemies").ChildAdded:Connect(function(p1) --[[ Line: 258 | Upvalues: t2 (copy) ]]
			if p1.Name == "Springer" then
				t2.moveCastParams:AddToFilter({ p1:WaitForChild("SpringerShockwave") })

				return
			end

			if p1.Name == "Slicer" then
				t2.moveCastParams:AddToFilter({ p1:WaitForChild("Kill") })

				return
			end

			if p1.Name == "Bell" then
				return
			end

			t2.moveCastParams:AddToFilter({ p1 })
		end)

		for v12, v2 in workspace.Enemies:GetChildren() do
			if v2.Name == "Springer" then
				t2.moveCastParams:AddToFilter({ v2:WaitForChild("SpringerShockwave") })

				continue
			end

			if v2.Name == "Slicer" then
				t2.moveCastParams:AddToFilter({ v2:WaitForChild("Kill") })

				continue
			end

			if v2.Name ~= "Bell" then
				t2.moveCastParams:AddToFilter({ v2 })
			end
		end
	else
		t2.moveCastParams.FilterDescendantsInstances = { t2.Character, workspace.CurrentCamera }
	end

	t2.moveCastParams.FilterType = Enum.RaycastFilterType.Exclude
	t2.moveCastParams.RespectCanCollide = true

	return setmetatable(t2, t)
end
function t.UpdateSpeed(p1) --[[ UpdateSpeed | Line: 292 | Upvalues: v1 (copy), v2 (ref) ]]
	if not v1 then
		p1.movementSpeedMulti = 1

		return
	end

	local v12 = if p1.ClassID == "class/Wanted" then 1.5 else 1
	local v22 = if p1.ClassID == "class/Wanted" then 1.25 else 1
	local v3 = 0.1 * v2.GetUpgradeStack("SwiftnessRing") * v12
	local v4 = 0.4 * v2.GetUpgradeStack("SportShoes") * v22
	local v5 = 0.2 * v2.GetUpgradeStack("Adrenaline") * v12

	if p1.hameUpgradeSettings.SportShoes == false then
		v4 = 0
	end

	local v7 = if p1.lastMan then 0.2 else 0

	p1.movementSpeedMulti = 1 + (v3 + v4 + v5) + v7 + (if p1.Status.HasStatus("Medal") then 0.1 else 0)
end
function t.HasUpgrade(p1, p2) --[[ HasUpgrade | Line: 314 | Upvalues: v1 (copy), AchievementHandler (copy), v2 (ref) ]]
	if not v1 then
		return p2 == "RealWings" and AchievementHandler.HasAchievement(game.Players.LocalPlayer, "TrueLevel50") and true
			or false
	end

	if (p1.ClassID == "class/Wicked" or p1.ClassID == "class/Phoon") and table.find(p1.WickedIgnoreList, p2) then
		return false, 0
	end

	if p1.hameUpgradeSettings[p2] == false then
		return false, 0
	end

	return v2.IsUpgradeEnabled(p2), v2.GetUpgradeStack(p2)
end
function t.HasCurse(p1, p2) --[[ HasCurse | Line: 333 | Upvalues: v1 (copy), v3 (ref), v4 (ref) ]]
	if v1 then
		return v3.IsCurseEnabled(p2) or v4.IsCurseEnabled(p2)
	end
end
function t.ReloadClass(p1, p2) --[[ ReloadClass | Line: 342 | Upvalues: InventoryHandler (copy), Cosmetics (copy), Specials (copy), MobileHandler (copy), v6 (copy), v1 (copy), ReplicatedStorage (copy) ]]
	if not (p1.Character and p1.Character.Parent) then
		return
	end

	p1.Humanoid:SetAttribute("UsingAbility", false)

	if p1.ActiveSpecial then
		p1.ActiveSpecial:Reset()
		p1.ActiveSpecial = nil
	end

	p1.classSpeedMulti = 0

	if p2 then
		print("forcing diver")
		p1.ClassID = "class/Diver"
	else
		p1.ClassID = InventoryHandler.WaitForInventory().Class.Equipped or "class/Diver"
	end

	p1.ClassCosmetic = Cosmetics.GetById(p1.ClassID)

	if p1.ClassID and p1.ClassCosmetic then
		p1.SpecialID = p1.ClassCosmetic.SpecialId
	else
		warn("oops all diver (invalid class, falling back to diver), tell ghosty pep")

		local v12 = warn

		v12("class: " .. tostring(p1.ClassID))
		p1.SpecialID = "Dive"
	end

	p1.ActiveSpecial = require(Specials:FindFirstChild(p1.SpecialID)).new(p1, p1.Animator)
	MobileHandler.SetButtonVisibility("SpecialAlt", p1.ActiveSpecial.AltSpecialAction ~= nil)
	p1.ActiveSpecial:Initialise()
	v6.Events.ReloadClassEvent:FireServer(p1.ClassID)

	if not v1 then
		p1.Character:SetAttribute("Class", p1.ClassID)
		p1:UpdateSpeed()

		return
	end

	ReplicatedStorage.Events.MovementGiftMagnet:Fire({
		Type = "Reset",
	})
	p1.Character:SetAttribute("Class", p1.ClassID)
	p1:UpdateSpeed()
end
function t.Initialise(p1) --[[ Initialise | Line: 390 | Upvalues: v6 (copy), v1 (copy), ReplicatedStorage (copy), v2 (ref), UserInputService (copy), LocalPlayer (copy), InventoryHandler (copy), SettingsHandler (copy) ]]
	p1.SFX:Initialise()
	p1.Animator:Initialise()
	p1.DoubleJump:Initialise()
	p1.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	p1.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	p1.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	p1.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	p1.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	p1.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
	p1.Humanoid.AutoRotate = false
	p1.Humanoid.StateChanged:Connect(function(p12, p2) --[[ Line: 409 | Upvalues: p1 (copy) ]]
		p1:OnStateChanged(p12, p2)
	end)
	p1.Humanoid
		:GetAttributeChangedSignal("UsingAbility")
		:Connect(function() --[[ Line: 413 | Upvalues: v6 (ref), p1 (copy) ]]
			v6.Events.ReplicateAbility:FireServer(p1.Humanoid:GetAttribute("UsingAbility"))
		end)
	p1.Humanoid:SetAttribute("UsingAbility", false)

	if v1 then
		ReplicatedStorage.Events.LastMan.OnClientEvent:Connect(function() --[[ Line: 421 | Upvalues: p1 (copy) ]]
			p1.lastMan = true
			p1:UpdateSpeed()
		end)
		ReplicatedStorage.Events.MovementGiftMagnet:Fire({
			Type = "Reset",
		})
		p1.Status.RemoveAllStatuses()
		v2.ForceSyncServer()
		ReplicatedStorage.Events.StatusEffectChanged.OnClientEvent:Connect(
			function(p12, p2) --[[ Line: 432 | Upvalues: p1 (copy) ]]
				p1:OnStatusChange(p12, p2)
			end
		)
		ReplicatedStorage.InRound.Changed:Connect(
			function() --[[ Line: 436 | Upvalues: ReplicatedStorage (ref), p1 (copy) ]]
				if ReplicatedStorage.InRound.Value == true then
					p1:OnLevelStart()

					return
				end

				p1:OnLevelEnd()

				if ReplicatedStorage.Level.Value ~= 0 then
					return
				end

				p1:OnGameOver()
			end
		)
		v2.UpgradesChanged:Connect(function(p12) --[[ Line: 447 | Upvalues: p1 (copy), v2 (ref) ]]
			p1:UpgradeChanged(p12, v2.GetUpgradeStack(p12))
		end)
		ReplicatedStorage.Events.Bell.OnClientEvent:Connect(function() --[[ Line: 451 | Upvalues: p1 (copy) ]]
			p1.lastBellTime = time()
		end)
	end

	p1:UpdateSpeed()
	p1.Hitbox.Size = Vector3.new(3, 2, 2)
	p1.Hitbox.Shape = Enum.PartType.Cylinder
	p1.Hitbox.Name = "Hitbox"
	p1.Hitbox.Parent = p1.Character
	p1.Hitbox.Material = Enum.Material.Neon
	p1.Hitbox.BrickColor = BrickColor.new("Persimmon")
	p1.Hitbox.Transparency = 1
	p1.Hitbox.CollisionGroup = "Player"
	p1.Hitbox.Massless = true

	if p1:HasCurse("RandomSpawn") then
		p1.antiRandomSpawnVoidBecauseTheClientMethod = Instance.new("Part")
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Size = Vector3.new(0.5, 6, 6)
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Material = Enum.Material.ForceField
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Color = Color3.fromRGB(255, 255, 255)
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Anchored = true
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Transparency = 1
		p1.antiRandomSpawnVoidBecauseTheClientMethod.CanCollide = false
		p1.antiRandomSpawnVoidBecauseTheClientMethod.CanQuery = false
		p1.antiRandomSpawnVoidBecauseTheClientMethod.CanTouch = false
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Shape = Enum.PartType.Cylinder
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Name = "anti random spawn void method"
		p1.antiRandomSpawnVoidBecauseTheClientMethod.Parent = p1.Character
	end

	p1.Hitbox.CustomPhysicalProperties =
		PhysicalProperties.new(p1.Hitbox.CurrentPhysicalProperties.Density, 0, 0, 100, 100)

	local HitboxWeld = Instance.new("Weld")

	HitboxWeld.Part0 = p1.RootPart
	HitboxWeld.Part1 = p1.Hitbox
	HitboxWeld.C0 = CFrame.Angles(0, 0, 1.5707963267948966)
	HitboxWeld.C1 = CFrame.new(-0.5, 0, 0)
	HitboxWeld.Name = "HitboxWeld"
	HitboxWeld.Parent = p1.RootPart
	p1.Hitbox.Touched:Connect(function(p12) --[[ Line: 499 | Upvalues: p1 (copy) ]]
		p1:OnHitboxTouch(p12)
	end)

	if p1.Character:FindFirstChild("Torso") then
		local CenterAttachment = Instance.new("Attachment")

		CenterAttachment.Name = "CenterAttachment"
		CenterAttachment.Parent = p1.Character:WaitForChild("Torso")
	end

	p1.RootPart:GetPropertyChangedSignal("Anchored"):Connect(function() --[[ Line: 512 | Upvalues: p1 (copy) ]]
		if p1.RootPart.Anchored then
			p1:OnRootAnchored()
		else
			p1:OnRootUnanchored()
		end
	end)

	local EmoteCheck = Instance.new("BindableFunction")

	EmoteCheck.Name = "EmoteCheck"
	EmoteCheck.Parent = p1.Character
	function EmoteCheck.OnInvoke() --[[ Line: 524 | Upvalues: p1 (copy) ]]
		return not p1.diving
			and (
				if p1.Humanoid:GetState() == Enum.HumanoidStateType.Running
					then not p1.sliding
						and (
							not p1.diveBonked
							and (
								not p1.doingQuickTurn
								and (
									not p1.RootPart.Anchored
									and (not p1.grappling and not workspace:GetAttribute("Series"))
								)
							)
						)
					else false
			)
	end
	p1.FloorParticles = ReplicatedStorage.partthatholdsrootparticles.FloorParticles:Clone()
	p1.FloorParticles.Parent = p1.RootPart
	p1.DiveParticles = ReplicatedStorage.partthatholdsrootparticles.DiveAttachment:Clone()
	p1.DiveParticles.Parent = p1.RootPart

	local v12 = nil

	local function f2(p12) --[[ Line: 545 | Upvalues: p1 (copy), v12 (ref) ]]
		if not (p1.Character and p1.Character.Parent) then
			v12:Disconnect()

			return
		end

		if p12.AnimationPack.Equipped == p1.Animator.AnimationPack then
			if p1.Animator.animationsReloadedEver == false then
				p1.Animator:ReloadAnimations()
				p1.SFX:ReloadSounds()
			end
		else
			p1.Animator:ReloadAnimations()
			p1.SFX:ReloadSounds()
		end

		if p12.Class.Equipped == p1.ClassID then
			return
		end

		p1:ReloadClass()
		p1.DoubleJump:Refresh()
	end

	local function f3(p12) --[[ Line: 569 | Upvalues: UserInputService (ref), p1 (copy), LocalPlayer (ref), ReplicatedStorage (ref) ]]
		if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
			p1.autoSprint = false
			p1.toggleAbility = true
		end

		if p12 == nil then
			return
		end

		local floorIndicator = p1.floorIndicator

		p1.autoSprint = p12.Controls.AutoSprint
		p1.toggleSprint = p12.Controls.ToggleSprint
		p1.toggleAbility = p12.Controls.ToggleAbility
		p1.jumpToRail = p12.Controls.JumpToRail
		p1.floorIndicator = p12.Misc.FloorIndicator
		p1.hameUpgradeSettings = p12.Upgrades
		LocalPlayer:SetAttribute("CameraOcclusionMode", if p12.Misc.Invisicam then "Invisicam" else "Zoom")
		p1:UpdateSpeed()
		p1.DoubleJump:SetUIPosition(p12.Misc.CenteredDoubleJumps)

		if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
			p1.autoSprint = false
			p1.toggleAbility = true
		end

		if p1.floorIndicator == floorIndicator then
			return
		end

		if p1.floorIndicator then
			p1.activeFloorIndicator = ReplicatedStorage.FloorIndicator:Clone()
			p1.activeFloorIndicator.Parent = workspace.ExternalCharacter

			return
		end

		if not (p1.activeFloorIndicator and p1.activeFloorIndicator.Parent) then
			return
		end

		p1.activeFloorIndicator:Destroy()
		p1.activeFloorIndicator = nil
	end

	v12 = InventoryHandler.OnInventoryChanged:Connect(f2)

	local v4 = nil

	v4 = SettingsHandler.OnSettingsChanged:Connect(
		function(p12) --[[ Line: 612 | Upvalues: p1 (copy), v4 (ref), f3 (copy) ]]
			if not (p1.Character and p1.Character.Parent) then
				v4:Disconnect()
			end

			f3(p12)
		end
	)

	local v5 = false
	local v62 = -1000

	task.delay(2, function() --[[ Line: 625 | Upvalues: v5 (ref), v62 (ref), p1 (copy), f3 (copy) ]]
		if v5 then
			return
		end

		warn("Inventory/Settings didn't load fast enough, using default.")
		v62 = time()

		if p1.Animator.animationsReloadedEver ~= false then
			p1.SFX:ReloadSounds()
			p1:ReloadClass(true)
			f3()

			return
		end

		p1.Animator:ReloadAnimations(true)
		p1.SFX:ReloadSounds()
		p1:ReloadClass(true)
		f3()
	end)
	p1.Humanoid
		:GetPropertyChangedSignal("FloorMaterial")
		:Connect(function() --[[ Line: 642 | Upvalues: p1 (copy), v6 (ref) ]]
			if p1.Humanoid.FloorMaterial ~= Enum.Material.CorrodedMetal then
				return
			end

			if p1.sliding and p1:HasUpgrade("SteelToed") then
				return
			end

			if p1.Character:GetAttribute("FleshImmunity") then
				return
			end

			if p1.spirit then
				return
			end

			v6.Events.FleshTileTouched:FireServer()
		end)

	local v7 = InventoryHandler.WaitForInventory()
	local v8 = SettingsHandler.WaitForSettings()

	v5 = true

	if time() - v62 < 0.5 then
		repeat
			task.wait()
		until time() - v62 >= 0.5
	end

	f3(v8)
	f2(v7)
	p1.DoubleJump:Refresh()
	p1.Initialised = true
	v6.Events.MovementLoaded:FireServer()
end
function t.Unload(p1) --[[ Unload | Line: 674 | Upvalues: v1 (copy), ReplicatedStorage (copy) ]]
	if p1.Hitbox and p1.Hitbox.Parent then
		p1.Hitbox:Destroy()
	end

	for v12, v2 in p1.SFX.LoadedSounds do
		v2:Stop()
	end

	if p1.ActiveSpecial then
		p1.ActiveSpecial:Reset()
	end

	p1.ActiveSpecial = nil

	for v3, v4 in p1.Animator.Animations do
		v4:Stop(0)
		p1.Animator.Animations[v3] = nil
	end

	if v1 then
		ReplicatedStorage.Events.MovementGiftMagnet:Fire({
			Type = "Reset",
		})
	end

	if not (p1.DoubleJump and p1.DoubleJump.UI) then
		return
	end

	p1.DoubleJump.UI:Destroy()
	p1.DoubleJump.UI = nil
end
function t.OnRootAnchored(p1) --[[ OnRootAnchored | Line: 706 | Upvalues: TweenService (copy) ]]
	p1.sprintSpeed = 0
	p1.Anchored = true
	p1.diving = false

	if p1.SFX.LoadedSounds.Dive_Alt and p1.SFX.LoadedSounds.Dive_Alt.IsPlaying then
		TweenService:Create(p1.SFX.LoadedSounds.Dive_Alt, TweenInfo.new(0.2), {
			Volume = 0,
		}):Play()
	end

	p1.sliding = false
	p1.slideSlopeSpeed = 0
	p1.slideJumpSpeed = 0

	if p1.ActiveSpecial and p1.ActiveSpecial.OnRootAnchored then
		p1.ActiveSpecial:OnRootAnchored()
	end

	p1:SetMoveDirection(Vector3.new(0, 0, 0))
	p1.Humanoid:SetAttribute("UsingAbility", false)

	if p1.RootPart:FindFirstChild("DiveVelocity") then
		p1.RootPart.DiveVelocity:Destroy()
	end

	p1.SlideManager:EndSlide()

	if p1.diving or (p1.grappling or (p1.charging or (p1.spirit or p1.gliding))) then
		p1.ActiveSpecial:End()
	end

	p1.DoubleJump:Refresh()

	for k, v in pairs(p1.Character:QueryDescendants("BasePart")) do
		v.Velocity = Vector3.new(0, 0, 0)
		v.RotVelocity = Vector3.new(0, 0, 0)
	end

	p1.RootPart.Velocity = Vector3.new(0, 0, 0)
	p1.Animator:StopAnimation("DiveLoop")
	p1.Animator:StopAnimation("DiveStart")
	p1.Animator:StopAnimation("SlideGetUp")
	p1.Animator:StopAnimation("SlideCancel")
	p1.triaHold = false
	p1.triaDebounce = false

	if not p1.RootPart:FindFirstChild("TRIA_WELD") then
		return
	end

	p1.RootPart.TRIA_WELD:Destroy()
end
function t.CheckIfAboveAntiRandomSpawnVoidMethod(p1) --[[ CheckIfAboveAntiRandomSpawnVoidMethod | Line: 752 | Upvalues: TweenService (copy) ]]
	if
		not (
			(
					p1.RootPart.Position * Vector3.new(1, 0, 1)
					- p1.antiRandomSpawnVoidBecauseTheClientMethod.Position * Vector3.new(1, 0, 1)
				).Magnitude
				> p1.antiRandomSpawnVoidBecauseTheClientMethod.Size.Z / 2
			or (if time() - p1.antiRandomSpawnVoidTime > 30 then true else false)
		)
	then
		return
	end

	p1.antiRandomSpawnVoidBecauseTheClientMethod.CanCollide = false
	p1.antiRandomSpawnVoidBecauseTheClientMethod.CanQuery = false
	p1.antiRandomSpawnVoidBecauseTheClientMethod.CanTouch = false
	TweenService:Create(p1.antiRandomSpawnVoidBecauseTheClientMethod, TweenInfo.new(0.5), {
		Transparency = 1,
	}):Play()
end
function t.OnRootUnanchored(p1) --[[ OnRootUnanchored | Line: 776 ]]
	p1.Anchored = false
	p1:FlipFlop()

	if not p1:HasCurse("RandomSpawn") then
		return
	end

	repeat
		if not task.wait() then
			break
		end

		local v1 = false

		for v2, v3 in p1.Hitbox:GetTouchingParts() do
			if v3.Name == "Beacon" then
				v1 = true
			end
		end
	until not v1

	if not p1.antiRandomSpawnVoidBecauseTheClientMethod then
		local Part = Instance.new("Part")

		Part.Size = Vector3.new(0.5, 6, 6)
		Part.Material = Enum.Material.ForceField
		Part.Color = Color3.fromRGB(255, 255, 255)
		Part.Anchored = true
		Part.Transparency = 1
		Part.CanCollide = false
		Part.CanQuery = false
		Part.CanTouch = false
		Part.Shape = Enum.PartType.Cylinder
		Part.Name = "anti random spawn void method"
		Part.Parent = p1.Character
		p1.antiRandomSpawnVoidBecauseTheClientMethod = Part
	end

	p1.antiRandomSpawnVoidTime = time()
	p1.antiRandomSpawnVoidBecauseTheClientMethod.Position = p1.RootPart.Position + Vector3.new(0, -5, 0)
	p1.antiRandomSpawnVoidBecauseTheClientMethod.Rotation = Vector3.new(0, 0, 90)
	p1.antiRandomSpawnVoidBecauseTheClientMethod.Transparency = 0
	p1.antiRandomSpawnVoidBecauseTheClientMethod.CanCollide = true
	p1.antiRandomSpawnVoidBecauseTheClientMethod.CanQuery = true
	p1.antiRandomSpawnVoidBecauseTheClientMethod.CanTouch = true
end
function t.FlipFlop(p1) --[[ FlipFlop | Line: 820 | Upvalues: CollectionService (copy) ]]
	if not p1:HasCurse("FlipFlop") then
		return
	end

	debug.profilebegin("FlipFlop")

	local function f1(p12) --[[ Line: 823 | Upvalues: p1 (copy) ]]
		p12:SetAttribute("FlipEnabled", not p12:GetAttribute("FlipEnabled") or p1.ClassID == "class/Wicked")

		if p12:GetAttribute("Fragile") then
			return
		end

		if p12:GetAttribute("FlipEnabled") then
			table.insert(p1.insideFlipFlop, p12)
			p12.CanQuery = true
		else
			p12.Transparency = 0.7
			p12.CanCollide = false
			p12.CanQuery = false
			p12.CanTouch = false

			local v3 = table.find(p1.insideFlipFlop, p12)

			if v3 then
				table.remove(p1.insideFlipFlop, v3)
			end
		end
	end

	for v2, v3 in CollectionService:GetTagged("FlipFlopOn") do
		f1(v3)
	end

	for v4, v5 in CollectionService:GetTagged("FlipFlopOff") do
		f1(v5)
	end

	debug.profileend()
end
function t.OnLevelStart(p1) --[[ OnLevelStart | Line: 859 ]]
	if not (p1.ActiveSpecial and p1.ActiveSpecial.OnLevelStart) then
		return
	end

	p1.ActiveSpecial:OnLevelStart()
end
function t.OnLevelEnd(p1) --[[ OnLevelEnd | Line: 865 ]]
	if not (p1.ActiveSpecial and p1.ActiveSpecial.OnLevelEnd) then
		return
	end

	p1.ActiveSpecial:OnLevelEnd()
end
function t.OnGameOver(p1) --[[ OnGameOver | Line: 871 ]]
end
function t.UpgradeChanged(p1, p2, p3) --[[ UpgradeChanged | Line: 875 ]]
	if p1.ActiveSpecial and p1.ActiveSpecial.UpgradeChanged then
		p1.ActiveSpecial:UpgradeChanged(p2, p3)
	end

	p1.Humanoid.JumpPower = 35

	if p1:HasUpgrade("AdvancedGravityCoil") then
		local Humanoid = p1.Humanoid

		Humanoid.JumpPower = Humanoid.JumpPower * 0.8
	end

	p1.DoubleJump:Refresh()
	p1:UpdateSpeed()
end
function t.LastInputTypeChanged(p1) --[[ LastInputTypeChanged | Line: 895 | Upvalues: UserInputService (copy) ]]
	p1.preferredInput = UserInputService.PreferredInput
end
function t.FollowRail(p1, p2) --[[ FollowRail | Line: 899 | Upvalues: v5 (ref), v6 (copy), RunService (copy), Debris (copy) ]]
	local t = {}
	local t2 = {}
	local t3 = {}

	for v1, v2 in p2.Parent.Parent._Points:GetChildren() do
		if string.find(v2.Name, "Point") then
			table.insert(t, v2)
		end
	end

	for i = 1, #t do
		for j = 1, #t do
			if tonumber((string.sub(t[j].Name, 6, 6))) == i then
				t2[i] = t[j]
			end
		end
	end

	for k = 1, #t2 do
		table.insert(t3, t2[k].Position)
	end

	local v52 = p2:GetAttribute("Alpha") or 0
	local v62 = v5.GetBezierPoint(v52, unpack(t3))
	local v7 = v5.GetBezierPoint(v52 + 0.025, unpack(t3)) - v62
	local v8 = v7:Dot(p1.RootPart.Position - v62)

	if v8 < 0 then
		return
	end

	local v9 = math.sqrt(v8) / v7.Magnitude * 1 / 40
	local sum = v52 + v9 - v9 * 0.2
	local v10 = p2.CFrame.LookVector:Dot(p1.RootPart.Velocity * Vector3.new(1, 0, 1))
	local v11 = math.abs(v10)
	local v12 = math.max(v11, 16) * math.sign(v10)

	if v12 == 0 then
		v12 = 16
	end

	local v13 = 1

	if p1.diving or (p1.grappling or (p1.charging or p1.chargeSlowing)) then
		p1.ActiveSpecial:End()
	end

	p1.rail = true
	p1.railDebounce = true

	if p1.chargePound then
		p1.chargePound = false
		p1.ActiveSpecial.altForceHold = false
		p1.ActiveSpecial.abilityToggled = false
		p1.Humanoid:SetAttribute("UsingAbility", false)
	end

	if p1.sliding then
		p1.SlideManager:EndSlide()
	end

	p1.Humanoid.PlatformStand = true

	if p1.diveBonked then
		p1.diveBonked = false
		p1.bonkedOffPlayer = false
		p1.Animator:StopAnimation("DiveBonk")
	end

	p1.Animator:PlayAnimation("RailLoop")

	local v14 = p1.SFX:PlaySound("RailGrind_Start")
	local v15 = math.sign(v12) * 0.025
	local v16 = v6.Instances.RailGrind:Clone()

	v16.Parent = p1.Character
	p1.DoubleJump:Refresh()
	p1.slideJumped = false
	p1.railSpiritCancel = false

	local v17 = nil
	local v18 = nil

	while p1.rail do
		local v19 = RunService.Heartbeat:Wait()

		if p1.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
			break
		end

		local v20 = v5.GetBezierPoint(sum, unpack(t3))
		local v21 = v5.GetBezierPoint(sum + v15, unpack(t3))
		local v22 = CFrame.lookAt(v20, v21)

		if p1.railSpiritCancel then
			break
		end

		p1.RootPart.CFrame = v22 * CFrame.new(0, 3, 0)
		p1.RootPart.Velocity = v22.LookVector * math.abs(v12) * 1.2
		p1:SetMoveDirection(v22.LookVector * Vector3.new(1, 0, 1))

		local Unit = (workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit

		if Unit ~= Unit then
			Unit = Vector3.new(0, 0, 0)
		end

		local v23 = p1.PlayerMoveDirection:Dot(Unit) * v19

		if v23 > 0 then
			v23 = v23 * 0.2
		end

		local v24 = math.clamp(v13 + v23, 0.5, 2)

		v16.CFrame = v22
		v17 = v22.LookVector
		v18 = v22.UpVector
		sum = sum + v12 * v19 * (math.abs(v15) / (v20 - v21).Magnitude) * v24
		v14.PlaybackSpeed = math.map(v24, 0.5, 1, 0.8, 1)

		if sum >= 1 or sum <= 0 then
			break
		end

		v13 = v24
	end

	p1.rail = false
	p1.Animator:StopAnimation("RailLoop")
	p1.Humanoid.PlatformStand = false
	p1.SFX:PlaySound("RailGrind_End")
	p1.SFX:StopSound("RailGrind_Start")

	if v16 and v16.Parent then
		for v25, v26 in v16:GetChildren() do
			v26.Enabled = false
		end

		Debris:AddItem(v16, 2)
	end

	if p1.railJumped then
		p1.Animator:PlayAnimation("RailJump")
		p1.railJumped = false
		p1.railJumpSpeed = math.max(p1.RootPart.Velocity:Dot(v17) - (p1.Humanoid.WalkSpeed - p1.railJumpSpeed), 0)
			* 1.15
		p1.jumpPadAirControl = true

		if v17 then
			local v28 = v17 * math.abs(v12) * 1.2

			p1.RootPart.Velocity = v28 + v18 * p1.Humanoid.JumpPower
			p1:SetMoveDirection((v28 * Vector3.new(1, 0, 1)).Unit)
		end

		p1.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	task.delay(0.2, function() --[[ Line: 1079 | Upvalues: p1 (copy) ]]
		p1.railDebounce = false
	end)
end
function t.OnHitboxTouch(p1, p2) --[[ OnHitboxTouch | Line: 1089 | Upvalues: v6 (copy), ReplicatedStorage (copy), v1 (copy), v7 (copy) ]]
	if p2.Material == Enum.Material.CorrodedMetal then
		local v12 = not p1.Character:GetAttribute("FleshImmunity")

		if p1.spirit then
			v12 = false
		end

		if v12 then
			v6.Events.FleshTileTouched:FireServer()
		end
	end

	if p2.Name == "SpringerShockwave" and not p1.springerDebounce then
		p1.springerDebounce = true
		p1.hitBySpringer = true

		local Unit = ((p1.RootPart.Position - p2.Position) * Vector3.new(1, 0, 1)).Unit
		local v2 = p2.Parent:GetAttribute("Big")
		local v3

		if p1:HasCurse("Springloaded") then
			v3 = Unit * 100 + Vector3.new(0, 120, 0)

			if v2 then
				v3 = v3 * 1.15
			end
		else
			v3 = Unit * 40 + Vector3.new(0, 75, 0)

			if v2 then
				v3 = v3 * 1.3
			end
		end

		if p1:HasCurse("SpringerKill") then
			ReplicatedStorage.Events.Died:FireServer("Springer", v3, game.ReplicatedStorage.Level.Value)
		else
			p1.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			p1.RootPart.Velocity = v3
			p1:SetMoveDirection(Unit * (p1.Humanoid.WalkSpeed / 25))
			p1.WantDirection = Unit * (p1.Humanoid.WalkSpeed / 25)
			task.wait(1)
			p1.springerDebounce = false
		end
	end

	if
		v1
		and (
			not p1.martSlideDebounce
			and (p2.Name == "Mart" and (p1:HasCurse("MartSlide") and p2.Parent == workspace.Enemies))
		)
	then
		p1.martSlideDebounce = true

		local v4 = v7:NextUnitVector() * v7:NextNumber(45, 70)
		local v8 = Vector3.new(math.min(p2.Velocity.X, 80), math.min(p2.Velocity.Y, 80), (math.min(p2.Velocity.Z, 80)))
			+ Vector3.new(0, 20, 0)
			+ v4
		local v10 = v8 * math.min((p2:GetAttribute("Scale") - 1) * 0.3 + 1, 2)

		p1.RootPart.Velocity = v10
		p1:SetMoveDirection(p1.RootPart.Velocity.Unit * Vector3.new(1, 0, 1))

		if v10.Magnitude > 300 then
			ReplicatedStorage.Events.BadgeEvent:FireServer("MartSlide")
		end

		task.delay(0.5, function() --[[ Line: 1161 | Upvalues: p1 (copy) ]]
			p1.martSlideDebounce = false
		end)
	end

	if not p1.jumpToRail and (p2.Name == "_RailPart" and not (p1.rail or p1.railDebounce)) then
		p1:FollowRail(p2)
	end

	if p2.Name == "TriaOrb" and not p1.triaDebounce then
		if p1.rail then
			return
		end

		if p1.ActiveSpecial and (p1.diving or (p1.grappling or (p1.charging or p1.gliding))) then
			p1.ActiveSpecial:End()
		end

		p1.slideJumped = false

		if p1.sliding then
			p1.SlideManager:EndSlide()
		end

		p1.triaDebounce = true
		p1.Animator:FaceDirection(p2.CFrame.LookVector)
		p1:SetMoveDirection(Vector3.new(0, 0, 0))
		p1.DoubleJump:Refresh()
		p2:FindFirstChild("Active"):Play()

		if p1.chargePound then
			p1.ActiveSpecial.altForceHold = false
			p1.ActiveSpecial.abilityToggled = false
		end

		local TRIA_WELD = Instance.new("AlignPosition")

		TRIA_WELD.MaxAxesForce = Vector3.new(10000000, 10000000, 10000000)
		TRIA_WELD.Responsiveness = 120
		TRIA_WELD.Mode = Enum.PositionAlignmentMode.OneAttachment
		TRIA_WELD.Attachment0 = p1.RootPart.RootAttachment
		TRIA_WELD.Position = p2.Position
		TRIA_WELD.Name = "TRIA_WELD"
		TRIA_WELD:SetAttribute("CFrame", p2.CFrame)
		TRIA_WELD.Parent = p1.RootPart
		p1.triaHold = true
	end

	if p2.Name == "JumpPad" and not p1.jumpPadDebounce then
		if p1.Character:FindFirstChild("Razorbloom") then
			p1.Character.Razorbloom.ClientBindable:Fire("Disable")
		end

		p1.Animator:FaceMoveDirection()
		p1.antiJumpPadClipMethod = true
		task.delay(0.07, function() --[[ Line: 1242 | Upvalues: p1 (copy) ]]
			p1.antiJumpPadClipMethod = false
		end)

		local v11 = p1:HasCurse("WeakJumpPads")

		p1.jumpPadAirControl = true
		p1.usedDoubleJumpInAir = false
		p1.usedGrappleInAir = false
		p1.DoubleJump:Refresh()
		p1.jumpPadDebounce = true

		if p1.jumpPadTweens[p2] then
			p1.jumpPadTweens[p2]:Cancel()
			p1.jumpPadTweens[p2]:Destroy()
			p1.jumpPadTweens[p2] = nil
		end

		p1.slideJumped = false

		if p1.ClassID == "class/Diver" and v1 then
			ReplicatedStorage.Events.MovementGiftMagnet:Fire({
				Reset = "Solve my puzzle",
			})
		end

		p2:FindFirstChild("Pad" .. math.random(1, 3)):Play()

		local v12 = if v11 and not p2:IsDescendantOf(workspace.CurrentRooms) then 60 else 100

		if p1.chargePound then
			if p1.specialHeld then
				p1.specialHeld = false
				p1.ActiveSpecial.abilityToggled = false
				p1.ActiveSpecial:SpecialAction(Enum.UserInputState.Begin, true)
				p1.Animator:FaceMoveDirection()
				v12 = v12 * 0.85
			else
				p1.ActiveSpecial.altForceHold = false
				p1.ActiveSpecial.abilityToggled = false
				v12 = v12 * 1.35
			end

			p1.chargePound = false
		end

		if p1.ActiveSpecial then
			if p1.diving or p1.grappling then
				p1.ActiveSpecial:End()
			end

			if p1.ActiveSpecial.OnJumpPad then
				p1.ActiveSpecial:OnJumpPad()
			end
		end

		p1.RootPart.Velocity = Vector3.new(p1.RootPart.Velocity.X, v12, p1.RootPart.Velocity.Z)
		task.wait(0.1)
		p1.jumpPadDebounce = false

		for v13, v14 in p2:GetTouchingParts() do
			if v14 == p1.Hitbox then
				print("lets prevent clipping through the jump pad")
				p1:OnHitboxTouch(p2)

				return
			end
		end
	else
		if p2.Name ~= "GrapplePoint" or p1.jumpPadDebounce then
			return
		end

		if p1.Character:FindFirstChild("Razorbloom") then
			p1.Character.Razorbloom.ClientBindable:Fire("Disable")
		end

		if p1.ActiveSpecial.OnJumpPad and p1.ClassID == "class/Glider" then
			p1.ActiveSpecial:OnJumpPad()
		end

		p1.antiJumpPadClipMethod = true
		task.delay(0.07, function() --[[ Line: 1319 | Upvalues: p1 (copy) ]]
			p1.antiJumpPadClipMethod = false
		end)
		p1.Animator:FaceMoveDirection()
		p1.jumpPadAirControl = true
		p1.usedDoubleJumpInAir = false
		p1.usedGrappleInAir = false
		p1.DoubleJump:Refresh()
		p1.jumpPadDebounce = true

		if p1.jumpPadTweens[p2] then
			p1.jumpPadTweens[p2]:Cancel()
			p1.jumpPadTweens[p2]:Destroy()
			p1.jumpPadTweens[p2] = nil
		end

		p1.slideJumped = false

		if p1.ClassID == "class/Diver" and v1 then
			ReplicatedStorage.Events.MovementGiftMagnet:Fire({
				Reset = "Solve my puzzle",
			})
		end

		p1.Animator:StopAnimation("DiveLoop")
		p1.Animator:StopAnimation("DiveStart")

		if p1.SpecialID == "Grapple" and (p1.SpecialID ~= "Grapple" or not p1.Status.HasStatus("Medal")) then
			local v15, v16

			if p1:HasCurse("WeakJumpPads") then
				v15 = 1.1
				v16 = 140
			else
				v15 = 1.5
				v16 = 180
			end

			local v17 = p1.RootPart.Velocity.Magnitude * v15

			if v16 < v17 then
				v17 = v16
			end

			p1.RootPart.Velocity = p1.RootPart.Velocity.Unit * v17
		else
			local v18 = if p1:HasCurse("WeakJumpPads") then 75 else 120

			if p1.chargePound then
				if p1.specialHeld then
					p1.specialHeld = false
					p1.ActiveSpecial.abilityToggled = false
					p1.ActiveSpecial:SpecialAction(Enum.UserInputState.Begin, true)
					p1.Animator:FaceMoveDirection()
				else
					p1.ActiveSpecial.altForceHold = false
					p1.ActiveSpecial.abilityToggled = false
					v18 = v18 * 1.2
				end

				p1.chargePound = false
			end

			p1.RootPart.Velocity = Vector3.new(p1.RootPart.Velocity.X, v18, p1.RootPart.Velocity.Z)
			p2:FindFirstChild("Pad1"):Play()
		end

		if p1.diving or p1.grappling then
			p1.ActiveSpecial:End()
		end

		task.wait(0.1)
		p1.jumpPadDebounce = false

		for v19, v20 in p2:GetTouchingParts() do
			if v20 == p1.Hitbox then
				print("lets prevent clipping through the jump Grapple point")
				p1:OnHitboxTouch(p2)

				return
			end
		end
	end
end
function t.OnStateChanged(p1, p2, p3) --[[ OnStateChanged | Line: 1414 | Upvalues: v1 (copy), ReplicatedStorage (copy) ]]
	if p3 == Enum.HumanoidStateType.Running then
		p1.hitBySpringer = false
		p1.leftGroundWithinBell = false
		p1.leftGroundWhileFleshed = false
		p1.agcJumped = false
		p1.DoubleJump:Refresh()

		if p1.jumpPressed and not (p1.diving or (p1.sliding or p1.charging)) then
			if p1.grappleJumpCancel then
				p1.grappleJumpCancel = false

				return
			end

			if p1.Status.HasStatus("Concussion") then
				return
			end

			p1.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end

		if p1.diveBonked then
			p1.diveBonked = false
			p1.bonkedOffPlayer = false
			p1.Animator:StopAnimation("DiveBonk")
		end
	end

	if p3 == Enum.HumanoidStateType.Jumping then
		p1.agcJumped = true
		p1.realWingsGrace = time()

		if p1.grappling then
			p1.ActiveSpecial:End()
		end

		p1.Animator:FaceMoveDirection()

		if p1.SFX.legacy and p1.isDoubleJumping then
			p1.SFX:LegacyDoubleJump()
		elseif not p1.isDoubleJumping then
			p1.SFX:PlaySound("Jump", true)
		end

		if p1.grappleJumping then
			p1.grappleJumping = false
		else
			p1.Character:SetAttribute("Jumps", p1.Character:GetAttribute("Jumps") - 1)
		end

		p1.isDoubleJumping = false

		local v12 = p1:HasUpgrade("AdvancedGravityCoil") and true

		if v12 or p1.spirit then
			local v2 = 60

			if v12 and p1.spirit then
				v2 = 90
			elseif v12 and p1.ClassID == "class/Wanted" then
				v2 = 100
			end

			if p1.advancedCoilTask then
				task.cancel(p1.advancedCoilTask)
				p1.advancedCoilTask = nil
			end

			p1.advancedCoilTask = task.spawn(function() --[[ Line: 1477 | Upvalues: p1 (copy), v2 (ref) ]]
				local v1 = time()
				local v22 = time()

				while true do
					local v3 = time() - v1
					local RootPart = p1.RootPart

					RootPart.Velocity = RootPart.Velocity + Vector3.new(0, 1, 0) * v2 * v3 * (1 - (time() - v22))

					local v4 = time()

					task.wait()

					if p1.RootPart.Velocity.Y <= 2 or (p1.jumpPressed == false or time() - v22 > 1) then
						break
					end

					v1 = v4
				end
			end)
		end

		p1:FlipFlop()
	end

	if p3 == Enum.HumanoidStateType.Landed then
		p1.usedGrappleInAir = false
		p1.usedDoubleJumpInAir = false
		p1.hitBySpringer = false
		p1.leftGroundWithinBell = false
		p1.leftGroundWhileFleshed = false
		p1.agcJumped = false
		p1.jumpPadAirControl = false
		p1.railJumpSpeed = 0
		p1.slideJumped = false

		if v1 and p1.ClassID == "class/Diver" then
			ReplicatedStorage.Events.MovementGiftMagnet:Fire({
				Reset = "Solve my puzzle",
			})
		end

		p1.storedSlideVel = Vector3.new(0, 0, 0)
		p1.grappleJumpCancel = false

		if p1.diveBonked then
			if v1 and (time() - p1.lastStunTime > 3 and ReplicatedStorage.InRound.Value) then
				ReplicatedStorage.Events.BadgeEvent:FireServer("NearDeathExperience")
			end

			p1.diveBonked = false
			p1.bonkedOffPlayer = false
			p1.Animator:StopAnimation("DiveBonk")
		end

		if p1.SpecialID ~= "Dive" or not p1.diving then
			if p1.SFX.Legacy then
				p1.SFX:PlayStepSound(1)
			else
				p1.SFX:PlayLandSound(p1.RootPart.Velocity)
			end
		end
	end

	if p3 == Enum.HumanoidStateType.Dead then
		if v1 then
			local v3 = p1.RootPart.Position.Y < workspace.KillVoid.Position.Y + 20

			if p1.diveBonked and (v3 and p1.bonkedOffPlayer) then
				ReplicatedStorage.Events.BadgeEvent:FireServer("CommunicationWin")
			end

			if p1.hitBySpringer and v3 then
				ReplicatedStorage.Events.BadgeEvent:FireServer("IchHasseEs")
			end

			if p1.leftGroundWhileFleshed and v3 then
				ReplicatedStorage.Events.BadgeEvent:FireServer("ComedicSlippingSfx")
			end
		end

		p1:Unload()
	end

	if p3 == Enum.HumanoidStateType.Freefall then
		if p1.Status.HasStatus("Flesh") then
			p1.leftGroundWhileFleshed = true
		end

		if time() - p1.lastBellTime < 1.2 then
			p1.leftGroundWithinBell = true
		end
	end

	if p1.ActiveSpecial and p1.ActiveSpecial.OnStateChanged then
		p1.ActiveSpecial:OnStateChanged(p2, p3)
	end

	p1.DoubleJump:OnStateChanged(p2, p3)
	shared.LeftGroundWithinBellMethod = p1.leftGroundWithinBell
end
function t.OnStatusChange(p1, p2, p3) --[[ OnStatusChange | Line: 1578 ]]
	if
		p2 == "Flesh"
		and (
			p3
			and (
				p1.ActiveSpecial
				and (p1.ActiveSpecial.End and (p1.diving or (p1.grappling or (p1.spirit or p1.charging))))
			)
		)
	then
		p1.ActiveSpecial:End()
	end

	if p2 ~= "Medal" or not p3 then
		return
	end

	if p1.ActiveSpecial and (p1.diving or (p1.grappling or (p1.spirit or p1.charging))) then
		p1.ActiveSpecial:End()
	end

	local t = {}

	t.MedalStatus = if p3 then 1 else 0
	p1.DoubleJump:Refresh(t)
end
function t.JumpButton(p1, p2) --[[ JumpButton | Line: 1598 ]]
	if p1.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	local v1 = false

	if p2 == Enum.UserInputState.Begin then
		p1.jumpPressed = true

		if p1.RootPart.Anchored then
			return
		end

		local v2 = p1.Humanoid:GetState()
		local v3 = if v2 == Enum.HumanoidStateType.Running then true else v2 == Enum.HumanoidStateType.Landed

		if p1.triaHold then
			p1.triaHold = false
			p1.RootPart.TRIA_WELD:Destroy()
			p1.SFX:PlaySound("TriaExit", true)

			local PlayerMoveDirection = p1.PlayerMoveDirection

			if PlayerMoveDirection == Vector3.new(0, 0, 0) then
				PlayerMoveDirection = p1.RootPart.CFrame.LookVector * 0.5 * Vector3.new(1, 0, 1)
					+ Vector3.new(0, 0.3, 0)
			end

			p1.RootPart.Velocity = PlayerMoveDirection * 70 * p1.movementSpeedMulti + Vector3.new(0, 70, 0)
			p1.RootPart.RotVelocity = Vector3.new(0, 0, 0)
			p1.Hitbox.RotVelocity = Vector3.new(0, 0, 0)
			p1.SFX:PlaySound("Jump", true)
			p1:SetMoveDirection(PlayerMoveDirection)
			p1.slideJumpSpeed = p1.slideJumpSpeed + 40
			p1.jumpPadAirControl = true
			task.wait(0.15)
			p1.triaDebounce = false

			return
		end

		if p1.rail then
			p1.rail = false
			p1.railJumped = true

			return
		end

		if p1.jumpToRail then
			for v4, v5 in p1.Hitbox:GetTouchingParts() do
				if v5.Name == "_RailPart" and not (p1.rail or p1.railDebounce) then
					p1:FollowRail(v5)

					return
				end
			end
		end

		if v3 and not p1.sliding then
			if p1.grappleJumpCancel then
				p1.grappleJumpCancel = false

				return
			end

			if p1.Status.HasStatus("Concussion") then
				return
			end

			if p1.charging then
				if p1:HasUpgrade("NinjaBelt") then
					task.spawn(function() --[[ Line: 1666 | Upvalues: p1 (copy) ]]
						p1.ActiveSpecial:End(false, true)
					end)
					p1.classSpeedMulti = 0
					p1.slideJumpSpeed = 24

					local v6 = p1.RootPart.Velocity * Vector3.new(1, 0, 1)
						+ p1.TrueMoveDirection * p1.Humanoid.WalkSpeed
					local v8 = v6.Unit * math.min(v6.Magnitude, p1.Humanoid.WalkSpeed * 2.5)

					if v8 ~= v8 then
						v8 = Vector3.new(0, 0, 0)
					end

					p1.RootPart.Velocity = v8 + Vector3.new(0, p1.RootPart.Velocity.Y, 0)
				else
					p1.ActiveSpecial:End(false, false)
					p1.classSpeedMulti = 0
				end
			end

			p1.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		elseif p1.sliding and v3 or (p1.diving or p1.sliding) then
			if p1.diving then
				p1.ActiveSpecial:UpdateParticles(0)

				for v9, v10 in p1.ActiveSpecial.DiveParticles do
					if not string.find(v10.Name, "Start") then
						v10.Enabled = false
					end
				end
			end

			p1.SlideManager:EndSlide("SlideCancel", p1.diving)
			p1:AdjustHitbox()
			v1 = true
		elseif p1.grappling then
			p1.grappleJumpCancel = true
			p1.ActiveSpecial:End()
		elseif p1.diveSharkTech then
			p1.ActiveSpecial:UpdateParticles(0)
			p1.diveSharkTech = false
			p1:SetMoveDirection(p1.TrueMoveUnit)

			local RootPart = p1.RootPart

			RootPart.Velocity = RootPart.Velocity + p1.TrueMoveDirection * p1.RootPart.Velocity.Y * 0.35
			p1.slideJumpSpeed = p1.slideJumpSpeed + p1.RootPart.Velocity.Y * 0.35
		elseif p1.Humanoid:GetState() ~= Enum.HumanoidStateType.Landed then
			p1.DoubleJump:TryDoubleJump()
		end
	end

	if p2 == Enum.UserInputState.End then
		p1.jumpPressed = false

		if p1.RootPart.Anchored then
			return
		end

		if p1:HasUpgrade("AdvancedGravityCoil") then
			local agcJumped = p1.agcJumped
		end
	end

	if not p1:HasUpgrade("RealWings") then
		p1.realWingsEnabled = false

		return
	end

	p1.realWingsEnabled = p1.jumpPressed and (if p1.realWingsTime > 0 then not v1 else false)
end
function t.SprintButton(p1, p2) --[[ SprintButton | Line: 1737 ]]
	if p2 == Enum.UserInputState.Begin then
		if p1.toggleSprint == true then
			p1.sprintHeld = not p1.sprintHeld
		else
			p1.sprintHeld = true
		end
	else
		if p2 ~= Enum.UserInputState.End or p1.toggleSprint == true then
			return
		end

		p1.sprintHeld = false
	end
end
function t.SpecialAction(p1, p2) --[[ SpecialAction | Line: 1751 ]]
	if p2 ~= Enum.UserInputState.Begin and p2 ~= Enum.UserInputState.End then
		return
	end

	if p2 == Enum.UserInputState.Begin then
		p1.specialHeld = true
	elseif p2 == Enum.UserInputState.End then
		p1.specialHeld = false
	end

	if not (p1.ActiveSpecial and p1.ActiveSpecial.SpecialAction) then
		return
	end

	p1.ActiveSpecial:SpecialAction(p2)
end
function t.AltSpecialAction(p1, p2) --[[ AltSpecialAction | Line: 1765 ]]
	if p2 ~= Enum.UserInputState.Begin and p2 ~= Enum.UserInputState.End then
		return
	end

	if p2 == Enum.UserInputState.Begin then
		p1.altSpecialHeld = true
	elseif p2 == Enum.UserInputState.End then
		p1.altSpecialHeld = false
	end

	if not (p1.ActiveSpecial and p1.ActiveSpecial.AltSpecialAction) then
		return
	end

	p1.ActiveSpecial:AltSpecialAction(p2)
end
function t.DiveBonk(p1, p2) --[[ DiveBonk | Line: 1779 | Upvalues: ReplicatedStorage (copy), TweenService (copy), Players (copy) ]]
	p1.diveBonked = true
	p1.lastStunTime = time()
	p1.diving = false
	p1.sliding = false
	p1:AdjustHitbox()
	p1.Humanoid:SetAttribute("UsingAbility", false)

	if p2 then
		if p2.Instance.Name == "Seamine" then
			p2.Instance.Bonked:FireServer()
		end

		local v1 = p2.Instance.Parent.Parent

		if (v1.Name == "Springer" or v1.Name == "BigSpringer") and v1:GetAttribute("Jumping") then
			local v2 = v1:GetAttribute("JumpStart")
			local v3 = v1:GetAttribute("JumpDuration")
			local v4 = (time() - v2) / v3

			if v4 >= 0.15 and v4 <= 0.85 then
				ReplicatedStorage.Events.BadgeEvent:FireServer("BestPatch5Feature")
			end
		end
	end

	if p1.ClassID == "class/Glider" then
		return
	end

	if p1.SFX.LoadedSounds.Dive_Alt and p1.SFX.LoadedSounds.Dive_Alt.IsPlaying then
		TweenService:Create(p1.SFX.LoadedSounds.Dive_Alt, TweenInfo.new(0.2), {
			Volume = 0,
		}):Play()
	end

	local v6 = if p2
		then p1.TrueMoveDirection - 2 * p1.TrueMoveDirection:Dot(p2.Normal) * p2.Normal
		else -p1.TrueMoveDirection
	local sum = math.max(p1.RootPart.Velocity.Y, 10)

	p1:SetMoveDirection(v6 * Vector3.new(1, 0, 1))

	if p1:HasUpgrade("Helmet") then
		sum = sum + 30
	end

	p1.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	p1.DiveParticles.Bonk:Emit(math.random(14, 21))
	p1.RootPart.Velocity = v6 * (p1.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude + Vector3.new(0, sum, 0)

	if p1.RootPart:FindFirstChild("DiveVelocity") then
		p1.RootPart.DiveVelocity:Destroy()
	end

	p1.SFX:PlaySound("Bonk")

	if p1.diveBonked then
		if p2 and Players:GetPlayerFromCharacter(p2.Instance.Parent) then
			p1.bonkedOffPlayer = true
		end

		p1:AdjustHitbox(3, 0.5)
		p1.Animator:PlayAnimation("DiveBonk")
		p1.Animator:StopAnimation("SlideStart")
		p1.Animator:StopAnimation("DiveStart")
		p1.Animator:StopAnimation("DiveLoop")
	end

	p1.Animator:FaceMoveDirection()
end
function t.AdjustHitbox(p1, p2, p3) --[[ AdjustHitbox | Line: 1864 ]]
	local v3 = if p1.sliding then 1 else 2

	if p1.diving then
		v3 = 1.5
	end

	p1.Hitbox.Size = Vector3.new(p2 or 3, v3, v3)
	p1.RootPart.HitboxWeld.C1 = CFrame.new(-(p3 or 0.5), 0, 0)
end
function t.SetMoveDirection(p1, p2) --[[ SetMoveDirection | Line: 1882 ]]
	p1.TrueMoveDirection = p2

	if p1.TrueMoveDirection ~= p1.TrueMoveDirection then
		p1.TrueMoveDirection = Vector3.new(0, 0, 0)
	end

	if not (p1.TrueMoveDirection.Magnitude > 0.001) then
		return
	end

	p1.TrueMoveUnit = p1.TrueMoveDirection.Unit
end
function t.CheckFlipFlop(p1) --[[ CheckFlipFlop | Line: 1892 ]]
	if not p1:HasCurse("FlipFlop") then
		return
	end

	local v1 = OverlapParams.new()

	v1.FilterDescendantsInstances = { workspace.CurrentRooms }
	v1.FilterType = Enum.RaycastFilterType.Include

	local v2 = workspace:GetPartsInPart(p1.Hitbox, v1)

	for v3, v4 in p1.insideFlipFlop do
		if not table.find(v2, v4) and v4:GetAttribute("FlipEnabled") ~= false then
			v4.Transparency = 0
			v4.CanCollide = true
			v4.CanTouch = true
			p1.insideFlipFlop[v3] = nil
		end
	end
end
function t.Step(p1, p2) --[[ Step | Line: 1913 | Upvalues: UserInputService (copy), v1 (copy) ]]
	if p1.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	if p1.Character:FindFirstChild("Torso") then
		p1.Character.Torso.CanCollide = false
	end

	if p1.Character:FindFirstChild("Head") then
		p1.Character.Head.CanCollide = false
	end

	if not p1.Humanoid.PlatformStand then
		p1.RootPart.RotVelocity = Vector3.new(0, 0, 0)
		p1.Hitbox.RotVelocity = Vector3.new(0, 0, 0)
	end

	if p1.Character:FindFirstChild("HumanoidRootPart") == nil then
		return
	end

	local v12 = math.min(p2, 0.05)
	local v2 = p1.ControlModule:GetMoveVector()

	if p1.Status.HasStatus("Fire") then
		v2 = Vector3.new(0, 0, -1)
	end

	p1.PlayerMoveDirection = (p1.Camera.CFrame * CFrame.Angles(-p1.Camera.CFrame:ToOrientation(), 0, 0)):VectorToWorldSpace(
		v2
	) * Vector3.new(1, 0, 1)

	if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
		p1.sprintHeld = v2.Magnitude > 0.5
	end

	p1.PlayerMoveDirection = p1.PlayerMoveDirection.Unit

	if p1.PlayerMoveDirection ~= p1.PlayerMoveDirection then
		p1.PlayerMoveDirection = Vector3.new(0, 0, 0)
	end

	if p1.RootPart.Anchored then
		p1.PlayerMoveDirection = Vector3.new(0, 0, 0)
		p1:SetMoveDirection(Vector3.new(0, 0, 0))
		p1.WantDirection = Vector3.new(0, 0, 0)
	end

	p1.TrueMoveDirection = p1.TrueMoveDirection * Vector3.new(1, 0, 1)
	p1.HumanoidMovement:Step(v12)
	p1.SlideManager:Step(v12)

	if p1.ActiveSpecial and p1.ActiveSpecial.Step then
		p1.ActiveSpecial:Step(v12)
	end

	if p1:HasUpgrade("IceSkates") then
		local v5 = p1.WantDirection:Dot(p1.TrueMoveDirection)
		local v6 = v5 ^ 2 * math.sign(v5)
		local v7 = p1.Status.HasStatus("Panic")

		if p1.Humanoid.FloorMaterial == Enum.Material.Ice then
			p1.friction = p1.friction * (if p1.doingQuickTurn then 0.85 else 0.75)
		end

		if p1.Humanoid.FloorMaterial == Enum.Material.CorrodedMetal and not v7 then
			p1.friction = p1.friction * (if p1.doingQuickTurn then 0.9 else 0.8)
		end

		local v10 = v6 - 0.8 - (1 - p1.sprintSpeed / 8)

		p1.iceSkateSpeed = math.clamp(
			p1.iceSkateSpeed + (if v10 > 0 then v10 * 1.6666666666666667 else v10 * (35 * (p1.friction / 4))) * v12,
			0,
			4
		)
		p1.iceSkateMulti = math.clamp(p1.iceSkateSpeed / 4 * 0.1, 0, 0.1)
	else
		local v14 = p1.Status.HasStatus("Panic")

		p1.iceSkateSpeed = 0
		p1.iceSkateMulti = 0

		if p1.Humanoid.FloorMaterial == Enum.Material.Ice then
			p1.friction = p1.friction * (if p1.doingQuickTurn then 0.5 else 0.25)
		end

		if p1.Humanoid.FloorMaterial == Enum.Material.CorrodedMetal and not v14 then
			p1.friction = p1.friction * (if p1.doingQuickTurn then 0.75 else 0.5)
		end
	end

	if p1.diveBonked and p1.Humanoid:GetState() == Enum.HumanoidStateType.Running then
		p1.diveBonked = false
		p1.bonkedOffPlayer = false
		p1.Animator:StopAnimation("DiveBonk")
	end

	if p1.triaHold then
		p1.friction = 20
	end

	if p1:HasUpgrade("RealWings") then
		if p1.realWingsVel.Enabled and time() - p1.realWingsGrace > 0.15 then
			p1.realWingsTime = p1.realWingsTime - p2 * 1

			if p1.realWingsTime <= 0 then
				p1.realWingsEnabled = false
			end
		elseif p1.Humanoid:GetState() == Enum.HumanoidStateType.Running then
			p1.realWingsTime = p1.realWingsTime + p2 * 0.6666666666666666

			if p1.realWingsTime >= 3 and p1.DoubleJump.RealWingsEnabled then
				p1.DoubleJump.RealWingsEnabled = false

				local v17 = game.TweenService:Create(p1.DoubleJump.UI.RealWings.Outline.UIStroke, TweenInfo.new(0.25), {
					Transparency = 1,
				})
				local v18 = game.TweenService:Create(p1.DoubleJump.UI.RealWings.Bar, TweenInfo.new(0.25), {
					BackgroundTransparency = 1,
				})

				v17:Play()
				v18:Play()
			end
		end

		p1.realWingsTime = math.clamp(p1.realWingsTime, 0, 3)
		p1.DoubleJump.UI.RealWings.Bar.Size = UDim2.fromScale(p1.realWingsTime / 3, 1)
	end

	p1.realWingsVel.Enabled = p1.realWingsEnabled
		and (if p1.RootPart.Velocity.Y <= p1.realWingsVel.VectorVelocity.Y + 8 then true else false)
	p1:SetMoveDirection(p1.TrueMoveDirection:Lerp(p1.WantDirection, v12 * p1.friction))

	if p1.TrueMoveDirection.Magnitude > 0.001 then
		p1.TrueMoveUnit = p1.TrueMoveDirection.Unit
	end

	p1.Humanoid:Move(p1.TrueMoveDirection, false)
	p1.SFX:Step(v12)
	p1.Animator:Step(v12)
	p1:CheckFlipFlop()
	p1.Humanoid:SetAttribute("PlayerMoveDirection", p1.PlayerMoveDirection)
	p1.Humanoid:SetAttribute("TrueMoveDirection", p1.TrueMoveDirection)

	if
		p1:HasCurse("RandomSpawn")
		and (
			p1.antiRandomSpawnVoidBecauseTheClientMethod
			and p1.antiRandomSpawnVoidBecauseTheClientMethod.Transparency == 0
		)
	then
		p1:CheckIfAboveAntiRandomSpawnVoidMethod()
	end

	if not p1.activeFloorIndicator then
		return
	end

	local v21 = RaycastParams.new()

	if v1 then
		v21.FilterDescendantsInstances = {
			p1.Character,
			workspace:WaitForChild("Enemies"),
			workspace:WaitForChild("Item_Pools"),
			workspace:WaitForChild("Skinwalkers"),
			workspace.CurrentCamera,
		}
	else
		v21.FilterDescendantsInstances = { p1.Character, workspace.CurrentCamera }
	end

	v21.FilterType = Enum.RaycastFilterType.Exclude
	v21.RespectCanCollide = true
	v21.CollisionGroup = "AlmostQuery"

	local v22 = RaycastParams.new()

	v22.FilterDescendantsInstances = {}
	v22.FilterType = Enum.RaycastFilterType.Include

	if workspace:FindFirstChild("JumpPads") then
		v22:AddToFilter(workspace.JumpPads)
	end

	local v23 = workspace:Raycast(p1.RootPart.Position, Vector3.new(-0, -256, -0), v22)
	local v24 = if v23 then v23 else workspace:Raycast(p1.RootPart.Position, Vector3.new(-0, -256, -0), v21)

	if
		not workspace:Blockcast(p1.RootPart.CFrame, p1.RootPart.Size, Vector3.new(-0, -2.1, -0), v21)
		and (v24 and v24.Distance > 3.2)
	then
		local v25 = 3 + v24.Distance / 35
		local v27 = math.clamp(math.map(v24.Distance, 3.2, 6, 1, 0), 0, 1) + (v24.Distance / 100) ^ 2

		p1.activeFloorIndicator.Size = Vector3.new(v25, v25, 0.01)
		p1.activeFloorIndicator.CFrame = CFrame.lookAlong(v24.Position, v24.Normal)
		p1.activeFloorIndicator.SurfaceGui.ImageLabel.ImageTransparency = v27

		return
	end

	p1.activeFloorIndicator.Size = Vector3.new(0, 0, 0)
end

return t
