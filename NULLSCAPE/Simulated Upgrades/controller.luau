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
	TripmineESPEnabled = false,
	CadenceESPEnabled = false,
	AltarESPEnabled = false,
	AltarFilter = { "All" },
	ESPStyle = "Highlight", -- Mặc định: "Highlight" hoặc "Dot"
	Destroyed = false,
	inLobby = true,

	AutoCollectEnabled = false,
	AutoCollectRange = 20,
	AutoCollectGiftRange = 20,
	AutoCollectInstrumentRange = 0,
	AutoCollectTargets = { "Gift/GoldenGift", "Instrument (Cadence)" },
	AutoCollectMode = "Legit",
	CollectMedalKeybind = "V",

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
	TripmineMode = "Blocker", -- "Blocker" (chan/day khoi min) | "Barrier" (local iframe only)
	TripmineDetonationDistance = 15,
	TripmineDetonationJitter = 2,
	TripmineBlastSafeRadius = 8, -- Legacy: active tripmine detonation is disabled by Defuse Kits
	ChargerTripmineAssistEnabled = false,
	ChargerTripmineMode = "Auto",
	ChargerTripmineDistance = 15,
	ChargerTripmineJitter = 2,
	SimulateDefuseKit = false,
	DefuseKitStack = 3,

	NearestGiftPosition = nil,
	NearestCadencePosition = nil,
	NearestAltarPosition = nil,
	ActiveGifts = {},
	ActiveInstruments = {},
	ActiveAltars = {},
	PermanentConnections = {},

	-- Player & Enemy ESP (cơ chế tạm thời giống RadarPlayer của game gốc)
	-- Tự "thả ra" khi native RadarPlayer upgrade có hiệu lực thật
	PlayerESPEnabled = false,
	PlayerESPColor = Color3.fromRGB(255, 255, 255), -- Trắng như game gốc
	EnemyESPEnabled = false,
	EnemyESPColor = Color3.fromRGB(255, 128, 0),   -- Cam để phân biệt với player
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
Controller.inLobby = inLobby
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
local instantUpdateQueued = false
local folderConnections = {}
local OBSERVE_REGISTER_BATCH_SIZE = 80
local GIFT_POOL_SCAN_INTERVAL = 0.85

-- Forward references cho việc quản lý các loop
local startMatchLoops, stopRenderStepped
local triggerInstantUpdate
-- Forward reference cho unregisterInstrument (dùng trong registerInstrument callback)
local unregisterInstrument
local unregisterAltar

local function isFeatureSimulating(featureKey)
	if Controller.RadarEnabled ~= true then
		return false
	end
	return Logic.isSimulationToggleOn(Controller, featureKey)
end

-- Kiểm tra xem có mục tiêu hợp lệ nào được bật hay không
local function checkActiveState()
	if isFeatureSimulating("Gift") or isFeatureSimulating("Tripmine") then
		if #Controller.ActiveGifts > 0 then
			return true
		end
	end
	if isFeatureSimulating("Cadence") and #Controller.ActiveInstruments > 0 then
		return true
	end
	if isFeatureSimulating("Altar") and #Controller.ActiveAltars > 0 then
		return true
	end
	if isFeatureSimulating("Player") or isFeatureSimulating("Enemy") then
		return true
	end

	return false
end

local function setFeatureToggle(fieldName, value)
	local nextValue = value == true
	if Controller[fieldName] == nextValue then
		return
	end
	Controller[fieldName] = nextValue
	Logic.syncSimulatedUpgradeHud(Controller)
	triggerInstantUpdate()
end

-- Điều phối trạng thái chạy/dừng của các loop và render
local function updateRunningState()
	if checkActiveState() then
		startMatchLoops()
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
	if typeof(giftObj) ~= "table" then
		return
	end
	if giftObj.Id == nil then
		return
	end
	if giftObj.Collected then
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
	task.spawn(function()
		local stack = folder:GetChildren()
		local scannedThisSlice = 0
		while #stack > 0 and folder.Parent and not Controller.Destroyed do
			local obj = table.remove(stack)
			if obj and obj.Parent then
				registerGift(obj)
				registerInstrument(obj)

				local children = obj:GetChildren()
				for i = #children, 1, -1 do
					table.insert(stack, children[i])
				end
			end

			scannedThisSlice += 1
			if scannedThisSlice >= OBSERVE_REGISTER_BATCH_SIZE then
				scannedThisSlice = 0
				task.wait()
			end
		end
	end)

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



