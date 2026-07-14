-- [[
--  NULLSCAPE - Entities Controller
--  Coordinates entity detection, immunity modules, observers, and cleanup.
-- ]]

local getgenv = getgenv
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

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
local CelestialImmunity = getgenv().loadModule("NULLSCAPE/Entities/Celestial Immunity.luau")
local VoidImplosionImmunity = getgenv().loadModule("NULLSCAPE/Entities/Void Implosion Immunity.luau")
local CadenceStatus = getgenv().loadModule("NULLSCAPE/Entities/Cadence Status.luau")
local OperatorAutoDisable = getgenv().loadModule("NULLSCAPE/Entities/Operator Auto Disable.luau")
local RazorbloomAutoDisable = getgenv().loadModule("NULLSCAPE/Entities/Razorbloom Auto Disable.luau")
local BellImmunity = getgenv().loadModule("NULLSCAPE/Entities/Bell Immunity.luau")
local GC = getgenv().loadModule("NULLSCAPE/Entities/GC.luau")
local KolonaAutoQTE = nil
local SpringerAutoJump = nil

local function getKolonaAutoQTE()
	if KolonaAutoQTE then
		return KolonaAutoQTE
	end

	local ok, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Entities/Kolona Auto QTE.luau")
	end)
	if ok and typeof(result) == "table" then
		KolonaAutoQTE = result
		return result
	end

	warn("[NULLSCAPE] Kolona Auto QTE failed to load: " .. tostring(result))
	return nil
end

local function getSpringerAutoJump()
	if SpringerAutoJump then
		return SpringerAutoJump
	end

	local ok, result = pcall(function()
		return getgenv().loadModule("NULLSCAPE/Entities/Springer Auto Jump.luau")
	end)
	if ok and typeof(result) == "table" then
		SpringerAutoJump = result
		return result
	end

	warn("[NULLSCAPE] Springer Auto Jump failed to load: " .. tostring(result))
	return nil
end

local function shouldBlockWithShieldPolicy(controller, allowShieldBait)
	if RemoteBlocking and typeof(RemoteBlocking.shouldBlockWithShieldPolicy) == "function" then
		return RemoteBlocking.shouldBlockWithShieldPolicy(controller, allowShieldBait)
	end

	return true
end

local Controller = {
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
	OperatorAutoDisable = false,
	SpringerImmune = false,
	SpringerKnockbackImmune = false,
	SpringerAutoJumpEnabled = false,
	SkinwalkerImmune = false,
	KolonaImmune = false,
	KolonaAutoQTEEnabled = false,
	OblivionImmune = false,
	ShadowBabyImmune = false,
	QuartzImmune = false,
	SigilImmune = false,
	SlicerImmune = false,
	VoidbreakerImmune = false,
	RazorbloomImmune = false,
	RazorbloomAutoDisable = false,
	CadenceImmune = false,
	CadenceAutoCollectInstruments = false,
	CadenceCheckStatus = false,
	CadenceInstrumentRange = 0,
	PondererImmune = false,
	PondererSilentLookat = false,
	VoidImplosionImmune = false,
	CelestialImmune = false,
	RealityBreakImmune = false,
	ScrapmawImmune = false,
	CatalystImmune = false,
	nilEnemyImmune = false,
	nilMirageImmune = false,
	SeamineImmune = false,
	ShieldBaitEnabled = false,
	ShieldBaitChance = 0,
	LastShieldBaitAt = 0,
	Destroyed = false,

	EnemiesFolder = nil,
	PermanentConnections = {},
	CadenceAutoCollectLoopActive = false,
}
GC.Controller = Controller

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
	return select("#", ...)
end

local inLobby = not isInMatch()
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
local startCadenceAutoCollectLoop

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
	if globals.EntitiesHookOwner ~= nil and globals.EntitiesHookOwner ~= Controller then
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

	globals.handleEntitiesRemoteCall = nil

	-- Restore StatusEffect connection hook
	-- WARNING: DO NOT call hookfunction on OnClientEvent.Connect prototype.
	if globals.StatusEffectHooked then
		globals.StatusEffectLoopToken = nil
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
	globals.EntitiesHookOwner = nil
end

function Controller:SetSeamineImmune(value)
	self.SeamineImmune = value
end

function Controller:SetShieldBaitEnabled(value)
	self.ShieldBaitEnabled = value == true
end

