-- [[
--  NULLSCAPE - Accessibility Controller
--  Vai trò: Quản lý trạng thái và phối hợp các tính năng trợ năng (Accessibility) của hack.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Executor = getgenv().loadModule("NULLSCAPE/Accessibility/executor.luau")
local GC = getgenv().loadModule("NULLSCAPE/Accessibility/GC.luau")

local Controller = {
	SpringerAutoJumpEnabled = false,
	InfiniteAirJumpEnabled = false,
	RailAssistSuiteEnabled = false,
	RailAutoEnabled = false,
	RailSpeedMultiplier = 1.1,
	GrapplerStaminaMode = "Off",
	GrappleAssistSuiteEnabled = false,
	GrappleAimAssistEnabled = false,
	GrappleRescueAssistEnabled = false,
	GrappleAimAssistTargetPriority = "GrapplePoint",
	GrappleAimAssistRangePriority = "Nearest",
	GrappleAntiBonkEnabled = false,
	GrappleSmartReelEnabled = false,
	GrappleSmartReelMode = "Manual",
	GrappleSharkTailHelperEnabled = false,
	GrappleSharkTailMode = "Manual",
	GrappleMomentumGuardEnabled = false,
	GrappleAirControlMultiplier = 1.1,
	GrappleReelPullMultiplier = 1.1,
	GrappleSharkTailPullMultiplier = 1.1,
	GrappleJumpPadUsesBypassEnabled = false,
	GrappleAdaptInputKey = "T",
	Destroyed = false,

	EnemiesFolder = nil,
	PermanentConnections = {},
}

local _LocalPlayer = Players.LocalPlayer
local inLobby = true
local folderConnections = {}

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
	local globals = getgenv()._NULLSCAPE_Globals
	if self.Destroyed or (globals and globals.activeAccessibilityController ~= self) then
		Executor.disableRailAssist()
		Executor.disableGrappleAimAssist()
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
	if value and not Executor.initializeInfiniteAirJump() then
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

	self.InfiniteAirJumpEnabled = value

	if getgenv().Rayfield then
		getgenv().Rayfield:Notify({
			Title = "Accessibility Config",
			Content = (value and "Activated" or "Disabled") .. " Infinite Air Jump",
			Duration = 2,
		})
	end
end

function Controller:RefreshRailAssistHook()
	if self.RailAssistSuiteEnabled then
		if not Executor.enableRailAssist() then
			return false
		end
	else
		Executor.disableRailAssist()
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
		or self.GrappleAntiBonkEnabled
		or self.GrappleSmartReelEnabled
		or self.GrappleSharkTailHelperEnabled
		or self.GrappleMomentumGuardEnabled
		or self.GrappleJumpPadUsesBypassEnabled
end

function Controller:RefreshGrappleAssistHook()
	if (self.GrappleAssistSuiteEnabled and self:HasAnyGrappleAssistFeature()) or self.GrapplerStaminaMode == "Infinite Stamina" then
		if not Executor.enableGrappleAimAssist() then
			return false
		end
	else
		Executor.disableGrappleAimAssist()
	end

	return true
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
	self.GrappleAimAssistEnabled = value == true

	if not self:RefreshGrappleAssistHook() then
		self.GrappleAimAssistEnabled = false
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
	self.GrappleRescueAssistEnabled = value == true

	if not self:RefreshGrappleAssistHook() then
		self.GrappleRescueAssistEnabled = false
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Accessibility Config",
				Content = "Grapple module is not available yet",
				Duration = 3,
			})
		end
		return
	end
end

function Controller:SetGrappleAntiBonk(value)
	self.GrappleAntiBonkEnabled = value == true

	if not self:RefreshGrappleAssistHook() then
		self.GrappleAntiBonkEnabled = false
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
			Content = (self.GrappleAntiBonkEnabled and "Activated" or "Disabled") .. " Grapple Anti Bonk",
			Duration = 2,
		})
	end
end

function Controller:SetGrappleSmartReel(value)
	self.GrappleSmartReelEnabled = value == true
	if not self:RefreshGrappleAssistHook() then
		self.GrappleSmartReelEnabled = false
	end
end

function Controller:SetGrappleSharkTailHelper(value)
	self.GrappleSharkTailHelperEnabled = value == true
	if not self:RefreshGrappleAssistHook() then
		self.GrappleSharkTailHelperEnabled = false
	end
end

function Controller:SetGrappleMomentumGuard(value)
	self.GrappleMomentumGuardEnabled = value == true
	if not self:RefreshGrappleAssistHook() then
		self.GrappleMomentumGuardEnabled = false
	end
end

function Controller:SetGrappleJumpPadUsesBypass(value)
	self.GrappleJumpPadUsesBypassEnabled = value == true
	if not self:RefreshGrappleAssistHook() then
		self.GrappleJumpPadUsesBypassEnabled = false
	end
end

function Controller:SetGrappleAirControlMultiplier(value)
	self.GrappleAirControlMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

function Controller:SetGrappleReelPullMultiplier(value)
	self.GrappleReelPullMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

function Controller:SetGrappleSharkTailPullMultiplier(value)
	self.GrappleSharkTailPullMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

function Controller:SetGrappleAdaptInputKey(key)
	local rawKey = tostring(key or "")
	local keyName = rawKey:match("%.([^%.]+)$") or rawKey
	if keyName ~= "" and keyName ~= "true" and keyName ~= "false" then
		self.GrappleAdaptInputKey = keyName
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

local function handleSpringerShockwave(enemy, child)
	if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
		Executor.setupAutoJump(enemy, child, Controller, GC)
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
		if getgenv()._NULLSCAPE_Globals.activeAccessibilityController ~= Controller then
			Controller:CleanUp()
			return
		end
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
	end
end

-- Đăng ký active controller hiện tại để tự động dừng các phiên bản cũ
getgenv()._NULLSCAPE_Globals.activeAccessibilityController = Controller

-- Khởi tạo ban đầu khi nạp script
if not inLobby then
	Controller:updateSpringerAutoJumpState()
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
	local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
	if inRoundVal and inRoundVal:IsA("BoolValue") then
		if getgenv()._NULLSCAPE_Globals.activeAccessibilityController ~= Controller then
			Controller:CleanUp()
			return
		end
		setInLobby(not inRoundVal.Value)

		local conn = inRoundVal.Changed:Connect(function(val)
			if Controller.Destroyed then
				return
			end
			if getgenv()._NULLSCAPE_Globals.activeAccessibilityController ~= Controller then
				Controller:CleanUp()
				return
			end
			setInLobby(not val)
		end)
		table.insert(Controller.PermanentConnections, conn)
	end
end)

return Controller
