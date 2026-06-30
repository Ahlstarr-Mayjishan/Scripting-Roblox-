-- [[
--  NULLSCAPE - Entities Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local getgenv = getgenv
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local activeCallbacks = {}

local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")
local SpecialImmunity = getgenv().loadModule("NULLSCAPE/Entities/SpecialImmunity.luau")
local Executor = {
	enableImmunity = function(gc, enemy)
		if TouchInterest then
			TouchInterest.enableImmunity(gc, enemy)
		end
	end,
	disableImmunityForType = function(gc, entityName)
		if TouchInterest then
			TouchInterest.disableImmunityForType(gc, entityName)
		end
		if SpecialImmunity then
			SpecialImmunity.disableForType(entityName)
		end
	end,
	restoreAll = function(gc)
		if TouchInterest then
			TouchInterest.restoreAll(gc)
		end
		if SpecialImmunity then
			SpecialImmunity.disable()
		end
	end,
	enableSpecialImmunity = function()
		if SpecialImmunity then
			return SpecialImmunity.enable()
		end
	end,
	disableSpecialImmunityForType = function(entityName)
		if SpecialImmunity then
			SpecialImmunity.disableForType(entityName)
		end
	end,
	disableSpecialImmunity = function()
		if SpecialImmunity then
			SpecialImmunity.disable()
		end
	end,
}
local HuskEvasion = getgenv().loadModule("NULLSCAPE/Entities/HuskEvasion.luau")
local RemoteBlocking = getgenv().loadModule("NULLSCAPE/Entities/RemoteBlocking.luau")
local GC = getgenv().loadModule("NULLSCAPE/Entities/GC.luau")
local BackTrick = getgenv().loadModule("NULLSCAPE/Entities/technique/BackTrick (TeleFragger).luau")

local hookedTelefraggers = setmetatable({}, { __mode = "k" })

local Controller = {
	-- Trạng thái bật/tắt miễn nhiễm cho từng thực thể
	BabyImmune = false,
	BellImmune = false,
	BellCurseImmune = false,
	BellBlindnessImmune = false,
	FleshImmune = false,
	MartImmune = false,
	TelefraggerImmune = false,
	ICBMImmune = false,
	ICBMBurnImmune = false,
	GuardianImmune = false,
	OperatorImmune = false,
	SpringerImmune = false,
	SkinwalkerImmune = false,
	KolonaImmune = false,
	OblivionImmune = false,
	ShadowBabyImmune = false,
	QuartzImmune = false,
	SigilImmune = false,
	SlicerImmune = false,
	VoidbreakerImmune = false,
	RazorbloomImmune = false,
	CadenceImmune = false,
	VoidImplosionImmune = false,
	CelestialImmune = false,
	ScrapmawImmune = false,
	CatalystImmune = false,
	nilEnemyImmune = false,
	nilMirageImmune = false,
	SeamineImmune = false,
	TelefraggerAutoDodge = false,
	TelefraggerBackTrick = false,
	TelefraggerBackTrickMode = "180",
	TelefraggerDesyncDelay = 0.44,
	TelefraggerActiveThreads = {},
	TelefraggerActiveDesyncs = {},
	TelefraggerConnection = nil,
	WasRedirectingTelefragger = false,
	RedirectRootJoint = nil,
	RedirectOriginalC0 = nil,
	SpringerImmunityMode = "Blatant",
	Destroyed = false,

	EnemiesFolder = nil,
	PermanentConnections = {},
	StartSkinwalkerEvasion = nil,
	CadenceUI = nil,
	CadenceStatusLabel = nil,
	CadenceUIFrame = nil,
}
GC.Controller = Controller

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

local function debugPrint(...)
	-- Không in debug theo yêu cầu của người dùng
	return select("#", ...)
end

local function createCadenceUI()
	if Controller.CadenceUI then
		return
	end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "CadenceStatusGui"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local CoreGui = game:GetService("CoreGui")
	local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

	local parent = CoreGui
	local success, _ = pcall(function()
		ScreenGui.Parent = parent
	end)
	if not success then
		ScreenGui.Parent = PlayerGui
	end

	local Frame = Instance.new("Frame")
	Frame.Name = "MainFrame"
	Frame.Size = UDim2.fromOffset(220, 80)
	Frame.Position = UDim2.new(0.5, -110, 0.1, 0)
	Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	Frame.BackgroundTransparency = 0.2
	Frame.BorderSizePixel = 0
	Frame.Active = true
	Frame.Draggable = true
	Frame.Parent = ScreenGui

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0, 10)
	UICorner.Parent = Frame

	local UIStroke = Instance.new("UIStroke")
	UIStroke.Color = Color3.fromRGB(80, 80, 80)
	UIStroke.Thickness = 1.5
	UIStroke.Parent = Frame

	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.Name = "TitleLabel"
	TitleLabel.Size = UDim2.fromScale(1, 0.4)
	TitleLabel.Position = UDim2.fromScale(0, 0.05)
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Text = "CADENCE STATUS"
	TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TitleLabel.TextSize = 13
	TitleLabel.Font = Enum.Font.GothamBold
	TitleLabel.Parent = Frame

	local StatusLabel = Instance.new("TextLabel")
	StatusLabel.Name = "StatusLabel"
	StatusLabel.Size = UDim2.fromScale(1, 0.5)
	StatusLabel.Position = UDim2.fromScale(0, 0.45)
	StatusLabel.BackgroundTransparency = 1
	StatusLabel.Text = "Not Active"
	StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	StatusLabel.TextSize = 16
	StatusLabel.Font = Enum.Font.GothamMedium
	StatusLabel.Parent = Frame

	Controller.CadenceUI = ScreenGui
	Controller.CadenceStatusLabel = StatusLabel
	Controller.CadenceUIFrame = Frame
end

local function getAccessibilityController()
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and globals.activeAccessibilityController then
		return globals.activeAccessibilityController
	end

	return nil
end

local inLobby = not isInMatch() -- Đang ở sảnh chờ/lựa chọn (Khởi tạo ban đầu)
Controller.inLobby = inLobby
local hasInRoundValue = false
local folderConnections = {} -- key: folder -> value: list of connections
local workspaceConnections = {} -- list of workspace-level connections
local processedEntities = setmetatable({}, { __mode = "k" })
local originalTouchStates = setmetatable({}, { __mode = "k" })

-- Ngắt các kết nối quan sát thư mục và workspace
local function disconnectFolderObservations()
	table.clear(processedEntities)
	for _, conn in ipairs(workspaceConnections) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	table.clear(workspaceConnections)

	for _, conns in pairs(folderConnections) do
		for _, conn in ipairs(conns) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
	end
	table.clear(folderConnections)
end

local function restoreHooks()
	local globals = getgenv()._NULLSCAPE_Globals
	if not globals then
		return
	end

	-- Restore namecall
	if globals.NamecallHooked and globals.OriginalNamecall then
		if typeof(hookmetamethod) == "function" then
			pcall(hookmetamethod, game, "__namecall", globals.OriginalNamecall)
		end
		globals.NamecallHooked = nil
		globals.OriginalNamecall = nil
	end

	-- Restore prototype hooks
	-- WARNING: DO NOT call hookfunction on RemoteEvent/RemoteFunction prototypes as it crashes the client!
	-- Instead, we just let them pass through since handleEntitiesRemoteCall is cleared during cleanup.
	if globals.PrototypeHooked then
		globals.PrototypeHooked = nil
		globals.OriginalFireServer = nil
		globals.OriginalInvokeServer = nil
	end

	-- Restore StatusEffect connection hook
	-- WARNING: DO NOT call hookfunction on OnClientEvent.Connect prototype.
	if globals.StatusEffectHooked then
		globals.StatusEffectHooked = nil
		globals.StatusEffectLoopToken = nil
		globals.OriginalOnClientEventConnect = nil

		-- Restore StatusEffectHandler.HasStatus (safe Lua table assignment)
		if globals.OriginalHasStatus then
			local ReplicatedFirst = game:GetService("ReplicatedFirst")
			local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
			local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
			if handlerModule and handlerModule:IsA("ModuleScript") then
				local success, StatusEffectHandler = pcall(require, handlerModule)
				if success and typeof(StatusEffectHandler) == "table" then
					StatusEffectHandler.HasStatus = globals.OriginalHasStatus
				end
			end
			globals.OriginalHasStatus = nil
		end
	end

	-- Restore SettingsHandler hooks
	if globals.SettingsHooked then
		local ReplicatedFirst = game:GetService("ReplicatedFirst")
		local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		local core = clientModules and clientModules:FindFirstChild("Core")
		local playerData = core and core:FindFirstChild("PlayerData")
		local settingsModule = playerData and playerData:FindFirstChild("SettingsHandler")
		if settingsModule and settingsModule:IsA("ModuleScript") then
			local SettingsHandler = require(settingsModule)
			if typeof(SettingsHandler) == "table" then
				if globals.OriginalSettingsGet then
					SettingsHandler.Get = globals.OriginalSettingsGet
				end
				if globals.OriginalGetSettings then
					SettingsHandler.GetSettings = globals.OriginalGetSettings
				end
			end
		end
		globals.SettingsHooked = nil
		globals.OriginalSettingsGet = nil
		globals.OriginalGetSettings = nil
	end
end

function Controller:SetTelefraggerAutoDodge(value)
	self.TelefraggerAutoDodge = value
	self:UpdateTelefraggerConnection()
end

function Controller:SetTelefraggerBackTrick(value)
	self.TelefraggerBackTrick = value
	self:UpdateTelefraggerConnection()
end

function Controller:SetTelefraggerBackTrickMode(value)
	self.TelefraggerBackTrickMode = value
end

function Controller:SetTelefraggerDesyncDelay(value)
	self.TelefraggerDesyncDelay = value
end

function Controller:SetSeamineImmune(value)
	self.SeamineImmune = value
end

function Controller:SetICBMBurnImmune(value)
	self.ICBMBurnImmune = value
end

function Controller:SetBellCurseImmune(value)
	self.BellCurseImmune = value
end

function Controller:SetBellBlindnessImmune(value)
	self.BellBlindnessImmune = value
end

function Controller:UpdateTelefraggerConnection()
	if self.TelefraggerConnection then
		pcall(function()
			self.TelefraggerConnection:Disconnect()
		end)
		self.TelefraggerConnection = nil
	end

	-- Khôi phục trạng thái xoay khớp nếu BackTrick bị tắt
	if not self.TelefraggerBackTrick and self.WasRedirectingTelefragger then
		BackTrick.revert(self)
	end

	if not self.TelefraggerAutoDodge then
		return
	end

	local RunService = game:GetService("RunService")
	local LocalPlayer = game.Players.LocalPlayer

	-- Helper: Tính khoảng cách ngắn nhất từ điểm P đến đoạn thẳng AB
	local function getDistanceToSegment(p, a, b)
		local ab = b - a
		local ap = p - a
		local abLenSq = ab:Dot(ab)
		if abLenSq < 1e-5 then
			return (p - a).Magnitude, a
		end
		local t = ap:Dot(ab) / abLenSq
		t = math.clamp(t, 0, 1)
		local closest = a + t * ab
		return (p - closest).Magnitude, closest
	end

	-- Helper: Kiểm tra vị trí sàn an toàn để tránh né xuống vực
	local function isFloorSafe(pos)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { LocalPlayer.Character }
		local rayResult = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -15, 0), raycastParams)
		return rayResult ~= nil
	end

	self.TelefraggerConnection = RunService.Heartbeat:Connect(function(dt)
		local char = LocalPlayer.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if not (humanoid and rootPart and humanoid.Health > 0) then
			return
		end

		local enemiesFolder = workspace:FindFirstChild("Enemies")
		if not enemiesFolder then
			return
		end

		local dangerSegment = nil
		local minSegmentDist = math.huge

		-- Quét tất cả các chỉ thị (Indicator) hoạt động của Telefragger ở cự ly gần
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			if string.find(string.lower(enemy.Name), "telefragger") then
				local indicatorPart = enemy:FindFirstChild("IndicatorPart", true)
				if indicatorPart then
					local attachments = {}
					for _, child in ipairs(indicatorPart:GetChildren()) do
						if child:IsA("Attachment") then
							table.insert(attachments, child)
						end
					end
					-- Attachment và Attachment2 được sinh ra ở client biểu diễn vị trí bắt đầu và kết thúc của cú dash/teleport
					if #attachments >= 2 then
						local startPos = attachments[1].WorldPosition
						local endPos = attachments[2].WorldPosition
						local dist, closest = getDistanceToSegment(rootPart.Position, startPos, endPos)
						if dist < 15 and dist < minSegmentDist then
							minSegmentDist = dist
							dangerSegment = { Start = startPos, End = endPos, Closest = closest }
						end
					end
				end
			end
		end

		-- 2. Xử lý cơ chế Auto-Dodge (Né tránh di chuyển tịnh tiến sang ngang ra khỏi đường dash đỏ)
		if self.TelefraggerAutoDodge and dangerSegment then
			local startPos = dangerSegment.Start
			local endPos = dangerSegment.End
			local dir = (endPos - startPos).Unit
			local perp = Vector3.new(-dir.Z, 0, dir.X).Unit

			local moveDir = humanoid.MoveDirection
			local slideDir = perp
			if moveDir.Magnitude > 0.1 then
				if moveDir:Dot(perp) < 0 then
					slideDir = -perp
				end
			else
				local camera = workspace.CurrentCamera
				if camera then
					if camera.CFrame.RightVector:Dot(perp) < 0 then
						slideDir = -perp
					end
				end
			end

			-- Thực hiện di chuyển né tránh (Auto-Dodge) bằng cách tịnh tiến mượt mà CFrame sang ngang
			local speed = 32 -- studs/giây (rất mượt mà như cú trượt chân nhẹ, không bị giật hoặc tele)
			local nextPos = rootPart.Position + slideDir * (dt * speed)
			
			if isFloorSafe(nextPos) then
				rootPart.CFrame = rootPart.CFrame + slideDir * (dt * speed)
			else
				local altPos = rootPart.Position - slideDir * (dt * speed)
				if isFloorSafe(altPos) then
					rootPart.CFrame = rootPart.CFrame - slideDir * (dt * speed)
				else
					-- Dự phòng: Nếu hai bên đều là vực thẳm, di chuyển giật lùi dọc theo đường dash
					local backPos = rootPart.Position - dir * (dt * speed)
					if isFloorSafe(backPos) then
						rootPart.CFrame = rootPart.CFrame - dir * (dt * speed)
					end
				end
			end
		end
	end)
