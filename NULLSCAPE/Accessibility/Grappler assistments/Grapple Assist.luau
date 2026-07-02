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

local HOOK_VERSION = 9

local Logic = {
	Controller = nil,
	LastGrapple = nil,
	WrappedCast = nil,
	WrappedStep = nil,
	OriginalCast = nil,
	OriginalStep = nil,
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
			local fallbackHit, fallbackDirection
			if Targeting and typeof(Targeting.fallbackCast) == "function" then
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

			local assistedHit = Targeting.findOptimalHit(self, controller)
			if assistedHit then
				if FailFeedback and typeof(FailFeedback.noteAssistCast) == "function" then
					pcall(function()
						FailFeedback.noteAssistCast(self, assistedHit, controller)
					end)
				end
				return assistedHit
			end

			if fallbackDirection then
				return nil, fallbackDirection
			end

			if DeferredAim and typeof(DeferredAim.note) == "function" then
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

		if BellContact and typeof(BellContact.afterStep) == "function" then
			pcall(function()
				BellContact.afterStep(self)
			end)
		end

		if VoidRescue and typeof(VoidRescue.step) == "function" then
			pcall(function()
				VoidRescue.step(self, dt, getController(), Targeting)
			end)
		end

		if ReelSaver and typeof(ReelSaver.step) == "function" then
			pcall(function()
				ReelSaver.step(self, dt, getController())
			end)
		end

		if DeferredAim and typeof(DeferredAim.step) == "function" then
			pcall(function()
				DeferredAim.step(self, getController())
			end)
		end

		if ReleaseTiming and typeof(ReleaseTiming.step) == "function" then
			pcall(function()
				ReleaseTiming.step(self)
			end)
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

	return SecondaryCast.cast(Logic.LastGrapple, getController(), Targeting)
end

function Logic.triggerReelSaver(controller)
	Logic.Controller = controller or Logic.Controller

	if not Logic.Enabled and not Logic.initialize(Logic.Controller) then
		return false
	end

	if not (ReelSaver and typeof(ReelSaver.trigger) == "function") then
		return false
	end

	return ReelSaver.trigger(Logic.LastGrapple, getController())
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
	Logic.Enabled = false

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
end

return Logic
