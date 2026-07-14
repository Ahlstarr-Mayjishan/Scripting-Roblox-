--!nocheck
-- [[
--  NULLSCAPE - Bell Immunity
--  Blocks native bell screen effects and removes Mighty Gong's client-authored impulse.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local MIGHTY_GONG_WINDOW = 1.7
local NATIVE_GONG_RANGE = 38
local NATIVE_GONG_ORIGIN_SPEED = 86
local NATIVE_GONG_MULTIPLIER = 2.35
local MIN_GONG_IMPULSE = (NATIVE_GONG_ORIGIN_SPEED - NATIVE_GONG_RANGE) * NATIVE_GONG_MULTIPLIER
local IMPULSE_MATCH_RATIO = 0.65
local SCREEN_RECOVERY_DURATION = 4

local BellImmunity = {
	Controller = nil,
	HookTarget = nil,
	OriginalRingBell = nil,
	HookWaitToken = 0,
	ScreenRecoveryToken = 0,
	CharacterConnection = nil,
	BellEventConnection = nil,
	PreSimulationConnection = nil,
	PostSimulationConnection = nil,
	BaselineRoot = nil,
	BaselineVelocity = nil,
	ActiveGongs = setmetatable({}, { __mode = "k" }),
	AttachedEnemies = setmetatable({}, { __mode = "k" }),
}

local function isBlindnessImmune()
	local controller = BellImmunity.Controller
	return controller ~= nil and controller.Destroyed ~= true and controller.BellBlindnessImmune == true
end

local function isGongImmune()
	local controller = BellImmunity.Controller
	return controller ~= nil
		and controller.Destroyed ~= true
		and (controller.BellCurseImmune == true or controller.BellKnockbackImmune == true)
end

local function disconnect(connection)
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function getEnemyPosition(enemy)
	if not (enemy and enemy.Parent) then
		return nil
	end
	if enemy:IsA("BasePart") then
		return enemy.Position
	end
	if enemy:IsA("Model") then
		return enemy:GetPivot().Position
	end

	local part = enemy:FindFirstChildWhichIsA("BasePart")
	return part and part.Position or nil
end

local function getBellStrength()
	local character = LocalPlayer.Character
	if not character then
		return nil
	end

	local boioing = character:FindFirstChild("Boioing")
	local strength = boioing and boioing:FindFirstChild("Strength")
	if strength and strength:IsA("NumberValue") then
		return strength
	end

	return nil
end

local function getBellVignette()
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local staticGui = playerGui and playerGui:FindFirstChild("StaticGUI")
	local vignette = staticGui and staticGui:FindFirstChild("BellVignette")
	return vignette
end

local function hasActiveScreenEffect()
	local vignette = getBellVignette()
	if
		vignette
		and (vignette:IsA("ImageLabel") or vignette:IsA("ImageButton"))
		and vignette.ImageTransparency < 0.999
	then
		return true
	end

	local strength = getBellStrength()
	if strength and strength.Value > 0.01 then
		return true
	end

	local colorCorrection = Lighting:FindFirstChild("ColorCorrection")
	local bloom = Lighting:FindFirstChild("Bloom")
	return colorCorrection ~= nil
		and colorCorrection:IsA("ColorCorrectionEffect")
		and colorCorrection.Contrast >= 3.5
		and bloom ~= nil
		and bloom:IsA("BloomEffect")
		and bloom.Intensity > 1
end

local function neutralizeScreenEffect()
	local vignette = getBellVignette()
	if vignette and (vignette:IsA("ImageLabel") or vignette:IsA("ImageButton")) then
		vignette.ImageTransparency = 1
		vignette.Size = UDim2.fromScale(2, 2)
	end

	local strength = getBellStrength()
	if strength then
		strength.Value = 0
	end

	local colorCorrection = Lighting:FindFirstChild("ColorCorrection")
	if colorCorrection and colorCorrection:IsA("ColorCorrectionEffect") then
		colorCorrection.Brightness = 0
		colorCorrection.Contrast = 0
		colorCorrection.Saturation = 0
	end

	local bloom = Lighting:FindFirstChild("Bloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Threshold = 1
		bloom.Intensity = 0.5
	end

	local flash = Lighting:FindFirstChild("Flash")
	if flash and flash:IsA("ColorCorrectionEffect") then
		flash.Brightness = 0
		flash.Contrast = 0
		flash.Saturation = 0
	end
end

local function recoverActiveScreenEffect()
	if not isBlindnessImmune() or not hasActiveScreenEffect() then
		return
	end

	BellImmunity.ScreenRecoveryToken += 1
	local token = BellImmunity.ScreenRecoveryToken
	local deadline = time() + SCREEN_RECOVERY_DURATION

	task.spawn(function()
		repeat
			neutralizeScreenEffect()
			RunService.RenderStepped:Wait()
		until token ~= BellImmunity.ScreenRecoveryToken or not isBlindnessImmune() or time() >= deadline
	end)
end

local function restoreRingBellHook()
	if BellImmunity.HookTarget and BellImmunity.OriginalRingBell and typeof(hookfunction) == "function" then
		pcall(hookfunction, BellImmunity.HookTarget, BellImmunity.OriginalRingBell)
	end
	BellImmunity.HookTarget = nil
	BellImmunity.OriginalRingBell = nil
end

local function installRingBellHook()
	local ringBell = _G.RingBell
	if typeof(ringBell) ~= "function" then
		return false
	end
	if BellImmunity.HookTarget == ringBell then
		return true
	end

	restoreRingBellHook()
	if typeof(hookfunction) ~= "function" then
		return false
	end

	local original
	local success
	success, original = pcall(function()
		local oldFunction
		oldFunction = hookfunction(ringBell, function(...)
			if isBlindnessImmune() then
				return
			end
			return oldFunction(...)
		end)
		return oldFunction
	end)
	if not success or typeof(original) ~= "function" then
		return false
	end

	BellImmunity.HookTarget = ringBell
	BellImmunity.OriginalRingBell = original
	return true
end

local function scheduleRingBellHook(timeout, staleRingBell)
	BellImmunity.HookWaitToken += 1
	local token = BellImmunity.HookWaitToken
	local deadline = time() + timeout

	task.spawn(function()
		repeat
			if token ~= BellImmunity.HookWaitToken or not BellImmunity.Controller then
				return
			end
			if _G.RingBell ~= staleRingBell and installRingBellHook() then
				return
			end
			task.wait(0.1)
		until time() >= deadline
	end)
end

local function stopPhysicsGuard()
	disconnect(BellImmunity.PreSimulationConnection)
	disconnect(BellImmunity.PostSimulationConnection)
	BellImmunity.PreSimulationConnection = nil
	BellImmunity.PostSimulationConnection = nil
	BellImmunity.BaselineRoot = nil
	BellImmunity.BaselineVelocity = nil
end

local function removeExpiredGongs(now)
	for enemy, expiresAt in BellImmunity.ActiveGongs do
		if expiresAt <= now or not enemy.Parent then
			BellImmunity.ActiveGongs[enemy] = nil
		end
	end
end

local function ensurePhysicsGuard()
	if BellImmunity.PreSimulationConnection then
		return
	end

	BellImmunity.PostSimulationConnection = RunService.PostSimulation:Connect(function()
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			BellImmunity.BaselineRoot = root
			BellImmunity.BaselineVelocity = root.AssemblyLinearVelocity
		else
			BellImmunity.BaselineRoot = nil
			BellImmunity.BaselineVelocity = nil
		end
	end)

	BellImmunity.PreSimulationConnection = RunService.PreSimulation:Connect(function()
		local now = time()
		removeExpiredGongs(now)
		if not isGongImmune() or next(BellImmunity.ActiveGongs) == nil then
			stopPhysicsGuard()
			return
		end

		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local baseline = BellImmunity.BaselineVelocity
		if not (root and root:IsA("BasePart") and BellImmunity.BaselineRoot == root and baseline) then
			return
		end

		local currentVelocity = root.AssemblyLinearVelocity
		local velocityDelta = currentVelocity - baseline
		for enemy in BellImmunity.ActiveGongs do
			local sourcePosition = getEnemyPosition(enemy)
			if sourcePosition then
				local offset = root.Position - sourcePosition
				local distance = offset.Magnitude
				if distance > 0 and distance <= NATIVE_GONG_RANGE + 2 then
					local direction = offset.Unit
					local expectedMagnitude = (NATIVE_GONG_ORIGIN_SPEED - distance) * NATIVE_GONG_MULTIPLIER
					local outwardDelta = velocityDelta:Dot(direction)
					if
						outwardDelta
						>= math.max(MIN_GONG_IMPULSE * IMPULSE_MATCH_RATIO, expectedMagnitude * IMPULSE_MATCH_RATIO)
					then
						root.AssemblyLinearVelocity = currentVelocity - direction * expectedMagnitude
						root.Velocity = root.AssemblyLinearVelocity
						BellImmunity.ActiveGongs[enemy] = nil
						break
					end
				end
			end
		end
	end)
end

local function armMightyGong(enemy)
	if not isGongImmune() then
		return
	end
	BellImmunity.ActiveGongs[enemy] = time() + MIGHTY_GONG_WINDOW
	ensurePhysicsGuard()
end

function BellImmunity.initialize(controller)
	BellImmunity.Controller = controller
	scheduleRingBellHook(15)

	if not BellImmunity.CharacterConnection then
		BellImmunity.CharacterConnection = LocalPlayer.CharacterAdded:Connect(function()
			BellImmunity.BaselineRoot = nil
			BellImmunity.BaselineVelocity = nil
			scheduleRingBellHook(5, BellImmunity.HookTarget)
		end)
	end

	if not BellImmunity.BellEventConnection then
		local events = ReplicatedStorage:FindFirstChild("Events")
		local bellEvent = events and events:FindFirstChild("Bell")
		if bellEvent and bellEvent:IsA("RemoteEvent") then
			BellImmunity.BellEventConnection = bellEvent.OnClientEvent:Connect(function()
				if isBlindnessImmune() then
					task.defer(function()
						recoverActiveScreenEffect()
					end)
				end
			end)
		end
	end
end

function BellImmunity.update(controller)
	BellImmunity.Controller = controller
	if controller.BellBlindnessImmune == true then
		if not installRingBellHook() then
			scheduleRingBellHook(5)
		end
		recoverActiveScreenEffect()
	else
		BellImmunity.ScreenRecoveryToken += 1
	end

	if not isGongImmune() then
		table.clear(BellImmunity.ActiveGongs)
		stopPhysicsGuard()
	end
end

function BellImmunity.attachEnemy(enemy, gc)
	if BellImmunity.AttachedEnemies[enemy] then
		return
	end

	local clientEvent = enemy:FindFirstChild("ClientEvent")
	if not (clientEvent and clientEvent:IsA("RemoteEvent")) then
		return
	end

	local connection = clientEvent.OnClientEvent:Connect(function(action)
		if action == "WarpIn" then
			armMightyGong(enemy)
		end
	end)
	BellImmunity.AttachedEnemies[enemy] = connection
	gc.registerEntityConnection(enemy, connection)
end

function BellImmunity.detachEnemy(enemy)
	BellImmunity.AttachedEnemies[enemy] = nil
	BellImmunity.ActiveGongs[enemy] = nil
	if next(BellImmunity.ActiveGongs) == nil then
		stopPhysicsGuard()
	end
end

function BellImmunity.clearRuntime()
	table.clear(BellImmunity.ActiveGongs)
	table.clear(BellImmunity.AttachedEnemies)
	stopPhysicsGuard()
	BellImmunity.ScreenRecoveryToken += 1
end

function BellImmunity.disable()
	BellImmunity.clearRuntime()
	BellImmunity.HookWaitToken += 1
	restoreRingBellHook()
	disconnect(BellImmunity.CharacterConnection)
	disconnect(BellImmunity.BellEventConnection)
	BellImmunity.CharacterConnection = nil
	BellImmunity.BellEventConnection = nil
	BellImmunity.Controller = nil
	table.clear(BellImmunity.AttachedEnemies)
end

return BellImmunity