end

function Controller:TriggerSilentBackTrick(enemy)
	if not enemy then return end

	-- Hủy luồng chờ cũ của Telefragger này nếu có
	if self.TelefraggerActiveThreads[enemy] then
		pcall(task.cancel, self.TelefraggerActiveThreads[enemy])
		self.TelefraggerActiveThreads[enemy] = nil
	end

	self.TelefraggerActiveThreads[enemy] = task.delay(self.TelefraggerDesyncDelay or 0.44, function()
		self.TelefraggerActiveThreads[enemy] = nil
		
		-- Thêm vào danh sách đang desync active
		local wasEmpty = (next(self.TelefraggerActiveDesyncs) == nil)
		self.TelefraggerActiveDesyncs[enemy] = true
		
		if wasEmpty then
			BackTrick.trigger(self)
		end
	end)
end

function Controller:CancelSilentBackTrick(enemy)
	if not enemy then return end

	-- Hủy luồng chờ nếu chưa kích hoạt desync
	if self.TelefraggerActiveThreads[enemy] then
		pcall(task.cancel, self.TelefraggerActiveThreads[enemy])
		self.TelefraggerActiveThreads[enemy] = nil
	end

	-- Xóa khỏi danh sách active
	if self.TelefraggerActiveDesyncs[enemy] then
		self.TelefraggerActiveDesyncs[enemy] = nil
		
		-- Nếu không còn thực thể nào đang desync thì khôi phục nhân vật
		if next(self.TelefraggerActiveDesyncs) == nil then
			BackTrick.revert(self)
		end
	end
end

