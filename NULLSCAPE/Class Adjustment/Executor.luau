--!nocheck
-- [[
--  NULLSCAPE - Class Adjustment Executor
--  Hooks Grapple methods once and applies class adjustments without per-frame module loads.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local CatapultBoost = nil
local SharkTailWindowState = setmetatable({}, { __mode = "k" })
local SharkTailEndTokens = setmetatable({}, { __mode = "k" })

local MODULE_PATHS = {
	AirControl = "NULLSCAPE/Class Adjustment/Grappler/Grapple Air Control.luau",
	ReelPull = "NULLSCAPE/Class Adjustment/Grappler/Grapple Reel Pull.luau",
	SharkTailPull = "NULLSCAPE/Class Adjustment/Grappler/SharkTail Pull.luau",
	SharkTailCooldown = "NULLSCAPE/Class Adjustment/Grappler/SharkTail Cooldown.luau",
	GrappleRecovery = "NULLSCAPE/Class Adjustment/Grappler/Grapple Recovery.luau",
	GrappleRange = "NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau",
	HookCastSpeed = "NULLSCAPE/Class Adjustment/Grappler/Grapple Hook Cast Speed.luau",
	ChargerTripmineAssist = "NULLSCAPE/Class Adjustment/Charger/Tripmine Assist.luau",
	CatapultBoost = "NULLSCAPE/Class Adjustment/Grappler/Grapple Catapult Boost.luau",
}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
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
	if
		not success
		or typeof(movementModule) ~= "table"
		or typeof(movementModule.HasUpgrade) ~= "function"
	then
		return nil
	end

	return movementModule
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
	CatapultBoost = CatapultBoost or getgenv().loadModule(MODULE_PATHS.CatapultBoost)
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

local function applyStepAdjustments(self, dt)
	if not HooksActive then
		return
	end
	if AirControl and typeof(AirControl.apply) == "function" then
		pcall(AirControl.apply, self, dt)
	end
	if ReelPull and typeof(ReelPull.apply) == "function" then
		pcall(ReelPull.apply, self)
	end
	if SharkTailCooldown and typeof(SharkTailCooldown.apply) == "function" then
		pcall(SharkTailCooldown.apply, self)
	end
end

local function applySharkTailAdjustment(self, previousVelocity)
	if not HooksActive then
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
			Control
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
			local Control = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
			if getgenv()._NULLSCAPE_InGrappleStep == true and Control and Control.GrappleWallGlide == true then
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
			local Control = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
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
			if
				Control
				and Control.GrappleInstantMaxPull
				and self
				and self.jumpPadReel
			then
				originalReelStart = self.reelStart
				self.reelStart = time() - 2.0
			end

			getgenv()._NULLSCAPE_InGrappleStep = true
			local stepResults = packValues(pcall(originalStep, self, dt, ...))
			getgenv()._NULLSCAPE_InGrappleStep = false

			if originalReelStart then
				self.reelStart = originalReelStart
			end

			if altered and self and self.grappleParams then
				self.grappleParams.FilterDescendantsInstances = originalFilter
			end

			if not stepResults[1] then
				error(stepResults[2], 0)
			end

			applyStepAdjustments(self, dt)

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
			local yBefore = self and self.RootPart and self.RootPart.Velocity.Y
			local yVelBelowMinBefore = self and self.yVelBelowMin

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
			if HooksActive and tryVirtualSharkTailInput(self, inputState) then
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
			if not HooksActive then
				return originalStart(self, p2, ...)
			end

			local Control = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")

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
			if not HooksActive then
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
	if ChargerTripmineAssist and typeof(ChargerTripmineAssist.update) == "function" then
		pcall(ChargerTripmineAssist.update, {
			ChargerTripmineAssistEnabled = false,
			ChargerTripmineMode = "Auto",
		})
	end
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

return Executor
