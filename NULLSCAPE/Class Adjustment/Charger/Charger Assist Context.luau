--!nocheck
-- Executor-facing native interop: getgc movement objects do not expose stable Luau types.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Context = {
	Movement = nil,
	LastMovementSearchAt = 0,
}

local MOVEMENT_RETRY_INTERVAL = 0.4

local function isLocalMovement(candidate, character, humanoid)
	if typeof(candidate) ~= "table" then
		return false
	end
	local metatable = getmetatable(candidate)
	local specialAction = rawget(candidate, "SpecialAction")
		or (typeof(metatable) == "table" and rawget(metatable, "SpecialAction"))
	return rawget(candidate, "IsLocalPlayer") == true
		and rawget(candidate, "Player") == LocalPlayer
		and rawget(candidate, "Character") == character
		and rawget(candidate, "Humanoid") == humanoid
		and typeof(specialAction) == "function"
end

function Context.getCharacterState()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

function Context.isGrounded(humanoid)
	if not humanoid then
		return false
	end
	return humanoid.FloorMaterial ~= Enum.Material.Air
		or humanoid:GetState() == Enum.HumanoidStateType.Running
		or humanoid:GetState() == Enum.HumanoidStateType.Landed
end

function Context.isCharging(character, humanoid)
	return character
		and humanoid
		and (character:GetAttribute("ChargingCheck") == true or humanoid:GetAttribute("UsingAbility") == true)
end

function Context.findMovement(character, humanoid)
	if isLocalMovement(Context.Movement, character, humanoid) then
		return Context.Movement
	end
	Context.Movement = nil
	local globals = getgenv()._NULLSCAPE_Globals
	if globals then
		for _, candidate in ipairs({ globals.NullscapeStaminaMovement, globals.NullscapeRailLocalMovement }) do
			if isLocalMovement(candidate, character, humanoid) then
				Context.Movement = candidate
				return candidate
			end
		end
	end
	if time() - Context.LastMovementSearchAt < MOVEMENT_RETRY_INTERVAL or typeof(getgc) ~= "function" then
		return nil
	end
	Context.LastMovementSearchAt = time()
	local success, objects = pcall(getgc, true)
	if success and typeof(objects) == "table" then
		for _, candidate in next, objects do
			if isLocalMovement(candidate, character, humanoid) then
				Context.Movement = candidate
				return candidate
			end
		end
	end
	return nil
end

function Context.isSafeAhead(character, root, distance)
	if not (character and root) then
		return true
	end
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local direction = horizontal.Magnitude > 4 and horizontal.Unit
		or (flatLook.Magnitude > 0.001 and flatLook.Unit or Vector3.zAxis)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.RespectCanCollide = true
	for _, scale in ipairs({ 0.45, 0.75, 1 }) do
		local sample = root.Position + direction * distance * scale + Vector3.new(0, 3, 0)
		if not Workspace:Raycast(sample, Vector3.new(0, -24, 0), rayParams) then
			return false
		end
	end
	return true
end

function Context.reset()
	Context.Movement = nil
	Context.LastMovementSearchAt = 0
end

return Context
