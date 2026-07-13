-- [[
--  NULLSCAPE - Accessibility Controller
--  Vai trò: Quản lý trạng thái và phối hợp các tính năng trợ năng (Accessibility) của hack.
-- ]]

local getgenv = getgenv
local Players = game:GetService("Players")
local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")

local executorLoaded, Executor = pcall(function()
	return getgenv().loadModule("NULLSCAPE/Accessibility/executor.luau")
end)
if not executorLoaded or typeof(Executor) ~= "table" then
	warn("[NULLSCAPE] Accessibility executor failed; using fallback dispatcher: " .. tostring(Executor))
	Executor = {}
end

local function callExecutor(methodName, ...)
	local method = Executor and Executor[methodName]
	if typeof(method) ~= "function" then
		return false
	end

	local success, result = pcall(method, ...)
	if not success then
		warn("[NULLSCAPE] Accessibility executor call failed: " .. tostring(methodName) .. " -> " .. tostring(result))
		return false
	end

	return result ~= false
end

local Controller = {
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
	GrappleAssistManualAnchorAngle = 24,
	GrappleAssistRange = 500,
	GrappleAssistConfidenceGateEnabled = true,
	GrappleAssistMinConfidenceScore = -35,
	GrappleAssistConfidenceMargin = 5,
	GrappleAssistBiomeTuningEnabled = true,
	GrappleAssistFailFeedbackEnabled = true,
	GrappleAssistSafetyEnabled = true,
	GrappleAssistSafetyRejectPenalty = 74,
	GrappleBrakeProfileSpeed = 300,
	GrappleAssistAnchorBiasEnabled = true,
	GrappleAssistSpecialPointPriority = true,
	GrappleAnchorTargetingStyle = "Auto",
	GrappleAssistSecondaryCastEnabled = false,
	GrappleAssistSecondaryCastKeybind = "Q",
	GrappleAnchorPriorityGrapplePoint = 700,
	GrappleAnchorPriorityJumpPad = 650,
	GrappleAnchorPriorityTriaOrb = 620,
	GrappleAnchorPriorityBell = 550,
	GrappleAssistTerrainPriority = 140,
	GrappleIntentHighSpeed = 120,
	GrappleIntentRailRange = 14,
	GrappleVoidProtectionEnabled = false,
	GrappleVoidProtectionHeight = 24,
	GrappleVoidProtectionFallSpeed = 85,
	GrappleVoidRescueEnabled = false,
	GrappleVoidRescueAutoReel = true,
	GrappleVoidRescueAutoSharkTail = true,
	GrappleVoidRescueHeight = 45,
	GrappleVoidRescueReelHoldTime = 0.12,
	GrappleDodgeEnabled = false,
	GrappleDodgeTechniqueEnabled = false,
	GrappleDodgeThreatRange = 42,
	GrappleDodgeDangerRadius = 10,
	GrappleDodgeHorizon = 0.45,
	GrappleDodgeRange = 92,
	GrappleDodgeStrength = 1,
	GrappleDodgeRailBonus = 34,
	GrappleDodgeMode = "Auto",
	GrappleThreatWhitelist = { Bell = true },
	GrappleThreatBlacklist = {},
	GrappleSharkEscapeEnabled = false,
	GrappleSharkEscapeMode = "Auto",
	GrappleSharkEscapeRange = 26,
	GrappleSharkEscapeReelHoldTime = 0.12,
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
	AntiBonkEnabled = false,
	IgnoreFakeCountEnabled = false,
	BeaconMirageIdentifierEnabled = false,
	PhysicalInteractionRangeGrapplePoint = 0,
	PhysicalInteractionRangeTriaOrb = 0,
	PhysicalInteractionRangeJumpPad = 0,
	GrapplerStaminaRecoverySpeed = 1,
	Destroyed = false,

	PermanentConnections = {},
	RespawnRefreshToken = 0,
	LastReapplyAt = 0,
}

