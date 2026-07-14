--!nocheck
-- [[
--  NULLSCAPE - Class Adjustment UI Tab
-- ]]

local resolveController = function(Client, Controller)
	if typeof(Controller) == "table" and rawget(Controller, "__ClassAdjustmentProxy") ~= true then
		return Controller
	end

	if Client and typeof(Client.Modules) == "table" and typeof(Client.Modules.ClassAdjustmentController) == "table" then
		return Client.Modules.ClassAdjustmentController
	end

	local globals = getgenv and getgenv()._NULLSCAPE_Globals
	if globals and typeof(globals.activeClassAdjustmentController) == "table" then
		return globals.activeClassAdjustmentController
	end

	if getgenv and typeof(getgenv().loadModule) == "function" then
		local success, loadedController = pcall(function()
			return getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
		end)
		if success and typeof(loadedController) == "table" then
			if Client and typeof(Client.Modules) == "table" then
				Client.Modules.ClassAdjustmentController = loadedController
			end
			return loadedController
		end
	end

	return nil
end

local createControllerProxy = function(Client, Controller)
	local DEFAULTS = {
		GrappleAirControlMultiplier = 0,
		GrappleReelPullMultiplier = 1,
		GrappleSharkTailPullMultiplier = 1,
		GrappleHookCastSpeedMultiplier = 1,
		GrappleMaxRange = 90,
		GrappleEasierVoidCast = false,
		GrappleDisableGroundRelease = false,
		GrappleNoReelCooldown = false,
		GrappleSharkTailNoCooldown = false,
		GrappleSharkTailWindow = 0.25,
		GrappleJumpPadUsesBypassEnabled = false,
		GrappleInstantGroundCast = false,
		GrappleWallGlide = false,
		GrappleInstantMaxPull = false,
		GrappleCatapultMultiplier = 1,
		GrappleMomentumTransferPercent = 0,
		ChargerTripmineAssistEnabled = false,
		ChargerTripmineMode = "Auto",
		ChargerTripmineDistance = 15,
		ChargerTripmineJitter = 2,
		ChargerSteeringAssistEnabled = false,
		ChargerSteeringAssistStrength = 50,
		ChargerCollisionGuardEnabled = false,
	}

	return setmetatable({ __ClassAdjustmentProxy = true }, {
		__index = function(_, key)
			local activeController = resolveController(Client, Controller)
			if activeController then
				local value = activeController[key]
				if value ~= nil then
					if typeof(value) == "function" and type(key) == "string" then
						return function(_, ...)
							local latestController = resolveController(Client, Controller) or activeController
							local latestMethod = latestController and latestController[key]
							if typeof(latestMethod) == "function" then
								return latestMethod(latestController, ...)
							end
							return nil
						end
					end
					return value
				end
			end
			return DEFAULTS[key]
		end,
	})
end

