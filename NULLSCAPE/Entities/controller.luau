-- [[
--  NULLSCAPE - Entities Controller
--  Vai trÃ²: Äáº£m nhiá»‡m viá»‡c quan sÃ¡t hiá»‡u nÄƒng, phÃ¢n tÃ­ch tÃ i nguyÃªn vÃ  Ä‘Æ°a ra cÃ¡c quyáº¿t Ä‘á»‹nh Ä‘iá»u phá»‘i:
--  - PhÃ¡t hiá»‡n tráº¡ng thÃ¡i sáº£nh chá»/tráº­n Ä‘áº¥u (khi inLobby = false sáº½ kÃ­ch hoáº¡t gá»i quÃ©t scan).
--  - GiÃ¡m sÃ¡t tráº¡ng thÃ¡i hoáº¡t Ä‘á»™ng cá»§a script, Ä‘iá»u phá»‘i cháº¿ Ä‘á»™ ngá»§ Ä‘Ã´ng (hibernating) tá»‘i Æ°u CPU.
--  - Gá»­i káº¿t ná»‘i Ä‘Äƒng kÃ½ qua GC vÃ  phÃ¡t lá»‡nh dá»n dáº¹p giáº£i phÃ³ng tÃ i nguyÃªn.
-- ]]

local getgenv = getgenv
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
	reconcile = function(gc)
		if TouchInterest and typeof(TouchInterest.reconcile) == "function" then
			TouchInterest.reconcile(gc)
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
	-- Tráº¡ng thÃ¡i báº­t/táº¯t miá»…n nhiá»…m cho tá»«ng thá»±c thá»ƒ
	BabyImmune = false,
	BellImmune = false,
	BellCurseImmune = false,
	BellBlindnessImmune = false,
	BellKnockbackImmune = false,
	BellOvertunedKillImmune = false,
	FleshImmune = false,
	FleshConcussionImmune = false,
	FleshScreenEffectImmune = false,
	MartImmune = false,
	TelefraggerImmune = false,
	ICBMImmune = false,
	ICBMBurnImmune = false,
	GuardianImmune = false,
	OperatorImmune = false,
	SpringerImmune = false,
	SpringerKnockbackImmune = false,
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
	PondererImmune = false,
	PondererSilentLookat = false,
	VoidImplosionImmune = false,
	CelestialImmune = false,
	ScrapmawImmune = false,
	CatalystImmune = false,
	nilEnemyImmune = false,
	nilMirageImmune = false,
	SeamineImmune = false,
	TelefraggerAutoDodge = false,
	TelefraggerAutoDodgeRequested = false,
	TelefraggerBackTrick = false,
	TelefraggerBackTrickMode = "180",
	TelefraggerDesyncDelay = 0.44,
	TelefraggerActiveThreads = {},
	TelefraggerActiveDesyncs = {},
	TelefraggerConnection = nil,
	WasRedirectingTelefragger = false,
	RedirectRootJoint = nil,
	RedirectOriginalC0 = nil,
	BellGongKnockbackConnection = nil,
	LastBellDebuffAt = 0,
	Destroyed = false,

	EnemiesFolder = nil,
	PermanentConnections = {},
	StartSkinwalkerEvasion = nil,
	CadenceUI = nil,
	CadenceStatusLabel = nil,
	CadenceUIFrame = nil,
}
GC.Controller = Controller

-- XÃ¡c minh kiá»ƒm tra tráº¡ng thÃ¡i game báº±ng ReplicatedStorage.InRound
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
	-- KhÃ´ng in debug theo yÃªu cáº§u cá»§a ngÆ°á»i dÃ¹ng
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

local inLobby = not isInMatch() -- Äang á»Ÿ sáº£nh chá»/lá»±a chá»n (Khá»Ÿi táº¡o ban Ä‘áº§u)
local function getStatusImmunity()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.NullscapeStatusImmunity or nil
end

Controller.inLobby = inLobby
local hasInRoundValue = false
local folderConnections = {} -- key: folder -> value: list of connections
local workspaceConnections = {} -- list of workspace-level connections
local processedEntities = setmetatable({}, { __mode = "k" })
local originalTouchStates = setmetatable({}, { __mode = "k" })
local disabledShockwaves = {}
local restoreShockwave
local isAnySpecialImmunityEnabled

local function getCharacterRoot()
	local localPlayer = Players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function restoreCharacterTouchStates()
	for part, state in pairs(originalTouchStates) do
		if part and part.Parent then
			pcall(function()
				part.CanTouch = state
			end)
		end
		originalTouchStates[part] = nil
	end
