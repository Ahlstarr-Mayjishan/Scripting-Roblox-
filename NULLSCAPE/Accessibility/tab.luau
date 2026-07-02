local DEFAULTS = {
	SpringerAutoJumpEnabled = false,
	InfiniteAirJumpEnabled = false,
	AntiBonkEnabled = false,
	IgnoreFakeCountEnabled = false,
	BeaconMirageIdentifierEnabled = false,
	RailAssistSuiteEnabled = false,
	RailAutoEnabled = false,
	RailSpeedMultiplier = 1.1,
	RailAutoDelay = 1.5,
	RailAutoCaptureRange = 4,
	MomentumMode = "Off",
	MomentumMaxHorizontalSpeed = 500,
	MomentumMaxVerticalSpeed = 500,
	MomentumDecay = 4,
	MomentumSoftReduction = 0.35,
	GrappleAssistEnabled = false,
	GrappleAssistStrength = 1,
	GrappleAssistCaptureAngle = 45,
	GrappleAssistRange = 500,
	GrappleAssistConfidenceGateEnabled = true,
	GrappleAssistMinConfidenceScore = -35,
	GrappleAssistConfidenceMargin = 5,
	GrappleAssistBiomeTuningEnabled = true,
	GrappleAssistFailFeedbackEnabled = true,
	GrappleAssistSpecialPointPriority = true,
	GrappleAssistSecondaryCastEnabled = false,
	GrappleAssistSecondaryCastKeybind = "Q",
	GrappleAnchorPriorityGrapplePoint = 900,
	GrappleAnchorPriorityJumpPad = 1000,
	GrappleAnchorPriorityTriaOrb = 850,
	GrappleAnchorPriorityBell = 800,
	GrappleAssistTerrainPriority = 100,
	GrappleVoidProtectionEnabled = false,
	GrappleVoidProtectionHeight = 24,
	GrappleVoidProtectionFallSpeed = 85,
	GrappleVoidRescueEnabled = false,
	GrappleVoidRescueAutoReel = true,
	GrappleVoidRescueAutoSharkTail = true,
	GrappleVoidRescueHeight = 45,
	GrappleVoidRescueReelHoldTime = 0.12,
	GrappleReelSaverEnabled = false,
	GrappleReelSaverKeybind = "E",
	GrappleReelSaverSideRange = 26,
	GrappleReelSaverMinHeight = 5,
	GrappleReelSaverMaxHeight = 14,
	GrappleReelSaverClearance = 5,
	GrappleReelSaverLandingRadius = 2.75,
	GrappleReelSaverReelHoldTime = 0.16,
	GrapplerStaminaMode = "Off",
	StaminaMode = "Off",
	GrapplerStaminaRecoverySpeed = 1,
}

local function resolveController(Client, Controller)
	if typeof(Controller) == "table" and rawget(Controller, "__AccessibilityProxy") ~= true then
		return Controller
	end

	if Client and typeof(Client.Modules) == "table" and typeof(Client.Modules.AccessibilityController) == "table" then
		return Client.Modules.AccessibilityController
	end

	local globals = getgenv and getgenv()._NULLSCAPE_Globals
	if globals and typeof(globals.activeAccessibilityController) == "table" then
		return globals.activeAccessibilityController
	end

	if getgenv and typeof(getgenv().loadModule) == "function" then
		local success, loadedController = pcall(function()
			return getgenv().loadModule("NULLSCAPE/Accessibility/controller.luau")
		end)
		if success and typeof(loadedController) == "table" then
			if Client and typeof(Client.Modules) == "table" then
				Client.Modules.AccessibilityController = loadedController
			end
			return loadedController
		end
	end

	return nil
end