-- Hàm dọn dẹp tài nguyên (Garbage Collection - GC) giải phóng bộ nhớ
function Controller:CleanUp()
	-- Hủy tất cả các luồng chờ và dọn dẹp danh sách active
	for enemy, thread in pairs(self.TelefraggerActiveThreads) do
		pcall(task.cancel, thread)
	end
	table.clear(self.TelefraggerActiveThreads)
	table.clear(self.TelefraggerActiveDesyncs)

	pcall(function()
		BackTrick.cleanup(self)
	end)

	for part, state in pairs(originalTouchStates) do
		pcall(function()
			part.CanTouch = state
		end)
	end
	table.clear(originalTouchStates)

	disconnectFolderObservations()
	pcall(function()
		Executor.disableSpecialImmunity()
	end)

	if self.TelefraggerRedirectConnection then
		pcall(function()
			self.TelefraggerRedirectConnection:Disconnect()
		end)
		self.TelefraggerRedirectConnection = nil
	end
	if self.TelefraggerConnection then
		pcall(function()
			self.TelefraggerConnection:Disconnect()
		end)
		self.TelefraggerConnection = nil
	end
	if self.WasRedirectingTelefragger then
		BackTrick.revert(self)
	end

	GC.cleanAll()
	self.EnemiesFolder = nil

	if self.CadenceUI then
		pcall(function()
			self.CadenceUI:Destroy()
		end)
		self.CadenceUI = nil
		self.CadenceStatusLabel = nil
		self.CadenceUIFrame = nil
	end

	-- Nếu bị hủy hoàn toàn (Destroyed = true), giải phóng các kết nối vĩnh viễn
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

	if self.Destroyed then
		pcall(restoreHooks)
	end

	-- Keep the active controller during lobby cleanup; only full destroy may release it.
	local globals = getgenv()._NULLSCAPE_Globals
	if self.Destroyed and globals and globals.activeEntitiesController == self then
		globals.activeEntitiesController = nil
	end
end

local disabledShockwaves = {}

local SPECIAL_IMMUNITY_FLAGS = {
	Kolona = "KolonaImmune",
	Oblivion = "OblivionImmune",
	ShadowBaby = "ShadowBabyImmune",
	Quartz = "QuartzImmune",
	Sigil = "SigilImmune",
	Slicer = "SlicerImmune",
	Voidbreaker = "VoidbreakerImmune",
	Razorbloom = "RazorbloomImmune",
	VoidImplosion = "VoidImplosionImmune",
}

local function isSpecialImmunityEntity(entityName)
	return SPECIAL_IMMUNITY_FLAGS[entityName] ~= nil
end

local function isAnySpecialImmunityEnabled()
	for _, flag in pairs(SPECIAL_IMMUNITY_FLAGS) do
		if Controller[flag] == true then
			return true
		end
	end
	return false
end

local function restoreShockwave(part)
	local data = disabledShockwaves[part]
	if data then
		if data.conn1 then
			pcall(function()
				data.conn1:Disconnect()
			end)
		end
		if data.conn2 then
			pcall(function()
				data.conn2:Disconnect()
			end)
		end
		pcall(function()
			part.CanTouch = data.originalCanTouch
		end)
		pcall(function()
			part.CanCollide = data.originalCanCollide
		end)
		disabledShockwaves[part] = nil
	end
end

local function disableShockwave(enemy, part)
	if not part then
		return
	end
	if disabledShockwaves[part] then
		return
	end

	local originalCanTouch = part.CanTouch
	local originalCanCollide = part.CanCollide

	part.CanTouch = false
	part.CanCollide = false

	local conn1 = part:GetPropertyChangedSignal("CanTouch"):Connect(function()
		if part.CanTouch then
			part.CanTouch = false
		end
	end)

	local conn2 = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
		if part.CanCollide then
			part.CanCollide = false
		end
	end)

	disabledShockwaves[part] = {
		conn1 = conn1,
		conn2 = conn2,
		originalCanTouch = originalCanTouch,
		originalCanCollide = originalCanCollide,
		enemy = enemy,
	}
end

-- Thiết lập cấu hình miễn nhiễm và kích hoạt dọn dẹp tức thời
function Controller:SetImmunity(entityName, value)
	debugPrint("SetImmunity called for:", entityName, "| value:", value)
	if entityName == "Baby" then
		self.BabyImmune = value
	elseif entityName == "Bell" then
		self.BellImmune = value
	elseif entityName == "Flesh" then
		self.FleshImmune = value
	elseif entityName == "Mart" then
		self.MartImmune = value
	elseif entityName == "Telefragger" or entityName == "Tele" then
		self.TelefraggerImmune = value
	elseif entityName == "ICBM" then
		self.ICBMImmune = value
	elseif entityName == "Guardian" then
		self.GuardianImmune = value
		if value then
			Executor.enableSpecialImmunity()
		else
			Executor.disableSpecialImmunityForType("Guardian")
		end
	elseif entityName == "Operator" then
		self.OperatorImmune = value
	elseif entityName == "Skinwalker" then
		self.SkinwalkerImmune = value
	elseif entityName == "Springer" then
		self.SpringerImmune = value

		-- Thông báo cho Accessibility controller cập nhật lại trạng thái Auto Jump
		local accessibilityController = getAccessibilityController()
		if accessibilityController and accessibilityController.updateSpringerAutoJumpState then
			pcall(function()
				accessibilityController:updateSpringerAutoJumpState()
			end)
		end
	elseif entityName == "Cadence" then
		self.CadenceImmune = value
	elseif entityName == "Celestial" then
		self.CelestialImmune = value
	elseif entityName == "Scrapmaw" then
		self.ScrapmawImmune = value
	elseif entityName == "Catalyst" then
		self.CatalystImmune = value
	elseif entityName == "nilEnemy" then
		self.nilEnemyImmune = value
	elseif entityName == "nilMirage" then
		self.nilMirageImmune = value
	elseif isSpecialImmunityEntity(entityName) then
		self[SPECIAL_IMMUNITY_FLAGS[entityName]] = value == true
		if value then
			Executor.enableSpecialImmunity()
		end
	end

	-- Áp dụng thay đổi tức thời cho thực thể đã tồn tại trong workspace
	if value then
		local function applyImmunityToChild(child)
			if not (child:IsA("Model") or child:IsA("BasePart")) then
				return
			end

			-- Husk / Skinwalker dùng module HuskEvasion mới
			if entityName == "Skinwalker" then
				local isHusk = (string.find(child.Name, "Skinwalker") or string.find(child.Name, "Husk"))
					and child.Name ~= "Skinwalkers"
				if isHusk then
					HuskEvasion.enableHuskImmunity(GC, child)
				end
				return
			end

			-- Baby / Bell / Mart dùng module TouchInterest Types
			local isTarget = string.find(string.lower(child.Name), string.lower(entityName))
			debugPrint("applyImmunityToChild check for target:", child.Name, "| isTarget:", isTarget ~= nil)
			if isTarget then
				Executor.enableImmunity(GC, child)
			end

			if
				entityName == "Springer"
				and string.find(child.Name, "Springer")
				and self.SpringerImmunityMode == "Blatant"
			then
				for _, subChild in ipairs(child:GetChildren()) do
					if subChild.Name == "SpringerShockwave" or subChild.Name == "DemonShockwave" then
						disableShockwave(child, subChild)
					end
				end
			end

			if isSpecialImmunityEntity(entityName) then
				Executor.enableSpecialImmunity()
			end
		end

		if self.EnemiesFolder then
			for _, child in ipairs(self.EnemiesFolder:GetChildren()) do
				applyImmunityToChild(child)
			end
		end
		local skinwalkersFolder = workspace:FindFirstChild("Skinwalkers")
		if skinwalkersFolder and skinwalkersFolder:IsA("Folder") then
			for _, child in ipairs(skinwalkersFolder:GetChildren()) do
				applyImmunityToChild(child)
			end
		end
	else
		if entityName == "Guardian" then
			Executor.disableImmunityForType(GC, "Guardian")
			Executor.disableImmunityForType(GC, "ShadowGuardian")
		elseif
			entityName == "Baby"
			or entityName == "Bell"
			or entityName == "Flesh"
			or entityName == "Mart"
			or entityName == "Telefragger"
			or entityName == "Tele"
			or entityName == "ShadowGuardian"
			or entityName == "Sigil"
			or entityName == "Cadence"
			or entityName == "Catalyst"
			or entityName == "nilEnemy"
			or entityName == "nilMirage"
		then
			Executor.disableImmunityForType(GC, entityName)
		elseif entityName == "Skinwalker" then
			HuskEvasion.disableHuskImmunity(GC)
		end
		if entityName == "Springer" then
			for part in pairs(disabledShockwaves) do
				restoreShockwave(part)
			end
		end
		if isSpecialImmunityEntity(entityName) then
			Executor.disableSpecialImmunityForType(entityName)
			if isAnySpecialImmunityEnabled() then
				Executor.enableSpecialImmunity()
			else
				Executor.disableSpecialImmunity()
			end
		end
	end