local ANCHOR_TARGETING_STYLES = {
	["Manual Control"] = {
		ManualAngle = 18,
		GrapplePoint = 620,
		JumpPad = 520,
		TriaOrb = 520,
		Bell = 460,
		Terrain = 170,
	},
	Balanced = {
		ManualAngle = 24,
		GrapplePoint = 700,
		JumpPad = 650,
		TriaOrb = 620,
		Bell = 550,
		Terrain = 140,
	},
	["Anchor Friendly"] = {
		ManualAngle = 30,
		GrapplePoint = 850,
		JumpPad = 800,
		TriaOrb = 760,
		Bell = 720,
		Terrain = 110,
	},
	["Terrain First"] = {
		ManualAngle = 16,
		GrapplePoint = 480,
		JumpPad = 420,
		TriaOrb = 420,
		Bell = 380,
		Terrain = 210,
	},
}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function isControllerActiveOrUnclaimed(controller)
	local globals = getGlobals()
	return globals.activeAccessibilityController == controller or globals.activeAccessibilityController == nil
end

local function claimActiveController(controller)
	local globals = getGlobals()
	if globals.activeAccessibilityController == nil then
		globals.activeAccessibilityController = controller
	end

	return globals.activeAccessibilityController == controller
end

local function isGrapplerClass()
	return ClassContext and ClassContext.is("Grappler")
end

-- Hàm dọn dẹp tài nguyên
function Controller:CleanUp()
	local globals = getGlobals()
	local finalCleanup = self.Destroyed
		or (globals.activeAccessibilityController ~= nil and globals.activeAccessibilityController ~= self)
	if finalCleanup then
		self.AntiBonkEnabled = false
		self.GrapplerStaminaMode = "Off"
		self.StaminaMode = "Off"
		callExecutor("disableStaminaAssist")
		callExecutor("disableRailAssist")
		callExecutor("disableAntiBonk")
		callExecutor("disableCurseVisualAssist")
		callExecutor("disableMirageSafety")
		callExecutor("disableMomentumGuard")
		callExecutor("disableGrappleAssist")
		callExecutor("disablePhysicalInteractionRange")
	end
	if self.Destroyed and self.PermanentConnections then
		for _, conn in ipairs(self.PermanentConnections) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		table.clear(self.PermanentConnections)
	end

	-- Giải phóng biến môi trường để hỗ trợ dọn dẹp bộ nhớ (GC)
	if self.Destroyed and globals and globals.activeAccessibilityController == self then
		globals.activeAccessibilityController = nil
	end
end

function Controller:ReapplyRespawnFeatures()
	if self.Destroyed then
		return
	end
	local now = time()
	if now - (self.LastReapplyAt or 0) < 0.12 then
		return
	end
	self.LastReapplyAt = now

	if not isControllerActiveOrUnclaimed(self) then
		return
	end
	claimActiveController(self)

	callExecutor("resetStaminaAssistRespawnState")
	callExecutor("resetGrappleAssistRespawnState")
	callExecutor("resetPhysicalInteractionRangeRespawnState", self)

	if self.AntiBonkEnabled then
		callExecutor("initializeAntiBonk")
	end

	if self.IgnoreFakeCountEnabled then
		callExecutor("setIgnoreFakeCount", true)
	end

	if self.BeaconMirageIdentifierEnabled then
		callExecutor("setBeaconMirageIdentifier", true)
	end

	if self.MomentumMode ~= "Off" then
		callExecutor("initializeMomentumGuard")
	end

	if self.GrappleAssistEnabled and isGrapplerClass() then
		callExecutor("initializeGrappleAssist", self)
	elseif self.GrappleAssistEnabled then
		callExecutor("disableGrappleAssist")
	end

	if self.GrapplerStaminaMode ~= "Off" and isGrapplerClass() then
		callExecutor("initializeStaminaAssist")
	elseif self.GrapplerStaminaMode ~= "Off" then
		callExecutor("disableStaminaAssist")
	end

	self:RefreshRailAssistHook()
	self:RefreshPhysicalInteractionRange()
end

function Controller:SetIgnoreFakeCount(value)
	local enabled = value == true
	self.IgnoreFakeCountEnabled = enabled
	if not callExecutor("setIgnoreFakeCount", enabled) then
		self.IgnoreFakeCountEnabled = false
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "CurseHandler is not available yet",
				Duration = 3,
			})
		end
	end
end

