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

	Tab:CreateToggle({
		Name = "Bell",
		CurrentValue = getFlag(Controller, "BellImmune"),
		Flag = "ImmunityBellToggle",
		Callback = function(Value)
			setImmunity(Controller, "Bell", Value)
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
	if getFlag(Controller, "TelefraggerRedirect") then
		table.insert(currentTelefraggerOptions, "Auto-Dodge")
	end

	Tab:CreateDropdown({
		Name = "Telefragger Hack Mode",
		Options = { "Immunity", "Auto-Dodge" },
		CurrentOption = currentTelefraggerOptions,
		MultipleOptions = true,
		Flag = "TelefraggerHackDropdown",
		Callback = function(Options)
			local hasImmunity = false
			local hasAutoDodge = false
			for _, opt in ipairs(Options) do
				if opt == "Immunity" then
					hasImmunity = true
				elseif opt == "Auto-Dodge" then
					hasAutoDodge = true
				end
			end
			local activeController = resolveController(nil, Controller)
			if activeController then
				if typeof(activeController.SetImmunity) == "function" then
					activeController:SetImmunity("Telefragger", hasImmunity)
				end
				if typeof(activeController.SetTelefraggerRedirect) == "function" then
					activeController:SetTelefraggerRedirect(hasAutoDodge)
				end
			else
				warn("[NULLSCAPE] Entities controller is not ready; ignored Telefragger Hack Mode change")
			end
		end,
	})

	Tab:CreateSection("Entities - Client Side")

	Tab:CreateToggle({
		Name = "ICBM",
		CurrentValue = getFlag(Controller, "ICBMImmune"),
		Flag = "ImmunityICBMToggle",
		Callback = function(Value)
			setImmunity(Controller, "ICBM", Value)
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

	Tab:CreateToggle({
		Name = "Springer",
		CurrentValue = getFlag(Controller, "SpringerImmune"),
		Flag = "ImmunitySpringerToggle",
		Callback = function(Value)
			setImmunity(Controller, "Springer", Value)
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
		Options = { "Flesh", "Concussion", "Fire", "Panic", "Insanity", "Overtuned", "Springer Knockback", "Bell Knockback" },
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
