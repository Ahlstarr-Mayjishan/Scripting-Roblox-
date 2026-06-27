-- [[
--  NULLSCAPE - Infinite Air Jump
--  Lightweight bypass-first air jump.
--  It no longer scans getgc on enable; cached DoubleJump is only used opportunistically
--  for animation/UI polish when already available.
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Logic = {}

local BAR_REFRESH_INTERVAL = 0.45
local JUMP_REQUEST_DEBOUNCE = 0.08
local FALLBACK_JUMP_POWER = 38

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function setStatus(text)
	local globals = getGlobals()
	globals.InfiniteAirJumpStatus = tostring(text or "ready")
	globals.InfiniteAirJumpStatusAt = os.clock()
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

local function getCachedDoubleJump()
	local globals = getGlobals()
	local cachedDoubleJump = globals.InfiniteAirJumpHookedDoubleJump or globals.InfiniteAirJumpLastDoubleJump
	if typeof(cachedDoubleJump) ~= "table" then
		return nil
	end

	local movement = rawget(cachedDoubleJump, "Movement")
	local character = Players.LocalPlayer.Character
	if isMovementAlive(movement) and (not character or not movement or movement.Character == character) then
		return cachedDoubleJump
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

local function refreshVirtualJumpBar(doubleJump, force)
	if typeof(doubleJump) ~= "table" or typeof(doubleJump.Refresh) ~= "function" then
		return false
	end

	local globals = getGlobals()
	local currentTime = os.clock()
	if not force and currentTime - (globals.InfiniteAirJumpLastBarRefresh or 0) < BAR_REFRESH_INTERVAL then
		return false
	end

	globals.InfiniteAirJumpLastBarRefresh = currentTime
	local success = pcall(function()
		doubleJump:Refresh({
			DoubleJump = math.max(tonumber(doubleJump.AvailableJumps and doubleJump.AvailableJumps.DoubleJump) or 0, 1),
		})
	end)

	return success == true
end

local function sustainVirtualJump(doubleJump, forceRefresh)
	if typeof(doubleJump) ~= "table" then
		return false
	end

	local movement = rawget(doubleJump, "Movement")
	if not isMovementAlive(movement) then
		return false
	end

	grantTemporaryJump(doubleJump)

	local character = rawget(doubleJump, "Character") or (movement and movement.Character)
	if character and typeof(character.SetAttribute) == "function" then
		pcall(function()
			character:SetAttribute("Jumps", math.max(tonumber(character:GetAttribute("Jumps")) or 0, 4))
		end)
	end

	local ui = rawget(doubleJump, "UI")
	local jumps = ui and ui:FindFirstChild("Jumps")
	local hasDoubleJumpBar = jumps and jumps:FindFirstChild("DoubleJump1") ~= nil
	local availableJumps = rawget(doubleJump, "AvailableJumps")
	local needsCharge = typeof(availableJumps) ~= "table" or (tonumber(availableJumps.DoubleJump) or 0) < 1
	if forceRefresh or needsCharge or not hasDoubleJumpBar then
		refreshVirtualJumpBar(doubleJump, forceRefresh)
		grantTemporaryJump(doubleJump)
	end

	return true
end

local function tryFallbackAirJump()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and rootPart) then
		setStatus("character missing")
		return false
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		setStatus("dead")
		return false
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		setStatus("grounded")
		return false
	end

	local doubleJump = getCachedDoubleJump()
	if doubleJump then
		sustainVirtualJump(doubleJump, true)
		playDoubleJumpAnimation(doubleJump)
	end

	local velocity = rootPart.AssemblyLinearVelocity or rootPart.Velocity
	local boostedVelocity = Vector3.new(velocity.X, math.max(velocity.Y, FALLBACK_JUMP_POWER), velocity.Z)
	pcall(function()
		rootPart.AssemblyLinearVelocity = boostedVelocity
	end)
	pcall(function()
		rootPart.Velocity = boostedVelocity
	end)
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)

	setStatus("fallback jump")
	return true
end

local function doAirJump()
	tryFallbackAirJump()
end

local function requestAirJump()
	local globals = getGlobals()
	local currentTime = os.clock()
	if currentTime - (globals.InfiniteAirJumpLastRequestAt or 0) < JUMP_REQUEST_DEBOUNCE then
		return
	end

	globals.InfiniteAirJumpLastRequestAt = currentTime
	doAirJump()
end

function Logic.initialize()
	local globals = getGlobals()
	setStatus("bypass ready")

	if globals.InfiniteAirJumpListenerConnected then
		return true
	end

	local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			if shouldJump() then
				requestAirJump()
			end
		end
	end)

	local jumpRequestConnection = UserInputService.JumpRequest:Connect(function()
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if shouldJump() then
			requestAirJump()
		end
	end)

	local characterConnection = Players.LocalPlayer.CharacterAdded:Connect(function()
		globals.InfiniteAirJumpHookedDoubleJump = nil
		globals.InfiniteAirJumpOriginalTryDoubleJump = nil
		globals.InfiniteAirJumpLastHookRefresh = 0
		globals.InfiniteAirJumpLastBarRefresh = 0
		globals.InfiniteAirJumpLastDoubleJump = nil
		globals.InfiniteAirJumpLastMovement = nil
		setStatus("bypass ready")
	end)

	globals.InfiniteAirJumpListenerConnected = true
	globals.InfiniteAirJumpConnection = inputConnection
	globals.InfiniteAirJumpJumpRequestConnection = jumpRequestConnection
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
	if globals.InfiniteAirJumpJumpRequestConnection then
		pcall(function()
			globals.InfiniteAirJumpJumpRequestConnection:Disconnect()
		end)
		globals.InfiniteAirJumpJumpRequestConnection = nil
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
	globals.InfiniteAirJumpLastHookRefresh = nil
	globals.InfiniteAirJumpLastBarRefresh = nil
	globals.InfiniteAirJumpLastRequestAt = nil
	globals.InfiniteAirJumpLastMovement = nil
	globals.InfiniteAirJumpLastDoubleJump = nil
	globals.InfiniteAirJumpListenerConnected = nil
end

function Logic.getStatus()
	return getGlobals().InfiniteAirJumpStatus or "pending"
end

return Logic