end

local function getBeaconPart()
	local beacon = workspace:FindFirstChild("Beacon")
	if not beacon then
		return nil
	end

	if beacon:IsA("BasePart") then
		return beacon
	end

	if beacon:IsA("Model") then
		return beacon.PrimaryPart or beacon:FindFirstChildWhichIsA("BasePart", true)
	end

	return beacon:FindFirstChildWhichIsA("BasePart", true)
end

local function isNearBeacon(rootPart)
	local beaconPart = getBeaconPart()
	if not (rootPart and beaconPart) then
		return false
	end

	local flatDistance = ((rootPart.Position - beaconPart.Position) * Vector3.new(1, 0, 1)).Magnitude
	return flatDistance <= 32
end

-- Ngáº¯t cÃ¡c káº¿t ná»‘i quan sÃ¡t thÆ° má»¥c vÃ  workspace
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
	globals.handleEntitiesRemoteCall = nil

	if globals.OriginalRingBell and typeof(_G.RingBell) == "function" then
		_G.RingBell = globals.OriginalRingBell
		globals.OriginalRingBell = nil
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
	self.TelefraggerAutoDodge = false
	self.TelefraggerAutoDodgeRequested = value == true
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
	self.BellCurseImmune = value == true
	Executor.reconcile(GC)
end

function Controller:SetBellBlindnessImmune(value)
	self.BellBlindnessImmune = value == true
end

function Controller:SetBellOvertunedKillImmune(value)
	self.BellOvertunedKillImmune = value == true
end

function Controller:SetFleshConcussionImmune(value)
	self.FleshConcussionImmune = value == true
	local StatusImmunity = getStatusImmunity()
	if StatusImmunity and typeof(StatusImmunity.RefreshActiveEffects) == "function" then
		StatusImmunity.RefreshActiveEffects()
	end
end

function Controller:SetFleshScreenEffectImmune(value)
	self.FleshScreenEffectImmune = value == true
end

function Controller:ReconcileImmunityState()
	Executor.reconcile(GC)

	if not self.BellImmune and not self.SpringerImmune then
		restoreCharacterTouchStates()
	end

	local springerKnockback = self.SpringerKnockbackImmune == true
	if not self.SpringerImmune and not springerKnockback then
		for part in pairs(disabledShockwaves) do
			restoreShockwave(part)
		end
	end

	if isAnySpecialImmunityEnabled() then
		Executor.enableSpecialImmunity()
	else
		Executor.disableSpecialImmunity()
	end
end

function Controller:UpdateTelefraggerConnection()
	if self.TelefraggerConnection then
		pcall(function()
			self.TelefraggerConnection:Disconnect()
		end)
		self.TelefraggerConnection = nil
	end

	-- KhÃ´i phá»¥c tráº¡ng thÃ¡i xoay khá»›p náº¿u BackTrick bá»‹ táº¯t
	if not self.TelefraggerBackTrick and self.WasRedirectingTelefragger then
		BackTrick.revert(self)
	end

	if not self.TelefraggerAutoDodge then
		return
	end

	local LocalPlayer = game.Players.LocalPlayer

	-- Helper: TÃ­nh khoáº£ng cÃ¡ch ngáº¯n nháº¥t tá»« Ä‘iá»ƒm P Ä‘áº¿n Ä‘oáº¡n tháº³ng AB
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

	-- Helper: Kiá»ƒm tra vá»‹ trÃ­ sÃ n an toÃ n Ä‘á»ƒ trÃ¡nh nÃ© xuá»‘ng vá»±c
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

		-- QuÃ©t táº¥t cáº£ cÃ¡c chá»‰ thá»‹ (Indicator) hoáº¡t Ä‘á»™ng cá»§a Telefragger á»Ÿ cá»± ly gáº§n
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
					-- Attachment vÃ  Attachment2 Ä‘Æ°á»£c sinh ra á»Ÿ client biá»ƒu diá»…n vá»‹ trÃ­ báº¯t Ä‘áº§u vÃ  káº¿t thÃºc cá»§a cÃº dash/teleport
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

		-- 2. Xá»­ lÃ½ cÆ¡ cháº¿ Auto-Dodge (NÃ© trÃ¡nh di chuyá»ƒn tá»‹nh tiáº¿n sang ngang ra khá»i Ä‘Æ°á»ng dash Ä‘á»)
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

			self.TelefraggerSuggestedDodgeDirection = slideDir
			self.TelefraggerSuggestedDodgeAt = os.clock()
		end
	end)
end

