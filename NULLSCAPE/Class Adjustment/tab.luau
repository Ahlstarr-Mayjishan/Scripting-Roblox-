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
end
