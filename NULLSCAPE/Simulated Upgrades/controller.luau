--!nocheck
-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Phát lệnh gọi quét định vị (scan) định kỳ thông qua Executor.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local getgenv = getgenv
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local LocalPlayer = Players.LocalPlayer

local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local Executor = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/executor.luau")
local GC = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/GC.luau")
local MatrixTetrahedron = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Matrix Tetrahedron.luau")
local GraceWings = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Grace Wings.luau")
local AdvancedGravityCoil = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Advanced Gravity Coil.luau")
local BetterJumpPad = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Better Jump Pad.luau")
local SpeedBuffs = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Speed Buffs.luau")
local Helmet = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Helmet.luau")
local MiniatureHourglass = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Miniature Hourglass.luau")

local Controller = {
	RadarEnabled = false,
	RadarFeatures = { "Gift", "Tripmine", "Cadance", "Altar", "Player", "Enemy" },
	Destroyed = false,
	inLobby = true,

	AutoCollectEnabled = false,
	GiftMagnetBlocked = true,
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
	HelmetEnabled = false,
	MiniatureHourglassEnabled = false,
	GrappleVirtualNinjaBelt = false,
	GrappleVirtualSharkTail = false,

	TripmineBarrierEnabled = false,
	TripmineBarrierMode = "Off",
	TripmineBarrierCollectDelay = 0.08,
	TripmineDetonationDistance = 15,
	TripmineDetonationJitter = 2,
	TripmineBlastSafeRadius = 8, -- Legacy: active tripmine detonation is disabled by Defuse Kits

	PermanentConnections = {},
	RespawnRefreshToken = 0,
	LastReapplyAt = 0,
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
local folderConnections = {}

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function isControllerActiveOrUnclaimed(controller)
	local globals = getGlobals()
	return globals.activeUpgradeController == controller or globals.activeUpgradeController == nil
end

local function claimActiveController(controller)
	local globals = getGlobals()
	if globals.activeUpgradeController == nil then
		globals.activeUpgradeController = controller
	end

	return globals.activeUpgradeController == controller
end

-- Stubs for backward/compatibility reference
local function triggerInstantUpdate() end
local function updateRunningState() end
local function stopRenderStepped() end
local function checkActiveState()
	return false
end
local startMatchLoops
local instantUpdateQueued = false
local matchLoopsActive = false

local function disconnectFolderObservations()
	table.clear(folderConnections)
end

local function startObservingFolders()
	disconnectFolderObservations()
end

local function hasUtilityWork()
	return (Controller.AutoCollectEnabled and Controller.GiftMagnetBlocked ~= true)
		or Controller.TripmineBarrierEnabled
		or Controller.MatrixTetrahedronEnabled
		or Controller.GraceWingsEnabled
		or Controller.AdvancedGravityCoilEnabled
		or Controller.BetterJumpPadEnabled
		or Controller.SpeedBuffsEnabled
		or Controller.HelmetEnabled
		or Controller.MiniatureHourglassEnabled
		or Controller.GrappleVirtualNinjaBelt
		or Controller.GrappleVirtualSharkTail
end

local function syncVirtualGrapplerVisuals()
	if Executor and typeof(Executor.syncVirtualGrapplerUpgradeVisuals) == "function" then
		pcall(function()
			Executor.syncVirtualGrapplerUpgradeVisuals(Controller)
		end)
	end
end

-- RenderStepped connection management
stopRenderStepped = function() end

-- Vòng lặp cập nhật styles hiển thị (Dot <-> Highlight) cực nhanh mỗi 0.15 giây
startMatchLoops = function()
	if matchLoopsActive then
		return
	end
	matchLoopsActive = true

	task.spawn(function()
		while not Controller.Destroyed and checkActiveState() do
			if not isControllerActiveOrUnclaimed(Controller) then
				safeControllerCleanUp()
				break
			end
			claimActiveController(Controller)
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

updateRunningState = function()
	if checkActiveState() then
		startMatchLoops()
	end
end

local utilityLoopActive = false

local function startUtilityLoop()
	if utilityLoopActive then
		return
	end
	utilityLoopActive = true
	task.spawn(function()
		while not Controller.Destroyed do
			if not isControllerActiveOrUnclaimed(Controller) then
				safeControllerCleanUp()
				break
			end
			claimActiveController(Controller)
			if not hasUtilityWork() then
				break
			end
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and not Controller.inLobby then
				if Controller.AutoCollectEnabled and Controller.GiftMagnetBlocked ~= true then
					pcall(function()
						Executor.updateMagnet(Controller, hrp)
					end)
				end
				if Controller.TripmineBarrierEnabled then
					pcall(function()
						Executor.updateBarriers(Controller, GC)
					end)
				end

				-- Tự động kích hoạt lại Matrix Tetrahedron nếu được bật nhưng chưa hook (phòng hờ load trễ/lobby)
				if Controller.MatrixTetrahedronEnabled and MatrixTetrahedron and not MatrixTetrahedron.Hooked then
					pcall(function()
						local reduction = Controller.MomentumReduction or 1.0
						MatrixTetrahedron.setReduction(reduction)
						MatrixTetrahedron.start(Controller, GC)
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
				if Controller.HelmetEnabled and Helmet and not Helmet.Hooked then
					pcall(function()
						Helmet.start(Controller, GC)
					end)
				end
				if Controller.MiniatureHourglassEnabled and MiniatureHourglass and not MiniatureHourglass.Hooked then
					pcall(function()
						MiniatureHourglass.start(Controller, GC)
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
		Controller:ReapplyRespawnFeatures()
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
	Logic.syncSimulatedUpgradeHud(self)
end

function Controller:SetRadarFeatures(value)
	if typeof(value) == "table" then
		self.RadarFeatures = value
	else
		self.RadarFeatures = {}
	end
	Logic.syncSimulatedUpgradeHud(self)
end

function Controller:SetAutoCollectEnabled(value)
	if self.GiftMagnetBlocked == true then
		self.AutoCollectEnabled = false
		local globals = getgenv()
		local suppressBootNotice = globals._NULLSCAPE_Booting == true
		if value == true and not suppressBootNotice and globals.Rayfield and typeof(globals.Rayfield.Notify) == "function" then
			pcall(function()
				globals.Rayfield:Notify({
					Title = "Gift Magnet Disabled",
					Content = "Gift Magnet is isolated from Gift Farm and will not run.",
					Duration = 3,
				})
			end)
		end
		return false
	end

	self.AutoCollectEnabled = value == true
	if self.AutoCollectEnabled then
		startUtilityLoop()
	end
	return true
end

-- Bật/tắt mô phỏng nâng cấp Matrix Tetrahedron
function Controller:SetMatrixTetrahedron(value)
	self.MatrixTetrahedronEnabled = value == true
	if MatrixTetrahedron then
		if self.MatrixTetrahedronEnabled then
			local reduction = self.MomentumReduction or 1.0
			MatrixTetrahedron.setReduction(reduction)
			MatrixTetrahedron.start(self, GC)
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
		if self.MatrixTetrahedronEnabled then
			MatrixTetrahedron.start(self, GC)
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
	local minJumpPower = AdvancedGravityCoil
			and AdvancedGravityCoil.getMinJumpPower
			and AdvancedGravityCoil.getMinJumpPower()
		or 28
	local maxJumpPower = AdvancedGravityCoil
			and AdvancedGravityCoil.getMaxJumpPower
			and AdvancedGravityCoil.getMaxJumpPower()
		or 100
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
	local minJumpPadPower = BetterJumpPad and BetterJumpPad.getMinJumpPadPower and BetterJumpPad.getMinJumpPadPower()
		or 100
	local maxJumpPadPower = BetterJumpPad and BetterJumpPad.getMaxJumpPadPower and BetterJumpPad.getMaxJumpPadPower()
		or 200
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

function Controller:SetHelmet(value)
	self.HelmetEnabled = value == true
	if Helmet then
		if self.HelmetEnabled then
			Helmet.start(self, GC)
		else
			Helmet.stop()
		end
	end
	refreshUpgradeServerState()
end

function Controller:SetMiniatureHourglass(value)
	self.MiniatureHourglassEnabled = value == true
	if MiniatureHourglass then
		if self.MiniatureHourglassEnabled then
			MiniatureHourglass.start(self, GC)
		else
			MiniatureHourglass.stop()
		end
	end
	refreshUpgradeServerState()
end

function Controller:SetGrappleVirtualNinjaBelt(value)
	self.GrappleVirtualNinjaBelt = value == true
	syncVirtualGrapplerVisuals()
	startUtilityLoop()
end

function Controller:SetGrappleVirtualSharkTail(value)
	self.GrappleVirtualSharkTail = value == true
	syncVirtualGrapplerVisuals()
	startUtilityLoop()
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
						Content = "Too far from Beacon! (Distance: "
							.. string.format("%.1f", distToBeacon)
							.. " studs, limit: 30)",
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
			local oldCFrame = hrp.CFrame
			local ok, err = pcall(function()

				-- Safe blink pick: Anchors root and teleports right on top of the Medal handle for 0.05s
				hrp.Anchored = true
				hrp.CFrame = medal.CFrame * CFrame.new(0, 1.5, 0)
				task.wait(0.05)

				if getgenv().Rayfield then
					getgenv().Rayfield:Notify({
						Title = "Medal Action",
						Content = "Attempted Medal pick up!",
						Duration = 2,
					})
				end
			end)
			pcall(function()
				if hrp and hrp.Parent then
					hrp.CFrame = oldCFrame
					hrp.Anchored = false
				end
			end)
			if not ok then
				warn("[NULLSCAPE] Medal action failed: " .. tostring(err))
			end
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
local function normalizeTripmineBarrierMode(value)
	if value == "I-Frames" or value == "Immunity" then
		return value
	end

	return "Off"
end

function Controller:SetTripmineBarrier(value)
	self.TripmineBarrierEnabled = value
	if value == true and (self.TripmineBarrierMode == nil or self.TripmineBarrierMode == "Off") then
		self.TripmineBarrierMode = "I-Frames"
	elseif value ~= true then
		self.TripmineBarrierMode = "Off"
	end
	pcall(function()
		Executor.updateBarriers(self, GC)
	end)
	startUtilityLoop()
end

function Controller:SetTripmineBarrierCollectDelay(value)
	self.TripmineBarrierCollectDelay = math.clamp(tonumber(value) or 0.08, 0.03, 1)
	pcall(function()
		Executor.updateBarriers(self, GC)
	end)
end

function Controller:SetTripmineBarrierMode(value)
	local mode = normalizeTripmineBarrierMode(value)
	self.TripmineBarrierMode = mode
	self.TripmineBarrierEnabled = mode ~= "Off"
	pcall(function()
		Executor.updateBarriers(self, GC)
	end)
	startUtilityLoop()
end

-- Thiết lập khoảng cách kích nổ mìn cơ sở
function Controller:SetTripmineDetonationDistance(value)
	self.TripmineDetonationDistance = value or 15
end

-- Thiết lập biên độ dao động khoảng cách kích nổ ngẫu nhiên
function Controller:SetTripmineDetonationJitter(value)
	self.TripmineDetonationJitter = value or 2
end

local function getClassAdjustmentController()
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and typeof(globals.activeClassAdjustmentController) == "table" then
		return globals.activeClassAdjustmentController
	end

	local success, control = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	end)

	return success and control or nil
end

function Controller:SetChargerTripmineAssist(value)
	local control = getClassAdjustmentController()
	if control and typeof(control.SetChargerTripmineAssist) == "function" then
		return control:SetChargerTripmineAssist(value)
	end
end

function Controller:SetChargerTripmineMode(value)
	local control = getClassAdjustmentController()
	if control and typeof(control.SetChargerTripmineMode) == "function" then
		return control:SetChargerTripmineMode(value)
	end
end

function Controller:SetChargerTripmineDistance(value)
	local control = getClassAdjustmentController()
	if control and typeof(control.SetChargerTripmineDistance) == "function" then
		return control:SetChargerTripmineDistance(value)
	end
end

function Controller:SetChargerTripmineJitter(value)
	local control = getClassAdjustmentController()
	if control and typeof(control.SetChargerTripmineJitter) == "function" then
		return control:SetChargerTripmineJitter(value)
	end
end

function Controller:SetTripmineBlastSafeRadius(value)
	self.TripmineBlastSafeRadius = value or 8
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
	startUtilityLoop()
	if not self.inLobby then
		if self.TripmineBarrierEnabled then
			pcall(function()
				Executor.updateBarriers(self, GC)
			end)
		end
		if self.MatrixTetrahedronEnabled and MatrixTetrahedron then
			pcall(function()
				MatrixTetrahedron.setReduction(self.MomentumReduction or 1.0)
				MatrixTetrahedron.start(self, GC)
			end)
		end
		if self.GraceWingsEnabled and GraceWings then
			pcall(function()
				GraceWings.setMultiplier(self.GraceWingsAirControlMultiplier or 1.1)
				GraceWings.start(self, GC)
			end)
		end
		if self.AdvancedGravityCoilEnabled and AdvancedGravityCoil then
			pcall(function()
				AdvancedGravityCoil.setJumpPower(self.AdvancedGravityCoilJumpPower or 28)
				AdvancedGravityCoil.start(self, GC)
			end)
		end
		if self.BetterJumpPadEnabled and BetterJumpPad then
			pcall(function()
				BetterJumpPad.setJumpPadPower(self.BetterJumpPadPower or 100)
				BetterJumpPad.start(self, GC)
			end)
		end
		if self.SpeedBuffsEnabled and SpeedBuffs then
			pcall(function()
				SpeedBuffs.setSelectedBuffs(self.SpeedBuffSelections or {})
				SpeedBuffs.start(self, GC)
			end)
		end
		if self.HelmetEnabled and Helmet then
			pcall(function()
				Helmet.start(self, GC)
			end)
		end
		if self.MiniatureHourglassEnabled and MiniatureHourglass then
			pcall(function()
				MiniatureHourglass.start(self, GC)
			end)
		end
	end
end

local function restoreHooks()
	local globals = getgenv()._NULLSCAPE_Globals
	if not globals then
		return
	end

	-- Restore GiftClientHandler hooks
	pcall(function()
		local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local GiftClientHandlerModule = PlayerScripts and PlayerScripts:FindFirstChild("GiftClientHandler")
		if GiftClientHandlerModule then
			local success, GiftClientHandler = pcall(require, GiftClientHandlerModule)
			if success and typeof(GiftClientHandler) == "table" then
				if globals.GiftClientNewHooked and globals.OriginalGiftClientNew then
					GiftClientHandler.new = globals.OriginalGiftClientNew
					globals.GiftClientNewHooked = nil
					globals.OriginalGiftClientNew = nil
				end
				if globals.GiftClientDestroyHooked and globals.OriginalGiftClientDestroy then
					GiftClientHandler.DestroyGift = globals.OriginalGiftClientDestroy
					globals.GiftClientDestroyHooked = nil
					globals.OriginalGiftClientDestroy = nil
				end
			end
		end
	end)

	-- Restore UpgradeHandler hooks
	pcall(function()
		local ClientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		local UpgradeHandlerModule = ClientModules and ClientModules:FindFirstChild("UpgradeHandler")
		if UpgradeHandlerModule then
			local success, UpgradeHandler = pcall(require, UpgradeHandlerModule)
			if success and typeof(UpgradeHandler) == "table" then
				if globals.IsUpgradeEnabledHooked and globals.OriginalIsUpgradeEnabled then
					if typeof(hookfunction) == "function" then
						pcall(hookfunction, UpgradeHandler.IsUpgradeEnabled, globals.OriginalIsUpgradeEnabled)
					else
						UpgradeHandler.IsUpgradeEnabled = globals.OriginalIsUpgradeEnabled
					end
					globals.IsUpgradeEnabledHooked = nil
					globals.OriginalIsUpgradeEnabled = nil
				end
				if globals.GetUpgradeStackHooked and globals.OriginalGetUpgradeStack then
					if typeof(hookfunction) == "function" then
						pcall(hookfunction, UpgradeHandler.GetUpgradeStack, globals.OriginalGetUpgradeStack)
					else
						UpgradeHandler.GetUpgradeStack = globals.OriginalGetUpgradeStack
					end
					globals.GetUpgradeStackHooked = nil
					globals.OriginalGetUpgradeStack = nil
				end
				if globals.GetUpgradeChangedSignalHooked and globals.OriginalGetUpgradeChangedSignal then
					if typeof(hookfunction) == "function" then
						pcall(
							hookfunction,
							UpgradeHandler.GetUpgradeChangedSignal,
							globals.OriginalGetUpgradeChangedSignal
						)
					else
						UpgradeHandler.GetUpgradeChangedSignal = globals.OriginalGetUpgradeChangedSignal
					end
					globals.GetUpgradeChangedSignalHooked = nil
					globals.OriginalGetUpgradeChangedSignal = nil
				end
			end
		end
	end)
end

-- Hàm dọn dẹp tài nguyên (GC) khi tắt hoặc hủy UI
function Controller:CleanUp()
	local globals = getGlobals()
	local finalCleanup = self.Destroyed
		or (globals.activeUpgradeController ~= nil and globals.activeUpgradeController ~= self)
	disconnectFolderObservations()
	stopRenderStepped()

	if finalCleanup then
		self.GraceWingsEnabled = false
		self.AdvancedGravityCoilEnabled = false
		self.BetterJumpPadEnabled = false
		self.SpeedBuffsEnabled = false
		self.HelmetEnabled = false
		self.MiniatureHourglassEnabled = false
		self.GrappleVirtualNinjaBelt = false
		self.GrappleVirtualSharkTail = false
		if Executor and typeof(Executor.clearVirtualGrapplerUpgradeVisuals) == "function" then
			pcall(Executor.clearVirtualGrapplerUpgradeVisuals)
		end
	end

	if finalCleanup and MatrixTetrahedron then
		pcall(function()
			MatrixTetrahedron.stop()
		end)
	end
	if finalCleanup and GraceWings then
		pcall(function()
			GraceWings.stop()
		end)
	end
	if finalCleanup and AdvancedGravityCoil then
		pcall(function()
			AdvancedGravityCoil.stop()
		end)
	end
	if finalCleanup and BetterJumpPad then
		pcall(function()
			BetterJumpPad.stop()
		end)
	end
	if finalCleanup and SpeedBuffs then
		pcall(function()
			SpeedBuffs.stop()
		end)
	end
	if finalCleanup and Helmet then
		pcall(function()
			Helmet.stop()
		end)
	end
	if finalCleanup and MiniatureHourglass then
		pcall(function()
			MiniatureHourglass.stop()
		end)
	end
	if finalCleanup then
		refreshUpgradeServerState()
	end

	if finalCleanup and self.PermanentConnections then
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

	if finalCleanup then
		pcall(restoreHooks)
		if Executor and typeof(Executor.restoreUpgradeSimulationHook) == "function" then
			pcall(Executor.restoreUpgradeSimulationHook)
		end
	end

	-- Giải phóng biến môi trường để hỗ trợ dọn dẹp bộ nhớ (GC)
	if self.Destroyed and globals and globals.activeUpgradeController == self then
		globals.activeUpgradeController = nil
	end
end

getgenv()._NULLSCAPE_Globals.onGiftCreated = function(_giftObj) end
getgenv()._NULLSCAPE_Globals.onGiftDestroyed = function(_id) end

getgenv()._NULLSCAPE_Globals.isUpgradeEnabledCheck = function(...)
	local args = { ... }
	local isTetrahedron = false
	local isGraceWings = false
	local isAdvancedGravityCoil = false
	local isBetterJumpPad = false
	local isHelmet = false
	local isMiniatureHourglass = false
	for _, v in ipairs(args) do
		if v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
			isTetrahedron = true
		elseif v == "GraceWings" or v == "Grace Wings" then
			isGraceWings = true
		elseif v == "AdvancedGravityCoil" or v == "Advanced Gravity Coil" then
			isAdvancedGravityCoil = true
		elseif v == "BetterJumpPad" or v == "Better Jump Pad" then
			isBetterJumpPad = true
		elseif v == "Helmet" then
			isHelmet = true
		elseif v == "MiniatureHourglass" or v == "Miniature Hourglass" then
			isMiniatureHourglass = true
		elseif v == "NinjaBelt" or v == "Ninja Belt" then
			if Controller.GrappleVirtualNinjaBelt then
				return true, true
			end
		elseif v == "SharkTail" or v == "Shark Tail" or v == "SharkBelt" or v == "Shark Belt" then
			if Controller.GrappleVirtualSharkTail then
				return true, true
			end
		else
			local shouldSpoof, result = Logic.shouldSpoofUpgradeEnabled(Controller, v)
			if shouldSpoof then
				return true, result
			end
		end
	end
	if isTetrahedron and Controller.MatrixTetrahedronEnabled then
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
	if isHelmet and Controller.HelmetEnabled then
		return true, true
	end
	if isMiniatureHourglass and Controller.MiniatureHourglassEnabled then
		return true, true
	end
	return false
end

getgenv()._NULLSCAPE_Globals.getUpgradeStackCheck = function(...)
	local args = { ... }
	local isTetrahedron = false
	local isGraceWings = false
	local isAdvancedGravityCoil = false
	local isBetterJumpPad = false
	local isHelmet = false
	local isMiniatureHourglass = false
	for _, v in ipairs(args) do
		if v == "MatrixTetrahedron" or v == "Matrix Tetrahedron" then
			isTetrahedron = true
		elseif v == "GraceWings" or v == "Grace Wings" then
			isGraceWings = true
		elseif v == "AdvancedGravityCoil" or v == "Advanced Gravity Coil" then
			isAdvancedGravityCoil = true
		elseif v == "BetterJumpPad" or v == "Better Jump Pad" then
			isBetterJumpPad = true
		elseif v == "Helmet" then
			isHelmet = true
		elseif v == "MiniatureHourglass" or v == "Miniature Hourglass" then
			isMiniatureHourglass = true
		elseif v == "NinjaBelt" or v == "Ninja Belt" then
			if Controller.GrappleVirtualNinjaBelt then
				return true, 1
			end
		elseif v == "SharkTail" or v == "Shark Tail" or v == "SharkBelt" or v == "Shark Belt" then
			if Controller.GrappleVirtualSharkTail then
				return true, 1
			end
		else
			local shouldSpoof, stack = Logic.shouldSpoofUpgradeStack(Controller, v)
			if shouldSpoof then
				return true, stack
			end
		end
	end
	if isTetrahedron and Controller.MatrixTetrahedronEnabled then
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
	if isHelmet and Controller.HelmetEnabled then
		return true, 1
	end
	if isMiniatureHourglass and Controller.MiniatureHourglassEnabled then
		return true, 1
	end
	return false
end

-- Đăng ký active controller hiện tại để tự động dừng các phiên bản cũ
if Executor and typeof(Executor.enableUpgradeSimulationHook) == "function" then
	pcall(Executor.enableUpgradeSimulationHook)
end

getGlobals().activeUpgradeController = Controller

-- Khởi tạo ban đầu khi nạp script
Logic.syncSimulatedUpgradeHud(Controller)
Logic.bindUpgradeWatcher(Controller, function()
	if triggerInstantUpdate then
		triggerInstantUpdate()
	end
end)
startObservingFolders()
updateRunningState()
startUtilityLoop()
syncVirtualGrapplerVisuals()

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
			safeControllerCleanUp()
			return
		end
		claimActiveController(Controller)
		Controller:ReapplyRespawnFeatures()
	end

	task.defer(refreshLater)
	task.delay(0.5, refreshLater)
	task.delay(1.5, refreshLater)
end

local characterRefreshConnection = LocalPlayer.CharacterAdded:Connect(function()
	scheduleRespawnFeatureRefresh()
end)
table.insert(Controller.PermanentConnections, characterRefreshConnection)

-- Lắng nghe và xử lý phần đầu cho các thực thể 3D như Springer (thêm proxy "head" để nhận ESP)
local function handleEnemyAdded(enemy)
	if not enemy or not enemy:IsA("Model") then
		return
	end
	if enemy.Name == "Springer" or enemy.Name == "BigSpringer" then
		task.spawn(function()
			if enemy:FindFirstChild("head") then
				return
			end
			local Head = enemy:WaitForChild("Head", 5)
			if Head and Head:IsA("BasePart") and not enemy:FindFirstChild("head") then
				local proxyHead = Instance.new("Part")
				proxyHead.Name = "head"
				proxyHead.Size = Head.Size
				proxyHead.Transparency = 1
				proxyHead.CanCollide = false
				proxyHead.Massless = true

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = Head
				weld.Part1 = proxyHead
				weld.Parent = proxyHead

				proxyHead.CFrame = Head.CFrame
				proxyHead.Parent = enemy

				-- Sửa lỗi hiển thị ESP cho thực thể 3D: hướng Adornee trực tiếp vào Head và đặt AlwaysOnTop = true
				local espConn
				espConn = enemy.ChildAdded:Connect(function(child)
					if child.Name == "ESP" or child.Name == "ESPCrayon" then
						pcall(function()
							child.Adornee = Head
							child.AlwaysOnTop = true
						end)
					end
				end)
				table.insert(Controller.PermanentConnections, espConn)

				-- Sửa ngay nếu ESP đã được sinh ra trước khi kết nối sự kiện
				for _, child in ipairs(enemy:GetChildren()) do
					if child.Name == "ESP" or child.Name == "ESPCrayon" then
						pcall(function()
							child.Adornee = Head
							child.AlwaysOnTop = true
						end)
					end
				end
			end
		end)
	end
end

local enemiesFolder = workspace:WaitForChild("Enemies", 15)
if enemiesFolder then
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		pcall(handleEnemyAdded, enemy)
	end

	local enemyAddedConn = enemiesFolder.ChildAdded:Connect(function(enemy)
		pcall(handleEnemyAdded, enemy)
	end)
	table.insert(Controller.PermanentConnections, enemyAddedConn)
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
	local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
	if Controller.Destroyed or not Controller.PermanentConnections then
		return
	end
	if inRoundVal and inRoundVal:IsA("BoolValue") then
		hasInRoundValue = true
		if not isControllerActiveOrUnclaimed(Controller) then
			pcall(safeControllerCleanUp)
			return
		end
		claimActiveController(Controller)
		setInLobby(not inRoundVal.Value)

		local conn
		conn = inRoundVal.Changed:Connect(function(val)
			if Controller.Destroyed or typeof(Controller) ~= "table" or not Controller.CleanUp then
				if conn then
					pcall(function()
						conn:Disconnect()
					end)
				end
				return
			end
			if not isControllerActiveOrUnclaimed(Controller) then
				pcall(safeControllerCleanUp)
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

-- Vòng lặp quan sát dự phòng (chỉ chạy khi không có InRound)
task.spawn(function()
	while not Controller.Destroyed and not hasInRoundValue do
		task.wait(3.0)
		if Controller.Destroyed or hasInRoundValue or typeof(Controller) ~= "table" or not Controller.CleanUp then
			break
		end
		if not isControllerActiveOrUnclaimed(Controller) then
			pcall(safeControllerCleanUp)
			break
		end
		claimActiveController(Controller)
		setInLobby(not isInMatch())
	end
end)

local function hookUpgradeHandler()
	getgenv()._NULLSCAPE_Globals.customUpgradeEvents = getgenv()._NULLSCAPE_Globals.customUpgradeEvents or {}
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

				if UpgradeHandler.GetUpgradeChangedSignal then
					if typeof(hookfunction) == "function" then
						if not getgenv()._NULLSCAPE_Globals.GetUpgradeChangedSignalHooked then
							local oldGetUpgradeChangedSignal
							oldGetUpgradeChangedSignal = hookfunction(
								UpgradeHandler.GetUpgradeChangedSignal,
								function(upgradeName)
									local originalEvent = oldGetUpgradeChangedSignal(upgradeName)
									local customUpgradeEvents = getgenv()._NULLSCAPE_Globals.customUpgradeEvents
									local customEvent = customUpgradeEvents[upgradeName]
									if not customEvent then
										customEvent = Instance.new("BindableEvent")
										customUpgradeEvents[upgradeName] = customEvent
										if originalEvent then
											originalEvent:Connect(function(...)
												customEvent:Fire(...)
											end)
										end
									end
									return customEvent.Event
								end
							)
							getgenv()._NULLSCAPE_Globals.OriginalGetUpgradeChangedSignal = oldGetUpgradeChangedSignal
							getgenv()._NULLSCAPE_Globals.GetUpgradeChangedSignalHooked = true
						end
					else
						if not getgenv()._NULLSCAPE_Globals.GetUpgradeChangedSignalHooked then
							local oldGetUpgradeChangedSignal = UpgradeHandler.GetUpgradeChangedSignal
							getgenv()._NULLSCAPE_Globals.OriginalGetUpgradeChangedSignal = oldGetUpgradeChangedSignal
							UpgradeHandler.GetUpgradeChangedSignal = function(upgradeName)
								local originalEvent =
									getgenv()._NULLSCAPE_Globals.OriginalGetUpgradeChangedSignal(upgradeName)
								local customUpgradeEvents = getgenv()._NULLSCAPE_Globals.customUpgradeEvents
								local customEvent = customUpgradeEvents[upgradeName]
								if not customEvent then
									customEvent = Instance.new("BindableEvent")
									customUpgradeEvents[upgradeName] = customEvent
									if originalEvent then
										originalEvent:Connect(function(...)
											customEvent:Fire(...)
										end)
									end
								end
								return customEvent.Event
							end
							getgenv()._NULLSCAPE_Globals.GetUpgradeChangedSignalHooked = true
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
