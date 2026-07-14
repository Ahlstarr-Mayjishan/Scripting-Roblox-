-- [[
--  NULLSCAPE - Remote Event Blocking
--  Filters selected client-originated entity damage and death reports.
-- ]]

local Logic = {}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RemoteRegistry = getgenv().loadModule("NULLSCAPE/Core/Remote Registry.luau")
local rng = Random.new()

-- ============================================================
-- Remote blocking configuration
-- ============================================================
Logic.Config = {
	["Baby"] = {
		ControllerFlag = "BabyImmune",
		Remotes = { "Died" },
		Keywords = { "Baby" },
		LegitKeywords = { "Baby" },
	},
	["Mart"] = {
		ControllerFlag = "MartImmune",
		Remotes = { "ClientEvent" },
		Keywords = {},
		LegitKeywords = {},
		BlockEmptyCalls = true,
	},
	["ICBM"] = {
		ControllerFlag = "ICBMImmune",
		Remotes = { "ClientEvent" },
		Keywords = { "kill", "damage", "hit", "combust" },
		LegitKeywords = { "kill" },
	},
	["Guardian"] = {
		ControllerFlag = "GuardianImmune",
		Remotes = { "ClientEvent", "Died" },
		Keywords = { "Kill", "Guardian" },
		LegitKeywords = { "Kill", "Guardian" },
	},
	["ShadowGuardian"] = {
		ControllerFlag = "GuardianImmune",
		Remotes = { "ClientEvent" },
		Keywords = { "Kill" },
		LegitKeywords = { "Kill" },
	},
	["Springer"] = {
		ControllerFlag = "SpringerImmune",
		Remotes = { "ClientEvent", "ShockwaveEvent", "Died" },
		Keywords = { "Springer", "Kill", "DemonKill", "Debuff" },
		LegitKeywords = { "Springer", "Kill", "DemonKill" },
	},
	["Bell"] = {
		ControllerFlag = "BellCurseImmune",
		Remotes = { "ClientEvent" },
		Keywords = { "debuff" },
		LegitKeywords = { "debuff" },
	},
	["Kolona"] = {
		ControllerFlag = "KolonaImmune",
		Remotes = { "DiedFunc", "Died" },
		Keywords = { "Kolona" },
		LegitKeywords = { "Kolona" },
	},
	["Oblivion"] = {
		ControllerFlag = "OblivionImmune",
		Remotes = { "DiedFunc", "OblivionEvent" },
		Keywords = { "Oblivion" },
		LegitKeywords = { "Oblivion" },
		BlockEmptyCalls = true,
	},
	["ShadowBaby"] = {
		ControllerFlag = "ShadowBabyImmune",
		Remotes = { "Died" },
		Keywords = { "ShadowBaby" },
		LegitKeywords = { "ShadowBaby" },
	},
	["Quartz"] = {
		ControllerFlag = "QuartzImmune",
		Remotes = { "ClientEvent" },
		Keywords = { "Kill", "Combust" },
		LegitKeywords = { "Kill", "Combust" },
	},
	["Sigil"] = {
		ControllerFlag = "SigilImmune",
		Remotes = { "ClientEvent" },
		Keywords = { "Kill", "Combust" },
		LegitKeywords = { "Kill", "Combust" },
	},
	["Slicer"] = {
		ControllerFlag = "SlicerImmune",
		Remotes = { "ClientEvent" },
		Keywords = {},
		LegitKeywords = {},
		BlockEmptyCalls = true,
	},
	["Voidbreaker"] = {
		ControllerFlag = "VoidbreakerImmune",
		Remotes = { "Died" },
		Keywords = { "Voidbreaker" },
		LegitKeywords = { "Voidbreaker" },
	},
	["Razorbloom"] = {
		ControllerFlag = "RazorbloomImmune",
		Remotes = { "ClientEvent" },
		Keywords = { "Fail" },
		LegitKeywords = { "Fail" },
	},
	["Scrapmaw"] = {
		ControllerFlag = "ScrapmawImmune",
		Remotes = { "Died" },
		Keywords = { "Scrapmaw" },
		LegitKeywords = { "Scrapmaw" },
	},
	["Skinwalker"] = {
		ControllerFlag = "SkinwalkerImmune",
		Remotes = { "Died" },
		Keywords = { "Skinwalker" },
		LegitKeywords = { "Skinwalker" },
	},
}

