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

local function setImmunity(Controller, entityName, value)
	local activeController = resolveController(nil, Controller)
	if activeController and typeof(activeController.SetImmunity) == "function" then
		activeController:SetImmunity(entityName, value)
	else
		warn("[NULLSCAPE] Entities controller is not ready; ignored immunity toggle for " .. tostring(entityName))
	end
end

return function(Client, Controller)
	Controller = resolveController(Client, Controller)
	if not Controller then
		warn("[NULLSCAPE] Entities tab loaded without controller; toggles will retry on use")
		Controller = {}
	end

	local Tab = Client.Window:CreateTab("Immunity", 4483362458)

	Tab:CreateSection("Entities List - Touch Immunity")

	Tab:CreateToggle({
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
		table.insert(currentBellOptions, "Knockback (Curse)")
	end
	if getFlag(Controller, "BellBlindnessImmune") then
		table.insert(currentBellOptions, "Ring screen blindness")
	end

	Tab:CreateDropdown({
		Name = "Bell Hack Mode",
		Options = { "Immunity", "Knockback (Curse)", "Ring screen blindness" },
		CurrentOption = currentBellOptions,
		MultipleOptions = true,
		Flag = "BellHackDropdown",
		Callback = function(Options)
			local hasImmunity = false
			local hasCurseImmune = false
			local hasBlindnessImmune = false
			for _, opt in ipairs(Options) do
				if opt == "Immunity" then
					hasImmunity = true
				elseif opt == "Knockback (Curse)" then
					hasCurseImmune = true
				elseif opt == "Ring screen blindness" then
					hasBlindnessImmune = true
				end
			end
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
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Bell Hack Mode change")
			end
		end,
	})

	Tab:CreateToggle({
		Name = "Flesh",
		CurrentValue = getFlag(Controller, "FleshImmune"),
		Flag = "ImmunityFleshToggle",
		Callback = function(Value)
			setImmunity(Controller, "Flesh", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Mart",
		CurrentValue = getFlag(Controller, "MartImmune"),
		Flag = "ImmunityMartToggle",
		Callback = function(Value)
			setImmunity(Controller, "Mart", Value)
		end,
	})

	local currentTelefraggerOptions = {}
	if getFlag(Controller, "TelefraggerImmune") then
		table.insert(currentTelefraggerOptions, "Immunity")
	end
	if getFlag(Controller, "TelefraggerAutoDodge") then
		table.insert(currentTelefraggerOptions, "Auto-Dodge")
	end
	if getFlag(Controller, "TelefraggerBackTrick") then
		table.insert(currentTelefraggerOptions, "BackTrick")
	end

	Tab:CreateDropdown({
		Name = "Telefragger Hack Mode",
		Options = { "Immunity", "Auto-Dodge", "BackTrick" },
		CurrentOption = currentTelefraggerOptions,
		MultipleOptions = true,
		Flag = "TelefraggerHackDropdown",
		Callback = function(Options)
			local hasImmunity = false
			local hasAutoDodge = false
			local hasBackTrick = false
			for _, opt in ipairs(Options) do
				if opt == "Immunity" then
					hasImmunity = true
				elseif opt == "Auto-Dodge" then
					hasAutoDodge = true
				elseif opt == "BackTrick" then
					hasBackTrick = true
				end
			end
			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("Telefragger", hasImmunity)
				end
				if typeof(activeController.SetTelefraggerAutoDodge) == "function" then
					activeController:SetTelefraggerAutoDodge(hasAutoDodge)
				end
				if typeof(activeController.SetTelefraggerBackTrick) == "function" then
					activeController:SetTelefraggerBackTrick(hasBackTrick)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Telefragger Hack Mode change")
			end
		end,
	})

	Tab:CreateSection("Entities - Client Side")

	local currentICBMOptions = {}
	if getFlag(Controller, "ICBMImmune") then
		table.insert(currentICBMOptions, "Immunity")
	end
	if getFlag(Controller, "ICBMBurnImmune") then
		table.insert(currentICBMOptions, "Burn effect (Curse)")
	end

	Tab:CreateDropdown({
		Name = "ICBM Hack Mode",
		Options = { "Immunity", "Burn effect (Curse)" },
		CurrentOption = currentICBMOptions,
		MultipleOptions = true,
		Flag = "ICBMHackDropdown",
		Callback = function(Options)
			local hasImmunity = false
			local hasBurnImmunity = false
			for _, opt in ipairs(Options) do
				if opt == "Immunity" then
					hasImmunity = true
				elseif opt == "Burn effect (Curse)" then
					hasBurnImmunity = true
				end
			end
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

	Tab:CreateToggle({
		Name = "Guardian",
		CurrentValue = getFlag(Controller, "GuardianImmune"),
		Flag = "ImmunityGuardianToggle",
		Callback = function(Value)
			setImmunity(Controller, "Guardian", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Operator",
		CurrentValue = getFlag(Controller, "OperatorImmune"),
		Flag = "ImmunityOperatorToggle",
		Callback = function(Value)
			setImmunity(Controller, "Operator", Value)
		end,
	})

	local currentSpringerOptions = {}
	if getFlag(Controller, "SpringerImmune") then
		table.insert(currentSpringerOptions, "Immunity")
	end
	if getFlag(Controller, "SpringerKnockbackImmune") then
		table.insert(currentSpringerOptions, "Springer Knockback")
	end

	Tab:CreateDropdown({
		Name = "Springer Hack Mode",
		Options = { "Immunity", "Springer Knockback" },
		CurrentOption = currentSpringerOptions,
		MultipleOptions = true,
		Flag = "SpringerHackDropdown",
		Callback = function(Options)
			local hasImmunity = false
			local hasKnockbackImmune = false
			for _, opt in ipairs(Options) do
				if opt == "Immunity" then
					hasImmunity = true
				elseif opt == "Springer Knockback" then
					hasKnockbackImmune = true
				end
			end

			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("Springer", hasImmunity)
				end
				if typeof(activeController.SetSpringerKnockbackImmune) == "function" then
					activeController:SetSpringerKnockbackImmune(hasKnockbackImmune)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Springer Hack Mode change")
			end
		end,
	})

	Tab:CreateToggle({
		Name = "Cadence",
		CurrentValue = getFlag(Controller, "CadenceImmune"),
		Flag = "ImmunityCadenceToggle",
		Callback = function(Value)
			setImmunity(Controller, "Cadence", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Celestial",
		CurrentValue = getFlag(Controller, "CelestialImmune"),
		Flag = "ImmunityCelestialToggle",
		Callback = function(Value)
			setImmunity(Controller, "Celestial", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Scrapmaw",
		CurrentValue = getFlag(Controller, "ScrapmawImmune"),
		Flag = "ImmunityScrapmawToggle",
		Callback = function(Value)
			setImmunity(Controller, "Scrapmaw", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Catalyst",
		CurrentValue = getFlag(Controller, "CatalystImmune"),
		Flag = "ImmunityCatalystToggle",
		Callback = function(Value)
			setImmunity(Controller, "Catalyst", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "nilEnemy",
		CurrentValue = getFlag(Controller, "nilEnemyImmune"),
		Flag = "ImmunitynilEnemyToggle",
		Callback = function(Value)
			setImmunity(Controller, "nilEnemy", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "nilMirage",
		CurrentValue = getFlag(Controller, "nilMirageImmune"),
		Flag = "ImmunitynilMirageToggle",
		Callback = function(Value)
			setImmunity(Controller, "nilMirage", Value)
		end,
	})

	Tab:CreateSection("Entities - Special Immunity")

	Tab:CreateToggle({
		Name = "Kolona",
		CurrentValue = getFlag(Controller, "KolonaImmune"),
		Flag = "ImmunityKolonaToggle",
		Callback = function(Value)
			setImmunity(Controller, "Kolona", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Oblivion",
		CurrentValue = getFlag(Controller, "OblivionImmune"),
		Flag = "ImmunityOblivionToggle",
		Callback = function(Value)
			setImmunity(Controller, "Oblivion", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "ShadowBaby",
		CurrentValue = getFlag(Controller, "ShadowBabyImmune"),
		Flag = "ImmunityShadowBabyToggle",
		Callback = function(Value)
			setImmunity(Controller, "ShadowBaby", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Quartz",
		CurrentValue = getFlag(Controller, "QuartzImmune"),
		Flag = "ImmunityQuartzToggle",
		Callback = function(Value)
			setImmunity(Controller, "Quartz", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Sigil",
		CurrentValue = getFlag(Controller, "SigilImmune"),
		Flag = "ImmunitySigilToggle",
		Callback = function(Value)
			setImmunity(Controller, "Sigil", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Slicer",
		CurrentValue = getFlag(Controller, "SlicerImmune"),
		Flag = "ImmunitySlicerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Slicer", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Voidbreaker",
		CurrentValue = getFlag(Controller, "VoidbreakerImmune"),
		Flag = "ImmunityVoidbreakerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Voidbreaker", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Razorbloom Phase",
		CurrentValue = getFlag(Controller, "RazorbloomImmune"),
		Flag = "ImmunityRazorbloomToggle",
		Callback = function(Value)
			setImmunity(Controller, "Razorbloom", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Void Implosion",
		CurrentValue = getFlag(Controller, "VoidImplosionImmune"),
		Flag = "ImmunityVoidImplosionToggle",
		Callback = function(Value)
			setImmunity(Controller, "VoidImplosion", Value)
		end,
	})

	Tab:CreateSection("Entities - Mimics")

	Tab:CreateToggle({
		Name = "Husk",
		CurrentValue = getFlag(Controller, "SkinwalkerImmune"),
		Flag = "ImmunitySkinwalkerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Skinwalker", Value)
		end,
	})

	Tab:CreateSection("Settings")

	local StatusImmunity = getgenv().loadModule("NULLSCAPE/Entities/StatusImmunity.luau")

	Tab:CreateDropdown({
		Name = "Immunity Effect",
		Options = { "Flesh", "Concussion", "Fire", "Panic", "Insanity", "Overtuned", "Bell Knockback" },
		CurrentOption = (StatusImmunity and StatusImmunity.GetActiveImmunities()) or {},
		MultipleOptions = true,
		Flag = "StatusImmunityDropdown",
		Callback = function(Options)
			if StatusImmunity and typeof(StatusImmunity.SetActiveImmunities) == "function" then
				StatusImmunity.SetActiveImmunities(Options)
			end
		end,
	})
end