end

-- Cấu hình chế độ bảo vệ Springer (Blatant: tắt hẳn sóng, Legit: giữ lại lực đẩy sóng)
function Controller:SetSpringerImmunityMode(mode)
	self.SpringerImmunityMode = mode

	-- Thông báo cho Accessibility controller cập nhật lại trạng thái Auto Jump
	local accessibilityController = getAccessibilityController()
	if accessibilityController and accessibilityController.updateSpringerAutoJumpState then
		pcall(function()
			accessibilityController:updateSpringerAutoJumpState()
		end)
	end

	if mode == "Blatant" then
		local StatusImmunity = getgenv().loadModule("NULLSCAPE/Entities/StatusImmunity.luau")
		if StatusImmunity then
			StatusImmunity.removeAllStatuses()
		end
	end

	if self.SpringerImmune then
		if mode == "Blatant" then
			-- Tắt toàn bộ sóng đang tồn tại
			if self.EnemiesFolder then
				for _, enemy in ipairs(self.EnemiesFolder:GetChildren()) do
					if string.find(enemy.Name, "Springer") then
						for _, child in ipairs(enemy:GetChildren()) do
							if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
								disableShockwave(enemy, child)
							end
						end
					end
				end
			end
		else
			-- Legit: Khôi phục lại toàn bộ sóng để có lực đẩy
			for part in pairs(disabledShockwaves) do
				restoreShockwave(part)
			end
		end
	end
end

function Controller:SetSpringerKnockbackImmune(enabled)
	if enabled then
		if self.EnemiesFolder then
			for _, enemy in ipairs(self.EnemiesFolder:GetChildren()) do
				if string.find(enemy.Name, "Springer") then
					for _, child in ipairs(enemy:GetChildren()) do
						if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
							disableShockwave(enemy, child)
						end
					end
				end
			end
		end
	else
		if not (self.SpringerImmune and self.SpringerImmunityMode == "Blatant") then
			for part in pairs(disabledShockwaves) do
				restoreShockwave(part)
			end
		end
	end
end

function Controller:SetBellKnockbackImmune(enabled)
	if enabled then
		if self.EnemiesFolder then
			for _, enemy in ipairs(self.EnemiesFolder:GetChildren()) do
				if string.find(enemy.Name, "Bell") then
					TouchInterest.enableImmunity(GC, enemy)
				end
			end
		end
	else
		if not self.BellImmune then
			TouchInterest.disableImmunityForType(GC, "Bell")
		end
	end
end

function Controller:DisableShockwave(enemy, part)
	disableShockwave(enemy, part)
end

function Controller:RestoreSpringerShockwaves()
	for part in pairs(disabledShockwaves) do
		restoreShockwave(part)
	end
end

function Controller:StartSkinwalkerEvasion() end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function findNativeEnemyESPTemplate()
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and globals.EntitiesNativeEnemyESPTemplate and globals.EntitiesNativeEnemyESPTemplate.Parent then
		return globals.EntitiesNativeEnemyESPTemplate
	end
	if
		globals
		and globals.EntitiesNativeEnemyESPTemplateMissAt
		and time() - globals.EntitiesNativeEnemyESPTemplateMissAt < 2
	then
		return nil
	end

	local function searchDescendantsBudgeted(root, maxDescendants)
		if not root then
			return nil
		end

		local stack = root:GetChildren()
		local scanned = 0
		while #stack > 0 and scanned < maxDescendants do
			local inst = table.remove(stack)
			if inst and inst.Parent then
				scanned = scanned + 1
				if (inst.Name == "ESP" or inst.Name == "ESPCrayon") and inst:IsA("BillboardGui") then
					return inst
				end

				local children = inst:GetChildren()
				for i = #children, 1, -1 do
					table.insert(stack, children[i])
				end
			end
		end

		return nil
	end

	local players = game:GetService("Players")
	local localPlayer = players.LocalPlayer
	local playerScripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
	local template = searchDescendantsBudgeted(playerScripts, 2500)
	if not template then
		template = searchDescendantsBudgeted(workspace:FindFirstChild("Enemies"), 2500)
	end
	if not template then
		local starterPlayer = game:GetService("StarterPlayer")
		template =
			searchDescendantsBudgeted(starterPlayer and starterPlayer:FindFirstChild("StarterPlayerScripts"), 2500)
	end
	if template then
		if globals then
			globals.EntitiesNativeEnemyESPTemplate = template
		end
		return template
	end

	if globals then
		globals.EntitiesNativeEnemyESPTemplateMissAt = time()
	end
	return nil
end

local function getEnemyDisplayName(enemy)
	local nameLower = enemy.Name:lower()
	if nameLower == "shadowguardian" then
		return "voidboundguardian"
	elseif nameLower == "shadowbaby" then
		return "voidboundbaby"
	elseif nameLower == "skinwalker" then
		return "husk"
	elseif nameLower == "mirage" then
		return "???"
	end
	return nameLower