Logic.TargetRemotes = {}
for _, data in pairs(Logic.Config) do
	if data.Remotes then
		for _, rName in ipairs(data.Remotes) do
			Logic.TargetRemotes[rName] = true
		end
	end
end

local CELESTIAL_CLIENT_BLOCKLIST = {
	kill = true,
	deathbeam = true,
}

local CELESTIAL_DIED_REASONS = {
	celestial = true,
}

local REALITY_BREAK_CLIENT_BLOCKLIST = {
	kill = true,
}

local function hasAncestorName(instance, targetSubName)
	local current = instance and instance.Parent
	local depth = 0
	local lowerTarget = string.lower(tostring(targetSubName or ""))

	while current and current ~= workspace and current ~= game and depth < 50 do
		depth = depth + 1
		local lowerName = string.lower(tostring(current.Name or ""))
		if string.find(lowerName, lowerTarget, 1, true) then
			return true
		end
		current = current.Parent
	end

	return false
end

local function isCelestialKillReport(remote, args)
	if typeof(remote) ~= "Instance" then
		return false
	end

	local remoteName = remote.Name
	local firstArg = tostring(args and args[1] or "")
	local lowerFirstArg = string.lower(firstArg)

	if remoteName == "Died" then
		return CELESTIAL_DIED_REASONS[lowerFirstArg] == true
	end

	if remoteName ~= "ClientEvent" then
		return false
	end

	local hasCelestialKillKeyword = CELESTIAL_CLIENT_BLOCKLIST[lowerFirstArg] == true
	if not hasCelestialKillKeyword then
		for _, arg in ipairs(args or {}) do
			if typeof(arg) == "string" and CELESTIAL_CLIENT_BLOCKLIST[string.lower(arg)] == true then
				hasCelestialKillKeyword = true
				break
			end
		end
	end

	if not hasCelestialKillKeyword then
		return false
	end

	return hasAncestorName(remote, "Celestial")
end

local function isRealityBreakKillReport(remote, args)
	return remote.Name == "ClientEvent"
		and REALITY_BREAK_CLIENT_BLOCKLIST[string.lower(tostring(args and args[1] or ""))] == true
		and hasAncestorName(remote, "RealityBreak")
end

local function isSeamineKillReport(remote, args)
	return remote.Name == "ClientEvent"
		and string.lower(tostring(args and args[1] or "")) == "kill"
		and hasAncestorName(remote, "Seamine")
end

local function localPlayerHasStatus(statusName)
	local LocalPlayer = Players.LocalPlayer
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
	if not (LocalPlayer and handlerModule and handlerModule:IsA("ModuleScript")) then
		return false
	end

	local success, StatusEffectHandler = pcall(require, handlerModule)
	if
		not (success and typeof(StatusEffectHandler) == "table" and typeof(StatusEffectHandler.HasStatus) == "function")
	then
		return false
	end

	local okWithPlayer, hasWithPlayer = pcall(StatusEffectHandler.HasStatus, LocalPlayer, statusName)
	if okWithPlayer and hasWithPlayer == true then
		return true
	end

	local okStatusOnly, hasStatusOnly = pcall(StatusEffectHandler.HasStatus, statusName)
	return okStatusOnly and hasStatusOnly == true
end

local function noteBellDebuff(controller)
	controller.LastBellDebuffAt = time()
	if not (controller.BellCurseImmune or controller.BellKnockbackImmune) then
		return
	end

	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	controller.BellPendingRoot = rootPart
	controller.BellVelocityBeforeDebuff = rootPart.AssemblyLinearVelocity
	controller.BellVelocityRestoreUntil = time() + 0.15
	task.defer(function()
		if
			(controller.BellCurseImmune or controller.BellKnockbackImmune)
			and controller.BellVelocityRestoreUntil
			and time() <= controller.BellVelocityRestoreUntil
			and controller.BellPendingRoot == rootPart
			and rootPart.Parent
		then
			rootPart.AssemblyLinearVelocity = controller.BellVelocityBeforeDebuff
			rootPart.Velocity = controller.BellVelocityBeforeDebuff
		end
	end)
end

local SHIELD_NAME_KEYWORDS = {
	"shield",
	"barrier",
	"forcefield",
}

local SHIELD_STATUS_NAMES = {
	"Shield",
	"Barrier",
	"ForceField",
}