function Controller:SetBeaconMirageIdentifier(value)
	local enabled = value == true
	self.BeaconMirageIdentifierEnabled = enabled
	if not callExecutor("setBeaconMirageIdentifier", enabled) then
		self.BeaconMirageIdentifierEnabled = false
	end
end

function Controller:RefreshPhysicalInteractionRange()
	if
		self.PhysicalInteractionRangeGrapplePoint > 0
		or self.PhysicalInteractionRangeTriaOrb > 0
		or self.PhysicalInteractionRangeJumpPad > 0
	then
		return callExecutor("initializePhysicalInteractionRange", self)
	end

	callExecutor("disablePhysicalInteractionRange")
	return true
end

function Controller:SetPhysicalInteractionRangeGrapplePoint(value)
	self.PhysicalInteractionRangeGrapplePoint = math.clamp(tonumber(value) or 0, 0, 10)
	self:RefreshPhysicalInteractionRange()
end

function Controller:SetPhysicalInteractionRangeTriaOrb(value)
	self.PhysicalInteractionRangeTriaOrb = math.clamp(tonumber(value) or 0, 0, 10)
	self:RefreshPhysicalInteractionRange()
end

function Controller:SetPhysicalInteractionRangeJumpPad(value)
	self.PhysicalInteractionRangeJumpPad = math.clamp(tonumber(value) or 0, 0, 10)
	self:RefreshPhysicalInteractionRange()
end

function Controller:RefreshRailAssistHook()
	if self.RailAssistSuiteEnabled then
		if not callExecutor("enableRailAssist") then
			return false
		end
	else
		callExecutor("disableRailAssist")
	end

	return true
end

function Controller:SetRailAssistSuite(value)
	self.RailAssistSuiteEnabled = value == true

	if not self:RefreshRailAssistHook() then
		self.RailAssistSuiteEnabled = false
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "MovementCore module is not available yet",
				Duration = 3,
			})
		end
		return
	end
end

function Controller:SetRailAuto(value)
	self.RailAutoEnabled = value == true

	if self.RailAssistSuiteEnabled and not self:RefreshRailAssistHook() then
		self.RailAutoEnabled = false
	end
end

function Controller:SetRailSpeedMultiplier(value)
	self.RailSpeedMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

function Controller:SetRailAutoDelay(value)
	self.RailAutoDelay = math.clamp(tonumber(value) or 1.5, 0.15, 3)
end

function Controller:SetRailAutoCaptureRange(value)
	self.RailAutoCaptureRange = math.clamp(tonumber(value) or 4, 1, 64)
end

function Controller:SetMomentumMode(mode)
	local selected = mode
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "Off")
	if selected ~= "Decay" and selected ~= "Soft Cap" then
		selected = "Off"
	end

	self.MomentumMode = selected
	if selected == "Off" then
		callExecutor("disableMomentumGuard")
	elseif not callExecutor("initializeMomentumGuard") then
		self.MomentumMode = "Off"
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "Momentum Guard module is not available yet",
				Duration = 3,
			})
		end
	end
end

function Controller:SetMomentumDecay(value)
	self.MomentumDecay = math.clamp(tonumber(value) or 4, 0.5, 12)
end

function Controller:SetMomentumSoftReduction(value)
	self.MomentumSoftReduction = math.clamp(tonumber(value) or 0.35, 0.05, 1)
end

function Controller:SetMomentumMaxHorizontalSpeed(value)
	self.MomentumMaxHorizontalSpeed = math.clamp(tonumber(value) or 500, 100, 500)
end

function Controller:SetMomentumMaxVerticalSpeed(value)
	self.MomentumMaxVerticalSpeed = math.clamp(tonumber(value) or 500, 100, 500)
end

function Controller:SetGrappleAssist(value)
	self.GrappleAssistEnabled = value == true

	if self.GrappleAssistEnabled and isGrapplerClass() and not callExecutor("initializeGrappleAssist", self) then
		self.GrappleAssistEnabled = false
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "Grapple module is not available yet",
				Duration = 3,
			})
		end
		return
	end

	if not self.GrappleAssistEnabled then
		callExecutor("disableGrappleAssist")
	end
end

