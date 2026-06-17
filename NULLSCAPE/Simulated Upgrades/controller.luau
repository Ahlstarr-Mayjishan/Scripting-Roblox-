--!nocheck
-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Phát lệnh gọi quét định vị (scan) định kỳ thông qua Executor.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/executor.luau")
local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local GC = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/GC.luau")
local MatrixTetrahedron = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Matrix Tetrahedron.luau")
local GraceWings = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Grace Wings.luau")
local AdvancedGravityCoil = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Advanced Gravity Coil.luau")
local BetterJumpPad = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Better Jump Pad.luau")
local SpeedBuffs = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Speed Buffs.luau")

local Controller = {
	RadarEnabled = false,
	GiftESPEnabled = false,
	CadenceESPEnabled = false,
	AltarESPEnabled = false,
	AltarFilter = { "All" },
	ESPStyle = "Highlight", -- Mặc định: "Highlight" hoặc "Dot"
	Destroyed = false,

	AutoCollectEnabled = false,
	AutoCollectRange = 20,
	AutoCollectMode = "Legit",

	MatrixTetrahedronEnabled = false, -- Mô phỏng Matrix Tetrahedron di chuyển instant acceleration
	MomentumReduction = 1.0, -- Lực Momentum Reduction tùy biến (mặc định 100%)

	GraceWingsEnabled = false,
	GraceWingsAirControlMultiplier = 1.1,
	GraceWingsStrongAirControl = false,
	AdvancedGravityCoilEnabled = false,
	AdvancedGravityCoilJumpPower = 28,
	BetterJumpPadEnabled = false,
	BetterJumpPadPower = 100,
	SpeedBuffsEnabled = false,
	SpeedBuffSelections = {},

	TripmineBarrierEnabled = false,
	TripmineMode = "Passthrough", -- "Passthrough" (xuyên mìn, nổ sau) | "PreDetonate" (nổ sớm từ xa) | "Barrier" (xuyên, không nổ)
	TripmineDetonationDistance = 15,
	TripmineDetonationJitter = 2,
	SimulateDefuseKit = false,
	DefuseKitStack = 3,

	NearestGiftPosition = nil,
	NearestCadencePosition = nil,
	NearestAltarPosition = nil,
	ActiveGifts = {},
	ActiveInstruments = {},
	ActiveAltars = {},
	PermanentConnections = {},
}

local function safeControllerCleanUp()
	if typeof(Controller) == "table" and typeof(Controller.CleanUp) == "function" then
		Controller:CleanUp()
	end
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

local inLobby = not isInMatch() -- Đang ở sảnh chờ/lựa chọn (Khởi tạo ban đầu)
local function refreshUpgradeServerState()
	task.spawn(function()
		local ClientModules = ReplicatedFirst:FindFirstChild("ClientModules")
			or ReplicatedFirst:WaitForChild("ClientModules", 5)
		local UpgradeHandlerModule = ClientModules and ClientModules:FindFirstChild("UpgradeHandler")
		if not UpgradeHandlerModule then
			return
		end

		local success, UpgradeHandler = pcall(require, UpgradeHandlerModule)
		if success and typeof(UpgradeHandler) == "table" and typeof(UpgradeHandler.ForceSyncServer) == "function" then
			pcall(function()
				UpgradeHandler.ForceSyncServer()
			end)
		end
	end)
end

local hasInRoundValue = false
local matchLoopsActive = false
local folderConnections = {}

-- Forward references cho việc quản lý các loop
local startMatchLoops, startRenderStepped, stopRenderStepped
-- Forward reference cho unregisterInstrument (dùng trong registerInstrument callback)
local unregisterInstrument
local unregisterAltar

-- Kiểm tra xem có mục tiêu hợp lệ nào được bật hay không
local function checkActiveState()
	if not Controller.RadarEnabled then
		return false
	end

	if Controller.GiftESPEnabled and #Controller.ActiveGifts > 0 then
		return true
	end
	if Controller.CadenceESPEnabled and #Controller.ActiveInstruments > 0 then
		return true
	end
	if Controller.AltarESPEnabled and #Controller.ActiveAltars > 0 then
		return true
	end

	return false
end

-- Điều phối trạng thái chạy/dừng của các loop và render
local function updateRunningState()
	if checkActiveState() then
		startMatchLoops()
		startRenderStepped()
	else
		stopRenderStepped()
	end
end

-- Ngắt các kết nối sự kiện thư mục
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

-- Đăng ký các hàm helper để quan sát vật thể thời gian thực (Gift từ Module gốc của game)
local function registerGiftObj(giftObj)
	if not giftObj or giftObj.Collected then
		return
	end

	for _, g in ipairs(Controller.ActiveGifts) do
		if g.id == giftObj.Id then
			return
		end
	end

	local giftModel = typeof(giftObj.Model) == "Instance" and giftObj.Model or nil
	local giftPart = nil
	if giftModel then
		if giftModel:IsA("BasePart") then
			giftPart = giftModel
		elseif giftModel:IsA("Model") then
			giftPart = giftModel.PrimaryPart or giftModel:FindFirstChildWhichIsA("BasePart")
		end
	end

	local color = Logic.ESPColors.Gift
	local giftType = giftObj.Type or "Gift"

	if giftObj.Tripmine then
		color = Logic.ESPColors.Tripmine
		giftType = "Tripmine"
	elseif giftObj.Golden then
		color = Logic.ESPColors.GoldenGift
		giftType = "GoldenGift"
	elseif giftType == "PassageGift" then
		color = Logic.ESPColors.PassageGift
	end

	table.insert(Controller.ActiveGifts, {
		id = giftObj.Id,
		part = giftPart,
		model = giftModel,
		color = color,
		type = giftType,
		rawObj = giftObj,
	})
	updateRunningState()
end