function Controller:SetShieldBaitChance(value)
	self.ShieldBaitChance = math.clamp(tonumber(value) or 0, 0, 100)
end

function Controller:SetICBMBurnImmune(value)
	self.ICBMBurnImmune = value == true
end

function Controller:SetKolonaAutoQTE(value)
	self.KolonaAutoQTEEnabled = value == true

	if self.KolonaAutoQTEEnabled then
		local kolona = getKolonaAutoQTE()
		if kolona and typeof(kolona.update) == "function" then
			return kolona.update(self)
		end
	elseif KolonaAutoQTE and typeof(KolonaAutoQTE.disable) == "function" then
		return KolonaAutoQTE.disable(self)
	end

	return true
end

function Controller:SetBellCurseImmune(value)
	self.BellCurseImmune = value == true
	BellImmunity.update(self)
	Executor.reconcile(GC)
end

function Controller:SetBellBlindnessImmune(value)
	self.BellBlindnessImmune = value == true
	BellImmunity.update(self)
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

local function updateSourceEventImmunity(controller)
	CelestialImmunity.disable()
	if controller.inLobby ~= true and (controller.CelestialImmune == true or controller.RealityBreakImmune == true) then
		CelestialImmunity.enable()
	end
end

function Controller:ReconcileImmunityState()
	Executor.reconcile(GC)
	updateSourceEventImmunity(self)
	OperatorAutoDisable.setEnabled(self.OperatorAutoDisable == true)
	RazorbloomAutoDisable.setEnabled(self.RazorbloomAutoDisable == true and self.inLobby ~= true)
	if self.VoidImplosionImmune == true and self.inLobby ~= true then
		VoidImplosionImmunity.enable()
	else
		VoidImplosionImmunity.disable()
	end

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

function Controller:CleanUp()
	local globals = getgenv()._NULLSCAPE_Globals
	local finalCleanup = self.Destroyed
		or (globals and globals.activeEntitiesController ~= nil and globals.activeEntitiesController ~= self)

	for part, state in pairs(originalTouchStates) do
		if part and part.Parent then
			pcall(function()
				part.CanTouch = state
			end)
		end
	end
	table.clear(originalTouchStates)

	for part in pairs(disabledShockwaves) do
		restoreShockwave(part)
	end

	disconnectFolderObservations()
	pcall(function()
		Executor.disableSpecialImmunity()
	end)
	pcall(function()
		CelestialImmunity.disable()
	end)
	pcall(function()
		VoidImplosionImmunity.disable()
	end)
	pcall(function()
		local kolona = KolonaAutoQTE
		if kolona and typeof(kolona.disable) == "function" then
			kolona.disable(self)
		end
	end)
	pcall(function()
		if SpringerAutoJump and typeof(SpringerAutoJump.disable) == "function" then
			SpringerAutoJump.disable()
		end
	end)
	pcall(function()
		if finalCleanup then
			RazorbloomAutoDisable.disable()
		else
			RazorbloomAutoDisable.setEnabled(false)
		end
	end)
	if finalCleanup then
		pcall(OperatorAutoDisable.disable)
	end
	pcall(if finalCleanup then BellImmunity.disable else BellImmunity.clearRuntime)

	GC.cleanAll()
	self.EnemiesFolder = nil

	pcall(if finalCleanup then CadenceStatus.cleanup else CadenceStatus.clearRuntime)

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

	if finalCleanup then
		local StatusImmunity = getStatusImmunity()
		if StatusImmunity and typeof(StatusImmunity.disable) == "function" then
			pcall(StatusImmunity.disable)
		end
		pcall(restoreHooks)
		if globals and globals.NullscapeEntitiesGC == GC then
			globals.NullscapeEntitiesGC = nil
		end
	end

	-- Keep the active controller during lobby cleanup; only full destroy may release it.
	if finalCleanup and globals and globals.activeEntitiesController == self then
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

	elseif entityName == "Cadence" then
		self.CadenceImmune = value
	elseif entityName == "Ponderer" then
		self.PondererImmune = value
	elseif entityName == "Celestial" then
		self.CelestialImmune = value == true
		updateSourceEventImmunity(self)
	elseif entityName == "RealityBreak" then
		self.RealityBreakImmune = value == true
		updateSourceEventImmunity(self)
	elseif entityName == "VoidImplosion" then
		self.VoidImplosionImmune = value == true
		if self.VoidImplosionImmune and self.inLobby ~= true then
			VoidImplosionImmunity.enable()
		else
			VoidImplosionImmunity.disable()
		end
	elseif entityName == "Scrapmaw" then
		self.ScrapmawImmune = value
	elseif entityName == "Catalyst" then
		self.CatalystImmune = value
	elseif entityName == "Seamine" then
		self.SeamineImmune = value == true
	elseif entityName == "Razorbloom" then
		self.RazorbloomImmune = value == true
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

	if value then
		local function applyImmunityToChild(child)
			if not (child:IsA("Model") or child:IsA("BasePart")) then
				return
			end

			if entityName == "Skinwalker" then
				local isHusk = (string.find(child.Name, "Skinwalker") or string.find(child.Name, "Husk"))
					and child.Name ~= "Skinwalkers"
				if isHusk then
					HuskEvasion.enableHuskImmunity(GC, child)
				end
				return
			end

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

