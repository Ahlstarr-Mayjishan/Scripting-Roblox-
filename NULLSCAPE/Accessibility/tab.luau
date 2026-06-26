local UserInputService = game:GetService("UserInputService")

return function(Client, Controller)
	local Tab = Client.Window:CreateTab("Accessibility", 4483362458)
	local adaptInputCaptureConnection = nil
	local adaptInputStatusLabel = nil

	local function disconnectAdaptCapture()
		if typeof(adaptInputCaptureConnection) == "RBXScriptConnection" then
			pcall(function()
				adaptInputCaptureConnection:Disconnect()
			end)
		end
		adaptInputCaptureConnection = nil
	end

	local function setAdaptInputStatus(text)
		if adaptInputStatusLabel and typeof(adaptInputStatusLabel.Set) == "function" then
			pcall(function()
				adaptInputStatusLabel:Set(text)
			end)
		end
	end

	Tab:CreateSection("Accessibility Features")

	Tab:CreateToggle({
		Name = "Auto jump - Springer",
		Info = "Automatically jumps over Springer shockwaves when the helper detects an incoming wave.",
		CurrentValue = Controller.SpringerAutoJumpEnabled,
		Flag = "SpringerAutoJumpToggle",
		Callback = function(Value)
			Controller:SetSpringerAutoJump(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Infinite Air Jump",
		Info = "Refills the native DoubleJump charge, preserving the game's animation and SFX.",
		CurrentValue = Controller.InfiniteAirJumpEnabled,
		Flag = "InfiniteAirJumpToggle",
		Callback = function(Value)
			Controller:SetInfiniteAirJump(Value)
		end,
	})

	Tab:CreateSection("Rail Assist")

	Tab:CreateToggle({
		Name = "Rail Assist Suite",
		Info = "Master switch for rail helpers. Required for Auto Rail and Rail Entry Speed to do anything.",
		CurrentValue = Controller.RailAssistSuiteEnabled or false,
		Flag = "RailAssistSuiteToggle",
		Callback = function(Value)
			Controller:SetRailAssistSuite(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Auto Rail",
		Info = "When you are close enough to a _RailPart and not using another movement state, it calls FollowRail for you.",
		CurrentValue = Controller.RailAutoEnabled or false,
		Flag = "RailAutoToggle",
		Callback = function(Value)
			Controller:SetRailAuto(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Rail Entry Speed",
		Info = "Applies once at the moment rail sliding starts. Higher values preserve/boost more horizontal speed.",
		Range = { 1.1, 5 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.RailSpeedMultiplier or 1.1,
		Flag = "RailSpeedMultiplierSlider",
		Callback = function(Value)
			Controller:SetRailSpeedMultiplier(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Auto Rail Delay",
		Info = "Cooldown between automatic rail snaps. Raise it if Auto Rail feels too eager or keeps re-grabbing rails.",
		Range = { 1.35, 3 },
		Increment = 0.15,
		Suffix = "s",
		CurrentValue = Controller.RailAutoDelay or 1.5,
		Flag = "RailAutoDelaySlider",
		Callback = function(Value)
			Controller:SetRailAutoDelay(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Auto Rail Capture Range",
		Info = "Maximum distance in studs before Auto Rail can grab a rail. It only catches rails in the front 180 degrees of your movement/look direction.",
		Range = { 1, 64 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = Controller.RailAutoCaptureRange or 4,
		Flag = "RailAutoCaptureRangeSlider",
		Callback = function(Value)
			Controller:SetRailAutoCaptureRange(Value)
		end,
	})

	Tab:CreateSection("Grapple Assist")

	Tab:CreateToggle({
		Name = "Grapple Assist Suite",
		Info = "Master switch for all Grapple hooks. Off restores Cast, Step, End, AltSpecialAction, and SharkTail hooks.",
		CurrentValue = Controller.GrappleAssistSuiteEnabled or false,
		Flag = "GrappleAssistSuiteToggle",
		Callback = function(Value)
			Controller:SetGrappleAssistSuite(Value)
		end,
	})

	if Tab.CreateLabel then
		adaptInputStatusLabel =
			Tab:CreateLabel("Grapple Adapt Input: " .. tostring(Controller.GrappleAdaptInputKey or "T"))
	end

	Tab:CreateButton({
		Name = "Rebind Grapple Adapt Input",
		Info = "Sets the Adapt Input key. Tap = one assisted recast. Hold = auto-drive while airborne. The key is saved to master_settings.json.",
		Callback = function()
			disconnectAdaptCapture()
			setAdaptInputStatus("Grapple Adapt Input: waiting for key...")

			if getgenv().Rayfield then
				getgenv().Rayfield:Notify({
					Title = "Accessibility Config",
					Content = "Press any keyboard key to bind Grapple Adapt Input. Press Esc to cancel. Current: "
						.. tostring(Controller.GrappleAdaptInputKey or "T"),
					Duration = 4,
				})
			end

			adaptInputCaptureConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then
					return
				end

				if input.KeyCode == Enum.KeyCode.Escape then
					disconnectAdaptCapture()
					setAdaptInputStatus("Grapple Adapt Input: " .. tostring(Controller.GrappleAdaptInputKey or "T"))
					if getgenv().Rayfield then
						getgenv().Rayfield:Notify({
							Title = "Accessibility Config",
							Content = "Grapple Adapt Input rebind cancelled",
							Duration = 2.5,
						})
					end
					return
				end

				local keyName = input.KeyCode.Name
				Controller:SetGrappleAdaptInputKey(keyName)
				disconnectAdaptCapture()
				setAdaptInputStatus("Grapple Adapt Input: " .. keyName)

				if getgenv().Rayfield then
					getgenv().Rayfield:Notify({
						Title = "Accessibility Config",
						Content = "Grapple Adapt Input bound to " .. keyName,
						Duration = 3,
					})
				end
			end)
		end,
	})

	if Client and type(Client.ActiveConnections) == "table" then
		table.insert(Client.ActiveConnections, {
			Disconnect = disconnectAdaptCapture,
		})
	end

	Tab:CreateDropdown({
		Name = "Grappler Stamina",
		Info = "Infinite Stamina refills the Grappler timer locally so long pulls do not drain the native grapple bar.",
		Options = { "Off", "Infinite Stamina" },
		CurrentOption = Controller.GrapplerStaminaMode or "Off",
		MultipleOptions = false,
		Flag = "GrapplerStaminaModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrapplerStaminaMode(selected)
		end,
	})

	Tab:CreateToggle({
		Name = "Grapple Aim Assist",
		Info = "Helps missed casts and can softly correct a valid cast when cursor, movement, and route confidence strongly agree on a better anchor.",
		CurrentValue = Controller.GrappleAimAssistEnabled or false,
		Flag = "GrappleAimAssistToggle",
		Callback = function(Value)
			Controller:SetGrappleAimAssist(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Aim Assist Strength",
		Info = "Controls how willing Grapple Aim Assist is to correct a usable but likely wrong cast. Light is subtle; Motor Accessibility is the most protective.",
		Options = { "Light", "Balanced", "Strong", "Motor Accessibility" },
		CurrentOption = Controller.GrappleAimAssistStrength or "Balanced",
		MultipleOptions = false,
		Flag = "GrappleAimAssistStrengthDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrappleAimAssistStrength(selected)
		end,
	})

	Tab:CreateToggle({
		Name = "Grapple Rescue Assist",
		Info = "While you are holding Grapple and falling fast, target priority changes toward rescue anchors. It does not run the emergency fall watchdog.",
		CurrentValue = Controller.GrappleRescueAssistEnabled or false,
		Flag = "GrappleRescueAssistToggle",
		Callback = function(Value)
			Controller:SetGrappleRescueAssist(Value)
		end,
	})

	Tab:CreateSection("Emergency Fall Protection")

	Tab:CreateToggle({
		Name = "Emergency Fall Protection",
		Info = "Separate safety system for map falls. It predicts your path, checks for ground below, then fires a rescue only when speed/fall danger and unsafe path agree.",
		CurrentValue = Controller.GrappleEmergencyProtectionEnabled or false,
		Flag = "GrappleEmergencyProtectionToggle",
		Callback = function(Value)
			Controller:SetGrappleEmergencyProtection(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Void Rescue",
		Info = "Immediately escalates Emergency Fall Protection near KillVoid/FallenPartsDestroyHeight. Uses ClassID so it only drives Grappler behavior for now.",
		CurrentValue = Controller.GrappleVoidRescueEnabled ~= false,
		Flag = "GrappleVoidRescueToggle",
		Callback = function(Value)
			Controller:SetGrappleVoidRescue(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Emergency Rescue Mode",
		Info = "Manual needs repeated panic Grapple inputs. Smart Auto reads fall path, input control, speed, and rescue target quality. Automatic uses the same checks with a lower threshold.",
		Options = { "Manual", "Smart Auto", "Automatic" },
		CurrentOption = Controller.GrappleEmergencyProtectionMode or "Manual",
		MultipleOptions = false,
		Flag = "GrappleEmergencyProtectionModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrappleEmergencyProtectionMode(selected)
		end,
	})

	Tab:CreateSlider({
		Name = "Emergency Speed Threshold",
		Info = "Horizontal speed required before emergency protection can react. Higher = fewer false saves during normal fast movement.",
		Range = { 150, 320 },
		Increment = 5,
		Suffix = " studs/s",
		CurrentValue = Controller.GrappleEmergencySpeedThreshold or 220,
		Flag = "GrappleEmergencySpeedThresholdSlider",
		Callback = function(Value)
			Controller:SetGrappleEmergencySpeedThreshold(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Emergency Fall Threshold",
		Info = "Downward speed required before emergency protection can react. Higher = lets normal falling happen more often.",
		Range = { 80, 220 },
		Increment = 5,
		Suffix = " studs/s",
		CurrentValue = Controller.GrappleEmergencyFallThreshold or 125,
		Flag = "GrappleEmergencyFallThresholdSlider",
		Callback = function(Value)
			Controller:SetGrappleEmergencyFallThreshold(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Grapple Anti Bonk",
		Info = "Suppresses Grapple-related DiveBonk stun during active pulls/reels and a short grace window after release.",
		CurrentValue = Controller.GrappleAntiBonkEnabled or false,
		Flag = "GrappleAntiBonkToggle",
		Callback = function(Value)
			Controller:SetGrappleAntiBonk(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Grapple Smart Reel",
		Info = "Adds helper behavior for NinjaBelt reel. It only works when Movement:HasUpgrade('NinjaBelt') is true.",
		CurrentValue = Controller.GrappleSmartReelEnabled or false,
		Flag = "GrappleSmartReelToggle",
		Callback = function(Value)
			Controller:SetGrappleSmartReel(Value)
		end,
	})

	if Tab.CreateLabel then
		Tab:CreateLabel(
			"Smart Reel: requires real NinjaBelt. \n - Manual: uses p2 sub-ability to start reel while already grappled; \n - Automatic: starts reel when airborne, attached, path-safe, and off cooldown."
		)
	end

	Tab:CreateDropdown({
		Name = "Smart Reel Mode",
		Info = "Manual keeps reel on p2/sub-ability. Automatic reels while airborne, already grappled, path-safe, and NinjaBelt is actually owned.",
		Options = { "Manual", "Automatic" },
		CurrentOption = Controller.GrappleSmartReelMode or "Manual",
		MultipleOptions = false,
		Flag = "GrappleSmartReelModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrappleSmartReelMode(selected)
		end,
	})

	Tab:CreateToggle({
		Name = "SharkTail Helper",
		Info = "Adds helper behavior for SharkTail during its allowed window. It only works when NinjaBelt and SharkTail are both real upgrades.",
		CurrentValue = Controller.GrappleSharkTailHelperEnabled or false,
		Flag = "GrappleSharkTailHelperToggle",
		Callback = function(Value)
			Controller:SetGrappleSharkTailHelper(Value)
		end,
	})

	if Tab.CreateLabel then
		Tab:CreateLabel(
			"SharkTail Helper: requires NinjaBelt + SharkTail. \n - Manual: uses p2 when the SharkTail window is safe; \n - outside that window it can fallback to Smart Reel. \n - Automatic: uses score/timing instead of firing every frame."
		)
	end

	Tab:CreateDropdown({
		Name = "SharkTail Mode",
		Info = "Manual uses p2/sub-ability during allowSharkTail after a safety score. Automatic fires only when SharkTail scores better for flow, rescue, or vector change.",
		Options = { "Manual", "Automatic" },
		CurrentOption = Controller.GrappleSharkTailMode or "Manual",
		MultipleOptions = false,
		Flag = "GrappleSharkTailModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrappleSharkTailMode(selected)
		end,
	})

	Tab:CreateDropdown({
		Name = "SharkTail Style",
		Info = "Controls how picky automatic SharkTail is. Balanced is the pro-like default; Emergency Only only reacts during dangerous fall/momentum states.",
		Options = { "Conservative", "Balanced", "Aggressive", "Emergency Only" },
		CurrentOption = Controller.GrappleSharkTailStyle or "Balanced",
		MultipleOptions = false,
		Flag = "GrappleSharkTailStyleDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrappleSharkTailStyle(selected)
		end,
	})

	Tab:CreateToggle({
		Name = "Grapple Momentum Guard",
		Info = "Soft clamps extreme horizontal velocity for a short window after grapple/reel so chained momentum is easier to control.",
		CurrentValue = Controller.GrappleMomentumGuardEnabled or false,
		Flag = "GrappleMomentumGuardToggle",
		Callback = function(Value)
			Controller:SetGrappleMomentumGuard(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "JumpPad Uses Bypass",
		Info = "Keeps Grapple JumpPads reusable/queryable for repeated pulls. Useful for testing repeated JumpPad grapples.",
		CurrentValue = Controller.GrappleJumpPadUsesBypassEnabled or false,
		Flag = "GrappleJumpPadUsesBypassToggle",
		Callback = function(Value)
			Controller:SetGrappleJumpPadUsesBypass(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Air Control",
		Info = "Multiplies the extra air steering force while actively grappling. It does not create a new grapple target.",
		Range = { 1.1, 5 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.GrappleAirControlMultiplier or 1.1,
		Flag = "GrappleAirControlMultiplierSlider",
		Callback = function(Value)
			Controller:SetGrappleAirControlMultiplier(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Reel Pull",
		Info = "Multiplies velocity gained from reel-style pulls. Affects special pull targets and NinjaBelt reel behavior.",
		Range = { 1.1, 5 },
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
		Range = { 1.1, 5 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.GrappleSharkTailPullMultiplier or 1.1,
		Flag = "GrappleSharkTailPullMultiplierSlider",
		Callback = function(Value)
			Controller:SetGrappleSharkTailPullMultiplier(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Grapple Target Priority",
		Info = "Preferred target type when several visible safe targets are valid. Emergency protection can temporarily force TriaOrb priority.",
		Options = { "GrapplePoint", "JumpPad", "Bell", "TriaOrb" },
		CurrentOption = Controller.GrappleAimAssistTargetPriority or "GrapplePoint",
		MultipleOptions = false,
		Flag = "GrappleAimAssistTargetPriorityDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrappleAimAssistTargetPriority(selected)
		end,
	})

	Tab:CreateDropdown({
		Name = "Grapple Range Priority",
		Info = "How valid targets are ranked: nearest, farthest, closest to cursor, or random among valid choices.",
		Options = { "Nearest", "Farthest", "Closest To Cursor", "Random" },
		CurrentOption = Controller.GrappleAimAssistRangePriority or "Nearest",
		MultipleOptions = false,
		Flag = "GrappleAimAssistRangePriorityDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetGrappleAimAssistRangePriority(selected)
		end,
	})
end
