--!nocheck
-- [[
--  NULLSCAPE - Accessibility Grapple Assist
--  Thin isolation wrapper around Grapple.Cast and Grapple.Step.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Targeting = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Targeting.luau")
local SecondaryCast = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Secondary Cast.luau")
local VoidRescue = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/SharkVoid.luau")
local ReelSaver = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Technique/Reel Saver/init.luau")
local ReleaseTiming = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Timing Helper.luau")
local FailFeedback = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Fail Feedback Loop.luau")

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

	if globals.AccessibilityGrappleAssistHooked and castHookValid and stepHookValid then
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
			local assistedHit = Targeting.findBestAssistHit(self, getController())
			if assistedHit then
				if FailFeedback and typeof(FailFeedback.noteAssistCast) == "function" then
					pcall(function()
						FailFeedback.noteAssistCast(self, assistedHit, getController())
					end)
				end
				return assistedHit
			end
		end

		return originalCast(self, forceRefresh, ...)
	end

	Logic.OriginalCast = originalCast
	Logic.WrappedCast = wrappedCast
	grappleModule.Cast = wrappedCast
	globals.AccessibilityGrappleAssistOriginalCast = originalCast
	globals.AccessibilityGrappleAssistWrappedCast = wrappedCast
end

local function installStepHook(grappleModule, globals)
	if typeof(grappleModule.Step) ~= "function" then
		return
	end

	local originalStep = grappleModule.Step
	local wrappedStep

	wrappedStep = function(self, dt, ...)
		rememberGrapple(self)
		local results = packValues(originalStep(self, dt, ...))

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
