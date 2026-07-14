--!nocheck
-- [[
--  NULLSCAPE - Momentum Guard
--  Softly controls excessive horizontal momentum without touching vertical lift.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local LocalPlayer = Players.LocalPlayer

local Logic = {
	Connection = nil,
	Bound = false,
}

local DEFAULT_MAX_HORIZONTAL_SPEED = 500
local DEFAULT_MAX_VERTICAL_SPEED = 500
local DEFAULT_DECAY = 4
local DEFAULT_SOFT_REDUCTION = 0.35
local IMPULSE_GRACE_WINDOW = 0.35
local MAX_HORIZONTAL_GRACE = 80
local MAX_VERTICAL_GRACE = 120
local RENDER_STEP_NAME = "NULLSCAPE_MomentumGuard"
local RENDER_PRIORITY = Enum.RenderPriority.Character.Value + 2

local CONTINUOUS_IMPULSE_SOURCES = {
	GrappleAirControl = true,
	GrappleReelPull = true,
}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getController()
	return getGlobals().activeAccessibilityController
end

local function getMode(controller)
	local mode = tostring(controller and controller.MomentumMode or "Off")
	if mode ~= "Decay" and mode ~= "Soft Cap" then
		return "Off"
	end

	return mode
end

local function getRootPart()
	local character = LocalPlayer and LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(rootPart)
	local character = rootPart and rootPart.Parent
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getVelocity(rootPart)
	return rootPart.AssemblyLinearVelocity or rootPart.Velocity
end

local function setVelocity(rootPart, horizontalVelocity, verticalVelocity)
	rootPart.AssemblyLinearVelocity = Vector3.new(horizontalVelocity.X, verticalVelocity, horizontalVelocity.Z)
end

local function getConfig(controller)
	return {
		MaxHorizontalSpeed = math.clamp(
			tonumber(controller and controller.MomentumMaxHorizontalSpeed) or DEFAULT_MAX_HORIZONTAL_SPEED,
			100,
			500
		),
		MaxVerticalSpeed = math.clamp(
			tonumber(controller and controller.MomentumMaxVerticalSpeed) or DEFAULT_MAX_VERTICAL_SPEED,
			100,
			500
		),
		Decay = math.clamp(tonumber(controller and controller.MomentumDecay) or DEFAULT_DECAY, 0.5, 12),
		SoftReduction = math.clamp(
			tonumber(controller and controller.MomentumSoftReduction) or DEFAULT_SOFT_REDUCTION,
			0.05,
			1
		),
	}
end

local function getMomentumState(rootPart)
	if MomentumMemory and typeof(MomentumMemory.getState) == "function" then
		local success, state = pcall(function()
			return MomentumMemory.getState(rootPart, IMPULSE_GRACE_WINDOW)
		end)
		if success and state then
			return state
		end
	end

	return nil
end

local function canGuard(rootPart)
	local humanoid = getHumanoid(rootPart)
	if not humanoid then
		return true
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return false
	end

	if humanoid.Sit or humanoid.PlatformStand then
		return false
	end

	return true
end

local function applyDecay(horizontalVelocity, speed, maxSpeed, decay, dt)
	local excess = speed - maxSpeed
	local nextSpeed = speed - excess * decay * dt
	nextSpeed = math.max(maxSpeed, nextSpeed)
	return horizontalVelocity.Unit * nextSpeed
end

local function getSoftReductionAlpha(strength, dt)
	local frameScale = math.clamp((tonumber(dt) or 0) * 60, 0, 4)
	return 1 - (1 - strength) ^ frameScale
end

local function applySoftCap(horizontalVelocity, speed, maxSpeed, strength, dt)
	local excess = speed - maxSpeed
	local reduction = excess * getSoftReductionAlpha(strength, dt)
	local nextSpeed = math.max(maxSpeed, speed - reduction)
	return horizontalVelocity.Unit * nextSpeed
end

local function reduceScalar(value, limit, mode, config, dt)
	local magnitude = math.abs(value)
	if magnitude <= limit then
		return value
	end

	local sign = value >= 0 and 1 or -1
	local nextMagnitude
	if mode == "Decay" then
		local excess = magnitude - limit
		nextMagnitude = math.max(limit, magnitude - excess * config.Decay * dt)
	else
		local excess = magnitude - limit
		nextMagnitude = math.max(limit, magnitude - excess * getSoftReductionAlpha(config.SoftReduction, dt))
	end

	return sign * nextMagnitude
end

local function hasContinuousImpulse(state)
	for source in pairs((state and state.RecentSources) or {}) do
		if CONTINUOUS_IMPULSE_SOURCES[source] then
			return true
		end
	end

	return false
end

local function step(dt)
	local controller = getController()
	local mode = getMode(controller)
	if mode == "Off" then
		return
	end

	local rootPart = getRootPart()
	if not (rootPart and rootPart.Parent and canGuard(rootPart)) then
		return
	end
	if rootPart.Anchored then
		return
	end

	local config = getConfig(controller)
	local state = getMomentumState(rootPart)
	local velocity = getVelocity(rootPart)
	local horizontalVelocity = flatten(velocity)
	local horizontalSpeed = horizontalVelocity.Magnitude
	local verticalSpeed = math.abs(velocity.Y)
	local useImpulseGrace = not hasContinuousImpulse(state)
	local horizontalGrace = useImpulseGrace
			and math.min((state and state.RecentHorizontalImpulse or 0) * 0.35, MAX_HORIZONTAL_GRACE)
		or 0
	local verticalGrace = useImpulseGrace
			and math.min((state and state.RecentVerticalImpulse or 0) * 0.35, MAX_VERTICAL_GRACE)
		or 0
	local horizontalLimit = config.MaxHorizontalSpeed + horizontalGrace
	local verticalLimit = config.MaxVerticalSpeed + verticalGrace
	if (horizontalSpeed <= horizontalLimit or horizontalSpeed <= 0.05) and verticalSpeed <= verticalLimit then
		if MomentumMemory and typeof(MomentumMemory.record) == "function" then
			pcall(MomentumMemory.record, rootPart, "momentum-guard-pass")
		end
		return
	end

	local nextHorizontal = horizontalVelocity
	if horizontalSpeed > horizontalLimit and horizontalSpeed > 0.05 then
		if mode == "Decay" then
			nextHorizontal = applyDecay(horizontalVelocity, horizontalSpeed, horizontalLimit, config.Decay, dt)
		elseif mode == "Soft Cap" then
			nextHorizontal =
				applySoftCap(horizontalVelocity, horizontalSpeed, horizontalLimit, config.SoftReduction, dt)
		end
	end

	local nextVertical = reduceScalar(velocity.Y, verticalLimit, mode, config, dt)
	setVelocity(rootPart, nextHorizontal, nextVertical)
	if MomentumMemory and typeof(MomentumMemory.record) == "function" then
		pcall(MomentumMemory.record, rootPart, "momentum-guard-reduced")
	end
end

function Logic.initialize()
	if Logic.Bound then
		return true
	end

	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	end)
	RunService:BindToRenderStep(RENDER_STEP_NAME, RENDER_PRIORITY, step)
	Logic.Bound = true
	return true
end

function Logic.disable()
	if Logic.Connection then
		pcall(function()
			Logic.Connection:Disconnect()
		end)
		Logic.Connection = nil
	end
	if Logic.Bound then
		pcall(function()
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end)
		Logic.Bound = false
	end
end

return Logic