function Controller:SetCadenceAutoCollectInstruments(value)
	self.CadenceAutoCollectInstruments = value == true
	if self.CadenceAutoCollectInstruments and self.inLobby ~= true then
		startCadenceAutoCollectLoop()
	end
end

function Controller:SetCadenceInstrumentRange(value)
	self.CadenceInstrumentRange = math.clamp(tonumber(value) or 0, 0, 30)
end

function Controller:SetCadenceOptions(options)
	local immune = false
	local autoCollect = false
	local checkStatus = false

	for _, option in ipairs(typeof(options) == "table" and options or {}) do
		if option == "Immunity" then
			immune = true
		elseif option == "Auto Collect Instruments" then
			autoCollect = true
		elseif option == "CheckStatus" then
			checkStatus = true
		end
	end

	self.CadenceCheckStatus = checkStatus
	self:SetImmunity("Cadence", immune)
	self:SetCadenceAutoCollectInstruments(autoCollect)
	CadenceStatus.setEnabled(checkStatus)
end

function Controller:SetOperatorAutoDisable(enabled)
	self.OperatorAutoDisable = enabled == true
	local installed = OperatorAutoDisable.setEnabled(self.OperatorAutoDisable)
	if self.OperatorAutoDisable and not installed then
		warn("[NULLSCAPE] Operator Auto Disable could not locate the native isStationary closure")
	end
	return installed
end

function Controller:SetOperatorOptions(options)
	local hasOption = function(option)
		return typeof(options) == "table" and (options[option] == true or table.find(options, option) ~= nil)
	end

	self:SetImmunity("Operator", hasOption("Immunity"))
	return self:SetOperatorAutoDisable(hasOption("Auto Disable"))
end

function Controller:SetRazorbloomAutoDisable(enabled)
	self.RazorbloomAutoDisable = enabled == true
	return RazorbloomAutoDisable.setEnabled(self.RazorbloomAutoDisable and self.inLobby ~= true)
end

function Controller:SetRazorbloomOptions(options)
	local hasOption = function(option)
		return typeof(options) == "table" and (options[option] == true or table.find(options, option) ~= nil)
	end

	self:SetImmunity("Razorbloom", hasOption("Immunity"))
	return self:SetRazorbloomAutoDisable(hasOption("Auto Disable"))
end

function Controller:SetPondererSilentLookat(enabled)
	self.PondererSilentLookat = enabled == true
end

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

function Controller:SetSpringerAutoJump(enabled)
	self.SpringerAutoJumpEnabled = enabled == true
	local autoJump = getSpringerAutoJump()
	if not autoJump then
		self.SpringerAutoJumpEnabled = false
		return false
	end

	if not self.SpringerAutoJumpEnabled then
		autoJump.disable()
		return true
	end

	if self.EnemiesFolder then
		for _, enemy in ipairs(self.EnemiesFolder:GetChildren()) do
			if string.find(enemy.Name, "Springer") then
				for _, child in ipairs(enemy:GetChildren()) do
					if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
						autoJump.watch(enemy, child, self)
					end
				end
			end
		end
	end

	return true
end

function Controller:SetSpringerOptions(options)
	local hasOption = function(option)
		return typeof(options) == "table" and (options[option] == true or table.find(options, option) ~= nil)
	end

	self:SetImmunity("Springer", hasOption("Immunity"))
	self:SetSpringerKnockbackImmune(hasOption("Immunity Shockwave") or hasOption("Springer Knockback"))
	return self:SetSpringerAutoJump(hasOption("Auto Jump"))
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
	else
		if not self.BellImmune then
			TouchInterest.disableImmunityForType(GC, "Bell")
		end
	end
	BellImmunity.update(self)
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

