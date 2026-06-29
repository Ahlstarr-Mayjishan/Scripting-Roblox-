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
local AirControl = nil
local ReelPull = nil
local SharkTailPull = nil
local GrappleRecovery = nil
local GrappleRange = nil

local MODULE_PATHS = {
	AirControl = "NULLSCAPE/Class Adjustment/Grappler/Grapple Air Control.luau",
	ReelPull = "NULLSCAPE/Class Adjustment/Grappler/Grapple Reel Pull.luau",
	SharkTailPull = "NULLSCAPE/Class Adjustment/Grappler/SharkTail Pull.luau",
	GrappleRecovery = "NULLSCAPE/Class Adjustment/Grappler/Grapple Recovery.luau",
	GrappleRange = "NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau",
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
	return success and grappleModule or nil
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
	GrappleRecovery = GrappleRecovery or getgenv().loadModule(MODULE_PATHS.GrappleRecovery)
	GrappleRange = GrappleRange or getgenv().loadModule(MODULE_PATHS.GrappleRange)
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
end

local function applySharkTailAdjustment(self, previousVelocity)
	if not HooksActive then
		return
	end
	if SharkTailPull and typeof(SharkTailPull.apply) == "function" then
		pcall(SharkTailPull.apply, self, previousVelocity)
	end
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

	if typeof(grappleModule.Step) == "function" and not globals.ClassAdjustmentOriginalStep then
		local originalStep = grappleModule.Step
		local wrappedStep
		wrappedStep = function(self, dt, ...)
			local Control = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
			local originalFilter
			local altered = false

			if Control and Control.GrappleDisableGroundRelease and self and self.Movement and self.Movement.grappling and self.grappleParams then
				originalFilter = self.grappleParams.FilterDescendantsInstances
				self.grappleParams.FilterDescendantsInstances = { workspace }
				altered = true
			end

			local beforeTime = self and self.Time
			local stepResults = packValues(pcall(originalStep, self, dt, ...))

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

			if Control and Control.GrappleSharkTailWindow and self and self.Movement and self.Movement:HasUpgrade("SharkTail") and not self.sharkTailDisable and self.lastGrappleRelease and self.lastGrappleRelease > 0 then
				local elapsed = time() - self.lastGrappleRelease
				if elapsed <= Control.GrappleSharkTailWindow then
					self.allowSharkTail = true
					if self.UI and self.UI:FindFirstChild("Frame") then
						pcall(function()
							self.UI.Frame.Bar.BackgroundColor3 = Color3.fromRGB(255, 255, 130)
							self.UI.Frame.Outline.UIStroke.Color = Color3.fromRGB(255, 255, 130)
						end)
					end
				end
			end

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
			applySharkTailAdjustment(self, previousVelocity)
			return result
		end

		globals.ClassAdjustmentOriginalSharkTail = originalSharkTail
		HookedSharkTail = wrappedSharkTail
		grappleModule.SharkTail = wrappedSharkTail
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
end

function Executor.restore()
	HooksActive = false
	local globals = getGlobals()
	local grappleModule = getGrappleModule()
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
	if grappleModule and globals.ClassAdjustmentHookedCast and grappleModule.Cast == globals.ClassAdjustmentHookedCast then
		grappleModule.Cast = globals.ClassAdjustmentOriginalCast
		globals.ClassAdjustmentOriginalCast = nil
		globals.ClassAdjustmentHookedCast = nil
	end
end

return Executor