local function unregisterGiftById(id)
	local removed = false
	for i, g in ipairs(Controller.ActiveGifts) do
		if g.id == id then
			table.remove(Controller.ActiveGifts, i)
			removed = true
			break
		end
	end
	if removed then
		updateRunningState()
	end
end

local function registerGift(obj)
	if not (obj:IsA("BasePart") or obj:IsA("Model")) then
		return
	end
	local nameLower = obj.Name:lower()

	local isGift = string.find(nameLower, "gift") or string.find(nameLower, "present") or obj:HasTag("Gift")
	local isTripmine = string.find(nameLower, "tripmine")

	if isGift or isTripmine then
		local targetPart = obj:IsA("Model")
				and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart") or obj)
			or obj
		if not targetPart then
			return
		end

		for _, g in ipairs(Controller.ActiveGifts) do
			if g.part == targetPart or g.model == obj then
				return
			end
		end

		-- Xác định màu sắc và phân loại từ bảng màu dùng chung
		local color = Logic.ESPColors.Gift
		local giftType = "Gift"

		if isTripmine then
			color = Logic.ESPColors.Tripmine
			giftType = "Tripmine"
		elseif string.find(nameLower, "golden") then
			color = Logic.ESPColors.GoldenGift
			giftType = "GoldenGift"
		elseif string.find(nameLower, "passage") then
			color = Logic.ESPColors.PassageGift
			giftType = "PassageGift"
		end

		table.insert(Controller.ActiveGifts, {
			id = obj:GetDebugId(),
			part = targetPart,
			model = obj,
			color = color,
			type = giftType,
			rawObj = nil,
		})
		updateRunningState()
	end
end

local function unregisterGift(obj)
	local removed = false
	for i, g in ipairs(Controller.ActiveGifts) do
		if g.part == obj or g.model == obj then
			table.remove(Controller.ActiveGifts, i)
			removed = true
			break
		end
	end
	if removed then
		updateRunningState()
	end
end

local function registerInstrument(obj)
	if not (obj:IsA("BasePart") or obj:IsA("Model")) then
		return
	end
	if not (Logic.isInstrument(obj.Name) or obj:HasTag("CadenceOrb")) then
		return
	end

	-- Theo ref.lua: CadenceOrb chỉ hợp lệ khi CanTouch = true (chưa bị nhặt)
	if obj:IsA("BasePart") and obj:HasTag("CadenceOrb") then
		if not obj.CanTouch then
			return
		end
	end

	local targetPart = obj:IsA("Model")
			and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart"))
		or obj
	if targetPart and targetPart:IsA("BasePart") then
		for _, inst in ipairs(Controller.ActiveInstruments) do
			if inst.model == obj or inst.part == targetPart then
				return
			end
		end
		table.insert(
			Controller.ActiveInstruments,
			{ part = targetPart, model = obj, color = Logic.ESPColors.Cadence, type = "Cadence" }
		)
		updateRunningState()

		-- Theo ref.lua: lắng nghe CanTouch thay đổi → tự động unregister
		if obj:IsA("BasePart") and obj:HasTag("CadenceOrb") then
			local canTouchConn
			canTouchConn = obj:GetPropertyChangedSignal("CanTouch"):Connect(function()
				if not obj.CanTouch then
					unregisterInstrument(obj)
					if canTouchConn then
						canTouchConn:Disconnect()
						canTouchConn = nil
					end
				end
			end)
			table.insert(folderConnections, canTouchConn)
		end
	end
end

unregisterInstrument = function(obj)
	local removed = false
	for i, inst in ipairs(Controller.ActiveInstruments) do
		if inst.model == obj or inst.part == obj then
			table.remove(Controller.ActiveInstruments, i)
			removed = true
			break
		end
	end
	if removed then
		updateRunningState()
	end
end

local function registerAltar(altarObj)
	-- Theo ref.lua RadarSlop: v2 = v.Parent, HitBox = v2:FindFirstChild("HitBox")
	-- Theo ref.lua ArrowHandler: Position = p1:WaitForChild("Hitbox").Position (trong altarObj)
	-- AltarUsed: attribute trên parent của tagged object
	local parentObj = altarObj.Parent
	if parentObj and parentObj:GetAttribute("AltarUsed") then
		return
	end

	-- Tìm HitBox/Hitbox: ArrowHandler dùng "Hitbox" (h viết thường) trong chính altarObj
	-- RadarSlop dùng "HitBox" từ v.Parent (tức room chứa altar)
	local hitBox = altarObj:FindFirstChild("Hitbox") -- ArrowHandler style (chưa thường)
		or altarObj:FindFirstChild("HitBox") -- fallback viết hoa
	if not hitBox and parentObj then
		hitBox = parentObj:FindFirstChild("HitBox") -- RadarSlop style
			or parentObj:FindFirstChild("Hitbox")
	end

	-- Nếu vẫn không tìm được HitBox, fallback sang bất kỳ BasePart nào
	local targetPart = hitBox
	if not targetPart then
		if altarObj:IsA("BasePart") then
			targetPart = altarObj
		elseif altarObj:IsA("Model") then
			targetPart = altarObj:FindFirstChildWhichIsA("BasePart")
		end
	end

	if not targetPart or not targetPart:IsA("BasePart") then
		return
	end

	for _, a in ipairs(Controller.ActiveAltars) do
		if a.model == altarObj or a.part == targetPart then
			return
		end
	end

	local altarName, altarColor = Logic.getAltarTypeAndColor(altarObj)

	-- Theo ref.lua ArrowHandler dòng 1315:
	-- Arrow chỉ hiển khi altar có tag "Voting" (Enabled > 0)
	-- Script mô phỏng: luôn hiển (ignore voting gate) nhưng đánh dấu voting state
	local isVoting = altarObj:HasTag("Voting")

	table.insert(Controller.ActiveAltars, {
		part = targetPart,
		model = altarObj,
		color = altarColor,
		type = "Altar",
		altarName = altarName,
		isVoting = isVoting,
	})
	updateRunningState()

	-- Lắng nghe sự thay đổi của AltarUsed để tự động huỷ đăng ký Altar
	if parentObj then
		local attrConn
		attrConn = parentObj:GetAttributeChangedSignal("AltarUsed"):Connect(function()
			if parentObj:GetAttribute("AltarUsed") then
				unregisterAltar(altarObj)
				if attrConn then
					attrConn:Disconnect()
				end
			end
		end)
		table.insert(folderConnections, attrConn)
	end