end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function processEntity(enemy)
	if not enemy or not (enemy:IsA("Model") or enemy:IsA("BasePart")) or enemy.Name == "Skinwalkers" then
		return
	end
	if processedEntities[enemy] or (GC.EntityConnections and GC.EntityConnections[enemy]) then
		return
	end
	processedEntities[enemy] = true

	if enemy:IsA("Model") then
		-- Tự động đổi Adornee của ESP / ESPCrayon sang PrimaryPart để tránh lỗi hiển thị khi Adornee là Model không có PrimaryPart từ server
		local function onChildAdded(child)
			if child.Name == "ESP" or child.Name == "ESPCrayon" then
				if child:IsA("BillboardGui") then
					-- Fix horizontal stretched border for Springer instantly to prevent visual glitches
					if string.find(enemy.Name:lower(), "springer") then
						pcall(function()
							child.Size = UDim2.fromScale(4, 4)
							local function formatSquare(obj)
								if obj:IsA("GuiObject") then
									obj.Size = UDim2.fromScale(1, 1)
									if obj:IsA("Frame") then
										obj.Position = UDim2.new(0, 0, 0, 0)
									end
								elseif obj:IsA("UIAspectRatioConstraint") then
									obj.AspectRatio = 1
								end
							end
							for _, desc in ipairs(child:GetDescendants()) do
								formatSquare(desc)
							end
							child.DescendantAdded:Connect(formatSquare)
						end)
					end

					task.spawn(function()
						-- Wait for physical parts of the enemy model to replicate/load (up to 3 seconds)
						local rootPart = nil
						for _ = 1, 60 do
							if not enemy or not enemy.Parent then
								return
							end
							rootPart = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart", true)
							if rootPart then
								break
							end
							task.wait(0.05)
						end

						if rootPart then
							if child.Adornee == enemy or child.Adornee == nil then
								pcall(function()
									child.Adornee = rootPart
								end)
							end

							-- Defensively hide native ESP when enemy is spawning far below the map (Y < -50)
							local function updateVisibility()
								if not rootPart or not rootPart.Parent then
									return
								end
								local isBelowMap = rootPart.Position.Y < -50
								pcall(function()
									child.Enabled = not isBelowMap
								end)
							end

							updateVisibility()
							local posConn = rootPart:GetPropertyChangedSignal("Position"):Connect(updateVisibility)
							child.Destroying:Connect(function()
								posConn:Disconnect()
							end)
						end
					end)
				end
			end
		end

		local conn = enemy.ChildAdded:Connect(onChildAdded)
		if GC.registerEntityConnection then
			GC.registerEntityConnection(enemy, conn)
		end

		for _, child in ipairs(enemy:GetChildren()) do
			onChildAdded(child)
		end

		task.spawn(function()
			-- Tìm kiếm đệ quy phần đầu hoặc phần thân khả dụng của quái vật 3D một cách không đồng bộ
			local actualHead
			for _ = 1, 30 do -- Thử tối đa 30 lần (30 * 0.05s = 1.5s) để khớp với nhịp tải phần tử của game
				if not enemy or not enemy.Parent then
					break
				end
				local horse = string.find(enemy.Name, "Springer") and enemy:FindFirstChild("horse")
				actualHead = (horse and horse:FindFirstChild("Head"))
					or enemy:FindFirstChild("Head", true)
					or enemy:FindFirstChild("head", true)
					or enemy.PrimaryPart
					or enemy:FindFirstChildWhichIsA("BasePart", true)
				if actualHead then
					break
				end
				task.wait(0.05) -- Chờ một nhịp cực ngắn trước khi kiểm tra lại
			end

			if not enemy or not enemy.Parent then
				return
			end

			-- Gán PrimaryPart nếu model thiếu (Cực kỳ quan trọng để BillboardGui ESP của game gốc hiển thị)
			if not enemy.PrimaryPart then
				local rootPart = actualHead
				if rootPart and rootPart:IsA("BillboardGui") then
					rootPart = rootPart.Adornee or rootPart.Parent
				end
				if not rootPart or not rootPart:IsA("BasePart") then
					rootPart = enemy:FindFirstChildWhichIsA("BasePart", true)
				end
				if rootPart and rootPart:IsA("BasePart") then
					pcall(function()
						enemy.PrimaryPart = rootPart
					end)
				end
			end

			-- Tạo phần đầu giả lập "head" (chữ thường) dạng BillboardGui cho thực thể 3D để khớp kiểu dữ liệu UDim2.Size của game gốc
			if not enemy:FindFirstChild("head") then
				local rootPart = actualHead
				if rootPart and rootPart:IsA("BillboardGui") then
					rootPart = rootPart.Adornee or rootPart.Parent
				end
				if rootPart and rootPart:IsA("BasePart") then
					local fakeHead = Instance.new("BillboardGui")
					fakeHead.Name = "head"
					fakeHead.Size = UDim2.fromScale(4, 4)
					fakeHead.Adornee = rootPart
					fakeHead.AlwaysOnTop = true
					fakeHead.Parent = enemy
				end
			end

			-- Chờ một chút để xem hệ thống gốc của game có tự động gắn ESP hay không
			task.wait(0.2)
			if enemy.Parent and not (enemy:FindFirstChild("ESP") or enemy:FindFirstChild("ESPCrayon")) then
				-- Nếu script gốc của game bỏ lỡ hoặc không kịp gắn, chúng ta tự gắn thủ công bằng template gốc
				local template = findNativeEnemyESPTemplate()
				if template then
					local cloned = template:Clone()
					local horse = string.find(enemy.Name, "Springer") and enemy:FindFirstChild("horse")
					local springerHead = horse and horse:FindFirstChild("Head")
					cloned.Adornee = springerHead or actualHead or enemy
					cloned.Enabled = true
					cloned.AlwaysOnTop = true
					local headPart = enemy:FindFirstChild("head")
					if string.find(enemy.Name, "Springer") then
						cloned.Size = UDim2.fromOffset(180, 44)
						cloned.StudsOffset = Vector3.new(0, 6.5, 0)
						cloned.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
					else
						cloned.Size = headPart and headPart:IsA("BillboardGui") and headPart.Size
							or UDim2.fromScale(4, 4)
					end

					local label = cloned:FindFirstChild("Label", true)
					if label and label:IsA("TextLabel") then
						if cloned.Name == "ESPCrayon" then
							local StupidNames =
								{ "bingle", "dangle", "glorp", "zorp", "splurg", "boing", "sproing", "floop" }
							label.Text = StupidNames[math.random(1, #StupidNames)]
						else
							label.Text = getEnemyDisplayName(enemy)
						end
						if string.find(enemy.Name, "Springer") then
							label.TextScaled = false
							label.TextSize = 24
							label.TextStrokeTransparency = 0.15
							label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						end
					end
					cloned.Parent = enemy
				end
			end
		end)
	end

	-- Hàm xử lý chính khi kiểm tra tên thực thể
	local function checkAndApply()
		if not enemy or not enemy.Parent then
			return
		end
		local name = enemy.Name
		debugPrint("processEntity checkAndApply for:", name)

		-- ── Thực thể dùng nguyên lý Xóa TouchInterest (Baby, Bell, Mart,...) ──
		if TouchInterest.isTargetEntity(name) then
			local checkFunc = TouchInterest.getImmunityCheck(name, Controller)
			debugPrint("checkAndApply TargetEntity:", name, "| checkFunc found:", checkFunc ~= nil)
			if checkFunc then
				debugPrint("checkAndApply TargetEntity:", name, "| checkFunc value:", checkFunc())
			end
			if checkFunc and checkFunc() then
				Executor.enableImmunity(GC, enemy)
			end
		end

		-- ── Husk / Skinwalker (đổi tên + CanTouch) ─────────────────────────────
		if
			HuskEvasion.isHuskEntity(name)
			or (enemy:GetAttribute("OriginalName") and HuskEvasion.isHuskEntity(enemy:GetAttribute("OriginalName")))
		then
			if Controller.SkinwalkerImmune then
				HuskEvasion.enableHuskImmunity(GC, enemy)
			end
		end

		-- ── Cadence Status UI Hook ─────────────────────────────
		if string.find(name, "Cadence") then
			createCadenceUI()
			if Controller.CadenceStatusLabel then
				Controller.CadenceStatusLabel.Text = "Stage 1"
				Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
			end

			local clientEvent = enemy:WaitForChild("ClientEvent", 5)
			if clientEvent and clientEvent:IsA("RemoteEvent") then
				local cadenceConn = clientEvent.OnClientEvent:Connect(function(p1, p2)
					if p1 == "Stage" then
						local stageNum = p2.Stage
						if Controller.CadenceStatusLabel then
							Controller.CadenceStatusLabel.Text = "Stage " .. tostring(stageNum)
							if stageNum == 2 then
								Controller.CadenceStatusLabel.Text = "Phase 2 (Stage 2)"
								Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
								pcall(function()
									local ts = game:GetService("TweenService")
									Controller.CadenceStatusLabel.TextSize = 20
									ts:Create(
										Controller.CadenceStatusLabel,
										TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
										{
											TextSize = 16,
										}
									):Play()
									if Controller.CadenceUIFrame then
										local stroke = Controller.CadenceUIFrame:FindFirstChildOfClass("UIStroke")
										if stroke then
											stroke.Color = Color3.fromRGB(255, 170, 0)
											ts:Create(stroke, TweenInfo.new(1, Enum.EasingStyle.Linear), {
												Color = Color3.fromRGB(80, 80, 80),
											}):Play()
										end
									end
								end)
							elseif stageNum == 3 then
								Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 0)
							elseif stageNum == 4 then
								Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
							else
								Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
							end
						end
					elseif p1 == "Chase" then
						if Controller.CadenceStatusLabel then
							Controller.CadenceStatusLabel.Text = "⚠️ CHASE ACTIVE ⚠️"
							Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
							pcall(function()
								local ts = game:GetService("TweenService")
								if Controller.CadenceUIFrame then
									local stroke = Controller.CadenceUIFrame:FindFirstChildOfClass("UIStroke")
									if stroke then
										stroke.Color = Color3.fromRGB(255, 50, 50)
										ts:Create(stroke, TweenInfo.new(1, Enum.EasingStyle.Linear), {
											Color = Color3.fromRGB(80, 80, 80),
										}):Play()
									end
								end
							end)
						end
					elseif p1 == "ElasticStop" then
						if Controller.CadenceStatusLabel then
							Controller.CadenceStatusLabel.Text = "Stopped"
							Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
						end
					end
				end)
				GC.registerEntityConnection(enemy, cadenceConn)
			end
		end

		-- ── Telefragger ClientEvent Hook ─────────────────────────────
		if string.find(string.lower(name), "telefragger") and not hookedTelefraggers[enemy] then
			hookedTelefraggers[enemy] = true
			task.spawn(function()
				local clientEvent = enemy:WaitForChild("ClientEvent", 5)
				if clientEvent and clientEvent:IsA("RemoteEvent") then
					local telefraggerConn = clientEvent.OnClientEvent:Connect(function(actionName, p2)
						if actionName == "SetTeleport" then
							Controller:TriggerSilentBackTrick(enemy)
						elseif actionName == "Indicator" then
							Controller:CancelSilentBackTrick(enemy)
						end
					end)
					GC.registerEntityConnection(enemy, telefraggerConn)
				end
			end)
		end
	end

	-- Đăng ký sự kiện lắng nghe đổi tên của thực thể (Phòng hờ game đổi tên trễ sau khi spawn)
	local nameConn = enemy:GetPropertyChangedSignal("Name"):Connect(checkAndApply)
	GC.registerEntityConnection(enemy, nameConn)

	-- Chạy kiểm tra ngay lập tức
	checkAndApply()

	-- Lắng nghe bộ phận mới được thêm vào cho Husk/Skinwalker
	local descConn = enemy.DescendantAdded:Connect(function(part)
		local name = enemy.Name
		if
			HuskEvasion.isHuskEntity(name)
			or (enemy:GetAttribute("OriginalName") and HuskEvasion.isHuskEntity(enemy:GetAttribute("OriginalName")))
		then
			if Controller.SkinwalkerImmune then
				HuskEvasion.onHuskDescendantAdded(GC, enemy, part)
			end
		end
	end)
	GC.registerEntityConnection(enemy, descConn)

	-- Xử lý vô hiệu hóa shockwave cho Springer (Springer không có TouchInterest, chỉ có ClientEvent và ShockwaveEvent)
	if string.find(enemy.Name, "Springer") then
		local childAddedConn = enemy.ChildAdded:Connect(function(child)
			if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
				local StatusImmunity = getgenv().loadModule("NULLSCAPE/Entities/StatusImmunity.luau")
				local hasKnockbackImmune = StatusImmunity and StatusImmunity.isImmune("Springer Knockback")
				local hasSpringerImmune = Controller.SpringerImmune
				local isBlatant = Controller.SpringerImmunityMode == "Blatant"

				if hasKnockbackImmune or (hasSpringerImmune and isBlatant) then
					disableShockwave(enemy, child)
				end
			end
		end)
		GC.registerEntityConnection(enemy, childAddedConn)

		for _, child in ipairs(enemy:GetChildren()) do
			if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
				local StatusImmunity = getgenv().loadModule("NULLSCAPE/Entities/StatusImmunity.luau")
				local hasKnockbackImmune = StatusImmunity and StatusImmunity.isImmune("Springer Knockback")
				local hasSpringerImmune = Controller.SpringerImmune
				local isBlatant = Controller.SpringerImmunityMode == "Blatant"

				if hasKnockbackImmune or (hasSpringerImmune and isBlatant) then
					disableShockwave(enemy, child)
				end
			end
		end
	end
end

-- Gỡ bỏ lắng nghe của thực thể khi nó bị xóa
local function removeEntity(enemy)
	processedEntities[enemy] = nil
	GC.removeEntityConnections(enemy)
	
	if string.find(string.lower(enemy.Name), "telefragger") then
		Controller:CancelSilentBackTrick(enemy)
	end

	for part, data in pairs(disabledShockwaves) do
		if data.enemy == enemy then
			restoreShockwave(part)
		end
	end
	if string.find(enemy.Name, "Cadence") then
		if Controller.CadenceStatusLabel then
			Controller.CadenceStatusLabel.Text = "Not Active"
			Controller.CadenceStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
end

-- Hàm dọn dẹp tài nguyên riêng cho một thư mục cụ thể khi nó bị xóa khỏi Workspace
function Controller:CleanUpFolder(folder)
	if not folder then
		return
	end

	-- 1. Dọn dẹp các thực thể đang tồn tại trong thư mục này
	for _, child in ipairs(folder:GetChildren()) do
		removeEntity(child)
	end

	-- 2. Ngắt kết nối của riêng thư mục này
	local conns = folderConnections[folder]
	if conns then
		for _, conn in ipairs(conns) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		folderConnections[folder] = nil
	end

	-- 3. Cập nhật biến tham chiếu EnemiesFolder nếu cần
	if self.EnemiesFolder == folder then
		self.EnemiesFolder = nil
	end
end

-- Thiết lập quan sát thư mục Enemies trong Workspace
function Controller:ObserveFolder(folder)
	debugPrint("ObserveFolder called for:", folder:GetFullName())
	-- Tránh đăng ký nhiều lần cho cùng một thư mục
	if folderConnections[folder] then
		debugPrint("Folder already observed, skipping:", folder.Name)
		return
	end

	if folder.Name == "Enemies" then
		self.EnemiesFolder = folder
	end

	local conns = {}

	-- 1. Lắng nghe khi thực thể mới xuất hiện
	local childAddedConn = folder.ChildAdded:Connect(function(child)
		debugPrint("ObserveFolder: ChildAdded in:", folder.Name, "| Child Name:", child.Name)
		processEntity(child)
	end)
	table.insert(conns, childAddedConn)

	-- 2. Lắng nghe khi thực thể bị xóa khỏi game
	local childRemovedConn = folder.ChildRemoved:Connect(function(child)
		removeEntity(child)
	end)
	table.insert(conns, childRemovedConn)

	-- 3. Xử lý các thực thể đã có sẵn trong thư mục
	debugPrint("ObserveFolder: Existing children in:", folder.Name, "| count:", #folder:GetChildren())
	for _, child in ipairs(folder:GetChildren()) do
		debugPrint("ObserveFolder: Processing existing child:", child.Name)
		processEntity(child)
	end

	-- 4. Cơ chế tự động GC khi thư mục bị xóa/hủy khỏi Workspace
	local destroyingConn = folder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			-- Thư mục đã bị xóa hoàn toàn khỏi trò chơi
			self:CleanUpFolder(folder)
		end
	end)
	table.insert(conns, destroyingConn)

	folderConnections[folder] = conns
end

function Controller:UpdateTouchImmunityState()
	local char = LocalPlayer.Character
	if not char then return end

	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local nearBell = false
	local nearSpringer = false

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			local name = enemy.Name
			local enemyRoot = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart", true)
			if enemyRoot then
				local dist = (rootPart.Position - enemyRoot.Position).Magnitude
				if string.find(name, "Bell") and dist < 16 then
					nearBell = true
				elseif string.find(name, "Springer") and dist < 42 then
					nearSpringer = true
				end
			end
		end
	end

	local shouldDisableTouch = (nearBell and self.BellImmune) or (nearSpringer and self.SpringerImmune)

	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			if shouldDisableTouch then
				if part.CanTouch then
					if originalTouchStates[part] == nil then
						originalTouchStates[part] = part.CanTouch
					end
					part.CanTouch = false
				end
			else
				if originalTouchStates[part] ~= nil then
					part.CanTouch = originalTouchStates[part]
					originalTouchStates[part] = nil
				end
			end
		end
	end
end

-- Quét tìm thư mục Enemies và Skinwalkers trong Workspace và lắng nghe sự thay đổi
local function startObservingFolders()
	debugPrint("startObservingFolders called")
	disconnectFolderObservations()

	local touchImmConn = game:GetService("RunService").Heartbeat:Connect(function()
		Controller:UpdateTouchImmunityState()
	end)
	table.insert(workspaceConnections, touchImmConn)

	local function checkAndObserve(child)
		if Controller.Destroyed then
			return
		end
		if (child.Name == "Enemies" or child.Name == "Skinwalkers") and child:IsA("Folder") then
			Controller:ObserveFolder(child)
		end
	end

	local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
	table.insert(workspaceConnections, wsConn)

	-- Xử lý các folder có sẵn
	for _, child in ipairs(workspace:GetChildren()) do
		if (child.Name == "Enemies" or child.Name == "Skinwalkers") and child:IsA("Folder") then
			Controller:ObserveFolder(child)
		end
	end
end

-- Hàm cập nhật trạng thái sảnh chờ và tự động dọn dẹp visual/connections
local function setInLobby(val)
	if inLobby == val then
		return
	end
	inLobby = val
	Controller.inLobby = val

	pcall(function()
		TouchInterest.setInLobbyState(val)
	end)

	if val then
		disconnectFolderObservations()
		Controller:CleanUp()
	else
		startObservingFolders()
	end
end

-- Hook hệ thống trạng thái (Status Effects) để miễn nhiễm debuff ở chế độ Blatant
local function initializeStatusEffectHook()
	local globals = getgenv()._NULLSCAPE_Globals
	local StatusImmunity = getgenv().loadModule("NULLSCAPE/Entities/StatusImmunity.luau")
	if StatusImmunity then
		StatusImmunity.initialize()
	end

	-- Hook SettingsHandler to bypass camera shakes, blurs, and flash effects natively
	pcall(function()
		local ReplicatedFirst = game:GetService("ReplicatedFirst")
		local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		local core = clientModules and clientModules:FindFirstChild("Core")
		local playerData = core and core:FindFirstChild("PlayerData")
		local settingsModule = playerData and playerData:FindFirstChild("SettingsHandler")
		if settingsModule and settingsModule:IsA("ModuleScript") then
			local SettingsHandler = require(settingsModule)
			if typeof(SettingsHandler) == "table" then
				if typeof(SettingsHandler.Get) == "function" and not globals.SettingsHooked then
					local oldGet = SettingsHandler.Get
					globals.OriginalSettingsGet = oldGet
					SettingsHandler.Get = function(keys, ...)
						local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
						if activeCtrl and activeCtrl.SpringerImmunityMode == "Blatant" then
							if typeof(keys) == "table" then
								if
									keys[1] == "Graphics"
									and (
										keys[2] == "NoBlur"
										or keys[2] == "Photosensitivity"
										or keys[2] == "NoVFXWobble"
									)
								then
									return true
								end
							end
						end
						return oldGet(keys, ...)
					end

					if typeof(SettingsHandler.GetSettings) == "function" then
						local oldGetSettings = SettingsHandler.GetSettings
						globals.OriginalGetSettings = oldGetSettings
						SettingsHandler.GetSettings = function(...)
							local settingsTable = oldGetSettings(...)
							local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
							if activeCtrl and activeCtrl.SpringerImmunityMode == "Blatant" then
								if typeof(settingsTable) == "table" then
									settingsTable.Graphics = settingsTable.Graphics or {}
									settingsTable.Graphics.NoBlur = true
									settingsTable.Graphics.Photosensitivity = true
									settingsTable.Graphics.NoVFXWobble = true
								end
							end
							return settingsTable
						end
					end

					globals.SettingsHooked = true
				end
			end
		end
	end)

	-- Khởi chạy vòng lặp ngầm để liên tục khử kích thước Blur và các hiệu ứng méo/đỏ màn hình
	globals.StatusEffectHooked = true
	local loopToken = {}
	globals.StatusEffectLoopToken = loopToken
	task.spawn(function()
		while globals.StatusEffectHooked and globals.StatusEffectLoopToken == loopToken do
			local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
			if activeCtrl and activeCtrl ~= Controller then
				break
			end
			if activeCtrl and activeCtrl.Destroyed then
				break
			end
			if activeCtrl and activeCtrl.SpringerImmunityMode == "Blatant" then
				pcall(function()
					local lighting = game:GetService("Lighting")
					local blur = lighting:FindFirstChild("Blur")
					if blur and blur:IsA("BlurEffect") and blur.Size > 0 then
						blur.Size = 0
					end

					for _, name in ipairs({ "Flesh", "Fire", "Oblivion", "IceExampleEffect" }) do
						local cc = lighting:FindFirstChild(name)
						if cc and cc:IsA("ColorCorrectionEffect") then
							cc.Brightness = 0
							cc.Contrast = 0
							cc.Saturation = 0
							cc.TintColor = Color3.fromRGB(255, 255, 255)
						end
					end
				end)
			end
			task.wait(activeCtrl and activeCtrl.SpringerImmunityMode == "Blatant" and 0.2 or 1.0)
		end
	end)
end

-- Hook hiệu ứng mù khi ai đó gõ Chuông (Bell Blindness / Screen flash black/white)
local function initializeBellBlindnessHook()
	local globals = getgenv()._NULLSCAPE_Globals
	globals.BellHookedFunctions = globals.BellHookedFunctions or {}

	-- Hook _G.RingBell để tránh nhấp nháy/mù cục bộ khi ta tự gõ hoặc chạm chuông
	task.spawn(function()
		while not _G.RingBell do
			task.wait(0.5)
		end
		local originalRingBell = _G.RingBell
		_G.RingBell = function(p1)
			local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
			if activeCtrl and activeCtrl.BellBlindnessImmune then
				return
			end
			return originalRingBell(p1)
		end
	end)

	-- Hook OnClientEvent của Bell để tránh mù khi người chơi khác gõ chuông trong phòng
	task.spawn(function()
		local events = ReplicatedStorage:WaitForChild("Events", 15)
		local bellEvent = events and events:WaitForChild("Bell", 15)
		if bellEvent and bellEvent:IsA("RemoteEvent") then
			if typeof(getconnections) == "function" and typeof(hookfunction) == "function" then
				local function hookBellConnections()
					for _, connection in ipairs(getconnections(bellEvent.OnClientEvent)) do
						local originalFunction = connection.Function
						if typeof(originalFunction) == "function" and not globals.BellHookedFunctions[originalFunction] then
							local oldFunc
							oldFunc = hookfunction(originalFunction, function(...)
								local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
								if activeCtrl and activeCtrl.BellBlindnessImmune then
									return
								end
								return oldFunc(...)
							end)
							globals.BellHookedFunctions[originalFunction] = true
						end
					end
				end

				-- Hook các kết nối cũ đang hoạt động
				hookBellConnections()

				-- Hook hàm Connect để tự động bọc các kết nối mới trong tương lai
				local oldConnect
				oldConnect = hookfunction(bellEvent.OnClientEvent.Connect, function(self, callback)
					if typeof(callback) == "function" then
						local newCallback = function(...)
							local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
							if activeCtrl and activeCtrl.BellBlindnessImmune then
								return
							end
							return callback(...)
						end
						return oldConnect(self, newCallback)
					end
					return oldConnect(self, callback)
				end)
			end
		end
	end)
end

-- Hook AnimationManager để phục vụ tính năng BackTrick của Telefragger
local function initializeMovementHook()
	local success, err = pcall(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local movementFolder = ReplicatedStorage:WaitForChild("Movement", 15)
		if movementFolder then
			local animManagerScript = movementFolder:WaitForChild("AnimationManager", 15)
			if animManagerScript and animManagerScript:IsA("ModuleScript") then
				local AnimationManager = require(animManagerScript)
				if typeof(AnimationManager) == "table" then
					if AnimationManager.FaceMoveDirection and not getgenv()._NULLSCAPE_Globals.AnimManagerHooked then
						local oldFaceMoveDirection = AnimationManager.FaceMoveDirection
						AnimationManager.FaceMoveDirection = function(self, ...)
							local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
							if activeCtrl and activeCtrl.WasRedirectingTelefragger then
								return
							end
							return oldFaceMoveDirection(self, ...)
						end

						local oldFaceDirection = AnimationManager.FaceDirection
						AnimationManager.FaceDirection = function(self, ...)
							local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
							if activeCtrl and activeCtrl.WasRedirectingTelefragger then
								return
							end
							return oldFaceDirection(self, ...)
						end

						getgenv()._NULLSCAPE_Globals.AnimManagerHooked = true
						debugPrint("Successfully hooked AnimationManager FaceMoveDirection & FaceDirection!")
					end
				end
			end
		end
	end)
	if not success then
		warn("Failed to hook AnimationManager:", err)
	end
end

-- Hook để chặn RemoteEvent báo tử của thực thể Client-side (như ICBM và Springer) một cách an toàn
local function initializeICBMHook()
	-- Xây dựng bảng tra cứu nhanh O(1) tên các RemoteEvent cần chặn
	local TargetRemoteNames = {
		["ClientEvent"] = true,
		["ShockwaveEvent"] = true,
		["DiedFunc"] = true,
		["Died"] = true,
		["OblivionEvent"] = true,
		["BroSecureMethod"] = true,
		["GrappleReplicator"] = true,
		["UnreliableRemoteEvent"] = true,
	}
 
 	local function handleRemoteCall(self, ...)
		local firstArg = ...
 
		-- Lấy activeController hiện tại từ globals
		local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
		if not activeCtrl then
			return false
		end
 
		-- ── HOOK GỬI CAMERA GIẢ LẬP CHO NGƯỜI XEM (SPECTATOR FLICK) ──
		if self.Name == "UnreliableRemoteEvent" and firstArg == 0 then
			if activeCtrl.FlickFakeSpectatorEnabled and activeCtrl.CurrentFlickAngle then
				local args = { ... }
				local originalCFrame = args[3]
				if typeof(originalCFrame) == "CFrame" then
					-- Xoay CFrame camera gửi lên server (nhân bên TRÁI để tạo hiệu ứng xoay quỹ đạo quanh nhân vật)
					args[3] = CFrame.Angles(0, activeCtrl.CurrentFlickAngle, 0) * originalCFrame
					return true, args -- Chặn cuộc gọi gốc và trả về danh sách tham số mới
				end
			end
			return false
		end

		-- Kiểm tra nhanh tên remote trước (O(1) lookup)
		if not TargetRemoteNames[self.Name] then
			return false
		end
 
		-- Trì hoãn cuộc gọi CreateHook để đồng bộ hóa trạng thái vật lý lên server (tránh bị từ chối do độ trễ ping)
		local namecallArgs = { ... }
		if self.Name == "GrappleReplicator" and firstArg == "CreateHook" and namecallArgs[3] ~= "DelayedBypass" then
			task.delay(0.06, function()
				local originalFireServer = getgenv()._NULLSCAPE_Globals.OriginalFireServer
				if originalFireServer then
					pcall(originalFireServer, self, table.unpack(namecallArgs))
				else
					-- Dự phòng nếu không có hookfunction: tự gọi lại và gắn thêm tag nhận biết để tránh lặp đệ quy
					namecallArgs[3] = "DelayedBypass"
					pcall(function()
						self:FireServer(table.unpack(namecallArgs))
					end)
				end
			end)
			return true
		end

		-- Chạy logic chặn RemoteEvent thống nhất từ RemoteBlocking.luau
		if self.Name == "Died" and firstArg == "VoidImplosion" and activeCtrl.VoidImplosionImmune == true then
			return true
		end
 
		local args = { ... }
 
		if activeCtrl.GuardianImmune == true and self.Name == "Died" and args[1] == "Guardian" then
			return true
		end
		if activeCtrl.KolonaImmune == true and self.Name == "DiedFunc" and args[1] == "Kolona" then
			return true
		end
 
		local block = RemoteBlocking.shouldBlockRemoteCall(self, args, activeCtrl)
		if block then
			return true
		end
 
		return false
	end
 
	-- Đăng ký dispatcher toàn cục
	getgenv()._NULLSCAPE_Globals.handleEntitiesRemoteCall = handleRemoteCall

	-- 1. Hook __namecall (Phương pháp chuẩn và mạnh nhất cho các cuộc gọi dạng Remote:FireServer(...) hoặc Remote:InvokeServer(...))
	local namecallSuccess = false
	if typeof(hookmetamethod) == "function" then
		if not getgenv()._NULLSCAPE_Globals.NamecallHooked then
			pcall(function()
				local oldNamecall
				oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
					local method = getnamecallmethod()
					local isRemote = false
					local isRemoteFunction = false

					if method == "FireServer" or method == "InvokeServer" then
						pcall(function()
							if typeof(self) == "Instance" then
								if self.ClassName == "RemoteEvent" then
									isRemote = true
								elseif self.ClassName == "RemoteFunction" then
									isRemote = true
									isRemoteFunction = true
								end
							end
						end)
					end

					if isRemote then
						local dispatcher = getgenv()._NULLSCAPE_Globals.handleEntitiesRemoteCall
						if dispatcher then
							local success, shouldBlock, modifiedArgs = pcall(dispatcher, self, ...)
							if success and shouldBlock then
								if modifiedArgs then
									return oldNamecall(self, table.unpack(modifiedArgs))
								end
								if isRemoteFunction then
									return nil -- Chặn đứng InvokeServer và trả về nil
								end
								return -- Chặn đứng FireServer
							end
						end
					end
					return oldNamecall(self, ...)
				end)
				getgenv()._NULLSCAPE_Globals.OriginalNamecall = oldNamecall
				getgenv()._NULLSCAPE_Globals.NamecallHooked = true
				namecallSuccess = true
			end)
		else
			namecallSuccess = true
		end
	end

	-- 2. Hook FireServer/InvokeServer prototype (Dự phòng)
	local prototypeSuccess = false
	if typeof(hookfunction) == "function" then
		if not getgenv()._NULLSCAPE_Globals.PrototypeHooked then
			pcall(function()
				local remoteProto = Instance.new("RemoteEvent")
				local oldFireServer
				oldFireServer = hookfunction(remoteProto.FireServer, function(self, ...)
					local dispatcher = getgenv()._NULLSCAPE_Globals.handleEntitiesRemoteCall
					if dispatcher then
						local success, shouldBlock, modifiedArgs = pcall(dispatcher, self, ...)
						if success and shouldBlock then
							if modifiedArgs then
								return oldFireServer(self, table.unpack(modifiedArgs))
							end
							return -- Chặn đứng cuộc gọi
						end
					end
					return oldFireServer(self, ...)
				end)

				local funcProto = Instance.new("RemoteFunction")
				local oldInvokeServer
				oldInvokeServer = hookfunction(funcProto.InvokeServer, function(self, ...)
					local dispatcher = getgenv()._NULLSCAPE_Globals.handleEntitiesRemoteCall
					if dispatcher then
						local success, shouldBlock, modifiedArgs = pcall(dispatcher, self, ...)
						if success and shouldBlock then
							if modifiedArgs then
								return oldInvokeServer(self, table.unpack(modifiedArgs))
							end
							return nil -- Chặn đứng cuộc gọi và trả về nil
						end
					end
					return oldInvokeServer(self, ...)
				end)
				getgenv()._NULLSCAPE_Globals.OriginalFireServer = oldFireServer
				getgenv()._NULLSCAPE_Globals.OriginalInvokeServer = oldInvokeServer
				getgenv()._NULLSCAPE_Globals.PrototypeHooked = true
				prototypeSuccess = true
			end)
		else
			prototypeSuccess = true
		end
	end

	if not namecallSuccess and not prototypeSuccess then
		warn("Failed to initialize any ClientSideHit hook. Exploits might not be supported.")
	end