local SHIELD_SOURCE_UPGRADES = {
	Shield = "Shield",
	SubspacialBarrier = "TripShield",
	AltarOfVoid = "VoidShield",
	LastManStanding = "NormalShield",
	PanicNecklace = "LastShieldBreakEffect",
}

local cachedUpgradeHandler = nil

local function getUpgradeHandler()
	if cachedUpgradeHandler ~= nil then
		return cachedUpgradeHandler
	end

	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
	local upgradeHandlerModule = clientModules and clientModules:FindFirstChild("UpgradeHandler")
	if not upgradeHandlerModule then
		return nil
	end

	local ok, handler = pcall(require, upgradeHandlerModule)
	if ok and typeof(handler) == "table" then
		cachedUpgradeHandler = handler
	end

	return cachedUpgradeHandler
end

local function getActiveUpgradeStack(upgradeName)
	local handler = getUpgradeHandler()
	if typeof(handler) ~= "table" or typeof(handler.GetActiveUpgrades) ~= "function" then
		return 0
	end

	local ok, upgrades = pcall(handler.GetActiveUpgrades)
	if not ok or typeof(upgrades) ~= "table" then
		return 0
	end

	local value = upgrades[upgradeName]
	if value == true then
		return 1
	end

	return tonumber(value) or 0
end

local function hasShieldKeyword(text)
	local lowerText = string.lower(tostring(text or ""))
	for _, keyword in ipairs(SHIELD_NAME_KEYWORDS) do
		if string.find(lowerText, keyword, 1, true) then
			return true
		end
	end
	return false
end

local function hasShieldAttribute(instance)
	if not instance then
		return false
	end

	for attrName, value in pairs(instance:GetAttributes()) do
		if hasShieldKeyword(attrName) and (value == true or (typeof(value) == "number" and value > 0)) then
			return true
		end
	end

	return false
end

local function hasShieldLikeChild(container)
	if not container then
		return false
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ForceField") or hasShieldKeyword(child.Name) or hasShieldAttribute(child) then
			return true
		end
	end

	return false
end

function Logic.getLocalShieldState(includeUpgradeSources)
	local localPlayer = Players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	local userId = localPlayer and localPlayer.UserId
	local isSpirit = character and character:GetAttribute("Spirit") == true or false
	local normalShield = 0
	local tripShield = 0
	local spiritShield = 0

	if userId and typeof(_G) == "table" then
		local playerShields = _G.PlrShield
		if typeof(playerShields) == "table" then
			normalShield = math.max(0, tonumber(playerShields[userId]) or 0)
		end

		local playerTripShields = _G.PlrTripShield
		if typeof(playerTripShields) == "table" then
			tripShield = math.max(0, tonumber(playerTripShields[userId]) or 0)
		end
	end

	if character then
		spiritShield = math.max(0, tonumber(character:GetAttribute("SpiritShield")) or 0)
	end

	local effectiveNormalShield = if isSpirit then spiritShield else normalShield
	local state = {
		IsSpirit = isSpirit,
		NormalShield = normalShield,
		TripShield = if isSpirit then 0 else tripShield,
		SpiritShield = spiritShield,
		EffectiveNormalShield = effectiveNormalShield,
		TotalShield = effectiveNormalShield + (if isSpirit then 0 else tripShield),
		UpgradeSources = nil,
	}

	if includeUpgradeSources == true then
		local sources = {}
		for upgradeName, sourceKind in pairs(SHIELD_SOURCE_UPGRADES) do
			local stack = getActiveUpgradeStack(upgradeName)
			if stack > 0 then
				sources[upgradeName] = {
					Kind = sourceKind,
					Stack = stack,
				}
			end
		end
		state.UpgradeSources = sources
	end

	return state
end

function Logic.getLocalShieldAmount(shieldKind)
	local state = Logic.getLocalShieldState(false)
	if shieldKind == "TripShield" then
		return state.TripShield
	elseif shieldKind == "NormalShield" or shieldKind == "Shield" then
		return state.EffectiveNormalShield
	elseif shieldKind == "SpiritShield" then
		return state.SpiritShield
	end

	return state.TotalShield
end

