-- [[
--  NULLSCAPE - Infinite Air Jump
--  Uses robust UserInputService listening to allow endless jumping in the air.
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

local function doAirJump()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Parent and rootPart then
		local state = humanoid:GetState()
		if state ~= Enum.HumanoidStateType.Running 
			and state ~= Enum.HumanoidStateType.Landed 
			and state ~= Enum.HumanoidStateType.Dead then
			-- Refill native charges so game's UI and internals remain happy
			pcall(function()
				local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
				local movement = playerScripts and playerScripts:FindFirstChild("Movement")
				if movement then
					-- If there is a native double jump object, try to refill it
					local doubleJump = movement:FindFirstChild("DoubleJump")
					if doubleJump and typeof(doubleJump) == "table" and doubleJump.AvailableJumps then
						doubleJump.AvailableJumps.DoubleJump = 1
					end
				end
			end)

			-- Force Roblox physics state change to initiate another jump
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
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
