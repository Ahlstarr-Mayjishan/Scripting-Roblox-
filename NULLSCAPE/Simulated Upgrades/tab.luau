--!nocheck
-- [[
--  NULLSCAPE - Simulated Upgrades & Radar UI Tab
--  Dong vai tro tao tab "Mo phong Upgrades & Radar" tren giao dien Rayfield
-- ]]

local function makeLabelAutoResize(labelText)
	local LocalPlayer = game.Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
	if not PlayerGui then
		return
	end

	task.spawn(function()
		task.wait(0.2)
		for _, desc in ipairs(PlayerGui:GetDescendants()) do
			if desc:IsA("TextLabel") and string.find(desc.Text, labelText, 1, true) then
				local labelFrame = desc.Parent
				if labelFrame and labelFrame:IsA("Frame") then
					desc.AutomaticSize = Enum.AutomaticSize.Y
					desc.TextWrapped = true
					labelFrame.AutomaticSize = Enum.AutomaticSize.Y
				end
			end
		end
	end)
end

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
		CurrentValue = Controller.GiftMagnetBlocked == true and false or Controller.AutoCollectEnabled,
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
		local text =
			"Note: 0 range represents Infinite (Map-wide) pick up.\n - Gifts have a server-side limit of 30 studs.\n - Instrument has no limit (0 = infinite range)."
		Tab:CreateLabel(text)
		makeLabelAutoResize("Note: 0 range represents Infinite")
	end

	Tab:CreateSlider({
		Name = "Collection Gift Range",
		Range = { 5, 60 },
		CurrentValue = Controller.AutoCollectGiftRange or Controller.AutoCollectRange or 20,
		Increment = 5,
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
		Callback = function(_Keybind)
			Controller:TriggerMedalAction()
		end,
	})

	Tab:CreateSection("Defuse Kits")

	Tab:CreateDropdown({
		Name = "Tripmine Immunity (Bypass)",
		Options = { "Off", "I-Frames", "Immunity" },
		CurrentOption = Controller.TripmineBarrierEnabled and (Controller.TripmineBarrierMode or "I-Frames") or "Off",
		MultipleOptions = false,
		Flag = "TripmineBarrierModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetTripmineBarrierMode(selected)
		end,
	})

	Tab:CreateSlider({
		Name = "Delay Collect",
		Info = "Delay before collecting tripmines after arming immunity. Higher values simulate lag and give the server more time.",
		Range = { 0.03, 1 },
		CurrentValue = Controller.TripmineBarrierCollectDelay or 0.08,
		Increment = 0.01,
		ValueName = "s",
		Flag = "TripmineBarrierCollectDelaySlider",
		Callback = function(Value)
			Controller:SetTripmineBarrierCollectDelay(Value)
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
		Range = { 1, 5 },
		Increment = 0.1,
		CurrentValue = Controller.GraceWingsAirControlMultiplier or 1,
		Flag = "GraceWingsAirControlSlider",
		Suffix = "x",
		Callback = function(Value)
			Controller:SetGraceWingsAirControlMultiplier(Value)
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
		Info = "100 keeps the native JumpPad launch. Raise the same launch up to 300.",
		Range = { 100, 300 },
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

	local AirJumpOptions = { "DoubleJump", "PocketBell" }
	local AirJumpSelection
	local isSettingAirJumps = false

	Tab:CreateSection("Air Jumps")

	AirJumpSelection = Tab:CreateDropdown({
		Name = "Air Jumps",
		Info = "Multi-select native air-jump names.",
		Options = AirJumpOptions,
		CurrentOption = Controller.AirJumpSelections or {},
		MultipleOptions = true,
		Flag = "AirJumpSelectionsDropdown",
		Callback = function(SelectedOptions)
			if typeof(SelectedOptions) ~= "table" then
				SelectedOptions = {}
			end

			Controller:SetAirJumpSelections(SelectedOptions)

			if not isSettingAirJumps and AirJumpSelection then
				isSettingAirJumps = true
				pcall(function()
					AirJumpSelection:Set(SelectedOptions)
				end)
				isSettingAirJumps = false
			end
		end,
	})

	Tab:CreateToggle({
		Name = "Infinite Jump",
		Info = "Refills selected native jump charges before they can stay empty.",
		CurrentValue = Controller.InfiniteJumpEnabled == true,
		Flag = "InfiniteJumpToggle",
		Callback = function(Value)
			Controller:SetInfiniteJump(Value)
		end,
	})

	Tab:CreateSection("Helmet")

	Tab:CreateToggle({
		Name = "Enable Helmet",
		Info = "Spoofs Helmet so native bonk recovery keeps movement control and upward boost.",
		CurrentValue = Controller.HelmetEnabled or false,
		Flag = "HelmetToggle",
		Callback = function(Value)
			Controller:SetHelmet(Value)
		end,
	})

	Tab:CreateSection("Miniature Hourglass")

	Tab:CreateToggle({
		Name = "Enable Miniature Hourglass",
		Info = "Spoofs MiniatureHourglass so native class logic applies its cooldown and recharge effects.",
		CurrentValue = Controller.MiniatureHourglassEnabled or false,
		Flag = "MiniatureHourglassToggle",
		Callback = function(Value)
			Controller:SetMiniatureHourglass(Value)
		end,
	})

	Tab:CreateSection("Grappler Upgrades")

	Tab:CreateToggle({
		Name = "Simulate Ninja Belt",
		Info = "Makes Grappler native HasUpgrade checks treat Ninja Belt as owned without spoofing other classes.",
		CurrentValue = Controller.GrappleVirtualNinjaBelt or false,
		Flag = "GrappleVirtualNinjaBeltToggle",
		Callback = function(Value)
			Controller:SetGrappleVirtualNinjaBelt(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Simulate Shark Tail",
		Info = "Makes Grappler native HasUpgrade checks treat Shark Tail as owned without spoofing other classes.",
		CurrentValue = Controller.GrappleVirtualSharkTail or false,
		Flag = "GrappleVirtualSharkTailToggle",
		Callback = function(Value)
			Controller:SetGrappleVirtualSharkTail(Value)
		end,
	})
end