local function startObservingFolders()
	disconnectFolderObservations()

	table.clear(Controller.ActiveGifts)
	table.clear(Controller.ActiveInstruments)
	table.clear(Controller.ActiveAltars)

	-- Register existing CollectionService tags in batches to avoid round-start spikes
	local function processTagged(tagName, registerFn)
		task.spawn(function()
			local processedThisSlice = 0
			for _, obj in ipairs(CollectionService:GetTagged(tagName)) do
				if Controller.Destroyed or Controller.inLobby then
					break
				end
				registerFn(obj)
				processedThisSlice += 1
				if processedThisSlice >= OBSERVE_REGISTER_BATCH_SIZE then
					processedThisSlice = 0
					task.wait()
				end
			end
		end)
	end
	processTagged("Gift", registerGift)
	processTagged("CadenceOrb", registerInstrument)
	processTagged("Altar", registerAltar)

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
		elseif child.Name ~= "Enemies" and child.Name ~= "CurrentRooms" then
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
end

local function hasUtilityWork()
	return Controller.AutoCollectEnabled
		or Controller.TripmineBarrierEnabled
		or Controller.ChargerTripmineAssistEnabled
		or Controller.MatrixTetrahedronEnabled
		or Controller.GraceWingsEnabled
		or Controller.AdvancedGravityCoilEnabled
		or Controller.BetterJumpPadEnabled
		or Controller.SpeedBuffsEnabled
end

-- RenderStepped connection management
stopRenderStepped = function()
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
			task.wait(hasUtilityWork() and 0.12 or 0.6)
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
			if hrp and not Controller.inLobby then
				if Controller.AutoCollectEnabled then
					pcall(function()
						Executor.updateMagnet(Controller, hrp)
					end)
				end
				if Controller.TripmineBarrierEnabled or Controller.ChargerTripmineAssistEnabled then
					pcall(function()
						Executor.updateBarriers(Controller, GC)
					end)
				end

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
			task.wait(hasUtilityWork() and 0.12 or 0.6)
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
	Controller.inLobby = val
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
triggerInstantUpdate = function()
	if instantUpdateQueued then
		return
	end
	instantUpdateQueued = true
	task.defer(function()
		instantUpdateQueued = false
		if Controller.Destroyed then
			return
		end
		updateRunningState()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and checkActiveState() then
			pcall(function()
				Executor.updateESPStyles(Controller, GC, hrp)
			end)
		end
	end)
end

-- Bật/tắt radar tổng
function Controller:SetRadarEnabled(value)
	self.RadarEnabled = value
	if not value then
		pcall(function()
			Executor.clearVisuals(GC, false)
		end)
	end
	Logic.syncSimulatedUpgradeHud(self)
	triggerInstantUpdate()
end

-- Bật/tắt định vị hộp quà
function Controller:SetGiftESP(value)
	setFeatureToggle("GiftESPEnabled", value)
end

-- Bật/tắt định vị bẫy mìn Tripmine
function Controller:SetTripmineESP(value)
	setFeatureToggle("TripmineESPEnabled", value)
end

-- Bật/tắt định vị nhạc cụ Cadence
function Controller:SetCadenceESP(value)
	setFeatureToggle("CadenceESPEnabled", value)
end

-- Bật/tắt định vị Đàn tế (Altar)
function Controller:SetAltarESP(value)
	setFeatureToggle("AltarESPEnabled", value)
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

-- Bật/tắt ESP cho Player khác
function Controller:SetPlayerESP(value, color)
	Controller.PlayerESPEnabled = value == true
	if color then
		self.PlayerESPColor = color
	end
	Logic.syncSimulatedUpgradeHud(self)
	triggerInstantUpdate()
end

function Controller:SetEnemyESP(value, color)
	Controller.EnemyESPEnabled = value == true
	if color then
		self.EnemyESPColor = color
	end
	Logic.syncSimulatedUpgradeHud(self)
	triggerInstantUpdate()
end

