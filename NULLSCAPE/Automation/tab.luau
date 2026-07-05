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
	Tab:CreateSection("Automation")

	Tab:CreateDropdown({
		Name = "Automation - multi select",
		Options = { "Auto Complete - Kolóna" },
		CurrentOption = Controller and Controller.AutomationSelections or {},
		MultipleOptions = true,
		Flag = "AutomationMultiSelectDropdown",
		Callback = function(Options)
			if Controller and typeof(Controller.SetAutomationSelections) == "function" then
				Controller:SetAutomationSelections(Options)
			end
		end,
	})

	Tab:CreateSection("Auto Choose Things")

	Tab:CreateToggle({
		Name = "Auto Choose Things",
		CurrentValue = Controller and Controller.AutoChooseThingsEnabled or false,
		Flag = "AutomationAutoChooseThingsToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetAutoChooseThingsEnabled) == "function" then
				Controller:SetAutoChooseThingsEnabled(Value)
			end
		end,
	})

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
		Name = "Farm Modes",
		Options = { "Normal (teleport)", "Pipelining (Network)" },
		CurrentOption = Controller and Controller.GiftFarmMode or "Normal (teleport)",
		MultipleOptions = false,
		Flag = "AutomationGiftFarmModeDropdown",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmMode) == "function" then
				Controller:SetGiftFarmMode(Value)
			end
		end,
	})

	Tab:CreateToggle({
		Name = "Collect Medal",
		CurrentValue = Controller and Controller.CollectMedalEnabled or false,
		Flag = "AutomationCollectMedalToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetCollectMedalEnabled) == "function" then
				Controller:SetCollectMedalEnabled(Value)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Gift Farm Range",
		Range = { 5, 60 },
		CurrentValue = Controller
				and typeof(Controller.GetGiftFarmRange) == "function"
				and Controller:GetGiftFarmRange()
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

	Tab:CreateSection("Altars")

	Tab:CreateDropdown({
		Name = "Altar Selections",
		Options = { "Passage", "Purgatory", "Chance", "Protection", "Chaos", "Echo", "Purification" },
		CurrentOption = Controller and Controller.AltarSelections or {},
		MultipleOptions = true,
		Flag = "AutomationAltarSelectionsDropdown",
		Callback = function(Options)
			if Controller and typeof(Controller.SetAltarSelections) == "function" then
				Controller:SetAltarSelections(Options)
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
