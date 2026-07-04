--!nocheck
--[[
	NULLSCAPE - Grappler Intent Resolver
	Infers the likely assist mode from movement state, momentum, rails, and void context.
]]

local Workspace = game:GetService("Workspace")

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local EntityContext = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Entity Intent Context.luau")

local Resolver = {}

local DEFAULT_VOID_HEIGHT = 45
local DEFAULT_RAIL_RANGE = 14
local DEFAULT_HIGH_SPEED = 120

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getNumber(value, fallback, minimum, maximum)
	return math.clamp(tonumber(value) or fallback, minimum, maximum)
end

local function getVelocity(rootPart)
	if MomentumMemory and typeof(MomentumMemory.getState) == "function" then
		local success, state = pcall(function()
			return MomentumMemory.getState(rootPart, 0.3)
		end)
		if success and state and state.Velocity then
			return state.Velocity, state
		end
	end

	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or Vector3.zero, nil
end

local function getKillVoidY()
	if TerrainMemory and typeof(TerrainMemory.getVoidInfo) == "function" then
		local voidInfo = TerrainMemory.getVoidInfo()
		if voidInfo then
			return voidInfo.Y
		end
	end

	local killVoid = Workspace:FindFirstChild("KillVoid", true)
	if killVoid and killVoid:IsA("BasePart") then
		return killVoid.Position.Y
	end

	return nil
end

local function isAirborne(grapple)
	local humanoid = grapple and grapple.Humanoid
	if not humanoid then
		return true
	end

	if humanoid.FloorMaterial ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air then
		return false
	end

	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Running and state ~= Enum.HumanoidStateType.Landed
end

local function getNearbyRailScore(rootPart, controller)
	if not (RailMemory and typeof(RailMemory.getNearbyRails) == "function") then
		return 0
	end

	local range = getNumber(controller and controller.GrappleIntentRailRange, DEFAULT_RAIL_RANGE, 4, 48)
	local rails = RailMemory.getNearbyRails(rootPart.Position, range)
	if #rails <= 0 then
		return 0
	end

	return math.clamp(0.45 + (#rails * 0.08), 0, 1)
end

function Resolver.resolve(grapple, controller, context)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and rootPart.Parent) then
		return {
			Name = "None",
			Confidence = 0,
		}
	end

	local velocity, state = getVelocity(rootPart)
	local horizontalSpeed = flatten(velocity).Magnitude
	local airborne = isAirborne(grapple)
	local killVoidY = getKillVoidY()
	local heightAboveVoid = killVoidY and rootPart.Position.Y - killVoidY or math.huge
	local voidHeight = getNumber(controller and controller.GrappleVoidRescueHeight, DEFAULT_VOID_HEIGHT, 10, 160)
	local railScore = getNearbyRailScore(rootPart, controller)
	local highSpeed = getNumber(controller and controller.GrappleIntentHighSpeed, DEFAULT_HIGH_SPEED, 40, 300)

	if airborne and heightAboveVoid >= 0 and heightAboveVoid <= voidHeight then
		return {
			Name = "VoidRescue",
			Confidence = 0.95,
			Velocity = velocity,
			MomentumState = state,
			Airborne = airborne,
			HeightAboveVoid = heightAboveVoid,
			AimDirection = context and context.AimDirection,
		}
	end

	if
		EntityContext
		and typeof(EntityContext.isRazorbloomActive) == "function"
		and EntityContext.isRazorbloomActive()
	then
		return {
			Name = "RazorbloomEscape",
			Confidence = 0.92,
			Velocity = velocity,
			MomentumState = state,
			Airborne = airborne,
			AimDirection = context and context.AimDirection,
		}
	end

	if
		context
		and context.Technique == "ReelSaver"
		and airborne
		and controller
		and controller.GrappleReelSaverEnabled == true
	then
		return {
			Name = "ReelSaver",
			Confidence = 0.68,
			Velocity = velocity,
			MomentumState = state,
			Airborne = airborne,
			AimDirection = context and context.AimDirection,
		}
	end

	if railScore > 0 then
		return {
			Name = "RailCapture",
			Confidence = railScore,
			Velocity = velocity,
			MomentumState = state,
			Airborne = airborne,
			AimDirection = context and context.AimDirection,
		}
	end

	if horizontalSpeed >= highSpeed then
		return {
			Name = "MomentumControl",
			Confidence = math.clamp((horizontalSpeed - highSpeed) / highSpeed + 0.45, 0.45, 0.9),
			Velocity = velocity,
			MomentumState = state,
			Airborne = airborne,
			AimDirection = context and context.AimDirection,
		}
	end

	return {
		Name = "AnchorAssist",
		Confidence = 0.5,
		Velocity = velocity,
		MomentumState = state,
		Airborne = airborne,
		AimDirection = context and context.AimDirection,
	}
end

return Resolver
