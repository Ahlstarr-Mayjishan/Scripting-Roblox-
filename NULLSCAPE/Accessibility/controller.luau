-- [[
--  NULLSCAPE - Accessibility Controller
--  Vai trò: Quản lý trạng thái và phối hợp các tính năng trợ năng (Accessibility) của hack.
-- ]]

local getgenv = getgenv
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

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

local SETTINGS_FOLDER = "NULLSCAPE"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/master_settings.json"
local ADAPT_INPUT_FLAG = "GrappleAdaptInputKeybind"

local function normalizeKeyName(key)
	local rawKey = tostring(key or "")
	local keyName = rawKey:match("%.([^%.]+)$") or rawKey
	if keyName == "" or keyName == "true" or keyName == "false" then
		return nil
	end

	return keyName
end

local function readSavedAdaptInputKey()
	if not (isfile and readfile and isfile(SETTINGS_FILE)) then
		return "T"
	end

	local success, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if not (success and type(decoded) == "table") then
		return "T"
	end

	return normalizeKeyName(decoded[ADAPT_INPUT_FLAG]) or "T"
end

local function writeSavedAdaptInputKey(keyName)
	if not (makefolder and writefile and readfile and isfile) then
		return
	end

	local data = {}
	if isfile(SETTINGS_FILE) then
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(SETTINGS_FILE))
		end)
		if success and type(decoded) == "table" then
			data = decoded
		end
	end

	data[ADAPT_INPUT_FLAG] = keyName

	pcall(function()
		makefolder(SETTINGS_FOLDER)
		writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
	end)
end

local Controller = {
	SpringerAutoJumpEnabled = false,
	InfiniteAirJumpEnabled = false,
	RailAssistSuiteEnabled = false,
	RailAutoEnabled = false,
	RailSpeedMultiplier = 1.1,
	RailAutoDelay = 1.5,
	RailAutoCaptureRange = 4,
	GrapplerStaminaMode = "Off",
	GrappleAssistSuiteEnabled = false,
	GrappleAimAssistEnabled = false,
	GrappleRescueAssistEnabled = false,
	GrappleEmergencyProtectionEnabled = false,
	GrappleVoidRescueEnabled = true,
	GrappleWallSlamRescueEnabled = false,
	GrappleEmergencyProtectionMode = "Manual",
	GrappleEmergencySpeedThreshold = 220,
	GrappleEmergencyFallThreshold = 125,
	GrappleAimAssistTargetPriority = "GrapplePoint",
	GrappleAimAssistRangePriority = "Nearest",
	GrappleAimAssistStrength = "Balanced",
	AntiBonkEnabled = false,
	GrappleSmartReelEnabled = false,
	GrappleSmartReelMode = "Manual",
	GrappleSharkTailHelperEnabled = false,
	GrappleSharkTailMode = "Manual",
	GrappleSharkTailStyle = "Balanced",
	GrappleMomentumGuardEnabled = false,
	GrappleAirControlMultiplier = 0,
	GrappleReelPullMultiplier = 1.1,
	GrappleSharkTailPullMultiplier = 1.1,
	GrappleJumpPadUsesBypassEnabled = false,
	GrappleAdaptInputKey = readSavedAdaptInputKey(),
	Destroyed = false,

	EnemiesFolder = nil,
	PermanentConnections = {},
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
	local finalCleanup = self.Destroyed or (globals.activeAccessibilityController ~= nil and globals.activeAccessibilityController ~= self)
	if finalCleanup then
		self.AntiBonkEnabled = false
		self.GrapplerStaminaMode = "Off"
		self.GrappleAssistSuiteEnabled = false
		self.GrappleAimAssistEnabled = false
		self.GrappleRescueAssistEnabled = false
		self.GrappleEmergencyProtectionEnabled = false
		self.GrappleSmartReelEnabled = false
		self.GrappleSharkTailHelperEnabled = false
		self.GrappleMomentumGuardEnabled = false
		self.GrappleJumpPadUsesBypassEnabled = false
		callExecutor("disableRailAssist")
		callExecutor("disableGrappleAimAssist")
		callExecutor("disableAntiBonk")
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
	if self.Destroyed and (not globals or globals.activeAccessibilityController == self or globals.activeAccessibilityController == nil) then
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

	self:RefreshGrappleAssistHook()
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
	self.RailAutoDelay = math.clamp(tonumber(value) or 1.5, 1.5, 3)
end

function Controller:SetRailAutoCaptureRange(value)
	self.RailAutoCaptureRange = math.clamp(tonumber(value) or 4, 1, 64)
end

function Controller:SetGrapplerStaminaMode(mode)
	local selectedMode = mode
	if typeof(selectedMode) == "table" then
		selectedMode = selectedMode[1]
	end
	selectedMode = tostring(selectedMode or "Off")

	if selectedMode ~= "Infinite Stamina" then
		selectedMode = "Off"
	end

	local previousMode = self.GrapplerStaminaMode
	self.GrapplerStaminaMode = selectedMode

	if not self:RefreshGrappleAssistHook() then
		self.GrapplerStaminaMode = previousMode or "Off"
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "Grapple module is not available yet",
				Duration = 3,
			})
		end
		return
	end

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = "Grappler stamina mode: " .. selectedMode,
			Duration = 2,
		})
	end