function Controller:TriggerSilentBackTrick(enemy)
	if not enemy then
		return
	end

	-- Há»§y luá»“ng chá» cÅ© cá»§a Telefragger nÃ y náº¿u cÃ³
	if self.TelefraggerActiveThreads[enemy] then
		pcall(task.cancel, self.TelefraggerActiveThreads[enemy])
		self.TelefraggerActiveThreads[enemy] = nil
	end

	self.TelefraggerActiveThreads[enemy] = task.delay(self.TelefraggerDesyncDelay or 0.44, function()
		self.TelefraggerActiveThreads[enemy] = nil

		-- ThÃªm vÃ o danh sÃ¡ch Ä‘ang desync active
		local wasEmpty = (next(self.TelefraggerActiveDesyncs) == nil)
		self.TelefraggerActiveDesyncs[enemy] = true

		if wasEmpty then
			BackTrick.trigger(self)
		end
	end)
end

function Controller:CancelSilentBackTrick(enemy)
	if not enemy then
		return
	end

	-- Há»§y luá»“ng chá» náº¿u chÆ°a kÃ­ch hoáº¡t desync
	if self.TelefraggerActiveThreads[enemy] then
		pcall(task.cancel, self.TelefraggerActiveThreads[enemy])
		self.TelefraggerActiveThreads[enemy] = nil
	end

	-- XÃ³a khá»i danh sÃ¡ch active
	if self.TelefraggerActiveDesyncs[enemy] then
		self.TelefraggerActiveDesyncs[enemy] = nil

		-- Náº¿u khÃ´ng cÃ²n thá»±c thá»ƒ nÃ o Ä‘ang desync thÃ¬ khÃ´i phá»¥c nhÃ¢n váº­t
		if next(self.TelefraggerActiveDesyncs) == nil then
			BackTrick.revert(self)
		end
	end

	Executor.reconcile(GC)
	if not self.BellImmune and not self.SpringerImmune then
		restoreCharacterTouchStates()
	end
end

-- HÃ m dá»n dáº¹p tÃ i nguyÃªn (Garbage Collection - GC) giáº£i phÃ³ng bá»™ nhá»›
function Controller:CleanUp()
	-- Há»§y táº¥t cáº£ cÃ¡c luá»“ng chá» vÃ  dá»n dáº¹p danh sÃ¡ch active
	for enemy, thread in pairs(self.TelefraggerActiveThreads) do
		pcall(task.cancel, thread)
	end
	table.clear(self.TelefraggerActiveThreads)
	table.clear(self.TelefraggerActiveDesyncs)

	pcall(function()
		BackTrick.cleanup(self)
	end)

	for part, state in pairs(originalTouchStates) do
		if part and part.Parent then
			pcall(function()
				part.CanTouch = state
			end)
		end
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
	if self.BellGongKnockbackConnection then
		pcall(function()
			self.BellGongKnockbackConnection:Disconnect()
		end)
		self.BellGongKnockbackConnection = nil
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

	-- Náº¿u bá»‹ há»§y hoÃ n toÃ n (Destroyed = true), giáº£i phÃ³ng cÃ¡c káº¿t ná»‘i vÄ©nh viá»…n
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

function isAnySpecialImmunityEnabled()
	for _, flag in pairs(SPECIAL_IMMUNITY_FLAGS) do
		if Controller[flag] == true then
			return true
		end
	end
	return false
end

function restoreShockwave(part)
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