-- Keep runtime feature gates in one place. Child toggles configure a feature;
-- they must never implicitly reactivate the parent Grapple Assist toggle.
function Controller:IsGrappleFeatureEnabled(featureName)
	if self.GrappleAssistEnabled ~= true or not isGrapplerClass() then
		return false
	end

	if featureName == "SharkVoid" then
		return self.GrappleVoidRescueEnabled == true
	end
	if featureName == "ReelSaver" then
		return self.GrappleReelSaverEnabled == true
	end
	if featureName == "GrappleDodge" then
		return self.GrappleDodgeTechniqueEnabled == true or self.GrappleSharkEscapeEnabled == true
	end
	if featureName == "SecondaryCast" then
		return self.GrappleAssistSecondaryCastEnabled == true
	end

	return true
end

function Controller:SetGrappleAssistStrength(value)
	self.GrappleAssistStrength = math.clamp(tonumber(value) or 1, 0.1, 3)
end

function Controller:SetGrappleAssistCaptureAngle(value)
	self.GrappleAssistCaptureAngle = math.clamp(tonumber(value) or 45, 1, 45)
end

function Controller:SetGrappleAssistManualAnchorAngle(value)
	self.GrappleAssistManualAnchorAngle = math.clamp(tonumber(value) or 24, 4, 45)
	self.GrappleAnchorTargetingStyle = "Custom"
end

function Controller:SetGrappleAssistRange(value)
	self.GrappleAssistRange = math.clamp(tonumber(value) or 500, 30, 500)
end

function Controller:SetGrappleAssistConfidenceGate(value)
	self.GrappleAssistConfidenceGateEnabled = value == true
end

function Controller:SetGrappleAssistMinConfidenceScore(value)
	self.GrappleAssistMinConfidenceScore = math.clamp(tonumber(value) or -35, -100, 80)
end

function Controller:SetGrappleAssistConfidenceMargin(value)
	self.GrappleAssistConfidenceMargin = math.clamp(tonumber(value) or 5, 0, 50)
end

function Controller:SetGrappleAssistBiomeTuning(value)
	self.GrappleAssistBiomeTuningEnabled = value == true
end

function Controller:SetGrappleAssistFailFeedback(value)
	self.GrappleAssistFailFeedbackEnabled = value == true
end

function Controller:SetGrappleAssistSafety(value)
	self.GrappleAssistSafetyEnabled = value == true
end

function Controller:SetGrappleAssistSafetyRejectPenalty(value)
	self.GrappleAssistSafetyRejectPenalty = math.clamp(tonumber(value) or 74, 20, 140)
end

function Controller:SetGrappleBrakeProfileSpeed(value)
	self.GrappleBrakeProfileSpeed = math.clamp(tonumber(value) or 300, 200, 500)
end

function Controller:SetGrappleAssistAnchorBias(value)
	self.GrappleAssistAnchorBiasEnabled = value == true
end

function Controller:SetGrappleAssistSpecialPointPriority(value)
	self.GrappleAssistSpecialPointPriority = value == true
end

function Controller:SetGrappleAnchorTargetingStyle(value)
	local styleName = tostring(value or "Auto")
	if styleName == "Auto" then
		self.GrappleAnchorTargetingStyle = "Auto"
		return
	end

	local style = ANCHOR_TARGETING_STYLES[styleName] or ANCHOR_TARGETING_STYLES.Balanced
	self.GrappleAnchorTargetingStyle = ANCHOR_TARGETING_STYLES[styleName] and styleName or "Balanced"
	self.GrappleAssistManualAnchorAngle = style.ManualAngle
	self.GrappleAnchorPriorityGrapplePoint = style.GrapplePoint
	self.GrappleAnchorPriorityJumpPad = style.JumpPad
	self.GrappleAnchorPriorityTriaOrb = style.TriaOrb
	self.GrappleAnchorPriorityBell = style.Bell
	self.GrappleAssistTerrainPriority = style.Terrain
end

function Controller:SetGrappleAnchorPriorityGrapplePoint(value)
	self.GrappleAnchorPriorityGrapplePoint = math.clamp(tonumber(value) or 700, 0, 1000)
	self.GrappleAnchorTargetingStyle = "Custom"
end

