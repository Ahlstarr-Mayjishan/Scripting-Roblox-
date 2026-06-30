local DEFAULTS = {
	SpringerAutoJumpEnabled = false,
	InfiniteAirJumpEnabled = false,
	AntiBonkEnabled = false,
	RailAssistSuiteEnabled = false,
	RailAutoEnabled = false,
	RailSpeedMultiplier = 1.1,
	RailAutoDelay = 1.5,
	RailAutoCaptureRange = 4,
	GrapplerStaminaMode = "Off",
	StaminaMode = "Off",
	GrapplerStaminaRecoverySpeed = 1,
}

local function resolveController(Client, Controller)
	if typeof(Controller) == "table" and rawget(Controller, "__AccessibilityProxy") ~= true then
		return Controller
	end

	if Client and typeof(Client.Modules) == "table" and typeof(Client.Modules.AccessibilityController) == "table" then
		return Client.Modules.AccessibilityController
	end

	local globals = getgenv and getgenv()._NULLSCAPE_Globals
	if globals and typeof(globals.activeAccessibilityController) == "table" then
		return globals.activeAccessibilityController
	end

	if getgenv and typeof(getgenv().loadModule) == "function" then
		local success, loadedController = pcall(function()
			return getgenv().loadModule("NULLSCAPE/Accessibility/controller.luau")
		end)
		if success and typeof(loadedController) == "table" then
			if Client and typeof(Client.Modules) == "table" then
				Client.Modules.AccessibilityController = loadedController
			end
			return loadedController
		end
	end

	return nil
end

local function createControllerProxy(Client, Controller)
	return setmetatable({ __AccessibilityProxy = true }, {
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
						end
					end
					return value
				end
			end

			if type(key) == "string" and (string.sub(key, 1, 3) == "Set" or string.sub(key, 1, 3) == "Get") then
				return function(_, ...)
					local latestController = resolveController(Client, Controller)
					local latestMethod = latestController and latestController[key]
					if typeof(latestMethod) == "function" then
						return latestMethod(latestController, ...)
					end
					if string.sub(key, 1, 3) == "Set" then
						warn("[NULLSCAPE] Accessibility controller is not ready; ignored " .. tostring(key))
					end
					return nil
				end
			end

			return DEFAULTS[key]
		end,
	})
end

return function(Client, Controller)
	Controller = createControllerProxy(Client, Controller)
	local Tab = Client.Window:CreateTab("Accessibility", 4483362458)

	Tab:CreateSection("Accessibility Features")

	Tab:CreateToggle({
		Name = "Auto jump - Springer",
		Info = "Automatically jumps over Springer shockwaves when the helper detects an incoming wave.",
		CurrentValue = Controller.SpringerAutoJumpEnabled,
		Flag = "SpringerAutoJumpToggle",
		Callback = function(Value)
			Controller:SetSpringerAutoJump(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Infinite Air Jump",
		Info = "Refills the native DoubleJump charge, preserving the game's animation and SFX.",
		CurrentValue = Controller.InfiniteAirJumpEnabled,
		Flag = "InfiniteAirJumpToggle",
		Callback = function(Value)
			Controller:SetInfiniteAirJump(Value)
		end,
	})

	local infiniteAirJumpStatusLabel = nil
	if Tab.CreateLabel then
		infiniteAirJumpStatusLabel = Tab:CreateLabel(
			"Infinite Air Jump Status: " .. tostring(Controller:GetInfiniteAirJumpStatus() or "pending")
		)
		task.spawn(function()
			while infiniteAirJumpStatusLabel and Client and not Client.Destroyed do
				task.wait(1)
				if infiniteAirJumpStatusLabel and typeof(infiniteAirJumpStatusLabel.Set) == "function" then
					pcall(function()
						infiniteAirJumpStatusLabel:Set(
							"Infinite Air Jump Status: " .. tostring(Controller:GetInfiniteAirJumpStatus() or "pending")
						)
					end)
				end
			end
		end)
	end

	Tab:CreateToggle({
		Name = "Anti Bonk",
		Info = "Suppresses all DiveBonk/stun states from diving or sliding into obstacles completely.",
		CurrentValue = Controller.AntiBonkEnabled or false,
		Flag = "AntiBonkToggle",
		Callback = function(Value)
			Controller:SetAntiBonk(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = " Stamina Mode",
		Info = "Infinite Stamina refills native class stamina/timer resources for classes that expose a compatible stamina bar.",
		Options = { "Manual", "Infinite Stamina" },
		CurrentOption = Controller.StaminaMode or Controller.GrapplerStaminaMode or "Off",
		MultipleOptions = false,
		Flag = "GrapplerStaminaModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetStaminaMode(selected)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Recovery Speed",
		Info = "Multiplies the natural stamina/time recovery speed of the Grappler when not active.",
		Range = { 1, 10 },
		Increment = 0.5,
		Suffix = "x",
		CurrentValue = Controller.GrapplerStaminaRecoverySpeed or 1,
		Flag = "GrapplerStaminaRecoverySpeedSlider",
		Callback = function(Value)
			Controller:SetGrapplerStaminaRecoverySpeed(Value)
		end,
	})

	Tab:CreateSection("Rail Assist")

	Tab:CreateToggle({
		Name = "Rail Assist Suite",
		Info = "Master switch for rail helpers. Required for Auto Rail and Rail Entry Speed to do anything.",
		CurrentValue = Controller.RailAssistSuiteEnabled or false,
		Flag = "RailAssistSuiteToggle",
		Callback = function(Value)
			Controller:SetRailAssistSuite(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Auto Rail",
		Info = "When you are close enough to a _RailPart and not using another movement state, it calls FollowRail for you.",
		CurrentValue = Controller.RailAutoEnabled or false,
		Flag = "RailAutoToggle",
		Callback = function(Value)
			Controller:SetRailAuto(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Rail Entry Speed",
		Info = "Applies once at the moment rail sliding starts. Higher values preserve/boost more horizontal speed.",
		Range = { 1.1, 5 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.RailSpeedMultiplier or 1.1,
		Flag = "RailSpeedMultiplierSlider",
		Callback = function(Value)
			Controller:SetRailSpeedMultiplier(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Auto Rail Delay",
		Info = "Cooldown between automatic rail snaps. Raise it if Auto Rail feels too eager or keeps re-grabbing rails.",
		Range = { 1.35, 3 },
		Increment = 0.15,
		Suffix = "s",
		CurrentValue = Controller.RailAutoDelay or 1.5,
		Flag = "RailAutoDelaySlider",
		Callback = function(Value)
			Controller:SetRailAutoDelay(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Auto Rail Capture Range",
		Info = "Maximum distance in studs before Auto Rail can grab a rail. It only catches rails in the front 180 degrees of your movement/look direction.",
		Range = { 1, 64 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = Controller.RailAutoCaptureRange or 4,
		Flag = "RailAutoCaptureRangeSlider",
		Callback = function(Value)
			Controller:SetRailAutoCaptureRange(Value)
		end,
	})
end
