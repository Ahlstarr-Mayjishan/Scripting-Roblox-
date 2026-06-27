-- [[
--  NULLSCAPE - Infinite Air Jump
--  Keeps the native DoubleJump path alive instead of fighting MovementCore.
--  The hook grants one temporary DoubleJump charge right before TryDoubleJump runs,
--  so keyboard, mobile, and gamepad jump inputs all use the game's own animation/SFX.
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Logic = {}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function shouldJump()
	local controller = getGlobals().activeAccessibilityController
	return controller and controller.InfiniteAirJumpEnabled == true
end

local function isMovementAlive(movement)
	local character = movement and movement.Character or Players.LocalPlayer.Character
	local humanoid = movement and movement.Humanoid or (character and character:FindFirstChildOfClass("Humanoid"))
	return humanoid and humanoid.Parent and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

local function isAirborne(movement)
	local humanoid = movement and movement.Humanoid
	if not humanoid then
		local character = Players.LocalPlayer.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
	end

	if not humanoid then
		return false
	end

	local state = humanoid:GetState()
	return humanoid.FloorMaterial == Enum.Material.Air
		and state ~= Enum.HumanoidStateType.Running
		and state ~= Enum.HumanoidStateType.Landed
		and state ~= Enum.HumanoidStateType.Dead
end

local function findMovementCoreInstance()
	if typeof(getgc) ~= "function" then
		return nil
	end

	local character = Players.LocalPlayer.Character
	for _, value in ipairs(getgc(true)) do
		if typeof(value) == "table"
			and rawget(value, "DoubleJump")
			and rawget(value, "JumpButton")
			and rawget(value, "Humanoid")
			and rawget(value, "RootPart")
		then
			if not character or value.Character == character then
				return value
			end
		end
	end

	return nil
end

local function getActiveDoubleJump()
	local movement = findMovementCoreInstance()
	if movement and typeof(movement.DoubleJump) == "table" then
		return movement.DoubleJump
	end

	if typeof(getgc) ~= "function" then
		return nil
	end

	local character = Players.LocalPlayer.Character
	for _, value in ipairs(getgc(true)) do
		if typeof(value) == "table"
			and rawget(value, "TryDoubleJump")
			and rawget(value, "AvailableJumps")
			and rawget(value, "Movement")
		then
			local movementValue = rawget(value, "Movement")
			if not character or not movementValue or movementValue.Character == character then
				return value
			end
		end
	end

	return nil
end

local function grantTemporaryJump(doubleJump)
	if typeof(doubleJump) ~= "table" then
		return false
	end

	local availableJumps = rawget(doubleJump, "AvailableJumps")
	if typeof(availableJumps) ~= "table" then
		availableJumps = {}
		doubleJump.AvailableJumps = availableJumps
	end

	if (tonumber(availableJumps.DoubleJump) or 0) < 1 then
		availableJumps.DoubleJump = 1
	end

	local movement = rawget(doubleJump, "Movement")
	if movement then
		movement.usedDoubleJumpInAir = false
		local character = movement.Character
		if character and typeof(character.SetAttribute) == "function" then
			pcall(function()
				character:SetAttribute("Jumps", math.max(tonumber(character:GetAttribute("Jumps")) or 0, 1))
			end)
		end
	end

	return true
end

local function playDoubleJumpAnimation(doubleJump)
	local animator = doubleJump and rawget(doubleJump, "Animator")
	if animator and typeof(animator.PlayAnimation) == "function" then
		pcall(function()
			animator:PlayAnimation("DoubleJump")
		end)
	end
end

local function tryNativeAirJump()
	local doubleJump = getActiveDoubleJump()
	if not doubleJump then
		return false
	end

	local movement = rawget(doubleJump, "Movement")
	if not (isMovementAlive(movement) and isAirborne(movement)) then
		return false
	end

	grantTemporaryJump(doubleJump)
	if typeof(doubleJump.TryDoubleJump) == "function" then
		local beforeY = movement and movement.RootPart and movement.RootPart.Velocity.Y or nil
		local success = pcall(function()
			doubleJump:TryDoubleJump()
		end)
		if success then
			playDoubleJumpAnimation(doubleJump)
			local afterY = movement and movement.RootPart and movement.RootPart.Velocity.Y or nil
			return beforeY == nil or afterY == nil or afterY > beforeY - 0.01
		end
	end

	return false
end

local function doAirJump()
	tryNativeAirJump()
end

local function hookDoubleJump(doubleJump)
	local globals = getGlobals()
	if globals.InfiniteAirJumpHookedDoubleJump == doubleJump then
		return true
	end
	if typeof(doubleJump) ~= "table" or typeof(doubleJump.TryDoubleJump) ~= "function" then
		return false
	end

	if globals.InfiniteAirJumpOriginalTryDoubleJump and globals.InfiniteAirJumpHookedDoubleJump then
		pcall(function()
			globals.InfiniteAirJumpHookedDoubleJump.TryDoubleJump = globals.InfiniteAirJumpOriginalTryDoubleJump
		end)
	end

	local originalTryDoubleJump = doubleJump.TryDoubleJump
	globals.InfiniteAirJumpOriginalTryDoubleJump = originalTryDoubleJump
	globals.InfiniteAirJumpHookedDoubleJump = doubleJump

	doubleJump.TryDoubleJump = function(self, ...)
		local movement = rawget(self, "Movement")
		local forceInfiniteJump = shouldJump() and isMovementAlive(movement) and isAirborne(movement)
		if forceInfiniteJump then
			grantTemporaryJump(self)
		end

		local result = originalTryDoubleJump(self, ...)
		if forceInfiniteJump then
			playDoubleJumpAnimation(self)
			grantTemporaryJump(self)
		end

		return result
	end

	return true
end

local function refreshHook()
	local doubleJump = getActiveDoubleJump()
	if doubleJump then
		hookDoubleJump(doubleJump)
	end
end

function Logic.initialize()
	local globals = getGlobals()
	refreshHook()

	if globals.InfiniteAirJumpListenerConnected then
		return true
	end

	local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			if shouldJump() then
				refreshHook()
				doAirJump()
			end
		end
	end)

	local characterConnection = Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(refreshHook)
		task.delay(1, refreshHook)
	end)

	globals.InfiniteAirJumpListenerConnected = true
	globals.InfiniteAirJumpConnection = inputConnection
	globals.InfiniteAirJumpCharacterConnection = characterConnection

	return true
end

function Logic.disable()
	local globals = getGlobals()
	if globals.InfiniteAirJumpConnection then
		pcall(function()
			globals.InfiniteAirJumpConnection:Disconnect()
		end)
		globals.InfiniteAirJumpConnection = nil
	end
	if globals.InfiniteAirJumpCharacterConnection then
		pcall(function()
			globals.InfiniteAirJumpCharacterConnection:Disconnect()
		end)
		globals.InfiniteAirJumpCharacterConnection = nil
	end
	if globals.InfiniteAirJumpHookedDoubleJump and globals.InfiniteAirJumpOriginalTryDoubleJump then
		pcall(function()
			globals.InfiniteAirJumpHookedDoubleJump.TryDoubleJump = globals.InfiniteAirJumpOriginalTryDoubleJump
		end)
	end
	globals.InfiniteAirJumpHookedDoubleJump = nil
	globals.InfiniteAirJumpOriginalTryDoubleJump = nil
	globals.InfiniteAirJumpListenerConnected = nil
end

return Logic