function Controller:SetGrappleAnchorPriorityJumpPad(value)
	self.GrappleAnchorPriorityJumpPad = math.clamp(tonumber(value) or 650, 0, 1000)
	self.GrappleAnchorTargetingStyle = "Custom"
end

function Controller:SetGrappleAnchorPriorityTriaOrb(value)
	self.GrappleAnchorPriorityTriaOrb = math.clamp(tonumber(value) or 620, 0, 1000)
	self.GrappleAnchorTargetingStyle = "Custom"
end

function Controller:SetGrappleAnchorPriorityBell(value)
	self.GrappleAnchorPriorityBell = math.clamp(tonumber(value) or 550, 0, 1000)
	self.GrappleAnchorTargetingStyle = "Custom"
end

function Controller:SetGrappleAssistTerrainPriority(value)
	self.GrappleAssistTerrainPriority = math.clamp(tonumber(value) or 140, -50, 300)
	self.GrappleAnchorTargetingStyle = "Custom"
end

function Controller:SetGrappleIntentHighSpeed(value)
	self.GrappleIntentHighSpeed = math.clamp(tonumber(value) or 120, 40, 300)
end

function Controller:SetGrappleIntentRailRange(value)
	self.GrappleIntentRailRange = math.clamp(tonumber(value) or 14, 4, 48)
end

function Controller:SetGrappleVoidProtection(value)
	self.GrappleVoidProtectionEnabled = value == true
end

function Controller:SetGrappleVoidProtectionHeight(value)
	self.GrappleVoidProtectionHeight = math.clamp(tonumber(value) or 24, 5, 120)
end

function Controller:SetGrappleVoidProtectionFallSpeed(value)
	self.GrappleVoidProtectionFallSpeed = math.clamp(tonumber(value) or 85, 20, 240)
end

function Controller:SetGrappleAssistSecondaryCast(value)
	self.GrappleAssistSecondaryCastEnabled = value == true
end

function Controller:SetGrappleAssistSecondaryCastKeybind(value)
	self.GrappleAssistSecondaryCastKeybind = tostring(value or "Q")
end

function Controller:SetGrappleVoidRescue(value)
	self.GrappleVoidRescueEnabled = value == true
end

function Controller:SetGrapplerTechniqueSelection(options)
	local sharkVoid = false
	local reelSaver = false
	local grappleDodge = false
	local sharkEscape = false

	if typeof(options) == "table" then
		if
			options.SharkVoid ~= nil
			or options.ReelSaver ~= nil
			or options.GrappleDodge ~= nil
			or options.SharkEscape ~= nil
		then
			sharkVoid = options.SharkVoid == true
			reelSaver = options.ReelSaver == true
			grappleDodge = options.GrappleDodge == true
			sharkEscape = options.SharkEscape == true
		else
			for _, option in ipairs(options) do
				if option == "SharkVoid" then
					sharkVoid = true
				elseif option == "Reel Saver" or option == "ReelSaver" then
					reelSaver = true
				elseif option == "Grapple Dodge" or option == "GrappleDodge" then
					grappleDodge = true
				elseif option == "SharkEscape" or option == "Shark Escape" then
					sharkEscape = true
				end
			end
		end
	end

	self.GrappleVoidRescueEnabled = sharkVoid
	self.GrappleReelSaverEnabled = reelSaver
	self.GrappleDodgeTechniqueEnabled = grappleDodge
	self.GrappleDodgeEnabled = grappleDodge or sharkEscape
	self.GrappleSharkEscapeEnabled = sharkEscape
end

function Controller:SetGrappleVoidRescueAutoReel(value)
	self.GrappleVoidRescueAutoReel = value == true
end

function Controller:SetGrappleVoidRescueAutoSharkTail(value)
	self.GrappleVoidRescueAutoSharkTail = value == true
end

function Controller:SetGrappleVoidRescueHeight(value)
	self.GrappleVoidRescueHeight = math.clamp(tonumber(value) or 45, 10, 160)
end

function Controller:SetGrappleVoidRescueReelHoldTime(value)
	self.GrappleVoidRescueReelHoldTime = math.clamp(tonumber(value) or 0.12, 0.05, 0.25)
end

