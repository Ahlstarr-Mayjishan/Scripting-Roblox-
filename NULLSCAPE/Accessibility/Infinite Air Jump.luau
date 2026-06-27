-- [[
--  NULLSCAPE - Infinite Air Jump
--  Uses robust UserInputService listening to allow endless jumping in the air,
--  with automatic GC discovery to play native animations, sounds, and particle effects.
-- ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function getActiveAnimator()
	if typeof(getgc) ~= "function" then
		return nil
	end
	for _, v in ipairs(getgc(true)) do
		if typeof(v) == "table" and rawget(v, "PlayAnimation") and rawget(v, "Animations") then
			local doubleJumpAnim = v.Animations.DoubleJump
			if doubleJumpAnim and typeof(doubleJumpAnim) == "Instance" and doubleJumpAnim:IsA("AnimationTrack") then
				return v
			end
		end
	end
	return nil
end

local function getActiveDoubleJump()
	if typeof(getgc) ~= "function" then
		return nil
	end
	for _, v in ipairs(getgc(true)) do
		if typeof(v) == "table" and rawget(v, "UsedDoubleJump") and rawget(v, "AvailableJumps") then
			return v
		end
	end
	return nil
end

local function doAirJump()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Parent and rootPart then
		local state = humanoid:GetState()
		if state ~= Enum.HumanoidStateType.Running 
			and state ~= Enum.HumanoidStateType.Landed 
			and state ~= Enum.HumanoidStateType.Dead then
			
			-- Perform pure physics jump
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			
			local jumpVelocity = humanoid.JumpPower > 0 and humanoid.JumpPower or 50.1
			rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, jumpVelocity, rootPart.AssemblyLinearVelocity.Z)
			
			-- Play native double jump flip animation
			local animator = getActiveAnimator()
			if animator then
				pcall(function()
					animator:PlayAnimation("DoubleJump")
				end)
			end
			
			-- Play native double jump SFX and particles
			local doubleJump = getActiveDoubleJump()
			if doubleJump then
				pcall(function()
					doubleJump:UsedDoubleJump()
				end)
			end
		end
	end
end

function Logic.initialize()
	local globals = getGlobals()
	if globals.InfiniteAirJumpListenerConnected then
		return true
	end

	-- Connect to InputBegan to capture new jumps in the air
	local conn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Space then
			if shouldJump() then
				doAirJump()
			end
		end
	end)

	globals.InfiniteAirJumpListenerConnected = true
	
	-- Register to the active controller's permanent connections if possible
	local controller = globals.activeAccessibilityController
	if controller and controller.PermanentConnections then
		table.insert(controller.PermanentConnections, conn)
	end

	return true
end

return Logic