-- Thiáº¿t láº­p cáº¥u hÃ¬nh miá»…n nhiá»…m vÃ  kÃ­ch hoáº¡t dá»n dáº¹p tá»©c thá»i
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

		-- ThÃ´ng bÃ¡o cho Accessibility controller cáº­p nháº­t láº¡i tráº¡ng thÃ¡i Auto Jump
		local accessibilityController = getAccessibilityController()
		if accessibilityController and accessibilityController.updateSpringerAutoJumpState then
			pcall(function()
				accessibilityController:updateSpringerAutoJumpState()
			end)
		end
	elseif entityName == "Cadence" then
		self.CadenceImmune = value
	elseif entityName == "Ponderer" then
		self.PondererImmune = value
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

	-- Ãp dá»¥ng thay Ä‘á»•i tá»©c thá»i cho thá»±c thá»ƒ Ä‘Ã£ tá»“n táº¡i trong workspace
	if value then
		local function applyImmunityToChild(child)
			if not (child:IsA("Model") or child:IsA("BasePart")) then
				return
			end

			-- Husk / Skinwalker dÃ¹ng module HuskEvasion má»›i
			if entityName == "Skinwalker" then
				local isHusk = (string.find(child.Name, "Skinwalker") or string.find(child.Name, "Husk"))
					and child.Name ~= "Skinwalkers"
				if isHusk then
					HuskEvasion.enableHuskImmunity(GC, child)
				end
				return
			end

			-- Baby / Bell / Mart dÃ¹ng module TouchInterest Types
			local isTarget = string.find(string.lower(child.Name), string.lower(entityName))
			debugPrint("applyImmunityToChild check for target:", child.Name, "| isTarget:", isTarget ~= nil)
			if isTarget then
				Executor.enableImmunity(GC, child)
			end

			if entityName == "Springer" and string.find(child.Name, "Springer") and self.SpringerKnockbackImmune then
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
			or entityName == "Ponderer"
			or entityName == "Catalyst"
			or entityName == "nilEnemy"
			or entityName == "nilMirage"
		then
			Executor.disableImmunityForType(GC, entityName)
		elseif entityName == "Skinwalker" then
			HuskEvasion.disableHuskImmunity(GC)
		end
		if entityName == "Springer" then
			if not self.SpringerKnockbackImmune then
				for part in pairs(disabledShockwaves) do
					restoreShockwave(part)
				end
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

	Executor.reconcile(GC)
	if not self.BellImmune and not self.SpringerImmune then
		restoreCharacterTouchStates()
	end
end

-- Cáº¥u hÃ¬nh Silent Lookat cá»§a Ponderer
function Controller:SetPondererSilentLookat(enabled)
	self.PondererSilentLookat = enabled == true
end

-- Cáº¥u hÃ¬nh miá»…n nhiá»…m knockback cá»§a Springer
function Controller:SetSpringerKnockbackImmune(enabled)
	self.SpringerKnockbackImmune = enabled == true
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
		for part in pairs(disabledShockwaves) do
			restoreShockwave(part)
		end
	end
	Executor.reconcile(GC)
end