function Controller:SetGrappleDodge(value)
	self.GrappleDodgeTechniqueEnabled = value == true
	self.GrappleDodgeEnabled = self.GrappleDodgeTechniqueEnabled or self.GrappleSharkEscapeEnabled == true
end

function Controller:SetGrappleDodgeThreatRange(value)
	self.GrappleDodgeThreatRange = math.clamp(tonumber(value) or 42, 16, 90)
end

function Controller:SetGrappleDodgeDangerRadius(value)
	self.GrappleDodgeDangerRadius = math.clamp(tonumber(value) or 10, 4, 24)
end

function Controller:SetGrappleDodgeHorizon(value)
	self.GrappleDodgeHorizon = math.clamp(tonumber(value) or 0.45, 0.15, 0.9)
end

function Controller:SetGrappleDodgeRange(value)
	self.GrappleDodgeRange = math.clamp(tonumber(value) or 92, 30, 150)
end

function Controller:SetGrappleDodgeStrength(value)
	self.GrappleDodgeStrength = math.clamp(tonumber(value) or 1, 0.25, 3)
end

function Controller:SetGrappleDodgeRailBonus(value)
	self.GrappleDodgeRailBonus = math.clamp(tonumber(value) or 34, 0, 120)
end

function Controller:SetGrappleDodgeMode(value)
	if typeof(value) == "table" then
		value = value[1]
	end
	self.GrappleDodgeMode = tostring(value) == "Manual" and "Manual" or "Auto"
end

local function normaliseThreatList(value)
	local result = {}
	if typeof(value) ~= "table" then
		return result
	end

	for key, selected in pairs(value) do
		local option = typeof(key) == "number" and selected or key
		if selected == true or typeof(key) == "number" then
			result[tostring(option)] = true
		end
	end

	return result
end

function Controller:SetGrappleThreatWhitelist(value)
	self.GrappleThreatWhitelist = normaliseThreatList(value)
end

function Controller:SetGrappleThreatBlacklist(value)
	self.GrappleThreatBlacklist = normaliseThreatList(value)
end

function Controller:SetGrappleSharkEscape(value)
	self.GrappleSharkEscapeEnabled = value == true
	self.GrappleDodgeEnabled = self.GrappleDodgeTechniqueEnabled == true or self.GrappleSharkEscapeEnabled
end

function Controller:SetGrappleSharkEscapeMode(value)
	if typeof(value) == "table" then
		value = value[1]
	end
	self.GrappleSharkEscapeMode = tostring(value) == "Manual" and "Manual" or "Auto"
end

function Controller:SetGrappleSharkEscapeRange(value)
	self.GrappleSharkEscapeRange = math.clamp(tonumber(value) or 26, 10, 50)
end

function Controller:SetGrappleSharkEscapeReelHoldTime(value)
	self.GrappleSharkEscapeReelHoldTime = math.clamp(tonumber(value) or 0.12, 0.05, 0.22)
end

function Controller:SetGrappleReelSaver(value)
	self.GrappleReelSaverEnabled = value == true
end

function Controller:SetGrappleReelSaverKeybind(value)
	self.GrappleReelSaverKeybind = tostring(value or "E")
end

function Controller:SetGrappleReelSaverSideRange(value)
	self.GrappleReelSaverSideRange = math.clamp(tonumber(value) or 26, 8, 60)
end

function Controller:SetGrappleReelSaverMinHeight(value)
	self.GrappleReelSaverMinHeight = math.clamp(tonumber(value) or 5, 3, 18)
end

function Controller:SetGrappleReelSaverMaxHeight(value)
	local minHeight = tonumber(self.GrappleReelSaverMinHeight) or 5
	self.GrappleReelSaverMaxHeight = math.clamp(tonumber(value) or 14, minHeight + 1, 28)
end

function Controller:SetGrappleReelSaverClearance(value)
	self.GrappleReelSaverClearance = math.clamp(tonumber(value) or 5, 3, 12)
end

function Controller:SetGrappleReelSaverReelHoldTime(value)
	self.GrappleReelSaverReelHoldTime = math.clamp(tonumber(value) or 0.16, 0.06, 0.35)
end