end

function Controller:HasAnyGrappleAssistFeature()
	return self.GrappleAimAssistEnabled
		or self.GrappleRescueAssistEnabled
		or self.GrappleEmergencyProtectionEnabled
		or (self.GrappleEmergencyProtectionEnabled and self.GrappleVoidRescueEnabled)
		or (self.GrappleEmergencyProtectionEnabled and self.GrappleWallSlamRescueEnabled)
		or self.GrappleSmartReelEnabled
		or self.GrappleSharkTailHelperEnabled
		or self.GrappleMomentumGuardEnabled
		or self.GrappleJumpPadUsesBypassEnabled
end

function Controller:RefreshGrappleAssistHook()
    if (self.GrappleAssistSuiteEnabled and self:HasAnyGrappleAssistFeature()) or self.GrapplerStaminaMode == "Infinite Stamina" then
        if not callExecutor("enableGrappleAimAssist") then
            return false
		end
	else
		callExecutor("disableGrappleAimAssist")
	end

    return true
end

function Controller:GetGrappleAssistHealthStatus()
    local method = Executor and Executor.getGrappleAimAssistHealthStatus
    if typeof(method) ~= "function" then
        return "Core pending"
    end

    local success, result = pcall(method)
    if not success then
        return "Core status error"
    end

    return tostring(result)
end

function Controller:SetGrappleAssistSuite(value)
    self.GrappleAssistSuiteEnabled = value == true

	if not self:RefreshGrappleAssistHook() then
		self.GrappleAssistSuiteEnabled = false
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "Grapple module is not available yet",
				Duration = 3,
			})
		end
		return
	end

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = (self.GrappleAssistSuiteEnabled and "Activated" or "Disabled") .. " Grapple Assist Suite",
			Duration = 2,
		})
	end
end

function Controller:SetGrappleAimAssist(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleAimAssistEnabled = value == true
	if self.GrappleAimAssistEnabled then
		self.GrappleAssistSuiteEnabled = true
	end

	if not self:RefreshGrappleAssistHook() then
		self.GrappleAimAssistEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "Grapple module is not available yet",
				Duration = 3,
			})
		end
		return
	end

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = (self.GrappleAimAssistEnabled and "Activated" or "Disabled") .. " Grapple Aim Assist",
			Duration = 2,
		})
	end
end