local function localPlayerHasShield(shieldKind)
	local localPlayer = Players.LocalPlayer
	local character = localPlayer and localPlayer.Character

	if shieldKind == "TripShield" then
		return Logic.getLocalShieldAmount("TripShield") > 0
	end

	if Logic.getLocalShieldAmount("NormalShield") > 0 then
		return true
	end

	if not character then
		return false
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if
		character:FindFirstChildOfClass("ForceField")
		or hasShieldAttribute(character)
		or hasShieldLikeChild(character)
		or (humanoidRootPart and humanoidRootPart:FindFirstChild("Shield") ~= nil)
	then
		return true
	end

	if localPlayer and (hasShieldAttribute(localPlayer) or hasShieldLikeChild(localPlayer)) then
		return true
	end

	for _, statusName in ipairs(SHIELD_STATUS_NAMES) do
		if localPlayerHasStatus(statusName) then
			return true
		end
	end

	return false
end

function Logic.shouldUseShieldBait(controller, allowShieldBait)
	if allowShieldBait == false then
		return false
	end

	if not (controller and controller.ShieldBaitEnabled == true) then
		return false
	end

	local chance = math.clamp(tonumber(controller.ShieldBaitChance) or 0, 0, 100)
	if chance <= 0 or not localPlayerHasShield(allowShieldBait) then
		return false
	end

	if chance >= 100 then
		controller.LastShieldBaitAt = time()
		return true
	end

	if rng:NextNumber(0, 100) < chance then
		controller.LastShieldBaitAt = time()
		return true
	end

	return false
end

function Logic.shouldBlockWithShieldPolicy(controller, allowShieldBait)
	return not Logic.shouldUseShieldBait(controller, allowShieldBait)
end

local function isICBMClientReport(remote, args)
	local firstArg = typeof(args[1]) == "string" and string.lower(args[1])
	if
		not (
			remote
			and remote:IsA("RemoteEvent")
			and remote.Name == "ClientEvent"
			and (firstArg == "kill" or firstArg == "combust")
		)
	then
		return false
	end

	local parent = remote.Parent
	if not parent then
		return false
	end
	local parentName = string.lower(parent.Name)
	if string.find(parentName, "icbm", 1, true) ~= nil or string.find(parentName, "nuclear", 1, true) ~= nil then
		return true
	end

	if parent:FindFirstChild("ICBM_ClientAI") or parent:FindFirstChild("ICBM_AI") then
		return true
	end

	return false
end
local function isKolonaKillReport(remote, args)
	if typeof(remote) ~= "Instance" then
		return false
	end

	local remoteName = remote.Name
	if remoteName ~= "DiedFunc" and remoteName ~= "Died" then
		return false
	end

	local firstArg = typeof(args and args[1]) == "string" and string.lower(args[1]) or ""
	return firstArg == "kolona"
end

local function isVoidImplosionDeathReport(remote, args)
	return remote.Name == "Died" and args[1] == "VoidImplosion"
end

local function findEntityParent(obj, targetSubName)
	local current = obj.Parent
	local depth = 0
	local lowerTarget = string.lower(targetSubName)
	while current and current ~= workspace and current ~= game and depth < 50 do
		depth = depth + 1
		local name = current.Name
		if name and string.find(string.lower(name), lowerTarget, 1, true) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isTargetsSomeoneElse(args, localPlayer, char)
	for i = 2, #args do
		local arg = args[i]
		if typeof(arg) == "Instance" then
			if arg:IsA("Player") and arg ~= localPlayer then
				return true
			elseif arg:IsA("Model") and arg:FindFirstChildOfClass("Humanoid") and arg ~= char then
				return true
			end
		elseif typeof(arg) == "table" then
			for _, val in pairs(arg) do
				if typeof(val) == "Instance" then
					if val:IsA("Player") and val ~= localPlayer then
						return true
					elseif val:IsA("Model") and val:FindFirstChildOfClass("Humanoid") and val ~= char then
						return true
					end
				end
			end
		end
	end
	return false
end