function Controller:TriggerGrappleReelSaver()
	if not (self:IsGrappleFeatureEnabled("ReelSaver")) then
		return false
	end

	return callExecutor("triggerGrappleReelSaver", self)
end

function Controller:TriggerGrappleAssistSecondaryCast()
	if not (self:IsGrappleFeatureEnabled("SecondaryCast")) then
		return false
	end

	return callExecutor("triggerGrappleAssistSecondaryCast", self)
end

function Controller:SetStaminaMode(mode)
	local selectedMode = mode
	if typeof(selectedMode) == "table" then
		selectedMode = selectedMode[1]
	end
	selectedMode = tostring(selectedMode or "Off")

	if selectedMode == "Infinite" then
		selectedMode = "Infinite Stamina"
	elseif selectedMode ~= "Infinite Stamina" and selectedMode ~= "Manual" then
		selectedMode = "Off"
	end

	local previousMode = self.GrapplerStaminaMode
	local previousStaminaMode = self.StaminaMode
	self.GrapplerStaminaMode = selectedMode
	self.StaminaMode = selectedMode

	if selectedMode == "Infinite Stamina" and isGrapplerClass() then
		if not callExecutor("initializeStaminaAssist") then
			self.GrapplerStaminaMode = previousMode or "Off"
			self.StaminaMode = previousStaminaMode or "Off"
			if getgenv().Rayfield then
				getgenv().Rayfield:Notify({
					Title = "Accessibility Config",
					Content = "Stamina module is not available yet",
					Duration = 3,
				})
			end
			return
		end
	elseif selectedMode ~= "Infinite Stamina" then
		callExecutor("disableStaminaAssist")
	end

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = "Class stamina mode: " .. selectedMode,
			Duration = 2,
		})
	end
end

function Controller:SetGrapplerStaminaMode(mode)
	return self:SetStaminaMode(mode)
end

function Controller:SetGrapplerStaminaRecoverySpeed(value)
	self.GrapplerStaminaRecoverySpeed = math.clamp(tonumber(value) or 1, 1, 10)
end

function Controller:SetAntiBonk(value)
	if value and not callExecutor("initializeAntiBonk") then
		self.AntiBonkEnabled = false
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "Movement module is not available yet",
				Duration = 3,
			})
		end
		return
	end

	self.AntiBonkEnabled = value == true
	if not self.AntiBonkEnabled then
		callExecutor("disableAntiBonk")
	end

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = (self.AntiBonkEnabled and "Activated" or "Disabled") .. " Universal Anti-Bonk",
			Duration = 2,
		})
	end
end

-- Đăng ký active controller hiện tại để tự động dừng các phiên bản cũ
local function scheduleRespawnFeatureRefresh()
	Controller.RespawnRefreshToken = (Controller.RespawnRefreshToken or 0) + 1
	local token = Controller.RespawnRefreshToken
	local function refreshLater()
		if Controller.Destroyed then
			return
		end
		if token ~= Controller.RespawnRefreshToken then
			return
		end
		if not isControllerActiveOrUnclaimed(Controller) then
			Controller:CleanUp()
			return
		end
		claimActiveController(Controller)
		Controller:ReapplyRespawnFeatures()
	end

	task.defer(refreshLater)
	task.delay(0.6, refreshLater)
	task.delay(1.6, refreshLater)
end

getGlobals().activeAccessibilityController = Controller
callExecutor("initializeMirageSafety")

-- Khởi tạo ban đầu khi nạp script
-- Lắng nghe sự kiện đổi trạng thái game thời gian thực

local characterRefreshConnection = Players.LocalPlayer.CharacterAdded:Connect(function()
	scheduleRespawnFeatureRefresh()
end)
table.insert(Controller.PermanentConnections, characterRefreshConnection)

if ClassContext and typeof(ClassContext.subscribe) == "function" then
	local classConnection = ClassContext.subscribe(function(currentClass)
		if Controller.Destroyed then
			return
		end

		if currentClass == "grappler" then
			scheduleRespawnFeatureRefresh()
		else
			callExecutor("disableGrappleAssist")
			callExecutor("disableStaminaAssist")
		end
	end)
	if classConnection then
		table.insert(Controller.PermanentConnections, classConnection)
	end
end

return Controller
