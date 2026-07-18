--!nocheck
-- [[
--  NULLSCAPE - Class Adjustment Executor
--  Hooks Grapple methods once and applies class adjustments without per-frame module loads.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getgenv = getgenv

local Executor = {}
local HooksActive = false
local HookedStep = nil
local HookedSharkTail = nil
local HookedStart = nil
local HookedEnd = nil
local HookedAltSpecialAction = nil
local AirControl = nil
local ReelPull = nil
local SharkTailPull = nil
local SharkTailCooldown = nil
local GrappleRecovery = nil
local GrappleRange = nil
local HookCastSpeed = nil
local ChargerTripmineAssist = nil
local ChargerSteeringAssist = nil
local ChargerCollisionGuard = nil
local ChargerAssistSuite = nil
local ChargerAnchorCastAssist = nil
local CatapultBoost = nil
local MomentumTransfer = nil
local MAIN_THREAD_KEY = {}
local ChargePlatformDurationState = {
	ChargeModule = nil,
	OriginalDelay = nil,
	ActiveThreads = setmetatable({}, { __mode = "k" }),
	HookedMethods = {},
	ConstantPatches = {},
}
local SharkTailWindowState = setmetatable({}, { __mode = "k" })
local SharkTailEndTokens = setmetatable({}, { __mode = "k" })
local SharkTailCooldownWasEnabled = false

local MODULE_PATHS = {
	AirControl = "NULLSCAPE/Class Adjustment/Grappler/Grapple Air Control.luau",
	ReelPull = "NULLSCAPE/Class Adjustment/Grappler/Grapple Reel Pull.luau",
	SharkTailPull = "NULLSCAPE/Class Adjustment/Grappler/SharkTail Pull.luau",
	SharkTailCooldown = "NULLSCAPE/Class Adjustment/Grappler/SharkTail Cooldown.luau",
	GrappleRecovery = "NULLSCAPE/Class Adjustment/Grappler/Grapple Recovery.luau",
	GrappleRange = "NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau",
	HookCastSpeed = "NULLSCAPE/Class Adjustment/Grappler/Grapple Hook Cast Speed.luau",
	ChargerTripmineAssist = "NULLSCAPE/Class Adjustment/Charger/Tripmine Assist.luau",
	ChargerSteeringAssist = "NULLSCAPE/Class Adjustment/Charger/Steering Assist.luau",
	ChargerCollisionGuard = "NULLSCAPE/Class Adjustment/Charger/Charge Collision Guard.luau",
	ChargerAssistSuite = "NULLSCAPE/Class Adjustment/Charger/Charger Assist Suite.luau",
	ChargerAnchorCastAssist = "NULLSCAPE/Class Adjustment/Charger/Anchor Cast Assist.luau",
	CatapultBoost = "NULLSCAPE/Class Adjustment/Grappler/Grapple Catapult Boost.luau",
	MomentumTransfer = "NULLSCAPE/Class Adjustment/Grappler/Grapple Momentum Transfer.luau",
}

local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")
local AnchorAvailability = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Anchor Availability.luau")

local function isGrapplerActive()
	return HooksActive and ClassContext and ClassContext.is("Grappler")
end

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getControl()
	local globals = getgenv()._NULLSCAPE_Globals
	local controller = globals and globals.activeClassAdjustmentController
	return typeof(controller) == "table" and controller or nil
end

local function getGrappleModule()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local specials = movement and movement:FindFirstChild("Specials")
	local grappleScript = specials and specials:FindFirstChild("Grapple")
	if not (grappleScript and grappleScript:IsA("ModuleScript")) then
		return nil
	end

	local success, grappleModule = pcall(require, grappleScript)
	if
		not success
		or typeof(grappleModule) ~= "table"
		or typeof(grappleModule.new) ~= "function"
		or typeof(grappleModule.Cast) ~= "function"
		or typeof(grappleModule.Start) ~= "function"
		or typeof(grappleModule.Step) ~= "function"
		or typeof(grappleModule.End) ~= "function"
	then
		return nil
	end

	return grappleModule
end

local function getMovementModule()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCore = movement and movement:FindFirstChild("MovementCore")
	if not (movementCore and movementCore:IsA("ModuleScript")) then
		return nil
	end

	local success, movementModule = pcall(require, movementCore)
	if not success or typeof(movementModule) ~= "table" or typeof(movementModule.HasUpgrade) ~= "function" then
		return nil
	end

	return movementModule
end

local function getChargeModule()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local specials = movement and movement:FindFirstChild("Specials")
	local chargeScript = specials and (specials:FindFirstChild("Charge") or specials:FindFirstChild("Charger"))
	if not (chargeScript and chargeScript:IsA("ModuleScript")) then
		return nil
	end

	local success, chargeModule = pcall(require, chargeScript)
	return success and typeof(chargeModule) == "table" and chargeModule or nil
end

local function getAirPlatformDuration(controller)
	return math.clamp(tonumber(controller and controller.ChargerAirPlatformDuration) or 1, 1, 10)
end

local function isNativeAirPlatformDelay(value)
	local duration = tonumber(value)
	return duration ~= nil and (math.abs(duration - 1) <= 0.01 or math.abs(duration - 1.4) <= 0.01)
end

local function getCurrentThreadKey()
	return coroutine.running() or MAIN_THREAD_KEY
end

local function getExecutorDebugFunction(name)
	local environment = getgenv()
	local direct = environment[name]
	if typeof(direct) == "function" then
		return direct
	end

	local debugLibrary = environment.debug or debug
	local debugFunction = debugLibrary and debugLibrary[name]
	return typeof(debugFunction) == "function" and debugFunction or nil
end

local function patchFrameTimerConstants(chargeModule, configuredDuration)
	local getConstants = getExecutorDebugFunction("getconstants")
	local setConstant = getExecutorDebugFunction("setconstant")
	if not (getConstants and setConstant) then
		return false
	end

	local patched = false
	for _, methodName in ipairs({ "Step", "AltSpecialAction", "SpecialAction", "Start" }) do
		local method = chargeModule[methodName]
		local success, constants = pcall(getConstants, method)
		if success and typeof(method) == "function" and typeof(constants) == "table" then
			local hasHourglassCheck = false
			local baseIndexes = {}
			local bonusIndexes = {}
			for index, value in pairs(constants) do
				hasHourglassCheck = hasHourglassCheck or value == "MiniatureHourglass"
				if typeof(value) == "number" then
					if math.abs(value - 1) <= 0.01 then
						table.insert(baseIndexes, index)
					elseif math.abs(value - 0.4) <= 0.01 or math.abs(value - 1.4) <= 0.01 then
						table.insert(bonusIndexes, index)
					end
				end
			end

			local baseIndex = nil
			local bonusIndex = nil
			local closestDistance = math.huge
			if hasHourglassCheck then
				for _, possibleBase in ipairs(baseIndexes) do
					for _, possibleBonus in ipairs(bonusIndexes) do
						local distance = math.abs(possibleBase - possibleBonus)
						if distance <= 3 and distance < closestDistance then
							baseIndex = possibleBase
							bonusIndex = possibleBonus
							closestDistance = distance
						end
					end
				end
			end

			if baseIndex and bonusIndex then
				local targets = {
					{ Index = baseIndex, Original = constants[baseIndex], Replacement = configuredDuration },
					{
						Index = bonusIndex,
						Original = constants[bonusIndex],
						Replacement = math.abs(constants[bonusIndex] - 0.4) <= 0.01 and 0 or configuredDuration,
					},
				}
				for _, target in ipairs(targets) do
					if pcall(setConstant, method, target.Index, target.Replacement) then
						table.insert(ChargePlatformDurationState.ConstantPatches, {
							Function = method,
							Index = target.Index,
							Original = target.Original,
						})
						patched = true
					end
				end
			end
		end
	end
	return patched
end

local function restoreChargerAirPlatformDuration()
	local state = ChargePlatformDurationState
	local setConstant = getExecutorDebugFunction("setconstant")
	if setConstant then
		for index = #state.ConstantPatches, 1, -1 do
			local patch = state.ConstantPatches[index]
			pcall(setConstant, patch.Function, patch.Index, patch.Original)
		end
	end
	state.ConstantPatches = {}

	for methodName, hook in pairs(state.HookedMethods) do
		if state.ChargeModule and state.ChargeModule[methodName] == hook.Wrapper then
			state.ChargeModule[methodName] = hook.Original
		end
	end
	state.HookedMethods = {}
	state.ChargeModule = nil
	state.ActiveThreads = setmetatable({}, { __mode = "k" })

	if state.OriginalDelay and typeof(hookfunction) == "function" then
		pcall(hookfunction, task.delay, state.OriginalDelay)
	end
	state.OriginalDelay = nil
end

local function updateChargerAirPlatformDuration(controller)
	restoreChargerAirPlatformDuration()
	local configuredDuration = getAirPlatformDuration(controller)
	if configuredDuration <= 1 or not (ClassContext and ClassContext.is("Charger")) then
		return true
	end

	local chargeModule = getChargeModule()
	if not chargeModule then
		return false
	end

	local state = ChargePlatformDurationState
	state.ChargeModule = chargeModule
	local constantsPatched = patchFrameTimerConstants(chargeModule, configuredDuration)
	if typeof(hookfunction) ~= "function" then
		return constantsPatched
	end

	local methodsToWrap = {}
	for _, methodName in ipairs({ "AltSpecialAction", "SpecialAction", "Start" }) do
		if typeof(chargeModule[methodName]) == "function" then
			table.insert(methodsToWrap, methodName)
		end
	end
	if #methodsToWrap == 0 then
		return constantsPatched
	end

	local delayHooked, originalDelay = pcall(function()
		return hookfunction(task.delay, function(delayTime, callback, ...)
			local activeThread = getCurrentThreadKey()
			if (state.ActiveThreads[activeThread] or 0) > 0 and isNativeAirPlatformDelay(delayTime) then
				delayTime = configuredDuration
			end
			return state.OriginalDelay(delayTime, callback, ...)
		end)
	end)
	if not delayHooked or typeof(originalDelay) ~= "function" then
		return constantsPatched
	end

	state.OriginalDelay = originalDelay
	for _, methodName in ipairs(methodsToWrap) do
		local original = chargeModule[methodName]
		if typeof(original) == "function" then
			local wrapper = function(...)
				local activeThread = getCurrentThreadKey()
				state.ActiveThreads[activeThread] = (state.ActiveThreads[activeThread] or 0) + 1
				local results = table.pack(pcall(original, ...))
				local remainingDepth = (state.ActiveThreads[activeThread] or 1) - 1
				state.ActiveThreads[activeThread] = remainingDepth > 0 and remainingDepth or nil
				if not results[1] then
					error(results[2], 0)
				end
				return table.unpack(results, 2, results.n)
			end
			state.HookedMethods[methodName] = { Original = original, Wrapper = wrapper }
			chargeModule[methodName] = wrapper
		end
	end

	if next(state.HookedMethods) == nil then
		pcall(hookfunction, task.delay, state.OriginalDelay)
		state.OriginalDelay = nil
		return constantsPatched
	end
	return true
end

local function packValues(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local function loadAdjustmentModules()
	AirControl = AirControl or getgenv().loadModule(MODULE_PATHS.AirControl)
	ReelPull = ReelPull or getgenv().loadModule(MODULE_PATHS.ReelPull)
	SharkTailPull = SharkTailPull or getgenv().loadModule(MODULE_PATHS.SharkTailPull)
	SharkTailCooldown = SharkTailCooldown or getgenv().loadModule(MODULE_PATHS.SharkTailCooldown)
	GrappleRecovery = GrappleRecovery or getgenv().loadModule(MODULE_PATHS.GrappleRecovery)
	GrappleRange = GrappleRange or getgenv().loadModule(MODULE_PATHS.GrappleRange)
	HookCastSpeed = HookCastSpeed or getgenv().loadModule(MODULE_PATHS.HookCastSpeed)
	ChargerTripmineAssist = ChargerTripmineAssist or getgenv().loadModule(MODULE_PATHS.ChargerTripmineAssist)
	ChargerSteeringAssist = ChargerSteeringAssist or getgenv().loadModule(MODULE_PATHS.ChargerSteeringAssist)
	ChargerCollisionGuard = ChargerCollisionGuard or getgenv().loadModule(MODULE_PATHS.ChargerCollisionGuard)
	CatapultBoost = CatapultBoost or getgenv().loadModule(MODULE_PATHS.CatapultBoost)
	MomentumTransfer = MomentumTransfer or getgenv().loadModule(MODULE_PATHS.MomentumTransfer)
end

local function clearStaleHooks(grappleModule, globals)
	if globals.ClassAdjustmentOriginalStep then
		if grappleModule.Step ~= globals.ClassAdjustmentOriginalStep then
			grappleModule.Step = globals.ClassAdjustmentOriginalStep
		end
		globals.ClassAdjustmentOriginalStep = nil
		HookedStep = nil
	end

	if globals.ClassAdjustmentOriginalSharkTail then
		if grappleModule.SharkTail ~= globals.ClassAdjustmentOriginalSharkTail then
			grappleModule.SharkTail = globals.ClassAdjustmentOriginalSharkTail
		end
		globals.ClassAdjustmentOriginalSharkTail = nil
		HookedSharkTail = nil
	end

	if globals.ClassAdjustmentOriginalStart then
		if grappleModule.Start ~= globals.ClassAdjustmentOriginalStart then
			grappleModule.Start = globals.ClassAdjustmentOriginalStart
		end
		globals.ClassAdjustmentOriginalStart = nil
		HookedStart = nil
	end

	if globals.ClassAdjustmentOriginalEnd then
		if grappleModule.End ~= globals.ClassAdjustmentOriginalEnd then
			grappleModule.End = globals.ClassAdjustmentOriginalEnd
		end
		globals.ClassAdjustmentOriginalEnd = nil
		HookedEnd = nil
	end

	if globals.ClassAdjustmentOriginalAltSpecialAction then
		if grappleModule.AltSpecialAction ~= globals.ClassAdjustmentOriginalAltSpecialAction then
			grappleModule.AltSpecialAction = globals.ClassAdjustmentOriginalAltSpecialAction
		end
		globals.ClassAdjustmentOriginalAltSpecialAction = nil
		HookedAltSpecialAction = nil
	end

	if globals.ClassAdjustmentOriginalCast then
		if grappleModule.Cast ~= globals.ClassAdjustmentOriginalCast then
			grappleModule.Cast = globals.ClassAdjustmentOriginalCast
		end
	end

	if globals.ClassAdjustmentOriginalShapecast and typeof(hookfunction) == "function" then
		pcall(hookfunction, workspace.Shapecast, globals.ClassAdjustmentOriginalShapecast)
		globals.ClassAdjustmentOriginalShapecast = nil
	end
end

local function applyStepAdjustments(self, dt, Control)
	if not isGrapplerActive() then
		return
	end
	if
		Control
		and (tonumber(Control.GrappleAirControlMultiplier) or 0) > 0
		and AirControl
		and typeof(AirControl.apply) == "function"
	then
		pcall(AirControl.apply, self, dt, Control)
	end
	if
		Control
		and self
		and self.jumpPadReel
		and (tonumber(Control.GrappleReelPullMultiplier) or 1.1) > 1
		and ReelPull
		and typeof(ReelPull.apply) == "function"
	then
		pcall(ReelPull.apply, self, Control)
	end
	local sharkTailCooldownEnabled = Control and Control.GrappleSharkTailNoCooldown == true
	if sharkTailCooldownEnabled and SharkTailCooldown and typeof(SharkTailCooldown.apply) == "function" then
		pcall(SharkTailCooldown.apply, self, Control)
	elseif SharkTailCooldownWasEnabled and SharkTailCooldown and typeof(SharkTailCooldown.reset) == "function" then
		pcall(SharkTailCooldown.reset)
	end
	SharkTailCooldownWasEnabled = sharkTailCooldownEnabled == true
end

local function applySharkTailAdjustment(self, previousVelocity)
	if not isGrapplerActive() then
		return
	end
	if SharkTailPull and typeof(SharkTailPull.apply) == "function" then
		pcall(SharkTailPull.apply, self, previousVelocity)
	end
end

local function setSharkTailBarColor(grapple, color)
	if not (grapple and grapple.UI and grapple.UI:FindFirstChild("Frame")) then
		return
	end

	pcall(function()
		grapple.UI.Frame.Bar.BackgroundColor3 = color
		grapple.UI.Frame.Outline.UIStroke.Color = color
	end)
end

local function resetSharkTailBar(grapple)
	if not grapple then
		return
	end

	local color = if grapple.reelCooldown or grapple.sharkTailDisable
		then Color3.new(0.5, 0.5, 0.5)
		else Color3.new(1, 1, 1)
	setSharkTailBarColor(grapple, color)
end

local function closeSharkTailWindow(grapple)
	if not grapple then
		return
	end

	grapple.allowSharkTail = false
	resetSharkTailBar(grapple)
	SharkTailWindowState[grapple] = nil
	SharkTailEndTokens[grapple] = nil
end

local function scheduleSharkTailEndCleanup(grapple)
	if not grapple then
		return
	end

	local token = {}
	SharkTailEndTokens[grapple] = token
	task.delay(0.32, function()
		if SharkTailEndTokens[grapple] ~= token then
			return
		end
		SharkTailEndTokens[grapple] = nil

		if grapple and grapple.allowSharkTail == true then
			closeSharkTailWindow(grapple)
		end
	end)
end

local function applySharkTailWindow(Control, grapple)
	local state = grapple and SharkTailWindowState[grapple]
	if
		not (
			isGrapplerActive()
			and Control
			and Control.GrappleSharkTailWindow
			and grapple
			and grapple.Movement
			and grapple.Movement:HasUpgrade("SharkTail")
			and not grapple.sharkTailDisable
			and grapple.lastGrappleRelease
			and grapple.lastGrappleRelease > 0
		)
	then
		if state then
			closeSharkTailWindow(grapple)
		end
		return
	end

	local elapsed = time() - grapple.lastGrappleRelease
	if elapsed > Control.GrappleSharkTailWindow then
		closeSharkTailWindow(grapple)
		return
	end

	if not state or state.ReleaseAt ~= grapple.lastGrappleRelease then
		state = {
			ReleaseAt = grapple.lastGrappleRelease,
			Applied = false,
			Consumed = false,
		}
		SharkTailWindowState[grapple] = state
	end

	if state.Consumed then
		closeSharkTailWindow(grapple)
		return
	end

	grapple.allowSharkTail = true
	if state.Applied then
		return
	end

	state.Applied = true
	setSharkTailBarColor(grapple, Color3.fromRGB(255, 255, 130))
end

local function consumeSharkTailWindow(grapple)
	local state = grapple and SharkTailWindowState[grapple]
	if state then
		state.Consumed = true
	end
	if grapple then
		grapple.allowSharkTail = false
		SharkTailEndTokens[grapple] = nil
	end
end

local function shouldCloseSharkTailAfterEnd(grapple, wasCancelled)
	if not grapple then
		return false
	end

	if wasCancelled ~= false then
		return true
	end

	if not grapple.UI then
		return true
	end

	return false
end

local function tryVirtualSharkTailInput(grapple, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return false
	end
	if not (grapple and grapple.allowSharkTail == true and grapple.sharkTailDisable ~= true) then
		return false
	end
	if not (grapple.Movement and grapple.Movement:HasUpgrade("SharkTail")) then
		return false
	end
	if typeof(grapple.SharkTail) ~= "function" then
		return false
	end

	local success, err = pcall(function()
		grapple:SharkTail()
	end)
	if not success then
		warn("[NULLSCAPE] Virtual SharkTail trigger failed: " .. tostring(err))
		return false
	end

	return true
end

function Executor.enable()
	if HooksActive then
		return true
	end

	local grappleModule = getGrappleModule()
	if not grappleModule then
		return false
	end

	loadAdjustmentModules()
	local globals = getGlobals()
	clearStaleHooks(grappleModule, globals)

	if typeof(hookfunction) == "function" and not globals.ClassAdjustmentOriginalShapecast then
		local originalShapecast
		originalShapecast = hookfunction(workspace.Shapecast, function(self, ...)
			local Control = getControl()
			if
				isGrapplerActive()
				and getgenv()._NULLSCAPE_InGrappleStep == true
				and Control
				and Control.GrappleWallGlide == true
			then
				return nil
			end
			return originalShapecast(self, ...)
		end)
		globals.ClassAdjustmentOriginalShapecast = originalShapecast
	end

	local movementModule = getMovementModule()
	if globals.ClassAdjustmentOriginalMovementHasUpgrade and movementModule then
		if movementModule.HasUpgrade ~= globals.ClassAdjustmentOriginalMovementHasUpgrade then
			movementModule.HasUpgrade = globals.ClassAdjustmentOriginalMovementHasUpgrade
		end
		globals.ClassAdjustmentOriginalMovementHasUpgrade = nil
	end

	if typeof(grappleModule.Step) == "function" and not globals.ClassAdjustmentOriginalStep then
		local originalStep = grappleModule.Step
		local wrappedStep
		wrappedStep = function(self, dt, ...)
			if not isGrapplerActive() then
				return originalStep(self, dt, ...)
			end

			local Control = getControl()
			local originalFilter
			local altered = false

			if
				Control
				and Control.GrappleDisableGroundRelease
				and self
				and self.Movement
				and self.Movement.grappling
				and self.grappleParams
			then
				originalFilter = self.grappleParams.FilterDescendantsInstances
				self.grappleParams.FilterDescendantsInstances = { workspace }
				altered = true
			end

			local beforeTime = self and self.Time
			local originalReelStart = nil
			if Control and Control.GrappleInstantMaxPull and self and self.jumpPadReel then
				originalReelStart = self.reelStart
				self.reelStart = time() - 2.0
			end

			local wasRopeEnabled = self and self.rope and self.rope.Enabled

			getgenv()._NULLSCAPE_InGrappleStep = true
			local stepResults = packValues(pcall(originalStep, self, dt, ...))
			getgenv()._NULLSCAPE_InGrappleStep = false

			if originalReelStart then
				self.reelStart = originalReelStart
			end

			local isRopeEnabled = self and self.rope and self.rope.Enabled
			if not wasRopeEnabled and isRopeEnabled then
				if MomentumTransfer and typeof(MomentumTransfer.apply) == "function" then
					pcall(MomentumTransfer.apply, self)
				end
			end

			if altered and self and self.grappleParams then
				self.grappleParams.FilterDescendantsInstances = originalFilter
			end

			if not stepResults[1] then
				error(stepResults[2], 0)
			end

			applyStepAdjustments(self, dt, Control)

			if GrappleRecovery and typeof(GrappleRecovery.apply) == "function" then
				pcall(GrappleRecovery.apply, self, dt, beforeTime)
			end

			if Control and Control.GrappleNoReelCooldown and self then
				self.reelCooldown = false
			end

			applySharkTailWindow(Control, self)

			return table.unpack(stepResults, 2, stepResults.n)
		end

		globals.ClassAdjustmentOriginalStep = originalStep
		HookedStep = wrappedStep
		grappleModule.Step = wrappedStep
	end

	if typeof(grappleModule.SharkTail) == "function" and not globals.ClassAdjustmentOriginalSharkTail then
		local originalSharkTail = grappleModule.SharkTail
		local wrappedSharkTail
		wrappedSharkTail = function(self, ...)
			local previousVelocity = self and self.RootPart and self.RootPart.Velocity
			local result = originalSharkTail(self, ...)
			if not isGrapplerActive() then
				return result
			end

			consumeSharkTailWindow(self)
			applySharkTailAdjustment(self, previousVelocity)
			return result
		end

		globals.ClassAdjustmentOriginalSharkTail = originalSharkTail
		HookedSharkTail = wrappedSharkTail
		grappleModule.SharkTail = wrappedSharkTail
	end

	if typeof(grappleModule.End) == "function" and not globals.ClassAdjustmentOriginalEnd then
		local originalEnd = grappleModule.End
		local wrappedEnd
		wrappedEnd = function(self, wasCancelled, ...)
			if not isGrapplerActive() then
				return originalEnd(self, wasCancelled, ...)
			end

			local yBefore = self and self.RootPart and self.RootPart.Velocity.Y
			local yVelBelowMinBefore = self and self.yVelBelowMin

			local releaseSpeed = self and self.RootPart and self.RootPart.Velocity.Magnitude
			if releaseSpeed then
				globals.GrappleLastReleaseSpeed = releaseSpeed
				globals.GrappleLastReleaseAt = time()
			end

			local results = packValues(pcall(originalEnd, self, wasCancelled, ...))
			if not results[1] then
				error(results[2], 0)
			end

			if shouldCloseSharkTailAfterEnd(self, wasCancelled) then
				closeSharkTailWindow(self)
			elseif wasCancelled == false then
				scheduleSharkTailEndCleanup(self)
			end

			if CatapultBoost and typeof(CatapultBoost.apply) == "function" then
				pcall(CatapultBoost.apply, self, yBefore, yVelBelowMinBefore)
			end

			return table.unpack(results, 2, results.n)
		end

		globals.ClassAdjustmentOriginalEnd = originalEnd
		HookedEnd = wrappedEnd
		grappleModule.End = wrappedEnd
	end

	if typeof(grappleModule.AltSpecialAction) == "function" and not globals.ClassAdjustmentOriginalAltSpecialAction then
		local originalAltSpecialAction = grappleModule.AltSpecialAction
		local wrappedAltSpecialAction
		wrappedAltSpecialAction = function(self, inputState, ...)
			if isGrapplerActive() and tryVirtualSharkTailInput(self, inputState) then
				return
			end
			return originalAltSpecialAction(self, inputState, ...)
		end

		globals.ClassAdjustmentOriginalAltSpecialAction = originalAltSpecialAction
		HookedAltSpecialAction = wrappedAltSpecialAction
		grappleModule.AltSpecialAction = wrappedAltSpecialAction
	end

	if typeof(grappleModule.Start) == "function" and not globals.ClassAdjustmentOriginalStart then
		local originalStart = grappleModule.Start
		local wrappedStart
		wrappedStart = function(self, p2, ...)
			if not isGrapplerActive() then
				return originalStart(self, p2, ...)
			end
			if
				p2
				and p2.Instance
				and AnchorAvailability
				and typeof(AnchorAvailability.evaluateBeacon) == "function"
			then
				local available = AnchorAvailability.evaluateBeacon(p2.Instance)
				if not available then
					return nil
				end
			end

			local Control = getControl()

			-- Capture JumpPad state before original Start runs
			local jumpPad = p2 and p2.Instance
			local isJumpPad = jumpPad and jumpPad.Name == "JumpPad"
			local origUses = isJumpPad and jumpPad:GetAttribute("Uses")
			local origCanQuery = isJumpPad and jumpPad.CanQuery
			local origColor = isJumpPad and jumpPad.Color

			local speedWindow = false
			if HookCastSpeed and typeof(HookCastSpeed.beforeStart) == "function" then
				local ok, enabled = pcall(HookCastSpeed.beforeStart, self, p2)
				speedWindow = ok and enabled == true
			end

			if Control and Control.GrappleInstantGroundCast == true and self and self.Humanoid then
				if self.Humanoid:GetState() == Enum.HumanoidStateType.Running then
					pcall(function()
						self.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
					end)
				end
			end

			local results = packValues(pcall(originalStart, self, p2, ...))

			if speedWindow and HookCastSpeed and typeof(HookCastSpeed.afterStart) == "function" then
				pcall(HookCastSpeed.afterStart, self)
			end

			-- Restore JumpPad state if bypass is enabled, even when native Start throws.
			if isJumpPad and Control and Control.GrappleJumpPadUsesBypassEnabled then
				pcall(function()
					jumpPad:SetAttribute("Uses", origUses)
					jumpPad.CanQuery = origCanQuery
					jumpPad.Color = origColor
				end)
			end

			if not results[1] then
				error(results[2], 0)
			end
			return table.unpack(results, 2, results.n)
		end

		globals.ClassAdjustmentOriginalStart = originalStart
		HookedStart = wrappedStart
		grappleModule.Start = wrappedStart
	end

	if typeof(grappleModule.Cast) == "function" and not globals.ClassAdjustmentOriginalCast then
		local originalCast = grappleModule.Cast
		local wrappedCast
		wrappedCast = function(self, forceRefresh, ...)
			if not isGrapplerActive() then
				return originalCast(self, forceRefresh, ...)
			end

			if GrappleRange and typeof(GrappleRange.cast) == "function" then
				local results = packValues(pcall(GrappleRange.cast, self, forceRefresh, originalCast, ...))
				if results[1] then
					return table.unpack(results, 2, results.n)
				end
			end

			return originalCast(self, forceRefresh, ...)
		end

		globals.ClassAdjustmentOriginalCast = originalCast
		globals.ClassAdjustmentHookedCast = wrappedCast
		grappleModule.Cast = wrappedCast
	end

	HooksActive = true
	return true
end

function Executor.disable()
	HooksActive = false
	SharkTailWindowState = setmetatable({}, { __mode = "k" })
	SharkTailCooldownWasEnabled = false
	if SharkTailCooldown and typeof(SharkTailCooldown.reset) == "function" then
		pcall(SharkTailCooldown.reset)
	end
	if ChargerTripmineAssist and typeof(ChargerTripmineAssist.stop) == "function" then
		pcall(ChargerTripmineAssist.stop)
	elseif ChargerTripmineAssist and typeof(ChargerTripmineAssist.update) == "function" then
		pcall(ChargerTripmineAssist.update, {
			ChargerTripmineAssistEnabled = false,
			ChargerTripmineMode = "Auto",
		})
	end
	if ChargerSteeringAssist and typeof(ChargerSteeringAssist.stop) == "function" then
		pcall(ChargerSteeringAssist.stop)
	end
	if ChargerCollisionGuard and typeof(ChargerCollisionGuard.stop) == "function" then
		pcall(ChargerCollisionGuard.stop)
	end
	if ChargerAssistSuite and typeof(ChargerAssistSuite.stop) == "function" then
		pcall(ChargerAssistSuite.stop)
	end
	if ChargerAnchorCastAssist and typeof(ChargerAnchorCastAssist.stop) == "function" then
		pcall(ChargerAnchorCastAssist.stop)
	end
	restoreChargerAirPlatformDuration()
end

function Executor.restore()
	Executor.disable()
	local globals = getGlobals()
	local grappleModule = getGrappleModule()
	local movementModule = getMovementModule()
	if movementModule and globals.ClassAdjustmentOriginalMovementHasUpgrade then
		movementModule.HasUpgrade = globals.ClassAdjustmentOriginalMovementHasUpgrade
		globals.ClassAdjustmentOriginalMovementHasUpgrade = nil
	end
	if grappleModule and HookedStep and grappleModule.Step == HookedStep then
		grappleModule.Step = globals.ClassAdjustmentOriginalStep
		globals.ClassAdjustmentOriginalStep = nil
		HookedStep = nil
	end
	if grappleModule and HookedSharkTail and grappleModule.SharkTail == HookedSharkTail then
		grappleModule.SharkTail = globals.ClassAdjustmentOriginalSharkTail
		globals.ClassAdjustmentOriginalSharkTail = nil
		HookedSharkTail = nil
	end
	if grappleModule and HookedStart and grappleModule.Start == HookedStart then
		grappleModule.Start = globals.ClassAdjustmentOriginalStart
		globals.ClassAdjustmentOriginalStart = nil
		HookedStart = nil
	end
	if grappleModule and HookedEnd and grappleModule.End == HookedEnd then
		grappleModule.End = globals.ClassAdjustmentOriginalEnd
		globals.ClassAdjustmentOriginalEnd = nil
		HookedEnd = nil
	end
	if grappleModule and HookedAltSpecialAction and grappleModule.AltSpecialAction == HookedAltSpecialAction then
		grappleModule.AltSpecialAction = globals.ClassAdjustmentOriginalAltSpecialAction
		globals.ClassAdjustmentOriginalAltSpecialAction = nil
		HookedAltSpecialAction = nil
	end
	if
		grappleModule
		and globals.ClassAdjustmentHookedCast
		and grappleModule.Cast == globals.ClassAdjustmentHookedCast
	then
		grappleModule.Cast = globals.ClassAdjustmentOriginalCast
		globals.ClassAdjustmentOriginalCast = nil
		globals.ClassAdjustmentHookedCast = nil
	end
	if HookCastSpeed and typeof(HookCastSpeed.restore) == "function" then
		pcall(HookCastSpeed.restore)
	end

	if globals.ClassAdjustmentOriginalShapecast and typeof(hookfunction) == "function" then
		pcall(hookfunction, workspace.Shapecast, globals.ClassAdjustmentOriginalShapecast)
		globals.ClassAdjustmentOriginalShapecast = nil
	end
end

function Executor.updateChargerTripmineAssist(controller)
	ChargerTripmineAssist = ChargerTripmineAssist or getgenv().loadModule(MODULE_PATHS.ChargerTripmineAssist)
	if ChargerTripmineAssist and typeof(ChargerTripmineAssist.update) == "function" then
		return ChargerTripmineAssist.update(controller)
	end

	return nil
end

function Executor.updateChargerSteeringAssist(controller)
	ChargerSteeringAssist = ChargerSteeringAssist or getgenv().loadModule(MODULE_PATHS.ChargerSteeringAssist)
	if ChargerSteeringAssist and typeof(ChargerSteeringAssist.update) == "function" then
		return ChargerSteeringAssist.update(controller)
	end

	return nil
end

function Executor.updateChargerCollisionGuard(controller)
	ChargerCollisionGuard = ChargerCollisionGuard or getgenv().loadModule(MODULE_PATHS.ChargerCollisionGuard)
	if ChargerCollisionGuard and typeof(ChargerCollisionGuard.update) == "function" then
		return ChargerCollisionGuard.update(controller)
	end

	return nil
end

function Executor.updateChargerAirPlatformDuration(controller)
	return updateChargerAirPlatformDuration(controller)
end

function Executor.updateChargerAssistSuite(controller)
	ChargerAssistSuite = ChargerAssistSuite or getgenv().loadModule(MODULE_PATHS.ChargerAssistSuite)
	if ChargerAssistSuite and typeof(ChargerAssistSuite.update) == "function" then
		return ChargerAssistSuite.update(controller)
	end
	return nil
end

function Executor.updateChargerAnchorCastAssist(controller)
	ChargerAnchorCastAssist = ChargerAnchorCastAssist or getgenv().loadModule(MODULE_PATHS.ChargerAnchorCastAssist)
	if ChargerAnchorCastAssist and typeof(ChargerAnchorCastAssist.update) == "function" then
		return ChargerAnchorCastAssist.update(controller)
	end
	return nil
end

return Executor
