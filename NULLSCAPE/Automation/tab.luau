--!nocheck
-- [[
--  NULLSCAPE - Automation UI Tab
-- ]]

local ChoicePolicy = getgenv().loadModule("NULLSCAPE/Automation/Choice Policy.luau")

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

	Tab:CreateDropdown({
		Name = "Medal Intermission Choice",
		Info = "Medal keeps native rerolls. Curse Medal grants Golden Gifts but disables rerolls.",
		Options = { "Medal", "Curse Medal" },
		CurrentOption = Controller and Controller.MedalChoiceMode or "Medal",
		MultipleOptions = false,
		Flag = "AutomationMedalChoiceModeDropdown",
		Callback = function(Value)
			local selected = typeof(Value) == "table" and Value[1] or Value
			if Controller and typeof(Controller.SetMedalChoiceMode) == "function" then
				Controller:SetMedalChoiceMode(selected)
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
			local selected = Value
			if typeof(Value) == "table" then
				selected = Value[1]
			end
			if Controller and typeof(Controller.SetGiftFarmMode) == "function" then
				Controller:SetGiftFarmMode(selected)
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

	Tab:CreateSection("Rules for AutoFarm")

	Tab:CreateToggle({
		Name = "Enable AutoFarm Rules",
		CurrentValue = Controller and Controller.GiftFarmRulesEnabled or false,
		Flag = "AutomationGiftFarmRulesToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmRulesEnabled) == "function" then
				Controller:SetGiftFarmRulesEnabled(Value)
			end
		end,
	})

	Tab:CreateToggle({
		Name = "No-Tracking me",
		Info = "Runs continuously and safely rotates servers during intermission before long sessions become unstable.",
		CurrentValue = Controller and Controller.GiftFarmNoTrackingEnabled or false,
		Flag = "AutomationGiftFarmNoTrackingToggle",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmNoTrackingEnabled) == "function" then
				Controller:SetGiftFarmNoTrackingEnabled(Value)
			end
		end,
	})

	local policyDropdowns = {}
	local policyIndexNames = {}
	local policyBaseOptions = {}
	local syncingPolicyDropdowns = false
	local oppositePolicyFields = {
		EnemyChoiceWhitelist = "EnemyChoiceBlacklist",
		EnemyChoiceBlacklist = "EnemyChoiceWhitelist",
		CurseChoiceWhitelist = "CurseChoiceBlacklist",
		CurseChoiceBlacklist = "CurseChoiceWhitelist",
		GreaterCurseChoiceWhitelist = "GreaterCurseChoiceBlacklist",
		GreaterCurseChoiceBlacklist = "GreaterCurseChoiceWhitelist",
	}

	local function selectionsMatch(left, right)
		if typeof(left) ~= "table" or #left ~= #right then
			return false
		end
		for index, value in ipairs(left) do
			if value ~= right[index] then
				return false
			end
		end
		return true
	end

	local function refreshPolicyDropdown(field)
		local dropdown = policyDropdowns[field]
		local indexName = policyIndexNames[field]
		if not (dropdown and indexName) then
			return
		end

		local oppositeField = oppositePolicyFields[field]
		local opposite = Controller and Controller[oppositeField] or {}
		local options = ChoicePolicy.excludeSelections(indexName, policyBaseOptions[field] or {}, opposite)
		local selected = ChoicePolicy.normalizeSelections(indexName, Controller and Controller[field] or {})

		if typeof(dropdown.Refresh) == "function" then
			dropdown:Refresh(options)
		end
		if not selectionsMatch(dropdown.CurrentOption or {}, selected) and typeof(dropdown.Set) == "function" then
			dropdown:Set(selected)
		end
	end

	local function refreshPolicyPair(field)
		task.defer(function()
			if syncingPolicyDropdowns then
				return
			end
			syncingPolicyDropdowns = true
			refreshPolicyDropdown(field)
			refreshPolicyDropdown(oppositePolicyFields[field])
			syncingPolicyDropdowns = false
		end)
	end

	local function createChoicePolicyDropdown(name, info, indexName, field, flag, setter)
		policyIndexNames[field] = indexName
		policyBaseOptions[field] = ChoicePolicy.getOptions(indexName)
		local oppositeField = oppositePolicyFields[field]
		local initialOptions = ChoicePolicy.excludeSelections(
			indexName,
			policyBaseOptions[field],
			Controller and Controller[oppositeField] or {}
		)

		local dropdown = Tab:CreateDropdown({
			Name = name,
			Info = info,
			Options = initialOptions,
			CurrentOption = ChoicePolicy.normalizeSelections(indexName, Controller and Controller[field] or {}),
			MultipleOptions = true,
			Flag = flag,
			Callback = function(Options)
				if syncingPolicyDropdowns then
					return
				end
				local normalized = ChoicePolicy.normalizeSelections(indexName, Options)
				if Controller and typeof(Controller[setter]) == "function" then
					Controller[setter](Controller, normalized)
				end
				refreshPolicyPair(field)
			end,
		})
		policyDropdowns[field] = dropdown
	end

	createChoicePolicyDropdown(
		"Enemy Whitelist",
		"Preferred enemies. The first matching available enemy is selected.",
		"EnemyIndex",
		"EnemyChoiceWhitelist",
		"AutomationEnemyChoiceWhitelistDropdown",
		"SetEnemyChoiceWhitelist"
	)
	createChoicePolicyDropdown(
		"Enemy Blacklist",
		"Avoided whenever possible. If every enemy is blacklisted, native rerolls are used before choosing a fallback.",
		"EnemyIndex",
		"EnemyChoiceBlacklist",
		"AutomationEnemyChoiceBlacklistDropdown",
		"SetEnemyChoiceBlacklist"
	)
	createChoicePolicyDropdown(
		"Curse Whitelist",
		"Preferred normal curses. The first matching available curse is selected.",
		"CurseIndex",
		"CurseChoiceWhitelist",
		"AutomationCurseChoiceWhitelistDropdown",
		"SetCurseChoiceWhitelist"
	)
	createChoicePolicyDropdown(
		"Curse Blacklist",
		"Avoided whenever possible. If every normal curse is blacklisted, native rerolls are used before choosing a fallback.",
		"CurseIndex",
		"CurseChoiceBlacklist",
		"AutomationCurseChoiceBlacklistDropdown",
		"SetCurseChoiceBlacklist"
	)
	createChoicePolicyDropdown(
		"Greater Curse Whitelist",
		"Preferred greater curses. The first matching available greater curse is selected.",
		"GreaterCurseIndex",
		"GreaterCurseChoiceWhitelist",
		"AutomationGreaterCurseChoiceWhitelistDropdown",
		"SetGreaterCurseChoiceWhitelist"
	)
	createChoicePolicyDropdown(
		"Greater Curse Blacklist",
		"Avoided whenever possible. If every greater curse is blacklisted, native rerolls are used before choosing a fallback.",
		"GreaterCurseIndex",
		"GreaterCurseChoiceBlacklist",
		"AutomationGreaterCurseChoiceBlacklistDropdown",
		"SetGreaterCurseChoiceBlacklist"
	)

	if Controller and typeof(Controller.NormalizeChoicePolicies) == "function" then
		Controller:NormalizeChoicePolicies()
	end
	refreshPolicyPair("EnemyChoiceWhitelist")
	refreshPolicyPair("CurseChoiceWhitelist")
	refreshPolicyPair("GreaterCurseChoiceWhitelist")

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

	Tab:CreateSlider({
		Name = "Golden Gift Collection Target (0 = All)",
		Info = "Stop prioritizing Golden Gifts after reaching this percentage. Zero disables the cap and collects all.",
		Range = { 0, 100 },
		CurrentValue = Controller and Controller.GiftFarmGoldenEfficiency or 100,
		Increment = 1,
		ValueName = "%",
		Flag = "AutomationGiftFarmGoldenEfficiencySlider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmGoldenEfficiency) == "function" then
				Controller:SetGiftFarmGoldenEfficiency(Value)
			end
		end,
	})

	Tab:CreateDropdown({
		Name = "Rest Mode",
		Options = { "Every Completed Round", "Interval" },
		CurrentOption = Controller and Controller.GiftFarmRestMode or "Interval",
		MultipleOptions = false,
		Flag = "AutomationGiftFarmRestModeDropdown",
		Callback = function(Value)
			local selected = typeof(Value) == "table" and Value[1] or Value
			if Controller and typeof(Controller.SetGiftFarmRestMode) == "function" then
				Controller:SetGiftFarmRestMode(selected)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Rest Interval (Rounds)",
		Info = "Rest after this many completed AutoFarm rounds, only during intermission.",
		Range = { 1, 30 },
		CurrentValue = Controller and Controller.GiftFarmRestIntervalRounds or 5,
		Increment = 1,
		ValueName = "Rounds",
		Flag = "AutomationGiftFarmRestIntervalRoundsSlider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmRestIntervalRounds) == "function" then
				Controller:SetGiftFarmRestIntervalRounds(Value)
			end
		end,
	})

	Tab:CreateDropdown({
		Name = "Goal Mode",
		Options = { "Reach to Levels", "Min-Max" },
		CurrentOption = Controller and Controller.GiftFarmGoalMode or "Reach to Levels",
		MultipleOptions = false,
		Flag = "AutomationGiftFarmGoalModeDropdown",
		Callback = function(Value)
			local selected = typeof(Value) == "table" and Value[1] or Value
			if Controller and typeof(Controller.SetGiftFarmGoalMode) == "function" then
				Controller:SetGiftFarmGoalMode(selected)
			end
		end,
	})

	Tab:CreateInput({
		Name = "Target Level",
		Info = "0 keeps farming without a level limit.",
		CurrentValue = tostring(Controller and Controller.GiftFarmTargetLevel or 100),
		PlaceholderText = "100",
		RemoveTextAfterFocusLost = false,
		Flag = "AutomationGiftFarmTargetLevelInput",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmTargetLevel) == "function" then
				Controller:SetGiftFarmTargetLevel(Value)
			end
		end,
	})

	Tab:CreateInput({
		Name = "Minimum Level",
		Info = "Lower bound used by Min-Max when Maximum Level is above 0.",
		CurrentValue = tostring(Controller and Controller.GiftFarmMinLevel or 10),
		PlaceholderText = "10",
		RemoveTextAfterFocusLost = false,
		Flag = "AutomationGiftFarmMinLevelInput",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmMinLevel) == "function" then
				Controller:SetGiftFarmMinLevel(Value)
			end
		end,
	})

	Tab:CreateInput({
		Name = "Maximum Level",
		Info = "0 keeps farming without a level limit in Min-Max mode.",
		CurrentValue = tostring(Controller and Controller.GiftFarmMaxLevel or 50),
		PlaceholderText = "50",
		RemoveTextAfterFocusLost = false,
		Flag = "AutomationGiftFarmMaxLevelInput",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmMaxLevel) == "function" then
				Controller:SetGiftFarmMaxLevel(Value)
			end
		end,
	})

	Tab:CreateInput({
		Name = "Farm Repeats (0 = Infinite)",
		CurrentValue = tostring(Controller and Controller.GiftFarmRepeatCount or 0),
		PlaceholderText = "0",
		RemoveTextAfterFocusLost = false,
		Flag = "AutomationGiftFarmRepeatCountInput",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmRepeatCount) == "function" then
				Controller:SetGiftFarmRepeatCount(Value)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Level 10+ to 25 Wait",
		Range = { 0, 30 },
		CurrentValue = Controller and Controller.GiftFarmWaitMinutes10To24 or 5,
		Increment = 1,
		ValueName = "Minutes",
		Flag = "AutomationGiftFarmWait10To24Slider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmWaitMinutes10To24) == "function" then
				Controller:SetGiftFarmWaitMinutes10To24(Value)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Level 25+ to 50 Wait",
		Range = { 0, 30 },
		CurrentValue = Controller and Controller.GiftFarmWaitMinutes25To49 or 10,
		Increment = 1,
		ValueName = "Minutes",
		Flag = "AutomationGiftFarmWait25To49Slider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmWaitMinutes25To49) == "function" then
				Controller:SetGiftFarmWaitMinutes25To49(Value)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Level 50+ Wait",
		Range = { 0, 30 },
		CurrentValue = Controller and Controller.GiftFarmWaitMinutes50Plus or 20,
		Increment = 1,
		ValueName = "Minutes",
		Flag = "AutomationGiftFarmWait50PlusSlider",
		Callback = function(Value)
			if Controller and typeof(Controller.SetGiftFarmWaitMinutes50Plus) == "function" then
				Controller:SetGiftFarmWaitMinutes50Plus(Value)
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
