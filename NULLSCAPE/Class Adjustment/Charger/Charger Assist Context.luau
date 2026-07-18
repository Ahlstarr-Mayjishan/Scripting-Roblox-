--!nocheck
-- Executor-facing native interop: getgc movement objects do not expose stable Luau types.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Context = {
	Movement = nil,
	LastMovementSearchAt = 0,
	Character = nil,
	Humanoid = nil,
	Root = nil,
	RaycastCharacter = nil,
	RaycastParams = RaycastParams.new(),
}

local MOVEMENT_RETRY_INTERVAL = 0.4
local SAFETY_SAMPLE_SCALES = { 0.45, 0.75, 1 }

Context.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
Context.RaycastParams.RespectCanCollide = true

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
	if
		character == Context.Character
		and Context.Humanoid
		and Context.Humanoid.Parent == character
		and Context.Root
		and Context.Root.Parent == character
	then
		return character, Context.Humanoid, Context.Root
	end

	Context.Character = character
	Context.Humanoid = character and character:FindFirstChildOfClass("Humanoid")
	Context.Root = character and character:FindFirstChild("HumanoidRootPart")
	return character, Context.Humanoid, Context.Root
end

function Context.isGrounded(humanoid)
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return humanoid.FloorMaterial ~= Enum.Material.Air
		or state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.Landed
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
		local staminaMovement = globals.NullscapeStaminaMovement
		if isLocalMovement(staminaMovement, character, humanoid) then
			Context.Movement = staminaMovement
			return staminaMovement
		end
		local railMovement = globals.NullscapeRailLocalMovement
		if isLocalMovement(railMovement, character, humanoid) then
			Context.Movement = railMovement
			return railMovement
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
	local rayParams = Context.RaycastParams
	if Context.RaycastCharacter ~= character then
		Context.RaycastCharacter = character
		rayParams.FilterDescendantsInstances = { character }
	end
	for _, scale in ipairs(SAFETY_SAMPLE_SCALES) do
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
	Context.Character = nil
	Context.Humanoid = nil
	Context.Root = nil
	Context.RaycastCharacter = nil
	Context.RaycastParams.FilterDescendantsInstances = {}
end

return Context
