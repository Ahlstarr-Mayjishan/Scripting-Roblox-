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
local ReelSaver = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/Reel Saver/init.luau")
local ReleaseTiming = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Timing Helper.luau")
local FailFeedback = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Fail Feedback Loop.luau")
local DeferredAim = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Deferred Aim Cast.luau")
local Arbiter = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique Arbiter.luau")
local EntityContext = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Entity Intent Context.luau")

local HOOK_VERSION = 13

local PRIORITY = {
	SharkVoid = 100,
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

local function installCastHook(grappleModule, globals)
	local originalCast = grappleModule.Cast
	local wrappedCast

	wrappedCast = function(self, forceRefresh, ...)
		rememberGrapple(self)

		if isEnabled() then
			local controller = getController()
			local manualCast = true
			local fallbackHit, fallbackDirection
			local prioritizeAssist = EntityContext
				and typeof(EntityContext.isRazorbloomActive) == "function"
				and EntityContext.isRazorbloomActive()

			if prioritizeAssist then
				local assistedHit = Targeting.findOptimalHit(self, controller, {
					ManualCast = manualCast,
					EntityIntent = "RazorbloomEscape",
				})
				if assistedHit then
					if FailFeedback and typeof(FailFeedback.noteAssistCast) == "function" then
						pcall(function()
							FailFeedback.noteAssistCast(self, assistedHit, controller)
						end)
					end
					return assistedHit
				end
			end

			if manualCast and Targeting and typeof(Targeting.fallbackCast) == "function" then
				fallbackHit, fallbackDirection = Targeting.fallbackCast(self, controller)
				if fallbackHit then
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
					if FailFeedback and typeof(FailFeedback.noteAssistCast) == "function" then
						pcall(function()
							FailFeedback.noteAssistCast(self, assistedHit, controller)
						end)
					end
					return assistedHit
				end
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
			local success, handled = pcall(function()
				return VoidRescue.step(self, dt, getController(), Targeting)
			end)
			if success and handled then
				activeTechnique = "SharkVoid"
				if Arbiter and typeof(Arbiter.claim) == "function" then
					pcall(function()
						Arbiter.claim(self, "SharkVoid", PRIORITY.SharkVoid, 0.45)
					end)
				end
			end
		end

		if
			not activeTechnique
			and ReelSaver
			and typeof(ReelSaver.step) == "function"
			and not (Arbiter and Arbiter.isBlocked and Arbiter.isBlocked(self, "ReelSaver", PRIORITY.ReelSaver))
		then
			local success, handled = pcall(function()
				return ReelSaver.step(self, dt, controller)
			end)
			if success and handled then
				activeTechnique = "ReelSaver"
				if Arbiter and typeof(Arbiter.claim) == "function" then
					pcall(function()
						Arbiter.claim(self, "ReelSaver", PRIORITY.ReelSaver, 0.35)
					end)
				end
			end
		end

		if
			not activeTechnique
			and Logic.PendingReelSaverUntil
			and time() <= Logic.PendingReelSaverUntil
			and ReelSaver
			and typeof(ReelSaver.trigger) == "function"
			and not (Arbiter and Arbiter.isBlocked and Arbiter.isBlocked(self, "ReelSaver", PRIORITY.ReelSaver))
		then
			local success, triggered = pcall(function()
				return ReelSaver.trigger(self, controller, Targeting)
			end)
			if success and triggered then
				Logic.PendingReelSaverUntil = nil
				activeTechnique = "ReelSaver"
				if Arbiter and typeof(Arbiter.claim) == "function" then
					pcall(function()
						Arbiter.claim(self, "ReelSaver", PRIORITY.ReelSaver, 0.55)
					end)
				end
			end
		elseif Logic.PendingReelSaverUntil and time() > Logic.PendingReelSaverUntil then
			Logic.PendingReelSaverUntil = nil
		end

		if
			not activeTechnique
			and DeferredAim
			and typeof(DeferredAim.step) == "function"
			and not (Arbiter and Arbiter.isBlocked and Arbiter.isBlocked(self, "DeferredAim", PRIORITY.DeferredAim))
		then
			local success, handled = pcall(function()
				return DeferredAim.step(self, controller)
			end)
			if success and handled then
				activeTechnique = "DeferredAim"
				if Arbiter and typeof(Arbiter.claim) == "function" then
					pcall(function()
						Arbiter.claim(self, "DeferredAim", PRIORITY.DeferredAim, 0.25)
					end)
				end
			end
		end

		if ReleaseTiming and typeof(ReleaseTiming.step) == "function" then
			local pending = ReleaseTiming.get and ReleaseTiming.get(self) or nil
			local reason = pending and pending.Reason or "ReleaseTiming"
			local releaseName = reason == "SharkVoid" and "SharkVoid"
				or reason == "ReelSaver" and "ReelSaver"
				or "ReleaseTiming"
			local releasePriority = releaseName == "SharkVoid" and PRIORITY.SharkVoid
				or releaseName == "ReelSaver" and PRIORITY.ReelSaver
				or PRIORITY.ReleaseTiming
			if not (Arbiter and Arbiter.isBlocked and Arbiter.isBlocked(self, releaseName, releasePriority)) then
				local success, handled = pcall(function()
					return ReleaseTiming.step(self)
				end)
				if success and handled and Arbiter and typeof(Arbiter.claim) == "function" then
					pcall(function()
						Arbiter.claim(self, releaseName, releasePriority, 0.12)
					end)
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
	if triggered and Arbiter and typeof(Arbiter.claim) == "function" then
		Arbiter.claim(Logic.LastGrapple, "SecondaryCast", PRIORITY.SecondaryCast, 0.35)
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
	elseif Arbiter and typeof(Arbiter.claim) == "function" then
		Arbiter.claim(Logic.LastGrapple, "ReelSaver", PRIORITY.ReelSaver, 0.55)
	end
	return triggered
end

function Logic.resetRespawnState()
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
	if DeferredAim and typeof(DeferredAim.reset) == "function" then
		pcall(function()
			DeferredAim.reset()
		end)
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
end

return Logic
