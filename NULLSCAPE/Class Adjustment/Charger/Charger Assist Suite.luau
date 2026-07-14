--!nocheck
-- Executor-facing native interop: getgc/hookfunction do not expose stable Luau types.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")
local Context = getgenv().loadModule("NULLSCAPE/Class Adjustment/Charger/Charger Assist Context.luau")
local HookBridge = getgenv().loadModule("NULLSCAPE/Class Adjustment/Charger/Charger Assist Hooks.luau")

local Suite = {
	Controller = nil,
	Connections = {},
	LastSafetyCheckAt = 0,
	Status = {
		Charging = false,
		Grounded = false,
		ChainReady = false,
		SharkTailReady = false,
		AirPlatformProtected = false,
		LongJumpSafe = true,
		MovementFound = false,
	},
	Input = {
		PrimaryHeld = false,
		AltHeld = false,
		SyntheticPrimary = false,
		DeferredPrimaryEnd = false,
		DeferredAltEnd = false,
		LastBeginAt = 0,
		LastBeginWasAlt = false,
		PendingSharkTailAt = 0,
		PendingSharkTailWasAlt = false,
		LastReleaseAt = 0,
	},
}

local LONG_JUMP_RELEASE_WINDOW = 0.4
local SAFETY_CHECK_INTERVAL = 0.1

local function isCharger()
	return ClassContext and ClassContext.is("Charger")
end

local function getSetting(name, fallback)
	local value = Suite.Controller and Suite.Controller[name]
	return value ~= nil and value or fallback
end

local function callNative(isAlt, inputState)
	return HookBridge.call(isAlt, inputState)
end

local function isSafeAhead(character, root)
	local distance = math.clamp(tonumber(getSetting("ChargerLongJumpGuardDistance", 18)) or 18, 8, 40)
	return Context.isSafeAhead(character, root, distance)
end

local function bufferChargeChain(now)
	if getSetting("ChargerChargeChainAssistEnabled", false) ~= true then
		return false
	end
	local buffer = math.clamp(tonumber(getSetting("ChargerChargeChainBuffer", 0.25)) or 0.25, 0.05, 0.5)
	if now - Suite.Input.LastBeginAt > buffer then
		return false
	end
	callNative(Suite.Input.LastBeginWasAlt, Enum.UserInputState.Begin)
	return true
end

local function retrySharkTail(now)
	if getSetting("ChargerSharkTailTimingAssistEnabled", false) ~= true then
		return false
	end
	local window = math.clamp(tonumber(getSetting("ChargerSharkTailTimingWindow", 0.25)) or 0.25, 0.05, 0.6)
	if Suite.Input.PendingSharkTailAt <= 0 or now - Suite.Input.PendingSharkTailAt > window then
		return false
	end
	local useAlt = Suite.Input.PendingSharkTailWasAlt
	Suite.Input.PendingSharkTailAt = 0
	callNative(useAlt, Enum.UserInputState.Begin)
	return true
end

local function protectAirPlatformInput(isAlt, inputState, humanoid)
	local input = Suite.Input
	local began = inputState == Enum.UserInputState.Begin
	if isAlt then
		input.AltHeld = began
	else
		input.PrimaryHeld = began
	end

	if began then
		input.LastBeginAt = time()
		input.LastBeginWasAlt = isAlt
		if Suite.Status.Charging and not (isAlt and not Context.isGrounded(humanoid)) then
			input.PendingSharkTailAt = input.LastBeginAt
			input.PendingSharkTailWasAlt = isAlt
		end
		if
			isAlt
			and getSetting("ChargerAirPlatformAssistEnabled", false) == true
			and not Context.isGrounded(humanoid)
			and not input.PrimaryHeld
		then
			callNative(false, Enum.UserInputState.Begin)
			input.SyntheticPrimary = true
		end
		return false
	end

	if Suite.Status.Charging and Suite.Status.Grounded then
		input.LastReleaseAt = time()
	end
	if getSetting("ChargerAirPlatformAssistEnabled", false) ~= true then
		return false
	end
	if isAlt and input.PrimaryHeld then
		input.DeferredAltEnd = true
		return true
	elseif not isAlt and input.AltHeld then
		input.DeferredPrimaryEnd = true
		return true
	end
	return false
end

local function guardLongJump()
	if getSetting("ChargerLongJumpGuardEnabled", false) ~= true or not isCharger() then
		return false
	end
	if time() - Suite.Input.LastReleaseAt > LONG_JUMP_RELEASE_WINDOW then
		return false
	end
	local character, humanoid, root = Context.getCharacterState()
	if not (humanoid and root) or isSafeAhead(character, root) then
		return false
	end
	humanoid.Jump = false
	root.AssemblyLinearVelocity = Vector3.new(
		root.AssemblyLinearVelocity.X,
		math.min(0, root.AssemblyLinearVelocity.Y),
		root.AssemblyLinearVelocity.Z
	)
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)
	callNative(false, Enum.UserInputState.Begin)
	Suite.Status.LongJumpSafe = false
	return true