end

unregisterAltar = function(altarObj)
	local removed = false
	for i, a in ipairs(Controller.ActiveAltars) do
		if a.model == altarObj or a.part == altarObj then
			table.remove(Controller.ActiveAltars, i)
			removed = true
			break
		end
	end
	if removed then
		updateRunningState()
	end
end

local function observeItemPools(folder)
	for _, obj in ipairs(folder:GetDescendants()) do
		registerGift(obj)
		registerInstrument(obj)
	end

	local addedConn = folder.DescendantAdded:Connect(function(obj)
		registerGift(obj)
		registerInstrument(obj)
	end)
	table.insert(folderConnections, addedConn)

	local removedConn = folder.DescendantRemoving:Connect(function(obj)
		unregisterGift(obj)
		unregisterInstrument(obj)
	end)
	table.insert(folderConnections, removedConn)
end

local function observeEnemies(folder)
	for _, obj in ipairs(folder:GetDescendants()) do
		registerInstrument(obj)
	end

	local addedConn = folder.DescendantAdded:Connect(function(obj)
		registerInstrument(obj)
	end)
	table.insert(folderConnections, addedConn)

	local removedConn = folder.DescendantRemoving:Connect(function(obj)
		unregisterInstrument(obj)
	end)
	table.insert(folderConnections, removedConn)
end

local function checkRoomForAltar(room)
	local altarObj = room:FindFirstChild("AltarLocation")
		or room:FindFirstChild("AltarModel")
		or room:FindFirstChild("Altar")
	if altarObj then
		registerAltar(altarObj)
	end

	local childAddedConn = room.ChildAdded:Connect(function(child)
		if child.Name == "AltarLocation" or child.Name == "AltarModel" or child.Name == "Altar" then
			registerAltar(child)
		end
	end)
	table.insert(folderConnections, childAddedConn)
end

local function observeCurrentRooms(folder)
	for _, room in ipairs(folder:GetChildren()) do
		checkRoomForAltar(room)
	end

	local roomAddedConn = folder.ChildAdded:Connect(function(room)
		checkRoomForAltar(room)
	end)
	table.insert(folderConnections, roomAddedConn)

	local roomRemovedConn = folder.ChildRemoved:Connect(function(room)
		local altarObj = room:FindFirstChild("AltarLocation")
			or room:FindFirstChild("AltarModel")
			or room:FindFirstChild("Altar")
		if altarObj then
			unregisterAltar(altarObj)
		end
	end)
	table.insert(folderConnections, roomRemovedConn)
end

local function startObservingFolders()
	disconnectFolderObservations()

	table.clear(Controller.ActiveGifts)
	table.clear(Controller.ActiveInstruments)
	table.clear(Controller.ActiveAltars)

	-- 1. Đăng ký các thực thể hiện có bằng CollectionService (Chuẩn xác theo ref.lua)
	for _, obj in ipairs(CollectionService:GetTagged("Gift")) do
		registerGift(obj)
	end
	for _, obj in ipairs(CollectionService:GetTagged("CadenceOrb")) do
		registerInstrument(obj)
	end
	for _, obj in ipairs(CollectionService:GetTagged("Altar")) do
		registerAltar(obj)
	end

	-- Lắng nghe các tín hiệu thêm/bớt tag của CollectionService
	table.insert(folderConnections, CollectionService:GetInstanceAddedSignal("Gift"):Connect(registerGift))
	table.insert(folderConnections, CollectionService:GetInstanceRemovedSignal("Gift"):Connect(unregisterGift))

	table.insert(folderConnections, CollectionService:GetInstanceAddedSignal("CadenceOrb"):Connect(registerInstrument))
	table.insert(
		folderConnections,
		CollectionService:GetInstanceRemovedSignal("CadenceOrb"):Connect(unregisterInstrument)
	)

	table.insert(folderConnections, CollectionService:GetInstanceAddedSignal("Altar"):Connect(registerAltar))
	table.insert(folderConnections, CollectionService:GetInstanceRemovedSignal("Altar"):Connect(unregisterAltar))

	-- Theo ref.lua dòng 1315: Altar chỉ hiển mũi tên khi có tag "Voting"
	-- Cập nhật isVoting state khi có Voting tag thêm/xoá
	table.insert(
		folderConnections,
		CollectionService:GetInstanceAddedSignal("Voting"):Connect(function(obj)
			for _, a in ipairs(Controller.ActiveAltars) do
				if a.model == obj or a.part == obj then
					a.isVoting = true
					break
				end
			end
		end)
	)
	table.insert(
		folderConnections,
		CollectionService:GetInstanceRemovedSignal("Voting"):Connect(function(obj)
			for _, a in ipairs(Controller.ActiveAltars) do
				if a.model == obj or a.part == obj then
					a.isVoting = false
					break
				end
			end
		end)
	)

	-- 2. Fallback: Lắng nghe cấu trúc thư mục Workspace phòng trường hợp game đổi cơ chế
	local function checkAndObserve(child)
		if child.Name == "Item_Pools" then
			observeItemPools(child)
		elseif child.Name == "Enemies" then
			observeEnemies(child)
		elseif child.Name == "CurrentRooms" then
			observeCurrentRooms(child)
		else
			-- Đề phòng Gift hoặc nhạc cụ spawn trực tiếp ngoài workspace
			registerGift(child)
			registerInstrument(child)
		end
	end

	local wsConn = workspace.ChildAdded:Connect(checkAndObserve)
	table.insert(folderConnections, wsConn)

	local wsRemovedConn = workspace.ChildRemoved:Connect(function(child)
		unregisterGift(child)
		unregisterInstrument(child)
	end)
	table.insert(folderConnections, wsRemovedConn)

	local itemPools = workspace:FindFirstChild("Item_Pools")
	if itemPools then
		observeItemPools(itemPools)
	end

	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		observeEnemies(enemies)
	end

	local currentRooms = workspace:FindFirstChild("CurrentRooms")
	if currentRooms then
		observeCurrentRooms(currentRooms)
	end
