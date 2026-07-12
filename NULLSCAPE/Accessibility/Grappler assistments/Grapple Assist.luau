--!nocheck
-- [[
--  NULLSCAPE - Accessibility Grapple Assist
--  Thin isolation wrapper around Grapple.Cast and Grapple.Step.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Targeting = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Targeting.luau")
local SecondaryCast = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Secondary Cast.luau")
local VoidRescue = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/SharkVoid.luau")
local BellContact =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/Bell Contact Assist.luau")
local GrappleDodge = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/Grapple Dodge.luau")
local ReelSaver = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/Reel Saver/init.luau")
local ReleaseTiming = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Timing Helper.luau")
local FailFeedback = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Fail Feedback Loop.luau")
local DeferredAim = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Deferred Aim Cast.luau")
local Arbiter = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique Arbiter.luau")
local EntityContext = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Entity Intent Context.luau")
local Decision = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique Decision Layer.luau")
local CastTransaction = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Cast Transaction.luau")
local PerformanceBudget = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Performance Budget.luau")
local NativeContext = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Native Context Sync.luau")
local AimLock = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Aim Target Lock.luau")
local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local EnemyMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Threat Context/Enemy Memory.luau")
local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local BadAnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Bad Anchor Memory.luau")
local PlayerIntent = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Player Intent State.luau")

local HOOK_VERSION = 16

local PRIORITY = Decision and Decision.Priority
	or {
		SharkVoid = 100,
		RazorbloomEscape = 94,
		GrappleDodge = 88,
		ReelSaver = 82,
		ReleaseTiming = 76,
		SecondaryCast = 72,
		DeferredAim = 45,
		Feedback = 10,
	}

local Logic = {
	Controller = nil,
	LastGrapple = nil,
	WrappedCast = nil,
	WrappedStep = nil,
	OriginalCast = nil,
	OriginalStep = nil,
	PendingReelSaverUntil = nil,
	Enabled = false,
}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getController()
	if Logic.Controller then
		return Logic.Controller
	end

	local globals = getGlobals()
	return globals and globals.activeAccessibilityController
end

local function isEnabled()
	local controller = getController()
	return controller and controller.GrappleAssistEnabled == true
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
	then
		return nil
	end

	return grappleModule
end

local function clearStaleHooks(grappleModule, globals)
	local castHookValid = globals.AccessibilityGrappleAssistWrappedCast
		and grappleModule.Cast == globals.AccessibilityGrappleAssistWrappedCast
	local stepHookValid = not globals.AccessibilityGrappleAssistWrappedStep
		or grappleModule.Step == globals.AccessibilityGrappleAssistWrappedStep
	local versionValid = globals.AccessibilityGrappleAssistHookVersion == HOOK_VERSION

	if globals.AccessibilityGrappleAssistHooked and castHookValid and stepHookValid and versionValid then
		Logic.OriginalCast = globals.AccessibilityGrappleAssistOriginalCast
		Logic.WrappedCast = globals.AccessibilityGrappleAssistWrappedCast
		Logic.OriginalStep = globals.AccessibilityGrappleAssistOriginalStep
		Logic.WrappedStep = globals.AccessibilityGrappleAssistWrappedStep
		return true
	end

	if globals.AccessibilityGrappleAssistOriginalCast then
		if grappleModule.Cast ~= globals.AccessibilityGrappleAssistOriginalCast then
			grappleModule.Cast = globals.AccessibilityGrappleAssistOriginalCast
		end
		globals.AccessibilityGrappleAssistOriginalCast = nil
		globals.AccessibilityGrappleAssistWrappedCast = nil
	end

	if globals.AccessibilityGrappleAssistOriginalStep then
		if grappleModule.Step ~= globals.AccessibilityGrappleAssistOriginalStep then
			grappleModule.Step = globals.AccessibilityGrappleAssistOriginalStep
		end
		globals.AccessibilityGrappleAssistOriginalStep = nil
		globals.AccessibilityGrappleAssistWrappedStep = nil
	end

	globals.AccessibilityGrappleAssistHooked = false
	Logic.WrappedCast = nil
	Logic.WrappedStep = nil
	Logic.OriginalCast = nil
	Logic.OriginalStep = nil
	return false
end

local function rememberGrapple(grapple)
	if grapple and grapple.Movement and grapple.RootPart then
		Logic.LastGrapple = grapple
	end
end

local function packValues(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function canRunTechnique(grapple, name, intent, options)
	if Decision and typeof(Decision.canRun) == "function" then
		local ok, allowed, state = pcall(function()
			return Decision.canRun(grapple, name, intent, options)
		end)
		if ok then
			return allowed == true, state
		end
	end

	if Arbiter and Arbiter.isBlocked and Arbiter.isBlocked(grapple, name, PRIORITY[name] or 0) then
		return false
	end
	return true
end

local function claimTechnique(grapple, name, holdTime)
	if Decision and typeof(Decision.claim) == "function" then
		pcall(function()
			Decision.claim(grapple, name, holdTime)
		end)
	elseif Arbiter and typeof(Arbiter.claim) == "function" then
		pcall(function()
			Arbiter.claim(grapple, name, PRIORITY[name] or 0, holdTime)
		end)
	end
end

local function clearRuntimeCaches(grapple)
	local rootPart = grapple and grapple.RootPart
	if MomentumMemory and typeof(MomentumMemory.clear) == "function" and rootPart then
		pcall(MomentumMemory.clear, rootPart)
	end

	if grapple and grapple.Movement and grapple.Movement.grappling == true then
		return
	end

	for _, memory in ipairs({ AnchorMemory, RailMemory, TerrainMemory, EnemyMemory, BadAnchorMemory }) do
		if memory and typeof(memory.clear) == "function" then
			pcall(memory.clear)
		end
	end
	if Targeting and typeof(Targeting.resetCache) == "function" then
		Targeting.resetCache()
	end
end

local function installCastHook(grappleModule, globals)
	local originalCast = grappleModule.Cast
	local wrappedCast

	wrappedCast = function(self, forceRefresh, ...)
		rememberGrapple(self)

		if isEnabled() then
			local controller = getController()
			local manualCast = true
			local fallbackHit, fallbackDirection, fallbackBlocked
			local prioritizeAssist = EntityContext
				and typeof(EntityContext.isRazorbloomActive) == "function"
				and EntityContext.isRazorbloomActive()

			if prioritizeAssist then
				local assistedHit = Targeting.findOptimalHit(self, controller, {
					ManualCast = manualCast,
					EntityIntent = "RazorbloomEscape",
				})
				if assistedHit then
					if CastTransaction and typeof(CastTransaction.expect) == "function" then
						CastTransaction.expect(self, assistedHit, controller, "RazorbloomEscape")
					end
					return assistedHit
				end
			end

			if manualCast and Targeting and typeof(Targeting.fallbackCast) == "function" then
				fallbackHit, fallbackDirection, fallbackBlocked = Targeting.fallbackCast(self, controller)
				if fallbackHit then
					if CastTransaction and typeof(CastTransaction.expect) == "function" then
						CastTransaction.expect(self, fallbackHit, controller, "ManualFallback")
					end
					if DeferredAim and typeof(DeferredAim.reset) == "function" then
						pcall(function()
							DeferredAim.reset()
						end)
					end
					return fallbackHit
				end
			end

			if not prioritizeAssist then
				local assistedHit = Targeting.findOptimalHit(self, controller, {
					ManualCast = manualCast,
				})
				if assistedHit then
					if CastTransaction and typeof(CastTransaction.expect) == "function" then
						CastTransaction.expect(self, assistedHit, controller, "AssistFallback")
					end
					return assistedHit
				end
			end

			if manualCast and fallbackBlocked then
				return nil, fallbackDirection
			end

			if manualCast and fallbackDirection then
				return nil, fallbackDirection
			end

			if manualCast and DeferredAim and typeof(DeferredAim.note) == "function" then
				pcall(function()
					DeferredAim.note(self, controller)
				end)
			end
		end

		local originalResults = packValues(originalCast(self, forceRefresh, ...))
		if originalResults[1] and DeferredAim and typeof(DeferredAim.reset) == "function" then
			pcall(function()
				DeferredAim.reset()
			end)
		end

		return table.unpack(originalResults, 1, originalResults.n)
	end

	Logic.OriginalCast = originalCast
	Logic.WrappedCast = wrappedCast
	grappleModule.Cast = wrappedCast
	globals.AccessibilityGrappleAssistOriginalCast = originalCast
	globals.AccessibilityGrappleAssistWrappedCast = wrappedCast
	globals.AccessibilityGrappleAssistHookVersion = HOOK_VERSION
end

local function installStepHook(grappleModule, globals)
	if typeof(grappleModule.Step) ~= "function" then
		return
	end

	local originalStep = grappleModule.Step
	local wrappedStep

	wrappedStep = function(self, dt, ...)
		rememberGrapple(self)

		if BellContact and typeof(BellContact.beforeStep) == "function" then
			pcall(function()
				BellContact.beforeStep(self)
			end)
		end

		local results = packValues(originalStep(self, dt, ...))
		local controller = getController()
		if
			isEnabled()
			and PlayerIntent
			and typeof(PlayerIntent.observe) == "function"
			and (typeof(PlayerIntent.shouldSample) ~= "function" or PlayerIntent.shouldSample(self))
		then
			pcall(function()
				local aimDirection = Targeting
					and typeof(Targeting.getAimDirection) == "function"
					and Targeting.getAimDirection(self)
				PlayerIntent.observe(self, aimDirection)
			end)
		end
		if PerformanceBudget and typeof(PerformanceBudget.observeFrame) == "function" then
			PerformanceBudget.observeFrame(dt)
		end
		if CastTransaction and typeof(CastTransaction.step) == "function" then
			pcall(function()
				CastTransaction.step(self)
			end)
		end
		if Arbiter and typeof(Arbiter.beginFrame) == "function" then
			pcall(function()
				Arbiter.beginFrame(self)
			end)
		end

		if BellContact and typeof(BellContact.afterStep) == "function" then
			pcall(function()
				BellContact.afterStep(self)
			end)
		end

		local activeTechnique = nil

		if VoidRescue and typeof(VoidRescue.step) == "function" then
			local allowed = canRunTechnique(self, "SharkVoid", {
				Name = "VoidRescue",
			})
			if allowed then
				local success, handled = pcall(function()
					return VoidRescue.step(self, dt, getController(), Targeting)
				end)
				if success and handled then
					activeTechnique = "SharkVoid"
					claimTechnique(self, "SharkVoid", 0.45)
				end
			end
		end

		if not activeTechnique and GrappleDodge and typeof(GrappleDodge.step) == "function" then
			local allowed = canRunTechnique(self, "GrappleDodge", {
				Name = "ThreatDodge",
			}, {
				AllowWhileMoving = true,
			})
			if allowed then
				local success, handled = pcall(function()
					return GrappleDodge.step(self, dt, controller)
				end)
				if success and handled then
					activeTechnique = "GrappleDodge"
					claimTechnique(self, "GrappleDodge", 0.42)
				end
			end
		end

		if not activeTechnique and ReelSaver and typeof(ReelSaver.step) == "function" then
			local allowed = canRunTechnique(self, "ReelSaver", {
				Name = "ReelSaver",
			}, {
				Technique = "ReelSaver",
			})
			if allowed then
				local success, handled = pcall(function()
					return ReelSaver.step(self, dt, controller)
				end)
				if success and handled then
					activeTechnique = "ReelSaver"
					claimTechnique(self, "ReelSaver", 0.35)
				end
			end
		end

		if
			not activeTechnique
			and Logic.PendingReelSaverUntil
			and time() <= Logic.PendingReelSaverUntil
			and ReelSaver
			and typeof(ReelSaver.trigger) == "function"
		then
			local allowed = canRunTechnique(self, "ReelSaver", {
				Name = "ReelSaver",
			}, {
				Technique = "ReelSaver",
			})
			if allowed then
				local success, triggered = pcall(function()
					return ReelSaver.trigger(self, controller, Targeting)
				end)
				if success and triggered then
					Logic.PendingReelSaverUntil = nil
					activeTechnique = "ReelSaver"
					claimTechnique(self, "ReelSaver", 0.55)
				end
			end
		elseif Logic.PendingReelSaverUntil and time() > Logic.PendingReelSaverUntil then
			Logic.PendingReelSaverUntil = nil
		end

		if not activeTechnique and DeferredAim and typeof(DeferredAim.step) == "function" then
			local allowed = canRunTechnique(self, "DeferredAim", {
				Name = "AnchorAssist",
			}, {
				AllowDuringManual = true,
				AllowWhileMoving = true,
			})
			if allowed then
				local success, handled = pcall(function()
					return DeferredAim.step(self, controller)
				end)
				if success and handled then
					activeTechnique = "DeferredAim"
					claimTechnique(self, "DeferredAim", 0.25)
				end
			end
		end

		if ReleaseTiming and typeof(ReleaseTiming.step) == "function" then
			local pending = ReleaseTiming.get and ReleaseTiming.get(self) or nil
			local reason = pending and pending.Reason or "ReleaseTiming"
			local releaseName = reason == "SharkVoid" and "SharkVoid"
				or reason == "ReelSaver" and "ReelSaver"
				or "ReleaseTiming"
			if
				canRunTechnique(self, releaseName, {
					Name = releaseName,
				}, {
					Technique = releaseName,
					AllowDuringManual = true,
				})
			then
				local success, handled = pcall(function()
					return ReleaseTiming.step(self)
				end)
				if success and handled then
					claimTechnique(self, releaseName, 0.12)
				end
			end
		end

		if FailFeedback and typeof(FailFeedback.step) == "function" then
			pcall(function()
				FailFeedback.step(self, dt, getController())
			end)
		end

		return table.unpack(results, 1, results.n)
	end

	Logic.OriginalStep = originalStep
	Logic.WrappedStep = wrappedStep
	grappleModule.Step = wrappedStep
	globals.AccessibilityGrappleAssistOriginalStep = originalStep
	globals.AccessibilityGrappleAssistWrappedStep = wrappedStep
end

function Logic.initialize(controller)
	Logic.Controller = controller or Logic.Controller
	if NativeContext and typeof(NativeContext.initialize) == "function" then
		NativeContext.initialize()
	end

	local grappleModule = getGrappleModule()
	if not (grappleModule and typeof(grappleModule.Cast) == "function") then
		return false
	end

	local globals = getGlobals()
	if clearStaleHooks(grappleModule, globals) then
		Logic.Enabled = true
		return true
	end

	installCastHook(grappleModule, globals)
	installStepHook(grappleModule, globals)

	globals.AccessibilityGrappleAssistHooked = true
	globals.AccessibilityGrappleAssistHookVersion = HOOK_VERSION
	Logic.Enabled = true
	return true
end

function Logic.triggerSecondaryCast(controller)
	Logic.Controller = controller or Logic.Controller

	if not Logic.Enabled and not Logic.initialize(Logic.Controller) then
		return false
	end

	if
		Arbiter
		and typeof(Arbiter.isBlocked) == "function"
		and Arbiter.isBlocked(Logic.LastGrapple, "SecondaryCast", PRIORITY.SecondaryCast)
	then
		return false
	end

	local triggered = SecondaryCast.cast(Logic.LastGrapple, getController(), Targeting)
	if triggered then
		claimTechnique(Logic.LastGrapple, "SecondaryCast", 0.35)
	end
	return triggered
end

function Logic.triggerReelSaver(controller)
	Logic.Controller = controller or Logic.Controller

	if not Logic.Enabled and not Logic.initialize(Logic.Controller) then
		return false
	end

	if not (ReelSaver and typeof(ReelSaver.trigger) == "function") then
		return false
	end

	if
		Arbiter
		and typeof(Arbiter.isBlocked) == "function"
		and Arbiter.isBlocked(Logic.LastGrapple, "ReelSaver", PRIORITY.ReelSaver)
	then
		return false
	end

	if not Logic.LastGrapple then
		Logic.PendingReelSaverUntil = time() + 1.2
		return true
	end

	local triggered = ReelSaver.trigger(Logic.LastGrapple, getController(), Targeting)
	if not triggered then
		Logic.PendingReelSaverUntil = time() + 0.35
	else
		claimTechnique(Logic.LastGrapple, "ReelSaver", 0.55)
	end
	return triggered
end

function Logic.resetRespawnState()
	local previousGrapple = Logic.LastGrapple
	Logic.LastGrapple = nil
	Logic.PendingReelSaverUntil = nil
	if VoidRescue and typeof(VoidRescue.reset) == "function" then
		pcall(function()
			VoidRescue.reset()
		end)
	end
	if ReelSaver and typeof(ReelSaver.reset) == "function" then
		pcall(function()
			ReelSaver.reset()
		end)
	end
	if GrappleDodge and typeof(GrappleDodge.reset) == "function" then
		pcall(function()
			GrappleDodge.reset()
		end)
	end
	if DeferredAim and typeof(DeferredAim.reset) == "function" then
		pcall(function()
			DeferredAim.reset()
		end)
	end
	if AimLock and typeof(AimLock.clear) == "function" then
		AimLock.clear()
	end
	if PlayerIntent and typeof(PlayerIntent.clear) == "function" then
		PlayerIntent.clear(previousGrapple)
	end
	if NativeContext and typeof(NativeContext.reset) == "function" then
		NativeContext.reset()
	end
	if BellContact and typeof(BellContact.reset) == "function" then
		pcall(function()
			BellContact.reset()
		end)
	end
	if ReleaseTiming and typeof(ReleaseTiming.reset) == "function" then
		pcall(function()
			ReleaseTiming.reset()
		end)
	end
	if FailFeedback and typeof(FailFeedback.reset) == "function" then
		pcall(function()
			FailFeedback.reset()
		end)
	end
	if Arbiter and typeof(Arbiter.reset) == "function" then
		pcall(function()
			Arbiter.reset()
		end)
	end
	if CastTransaction and typeof(CastTransaction.reset) == "function" then
		CastTransaction.reset()
	end
	if PerformanceBudget and typeof(PerformanceBudget.reset) == "function" then
		PerformanceBudget.reset()
	end
	clearRuntimeCaches(previousGrapple)
	return true
end

function Logic.disable()
	local globals = getGlobals()
	local grappleModule = getGrappleModule()

	if
		grappleModule
		and globals.AccessibilityGrappleAssistWrappedCast
		and grappleModule.Cast == globals.AccessibilityGrappleAssistWrappedCast
	then
		grappleModule.Cast = globals.AccessibilityGrappleAssistOriginalCast
	end

	if
		grappleModule
		and globals.AccessibilityGrappleAssistWrappedStep
		and grappleModule.Step == globals.AccessibilityGrappleAssistWrappedStep
	then
		grappleModule.Step = globals.AccessibilityGrappleAssistOriginalStep
	end

	globals.AccessibilityGrappleAssistOriginalCast = nil
	globals.AccessibilityGrappleAssistWrappedCast = nil
	globals.AccessibilityGrappleAssistOriginalStep = nil
	globals.AccessibilityGrappleAssistWrappedStep = nil
	globals.AccessibilityGrappleAssistHooked = false
	globals.AccessibilityGrappleAssistHookVersion = nil

	Logic.LastGrapple = nil
	Logic.WrappedCast = nil
	Logic.WrappedStep = nil
	Logic.OriginalCast = nil
	Logic.OriginalStep = nil
	Logic.PendingReelSaverUntil = nil
	Logic.Enabled = false

	Logic.resetRespawnState()
	if NativeContext and typeof(NativeContext.disable) == "function" then
		NativeContext.disable()
	end
end

return Logic