function Logic.shouldBlockRemoteCall(remote, args, controller)
	if not controller then
		return false
	end

	if typeof(remote) ~= "Instance" then
		return false
	end

	if RemoteRegistry and typeof(RemoteRegistry.isRemote) == "function" and not RemoteRegistry.isRemote(remote) then
		return false
	end

	if controller.CelestialImmune == true and isCelestialKillReport(remote, args) then
		return Logic.shouldBlockWithShieldPolicy(controller)
	end

	if controller.RealityBreakImmune == true and isRealityBreakKillReport(remote, args) then
		return Logic.shouldBlockWithShieldPolicy(controller)
	end

	if controller.SeamineImmune == true and isSeamineKillReport(remote, args) then
		return Logic.shouldBlockWithShieldPolicy(controller)
	end

	if isICBMClientReport(remote, args) then
		local firstArg = string.lower(args[1])
		if firstArg == "kill" then
			return controller.ICBMImmune == true and Logic.shouldBlockWithShieldPolicy(controller)
		end
		if firstArg == "combust" then
			return controller.ICBMBurnImmune == true and Logic.shouldBlockWithShieldPolicy(controller)
		end
	end

	if controller.KolonaImmune == true and isKolonaKillReport(remote, args) then
		return Logic.shouldBlockWithShieldPolicy(controller)
	end

	if controller.VoidImplosionImmune == true and isVoidImplosionDeathReport(remote, args) then
		return Logic.shouldBlockWithShieldPolicy(controller, false)
	end

	if controller.inLobby then
		return false
	end

	local remoteName = remote.Name
	if remoteName == "LookEvent" then
		if controller.PondererSilentLookat == true and findEntityParent(remote, "Ponderer") then
			if args[1] ~= true then
				local newArgs = table.clone(args)
				newArgs[1] = true
				return true, newArgs
			end
		end
	end

	if remote.ClassName == "RemoteEvent" and remote.Name == "ClientEvent" and args[1] == "Debuff" then
		local parent = remote.Parent
		if parent and string.find(parent.Name, "Bell", 1, true) then
			noteBellDebuff(controller)
			if controller.BellCurseImmune == true then
				return Logic.shouldBlockWithShieldPolicy(controller, false)
			end
		end
	end

	if
		controller.BellOvertunedKillImmune == true
		and remote.ClassName == "RemoteEvent"
		and remote.Name == "ClientEvent"
		and args[1] == "Debuff"
	then
		local parent = remote.Parent
		if parent and string.find(parent.Name, "Bell", 1, true) and localPlayerHasStatus("Overtuned") then
			return Logic.shouldBlockWithShieldPolicy(controller, false)
		end
	end

	-- Operator is entirely client-driven and reports its kill through the BroSecureMethod RemoteEvent or DiedFunc.
	if controller.OperatorImmune == true then
		if
			(remote.Name == "BroSecureMethod" and args[1] == 1112)
			or (remote.ClassName == "RemoteFunction" and remote.Name == "DiedFunc" and args[1] == "Operator")
		then
			return Logic.shouldBlockWithShieldPolicy(controller)
		end
	end

	if remote.ClassName ~= "RemoteEvent" and remote.ClassName ~= "RemoteFunction" then
		return false
	end

	if not Logic.TargetRemotes[remoteName] then
		return false
	end

	local LocalPlayer = Players.LocalPlayer
	local char = LocalPlayer and LocalPlayer.Character

	for entityName, config in pairs(Logic.Config) do
		local controllerFlag = config.ControllerFlag
		if controller[controllerFlag] == true then
			local isMatchingRemote = false
			for _, rName in ipairs(config.Remotes) do
				if rName == remoteName then
					isMatchingRemote = true
					break
				end
			end

			if isMatchingRemote then
				local hasKeyword = false
				local keywordsList = config.Keywords or {}

				if config.BlockEmptyCalls and #args == 0 then
					hasKeyword = true
				else
					for _, arg in ipairs(args) do
						if typeof(arg) == "string" then
							local lowerArg = string.lower(arg)
							for _, kw in ipairs(keywordsList) do
								if string.lower(kw) == lowerArg or string.find(lowerArg, string.lower(kw), 1, true) then
									hasKeyword = true
									break
								end
							end
						end
						if hasKeyword then
							break
						end
					end
				end

				if hasKeyword then
					local isRelated = false
					if findEntityParent(remote, entityName) then
						isRelated = true
					else
						for _, arg in ipairs(args) do
							if
								(
									typeof(arg) == "Instance"
									and string.find(string.lower(arg.Name), string.lower(entityName), 1, true)
								)
								or (
									typeof(arg) == "string"
									and string.find(string.lower(arg), string.lower(entityName), 1, true)
								)
							then
								isRelated = true
								break
							end
						end
					end

					if isRelated and not isTargetsSomeoneElse(args, LocalPlayer, char) then
						return Logic.shouldBlockWithShieldPolicy(controller)
					end
				end
			end
		end
	end

	return false
end

return Logic
