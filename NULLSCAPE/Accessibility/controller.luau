-- [[
--  NULLSCAPE - Accessibility Controller
--  Vai trò: Quản lý trạng thái và phối hợp các tính năng trợ năng (Accessibility) của hack.
-- ]]

local getgenv = getgenv
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local executorLoaded, Executor = pcall(function()
	return getgenv().loadModule("NULLSCAPE/Accessibility/executor.luau")
end)
if not executorLoaded or typeof(Executor) ~= "table" then
	warn("[NULLSCAPE] Accessibility executor failed; using fallback dispatcher: " .. tostring(Executor))
	Executor = {}
end

local gcLoaded, GC = pcall(function()
	return getgenv().loadModule("NULLSCAPE/Accessibility/GC.luau")
end)
if not gcLoaded or typeof(GC) ~= "table" then
	warn("[NULLSCAPE] Accessibility GC failed; using fallback cleaner: " .. tostring(GC))
	GC = {
		cleanAll = function() end,
	}
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
	SpringerAutoJumpEnabled = false,
	InfiniteAirJumpEnabled = false,
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
	GrappleIntentHighSpeed = 120,
	GrappleIntentRailRange = 14,
	GrappleVoidProtectionEnabled = false,
	GrappleVoidProtectionHeight = 24,
	GrappleVoidProtectionFallSpeed = 85,
	GrappleVoidRescueEnabled = false,
	GrappleVoidRescueAutoCast = false,
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
	AntiBonkEnabled = false,
	GrapplerStaminaRecoverySpeed = 1,
	Destroyed = false,

	EnemiesFolder = nil,
	PermanentConnections = {},
	RespawnRefreshToken = 0,
	LastReapplyAt = 0,
}

local _LocalPlayer = Players.LocalPlayer
local inLobby = true
local folderConnections = {}

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

-- Xác minh kiểm tra trạng thái game bằng ReplicatedStorage.InRound
local function isInMatch()
	local inRoundVal = ReplicatedStorage:FindFirstChild("InRound")
	if inRoundVal and inRoundVal:IsA("BoolValue") then
		return inRoundVal.Value
	end

	local enemies = workspace:FindFirstChild("Enemies")
	if enemies and #enemies:GetChildren() > 0 then
		return true
	end

	return false
end

inLobby = not isInMatch()

-- Ngắt các kết nối quan sát thư mục
local function disconnectFolderObservations()
	for _, conn in ipairs(folderConnections) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	table.clear(folderConnections)
end

-- Hàm dọn dẹp tài nguyên
function Controller:CleanUp()
	disconnectFolderObservations()
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
		callExecutor("disableMomentumGuard")
		callExecutor("disableGrappleAssist")
	end
	GC.cleanAll()
	self.EnemiesFolder = nil

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

	-- Don dep ket noi nhay vo han neu huy hoan toan
	if
		self.Destroyed
		and (
			not globals
			or globals.activeAccessibilityController == self
			or globals.activeAccessibilityController == nil
		)
	then
		callExecutor("disableInfiniteAirJump")
	end

	-- Giải phóng biến môi trường để hỗ trợ dọn dẹp bộ nhớ (GC)
	if self.Destroyed and globals and globals.activeAccessibilityController == self then
		globals.activeAccessibilityController = nil
	end
end

-- Thiết lập cấu hình tự động nhảy
function Controller:SetSpringerAutoJump(value)
	self.SpringerAutoJumpEnabled = value
	self:updateSpringerAutoJumpState()

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = (value and "Activated" or "Disabled") .. " Springer Auto Jump",
			Duration = 2,
		})
	end
end

function Controller:SetInfiniteAirJump(value)
	local enabled = value == true
	self.InfiniteAirJumpEnabled = enabled

	if enabled and not callExecutor("initializeInfiniteAirJump") then
		self.InfiniteAirJumpEnabled = false
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "DoubleJump module is not available yet",
				Duration = 3,
			})
		end
		return
	end

	if not self.InfiniteAirJumpEnabled then
		callExecutor("disableInfiniteAirJump")
	end

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = (enabled and "Activated" or "Disabled") .. " Infinite Air Jump",
			Duration = 2,
		})
	end
end

function Controller:GetInfiniteAirJumpStatus()
	local method = Executor and Executor.getInfiniteAirJumpStatus
	if typeof(method) ~= "function" then
		return "pending"
	end

	local success, result = pcall(method)
	if not success then
		return "status error"
	end

	return tostring(result)
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

	if self.InfiniteAirJumpEnabled then
		callExecutor("initializeInfiniteAirJump")
	end

	if self.AntiBonkEnabled then
		callExecutor("initializeAntiBonk")
	end

	if self.MomentumMode ~= "Off" then
		callExecutor("initializeMomentumGuard")
	end

	if self.GrappleAssistEnabled then
		callExecutor("initializeGrappleAssist", self)
	end

	self:RefreshRailAssistHook()
	self:updateSpringerAutoJumpState()
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

	if self.GrappleAssistEnabled and not callExecutor("initializeGrappleAssist", self) then
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

