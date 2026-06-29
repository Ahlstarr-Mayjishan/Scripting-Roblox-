--!nocheck
-- [[
--  NULLSCAPE - Simulated Upgrades & Radar UI Tab
--  Dong vai tro tao tab "Mo phong Upgrades & Radar" tren giao dien Rayfield
-- ]]

return function(Client, Controller)
	local Tab = Client.Window:CreateTab("Upgrade Simulations", 4483362458)

	Tab:CreateSection("Radar")

	Tab:CreateToggle({
		Name = "Radar Upgrade",
		CurrentValue = Controller.RadarEnabled,
		Flag = "RadarEnabledToggle",
		Callback = function(Value)
			Controller:SetRadarEnabled(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Radar Selections",
		Options = { "Gift", "Tripmine", "Cadance", "Altar", "Player", "Enemy" },
		CurrentOption = Controller.RadarFeatures or { "Gift", "Tripmine", "Cadance", "Altar", "Player", "Enemy" },
		MultipleOptions = true,
		Flag = "RadarFeaturesDropdown",
		Callback = function(Options)
			Controller:SetRadarFeatures(Options)
		end,
	})

	Tab:CreateSection("Gifts Magnet")

	Tab:CreateToggle({
		Name = "Enable Magnet Gifts",
		CurrentValue = Controller.AutoCollectEnabled,
		Flag = "AutoCollectGiftsToggle",
		Callback = function(Value)
			Controller:SetAutoCollectEnabled(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Collection Targets",
		Options = { "Gift/GoldenGift", "Instrument (Cadence)" },
		CurrentOption = Controller.AutoCollectTargets or { "Gift/GoldenGift", "Instrument (Cadence)" },
		MultipleOptions = true,
		Flag = "AutoCollectTargetsDropdown",
		Callback = function(Options)
			Controller:SetAutoCollectTargets(Options)
		end,
	})

	Tab:CreateDropdown({
		Name = "Collection Mode",
		Options = { "Legit", "Blatant" },
		CurrentOption = Controller.AutoCollectMode or "Legit",
		MultipleOptions = false,
		Flag = "AutoCollectModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetAutoCollectMode(selected)
		end,
	})

	if Tab.CreateLabel then
		Tab:CreateLabel(
			"Note: 0 range represents Infinite (Map-wide) pick up. \n - Gifts have a server-side limit of 30 studs. \n - Instrument has no limit (0 = infinite range)."
		)
	end

	Tab:CreateSlider({
		Name = "Collection Gift Range",
		Range = { 5, 30 },
		CurrentValue = Controller.AutoCollectGiftRange or Controller.AutoCollectRange or 20,
		Increment = 1,
		ValueName = "Studs",
		Flag = "AutoCollectRangeSlider",
		Callback = function(Value)
			Controller:SetAutoCollectGiftRange(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Collection Instrument Range",
		Range = { 0, 30 },
		CurrentValue = Controller.AutoCollectInstrumentRange or 0,
		Increment = 1,
		ValueName = "Studs (0=Inf)",
		Flag = "AutoCollectInstrumentRangeSlider",
		Callback = function(Value)
			Controller:SetAutoCollectInstrumentRange(Value)
		end,
	})

	Tab:CreateKeybind({
		Name = "Collect / Submit Medal Keybind",
		CurrentKeybind = Controller.CollectMedalKeybind or "V",
		HoldToTrigger = false,
		Flag = "CollectMedalKeybind",
		Callback = function(Keybind)
			Controller:TriggerMedalAction()
		end,
	})

	Tab:CreateSection("Defuse Kits")

	Tab:CreateToggle({
		Name = "Tripmine Immunity (Bypass)",
		CurrentValue = Controller.TripmineBarrierEnabled,
		Flag = "TripmineBarrierToggle",
		Callback = function(Value)
			Controller:SetTripmineBarrier(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Tripmine Bypass Mode",
		Info = "Blocker: tao vat can local de chan/repel truoc tripmine. Barrier: chi giu local iframes.",
		Options = { "Blocker", "Barrier" },
		CurrentOption = (Controller.TripmineMode == "Barrier" and "Barrier")
			or "Blocker",
		MultipleOptions = false,
		Flag = "TripmineModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetTripmineMode(selected)
		end,
	})

	Tab:CreateSection("Charger Assists")

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
		Info = "Auto se chi kich khi dang lao vao/cua so gan; Passthrough va PreDetonate la mode thu cong.",
		Options = { "Auto", "Passthrough", "PreDetonate" },
		CurrentOption = (Controller.ChargerTripmineMode == "Passthrough" and "Passthrough")
			or (Controller.ChargerTripmineMode == "PreDetonate" and "PreDetonate")
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
		Info = "Charger Passthrough/PreDetonate distance.",
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
	Tab:CreateToggle({
		Name = "Simulate Defuse Kit",
		CurrentValue = Controller.SimulateDefuseKit or false,
		Flag = "SimulateDefuseKitToggle",
		Callback = function(Value)
			Controller:SetSimulateDefuseKit(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Defuse Kit Stacks",
		Range = { 1, 5 },
		CurrentValue = Controller.DefuseKitStack or 3,
		Increment = 1,
		ValueName = "Stacks",
		Flag = "DefuseKitStackSlider",
		Callback = function(Value)
			Controller:SetDefuseKitStack(Value)
		end,
	})

	Tab:CreateSection("Matrix Tetrahedron")

	Tab:CreateToggle({
		Name = "Simulate Matrix Tetrahedron",
		Info = "Instant acceleration, removes slippery momentum, and reduces ice tiles sliding.",
		CurrentValue = Controller.MatrixTetrahedronEnabled,
		Flag = "MatrixTetrahedronToggle",
		Callback = function(Value)
			Controller:SetMatrixTetrahedron(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Momentum Reduction",
		Info = "Brake animation duration: 10% -> 90%, 50% -> 50%, >=60% bypass.",
		Range = { 10, 100 },
		Increment = 10,
		CurrentValue = math.clamp((Controller.MomentumReduction or 1.0) * 100, 10, 100),
		Flag = "MomentumReductionSlider",
		Suffix = "%",
		Callback = function(Value)
			Controller:SetMomentumReduction(Value / 100)
		end,
	})

	Tab:CreateSection("Grace Wings")

	Tab:CreateToggle({
		Name = "Enable Grace Wings",
		Info = "Master toggle. Turning it off restores movement hook and stops spoofing GraceWings.",
		CurrentValue = Controller.GraceWingsEnabled or false,
		Flag = "GraceWingsToggle",
		Callback = function(Value)
			Controller:SetGraceWings(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Air Control Multiplier",
		Range = { 1.1, 5 },
		Increment = 0.1,
		CurrentValue = Controller.GraceWingsAirControlMultiplier or 1.1,
		Flag = "GraceWingsAirControlSlider",
		Suffix = "x",
		Callback = function(Value)
			Controller:SetGraceWingsAirControlMultiplier(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Strong Air Control",
		Info = "Extra direct horizontal steering while falling. Keep off for closer GraceWings simulation.",
		CurrentValue = Controller.GraceWingsStrongAirControl or false,
		Flag = "GraceWingsStrongAirControlToggle",
		Callback = function(Value)
			Controller:SetGraceWingsStrongAirControl(Value)
		end,
	})

	Tab:CreateSection("Advanced Gravity Coil")

	Tab:CreateToggle({
		Name = "Enable Advanced Gravity Coil",
		Info = "Spoofs the upgrade and applies the JumpPower override from Ref logic.",
		CurrentValue = Controller.AdvancedGravityCoilEnabled or false,
		Flag = "AdvancedGravityCoilToggle",
		Callback = function(Value)
			Controller:SetAdvancedGravityCoil(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Jump Power",
		Info = "Ref minimum is 35 * 0.8 = 28. Raise it up to 100.",
		Range = { 28, 100 },
		Increment = 1,
		CurrentValue = Controller.AdvancedGravityCoilJumpPower or 28,
		Flag = "AdvancedGravityCoilJumpPowerSlider",
		Callback = function(Value)
			Controller:SetAdvancedGravityCoilJumpPower(Value)
		end,
	})

	Tab:CreateSection("Better Jump Pad")

	Tab:CreateToggle({
		Name = "Enable Better Jump Pad",
		Info = "Spoofs BetterJumpPad and raises JumpPad vertical launch.",
		CurrentValue = Controller.BetterJumpPadEnabled or false,
		Flag = "BetterJumpPadToggle",
		Callback = function(Value)
			Controller:SetBetterJumpPad(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "JumpPad Power",
		Info = "Ref JumpPad power is 100. Raise it up to 200.",
		Range = { 100, 200 },
		Increment = 1,
		CurrentValue = Controller.BetterJumpPadPower or 100,
		Flag = "BetterJumpPadPowerSlider",
		Callback = function(Value)
			Controller:SetBetterJumpPadPower(Value)
		end,
	})

	local SpeedBuffOptions = {
		"Swiftness Ring I (+10%)",
		"Swiftness Ring II (+10%)",
		"Swiftness Ring III (+10%)",
		"Adrenaline (+20%)",
		"Sport Shoes (+40%)",
	}

	local SpeedBuffSelection
	local isSettingSpeedBuffs = false

	Tab:CreateSection("Speed Buffs")

	SpeedBuffSelection = Tab:CreateDropdown({
		Name = "Buff Speed",
		Info = "Multi-select simulated speed upgrades. Bonuses stack together.",
		Options = SpeedBuffOptions,
		CurrentOption = Controller.SpeedBuffSelections or {},
		MultipleOptions = true,
		Flag = "SpeedBuffSelectionsDropdown",
		Callback = function(SelectedOptions)
			if typeof(SelectedOptions) ~= "table" then
				SelectedOptions = {}
			end

			Controller:SetSpeedBuffSelections(SelectedOptions)

			if not isSettingSpeedBuffs and SpeedBuffSelection then
				isSettingSpeedBuffs = true
				pcall(function()
					SpeedBuffSelection:Set(SelectedOptions)
				end)
				isSettingSpeedBuffs = false
			end
		end,
	})
end