-- Bật/tắt Auto Collect
function Controller:SetESPSelections(selections)
	selections = typeof(selections) == "table" and selections or {}
	local changed = false

	local function apply(fieldName, optionName)
		local nextValue = table.find(selections, optionName) ~= nil
		if self[fieldName] ~= nextValue then
			self[fieldName] = nextValue
			changed = true
		end
	end

	apply("GiftESPEnabled", "Gift")
	apply("TripmineESPEnabled", "Tripmine")
	apply("CadenceESPEnabled", "Cadence")
	apply("AltarESPEnabled", "Altar")
	apply("PlayerESPEnabled", "Player")
	apply("EnemyESPEnabled", "Enemy")

	if changed then
		Logic.syncSimulatedUpgradeHud(self)
		triggerInstantUpdate()
	end
end

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
	self.AutoCollectGiftRange = value
end

function Controller:SetAutoCollectGiftRange(value)
	self.AutoCollectGiftRange = value
	self.AutoCollectRange = value
end

function Controller:SetCollectMedalKeybind(value)
	self.CollectMedalKeybind = value
end

function Controller:TriggerMedalAction()
	if self.inLobby then
		if getgenv().Rayfield then
			getgenv().Rayfield:Notify({
				Title = "Medal Action",
				Content = "Cannot collect Medal while in lobby!",
				Duration = 2,
			})
		end
		return
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local carriesMedal = char:FindFirstChild("Medal") ~= nil
	if carriesMedal then
		-- Auto-submit to Beacon
		local beacon = workspace:FindFirstChild("Beacon")
		local beaconPart = beacon and beacon:FindFirstChildWhichIsA("BasePart", true)
		if beaconPart then
			local distToBeacon = (beaconPart.Position - hrp.Position).Magnitude
			if distToBeacon <= 30 then
				pcall(function()
					if typeof(firetouchinterest) == "function" then
						firetouchinterest(beaconPart, hrp, 0)
						task.wait()
						firetouchinterest(beaconPart, hrp, 1)
						if getgenv().Rayfield then
							getgenv().Rayfield:Notify({
								Title = "Medal Action",
								Content = "Medal submitted successfully!",
								Duration = 2,
							})
						end
					end
				end)
			else
				if getgenv().Rayfield then
					getgenv().Rayfield:Notify({
						Title = "Medal Action",
						Content = "Too far from Beacon! (Distance: " .. string.format("%.1f", distToBeacon) .. " studs, limit: 30)",
						Duration = 3,
					})
				end
			end
		else
			if getgenv().Rayfield then
				getgenv().Rayfield:Notify({
					Title = "Medal Action",
					Content = "Beacon not found in workspace!",
					Duration = 2.5,
				})
			end
		end
	else
		-- Auto-pickup Medal using Blink Pick / Proximity Teleportation
		-- Search for Medal
		local function findMedal()
			local medal = workspace:FindFirstChild("Medal")
			if medal then
				if medal:IsA("BasePart") then
					return medal
				elseif medal:IsA("Model") then
					local handle = medal:FindFirstChild("Handle") or medal:FindFirstChildWhichIsA("BasePart", true)
					if handle then
						return handle
					end
				end
			end
			for _, child in ipairs(workspace:GetChildren()) do
				if child.Name == "Medal" then
					if child:IsA("BasePart") then
						return child
					end
					local handle = child:FindFirstChild("Handle") or child:FindFirstChildWhichIsA("BasePart", true)
					if handle then
						return handle
					end
				end
			end
			return nil
		end

		local medal = findMedal()
		if medal then
			pcall(function()
				local oldCFrame = hrp.CFrame
				local oldAnchored = hrp.Anchored
				
				-- Safe blink pick: Anchors root and teleports right on top of the Medal handle for 0.05s
				hrp.Anchored = true
				hrp.CFrame = medal.CFrame * CFrame.new(0, 1.5, 0)
				task.wait(0.05)
				hrp.CFrame = oldCFrame
				hrp.Anchored = oldAnchored
				
				if getgenv().Rayfield then
					getgenv().Rayfield:Notify({
						Title = "Medal Action",
						Content = "Attempted Medal pick up!",
						Duration = 2,
					})
				end
			end)
		else
			if getgenv().Rayfield then
				getgenv().Rayfield:Notify({
					Title = "Medal Action",
					Content = "Medal not found in workspace!",
					Duration = 2.5,
				})
			end
		end
	end