end

local function flushDeferredEnds()
	local input = Suite.Input
	if input.PrimaryHeld or input.AltHeld then
		return
	end
	if input.DeferredPrimaryEnd then
		input.DeferredPrimaryEnd = false
		callNative(false, Enum.UserInputState.End)
	end
	if input.DeferredAltEnd then
		input.DeferredAltEnd = false
		callNative(true, Enum.UserInputState.End)
	end
	if input.SyntheticPrimary then
		input.SyntheticPrimary = false
		callNative(false, Enum.UserInputState.End)
	end
end

local HookHandlers = {
	isActive = isCharger,
	before = function(isAlt, inputState)
		local _, humanoid = Context.getCharacterState()
		return protectAirPlatformInput(isAlt, inputState, humanoid)
	end,
	after = function(_, inputState)
		if inputState == Enum.UserInputState.End then
			flushDeferredEnds()
		end
	end,
}

local function updateStatus(now, character, humanoid, root)
	local previousCharging = Suite.Status.Charging
	local previousGrounded = Suite.Status.Grounded
	local charging = Context.isCharging(character, humanoid) == true
	local grounded = Context.isGrounded(humanoid)
	Suite.Status.Charging = charging
	Suite.Status.Grounded = grounded

	if previousCharging and not charging then
		Suite.ChargeEndedAt = now
		retrySharkTail(now)
	end
	if not previousGrounded and grounded then
		bufferChargeChain(now)
	end

	local chainBuffer = math.clamp(tonumber(getSetting("ChargerChargeChainBuffer", 0.25)) or 0.25, 0.05, 0.5)
	local sharkWindow = math.clamp(tonumber(getSetting("ChargerSharkTailTimingWindow", 0.25)) or 0.25, 0.05, 0.6)
	Suite.Status.ChainReady = grounded and now - Suite.Input.LastBeginAt <= chainBuffer
	Suite.Status.SharkTailReady = not charging and now - (Suite.ChargeEndedAt or 0) <= sharkWindow
	Suite.Status.AirPlatformProtected = getSetting("ChargerAirPlatformAssistEnabled", false) == true
		and (Suite.Input.PrimaryHeld and Suite.Input.AltHeld or Suite.Input.SyntheticPrimary)

	if now - Suite.LastSafetyCheckAt >= SAFETY_CHECK_INTERVAL then
		Suite.LastSafetyCheckAt = now
		Suite.Status.LongJumpSafe = isSafeAhead(character, root)
	end
end

local function step()
	if not isCharger() then
		Suite.Status.Charging = false
		Suite.Status.Grounded = false
		Suite.Status.MovementFound = false
		return
	end
	local character, humanoid, root = Context.getCharacterState()
	if not (character and humanoid and root) then
		return
	end
	local movement = Context.findMovement(character, humanoid)
	Suite.Status.MovementFound = movement ~= nil
	if movement then
		HookBridge.install(movement, HookHandlers)
	end
	updateStatus(time(), character, humanoid, root)
end

local function shouldRun(controller)
	return controller
		and (
			controller.ChargerChargeChainAssistEnabled == true
			or controller.ChargerSharkTailTimingAssistEnabled == true
			or controller.ChargerAirPlatformAssistEnabled == true
			or controller.ChargerLongJumpGuardEnabled == true
		)
end

local function disconnectAll()
	for _, connection in pairs(Suite.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	Suite.Connections = {}
end

function Suite.update(controller)
	Suite.Controller = controller
	if not shouldRun(controller) then
		Suite.stop()
		return false
	end
	if not Suite.Connections.Step then
		Suite.Connections.Step = RunService.RenderStepped:Connect(step)
		Suite.Connections.Jump = UserInputService.JumpRequest:Connect(guardLongJump)
	end
	return true
end

function Suite.stop()
	disconnectAll()
	HookBridge.restore()
	Suite.Controller = nil
	Suite.ChargeEndedAt = nil
	Suite.LastSafetyCheckAt = 0
	Context.reset()
	for key, value in pairs(Suite.Input) do
		Suite.Input[key] = typeof(value) == "boolean" and false or 0
	end
	Suite.Status.Charging = false
	Suite.Status.Grounded = false
	Suite.Status.ChainReady = false
	Suite.Status.SharkTailReady = false
	Suite.Status.AirPlatformProtected = false
	Suite.Status.LongJumpSafe = true
	Suite.Status.MovementFound = false
end

function Suite.getStatus()
	return table.clone(Suite.Status)
end

return Suite