end

-- RenderStepped connection management
local renderConn = nil

stopRenderStepped = function()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

startRenderStepped = function()
	if renderConn then
		return
	end
	renderConn = RunService.RenderStepped:Connect(function()
		if Controller.Destroyed then
			stopRenderStepped()
			return
		end
		if getgenv()._NULLSCAPE_Globals.activeUpgradeController ~= Controller then
			safeControllerCleanUp()
			stopRenderStepped()
			return
		end
		if not checkActiveState() then
			stopRenderStepped()
			return
		end

		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		pcall(function()
			Executor.updateRender(Controller, GC, hrp)
		end)
	end)
end

-- Vòng lặp cập nhật styles hiển thị (Dot <-> Highlight) cực nhanh mỗi 0.15 giây
startMatchLoops = function()
	if matchLoopsActive then
		return
	end
	matchLoopsActive = true

	task.spawn(function()
		while not Controller.Destroyed and checkActiveState() do
			if getgenv()._NULLSCAPE_Globals.activeUpgradeController ~= Controller then
				safeControllerCleanUp()
				break
			end
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				pcall(function()
					Executor.updateESPStyles(Controller, GC, hrp)
				end)
			end
			task.wait(0.1)
		end
		matchLoopsActive = false
		-- Xóa visuals cũ khi dừng loop (hủy cả các mũi tên chỉ hướng)
		pcall(function()
			Executor.clearVisuals(GC, false)
		end)
	end)
end

local utilityLoopActive = false
local function startUtilityLoop()
	if utilityLoopActive then
		return
	end
	utilityLoopActive = true
	task.spawn(function()
		while not Controller.Destroyed do
			if getgenv()._NULLSCAPE_Globals.activeUpgradeController ~= Controller then
				safeControllerCleanUp()
				break
			end
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				pcall(function()
					Executor.updateMagnet(Controller, hrp)
				end)
				pcall(function()
					Executor.updateBarriers(Controller, GC)
				end)

				-- Tự động kích hoạt lại Matrix Tetrahedron nếu được bật nhưng chưa hook (phòng hờ load trễ/lobby)
				if Controller.MatrixTetrahedronEnabled and MatrixTetrahedron and not MatrixTetrahedron.Hooked then
					pcall(function()
						local reduction = Controller.MomentumReduction or 1.0
						MatrixTetrahedron.setReduction(reduction)
						if reduction > 0 then
							MatrixTetrahedron.start(Controller, GC)
						end
					end)
				end
				if Controller.GraceWingsEnabled and GraceWings and not GraceWings.Hooked then
					pcall(function()
						GraceWings.setMultiplier(Controller.GraceWingsAirControlMultiplier or 1.1)
						GraceWings.start(Controller, GC)
					end)
				end
				if Controller.AdvancedGravityCoilEnabled and AdvancedGravityCoil and not AdvancedGravityCoil.Hooked then
					pcall(function()
						AdvancedGravityCoil.setJumpPower(Controller.AdvancedGravityCoilJumpPower or 28)
						AdvancedGravityCoil.start(Controller, GC)
					end)
				end
				if Controller.BetterJumpPadEnabled and BetterJumpPad and not BetterJumpPad.Hooked then
					pcall(function()
						BetterJumpPad.setJumpPadPower(Controller.BetterJumpPadPower or 100)
						BetterJumpPad.start(Controller, GC)
					end)
				end
				if Controller.SpeedBuffsEnabled and SpeedBuffs and not SpeedBuffs.Hooked then
					pcall(function()
						SpeedBuffs.setSelectedBuffs(Controller.SpeedBuffSelections or {})
						SpeedBuffs.start(Controller, GC)
					end)
				end
			end
			task.wait(0.1)
		end
		utilityLoopActive = false
	end)
end

-- Hàm cập nhật trạng thái sảnh chờ và tự động dọn dẹp visual khi vào sảnh
local function setInLobby(val)
	if inLobby == val then
		return
	end
	inLobby = val
	if val then
		if not Controller.RadarEnabled then
			pcall(function()
				Executor.clearVisuals(GC, false)
			end)
			stopRenderStepped()
		end
	else
		startObservingFolders()
		updateRunningState()
		startUtilityLoop()
	end
end

-- Hàm trigger cập nhật ESP tức thì khi thay đổi cấu hình
local function triggerInstantUpdate()
	updateRunningState()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and checkActiveState() then
		pcall(function()
			Executor.updateESPStyles(Controller, GC, hrp)
		end)
	end
end

-- Bật/tắt radar tổng
function Controller:SetRadarEnabled(value)
	self.RadarEnabled = value
	if not value then
		pcall(function()
			Executor.clearVisuals(GC, false)
		end)
	end
	triggerInstantUpdate()
end

-- Bật/tắt định vị hộp quà
function Controller:SetGiftESP(value)
	self.GiftESPEnabled = value
	triggerInstantUpdate()
end

-- Bật/tắt định vị nhạc cụ Cadence
function Controller:SetCadenceESP(value)
	self.CadenceESPEnabled = value
	triggerInstantUpdate()
end

-- Bật/tắt định vị Đàn tế (Altar)
function Controller:SetAltarESP(value)
	self.AltarESPEnabled = value
	triggerInstantUpdate()
end

