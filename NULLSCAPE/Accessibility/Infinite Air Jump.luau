-- [[
--  NULLSCAPE - Infinite Air Jump
--  Lightweight bypass-first air jump.
--  It no longer scans getgc on enable; cached DoubleJump is only used opportunistically
--  for animation/UI polish when already available.
-- ]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local Logic = {}

local BAR_REFRESH_INTERVAL = 0.45
local JUMP_REQUEST_DEBOUNCE = 0.08
local FALLBACK_JUMP_POWER = 38
local DOUBLE_JUMP_ANIMATION_NAMES = {
	"DoubleJump",
	"Double Jump",
	"Jump_Double",
	"DoubleJumpAnimation",
}
local MAX_ANIMATION_DESCENDANTS = 160

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
	local globals = getGlobals()
	local accessibilityController = globals.activeAccessibilityController
	if accessibilityController and accessibilityController.InfiniteAirJumpEnabled == true then
		return true
	end

	local upgradeController = globals.activeUpgradeController
	return upgradeController and upgradeController.AirJumpSimulationEnabled == true
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
		local success = pcall(function()
			animator:PlayAnimation("DoubleJump")
		end)
		if success then
			setStatus("fallback jump + native anim")
			return true
		end
	end

	return false
end

local function findNamedAnimation(root)
	if not root then
		return nil
	end

	for _, wantedName in ipairs(DOUBLE_JUMP_ANIMATION_NAMES) do
		local direct = root:FindFirstChild(wantedName, true)
		if direct and direct:IsA("Animation") and tostring(direct.AnimationId or "") ~= "" then
			return direct
		end
	end

	local checked = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		checked = checked + 1
		if checked > MAX_ANIMATION_DESCENDANTS then
			break
		end
		if descendant:IsA("Animation") then
			local name = string.lower(descendant.Name)
			if
				string.find(name, "double")
				and string.find(name, "jump")
				and tostring(descendant.AnimationId or "") ~= ""
			then
				return descendant
			end
		end
	end

	return nil
end

local function getInventoryHandler()
	local globals = getGlobals()
	if typeof(globals.InfiniteAirJumpInventoryHandler) == "table" then
		return globals.InfiniteAirJumpInventoryHandler
	end

	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local core = clientModules and clientModules:FindFirstChild("Core")
	local playerData = core and core:FindFirstChild("PlayerData")
	local inventoryHandlerModule = playerData and playerData:FindFirstChild("InventoryHandler")
	if not inventoryHandlerModule then
		return nil
	end

	local success, inventoryHandler = pcall(require, inventoryHandlerModule)
	if success and typeof(inventoryHandler) == "table" then
		globals.InfiniteAirJumpInventoryHandler = inventoryHandler
		return inventoryHandler
	end

	return nil
end

local function getCosmetics()
	local globals = getGlobals()
	if typeof(globals.InfiniteAirJumpCosmetics) == "table" then
		return globals.InfiniteAirJumpCosmetics
	end

	local cosmeticsModule = ReplicatedStorage:FindFirstChild("Cosmetics")
	if not cosmeticsModule then
		return nil
	end

	local success, cosmetics = pcall(require, cosmeticsModule)
	if success and typeof(cosmetics) == "table" then
		globals.InfiniteAirJumpCosmetics = cosmetics
		return cosmetics
	end

	return nil
end

local function getEquippedAnimationPackId()
	local inventoryHandler = getInventoryHandler()
	if not (inventoryHandler and typeof(inventoryHandler.GetEquipped) == "function") then
		return ""
	end

	local success, equipped = pcall(function()
		return inventoryHandler.GetEquipped("AnimationPack")
	end)
	if not success then
		return ""
	end

	return tostring(equipped or "")
end

local function getEquippedAnimationPackRoot()
	local equipped = getEquippedAnimationPackId()
	if equipped == "" then
		return nil, equipped
	end

	local cosmetics = getCosmetics()
	if not (cosmetics and typeof(cosmetics.GetById) == "function") then
		return nil, equipped
	end

	local success, cosmetic = pcall(function()
		return cosmetics.GetById(equipped)
	end)
	if success and typeof(cosmetic) == "table" then
		local animations = cosmetic.Animations
		if typeof(animations) == "Instance" then
			return animations, equipped
		end
	end

	return nil, equipped
end

local function resolveDoubleJumpAnimationId()
	local globals = getGlobals()
	local equippedRoot, equippedPackId = getEquippedAnimationPackRoot()
	local cacheKey = equippedPackId ~= "" and equippedPackId or "Default"
	if
		globals.InfiniteAirJumpAnimationKey == cacheKey
		and type(globals.InfiniteAirJumpAnimationId) == "string"
		and globals.InfiniteAirJumpAnimationId ~= ""
	then
		return globals.InfiniteAirJumpAnimationId
	end

	local localPlayer = Players.LocalPlayer
	local animationsFolder = ReplicatedStorage:FindFirstChild("Animations")
	local animationInstances = animationsFolder and animationsFolder:FindFirstChild("Instances")
	local defaultAnimations = animationInstances and animationInstances:FindFirstChild("Default")
	local roots = {
		equippedRoot,
		defaultAnimations,
		localPlayer.Character,
		localPlayer:FindFirstChild("PlayerScripts"),
	}

	for _, root in ipairs(roots) do
		local animation = findNamedAnimation(root)
		if animation then
			globals.InfiniteAirJumpAnimationKey = cacheKey
			globals.InfiniteAirJumpAnimationId = animation.AnimationId
			return animation.AnimationId
		end
	end

	globals.InfiniteAirJumpAnimationKey = nil
	globals.InfiniteAirJumpAnimationId = nil
	return nil
end

local function playFallbackDoubleJumpAnimation(humanoid)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end

	local animationId = resolveDoubleJumpAnimationId()
	if not animationId then
		return false
	end

	local animation = Instance.new("Animation")
	animation.Name = "NULLSCAPE_DoubleJump"
	animation.AnimationId = animationId

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if not success or not track then
		return false
	end

	pcall(function()
		track.Priority = Enum.AnimationPriority.Action2
		track:Play(0.05, 1, 1)
	end)

	getGlobals().InfiniteAirJumpLastAnimationTrack = track
	return true
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
	local playedAnimation = false
	if doubleJump then
		sustainVirtualJump(doubleJump, true)
		playedAnimation = playDoubleJumpAnimation(doubleJump)
	end
	if not playedAnimation then
		playedAnimation = playFallbackDoubleJumpAnimation(humanoid)
	end

	local velocity = rootPart.AssemblyLinearVelocity or rootPart.Velocity
	local boostedVelocity = Vector3.new(velocity.X, math.max(velocity.Y, FALLBACK_JUMP_POWER), velocity.Z)
	pcall(function()
		rootPart.AssemblyLinearVelocity = boostedVelocity
	end)
	pcall(function()
		rootPart.Velocity = boostedVelocity
	end)
	MomentumMemory.noteImpulse(rootPart, "InfiniteAirJump", velocity, boostedVelocity, boostedVelocity - velocity, {
		Power = FALLBACK_JUMP_POWER,
	})
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)

	setStatus(playedAnimation and "fallback jump + anim" or "fallback jump")
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
		globals.InfiniteAirJumpAnimationKey = nil
		globals.InfiniteAirJumpAnimationId = nil
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
	globals.InfiniteAirJumpAnimationKey = nil
	globals.InfiniteAirJumpAnimationId = nil
	globals.InfiniteAirJumpLastAnimationTrack = nil
	globals.InfiniteAirJumpListenerConnected = nil
end

function Logic.getStatus()
	return getGlobals().InfiniteAirJumpStatus or "pending"
end

return Logic
