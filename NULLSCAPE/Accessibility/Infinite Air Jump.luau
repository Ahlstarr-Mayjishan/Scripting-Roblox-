-- [[
--  NULLSCAPE - Infinite Air Jump
--  Keeps the native DoubleJump path alive instead of fighting MovementCore.
--  The hook grants one temporary DoubleJump charge right before TryDoubleJump runs,
--  so keyboard, mobile, and gamepad jump inputs all use the game's own animation/SFX.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Logic = {}

local HOOK_REFRESH_INTERVAL = 0.25
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
		setStatus("getgc unavailable")
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
			local rootPart = rawget(value, "RootPart")
			if not character or value.Character == character or (rootPart and rootPart.Parent == character) then
				getGlobals().InfiniteAirJumpLastMovement = value
				return value
			end
		end
	end

	return nil
end

local function getActiveDoubleJump()
	local globals = getGlobals()
	local cachedDoubleJump = globals.InfiniteAirJumpHookedDoubleJump or globals.InfiniteAirJumpLastDoubleJump
	if typeof(cachedDoubleJump) == "table" then
		local movement = rawget(cachedDoubleJump, "Movement")
		local character = Players.LocalPlayer.Character
		if isMovementAlive(movement) and (not character or not movement or movement.Character == character) then
			return cachedDoubleJump
		end
	end

	local movement = findMovementCoreInstance()
	if movement and typeof(movement.DoubleJump) == "table" then
		globals.InfiniteAirJumpLastMovement = movement
		globals.InfiniteAirJumpLastDoubleJump = movement.DoubleJump
		return movement.DoubleJump
	end

	if typeof(getgc) ~= "function" then
		setStatus("getgc unavailable")
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
				globals.InfiniteAirJumpLastDoubleJump = value
				return value
			end
		end
	end

	setStatus("DoubleJump not found")
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

local function tryNativeAirJump()
	local doubleJump = getActiveDoubleJump()
	if not doubleJump then
		setStatus("DoubleJump missing")
		return false
	end

	local movement = rawget(doubleJump, "Movement")
	if not (isMovementAlive(movement) and isAirborne(movement)) then
		setStatus("not airborne")
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
			sustainVirtualJump(doubleJump, true)
			local afterY = movement and movement.RootPart and movement.RootPart.Velocity.Y or nil
			local moved = beforeY == nil or afterY == nil or afterY > beforeY - 0.01
			setStatus(moved and "native jump" or "native blocked")
			return moved
		end
		setStatus("native error")
	end

	return false
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

	local doubleJump = getActiveDoubleJump()
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
	if not tryNativeAirJump() then
		tryFallbackAirJump()
	end
end

local function requestAirJump()
	local globals = getGlobals()
	local currentTime = os.clock()
	if currentTime - (globals.InfiniteAirJumpLastRequestAt or 0) < JUMP_REQUEST_DEBOUNCE then
		return
	end

	globals.InfiniteAirJumpLastRequestAt = currentTime
	refreshHook(false)
	doAirJump()
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
			sustainVirtualJump(self, false)
		end

		local result = originalTryDoubleJump(self, ...)
		if forceInfiniteJump then
			playDoubleJumpAnimation(self)
			sustainVirtualJump(self, true)
		end

		return result
	end

	return true
end

local function refreshHook(forceBarRefresh)
	local doubleJump = getActiveDoubleJump()
	if doubleJump then
		hookDoubleJump(doubleJump)
		if shouldJump() then
			sustainVirtualJump(doubleJump, forceBarRefresh == true)
		end
		setStatus("hooked")
	end
end

local function startHeartbeat()
	local globals = getGlobals()
	if globals.InfiniteAirJumpHeartbeatConnection then
		return
	end

	globals.InfiniteAirJumpHeartbeatConnection = RunService.Heartbeat:Connect(function()
		if not shouldJump() then
			return
		end

		local currentTime = os.clock()
		if currentTime - (globals.InfiniteAirJumpLastHookRefresh or 0) < HOOK_REFRESH_INTERVAL then
			return
		end

		globals.InfiniteAirJumpLastHookRefresh = currentTime
		refreshHook(false)
	end)
end

function Logic.initialize()
	local globals = getGlobals()
	refreshHook(true)
	startHeartbeat()

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
		task.defer(function()
			refreshHook(true)
		end)
		task.delay(0.5, function()
			refreshHook(true)
		end)
		task.delay(1.5, function()
			refreshHook(true)
		end)
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
	if globals.InfiniteAirJumpHeartbeatConnection then
		pcall(function()
			globals.InfiniteAirJumpHeartbeatConnection:Disconnect()
		end)
		globals.InfiniteAirJumpHeartbeatConnection = nil
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
