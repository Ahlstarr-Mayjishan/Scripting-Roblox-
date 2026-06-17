return function(Client, Controller)
	local Tab = Client.Window:CreateTab("Entities", 4483362458)

	Tab:CreateSection("Entities List - Touch Immunity")

	Tab:CreateToggle({
		Name = "Baby",
		CurrentValue = Controller.BabyImmune,
		Flag = "ImmunityBabyToggle",
		Callback = function(Value)
			Controller:SetImmunity("Baby", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Bell",
		CurrentValue = Controller.BellImmune,
		Flag = "ImmunityBellToggle",
		Callback = function(Value)
			Controller:SetImmunity("Bell", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Flesh",
		CurrentValue = Controller.FleshImmune,
		Flag = "ImmunityFleshToggle",
		Callback = function(Value)
			Controller:SetImmunity("Flesh", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Mart",
		CurrentValue = Controller.MartImmune,
		Flag = "ImmunityMartToggle",
		Callback = function(Value)
			Controller:SetImmunity("Mart", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Telefragger",
		CurrentValue = Controller.TelefraggerImmune,
		Flag = "ImmunityTelefraggerToggle",
		Callback = function(Value)
			Controller:SetImmunity("Telefragger", Value)
		end,
	})

	Tab:CreateSection("Entities - Client Side")

	Tab:CreateToggle({
		Name = "ICBM",
		CurrentValue = Controller.ICBMImmune,
		Flag = "ImmunityICBMToggle",
		Callback = function(Value)
			Controller:SetImmunity("ICBM", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Guardian",
		CurrentValue = Controller.GuardianImmune,
		Flag = "ImmunityGuardianToggle",
		Callback = function(Value)
			Controller:SetImmunity("Guardian", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Operator",
		CurrentValue = Controller.OperatorImmune,
		Flag = "ImmunityOperatorToggle",
		Callback = function(Value)
			Controller:SetImmunity("Operator", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Springer",
		CurrentValue = Controller.SpringerImmune,
		Flag = "ImmunitySpringerToggle",
		Callback = function(Value)
			Controller:SetImmunity("Springer", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Cadence",
		CurrentValue = Controller.CadenceImmune,
		Flag = "ImmunityCadenceToggle",
		Callback = function(Value)
			Controller:SetImmunity("Cadence", Value)
		end,
	})

	Tab:CreateSection("Entities - Special Immunity")

	Tab:CreateToggle({
		Name = "Kolona",
		CurrentValue = Controller.KolonaImmune,
		Flag = "ImmunityKolonaToggle",
		Callback = function(Value)
			Controller:SetImmunity("Kolona", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Oblivion",
		CurrentValue = Controller.OblivionImmune,
		Flag = "ImmunityOblivionToggle",
		Callback = function(Value)
			Controller:SetImmunity("Oblivion", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "ShadowBaby",
		CurrentValue = Controller.ShadowBabyImmune,
		Flag = "ImmunityShadowBabyToggle",
		Callback = function(Value)
			Controller:SetImmunity("ShadowBaby", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Quartz",
		CurrentValue = Controller.QuartzImmune,
		Flag = "ImmunityQuartzToggle",
		Callback = function(Value)
			Controller:SetImmunity("Quartz", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Sigil",
		CurrentValue = Controller.SigilImmune,
		Flag = "ImmunitySigilToggle",
		Callback = function(Value)
			Controller:SetImmunity("Sigil", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Slicer",
		CurrentValue = Controller.SlicerImmune,
		Flag = "ImmunitySlicerToggle",
		Callback = function(Value)
			Controller:SetImmunity("Slicer", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Voidbreaker",
		CurrentValue = Controller.VoidbreakerImmune,
		Flag = "ImmunityVoidbreakerToggle",
		Callback = function(Value)
			Controller:SetImmunity("Voidbreaker", Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Razorbloom Phase",
		CurrentValue = Controller.RazorbloomImmune,
		Flag = "ImmunityRazorbloomToggle",
		Callback = function(Value)
			Controller:SetImmunity("Razorbloom", Value)
		end,
	})

	Tab:CreateSection("Entities - Mimics")

	Tab:CreateToggle({
		Name = "Husk",
		CurrentValue = Controller.SkinwalkerImmune,
		Flag = "ImmunitySkinwalkerToggle",
		Callback = function(Value)
			Controller:SetImmunity("Skinwalker", Value)
		end,
	})

	Tab:CreateSection("Settings")

	Tab:CreateDropdown({
		Name = "Immunity Mode",
		Options = { "Legit", "Blatant" },
		CurrentOption = Controller.SpringerImmunityMode or "Legit",
		MultipleOptions = false,
		Flag = "SpringerImmunityModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetSpringerImmunityMode(selected)
		end,
	})
end