-- Bộ lọc loại Altar (Hỗ trợ multi-select table)
function Controller:SetAltarFilter(option)
	if typeof(option) == "string" then
		self.AltarFilter = { option }
	else
		self.AltarFilter = option or { "All" }
	end
	triggerInstantUpdate()
end

-- Thay đổi chế độ hiển thị ESP
function Controller:SetESPStyle(style)
	self.ESPStyle = style or "Highlight"
	pcall(function()
		Executor.clearVisuals(GC, true)
	end)
	triggerInstantUpdate()
end

-- Bật/tắt Auto Collect
function Controller:SetAutoCollectEnabled(value)
	self.AutoCollectEnabled = value
end

-- Bật/tắt mô phỏng nâng cấp Matrix Tetrahedron
function Controller:SetMatrixTetrahedron(value)
	self.MatrixTetrahedronEnabled = value
	if MatrixTetrahedron then
		if value then
			local reduction = self.MomentumReduction or 1.0
			MatrixTetrahedron.setReduction(reduction)
			if reduction > 0 then
				MatrixTetrahedron.start(self, GC)
			end
		else
			MatrixTetrahedron.stop()
		end
	end
end

-- Tùy biến lực Momentum Reduction của Matrix Tetrahedron
function Controller:SetMomentumReduction(value)
	local val = tonumber(value) or 1.0
	if val > 1 then
		val = val / 100
	end
	val = math.clamp(val, 0, 1)

	self.MomentumReduction = val
	if MatrixTetrahedron then
		MatrixTetrahedron.setReduction(val)
		if self.MatrixTetrahedronEnabled and val > 0 then
			MatrixTetrahedron.start(self, GC)
		elseif val == 0 then
			MatrixTetrahedron.stop()
		end
	end
end

-- Điều chỉnh khoảng cách Auto Collect
function Controller:SetGraceWings(value)
	self.GraceWingsEnabled = value == true
	if GraceWings then
		if self.GraceWingsEnabled then
			GraceWings.setMultiplier(self.GraceWingsAirControlMultiplier or 1.1)
			GraceWings.start(self, GC)
		else
			GraceWings.stop()
		end
	end
	refreshUpgradeServerState()
end

function Controller:SetGraceWingsAirControlMultiplier(value)
	local val = math.clamp(tonumber(value) or 1.1, 1.1, 5)
	self.GraceWingsAirControlMultiplier = val
	if GraceWings then
		GraceWings.setMultiplier(val)
		if self.GraceWingsEnabled then
			GraceWings.start(self, GC)
		end
	end
end

function Controller:SetGraceWingsStrongAirControl(value)
	self.GraceWingsStrongAirControl = value == true
	if self.GraceWingsEnabled and GraceWings then
		GraceWings.start(self, GC)
	end
end

function Controller:SetAdvancedGravityCoil(value)
	self.AdvancedGravityCoilEnabled = value == true
	if AdvancedGravityCoil then
		if self.AdvancedGravityCoilEnabled then
			AdvancedGravityCoil.setJumpPower(self.AdvancedGravityCoilJumpPower or 28)
			AdvancedGravityCoil.start(self, GC)
		else
			AdvancedGravityCoil.stop()
		end
	end
	refreshUpgradeServerState()
end

function Controller:SetAdvancedGravityCoilJumpPower(value)
	local minJumpPower = AdvancedGravityCoil and AdvancedGravityCoil.getMinJumpPower and AdvancedGravityCoil.getMinJumpPower() or 28
	local maxJumpPower = AdvancedGravityCoil and AdvancedGravityCoil.getMaxJumpPower and AdvancedGravityCoil.getMaxJumpPower() or 100
	local val = math.clamp(tonumber(value) or minJumpPower, minJumpPower, maxJumpPower)
	self.AdvancedGravityCoilJumpPower = val
	if AdvancedGravityCoil then
		AdvancedGravityCoil.setJumpPower(val)
		if self.AdvancedGravityCoilEnabled then
			AdvancedGravityCoil.start(self, GC)
		end
	end
end

function Controller:SetBetterJumpPad(value)
	self.BetterJumpPadEnabled = value == true
	if BetterJumpPad then
		if self.BetterJumpPadEnabled then
			BetterJumpPad.setJumpPadPower(self.BetterJumpPadPower or 100)
			BetterJumpPad.start(self, GC)
		else
			BetterJumpPad.stop()
		end
	end
	refreshUpgradeServerState()
end

function Controller:SetBetterJumpPadPower(value)
	local minJumpPadPower = BetterJumpPad and BetterJumpPad.getMinJumpPadPower and BetterJumpPad.getMinJumpPadPower() or 100
	local maxJumpPadPower = BetterJumpPad and BetterJumpPad.getMaxJumpPadPower and BetterJumpPad.getMaxJumpPadPower() or 200
	local val = math.clamp(tonumber(value) or minJumpPadPower, minJumpPadPower, maxJumpPadPower)
	self.BetterJumpPadPower = val
	if BetterJumpPad then
		BetterJumpPad.setJumpPadPower(val)
		if self.BetterJumpPadEnabled then
			BetterJumpPad.start(self, GC)
		end
	end
end

function Controller:SetSpeedBuffSelections(selectedOptions)
	if typeof(selectedOptions) ~= "table" then
		selectedOptions = {}
	end

	local validOptions = SpeedBuffs and SpeedBuffs.getOptions and SpeedBuffs.getOptions() or {}
	local normalized = {}
	for _, option in ipairs(selectedOptions) do
		if table.find(validOptions, option) and not table.find(normalized, option) then
			table.insert(normalized, option)
		end
	end

	self.SpeedBuffSelections = normalized
	self.SpeedBuffsEnabled = #normalized > 0

	if SpeedBuffs then
		SpeedBuffs.setSelectedBuffs(normalized)
		if self.SpeedBuffsEnabled then
			SpeedBuffs.start(self, GC)
		else
			SpeedBuffs.stop()
		end
	end

	refreshUpgradeServerState()