local function createControllerProxy(Client, Controller)
	return setmetatable({ __AccessibilityProxy = true }, {
		__index = function(_, key)
			local activeController = resolveController(Client, Controller)
			if activeController then
				local value = activeController[key]
				if value ~= nil then
					if typeof(value) == "function" and type(key) == "string" then
						return function(_, ...)
							local latestController = resolveController(Client, Controller) or activeController
							local latestMethod = latestController and latestController[key]
							if typeof(latestMethod) == "function" then
								return latestMethod(latestController, ...)
							end
						end
					end
					return value
				end
			end

			if type(key) == "string" and (string.sub(key, 1, 3) == "Set" or string.sub(key, 1, 3) == "Get") then
				return function(_, ...)
					local latestController = resolveController(Client, Controller)
					local latestMethod = latestController and latestController[key]
					if typeof(latestMethod) == "function" then
						return latestMethod(latestController, ...)
					end
					if string.sub(key, 1, 3) == "Set" then
						warn("[NULLSCAPE] Accessibility controller is not ready; ignored " .. tostring(key))
					end
					return nil
				end
			end

			return DEFAULTS[key]
		end,
	})
end

local function getSelectedGrapplerTechniques(Controller)
	local selected = {}

	if Controller.GrappleVoidRescueEnabled == true then
		table.insert(selected, "SharkVoid")
	end

	if Controller.GrappleReelSaverEnabled == true then
		table.insert(selected, "Reel Saver")
	end

	return selected
end