end

function Controller:SetAutoCollectInstrumentRange(value)
	self.AutoCollectInstrumentRange = value
end

function Controller:SetAutoCollectTargets(value)
	self.AutoCollectTargets = value or {}
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
	self.TripmineMode = value or "Blocker"
end

-- Thiết lập khoảng cách kích nổ mìn cơ sở
function Controller:SetTripmineDetonationDistance(value)
	self.TripmineDetonationDistance = value or 15
end

-- Thiết lập biên độ dao động khoảng cách kích nổ ngẫu nhiên
function Controller:SetTripmineDetonationJitter(value)
	self.TripmineDetonationJitter = value or 2
end

function Controller:SetChargerTripmineAssist(value)
	self.ChargerTripmineAssistEnabled = value
end

function Controller:SetChargerTripmineMode(value)
	self.ChargerTripmineMode = value or "Auto"
end

function Controller:SetChargerTripmineDistance(value)
	self.ChargerTripmineDistance = value or 15
end

function Controller:SetChargerTripmineJitter(value)
	self.ChargerTripmineJitter = value or 2
end

-- Thiết lập bán kính an toàn trước khi kích nổ mìn
function Controller:SetTripmineBlastSafeRadius(value)
	self.TripmineBlastSafeRadius = value or 8
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

	-- Giải phóng biến môi trường để hỗ trợ dọn dẹp bộ nhớ (GC)
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and globals.activeUpgradeController == self then
		globals.activeUpgradeController = nil
	end
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
			local shouldScanPools = not Controller.inLobby and (isFeatureSimulating("Gift") or isFeatureSimulating("Tripmine"))
			if shouldScanPools then
				local poolGifts = scanActiveGiftsFromPools()
				local newGifts = {}
				local seen = {}

				for _, g in ipairs(Controller.ActiveGifts) do
					if g.rawObj and not g.rawObj.Collected and not g.rawObj.Destroyed then
						table.insert(newGifts, g)
						seen[g.part or g.id] = true
					end
				end

				for _, pg in ipairs(poolGifts) do
					local key = pg.part or pg.id
					if not seen[key] then
						seen[key] = true
						table.insert(newGifts, pg)
					end
				end

				Controller.ActiveGifts = newGifts
				updateRunningState()
			end
			task.wait(shouldScanPools and GIFT_POOL_SCAN_INTERVAL or 1.2)
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
		else
			local shouldSpoof, result = Logic.shouldSpoofUpgradeEnabled(Controller, v)
			if shouldSpoof then
				return true, result
			end
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
	return false
end

getgenv()._NULLSCAPE_Globals.getUpgradeStackCheck = function(...)
	local args = { ... }
	local isDefuse = false
	local isTetrahedron = false
	local isGraceWings = false
	local isAdvancedGravityCoil = false
	local isBetterJumpPad = false
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
		else
			local shouldSpoof, stack = Logic.shouldSpoofUpgradeStack(Controller, v)
			if shouldSpoof then
				return true, stack
			end
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
					if typeof(orig) ~= "function" then
						return nil
					end

					local ok, giftObj = pcall(orig, ...)
					if not ok then
						warn("[NULLSCAPE Radar] GiftClientHandler.new original failed: " .. tostring(giftObj))
						return nil
					end

					if giftObj then
						local cb = getgenv()._NULLSCAPE_Globals.onGiftCreated
						if typeof(cb) == "function" then
							local cbOk, cbErr = pcall(cb, giftObj)
							if not cbOk then
								warn("[NULLSCAPE Radar] onGiftCreated failed: " .. tostring(cbErr))
							end
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
local previousUpgradeController = getgenv()._NULLSCAPE_Globals.activeUpgradeController
if previousUpgradeController and previousUpgradeController ~= Controller and typeof(previousUpgradeController.CleanUp) == "function" then
	pcall(function()
		previousUpgradeController:CleanUp()
	end)
end
getgenv()._NULLSCAPE_Globals.activeUpgradeController = Controller

-- Khởi tạo ban đầu khi nạp script
Logic.syncSimulatedUpgradeHud(Controller)
Logic.bindUpgradeWatcher(Controller, function()
	if triggerInstantUpdate then
		triggerInstantUpdate()
	end
end)
if not inLobby then
	startObservingFolders()
end
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
