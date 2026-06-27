-- [[
--  NULLSCAPE - Universal Anti Bonk
--  Suppresses DiveBonk stun while still cleaning movement state safely.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logic = {}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function shouldSuppress()
	local controller = getGlobals().activeAccessibilityController
	return controller and controller.AntiBonkEnabled == true
end

local function getMovementCore()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
	if not movementCoreScript or not movementCoreScript:IsA("ModuleScript") then
		return nil
	end

	local success, movementCore = pcall(require, movementCoreScript)
	if not success or typeof(movementCore) ~= "table" then
		return nil
	end

	return movementCore
end

local function stopAnimation(animator, name)
	if animator and typeof(animator.StopAnimation) == "function" then
		pcall(function()
			animator:StopAnimation(name)
		end)
	end
end

local function stopSound(sound)
	if sound and sound.IsPlaying then
		pcall(function()
			sound:Stop()
		end)
	end
end

local function neutralizeBonk(movement)
	if typeof(movement) ~= "table" then
		return
	end

	movement.diveBonked = false
	movement.bonkedOffPlayer = false
	movement.diving = false
	movement.sliding = false

	local humanoid = movement.Humanoid
	if humanoid and typeof(humanoid.SetAttribute) == "function" then
		pcall(function()
			humanoid:SetAttribute("UsingAbility", false)
		end)
	end

	if typeof(movement.AdjustHitbox) == "function" then
		pcall(function()
			movement:AdjustHitbox()
		end)
	end

	local animator = movement.Animator
	stopAnimation(animator, "DiveBonk")
	stopAnimation(animator, "DiveStart")
	stopAnimation(animator, "DiveLoop")
	stopAnimation(animator, "SlideStart")

	local sfx = movement.SFX
	local sounds = sfx and sfx.LoadedSounds
	if sounds then
		stopSound(sounds.Dive_Alt)
		stopSound(sounds.Dive)
		stopSound(sounds.Slide)
	end

	local rootPart = movement.RootPart
	if rootPart and rootPart:FindFirstChild("DiveVelocity") then
		pcall(function()
			rootPart.DiveVelocity:Destroy()
		end)
	end
end

local function installHook()
	local globals = getGlobals()
	local movementCore = getMovementCore()
	if not (movementCore and typeof(movementCore.DiveBonk) == "function") then
		return false
	end

	if movementCore.DiveBonk == globals.AntiBonkWrappedDiveBonk then
		return true
	end

	local previousDiveBonk = movementCore.DiveBonk
	globals.AntiBonkPreviousDiveBonk = previousDiveBonk

	local wrappedDiveBonk
	wrappedDiveBonk = function(self, ...)
		if shouldSuppress() then
			neutralizeBonk(self)
			return nil
		end

		return previousDiveBonk(self, ...)
	end

	globals.AntiBonkWrappedDiveBonk = wrappedDiveBonk
	movementCore.DiveBonk = wrappedDiveBonk
	globals.AntiBonkHooked = true
	return true
end

local function startWatchdog()
	local globals = getGlobals()
	if globals.AntiBonkWatchdog then
		return
	end

	local lastCheck = 0
	globals.AntiBonkWatchdog = RunService.Heartbeat:Connect(function()
		if not shouldSuppress() then
			return
		end

		local now = os.clock()
		if now - lastCheck < 0.5 then
			return
		end
		lastCheck = now

		local movementCore = getMovementCore()
		if movementCore and movementCore.DiveBonk ~= globals.AntiBonkWrappedDiveBonk then
			installHook()
		end
	end)
end

function Logic.initialize()
	if not installHook() then
		return false
	end

	startWatchdog()
	return true
end

function Logic.disable()
	local globals = getGlobals()
	if globals.AntiBonkWatchdog then
		pcall(function()
			globals.AntiBonkWatchdog:Disconnect()
		end)
		globals.AntiBonkWatchdog = nil
	end
end

return Logic