end

function Controller:SetAutoCollectRange(value)
	self.AutoCollectRange = value
end

-- Thiết lập chế độ Auto Collect (Legit / Blatant)
function Controller:SetAutoCollectMode(value)
	self.AutoCollectMode = value or "Legit"
end

-- Bật/tắt rào cản vật lý mìn (Tripmine Barrier)
function Controller:SetTripmineBarrier(value)
	self.TripmineBarrierEnabled = value
end

-- Thiết lập chế độ chống mìn (Passthrough / PreDetonate / Barrier)
function Controller:SetTripmineMode(value)
	self.TripmineMode = value or "Passthrough"
end

-- Thiết lập khoảng cách kích nổ mìn cơ sở
function Controller:SetTripmineDetonationDistance(value)
	self.TripmineDetonationDistance = value or 15
end

-- Thiết lập biên độ dao động khoảng cách kích nổ ngẫu nhiên
function Controller:SetTripmineDetonationJitter(value)
	self.TripmineDetonationJitter = value or 2
end

-- Bật/tắt mô phỏng Defuse Kit
function Controller:SetSimulateDefuseKit(value)
	self.SimulateDefuseKit = value
end

-- Điều chỉnh số stack Defuse Kit mô phỏng
function Controller:SetDefuseKitStack(value)
	self.DefuseKitStack = value
end

-- Hàm dọn dẹp tài nguyên (GC) khi tắt hoặc hủy UI
function Controller:CleanUp()
	self.Destroyed = true
	self.GraceWingsEnabled = false
	self.AdvancedGravityCoilEnabled = false
	self.BetterJumpPadEnabled = false
	self.SpeedBuffsEnabled = false
	disconnectFolderObservations()
	stopRenderStepped()

	if MatrixTetrahedron then
		pcall(function()
			MatrixTetrahedron.stop()
		end)
	end
	if GraceWings then
		pcall(function()
			GraceWings.stop()
		end)
	end
	if AdvancedGravityCoil then
		pcall(function()
			AdvancedGravityCoil.stop()
		end)
	end
	if BetterJumpPad then
		pcall(function()
			BetterJumpPad.stop()
		end)
	end
	if SpeedBuffs then
		pcall(function()
			SpeedBuffs.stop()
		end)
	end
	refreshUpgradeServerState()

	if self.PermanentConnections then
		for _, conn in ipairs(self.PermanentConnections) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		table.clear(self.PermanentConnections)
	end

	GC.cleanAll()
end

local function findPoolFolders()
	local folders = {}
	local itemPools = workspace:FindFirstChild("Item_Pools")
	if itemPools then
		for _, child in ipairs(itemPools:GetChildren()) do
			if child:IsA("Folder") and string.find(child.Name:lower(), "shell") then
				table.insert(folders, child)
			end
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Folder") and string.find(child.Name:lower(), "shell") then
			table.insert(folders, child)
		end
	end
	return folders
end

local function scanActiveGiftsFromPools()
	local activeGifts = {}
	local folders = findPoolFolders()

	for _, folder in ipairs(folders) do
		local folderNameLower = folder.Name:lower()
		local shellType = "Gift"

		if string.find(folderNameLower, "tripmine") then
			shellType = "Tripmine"
		elseif string.find(folderNameLower, "golden") then
			shellType = "GoldenGift"
		elseif string.find(folderNameLower, "passage") then
			shellType = "PassageGift"
		end

		for _, shell in ipairs(folder:GetChildren()) do
			local weld = shell:FindFirstChildWhichIsA("Weld") or shell:FindFirstChild("Weld")
			local part1 = weld and weld.Part1

			if part1 and part1.Parent and part1:IsDescendantOf(workspace) then
				if part1.Transparency < 0.99 then
					local color = Logic.ESPColors.Gift
					if shellType == "Tripmine" then
						color = Logic.ESPColors.Tripmine
					elseif shellType == "GoldenGift" then
						color = Logic.ESPColors.GoldenGift
					elseif shellType == "PassageGift" then
						color = Logic.ESPColors.PassageGift
					end

					table.insert(activeGifts, {
						id = part1:GetDebugId(),
						part = part1,
						model = part1,
						color = color,
						type = shellType,
						rawObj = nil,
					})
				end
			end
		end
	end

	return activeGifts
end

local function startGiftPoolObserver()
	task.spawn(function()
		while not Controller.Destroyed do
			if getgenv()._NULLSCAPE_Globals.activeUpgradeController ~= Controller then
				safeControllerCleanUp()
				break
			end
			if Controller.RadarEnabled and Controller.GiftESPEnabled then
				local poolGifts = scanActiveGiftsFromPools()

				-- Hợp nhất dữ liệu quét pool với ActiveGifts hiện tại (tránh trùng lặp)
				local newGifts = {}

				-- Giữ lại các gift từ setupGiftClientHook (nếu có rawObj) mà chưa bị Collected
				for _, g in ipairs(Controller.ActiveGifts) do
					if g.rawObj and not g.rawObj.Collected and not g.rawObj.Destroyed then
						table.insert(newGifts, g)
					end
				end

				-- Thêm các gift quét được từ pool folder vào nếu chưa có
				for _, pg in ipairs(poolGifts) do
					local exists = false
					for _, g in ipairs(newGifts) do
						if g.part == pg.part or g.id == pg.id then
							exists = true
							break
						end
					end
					if not exists then
						table.insert(newGifts, pg)
					end
				end

				Controller.ActiveGifts = newGifts
				updateRunningState()
			end
			task.wait(0.2)
		end
	end)
end

-- Đăng ký các dispatcher cho các hooks
getgenv()._NULLSCAPE_Globals.onGiftCreated = function(giftObj)
	pcall(registerGiftObj, giftObj)
end
getgenv()._NULLSCAPE_Globals.onGiftDestroyed = function(id)
	pcall(unregisterGiftById, id)
