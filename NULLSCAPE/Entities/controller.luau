-- [[
--  NULLSCAPE - Entities Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Executor = getgenv().loadModule("NULLSCAPE/Entities/executor.luau")
local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")
local HuskEvasion = getgenv().loadModule("NULLSCAPE/Entities/HuskEvasion.luau")
local RemoteBlocking = getgenv().loadModule("NULLSCAPE/Entities/RemoteBlocking.luau")
local GC = getgenv().loadModule("NULLSCAPE/Entities/GC.luau")

local Controller = {
	-- Trạng thái bật/tắt miễn nhiễm cho từng thực thể
	BabyImmune = false,
	BellImmune = false,
	FleshImmune = false,
	MartImmune = false,
	TelefraggerImmune = false,
	ICBMImmune = false,
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
	SpringerImmunityMode = "Legit",
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
	Frame.Size = UDim2.new(0, 220, 0, 80)
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
	TitleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	TitleLabel.Position = UDim2.new(0, 0, 0.05, 0)
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Text = "🎵 CADENCE STATUS"
	TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TitleLabel.TextSize = 13
	TitleLabel.Font = Enum.Font.GothamBold
	TitleLabel.Parent = Frame

	local StatusLabel = Instance.new("TextLabel")
	StatusLabel.Name = "StatusLabel"
	StatusLabel.Size = UDim2.new(1, 0, 0.5, 0)
	StatusLabel.Position = UDim2.new(0, 0, 0.45, 0)
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
	
	local success, result = pcall(function()
		return getgenv().loadModule and getgenv().loadModule("NULLSCAPE/Accessibility/controller.luau")
	end)
	return success and result or nil
end

local inLobby = not isInMatch() -- Đang ở sảnh chờ/lựa chọn (Khởi tạo ban đầu)
Controller.inLobby = inLobby
local hasInRoundValue = false
local folderConnections = {} -- key: folder -> value: list of connections
local workspaceConnections = {} -- list of workspace-level connections
local processedEntities = setmetatable({}, { __mode = "k" })
local ENTITY_PROCESS_BATCH_SIZE = 4

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

	for folder, conns in pairs(folderConnections) do
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

-- Hàm dọn dẹp tài nguyên (Garbage Collection - GC) giải phóng bộ nhớ
function Controller:CleanUp()
	disconnectFolderObservations()
	pcall(function()
		Executor.disableSpecialImmunity()
	end)
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

	-- Giải phóng biến môi trường để hỗ trợ dọn dẹp bộ nhớ (GC)
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and globals.activeEntitiesController == self then
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
		then
			Executor.disableImmunityForType(GC, entityName)
		elseif entityName == "Skinwalker" then
			HuskEvasion.disableHuskImmunity(GC)
		end
		if entityName == "Springer" then
			for part, data in pairs(disabledShockwaves) do
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
		-- Tự động dọn dẹp toàn bộ debuff đang có trên người chơi
		pcall(function()
			for _, debuffName in ipairs({ "Flesh", "Panic", "Concussion", "Fire", "Insanity" }) do
				for _, callback in ipairs(activeCallbacks) do
					pcall(callback, debuffName, false)
				end
			end
		end)
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
			for part, data in pairs(disabledShockwaves) do
				restoreShockwave(part)
			end
		end
	end
end

function Controller:StartSkinwalkerEvasion()
end

-- Tối ưu hóa xử lý từng thực thể (Sử dụng Event thay vì Loop)
local function findNativeEnemyESPTemplate()
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and globals.EntitiesNativeEnemyESPTemplate and globals.EntitiesNativeEnemyESPTemplate.Parent then
		return globals.EntitiesNativeEnemyESPTemplate
	end
	if globals and globals.EntitiesNativeEnemyESPTemplateMissAt and time() - globals.EntitiesNativeEnemyESPTemplateMissAt < 2 then
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
				scanned += 1
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
		template = searchDescendantsBudgeted(starterPlayer and starterPlayer:FindFirstChild("StarterPlayerScripts"), 2500)
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
							child.Size = UDim2.new(4, 0, 4, 0)
							local function formatSquare(obj)
								if obj:IsA("GuiObject") then
									obj.Size = UDim2.new(1, 0, 1, 0)
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
						for i = 1, 60 do
							if not enemy or not enemy.Parent then return end
							rootPart = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart", true)
							if rootPart then break end
							task.wait(0.05)
						end

						if rootPart then
							if child.Adornee == enemy or child.Adornee == nil then
								pcall(function() child.Adornee = rootPart end)
							end

							-- Defensively hide native ESP when enemy is spawning far below the map (Y < -50)
							local function updateVisibility()
								if not rootPart or not rootPart.Parent then return end
								local isBelowMap = rootPart.Position.Y < -50
								pcall(function() child.Enabled = not isBelowMap end)
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
			for i = 1, 30 do -- Thử tối đa 30 lần (30 * 0.05s = 1.5s) để khớp với nhịp tải phần tử của game
				if not enemy or not enemy.Parent then
					break
				end
				local horse = string.find(enemy.Name, "Springer") and enemy:FindFirstChild("horse")
				actualHead = (horse and horse:FindFirstChild("Head")) or enemy:FindFirstChild("Head", true) or enemy:FindFirstChild("head", true) or enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart", true)
				if actualHead then
					break
				end
				task.wait(0.05) -- Chờ một nhịp cực ngắn trước khi kiểm tra lại
			end

			if not enemy or not enemy.Parent then return end

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
					pcall(function() enemy.PrimaryPart = rootPart end)
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
					fakeHead.Size = UDim2.new(4, 0, 4, 0)
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
						cloned.Size = headPart and headPart:IsA("BillboardGui") and headPart.Size or UDim2.fromScale(4, 4)
					end
					
					local label = cloned:FindFirstChild("Label", true)
					if label and label:IsA("TextLabel") then
						if cloned.Name == "ESPCrayon" then
							local StupidNames = { "bingle", "dangle", "glorp", "zorp", "splurg", "boing", "sproing", "floop" }
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
									ts:Create(Controller.CadenceStatusLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
										TextSize = 16
									}):Play()
									if Controller.CadenceUIFrame then
										local stroke = Controller.CadenceUIFrame:FindFirstChildOfClass("UIStroke")
										if stroke then
											stroke.Color = Color3.fromRGB(255, 170, 0)
											ts:Create(stroke, TweenInfo.new(1, Enum.EasingStyle.Linear), {
												Color = Color3.fromRGB(80, 80, 80)
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
											Color = Color3.fromRGB(80, 80, 80)
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
			if
				(child.Name == "SpringerShockwave" or child.Name == "DemonShockwave")
				and Controller.SpringerImmune
				and Controller.SpringerImmunityMode == "Blatant"
			then
				disableShockwave(enemy, child)
			end
		end)
		GC.registerEntityConnection(enemy, childAddedConn)

		for _, child in ipairs(enemy:GetChildren()) do
			if
				(child.Name == "SpringerShockwave" or child.Name == "DemonShockwave")
				and Controller.SpringerImmune
				and Controller.SpringerImmunityMode == "Blatant"
			then
				disableShockwave(enemy, child)
			end
		end
	end
end

-- Gỡ bỏ lắng nghe của thực thể khi nó bị xóa
local function removeEntity(enemy)
	processedEntities[enemy] = nil
	GC.removeEntityConnections(enemy)
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
	local existingChildren = folder:GetChildren()
	debugPrint("ObserveFolder: Existing children in:", folder.Name, "| count:", #existingChildren)
	task.spawn(function()
		local processedThisSlice = 0
		for _, child in ipairs(existingChildren) do
			if Controller.Destroyed or (folderConnections[folder] and folderConnections[folder] ~= conns) or not folder.Parent then
				break
			end
			debugPrint("ObserveFolder: Processing existing child:", child.Name)
			processEntity(child)
			processedThisSlice += 1
			if processedThisSlice >= ENTITY_PROCESS_BATCH_SIZE then
				processedThisSlice = 0
				task.wait()
			end
		end
	end)

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

-- Quét tìm thư mục Enemies và Skinwalkers trong Workspace và lắng nghe sự thay đổi
local function startObservingFolders()
	debugPrint("startObservingFolders called")
	disconnectFolderObservations()

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

local activeCallbacks = {}

-- Hook hệ thống trạng thái (Status Effects) để miễn nhiễm debuff ở chế độ Blatant
local function initializeStatusEffectHook()
	local globals = getgenv()._NULLSCAPE_Globals
	if globals.StatusEffectHooked then
		return
	end

	local StatusEffectChanged = ReplicatedStorage:FindFirstChild("Events")
		and ReplicatedStorage.Events:FindFirstChild("StatusEffectChanged")
	if StatusEffectChanged and StatusEffectChanged:IsA("RemoteEvent") then
		pcall(function()
			if typeof(hookfunction) == "function" then
				local oldConnect
				oldConnect = hookfunction(StatusEffectChanged.OnClientEvent.Connect, function(self, callback)
					local isTarget = false
					pcall(function()
						isTarget = (self == StatusEffectChanged.OnClientEvent)
					end)
					
					if isTarget then
						if not table.find(activeCallbacks, callback) then
							table.insert(activeCallbacks, callback)
						end
						local newCallback = function(statusName, isActive, ...)
							local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
							if
								activeCtrl
								and activeCtrl.SpringerImmunityMode == "Blatant"
								and statusName ~= "Medal"
								and statusName ~= "Overtuned"
							then
								return
							end
							return callback(statusName, isActive, ...)
						end
						return oldConnect(self, newCallback)
					end
					return oldConnect(self, callback)
				end)
			end
		end)
	end

	pcall(function()
		local ReplicatedFirst = game:GetService("ReplicatedFirst")
		local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
		if handlerModule and handlerModule:IsA("ModuleScript") then
			local StatusEffectHandler = require(handlerModule)
			if typeof(StatusEffectHandler) == "table" and typeof(StatusEffectHandler.HasStatus) == "function" then
				if typeof(hookfunction) == "function" then
					local oldHasStatus
					oldHasStatus = hookfunction(StatusEffectHandler.HasStatus, function(statusName, ...)
						local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
						if
							activeCtrl
							and activeCtrl.SpringerImmunityMode == "Blatant"
							and statusName ~= "Medal"
							and statusName ~= "Overtuned"
						then
							return false
						end
						return oldHasStatus(statusName, ...)
					end)
				else
					local oldHasStatus = StatusEffectHandler.HasStatus
					StatusEffectHandler.HasStatus = function(statusName, ...)
						local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
						if
							activeCtrl
							and activeCtrl.SpringerImmunityMode == "Blatant"
							and statusName ~= "Medal"
							and statusName ~= "Overtuned"
						then
							return false
						end
						return oldHasStatus(statusName, ...)
					end
				end
			end
		end
	end)

	globals.StatusEffectHooked = true
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
	}

	local function handleRemoteCall(self, ...)
		local args = { ... }

		-- Lấy activeController hiện tại từ globals
		local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
		if not activeCtrl then
			return false
		end

		-- Kiểm tra nhanh tên remote trước (O(1) lookup)
		if not TargetRemoteNames[self.Name] then
			return false
		end

		-- Chạy logic chặn RemoteEvent thống nhất từ RemoteBlocking.luau
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
							local success, shouldBlock = pcall(dispatcher, self, ...)
							if success and shouldBlock then
								if isRemoteFunction then
									return nil -- Chặn đứng InvokeServer và trả về nil
								end
								return -- Chặn đứng FireServer
							end
						end
					end
					return oldNamecall(self, ...)
				end)
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
						local success, shouldBlock = pcall(dispatcher, self, ...)
						if success and shouldBlock then
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
						local success, shouldBlock = pcall(dispatcher, self, ...)
						if success and shouldBlock then
							return nil -- Chặn đứng cuộc gọi và trả về nil
						end
					end
					return oldInvokeServer(self, ...)
				end)
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
local previousEntitiesController = getgenv()._NULLSCAPE_Globals.activeEntitiesController
if previousEntitiesController and previousEntitiesController ~= Controller and typeof(previousEntitiesController.CleanUp) == "function" then
	pcall(function()
		previousEntitiesController:CleanUp()
	end)
end
getgenv()._NULLSCAPE_Globals.activeEntitiesController = Controller

-- Khởi tạo ban đầu khi nạp script
if not inLobby then
	startObservingFolders()
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
	local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
	if inRoundVal and inRoundVal:IsA("BoolValue") then
		hasInRoundValue = true
		setInLobby(not inRoundVal.Value)

		local conn = inRoundVal.Changed:Connect(function(val)
			if Controller.Destroyed then
				return
			end
			if getgenv()._NULLSCAPE_Globals.activeEntitiesController ~= Controller then
				Controller:CleanUp()
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
		if Controller.Destroyed or hasInRoundValue then
			break
		end
		if getgenv()._NULLSCAPE_Globals.activeEntitiesController ~= Controller then
			Controller:CleanUp()
			break
		end
		setInLobby(not isInMatch())
	end
end)

task.spawn(initializeICBMHook)
task.spawn(initializeStatusEffectHook)

return Controller