function Controller:SetGrappleAssistStrength(value)
	self.GrappleAssistStrength = math.clamp(tonumber(value) or 1, 0.1, 3)
end

function Controller:SetGrappleAssistCaptureAngle(value)
	self.GrappleAssistCaptureAngle = math.clamp(tonumber(value) or 45, 1, 45)
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

function Controller:SetGrappleAssistSpecialPointPriority(value)
	self.GrappleAssistSpecialPointPriority = value == true
end

function Controller:SetGrappleAnchorPriorityGrapplePoint(value)
	self.GrappleAnchorPriorityGrapplePoint = math.clamp(tonumber(value) or 900, 0, 1000)
end

function Controller:SetGrappleAnchorPriorityJumpPad(value)
	self.GrappleAnchorPriorityJumpPad = math.clamp(tonumber(value) or 1000, 0, 1000)
end

function Controller:SetGrappleAnchorPriorityTriaOrb(value)
	self.GrappleAnchorPriorityTriaOrb = math.clamp(tonumber(value) or 850, 0, 1000)
end

function Controller:SetGrappleAnchorPriorityBell(value)
	self.GrappleAnchorPriorityBell = math.clamp(tonumber(value) or 800, 0, 1000)
end

function Controller:SetGrappleAssistTerrainPriority(value)
	self.GrappleAssistTerrainPriority = math.clamp(tonumber(value) or 100, -50, 300)
end

function Controller:SetGrappleIntentHighSpeed(value)
	self.GrappleIntentHighSpeed = math.clamp(tonumber(value) or 120, 40, 300)
end

function Controller:SetGrappleIntentRailRange(value)
	self.GrappleIntentRailRange = math.clamp(tonumber(value) or 14, 4, 48)
end

function Controller:SetGrappleVoidProtection(value)
	self.GrappleVoidProtectionEnabled = value == true

	if self.GrappleVoidProtectionEnabled then
		self:SetGrappleAssist(true)
	end
end

function Controller:SetGrappleVoidProtectionHeight(value)
	self.GrappleVoidProtectionHeight = math.clamp(tonumber(value) or 24, 5, 120)
end

function Controller:SetGrappleVoidProtectionFallSpeed(value)
	self.GrappleVoidProtectionFallSpeed = math.clamp(tonumber(value) or 85, 20, 240)
end

function Controller:SetGrappleAssistSecondaryCast(value)
	self.GrappleAssistSecondaryCastEnabled = value == true

	if self.GrappleAssistSecondaryCastEnabled then
		self:SetGrappleAssist(true)
	end
end

function Controller:SetGrappleAssistSecondaryCastKeybind(value)
	self.GrappleAssistSecondaryCastKeybind = tostring(value or "Q")
end

function Controller:SetGrappleVoidRescue(value)
	self.GrappleVoidRescueEnabled = value == true

	if self.GrappleVoidRescueEnabled then
		self.GrappleVoidRescueAutoCast = true
		self:SetGrappleAssist(true)
	end
end

function Controller:SetGrapplerTechniqueSelection(options)
	local sharkVoid = false
	local reelSaver = false

	if typeof(options) == "table" then
		if options.SharkVoid ~= nil or options.ReelSaver ~= nil then
			sharkVoid = options.SharkVoid == true
			reelSaver = options.ReelSaver == true
		else
			for _, option in ipairs(options) do
				if option == "SharkVoid" then
					sharkVoid = true
				elseif option == "Reel Saver" or option == "ReelSaver" then
					reelSaver = true
				end
			end
		end
	end

	self.GrappleVoidRescueEnabled = sharkVoid
	self.GrappleReelSaverEnabled = reelSaver

	if sharkVoid then
		self.GrappleVoidRescueAutoCast = true
	end

	if sharkVoid or reelSaver then
		self:SetGrappleAssist(true)
	end
end

function Controller:SetGrappleVoidRescueAutoReel(value)
	self.GrappleVoidRescueAutoReel = value == true
end

function Controller:SetGrappleVoidRescueAutoCast(value)
	self.GrappleVoidRescueAutoCast = value == true
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

function Controller:SetGrappleReelSaver(value)
	self.GrappleReelSaverEnabled = value == true

	if self.GrappleReelSaverEnabled then
		self:SetGrappleAssist(true)
	end
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
	if not self.GrappleReelSaverEnabled then
		return false
	end

	if not self.GrappleAssistEnabled then
		self:SetGrappleAssist(true)
	end

	return callExecutor("triggerGrappleReelSaver", self)
end

function Controller:TriggerGrappleAssistSecondaryCast()
	if not self.GrappleAssistSecondaryCastEnabled then
		return false
	end

	if not self.GrappleAssistEnabled then
		self:SetGrappleAssist(true)
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

	if selectedMode == "Infinite Stamina" then
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
	else
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

local function handleSpringerShockwave(enemy, child)
	if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
		callExecutor("setupAutoJump", enemy, child, Controller, GC)
	end
end

