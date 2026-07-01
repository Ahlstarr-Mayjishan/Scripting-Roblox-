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
local AirControl = nil
local ReelPull = nil
local SharkTailPull = nil
local SharkTailCooldown = nil
local GrappleRecovery = nil
local GrappleRange = nil
local HookCastSpeed = nil
local ChargerTripmineAssist = nil

local MODULE_PATHS = {
	AirControl = "NULLSCAPE/Class Adjustment/Grappler/Grapple Air Control.luau",
	ReelPull = "NULLSCAPE/Class Adjustment/Grappler/Grapple Reel Pull.luau",
	SharkTailPull = "NULLSCAPE/Class Adjustment/Grappler/SharkTail Pull.luau",
	SharkTailCooldown = "NULLSCAPE/Class Adjustment/Grappler/SharkTail Cooldown.luau",
	GrappleRecovery = "NULLSCAPE/Class Adjustment/Grappler/Grapple Recovery.luau",
	GrappleRange = "NULLSCAPE/Class Adjustment/Grappler/Grapple Range.luau",
	HookCastSpeed = "NULLSCAPE/Class Adjustment/Grappler/Grapple Hook Cast Speed.luau",
	ChargerTripmineAssist = "NULLSCAPE/Class Adjustment/Charger/Tripmine Assist.luau",
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
	SharkTailCooldown = SharkTailCooldown or getgenv().loadModule(MODULE_PATHS.SharkTailCooldown)
	GrappleRecovery = GrappleRecovery or getgenv().loadModule(MODULE_PATHS.GrappleRecovery)
	GrappleRange = GrappleRange or getgenv().loadModule(MODULE_PATHS.GrappleRange)
	HookCastSpeed = HookCastSpeed or getgenv().loadModule(MODULE_PATHS.HookCastSpeed)
	ChargerTripmineAssist = ChargerTripmineAssist or getgenv().loadModule(MODULE_PATHS.ChargerTripmineAssist)
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

			if
				Control
				and Control.GrappleSharkTailWindow
				and self
				and self.Movement
				and self.Movement:HasUpgrade("SharkTail")
				and not self.sharkTailDisable
				and self.lastGrappleRelease
				and self.lastGrappleRelease > 0
			then
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

			local multiplier = Control and Control.GrappleHookCastSpeedMultiplier or 1
			local results
			if multiplier ~= 1 then
				local originalCreate = game.TweenService.Create
				local originalDelay = task.delay
				
				-- Hook TweenService:Create temporarily for the duration of Start call
				game.TweenService.Create = function(ts, instance, tweenInfo, propertyTable)
					if instance == self.hook or (self.hook and instance and (instance == self.hook or instance.Parent == self.hook or instance:IsDescendantOf(self.hook))) then
						local speedMultiplier = multiplier == 0 and 999999 or multiplier
						local newTime = tweenInfo.Time / speedMultiplier
						tweenInfo = TweenInfo.new(newTime, tweenInfo.EasingStyle, tweenInfo.EasingDirection, tweenInfo.RepeatCount, tweenInfo.Reverses, tweenInfo.DelayTime)
					end
					return originalCreate(ts, instance, tweenInfo, propertyTable)
				end
				
				-- Hook task.delay temporarily for the duration of Start call
				task.delay = function(delayTime, callback)
					local speedMultiplier = multiplier == 0 and 999999 or multiplier
					local newDelay = delayTime / speedMultiplier
					return originalDelay(newDelay, callback)
				end
				
				results = packValues(pcall(originalStart, self, p2, ...))
				
				game.TweenService.Create = originalCreate
				task.delay = originalDelay
			else
				results = packValues(pcall(originalStart, self, p2, ...))
			end

			-- Restore JumpPad state if bypass is enabled
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
end

function Executor.updateChargerTripmineAssist(controller)
	ChargerTripmineAssist = ChargerTripmineAssist or getgenv().loadModule(MODULE_PATHS.ChargerTripmineAssist)
	if ChargerTripmineAssist and typeof(ChargerTripmineAssist.update) == "function" then
		return ChargerTripmineAssist.update(controller)
	end

	return nil
end

return Executor