return function(Client, Controller)
	Controller = createControllerProxy(Client, Controller)
	local Tab = Client.Window:CreateTab("Accessibility", 4483362458)

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

	local infiniteAirJumpStatusLabel = nil
	if Tab.CreateLabel then
		infiniteAirJumpStatusLabel = Tab:CreateLabel(
			"Infinite Air Jump Status: " .. tostring(Controller:GetInfiniteAirJumpStatus() or "pending")
		)
		task.spawn(function()
			while infiniteAirJumpStatusLabel and Client and not Client.Destroyed do
				task.wait(1)
				if infiniteAirJumpStatusLabel and typeof(infiniteAirJumpStatusLabel.Set) == "function" then
					pcall(function()
						infiniteAirJumpStatusLabel:Set(
							"Infinite Air Jump Status: " .. tostring(Controller:GetInfiniteAirJumpStatus() or "pending")
						)
					end)
				end
			end
		end)
	end

	Tab:CreateToggle({
		Name = "Anti Bonk",
		Info = "Suppresses all DiveBonk/stun states from diving or sliding into obstacles completely.",
		CurrentValue = Controller.AntiBonkEnabled or false,
		Flag = "AntiBonkToggle",
		Callback = function(Value)
			Controller:SetAntiBonk(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Ignore Fake Count",
		Info = "Shows the real gift/pylon count when the Fake Count curse tries to randomize the counter.",
		CurrentValue = Controller.IgnoreFakeCountEnabled or false,
		Flag = "IgnoreFakeCountToggle",
		Callback = function(Value)
			Controller:SetIgnoreFakeCount(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Beacon Mirage Identifier",
		Info = "Marks the real workspace Beacon and fades/blocks Beacon Mirage or Beacon Feint decoys.",
		CurrentValue = Controller.BeaconMirageIdentifierEnabled or false,
		Flag = "BeaconMirageIdentifierToggle",
		Callback = function(Value)
			Controller:SetBeaconMirageIdentifier(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = " Stamina Mode",
		Info = "Infinite Stamina refills native class stamina/timer resources for classes that expose a compatible stamina bar.",
		Options = { "Manual", "Infinite Stamina" },
		CurrentOption = Controller.StaminaMode or Controller.GrapplerStaminaMode or "Off",
		MultipleOptions = false,
		Flag = "GrapplerStaminaModeDropdown",
		Callback = function(Option)
			local selected = Option
			if typeof(Option) == "table" then
				selected = Option[1]
			end
			Controller:SetStaminaMode(selected)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Recovery Speed",
		Info = "Multiplies the natural stamina/time recovery speed of the Grappler when not active.",
		Range = { 1, 10 },
		Increment = 0.5,
		Suffix = "x",
		CurrentValue = Controller.GrapplerStaminaRecoverySpeed or 1,
		Flag = "GrapplerStaminaRecoverySpeedSlider",
		Callback = function(Value)
			Controller:SetGrapplerStaminaRecoverySpeed(Value)
		end,
	})

	Tab:CreateSection("Momentum")

	Tab:CreateDropdown({
		Name = "Momentum",
		Info = "Controls excessive horizontal speed while preserving vertical lift.",
		Options = { "Off", "Decay", "Soft Cap" },
		CurrentOption = Controller.MomentumMode or "Off",
		MultipleOptions = false,
		Flag = "MomentumModeDropdown",
		Callback = function(Option)
			Controller:SetMomentumMode(Option)
		end,
	})

	Tab:CreateSlider({
		Name = "Momentum Decay",
		Info = "Decay strength used by Decay mode after horizontal speed passes the guard threshold.",
		Range = { 0.5, 12 },
		Increment = 0.5,
		Suffix = "x",
		CurrentValue = Controller.MomentumDecay or 4,
		Flag = "MomentumDecaySlider",
		Callback = function(Value)
			Controller:SetMomentumDecay(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Momentum Soft Reduction",
		Info = "Soft Cap reduction amount applied to excess horizontal speed each frame.",
		Range = { 0.05, 1 },
		Increment = 0.05,
		Suffix = "x",
		CurrentValue = Controller.MomentumSoftReduction or 0.35,
		Flag = "MomentumSoftReductionSlider",
		Callback = function(Value)
			Controller:SetMomentumSoftReduction(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Momentum Horizontal Limit",
		Info = "Horizontal speed threshold before Momentum Guard starts reducing excess movement.",
		Range = { 100, 500 },
		Increment = 10,
		Suffix = " vel",
		CurrentValue = Controller.MomentumMaxHorizontalSpeed or 500,
		Flag = "MomentumMaxHorizontalSpeedSlider",
		Callback = function(Value)
			Controller:SetMomentumMaxHorizontalSpeed(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Momentum Vertical Limit",
		Info = "Vertical speed threshold before Momentum Guard starts reducing excess upward or downward velocity.",
		Range = { 100, 500 },
		Increment = 10,
		Suffix = " vel",
		CurrentValue = Controller.MomentumMaxVerticalSpeed or 500,
		Flag = "MomentumMaxVerticalSpeedSlider",
		Callback = function(Value)
			Controller:SetMomentumMaxVerticalSpeed(Value)
		end,
	})

	Tab:CreateSection("Grappler Assistments")

	Tab:CreateToggle({
		Name = "Grapple Assist",
		Info = "Adds an isolated fallback around the native grapple cast. Normal hits are left untouched; near misses can snap to valid grapple targets.",
		CurrentValue = Controller.GrappleAssistEnabled or false,
		Flag = "GrappleAssistToggle",
		Callback = function(Value)
			Controller:SetGrappleAssist(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Assist Strength",
		Info = "Controls how forgiving the fallback target cone feels.",
		Range = { 0.1, 3 },
		Increment = 0.1,
		Suffix = "x",
		CurrentValue = Controller.GrappleAssistStrength or 1,
		Flag = "GrappleAssistStrengthSlider",
		Callback = function(Value)
			Controller:SetGrappleAssistStrength(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Assist Angle",
		Info = "Maximum angle away from your aim direction before a target can be considered.",
		Range = { 1, 45 },
		Increment = 1,
		Suffix = " deg",
		CurrentValue = Controller.GrappleAssistCaptureAngle or 45,
		Flag = "GrappleAssistCaptureAngleSlider",
		Callback = function(Value)
			Controller:SetGrappleAssistCaptureAngle(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Grapple Assist Range",
		Info = "Maximum distance in studs for assisted fallback targets.",
		Range = { 30, 500 },
		Increment = 5,
		Suffix = " studs",
		CurrentValue = Controller.GrappleAssistRange or 500,
		Flag = "GrappleAssistRangeSlider",
		Callback = function(Value)
			Controller:SetGrappleAssistRange(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Assist Confidence Gate",
		Info = "Prevents assisted snapping when the best target is too weak or too close to the runner-up.",
		CurrentValue = Controller.GrappleAssistConfidenceGateEnabled ~= false,
		Flag = "GrappleAssistConfidenceGateToggle",
		Callback = function(Value)
			Controller:SetGrappleAssistConfidenceGate(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Assist Min Score",
		Info = "Minimum target score required before Grapple Assist can snap to a fallback target.",
		Range = { -100, 80 },
		Increment = 5,
		Suffix = " score",
		CurrentValue = Controller.GrappleAssistMinConfidenceScore or -35,
		Flag = "GrappleAssistMinConfidenceScoreSlider",
		Callback = function(Value)
			Controller:SetGrappleAssistMinConfidenceScore(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Assist Margin",
		Info = "Required score gap between the best and second-best fallback target.",
		Range = { 0, 50 },
		Increment = 1,
		Suffix = " score",
		CurrentValue = Controller.GrappleAssistConfidenceMargin or 5,
		Flag = "GrappleAssistConfidenceMarginSlider",
		Callback = function(Value)
			Controller:SetGrappleAssistConfidenceMargin(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Biome Tuning",
		Info = "Applies small map-aware targeting nudges for dense rail/tower layouts such as Highrise.",
		CurrentValue = Controller.GrappleAssistBiomeTuningEnabled ~= false,
		Flag = "GrappleAssistBiomeTuningToggle",
		Callback = function(Value)
			Controller:SetGrappleAssistBiomeTuning(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Fail Feedback Loop",
		Info = "Temporarily downranks assisted targets that immediately cause drops or wall traps.",
		CurrentValue = Controller.GrappleAssistFailFeedbackEnabled ~= false,
		Flag = "GrappleAssistFailFeedbackToggle",
		Callback = function(Value)
			Controller:SetGrappleAssistFailFeedback(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Prioritize Grapple Points",
		Info = "Prefers JumpPad, GrapplePoint, Bell, and TriaOrb targets over ordinary collision surfaces.",
		CurrentValue = Controller.GrappleAssistSpecialPointPriority ~= false,
		Flag = "GrappleAssistSpecialPriorityToggle",
		Callback = function(Value)
			Controller:SetGrappleAssistSpecialPointPriority(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Anchor Priority - GrapplePoint",
		Info = "Higher values make GrapplePoint anchors win targeting decisions more often.",
		Range = { 0, 1000 },
		Increment = 25,
		Suffix = " pts",
		CurrentValue = Controller.GrappleAnchorPriorityGrapplePoint or 900,
		Flag = "GrappleAnchorPriorityGrapplePointSlider",
		Callback = function(Value)
			Controller:SetGrappleAnchorPriorityGrapplePoint(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Anchor Priority - JumpPad",
		Info = "Higher values make JumpPad anchors win targeting decisions more often.",
		Range = { 0, 1000 },
		Increment = 25,
		Suffix = " pts",
		CurrentValue = Controller.GrappleAnchorPriorityJumpPad or 1000,
		Flag = "GrappleAnchorPriorityJumpPadSlider",
		Callback = function(Value)
			Controller:SetGrappleAnchorPriorityJumpPad(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Anchor Priority - TriaOrb",
		Info = "Higher values make TriaOrb anchors win targeting decisions more often.",
		Range = { 0, 1000 },
		Increment = 25,
		Suffix = " pts",
		CurrentValue = Controller.GrappleAnchorPriorityTriaOrb or 850,
		Flag = "GrappleAnchorPriorityTriaOrbSlider",
		Callback = function(Value)
			Controller:SetGrappleAnchorPriorityTriaOrb(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Anchor Priority - Bell",
		Info = "Higher values make Bell anchors win targeting decisions more often.",
		Range = { 0, 1000 },
		Increment = 25,
		Suffix = " pts",
		CurrentValue = Controller.GrappleAnchorPriorityBell or 800,
		Flag = "GrappleAnchorPriorityBellSlider",
		Callback = function(Value)
			Controller:SetGrappleAnchorPriorityBell(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Terrain Priority",
		Info = "Base score for ordinary solid surfaces before height, ceiling, distance, and aim-angle scoring are applied.",
		Range = { -50, 300 },
		Increment = 10,
		Suffix = " pts",
		CurrentValue = Controller.GrappleAssistTerrainPriority or 100,
		Flag = "GrappleAssistTerrainPrioritySlider",
		Callback = function(Value)
			Controller:SetGrappleAssistTerrainPriority(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "Secondary Grapple Cast",
		Info = "Enables a separate keybind that instantly fires the isolated grapple assist cast.",
		CurrentValue = Controller.GrappleAssistSecondaryCastEnabled or false,
		Flag = "GrappleAssistSecondaryCastToggle",
		Callback = function(Value)
			Controller:SetGrappleAssistSecondaryCast(Value)
		end,
	})

	Tab:CreateKeybind({
		Name = "Secondary Grapple Cast Keybind",
		CurrentKeybind = Controller.GrappleAssistSecondaryCastKeybind or "Q",
		HoldToTrigger = false,
		Flag = "GrappleAssistSecondaryCastKeybind",
		Callback = function(Keybind)
			Controller:SetGrappleAssistSecondaryCastKeybind(Keybind)
			Controller:TriggerGrappleAssistSecondaryCast()
		end,
	})

	Tab:CreateToggle({
		Name = "Void Protection",
		Info = "Prevents Grapple Assist from selecting ordinary anchors that would pull you into KillVoid during dangerous falls.",
		CurrentValue = Controller.GrappleVoidProtectionEnabled or false,
		Flag = "GrappleVoidProtectionToggle",
		Callback = function(Value)
			Controller:SetGrappleVoidProtection(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Void Protection Height",
		Info = "Ordinary assisted targets this close to KillVoid are treated as unsafe.",
		Range = { 5, 120 },
		Increment = 5,
		Suffix = " studs",
		CurrentValue = Controller.GrappleVoidProtectionHeight or 24,
		Flag = "GrappleVoidProtectionHeightSlider",
		Callback = function(Value)
			Controller:SetGrappleVoidProtectionHeight(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Void Protection Fall Speed",
		Info = "When falling faster than this, assisted targeting avoids ordinary anchors below you.",
		Range = { 20, 240 },
		Increment = 5,
		Suffix = " studs/s",
		CurrentValue = Controller.GrappleVoidProtectionFallSpeed or 85,
		Flag = "GrappleVoidProtectionFallSpeedSlider",
		Callback = function(Value)
			Controller:SetGrappleVoidProtectionFallSpeed(Value)
		end,
	})

	Tab:CreateDropdown({
		Name = "Grappler Techniques",
		Info = "Choose which grappler techniques are enabled. SharkVoid auto-runs near void; Reel Saver runs from its keybind.",
		Options = { "SharkVoid", "Reel Saver" },
		CurrentOption = getSelectedGrapplerTechniques(Controller),
		MultipleOptions = true,
		Flag = "GrappleTechniqueDropdown",
		Callback = function(Options)
			Controller:SetGrapplerTechniqueSelection(Options)
		end,
	})

	Tab:CreateKeybind({
		Name = "Reel Saver Keybind",
		CurrentKeybind = Controller.GrappleReelSaverKeybind or "E",
		HoldToTrigger = false,
		Flag = "GrappleReelSaverKeybind",
		Callback = function(Keybind)
			Controller:SetGrappleReelSaverKeybind(Keybind)
			Controller:TriggerGrappleReelSaver()
		end,
	})

	Tab:CreateSlider({
		Name = "Reel Saver Search Range",
		Info = "Maximum horizontal distance the keybind scans for a wall face beside or ahead of you.",
		Range = { 8, 60 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = Controller.GrappleReelSaverSideRange or 26,
		Flag = "GrappleReelSaverSideRangeSlider",
		Callback = function(Value)
			Controller:SetGrappleReelSaverSideRange(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Reel Saver Min Ledge Height",
		Info = "Minimum ledge height above your root before Reel Saver accepts it as a recovery target.",
		Range = { 3, 18 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = Controller.GrappleReelSaverMinHeight or 5,
		Flag = "GrappleReelSaverMinHeightSlider",
		Callback = function(Value)
			Controller:SetGrappleReelSaverMinHeight(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Reel Saver Max Height",
		Info = "Maximum upper ledge height Reel Saver will try to pull toward.",
		Range = { 4, 28 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = Controller.GrappleReelSaverMaxHeight or 14,
		Flag = "GrappleReelSaverMaxHeightSlider",
		Callback = function(Value)
			Controller:SetGrappleReelSaverMaxHeight(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Reel Saver Clearance",
		Info = "Required open space above the landing plane before Reel Saver accepts it.",
		Range = { 3, 12 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = Controller.GrappleReelSaverClearance or 5,
		Flag = "GrappleReelSaverClearanceSlider",
		Callback = function(Value)
			Controller:SetGrappleReelSaverClearance(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "Reel Saver Reel Hold",
		Info = "How long the keybind-triggered reel holds before releasing.",
		Range = { 0.06, 0.35 },
		Increment = 0.01,
		Suffix = "s",
		CurrentValue = Controller.GrappleReelSaverReelHoldTime or 0.16,
		Flag = "GrappleReelSaverReelHoldSlider",
		Callback = function(Value)
			Controller:SetGrappleReelSaverReelHoldTime(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "SharkVoid Auto Reel",
		Info = "When already grappling during a dangerous fall, starts the NinjaBelt reel and schedules a short release.",
		CurrentValue = Controller.GrappleVoidRescueAutoReel ~= false,
		Flag = "GrappleVoidRescueAutoReelToggle",
		Callback = function(Value)
			Controller:SetGrappleVoidRescueAutoReel(Value)
		end,
	})

	Tab:CreateToggle({
		Name = "SharkVoid Auto SharkTail",
		Info = "Automatically spends the 0.25 second SharkTail window after release while still in danger.",
		CurrentValue = Controller.GrappleVoidRescueAutoSharkTail ~= false,
		Flag = "GrappleVoidRescueAutoSharkTailToggle",
		Callback = function(Value)
			Controller:SetGrappleVoidRescueAutoSharkTail(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "SharkVoid Height",
		Info = "Starts rescue behavior this many studs above KillVoid when KillVoid exists.",
		Range = { 10, 160 },
		Increment = 5,
		Suffix = " studs",
		CurrentValue = Controller.GrappleVoidRescueHeight or 45,
		Flag = "GrappleVoidRescueHeightSlider",
		Callback = function(Value)
			Controller:SetGrappleVoidRescueHeight(Value)
		end,
	})

	Tab:CreateSlider({
		Name = "SharkVoid Reel Hold",
		Info = "How long Auto Reel holds before release, matching the tiny timing gap of the rescue technique.",
		Range = { 0.05, 0.25 },
		Increment = 0.01,
		Suffix = "s",
		CurrentValue = Controller.GrappleVoidRescueReelHoldTime or 0.12,
		Flag = "GrappleVoidRescueReelHoldSlider",
		Callback = function(Value)
			Controller:SetGrappleVoidRescueReelHoldTime(Value)
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
		Info = "Cooldown between automatic rail snaps. Lower values catch rails faster; higher values prevent repeated re-grabs.",
		Range = { 0.15, 3 },
		Increment = 0.05,
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
end