return function(Client, Controller)
	Controller = createControllerProxy(Client, Controller)
	local Tab = Client.Window:CreateTab("Class Adjustment", 4483362458)

	Tab:CreateSection("Grappler")
	Tab:CreateDivider()

	Tab:CreateToggle({
		Name = "Disable Ground Auto-Release",
		Info = "Prevents the grapple hook from automatically releasing when you are close to or running on the ground.",
		CurrentValue = Controller.GrappleDisableGroundRelease or false,
		Flag = "GrappleDisableGroundReleaseToggle",
		Callback = function(Value)
			Controller:SetGrappleDisableGroundRelease(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "No Reel Cooldown",
		Info = "Removes the 3-second cooldown between grapple hooks, allowing you to fire hooks instantly.",
		CurrentValue = Controller.GrappleNoReelCooldown or false,
		Flag = "GrappleNoReelCooldownToggle",
		Callback = function(Value)
			Controller:SetGrappleNoReelCooldown(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "No SharkTail Cooldown",
		Info = "Removes the ground-touch requirement to reuse SharkTail boost on the air.",
		CurrentValue = Controller.GrappleSharkTailNoCooldown or false,
		Flag = "GrappleSharkTailNoCooldownToggle",
		Callback = function(Value)
			Controller:SetGrappleSharkTailNoCooldown(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "JumpPad Uses Bypass",
		Info = "Keeps Grapple JumpPads reusable/queryable for repeated pulls. Useful for testing repeated JumpPad grapples.",
		CurrentValue = Controller.GrappleJumpPadUsesBypassEnabled or false,
		Flag = "GrappleJumpPadUsesBypassToggle",
		Callback = function(Value)
			Controller:SetGrappleJumpPadUsesBypass(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Air Control",
		Info = "0 returns control to the game. 1-9 adds stronger physical steering while preserving grapple momentum. 10 is strong but smoothed to avoid snap turns.",
		Range = { 0, 10 },
		Increment = 1,
		Suffix = "/10",
		CurrentValue = Controller.GrappleAirControlMultiplier or 0,
		Flag = "GrappleAirControlMultiplierSlider",
		Callback = function(Value)
			Controller:SetGrappleAirControlMultiplier(Value)
		end,
	})

	Tab:CreateDivider()

	Tab:CreateSlider({
		Name = "Grapple Reel Pull",
		Info = "Multiplies velocity gained from reel-style pulls. Affects special pull targets and NinjaBelt reel behavior.",
		Range = { 1, 5 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.GrappleReelPullMultiplier or 1.1,
		Flag = "GrappleReelPullMultiplierSlider",
		Callback = function(Value)
			Controller:SetGrappleReelPullMultiplier(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "SharkTail Pull",
		Info = "Multiplies the velocity delta created by SharkTail. Only applies when SharkTail actually fires and NinjaBelt + SharkTail are both owned.",
		Range = { 1, 5 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.GrappleSharkTailPullMultiplier or 1.1,
		Flag = "GrappleSharkTailPullMultiplierSlider",
		Callback = function(Value)
			Controller:SetGrappleSharkTailPullMultiplier(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Hook Cast Speed",
		Info = "0 makes the hook arrive instantly. 1 is native speed. Higher values multiply hook travel speed and shorten the matching weld delay.",
		Range = { 0, 10 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.GrappleHookCastSpeedMultiplier or 1,
		Flag = "GrappleHookCastSpeedMultiplierSlider",
		Callback = function(Value)
			Controller:SetGrappleHookCastSpeedMultiplier(Value)
		end,
	})

	Tab:CreateDivider()

	Tab:CreateSlider({
		Name = "Grapple Max Range",
		Info = "Adjusts the maximum grapple cast lock-on range limit client-side. 0 uses the extreme 5000 studs range.",
		Range = { 0, 500 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = Controller.GrappleMaxRange or 90,
		Flag = "GrappleMaxRangeSlider",
		Callback = function(Value)
			Controller:SetGrappleMaxRange(Value)
		end,
	})
	Tab:CreateToggle({
		Name = "Easier Void Cast",
		Info = "Widens KillVoid acquisition up to 160 studs and shares the same void target with SharkVoid.",
		CurrentValue = Controller.GrappleEasierVoidCast or false,
		Flag = "GrappleEasierVoidCastToggle",
		Callback = function(Value)
			Controller:SetGrappleEasierVoidCast(Value)
		end,
	})
	Tab:CreateToggle({
		Name = "Instant Ground Grapple",
		Info = "Allows shooting the grapple directly from the ground without jumping.",
		CurrentValue = Controller.GrappleInstantGroundCast or false,
		Flag = "GrappleInstantGroundCastToggle",
		Callback = function(Value)
			Controller:SetGrappleInstantGroundCast(Value)
		end,
	})
	Tab:CreateToggle({
		Name = "Wall-Glide",
		Info = "Prevents wall collisions from detaching your grapple constraint.",
		CurrentValue = Controller.GrappleWallGlide or false,
		Flag = "GrappleWallGlideToggle",
		Callback = function(Value)
			Controller:SetGrappleWallGlide(Value)
		end,
	})
	Tab:CreateToggle({
		Name = "Instant Max Pull Speed",
		Info = "Forces maximum reel coiling speed instantly without ramp-up delay.",
		CurrentValue = Controller.GrappleInstantMaxPull or false,
		Flag = "GrappleInstantMaxPullToggle",
		Callback = function(Value)
			Controller:SetGrappleInstantMaxPull(Value)
		end,
	})

	Tab:CreateDivider()
	Tab:CreateSlider({
		Name = "Slider Catapult Boost Multiplier",
		Info = "Multiplies the native vertical catapult boost when releasing upward from a grapple.",
		Range = { 1, 3 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.GrappleCatapultMultiplier or 1,
		Flag = "GrappleCatapultMultiplierSlider",
		Callback = function(Value)
			Controller:SetGrappleCatapultMultiplier(Value)
		end,
	})
	Tab:CreateSlider({
		Name = "Momentum Transfer",
		Info = "Preserves player momentum when connecting consecutive grapples. 0% is native game behavior.",
		Range = { 0, 100 },
		Increment = 5,
		Suffix = "%",
		CurrentValue = Controller.GrappleMomentumTransferPercent or 0,
		Flag = "GrappleMomentumTransferSlider",
		Callback = function(Value)
			Controller:SetGrappleMomentumTransferPercent(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "SharkTail Window",
		Info = "Adjusts the timing window (in seconds) allowed to trigger SharkTail after releasing a reel.",
		Range = { 0.25, 10 },
		Increment = 0.05,
		Suffix = "s",
		CurrentValue = Controller.GrappleSharkTailWindow or 0.25,
		Flag = "GrappleSharkTailWindowSlider",
		Callback = function(Value)
			Controller:SetGrappleSharkTailWindow(Value)
		end,
	})

	Tab:CreateSection("Charger")

	Tab:CreateToggle({
		Name = "Charger Steering Assist",
		Info = "Khi dang lao, uu tien huong WASD; neu khong co input thi theo huong camera.",
		CurrentValue = Controller.ChargerSteeringAssistEnabled or false,
		Flag = "ChargerSteeringAssistToggle",
		Callback = function(Value)
			Controller:SetChargerSteeringAssist(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Charger Steering Strength",
		Info = "0% khong can thiep; 100% bam sat huong WASD/camera trong luc lao.",
		Range = { 0, 100 },
		Increment = 1,
		Suffix = "%",
		CurrentValue = Controller.ChargerSteeringAssistStrength or 50,
		Flag = "ChargerSteeringAssistStrengthSlider",
		Callback = function(Value)
			Controller:SetChargerSteeringAssistStrength(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Charger Collision Guard",
		Info = "Giup charge khong bi ngat boi player khac va vat the nho; van giu va cham voi terrain/tuong map.",
		CurrentValue = Controller.ChargerCollisionGuardEnabled or false,
		Flag = "ChargerCollisionGuardToggle",
		Callback = function(Value)
			Controller:SetChargerCollisionGuard(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Charger Tripmine Assist",
		CurrentValue = Controller.ChargerTripmineAssistEnabled or false,
		Flag = "ChargerTripmineAssistToggle",
		Callback = function(Value)
			Controller:SetChargerTripmineAssist(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Charger Tripmine Mode",
		Info = "Auto se chi kich khi dang lao vao/cua so gan; PassBatch gom mine tren duong charge roi kich hoat mot luot.",
		Options = { "Auto", "PassBatch", "PreDetonate" },
		CurrentOption = (Controller.ChargerTripmineMode == "PreDetonate" and "PreDetonate")
			or (Controller.ChargerTripmineMode == "PassBatch" and "PassBatch")
			or "Auto",
		MultipleOptions = false,
		Flag = "ChargerTripmineModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetChargerTripmineMode(selected)
		end,
	})

	Tab:CreateSlider({
		Name = "Detonation Distance",
		Info = "Charger Auto/PreDetonate distance.",
		Range = { 5, 50 },
		CurrentValue = Controller.ChargerTripmineDistance or 15,
		Increment = 1,
		ValueName = "Studs",
		Flag = "ChargerTripmineDistanceSlider",
		Callback = function(Value)
			Controller:SetChargerTripmineDistance(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "PassBatch Distance",
		Info = "Khoang gom tripmine tinh tu mine dau tien da vuot qua.",
		Range = { 20, 60 },
		CurrentValue = Controller.ChargerTripmineBatchDistance or 60,
		Increment = 1,
		ValueName = "Studs",
		Flag = "ChargerTripmineBatchDistanceSlider",
		Callback = function(Value)
			Controller:SetChargerTripmineBatchDistance(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Detonation Jitter",
		Range = { 0, 10 },
		CurrentValue = Controller.ChargerTripmineJitter or 2,
		Increment = 1,
		ValueName = "Studs",
		Flag = "ChargerTripmineJitterSlider",
		Callback = function(Value)
			Controller:SetChargerTripmineJitter(Value)
		end,
	})
end