function Controller:SetGrappleRescueAssist(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleRescueAssistEnabled = value == true
	if self.GrappleRescueAssistEnabled then
		self.GrappleAssistSuiteEnabled = true
	end

	if not self:RefreshGrappleAssistHook() then
		self.GrappleRescueAssistEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleEmergencyProtection(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleEmergencyProtectionEnabled = value == true
	if self.GrappleEmergencyProtectionEnabled then
		self.GrappleAssistSuiteEnabled = true
	end

	if not self:RefreshGrappleAssistHook() then
		self.GrappleEmergencyProtectionEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleVoidRescue(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleVoidRescueEnabled = value == true
	if self.GrappleVoidRescueEnabled and self.GrappleEmergencyProtectionEnabled then
		self.GrappleAssistSuiteEnabled = true
	end

	if not self:RefreshGrappleAssistHook() then
		self.GrappleVoidRescueEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleWallSlamRescue(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	local previousEmergencyProtection = self.GrappleEmergencyProtectionEnabled
	self.GrappleWallSlamRescueEnabled = value == true
	if self.GrappleWallSlamRescueEnabled then
		self.GrappleAssistSuiteEnabled = true
		self.GrappleEmergencyProtectionEnabled = true
	end

	if not self:RefreshGrappleAssistHook() then
		self.GrappleWallSlamRescueEnabled = false
		self.GrappleEmergencyProtectionEnabled = previousEmergencyProtection
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleEmergencyProtectionMode(mode)
	local selected = mode
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "Manual")

	if selected ~= "Manual" and selected ~= "Smart Auto" and selected ~= "Automatic" then
		selected = "Manual"
	end

	self.GrappleEmergencyProtectionMode = selected
end

function Controller:SetGrappleEmergencySpeedThreshold(value)
	self.GrappleEmergencySpeedThreshold = math.clamp(tonumber(value) or 220, 150, 320)
end

function Controller:SetGrappleEmergencyFallThreshold(value)
	self.GrappleEmergencyFallThreshold = math.clamp(tonumber(value) or 125, 80, 220)
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

function Controller:SetGrappleSmartReel(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleSmartReelEnabled = value == true
	if self.GrappleSmartReelEnabled then
		self.GrappleAssistSuiteEnabled = true
	end
	if not self:RefreshGrappleAssistHook() then
		self.GrappleSmartReelEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleSharkTailHelper(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleSharkTailHelperEnabled = value == true
	if self.GrappleSharkTailHelperEnabled then
		self.GrappleAssistSuiteEnabled = true
	end
	if not self:RefreshGrappleAssistHook() then
		self.GrappleSharkTailHelperEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleMomentumGuard(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleMomentumGuardEnabled = value == true
	if self.GrappleMomentumGuardEnabled then
		self.GrappleAssistSuiteEnabled = true
	end
	if not self:RefreshGrappleAssistHook() then
		self.GrappleMomentumGuardEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleJumpPadUsesBypass(value)
	local previousSuite = self.GrappleAssistSuiteEnabled
	self.GrappleJumpPadUsesBypassEnabled = value == true
	if self.GrappleJumpPadUsesBypassEnabled then
		self.GrappleAssistSuiteEnabled = true
	end
	if not self:RefreshGrappleAssistHook() then
		self.GrappleJumpPadUsesBypassEnabled = false
		self.GrappleAssistSuiteEnabled = previousSuite
	end
end

function Controller:SetGrappleAirControlMultiplier(value)
	self.GrappleAirControlMultiplier = math.clamp(tonumber(value) or 0, 0, 10)
end

function Controller:SetGrappleReelPullMultiplier(value)
	self.GrappleReelPullMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

function Controller:SetGrappleSharkTailPullMultiplier(value)
	self.GrappleSharkTailPullMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

function Controller:SetGrappleAdaptInputKey(key)
	local keyName = normalizeKeyName(key)
	if keyName then
		self.GrappleAdaptInputKey = keyName
		writeSavedAdaptInputKey(keyName)
	end
end

function Controller:SetGrappleSmartReelMode(mode)
	local selected = mode
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "Manual")
	self.GrappleSmartReelMode = selected == "Automatic" and "Automatic" or "Manual"
end

function Controller:SetGrappleSharkTailMode(mode)
	local selected = mode
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "Manual")
	self.GrappleSharkTailMode = selected == "Automatic" and "Automatic" or "Manual"
end

function Controller:SetGrappleSharkTailStyle(style)
	local selected = style
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "Balanced")

	if selected ~= "Conservative" and selected ~= "Balanced" and selected ~= "Aggressive" and selected ~= "Emergency Only" then
		selected = "Balanced"
	end

	self.GrappleSharkTailStyle = selected
end

function Controller:SetGrappleAimAssistTargetPriority(option)
	local selected = option
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "GrapplePoint")

	if selected ~= "GrapplePoint" and selected ~= "JumpPad" and selected ~= "Bell" and selected ~= "TriaOrb" then
		selected = "GrapplePoint"
	end

	self.GrappleAimAssistTargetPriority = selected
end

function Controller:SetGrappleAimAssistRangePriority(option)
	local selected = option
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "Nearest")

	if selected ~= "Nearest" and selected ~= "Farthest" and selected ~= "Closest To Cursor" and selected ~= "Random" then
		selected = "Nearest"
	end

	self.GrappleAimAssistRangePriority = selected
end

function Controller:SetGrappleAimAssistStrength(option)
	local selected = option
	if typeof(selected) == "table" then
		selected = selected[1]
	end
	selected = tostring(selected or "Balanced")

	if selected ~= "Light" and selected ~= "Balanced" and selected ~= "Strong" and selected ~= "Motor Accessibility" then
		selected = "Balanced"
	end

	self.GrappleAimAssistStrength = selected
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
	local entitiesController = getgenv().loadModule("NULLSCAPE/Entities/controller.luau")
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
	local function refreshLater()
		if Controller.Destroyed then
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
