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
	local finalCleanup = self.Destroyed or (globals.activeAccessibilityController ~= nil and globals.activeAccessibilityController ~= self)
	if finalCleanup then
		self.AntiBonkEnabled = false
		self.GrapplerStaminaMode = "Off"
		self.StaminaMode = "Off"
		callExecutor("disableStaminaAssist")
		callExecutor("disableRailAssist")
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

function Controller:SetStaminaMode(mode)
	local selectedMode = mode
	if typeof(selectedMode) == "table" then
		selectedMode = selectedMode[1]
	end
	selectedMode = tostring(selectedMode or "Off")

	if selectedMode ~= "Infinite Stamina" then
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