end

getgenv()._NULLSCAPE_Globals.isUpgradeEnabledCheck = function(...)
	local args = { ... }
	local isDefuse = false
	local isTetrahedron = false
	local isGraceWings = false
	local isAdvancedGravityCoil = false
	local isBetterJumpPad = false
	local isRadarPlayer = false
	local isRadarAltars = false
	local isRadarInstruments = false
	for _, v in ipairs(args) do
		if v == "DefuseKit" or v == "Defuse Kit" then
			isDefuse = true
		elseif v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
			isTetrahedron = true
		elseif v == "GraceWings" or v == "Grace Wings" then
			isGraceWings = true
		elseif v == "AdvancedGravityCoil" or v == "Advanced Gravity Coil" then
			isAdvancedGravityCoil = true
		elseif v == "BetterJumpPad" or v == "Better Jump Pad" then
			isBetterJumpPad = true
		elseif v == "RadarPlayer" then
			isRadarPlayer = true
		elseif v == "RadarAltars" then
			isRadarAltars = true
		elseif v == "RadarInstruments" then
			isRadarInstruments = true
		end
	end
	if isDefuse and Controller.SimulateDefuseKit then
		return true, true
	end
	if isTetrahedron and Controller.MatrixTetrahedronEnabled and (Controller.MomentumReduction or 0) >= 0.6 then
		return true, true
	end
	if isGraceWings and Controller.GraceWingsEnabled then
		return true, true
	end
	if isAdvancedGravityCoil and Controller.AdvancedGravityCoilEnabled then
		return true, true
	end
	if isBetterJumpPad and Controller.BetterJumpPadEnabled then
		return true, true
	end
	if isRadarPlayer and Controller.RadarEnabled then
		return true, true
	end
	if isRadarAltars or isRadarInstruments then
		return false
	end
	return false
end

getgenv()._NULLSCAPE_Globals.getUpgradeStackCheck = function(...)
	local args = { ... }
	local isDefuse = false
	local isTetrahedron = false
	local isGraceWings = false
	local isAdvancedGravityCoil = false
	local isBetterJumpPad = false
	local isRadarPlayer = false
	local isRadarSubUpgrade = false
	for _, v in ipairs(args) do
		if v == "DefuseKit" or v == "Defuse Kit" then
			isDefuse = true
		elseif v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
			isTetrahedron = true
		elseif v == "GraceWings" or v == "Grace Wings" then
			isGraceWings = true
		elseif v == "AdvancedGravityCoil" or v == "Advanced Gravity Coil" then
			isAdvancedGravityCoil = true
		elseif v == "BetterJumpPad" or v == "Better Jump Pad" then
			isBetterJumpPad = true
		elseif v == "RadarPlayer" then
			isRadarPlayer = true
		elseif v == "RadarAltars" or v == "RadarInstruments" then
			isRadarSubUpgrade = true
		end
	end
	if isDefuse and Controller.SimulateDefuseKit then
		return true, Controller.DefuseKitStack or 3
	end
	if isTetrahedron and Controller.MatrixTetrahedronEnabled and (Controller.MomentumReduction or 0) >= 0.6 then
		return true, 1
	end
	if isGraceWings and Controller.GraceWingsEnabled then
		return true, 1
	end
	if isAdvancedGravityCoil and Controller.AdvancedGravityCoilEnabled then
		return true, 1
	end
	if isBetterJumpPad and Controller.BetterJumpPadEnabled then
		return true, 1
	end
	if isRadarPlayer and Controller.RadarEnabled then
		return true, 1
	end
	if isRadarSubUpgrade then
		return false
	end
	return false
end

local function setupGiftClientHook()
	task.spawn(function()
		print("[NULLSCAPE Radar] Bắt đầu tìm kiếm ClientModules...")
		local ClientModules = ReplicatedFirst:FindFirstChild("ClientModules")
			or ReplicatedStorage:FindFirstChild("ClientModules")
		if not ClientModules then
			pcall(function()
				ClientModules = ReplicatedFirst:WaitForChild("ClientModules", 5)
			end)
			if not ClientModules then
				pcall(function()
					ClientModules = ReplicatedStorage:WaitForChild("ClientModules", 5)
				end)
			end
		end

		if not ClientModules then
			warn(
				"[NULLSCAPE Radar] LỖI: Không tìm thấy thư mục ClientModules ở cả ReplicatedFirst và ReplicatedStorage."
			)
			return
		end

		print("[NULLSCAPE Radar] Đã tìm thấy ClientModules tại: " .. ClientModules:GetFullName())

		local GiftClient = ClientModules:FindFirstChild("GiftClient") or ClientModules:WaitForChild("GiftClient", 5)
		local GiftClientHandlerModule = GiftClient
			and (GiftClient:FindFirstChild("GiftClientHandler") or GiftClient:WaitForChild("GiftClientHandler", 5))

		if not GiftClientHandlerModule then
			warn("[NULLSCAPE Radar] LỖI: Không tìm thấy module GiftClientHandler.")
			return
		end

		local success, GiftClientHandler = pcall(require, GiftClientHandlerModule)
		if success and typeof(GiftClientHandler) == "table" then
			print("[NULLSCAPE Radar] Hook GiftClientHandler thành công!")

			-- Đăng ký các gift hiện có
			local existingCount = 0
			if GiftClientHandler.Gifts then
				for _, giftObj in pairs(GiftClientHandler.Gifts) do
					pcall(registerGiftObj, giftObj)
					existingCount = existingCount + 1
				end
			end
			print("[NULLSCAPE Radar] Đã đăng ký " .. tostring(existingCount) .. " Hộp quà hiện có.")

			-- Hook hàm new
			-- Hook hàm new
			if not getgenv()._NULLSCAPE_Globals.GiftClientNewHooked then
				local originalNew = GiftClientHandler.new
				getgenv()._NULLSCAPE_Globals.OriginalGiftClientNew = originalNew

				GiftClientHandler.new = function(...)
					local orig = getgenv()._NULLSCAPE_Globals.OriginalGiftClientNew
					local giftObj = orig(...)
					if giftObj then
						local cb = getgenv()._NULLSCAPE_Globals.onGiftCreated
						if cb then
							pcall(cb, giftObj)
						end
					end
					return giftObj
				end
				getgenv()._NULLSCAPE_Globals.GiftClientNewHooked = true
				print("[NULLSCAPE Radar] Đã hook hàm GiftClientHandler.new")
			end

			-- Hook hàm DestroyGift
			if not getgenv()._NULLSCAPE_Globals.GiftClientDestroyHooked then
				local originalDestroyGift = GiftClientHandler.DestroyGift
				getgenv()._NULLSCAPE_Globals.OriginalGiftClientDestroy = originalDestroyGift

				GiftClientHandler.DestroyGift = function(id, ...)
					local cb = getgenv()._NULLSCAPE_Globals.onGiftDestroyed
					if cb then
						pcall(cb, id)
					end
					local orig = getgenv()._NULLSCAPE_Globals.OriginalGiftClientDestroy
					return orig(id, ...)
				end
				getgenv()._NULLSCAPE_Globals.GiftClientDestroyHooked = true
				print("[NULLSCAPE Radar] Đã hook hàm GiftClientHandler.DestroyGift")
			end
		else
			warn("[NULLSCAPE Radar] LỖI: Không thể require GiftClientHandler: " .. tostring(GiftClientHandler))
		end
	end)
