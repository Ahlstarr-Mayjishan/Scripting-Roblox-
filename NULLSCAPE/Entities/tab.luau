local function resolveController(Client, Controller)
	if typeof(Controller) == "table" then
		return Controller
	end

	if Client and typeof(Client.Modules) == "table" and typeof(Client.Modules.EntitiesController) == "table" then
		return Client.Modules.EntitiesController
	end

	local globals = getgenv and getgenv()._NULLSCAPE_Globals
	if globals and typeof(globals.activeEntitiesController) == "table" then
		return globals.activeEntitiesController
	end

	if getgenv and typeof(getgenv().loadModule) == "function" then
		local success, loadedController = pcall(function()
			return getgenv().loadModule("NULLSCAPE/Entities/controller.luau")
		end)
		if success and typeof(loadedController) == "table" then
			if Client and typeof(Client.Modules) == "table" then
				Client.Modules.EntitiesController = loadedController
			end
			return loadedController
		end
	end

	return nil
end

local function getFlag(Controller, flagName)
	local activeController = resolveController(nil, Controller)
	return activeController and activeController[flagName] == true
end

local function getStatusImmunity(Controller)
	local activeController = resolveController(nil, Controller)
	return activeController and activeController.StatusImmunity or nil
end

local primaryImmunityUISyncing = false

local function setImmunity(Controller, entityName, value)
	if primaryImmunityUISyncing then
		return
	end
	local activeController = resolveController(nil, Controller)
	if activeController and typeof(activeController.SetImmunity) == "function" then
		activeController:SetImmunity(entityName, value)
	else
		warn("[NULLSCAPE] Entities controller is not ready; ignored immunity toggle for " .. tostring(entityName))
	end
end

local function setShieldBaitEnabled(Controller, value)
	local activeController = resolveController(nil, Controller)
	if activeController and typeof(activeController.SetShieldBaitEnabled) == "function" then
		activeController:SetShieldBaitEnabled(value)
	else
		warn("[NULLSCAPE] Entities controller is not ready; ignored shield bait toggle")
	end
end

local function setShieldBaitChance(Controller, value)
	local activeController = resolveController(nil, Controller)
	if activeController and typeof(activeController.SetShieldBaitChance) == "function" then
		activeController:SetShieldBaitChance(value)
	else
		warn("[NULLSCAPE] Entities controller is not ready; ignored shield bait chance")
	end
end

local function optionSelected(options, optionName)
	if typeof(options) ~= "table" then
		return false
	end
	for _, opt in ipairs(options) do
		if opt == optionName then
			return true
		end
	end
	return options[optionName] == true
end

local ICBM_SCORCHED_EARTH_OPTION = "Immune Scorched Earth"
local ICBM_SCORCHED_EARTH_LEGACY_OPTION = "Burn effect (Curse)"