end

-- Đăng ký active controller hiện tại để tự động dừng các phiên bản cũ
getgenv()._NULLSCAPE_Globals.activeEntitiesController = Controller

-- Khởi tạo ban đầu khi nạp script
if not inLobby then
	startObservingFolders()
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
	local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
	if Controller.Destroyed or not Controller.PermanentConnections then
		return
	end
	if inRoundVal and inRoundVal:IsA("BoolValue") then
		hasInRoundValue = true
		if getgenv()._NULLSCAPE_Globals.activeEntitiesController ~= Controller then
			pcall(function()
				Controller:CleanUp()
			end)
			return
		end
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
			if getgenv()._NULLSCAPE_Globals.activeEntitiesController ~= Controller then
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
			setInLobby(not val)
		end)
		table.insert(Controller.PermanentConnections, conn)
	end
end)

-- Vòng lặp quan sát dự phòng (chỉ chạy khi không có InRound)
task.spawn(function()
	while not Controller.Destroyed and not hasInRoundValue do
		task.wait(3.0)
		if Controller.Destroyed or hasInRoundValue or not Controller.CleanUp then
			break
		end
		if getgenv()._NULLSCAPE_Globals.activeEntitiesController ~= Controller then
			pcall(function()
				Controller:CleanUp()
			end)
			break
		end
		setInLobby(not isInMatch())
	end
end)

task.spawn(initializeMovementHook)
task.spawn(initializeICBMHook)
task.spawn(initializeStatusEffectHook)
task.spawn(initializeBellBlindnessHook)

return Controller