end

-- Đăng ký active controller hiện tại để tự động dừng các phiên bản cũ
getgenv()._NULLSCAPE_Globals.activeUpgradeController = Controller

-- Khởi tạo ban đầu khi nạp script
startObservingFolders()
setupGiftClientHook()
startGiftPoolObserver()
updateRunningState()
startUtilityLoop()

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
			if getgenv()._NULLSCAPE_Globals.activeUpgradeController ~= Controller then
				safeControllerCleanUp()
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
		if getgenv()._NULLSCAPE_Globals.activeUpgradeController ~= Controller then
			safeControllerCleanUp()
			break
		end
		setInLobby(not isInMatch())
	end
end)

local function hookUpgradeHandler()
	task.spawn(function()
		local ClientModules = ReplicatedFirst:WaitForChild("ClientModules", 15)
		local UpgradeHandlerModule = ClientModules and ClientModules:WaitForChild("UpgradeHandler", 15)
		if UpgradeHandlerModule then
			local success, UpgradeHandler = pcall(require, UpgradeHandlerModule)
			if success and typeof(UpgradeHandler) == "table" then
				if UpgradeHandler.IsUpgradeEnabled then
					if typeof(hookfunction) == "function" then
						if not getgenv()._NULLSCAPE_Globals.IsUpgradeEnabledHooked then
							local oldIsUpgradeEnabled
							oldIsUpgradeEnabled = hookfunction(UpgradeHandler.IsUpgradeEnabled, function(...)
								local cb = getgenv()._NULLSCAPE_Globals.isUpgradeEnabledCheck
								if cb then
									local override, result = cb(...)
									if override then
										return result
									end
								end
								return oldIsUpgradeEnabled(...)
							end)
							getgenv()._NULLSCAPE_Globals.OriginalIsUpgradeEnabled = oldIsUpgradeEnabled
							getgenv()._NULLSCAPE_Globals.IsUpgradeEnabledHooked = true
						end
					else
						if not getgenv()._NULLSCAPE_Globals.IsUpgradeEnabledHooked then
							local oldIsUpgradeEnabled = UpgradeHandler.IsUpgradeEnabled
							getgenv()._NULLSCAPE_Globals.OriginalIsUpgradeEnabled = oldIsUpgradeEnabled
							UpgradeHandler.IsUpgradeEnabled = function(...)
								local cb = getgenv()._NULLSCAPE_Globals.isUpgradeEnabledCheck
								if cb then
									local override, result = cb(...)
									if override then
										return result
									end
								end
								return getgenv()._NULLSCAPE_Globals.OriginalIsUpgradeEnabled(...)
							end
							getgenv()._NULLSCAPE_Globals.IsUpgradeEnabledHooked = true
						end
					end
				end

				if UpgradeHandler.GetUpgradeStack then
					if typeof(hookfunction) == "function" then
						if not getgenv()._NULLSCAPE_Globals.GetUpgradeStackHooked then
							local oldGetUpgradeStack
							oldGetUpgradeStack = hookfunction(UpgradeHandler.GetUpgradeStack, function(...)
								local cb = getgenv()._NULLSCAPE_Globals.getUpgradeStackCheck
								if cb then
									local override, result = cb(...)
									if override then
										return result
									end
								end
								return oldGetUpgradeStack(...)
							end)
							getgenv()._NULLSCAPE_Globals.OriginalGetUpgradeStack = oldGetUpgradeStack
							getgenv()._NULLSCAPE_Globals.GetUpgradeStackHooked = true
						end
					else
						if not getgenv()._NULLSCAPE_Globals.GetUpgradeStackHooked then
							local oldGetUpgradeStack = UpgradeHandler.GetUpgradeStack
							getgenv()._NULLSCAPE_Globals.OriginalGetUpgradeStack = oldGetUpgradeStack
							UpgradeHandler.GetUpgradeStack = function(...)
								local cb = getgenv()._NULLSCAPE_Globals.getUpgradeStackCheck
								if cb then
									local override, result = cb(...)
									if override then
										return result
									end
								end
								return getgenv()._NULLSCAPE_Globals.OriginalGetUpgradeStack(...)
							end
							getgenv()._NULLSCAPE_Globals.GetUpgradeStackHooked = true
						end
					end
				end
			end
		end
	end)
end

pcall(hookUpgradeHandler)

return Controller