local function processEntity(enemy)
	if not enemy or not (enemy:IsA("Model") or enemy:IsA("BasePart")) or enemy.Name == "Skinwalkers" then
		return
	end
	if processedEntities[enemy] or (GC.EntityConnections and GC.EntityConnections[enemy]) then
		return
	end
	processedEntities[enemy] = true

	if enemy:IsA("Model") then
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
							local descendantConn = child.DescendantAdded:Connect(formatSquare)
							GC.registerEntityConnection(enemy, descendantConn)
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
							local destroyingConn = child.Destroying:Connect(function()
								posConn:Disconnect()
							end)
							GC.registerEntityConnection(enemy, posConn)
							GC.registerEntityConnection(enemy, destroyingConn)
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
			local actualHead
			for _ = 1, 30 do
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
				task.wait(0.05)
			end

			if not enemy or not enemy.Parent then
				return
			end

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

			task.wait(0.2)
			if enemy.Parent and not (enemy:FindFirstChild("ESP") or enemy:FindFirstChild("ESPCrayon")) then
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

	local function checkAndApply()
		if not enemy or not enemy.Parent then
			return
		end
		local name = enemy.Name
		debugPrint("processEntity checkAndApply for:", name)

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

		if
			HuskEvasion.isHuskEntity(name)
			or (enemy:GetAttribute("OriginalName") and HuskEvasion.isHuskEntity(enemy:GetAttribute("OriginalName")))
		then
			if Controller.SkinwalkerImmune then
				HuskEvasion.enableHuskImmunity(GC, enemy)
			end
		end

		if string.find(name, "Cadence") then
			CadenceStatus.attach(enemy)
		end

		if string.find(name, "Bell", 1, true) then
			BellImmunity.attachEnemy(enemy, GC)
		end
	end

	local nameConn = enemy:GetPropertyChangedSignal("Name"):Connect(checkAndApply)
	GC.registerEntityConnection(enemy, nameConn)

	checkAndApply()

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

	if string.find(enemy.Name, "Springer") then
		local childAddedConn = enemy.ChildAdded:Connect(function(child)
			if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
				if Controller.SpringerKnockbackImmune == true then
					disableShockwave(enemy, child)
				end
				if Controller.SpringerAutoJumpEnabled then
					local autoJump = getSpringerAutoJump()
					if autoJump then
						autoJump.watch(enemy, child, Controller)
					end
				end
			end
		end)
		GC.registerEntityConnection(enemy, childAddedConn)

		for _, child in ipairs(enemy:GetChildren()) do
			if child.Name == "SpringerShockwave" or child.Name == "DemonShockwave" then
				if Controller.SpringerKnockbackImmune == true then
					disableShockwave(enemy, child)
				end
				if Controller.SpringerAutoJumpEnabled then
					local autoJump = getSpringerAutoJump()
					if autoJump then
						autoJump.watch(enemy, child, Controller)
					end
				end
			end
		end
	end
end

local function removeEntity(enemy)
	processedEntities[enemy] = nil
	BellImmunity.detachEnemy(enemy)
	GC.removeEntityConnections(enemy)
	if SpringerAutoJump then
		SpringerAutoJump.releaseEnemy(enemy)
	end

	for part, data in pairs(disabledShockwaves) do
		if data.enemy == enemy then
			restoreShockwave(part)
		end
	end
	if string.find(enemy.Name, "Cadence") then
		CadenceStatus.detach(enemy)
	end
end

function Controller:CleanUpFolder(folder)
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		removeEntity(child)
	end

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

	if self.EnemiesFolder == folder then
		self.EnemiesFolder = nil
	end
end