local function getNearestBellPosition(controller, rootPart)
	if not (controller and controller.EnemiesFolder and rootPart) then
		return nil
	end

	local nearestPosition = nil
	local nearestDistance = math.huge
	for _, enemy in ipairs(controller.EnemiesFolder:GetChildren()) do
		if string.find(enemy.Name, "Bell") then
			local bellPart = enemy:IsA("BasePart") and enemy or enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart", true)
			if bellPart then
				local distance = (rootPart.Position - bellPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestPosition = bellPart.Position
				end
			end
		end
	end

	if nearestDistance <= 60 then
		return nearestPosition
	end
	return nil
end

local function stopBellGongKnockbackGuard(controller)
	if controller.BellGongKnockbackConnection then
		pcall(function()
			controller.BellGongKnockbackConnection:Disconnect()
		end)
		controller.BellGongKnockbackConnection = nil
	end
end

local function startBellGongKnockbackGuard(controller)
	controller.BellKnockbackGuardRequested = true
end

function Controller:SetBellKnockbackImmune(enabled)
	self.BellKnockbackImmune = enabled == true
	if enabled then
		if self.EnemiesFolder then
			for _, enemy in ipairs(self.EnemiesFolder:GetChildren()) do
				if string.find(enemy.Name, "Bell") then
					TouchInterest.enableImmunity(GC, enemy)
				end
			end
		end
		startBellGongKnockbackGuard(self)
	else
		stopBellGongKnockbackGuard(self)
		if not self.BellImmune then
			TouchInterest.disableImmunityForType(GC, "Bell")
		end
	end
	Executor.reconcile(GC)
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

-- Tá»‘i Æ°u hÃ³a xá»­ lÃ½ tá»«ng thá»±c thá»ƒ (Sá»­ dá»¥ng Event thay vÃ¬ Loop)
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

-- Tá»‘i Æ°u hÃ³a xá»­ lÃ½ tá»«ng thá»±c thá»ƒ (Sá»­ dá»¥ng Event thay vÃ¬ Loop)
local function processEntity(enemy)
	if not enemy or not (enemy:IsA("Model") or enemy:IsA("BasePart")) or enemy.Name == "Skinwalkers" then
		return
	end
	if processedEntities[enemy] or (GC.EntityConnections and GC.EntityConnections[enemy]) then
		return
	end
	processedEntities[enemy] = true

	if enemy:IsA("Model") then
		-- Tá»± Ä‘á»™ng Ä‘á»•i Adornee cá»§a ESP / ESPCrayon sang PrimaryPart Ä‘á»ƒ trÃ¡nh lá»—i hiá»ƒn thá»‹ khi Adornee lÃ  Model khÃ´ng cÃ³ PrimaryPart tá»« server
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
			-- TÃ¬m kiáº¿m Ä‘á»‡ quy pháº§n Ä‘áº§u hoáº·c pháº§n thÃ¢n kháº£ dá»¥ng cá»§a quÃ¡i váº­t 3D má»™t cÃ¡ch khÃ´ng Ä‘á»“ng bá»™
			local actualHead
			for _ = 1, 30 do -- Thá»­ tá»‘i Ä‘a 30 láº§n (30 * 0.05s = 1.5s) Ä‘á»ƒ khá»›p vá»›i nhá»‹p táº£i pháº§n tá»­ cá»§a game
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
				task.wait(0.05) -- Chá» má»™t nhá»‹p cá»±c ngáº¯n trÆ°á»›c khi kiá»ƒm tra láº¡i
			end

			if not enemy or not enemy.Parent then
				return
			end

			-- GÃ¡n PrimaryPart náº¿u model thiáº¿u (Cá»±c ká»³ quan trá»ng Ä‘á»ƒ BillboardGui ESP cá»§a game gá»‘c hiá»ƒn thá»‹)
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

			-- Táº¡o pháº§n Ä‘áº§u giáº£ láº­p "head" (chá»¯ thÆ°á»ng) dáº¡ng BillboardGui cho thá»±c thá»ƒ 3D Ä‘á»ƒ khá»›p kiá»ƒu dá»¯ liá»‡u UDim2.Size cá»§a game gá»‘c
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

			-- Chá» má»™t chÃºt Ä‘á»ƒ xem há»‡ thá»‘ng gá»‘c cá»§a game cÃ³ tá»± Ä‘á»™ng gáº¯n ESP hay khÃ´ng
			task.wait(0.2)
			if enemy.Parent and not (enemy:FindFirstChild("ESP") or enemy:FindFirstChild("ESPCrayon")) then
				-- Náº¿u script gá»‘c cá»§a game bá» lá»¡ hoáº·c khÃ´ng ká»‹p gáº¯n, chÃºng ta tá»± gáº¯n thá»§ cÃ´ng báº±ng template gá»‘c
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

	-- HÃ m xá»­ lÃ½ chÃ­nh khi kiá»ƒm tra tÃªn thá»±c thá»ƒ
	local function checkAndApply()
		if not enemy or not enemy.Parent then
			return
		end
		local name = enemy.Name
		debugPrint("processEntity checkAndApply for:", name)

		-- â”€â”€ Thá»±c thá»ƒ dÃ¹ng nguyÃªn lÃ½ XÃ³a TouchInterest (Baby, Bell, Mart,...) â”€â”€
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

		-- â”€â”€ Husk / Skinwalker (Ä‘á»•i tÃªn + CanTouch) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
		if
			HuskEvasion.isHuskEntity(name)
			or (enemy:GetAttribute("OriginalName") and HuskEvasion.isHuskEntity(enemy:GetAttribute("OriginalName")))
		then
			if Controller.SkinwalkerImmune then
				HuskEvasion.enableHuskImmunity(GC, enemy)
			end
		end

		-- â”€â”€ Cadence Status UI Hook â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
							Controller.CadenceStatusLabel.Text = "âš ï¸ CHASE ACTIVE âš ï¸"
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

		-- â”€â”€ Telefragger ClientEvent Hook â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

	-- ÄÄƒng kÃ½ sá»± kiá»‡n láº¯ng nghe Ä‘á»•i tÃªn cá»§a thá»±c thá»ƒ (PhÃ²ng há» game Ä‘á»•i tÃªn trá»… sau khi spawn)
	local nameConn = enemy:GetPropertyChangedSignal("Name"):Connect(checkAndApply)
	GC.registerEntityConnection(enemy, nameConn)

	-- Cháº¡y kiá»ƒm tra ngay láº­p tá»©c
	checkAndApply()

	-- Láº¯ng nghe bá»™ pháº­n má»›i Ä‘Æ°á»£c thÃªm vÃ o cho Husk/Skinwalker
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

	-- Xá»­ lÃ½ vÃ´ hiá»‡u hÃ³a shockwave cho Springer (Springer khÃ´ng cÃ³ TouchInterest, chá»‰ cÃ³ ClientEvent vÃ  ShockwaveEvent)
	if string.find(enemy.Name, "Springer") then
		local childAddedConn = enemy.ChildAdded:Connect(function(child)
			if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
				if Controller.SpringerKnockbackImmune == true then
					disableShockwave(enemy, child)
				end
			end
		end)
		GC.registerEntityConnection(enemy, childAddedConn)

		for _, child in ipairs(enemy:GetChildren()) do
			if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
				if Controller.SpringerKnockbackImmune == true then
					disableShockwave(enemy, child)
				end
			end
		end
	end
end

-- Gá»¡ bá» láº¯ng nghe cá»§a thá»±c thá»ƒ khi nÃ³ bá»‹ xÃ³a
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

-- HÃ m dá»n dáº¹p tÃ i nguyÃªn riÃªng cho má»™t thÆ° má»¥c cá»¥ thá»ƒ khi nÃ³ bá»‹ xÃ³a khá»i Workspace
function Controller:CleanUpFolder(folder)
	if not folder then
		return
	end

	-- 1. Dá»n dáº¹p cÃ¡c thá»±c thá»ƒ Ä‘ang tá»“n táº¡i trong thÆ° má»¥c nÃ y
	for _, child in ipairs(folder:GetChildren()) do
		removeEntity(child)
	end

	-- 2. Ngáº¯t káº¿t ná»‘i cá»§a riÃªng thÆ° má»¥c nÃ y
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

	-- 3. Cáº­p nháº­t biáº¿n tham chiáº¿u EnemiesFolder náº¿u cáº§n
	if self.EnemiesFolder == folder then
		self.EnemiesFolder = nil
	end
end

-- Thiáº¿t láº­p quan sÃ¡t thÆ° má»¥c Enemies trong Workspace
function Controller:ObserveFolder(folder)
	debugPrint("ObserveFolder called for:", folder:GetFullName())
	-- TrÃ¡nh Ä‘Äƒng kÃ½ nhiá»u láº§n cho cÃ¹ng má»™t thÆ° má»¥c
	if folderConnections[folder] then
		debugPrint("Folder already observed, skipping:", folder.Name)
		return
	end

	if folder.Name == "Enemies" then
		self.EnemiesFolder = folder
	end

	local conns = {}

	-- 1. Láº¯ng nghe khi thá»±c thá»ƒ má»›i xuáº¥t hiá»‡n
	local childAddedConn = folder.ChildAdded:Connect(function(child)
		debugPrint("ObserveFolder: ChildAdded in:", folder.Name, "| Child Name:", child.Name)
		processEntity(child)
	end)
	table.insert(conns, childAddedConn)

	-- 2. Láº¯ng nghe khi thá»±c thá»ƒ bá»‹ xÃ³a khá»i game
	local childRemovedConn = folder.ChildRemoved:Connect(function(child)
		removeEntity(child)
	end)
	table.insert(conns, childRemovedConn)

	-- 3. Xá»­ lÃ½ cÃ¡c thá»±c thá»ƒ Ä‘Ã£ cÃ³ sáºµn trong thÆ° má»¥c
	debugPrint("ObserveFolder: Existing children in:", folder.Name, "| count:", #folder:GetChildren())
	for _, child in ipairs(folder:GetChildren()) do
		debugPrint("ObserveFolder: Processing existing child:", child.Name)
		processEntity(child)
	end

	-- 4. CÆ¡ cháº¿ tá»± Ä‘á»™ng GC khi thÆ° má»¥c bá»‹ xÃ³a/há»§y khá»i Workspace
	local destroyingConn = folder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			-- ThÆ° má»¥c Ä‘Ã£ bá»‹ xÃ³a hoÃ n toÃ n khá»i trÃ² chÆ¡i
			self:CleanUpFolder(folder)
		end
	end)
	table.insert(conns, destroyingConn)

	folderConnections[folder] = conns
end

function Controller:UpdateTouchImmunityState()
	restoreCharacterTouchStates()
end

-- QuÃ©t tÃ¬m thÆ° má»¥c Enemies vÃ  Skinwalkers trong Workspace vÃ  láº¯ng nghe sá»± thay Ä‘á»•i
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

	-- Xá»­ lÃ½ cÃ¡c folder cÃ³ sáºµn
	for _, child in ipairs(workspace:GetChildren()) do
		if (child.Name == "Enemies" or child.Name == "Skinwalkers") and child:IsA("Folder") then
			Controller:ObserveFolder(child)
		end
	end
end

-- HÃ m cáº­p nháº­t tráº¡ng thÃ¡i sáº£nh chá» vÃ  tá»± Ä‘á»™ng dá»n dáº¹p visual/connections
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

-- Hook há»‡ thá»‘ng tráº¡ng thÃ¡i (Status Effects) Ä‘á»ƒ miá»…n nhiá»…m debuff vÃ  screen effect Ä‘Æ°á»£c chá»n
local function initializeStatusEffectHook()
	local globals = getgenv()._NULLSCAPE_Globals
	local StatusImmunity = getStatusImmunity() or getgenv().loadModule("NULLSCAPE/Entities/StatusImmunity.luau")
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
						if activeCtrl and activeCtrl.FleshScreenEffectImmune == true then
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
							if activeCtrl and activeCtrl.FleshScreenEffectImmune == true then
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

	-- Khá»Ÿi cháº¡y vÃ²ng láº·p ngáº§m Ä‘á»ƒ liÃªn tá»¥c khá»­ kÃ­ch thÆ°á»›c Blur vÃ  cÃ¡c hiá»‡u á»©ng mÃ©o/Ä‘á» mÃ n hÃ¬nh
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
			local suppressFleshScreenEffects = activeCtrl and activeCtrl.FleshScreenEffectImmune == true
			if suppressFleshScreenEffects then
				pcall(function()
					local lighting = game:GetService("Lighting")
					local blur = lighting:FindFirstChild("Blur")
					if blur and blur:IsA("BlurEffect") and blur.Size > 0 then
						blur.Size = 0
					end

					for _, name in ipairs({ "Flesh" }) do
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
			task.wait(suppressFleshScreenEffects and 0.2 or 1.0)
		end
	end)
end

-- Hook hiá»‡u á»©ng mÃ¹ khi ai Ä‘Ã³ gÃµ ChuÃ´ng (Bell Blindness / Screen flash black/white)
local function initializeBellBlindnessHook()
	local globals = getgenv()._NULLSCAPE_Globals
	globals.BellHookedFunctions = globals.BellHookedFunctions or {}

	local function shouldBlockRingBell()
		local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
		return activeCtrl and activeCtrl.BellBlindnessImmune == true
	end

	local function makeRingBellWrapper(callback)
		return function(...)
			if shouldBlockRingBell() then
				return
			end
			return callback(...)
		end
	end

	-- Hook _G.RingBell Ä‘á»ƒ trÃ¡nh nháº¥p nhÃ¡y/mÃ¹ cá»¥c bá»™ khi ta tá»± gÃµ hoáº·c cháº¡m chuÃ´ng
	task.spawn(function()
		while not _G.RingBell do
			task.wait(0.5)
		end
		local originalRingBell = _G.RingBell
		if typeof(originalRingBell) ~= "function" then
			return
		end
		if not globals.OriginalRingBell then
			globals.OriginalRingBell = originalRingBell
		end
		_G.RingBell = makeRingBellWrapper(globals.OriginalRingBell)
	end)

	-- Hook OnClientEvent cá»§a Bell Ä‘á»ƒ trÃ¡nh mÃ¹ khi ngÆ°á»i chÆ¡i khÃ¡c gÃµ chuÃ´ng trong phÃ²ng
	task.spawn(function()
		local events = ReplicatedStorage:WaitForChild("Events", 15)
		local bellEvent = events and events:WaitForChild("Bell", 15)
		if bellEvent and bellEvent:IsA("RemoteEvent") then
			if typeof(getconnections) == "function" and typeof(hookfunction) == "function" then
				local function hookBellConnections()
					for _, connection in ipairs(getconnections(bellEvent.OnClientEvent)) do
						local originalFunction = connection.Function
						if
							typeof(originalFunction) == "function"
							and globals.OriginalRingBell
							and originalFunction == globals.OriginalRingBell
							and not globals.BellHookedFunctions[originalFunction]
						then
							local oldFunc
							oldFunc = hookfunction(originalFunction, function(...)
								if shouldBlockRingBell() then
									return
								end
								return oldFunc(...)
							end)
							globals.BellHookedFunctions[originalFunction] = oldFunc
						end
					end
				end

				-- Hook cÃ¡c káº¿t ná»‘i cÅ© Ä‘ang hoáº¡t Ä‘á»™ng
				hookBellConnections()

				-- Hook hÃ m Connect Ä‘á»ƒ tá»± Ä‘á»™ng bá»c cÃ¡c káº¿t ná»‘i má»›i trong tÆ°Æ¡ng lai
				local oldConnect
				oldConnect = hookfunction(bellEvent.OnClientEvent.Connect, function(self, callback)
					if typeof(callback) == "function" and globals.OriginalRingBell and callback == globals.OriginalRingBell then
						return oldConnect(self, makeRingBellWrapper(callback))
					end
					return oldConnect(self, callback)
				end)
			end
		end
	end)
end

-- Hook Ä‘á»ƒ cháº·n RemoteEvent bÃ¡o tá»­ cá»§a thá»±c thá»ƒ Client-side (nhÆ° ICBM vÃ  Springer) má»™t cÃ¡ch an toÃ n
local function initializeICBMHook()
	-- XÃ¢y dá»±ng báº£ng tra cá»©u nhanh O(1) tÃªn cÃ¡c RemoteEvent cáº§n cháº·n
	local TargetRemoteNames = {
		["ClientEvent"] = true,
		["ShockwaveEvent"] = true,
		["DiedFunc"] = true,
		["Died"] = true,
		["OblivionEvent"] = true,
		["BroSecureMethod"] = true,
		["LookEvent"] = true,
	}

	local function handleRemoteCall(self, ...)
		local args = { ... }

		-- Láº¥y activeController hiá»‡n táº¡i tá»« globals
		local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
		if not activeCtrl then
			return false
		end


		-- Kiá»ƒm tra nhanh tÃªn remote trÆ°á»›c (O(1) lookup)
		if not TargetRemoteNames[self.Name] then
			return false
		end


		-- Cháº¡y logic cháº·n RemoteEvent thá»‘ng nháº¥t tá»« RemoteBlocking.luau
		if self.Name == "Died" and args[1] == "VoidImplosion" and activeCtrl.VoidImplosionImmune == true then
			return true
		end

		if activeCtrl.GuardianImmune == true and self.Name == "Died" and args[1] == "Guardian" then
			return true
		end
		local firstStringArg = typeof(args[1]) == "string" and string.lower(args[1]) or ""
		if activeCtrl.KolonaImmune == true
			and (self.Name == "DiedFunc" or self.Name == "Died")
			and firstStringArg == "kolona" then
			return true
		end

		local block, modifiedArgs = RemoteBlocking.shouldBlockRemoteCall(self, args, activeCtrl)
		if block then
			return true, modifiedArgs
		end

		return false
	end

	-- ÄÄƒng kÃ½ dispatcher toÃ n cá»¥c
	getgenv()._NULLSCAPE_Globals.handleEntitiesRemoteCall = handleRemoteCall

	-- 1. Hook __namecall (PhÆ°Æ¡ng phÃ¡p chuáº©n vÃ  máº¡nh nháº¥t cho cÃ¡c cuá»™c gá»i dáº¡ng Remote:FireServer(...) hoáº·c Remote:InvokeServer(...))
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
						if typeof(self) == "Instance" then
							local className = self.ClassName
							if className == "RemoteEvent" then
								isRemote = true
							elseif className == "RemoteFunction" then
								isRemote = true
								isRemoteFunction = true
							end
						end
					end

					if isRemote then
						local dispatcher = getgenv()._NULLSCAPE_Globals.handleEntitiesRemoteCall
						if dispatcher then
							local success, shouldBlock, modifiedArgs = pcall(dispatcher, self, ...)
							if success and shouldBlock then
								if modifiedArgs then
									if typeof(setnamecallmethod) == "function" then
										setnamecallmethod(method)
									end
									return oldNamecall(self, table.unpack(modifiedArgs))
								end
								if isRemoteFunction then
									return nil -- Cháº·n Ä‘á»©ng InvokeServer vÃ  tráº£ vá» nil
								end
								return -- Cháº·n Ä‘á»©ng FireServer
							end
						end
					end
					if typeof(setnamecallmethod) == "function" then
						setnamecallmethod(method)
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

	-- 2. Hook FireServer/InvokeServer prototype (Dá»± phÃ²ng)
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
							return -- Cháº·n Ä‘á»©ng cuá»™c gá»i
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
							return nil -- Cháº·n Ä‘á»©ng cuá»™c gá»i vÃ  tráº£ vá» nil
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

-- ÄÄƒng kÃ½ active controller hiá»‡n táº¡i Ä‘á»ƒ tá»± Ä‘á»™ng dá»«ng cÃ¡c phiÃªn báº£n cÅ©
getgenv()._NULLSCAPE_Globals.activeEntitiesController = Controller

-- Khá»Ÿi táº¡o ban Ä‘áº§u khi náº¡p script
if not inLobby then
	startObservingFolders()
end

-- Láº¯ng nghe sá»± kiá»‡n Ä‘á»•i tráº¡ng thÃ¡i game thá»i gian thá»±c
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

-- VÃ²ng láº·p quan sÃ¡t dá»± phÃ²ng (chá»‰ cháº¡y khi khÃ´ng cÃ³ InRound)
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

task.spawn(initializeICBMHook)
task.spawn(initializeStatusEffectHook)
task.spawn(initializeBellBlindnessHook)

return Controller