return function(Client, Controller)
	Controller = resolveController(Client, Controller)
	if not Controller then
		warn("[NULLSCAPE] Entities tab loaded without controller; toggles will retry on use")
		Controller = {}
	end

	local Tab = Client.Window:CreateTab("Immunity", 4483362458)
	local primaryControls = {}
	local oneForAllControl = nil
	local refreshScheduled = false
	local updatePrimaryImmunityUI

	local advancedOptions = {
		Bell = {
			{ Flag = "BellCurseImmune", Option = "Mighty Gong" },
			{ Flag = "BellBlindnessImmune", Option = "Ring screen blindness" },
			{ Flag = "BellOvertunedKillImmune", Option = "Overtuned kill" },
		},
		Flesh = {
			{ Flag = "FleshConcussionImmune", Option = "Concussion" },
			{ Flag = "FleshScreenEffectImmune", Option = "Screen effects" },
		},
		ICBM = { { Flag = "ICBMBurnImmune", Option = ICBM_SCORCHED_EARTH_OPTION } },
		Operator = { { Flag = "OperatorAutoDisable", Option = "Auto Disable" } },
		Springer = {
			{ Flag = "SpringerKnockbackImmune", Option = "Immunity Shockwave" },
			{ Flag = "SpringerAutoJumpEnabled", Option = "Auto Jump" },
		},
		Cadence = {
			{ Flag = "CadenceAutoCollectInstruments", Option = "Auto Collect Instruments" },
			{ Flag = "CadenceCheckStatus", Option = "CheckStatus" },
		},
		Ponderer = { { Flag = "PondererSilentLookat", Option = "Silent Lookat" } },
		Kolona = { { Flag = "KolonaAutoQTEEnabled", Option = "Auto QTE" } },
		Razorbloom = { { Flag = "RazorbloomAutoDisable", Option = "Auto Disable" } },
	}

	local function createPrimaryToggle(entityName, flagName, options)
		local control = Tab:CreateToggle(options)
		primaryControls[entityName] = { Control = control, Flag = flagName }
		return control
	end

	local function createPrimaryDropdown(entityName, flagName, options)
		local control = Tab:CreateDropdown(options)
		primaryControls[entityName] = {
			Control = control,
			Flag = flagName,
			Advanced = advancedOptions[entityName] or {},
		}
		return control
	end

	local function schedulePrimaryImmunityUIUpdate()
		if refreshScheduled then
			return
		end
		refreshScheduled = true
		task.defer(function()
			refreshScheduled = false
			if updatePrimaryImmunityUI then
				updatePrimaryImmunityUI()
			end
		end)
	end

	updatePrimaryImmunityUI = function()
		local activeController = resolveController(nil, Controller)
		if not activeController then
			return false
		end

		primaryImmunityUISyncing = true
		if oneForAllControl and typeof(oneForAllControl.Set) == "function" then
			pcall(function()
				oneForAllControl:Set(activeController:AreAllPrimaryImmunitiesEnabled())
			end)
		end
		for _, entry in pairs(primaryControls) do
			if entry.Control and typeof(entry.Control.Set) == "function" then
				pcall(function()
					if entry.Advanced then
						local options = {}
						if activeController[entry.Flag] == true then
							table.insert(options, "Immunity")
						end
						for _, advanced in ipairs(entry.Advanced) do
							if activeController[advanced.Flag] == true then
								table.insert(options, advanced.Option)
							end
						end
						entry.Control:Set(options)
					else
						entry.Control:Set(activeController[entry.Flag] == true)
					end
				end)
			end
		end
		primaryImmunityUISyncing = false
		return true
	end

	Tab:CreateSection("All Entities")
	oneForAllControl = Tab:CreateToggle({
		Name = "One for All",
		CurrentValue = typeof(Controller.AreAllPrimaryImmunitiesEnabled) == "function"
				and Controller:AreAllPrimaryImmunitiesEnabled()
			or false,
		Callback = function(Value)
			if primaryImmunityUISyncing then
				return
			end
			local activeController = resolveController(nil, Controller)
			if activeController and typeof(activeController.SetAllPrimaryImmunities) == "function" then
				activeController:SetAllPrimaryImmunities(Value)
				schedulePrimaryImmunityUIUpdate()
			end
		end,
	})

	Tab:CreateSection("Entities List - Touch Immunity")

	createPrimaryToggle("Baby", "BabyImmune", {
		Name = "Baby",
		CurrentValue = getFlag(Controller, "BabyImmune"),
		Flag = "ImmunityBabyToggle",
		Callback = function(Value)
			setImmunity(Controller, "Baby", Value)
		end,
	})

	local currentBellOptions = {}
	if getFlag(Controller, "BellImmune") then
		table.insert(currentBellOptions, "Immunity")
	end
	if getFlag(Controller, "BellCurseImmune") then
		table.insert(currentBellOptions, "Mighty Gong")
	end
	if getFlag(Controller, "BellBlindnessImmune") then
		table.insert(currentBellOptions, "Ring screen blindness")
	end
	if getFlag(Controller, "BellOvertunedKillImmune") then
		table.insert(currentBellOptions, "Overtuned kill")
	end

	createPrimaryDropdown("Bell", "BellImmune", {
		Name = "Bell Hack Mode",
		Options = { "Immunity", "Mighty Gong", "Ring screen blindness", "Overtuned kill" },
		CurrentOption = currentBellOptions,
		MultipleOptions = true,
		Flag = "BellHackDropdownV2",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local hasImmunity = optionSelected(Options, "Immunity")
			local hasCurseImmune = optionSelected(Options, "Mighty Gong")
				or optionSelected(Options, "Knockback (Curse)")
			local hasBlindnessImmune = optionSelected(Options, "Ring screen blindness")
			local hasOvertunedKillImmune = optionSelected(Options, "Overtuned kill")
			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("Bell", hasImmunity)
				end
				if typeof(activeController.SetBellCurseImmune) == "function" then
					activeController:SetBellCurseImmune(hasCurseImmune)
				end
				if typeof(activeController.SetBellBlindnessImmune) == "function" then
					activeController:SetBellBlindnessImmune(hasBlindnessImmune)
				end
				if typeof(activeController.SetBellOvertunedKillImmune) == "function" then
					activeController:SetBellOvertunedKillImmune(hasOvertunedKillImmune)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Bell Hack Mode change")
			end
		end,
	})

	local currentFleshOptions = {}
	if getFlag(Controller, "FleshImmune") then
		table.insert(currentFleshOptions, "Immunity")
	end
	if getFlag(Controller, "FleshConcussionImmune") then
		table.insert(currentFleshOptions, "Concussion")
	end
	if getFlag(Controller, "FleshScreenEffectImmune") then
		table.insert(currentFleshOptions, "Screen effects")
	end

	createPrimaryDropdown("Flesh", "FleshImmune", {
		Name = "Flesh Hack Mode",
		Options = { "Immunity", "Concussion", "Screen effects" },
		CurrentOption = currentFleshOptions,
		MultipleOptions = true,
		Flag = "FleshHackDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local hasImmunity = false
			local hasConcussionImmune = false
			local hasScreenEffectImmune = false
			for _, opt in ipairs(Options) do
				if opt == "Immunity" then
					hasImmunity = true
				elseif opt == "Concussion" then
					hasConcussionImmune = true
				elseif opt == "Screen effects" then
					hasScreenEffectImmune = true
				end
			end
			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("Flesh", hasImmunity)
				end
				if typeof(activeController.SetFleshConcussionImmune) == "function" then
					activeController:SetFleshConcussionImmune(hasConcussionImmune)
				end
				if typeof(activeController.SetFleshScreenEffectImmune) == "function" then
					activeController:SetFleshScreenEffectImmune(hasScreenEffectImmune)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Flesh Hack Mode change")
			end
		end,
	})

	createPrimaryToggle("Mart", "MartImmune", {
		Name = "Mart",
		CurrentValue = getFlag(Controller, "MartImmune"),
		Flag = "ImmunityMartToggle",
		Callback = function(Value)
			setImmunity(Controller, "Mart", Value)
		end,
	})

	createPrimaryToggle("Telefragger", "TelefraggerImmune", {
		Name = "Telefragger",
		CurrentValue = getFlag(Controller, "TelefraggerImmune"),
		Flag = "ImmunityTelefraggerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Telefragger", Value)
		end,
	})

	Tab:CreateSection("Entities - Client Side")

	local currentICBMOptions = {}
	if getFlag(Controller, "ICBMImmune") then
		table.insert(currentICBMOptions, "Immunity")
	end
	if getFlag(Controller, "ICBMBurnImmune") then
		table.insert(currentICBMOptions, ICBM_SCORCHED_EARTH_OPTION)
	end

	createPrimaryDropdown("ICBM", "ICBMImmune", {
		Name = "ICBM Hack Mode",
		Options = { "Immunity", ICBM_SCORCHED_EARTH_OPTION },
		CurrentOption = currentICBMOptions,
		MultipleOptions = true,
		Flag = "ICBMHackDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local hasImmunity = optionSelected(Options, "Immunity")
			local hasBurnImmunity = optionSelected(Options, ICBM_SCORCHED_EARTH_OPTION)
				or optionSelected(Options, ICBM_SCORCHED_EARTH_LEGACY_OPTION)
			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("ICBM", hasImmunity)
				end
				if typeof(activeController.SetICBMBurnImmune) == "function" then
					activeController:SetICBMBurnImmune(hasBurnImmunity)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored ICBM Hack Mode change")
			end
		end,
	})

	createPrimaryToggle("Guardian", "GuardianImmune", {
		Name = "Guardian",
		CurrentValue = getFlag(Controller, "GuardianImmune"),
		Flag = "ImmunityGuardianToggle",
		Callback = function(Value)
			setImmunity(Controller, "Guardian", Value)
		end,
	})

	local currentOperatorOptions = {}
	if getFlag(Controller, "OperatorImmune") then
		table.insert(currentOperatorOptions, "Immunity")
	end
	if getFlag(Controller, "OperatorAutoDisable") then
		table.insert(currentOperatorOptions, "Auto Disable")
	end

	createPrimaryDropdown("Operator", "OperatorImmune", {
		Name = "Operator Hack Mode",
		Options = { "Immunity", "Auto Disable" },
		CurrentOption = currentOperatorOptions,
		MultipleOptions = true,
		Flag = "OperatorHackDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local activeController = resolveController(nil, Controller)
			if activeController and typeof(activeController.SetOperatorOptions) == "function" then
				activeController:SetOperatorOptions(Options)
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Operator Hack Mode change")
			end
		end,
	})

	local currentSpringerOptions = {}
	if getFlag(Controller, "SpringerImmune") then
		table.insert(currentSpringerOptions, "Immunity")
	end
	if getFlag(Controller, "SpringerKnockbackImmune") then
		table.insert(currentSpringerOptions, "Immunity Shockwave")
	end
	if getFlag(Controller, "SpringerAutoJumpEnabled") then
		table.insert(currentSpringerOptions, "Auto Jump")
	end

	createPrimaryDropdown("Springer", "SpringerImmune", {
		Name = "Springer Hack Mode",
		Options = { "Immunity", "Immunity Shockwave", "Auto Jump" },
		CurrentOption = currentSpringerOptions,
		MultipleOptions = true,
		Flag = "SpringerHackDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local activeController = resolveController(nil, Controller)
			if activeController and typeof(activeController.SetSpringerOptions) == "function" then
				activeController:SetSpringerOptions(Options)
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Springer Hack Mode change")
			end
		end,
	})

	local currentCadenceOptions = {}
	if getFlag(Controller, "CadenceImmune") then
		table.insert(currentCadenceOptions, "Immunity")
	end
	if getFlag(Controller, "CadenceAutoCollectInstruments") then
		table.insert(currentCadenceOptions, "Auto Collect Instruments")
	end
	if getFlag(Controller, "CadenceCheckStatus") then
		table.insert(currentCadenceOptions, "CheckStatus")
	end

	createPrimaryDropdown("Cadence", "CadenceImmune", {
		Name = "Cadence",
		Options = { "Immunity", "Auto Collect Instruments", "CheckStatus" },
		CurrentOption = currentCadenceOptions,
		MultipleOptions = true,
		Flag = "CadenceOptionsDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			if typeof(Controller.SetCadenceOptions) == "function" then
				Controller:SetCadenceOptions(Options)
			else
				setImmunity(Controller, "Cadence", table.find(Options, "Immunity") ~= nil)
			end
		end,
	})

	Tab:CreateSlider({
		Name = "Cadence Instrument Range",
		Range = { 0, 30 },
		CurrentValue = Controller.CadenceInstrumentRange or 0,
		Increment = 1,
		ValueName = "Studs (0=Inf)",
		Flag = "CadenceInstrumentRangeSlider",
		Callback = function(Value)
			if typeof(Controller.SetCadenceInstrumentRange) == "function" then
				Controller:SetCadenceInstrumentRange(Value)
			end
		end,
	})

	local currentPondererOptions = {}
	if getFlag(Controller, "PondererImmune") then
		table.insert(currentPondererOptions, "Immunity")
	end
	if getFlag(Controller, "PondererSilentLookat") then
		table.insert(currentPondererOptions, "Silent Lookat")
	end

	createPrimaryDropdown("Ponderer", "PondererImmune", {
		Name = "Ponderer Mode",
		Options = { "Immunity", "Silent Lookat" },
		CurrentOption = currentPondererOptions,
		MultipleOptions = true,
		Flag = "PondererHackDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local hasImmunity = false
			local hasSilentLookat = false
			for _, opt in ipairs(Options) do
				if opt == "Immunity" then
					hasImmunity = true
				elseif opt == "Silent Lookat" then
					hasSilentLookat = true
				end
			end

			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("Ponderer", hasImmunity)
				end
				if typeof(activeController.SetPondererSilentLookat) == "function" then
					activeController:SetPondererSilentLookat(hasSilentLookat)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Ponderer Mode change")
			end
		end,
	})

	createPrimaryToggle("Celestial", "CelestialImmune", {
		Name = "Celestial",
		CurrentValue = getFlag(Controller, "CelestialImmune"),
		Flag = "ImmunityCelestialToggle",
		Callback = function(Value)
			setImmunity(Controller, "Celestial", Value)
		end,
	})

	createPrimaryToggle("RealityBreak", "RealityBreakImmune", {
		Name = "Reality Break",
		CurrentValue = getFlag(Controller, "RealityBreakImmune"),
		Flag = "ImmunityRealityBreakToggle",
		Callback = function(Value)
			setImmunity(Controller, "RealityBreak", Value)
		end,
	})

	createPrimaryToggle("Scrapmaw", "ScrapmawImmune", {
		Name = "Scrapmaw",
		CurrentValue = getFlag(Controller, "ScrapmawImmune"),
		Flag = "ImmunityScrapmawToggle",
		Callback = function(Value)
			setImmunity(Controller, "Scrapmaw", Value)
		end,
	})

	createPrimaryToggle("Catalyst", "CatalystImmune", {
		Name = "Catalyst",
		CurrentValue = getFlag(Controller, "CatalystImmune"),
		Flag = "ImmunityCatalystToggle",
		Callback = function(Value)
			setImmunity(Controller, "Catalyst", Value)
		end,
	})

	createPrimaryToggle("nilEnemy", "nilEnemyImmune", {
		Name = "nilEnemy",
		CurrentValue = getFlag(Controller, "nilEnemyImmune"),
		Flag = "ImmunitynilEnemyToggle",
		Callback = function(Value)
			setImmunity(Controller, "nilEnemy", Value)
		end,
	})

	createPrimaryToggle("nilMirage", "nilMirageImmune", {
		Name = "nilMirage",
		CurrentValue = getFlag(Controller, "nilMirageImmune"),
		Flag = "ImmunitynilMirageToggle",
		Callback = function(Value)
			setImmunity(Controller, "nilMirage", Value)
		end,
	})

	Tab:CreateSection("Entities - Special Immunity")

	local currentKolonaOptions = {}
	if getFlag(Controller, "KolonaImmune") then
		table.insert(currentKolonaOptions, "Immunity")
	end
	if getFlag(Controller, "KolonaAutoQTEEnabled") then
		table.insert(currentKolonaOptions, "Auto QTE")
	end

	createPrimaryDropdown("Kolona", "KolonaImmune", {
		Name = "Kolona Hack Mode",
		Options = { "Immunity", "Auto QTE" },
		CurrentOption = currentKolonaOptions,
		MultipleOptions = true,
		Flag = "KolonaHackDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local hasImmunity = optionSelected(Options, "Immunity")
			local hasAutoQTE = optionSelected(Options, "Auto QTE")
			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("Kolona", hasImmunity)
				end
				if typeof(activeController.SetKolonaAutoQTE) == "function" then
					activeController:SetKolonaAutoQTE(hasAutoQTE)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Kolona Hack Mode change")
			end
		end,
	})

	createPrimaryToggle("Oblivion", "OblivionImmune", {
		Name = "Oblivion",
		CurrentValue = getFlag(Controller, "OblivionImmune"),
		Flag = "ImmunityOblivionToggle",
		Callback = function(Value)
			setImmunity(Controller, "Oblivion", Value)
		end,
	})

	createPrimaryToggle("ShadowBaby", "ShadowBabyImmune", {
		Name = "ShadowBaby",
		CurrentValue = getFlag(Controller, "ShadowBabyImmune"),
		Flag = "ImmunityShadowBabyToggle",
		Callback = function(Value)
			setImmunity(Controller, "ShadowBaby", Value)
		end,
	})

	createPrimaryToggle("Quartz", "QuartzImmune", {
		Name = "Quartz",
		CurrentValue = getFlag(Controller, "QuartzImmune"),
		Flag = "ImmunityQuartzToggle",
		Callback = function(Value)
			setImmunity(Controller, "Quartz", Value)
		end,
	})

	createPrimaryToggle("Sigil", "SigilImmune", {
		Name = "Sigil",
		CurrentValue = getFlag(Controller, "SigilImmune"),
		Flag = "ImmunitySigilToggle",
		Callback = function(Value)
			setImmunity(Controller, "Sigil", Value)
		end,
	})

	createPrimaryToggle("Slicer", "SlicerImmune", {
		Name = "Slicer",
		CurrentValue = getFlag(Controller, "SlicerImmune"),
		Flag = "ImmunitySlicerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Slicer", Value)
		end,
	})

	createPrimaryToggle("Voidbreaker", "VoidbreakerImmune", {
		Name = "Voidbreaker",
		CurrentValue = getFlag(Controller, "VoidbreakerImmune"),
		Flag = "ImmunityVoidbreakerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Voidbreaker", Value)
		end,
	})

	local currentRazorbloomOptions = {}
	if getFlag(Controller, "RazorbloomImmune") then
		table.insert(currentRazorbloomOptions, "Immunity")
	end
	if getFlag(Controller, "RazorbloomAutoDisable") then
		table.insert(currentRazorbloomOptions, "Auto Disable")
	end

	createPrimaryDropdown("Razorbloom", "RazorbloomImmune", {
		Name = "Razorbloom",
		Options = { "Immunity", "Auto Disable" },
		CurrentOption = currentRazorbloomOptions,
		MultipleOptions = true,
		Flag = "RazorbloomHackDropdown",
		Callback = function(Options)
			if primaryImmunityUISyncing then
				return
			end
			local activeController = resolveController(nil, Controller)
			if activeController and typeof(activeController.SetRazorbloomOptions) == "function" then
				activeController:SetRazorbloomOptions(Options)
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Razorbloom change")
			end
		end,
	})

	createPrimaryToggle("VoidImplosion", "VoidImplosionImmune", {
		Name = "Void Implosion",
		CurrentValue = getFlag(Controller, "VoidImplosionImmune"),
		Flag = "ImmunityVoidImplosionToggle",
		Callback = function(Value)
			setImmunity(Controller, "VoidImplosion", Value)
		end,
	})

	createPrimaryToggle("Seamine", "SeamineImmune", {
		Name = "Seamine",
		CurrentValue = getFlag(Controller, "SeamineImmune"),
		Flag = "ImmunitySeamineToggle",
		Callback = function(Value)
			setImmunity(Controller, "Seamine", Value)
		end,
	})

	Tab:CreateSection("Entities - Mimics")

	createPrimaryToggle("Skinwalker", "SkinwalkerImmune", {
		Name = "Husk",
		CurrentValue = getFlag(Controller, "SkinwalkerImmune"),
		Flag = "ImmunitySkinwalkerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Skinwalker", Value)
		end,
	})

	Tab:CreateSection("Settings")

	Tab:CreateToggle({
		Name = "Use Shield / Barrier",
		CurrentValue = getFlag(Controller, "ShieldBaitEnabled"),
		Flag = "EntityShieldBaitToggle",
		Callback = function(Value)
			setShieldBaitEnabled(Controller, Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Barrier Chance",
		Range = { 0, 100 },
		Increment = 1,
		Suffix = "%",
		CurrentValue = tonumber(Controller.ShieldBaitChance) or 0,
		Flag = "EntityShieldBaitChanceSlider",
		Callback = function(Value)
			setShieldBaitChance(Controller, Value)
		end,
	})

	local StatusImmunity = getStatusImmunity(Controller)

	Tab:CreateDropdown({
		Name = "Immunity Effect",
		Options = { "Fire", "Panic", "Insanity", "Overtuned", "Bell Knockback" },
		CurrentOption = (StatusImmunity and StatusImmunity.GetActiveImmunities()) or {},
		MultipleOptions = true,
		Flag = "StatusImmunityDropdownV2",
		Callback = function(Options)
			local activeStatusImmunity = getStatusImmunity(Controller)
			if activeStatusImmunity and typeof(activeStatusImmunity.SetActiveImmunities) == "function" then
				activeStatusImmunity.SetActiveImmunities(Options)
			end
		end,
	})

	local activeController = resolveController(nil, Controller)
	if activeController and activeController.PrimaryImmunityChanged then
		local connection = activeController.PrimaryImmunityChanged.Event:Connect(schedulePrimaryImmunityUIUpdate)
		if Client and typeof(Client.ActiveConnections) == "table" then
			table.insert(Client.ActiveConnections, connection)
		end
	end
	schedulePrimaryImmunityUIUpdate()
end