function Controller:ObserveFolder(folder)
	debugPrint("ObserveFolder called for:", folder:GetFullName())
	if folderConnections[folder] then
		debugPrint("Folder already observed, skipping:", folder.Name)
		return
	end

	if folder.Name == "Enemies" then
		self.EnemiesFolder = folder
	end

	local conns = {}

	local childAddedConn = folder.ChildAdded:Connect(function(child)
		debugPrint("ObserveFolder: ChildAdded in:", folder.Name, "| Child Name:", child.Name)
		processEntity(child)
	end)
	table.insert(conns, childAddedConn)

	local childRemovedConn = folder.ChildRemoved:Connect(function(child)
		removeEntity(child)
	end)
	table.insert(conns, childRemovedConn)

	debugPrint("ObserveFolder: Existing children in:", folder.Name, "| count:", #folder:GetChildren())
	for _, child in ipairs(folder:GetChildren()) do
		debugPrint("ObserveFolder: Processing existing child:", child.Name)
		processEntity(child)
	end

	local destroyingConn = folder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:CleanUpFolder(folder)
		end
	end)
	table.insert(conns, destroyingConn)

	folderConnections[folder] = conns
end

function Controller:UpdateTouchImmunityState()
	restoreCharacterTouchStates()
end

local function collectCadenceInstruments(controller)
	if not (controller and controller.CadenceAutoCollectInstruments == true) then
		return
	end
	if controller.inLobby == true then
		return
	end
	if typeof(firetouchinterest) ~= "function" then
		return
	end

	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local hrpPos = hrp.Position
	local instrumentRange = tonumber(controller.CadenceInstrumentRange) or 0
	for _, orb in ipairs(CollectionService:GetTagged("CadenceOrb")) do
		if orb:IsA("BasePart") and orb.Parent then
			local dist = (orb.Position - hrpPos).Magnitude
			if instrumentRange == 0 or dist <= instrumentRange then
				pcall(function()
					firetouchinterest(orb, hrp, 0)
					task.wait()
					firetouchinterest(orb, hrp, 1)
				end)
			end
		end
	end
end

startCadenceAutoCollectLoop = function()
	if Controller.CadenceAutoCollectLoopActive then
		return
	end
	Controller.CadenceAutoCollectLoopActive = true
	task.spawn(function()
		while
			not Controller.Destroyed
			and Controller.CadenceAutoCollectInstruments == true
			and Controller.inLobby ~= true
		do
			pcall(collectCadenceInstruments, Controller)
			task.wait(0.15)
		end
		Controller.CadenceAutoCollectLoopActive = false
	end)
end

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

	for _, child in ipairs(workspace:GetChildren()) do
		if (child.Name == "Enemies" or child.Name == "Skinwalkers") and child:IsA("Folder") then
			Controller:ObserveFolder(child)
		end
	end
end

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
		updateSourceEventImmunity(Controller)
		if Controller.VoidImplosionImmune == true then
			VoidImplosionImmunity.enable()
		end
		if Controller.CadenceAutoCollectInstruments == true then
			startCadenceAutoCollectLoop()
		end
		if Controller.CadenceCheckStatus == true then
			CadenceStatus.setEnabled(true)
		end
		if Controller.KolonaAutoQTEEnabled == true and typeof(Controller.SetKolonaAutoQTE) == "function" then
			Controller:SetKolonaAutoQTE(true)
		end
	end
end

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

local function initializeICBMHook()
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

		local activeCtrl = getgenv()._NULLSCAPE_Globals.activeEntitiesController
		if not activeCtrl then
			return false
		end


		if not TargetRemoteNames[self.Name] then
			return false
		end


		if activeCtrl.GuardianImmune == true and self.Name == "Died" and args[1] == "Guardian" then
			return shouldBlockWithShieldPolicy(activeCtrl)
		end
		local firstStringArg = typeof(args[1]) == "string" and string.lower(args[1]) or ""
		if activeCtrl.KolonaImmune == true
			and (self.Name == "DiedFunc" or self.Name == "Died")
			and firstStringArg == "kolona" then
			return shouldBlockWithShieldPolicy(activeCtrl)
		end

		local block, modifiedArgs = RemoteBlocking.shouldBlockRemoteCall(self, args, activeCtrl)
		if block then
			return true, modifiedArgs
		end

		return false
	end

	getgenv()._NULLSCAPE_Globals.handleEntitiesRemoteCall = handleRemoteCall

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
									return nil
								end
								return
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

	-- Namecall is the only remote interception path because it can be restored cleanly.
	if not namecallSuccess then
		warn("Failed to initialize the ClientSideHit namecall hook.")
	end
end

getgenv()._NULLSCAPE_Globals.activeEntitiesController = Controller
getgenv()._NULLSCAPE_Globals.EntitiesHookOwner = Controller

if not inLobby then
	startObservingFolders()
end

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
BellImmunity.initialize(Controller)

return Controller