-- Xử lý từng thực thể Springer khi xuất hiện
local function processEntity(enemy)
	if not enemy then
		return
	end

	if string.find(enemy.Name, "Springer") then
		-- 1. Lắng nghe các shockwave được thêm vào động sau này (khi Springer nhảy)
		local childAddedConn = enemy.ChildAdded:Connect(function(child)
			handleSpringerShockwave(enemy, child)
		end)
		GC.registerEntityConnection(enemy, childAddedConn)

		-- 2. Xử lý các shockwave đã có sẵn trong model
		for _, child in ipairs(enemy:GetChildren()) do
			handleSpringerShockwave(enemy, child)
		end
	end
end

-- Gỡ bỏ lắng nghe của thực thể khi bị xóa
local function removeEntity(enemy)
	GC.removeEntityConnections(enemy)
end

-- Thiết lập quan sát thư mục Enemies trong Workspace
function Controller:ObserveFolder(folder)
	self.EnemiesFolder = folder

	-- 1. Lắng nghe khi thực thể mới xuất hiện
	local childAddedConn = folder.ChildAdded:Connect(function(child)
		processEntity(child)
	end)
	table.insert(folderConnections, childAddedConn)

	-- 2. Lắng nghe khi thực thể bị xóa khỏi game
	local childRemovedConn = folder.ChildRemoved:Connect(function(child)
		removeEntity(child)
	end)
	table.insert(folderConnections, childRemovedConn)

	-- 3. Xử lý các thực thể đã có sẵn trong thư mục
	for _, child in ipairs(folder:GetChildren()) do
		processEntity(child)
	end

	-- 4. Cơ chế tự động GC khi thư mục bị xóa/hủy khỏi Workspace
	local destroyingConn = folder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:CleanUp()
		end
	end)
	table.insert(folderConnections, destroyingConn)
end

-- Quét tìm thư mục Enemies trong Workspace và lắng nghe sự thay đổi
local function startObservingFolders()
	disconnectFolderObservations()

	local function checkAndObserve(child)
		if Controller.Destroyed then
			return
		end
		if not isControllerActiveOrUnclaimed(Controller) then
			Controller:CleanUp()
			return
		end
		claimActiveController(Controller)
		if child.Name == "Enemies" and child:IsA("Folder") then
			Controller:ObserveFolder(child)
		end
	end

	local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
	table.insert(folderConnections, wsConn)

	local initialFolder = workspace:FindFirstChild("Enemies")
	if initialFolder and initialFolder:IsA("Folder") then
		Controller:ObserveFolder(initialFolder)
	end
end

-- Cập nhật động trạng thái Auto Jump của Springer dựa trên cài đặt và immunity mode
function Controller:updateSpringerAutoJumpState()
	local globals = getGlobals()
	local entitiesController = globals.activeEntitiesController
	local isBlatant = entitiesController and entitiesController.SpringerImmunityMode == "Blatant"

	if self.SpringerAutoJumpEnabled and not isBlatant then
		-- Kích hoạt quan sát thư mục nếu chưa kích hoạt
		if not next(folderConnections) then
			startObservingFolders()
		end
	else
		-- Blatant mode hoặc Auto Jump tắt -> Giải phóng hoàn toàn để CPU nghỉ ngơi
		disconnectFolderObservations()
		GC.cleanAll()
		self.EnemiesFolder = nil
	end
end

-- Hàm cập nhật trạng thái sảnh chờ
local function setInLobby(val)
	if inLobby == val then
		return
	end
	inLobby = val
	if val then
		disconnectFolderObservations()
		Controller:CleanUp()
	else
		Controller:updateSpringerAutoJumpState()
		Controller:ReapplyRespawnFeatures()
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

-- Khởi tạo ban đầu khi nạp script
if not inLobby then
	Controller:updateSpringerAutoJumpState()
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
if not inLobby then
	Controller:ReapplyRespawnFeatures()
end

local characterRefreshConnection = Players.LocalPlayer.CharacterAdded:Connect(function()
	scheduleRespawnFeatureRefresh()
end)
table.insert(Controller.PermanentConnections, characterRefreshConnection)

task.spawn(function()
	local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
	if Controller.Destroyed or not Controller.PermanentConnections then
		return
	end
	if inRoundVal and inRoundVal:IsA("BoolValue") then
		if not isControllerActiveOrUnclaimed(Controller) then
			pcall(function()
				Controller:CleanUp()
			end)
			return
		end
		claimActiveController(Controller)
		setInLobby(not inRoundVal.Value)

		local conn
		conn = inRoundVal.Changed:Connect(function(val)
			if Controller.Destroyed or not Controller.CleanUp then
				if conn then
					pcall(function()
						conn:Disconnect()
					end)
				end
				return
			end
			if not isControllerActiveOrUnclaimed(Controller) then
				pcall(function()
					Controller:CleanUp()
				end)
				if conn then
					pcall(function()
						conn:Disconnect()
					end)
				end
				return
			end
			claimActiveController(Controller)
			setInLobby(not val)
		end)
		table.insert(Controller.PermanentConnections, conn)
	end
end)

return Controller
