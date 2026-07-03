--!nocheck
-- [[
--  NULLSCAPE - Automation UI Tab
-- ]]

local function resolveController(Client, fallbackController)
	if Client and typeof(Client.Modules) == "table" and typeof(Client.Modules.AutomationController) == "table" then
		return Client.Modules.AutomationController
	end

	local globals = getgenv()._NULLSCAPE_Globals
	if globals and typeof(globals.activeAutomationController) == "table" then
		return globals.activeAutomationController
	end

	if fallbackController and typeof(fallbackController) == "table" then
		return fallbackController
	end

	local success, loadedController = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Automation/controller.luau")
	end)
	if success and typeof(loadedController) == "table" then
		if Client and typeof(Client.Modules) == "table" then
			Client.Modules.AutomationController = loadedController
		end
		return loadedController
	end

	return nil
end

return function(Client, Controller)
	Controller = resolveController(Client, Controller)
	if not Controller then
		warn("[NULLSCAPE] Automation tab loaded without controller")
	end

	local Tab = Client.Window:CreateTab("Automation", 4483362458)
	Tab:CreateSection("Auto Farm")

	Tab:CreateToggle({
		Name = "Gift Farm",
		CurrentValue = Controller and Controller.GiftFarmEnabled or false,
		Flag = "AutomationGiftFarmToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmEnabled) == "function" then
				Controller:SetGiftFarmEnabled(Value)
			end
		end,
	})

	Tab:CreateDropdown({
		Name = "Gift Farm Mode",
		Options = { "Golden Priority", "Golden Only", "Purgatory Greed", "Purgatory Revive Window", "Full Sweep" },
		CurrentOption = Controller and Controller.GiftFarmMode or "Golden Priority",
		MultipleOptions = false,
		Flag = "AutomationGiftFarmModeDropdown",
		Callback = function(Option)
			if Controller and typeof(Controller.SetGiftFarmMode) == "function" then
				Controller:SetGiftFarmMode(Option)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Gift Farm Range",
		Range = { 5, 60 },
		CurrentValue = Controller and typeof(Controller.GetGiftFarmRange) == "function" and Controller:GetGiftFarmRange()
			or (Controller and Controller.GiftFarmRange or 60),
		Increment = 1,
		ValueName = "Studs",
		Flag = "AutomationGiftFarmRangeSlider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmRange) == "function" then
				Controller:SetGiftFarmRange(Value)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Gift Farm Burst",
		Range = { 1, 60 },
		CurrentValue = Controller and Controller.GiftFarmBurstSize or 16,
		Increment = 1,
		ValueName = "Gifts",
		Flag = "AutomationGiftFarmBurstSlider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmBurstSize) == "function" then
				Controller:SetGiftFarmBurstSize(Value)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Collects Per Frame",
		Range = { 1, 60 },
		CurrentValue = Controller and Controller.GiftFarmCollectsPerFrame or 8,
		Increment = 1,
		ValueName = "Gifts",
		Flag = "AutomationGiftFarmCollectsPerFrameSlider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmCollectsPerFrame) == "function" then
				Controller:SetGiftFarmCollectsPerFrame(Value)
			end
		end,
	})

	Tab:CreateToggle({
		Name = "Return After Cluster",
		CurrentValue = Controller and Controller.GiftFarmReturnAfterCluster ~= false,
		Flag = "AutomationGiftFarmReturnToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmReturnAfterCluster) == "function" then
				Controller:SetGiftFarmReturnAfterCluster(Value)
			end
		end,
	})

	Tab:CreateToggle({
		Name = "Return Beacon After Golden",
		CurrentValue = Controller and Controller.GiftFarmReturnToBeaconAfterGolden ~= false,
		Flag = "AutomationGiftFarmReturnBeaconToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmReturnToBeaconAfterGolden) == "function" then
				Controller:SetGiftFarmReturnToBeaconAfterGolden(Value)
			end
		end,
	})

	Tab:CreateSection("Pylons")

	Tab:CreateToggle({
		Name = "Auto Activate Pylons",
		CurrentValue = Controller and Controller.PylonActivatorEnabled or false,
		Flag = "AutomationPylonActivatorToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetPylonActivatorEnabled) == "function" then
				Controller:SetPylonActivatorEnabled(Value)
			end
		end,
	})

	Tab:CreateToggle({
		Name = "Return After Pylons",
		CurrentValue = Controller and Controller.PylonActivatorReturnAfter ~= false,
		Flag = "AutomationPylonActivatorReturnToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetPylonActivatorReturnAfter) == "function" then
				Controller:SetPylonActivatorReturnAfter(Value)
			end
		end,
	})
end
