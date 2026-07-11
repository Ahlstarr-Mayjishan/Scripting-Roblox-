--!nocheck
--[[
	NULLSCAPE - Game State Context
	Small source-aware facade over local character, handlers, upgrades, enemies, and curses.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = {}

local LocalPlayer = Players.LocalPlayer
local moduleCache = {}

local function safeRequire(pathSegments)
	local key = table.concat(pathSegments, "/")
	if moduleCache[key] ~= nil then
		return moduleCache[key]
	end

	local cursor = ReplicatedFirst
	for _, segment in ipairs(pathSegments) do
		cursor = cursor and cursor:FindFirstChild(segment)
		if not cursor then
			moduleCache[key] = false
			return nil
		end
	end

	if not cursor:IsA("ModuleScript") then
		moduleCache[key] = false
		return nil
	end

	local ok, result = pcall(require, cursor)
	moduleCache[key] = ok and result or false
	return ok and result or nil
end

local function readBoolValue(parent, name)
	local value = parent and parent:FindFirstChild(name)
	return value and value:IsA("BoolValue") and value.Value == true
end

function Context.getPlayer()
	return LocalPlayer
end

function Context.getCharacter()
	return LocalPlayer and LocalPlayer.Character
end

function Context.getHumanoid(character)
	character = character or Context.getCharacter()
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Context.getRootPart(character)
	character = character or Context.getCharacter()
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Context.isDead()
	if not LocalPlayer then
		return true
	end

	local deadValue = LocalPlayer:FindFirstChild("Dead")
	if deadValue and deadValue:IsA("BoolValue") then
		return deadValue.Value == true
	end

	local character = Context.getCharacter()
	return not (character and character.Parent and Context.getHumanoid(character))
end

function Context.isInRound()
	return readBoolValue(ReplicatedStorage, "InRound")
end

function Context.getUsingAbility(character)
	local humanoid = Context.getHumanoid(character)
	return humanoid and humanoid:GetAttribute("UsingAbility") == true
end

function Context.setUsingAbility(value, character)
	local humanoid = Context.getHumanoid(character)
	if not humanoid then
		return false
	end

	local ok = pcall(function()
		humanoid:SetAttribute("UsingAbility", value == true)
	end)
	return ok
end

function Context.getClassId()
	local character = Context.getCharacter()
	local classId = character and character:GetAttribute("Class")
	if typeof(classId) == "string" then
		return classId
	end

	local inventory = safeRequire({ "ClientModules", "Core", "PlayerData", "InventoryHandler" })
	if inventory and typeof(inventory.GetEquipped) == "function" then
		local ok, equipped = pcall(inventory.GetEquipped, "Class")
		if ok then
			return equipped
		end
	end

	return nil
end

function Context.hasStatus(statusName)
	local status = safeRequire({ "ClientModules", "StatusEffectHandler" })
	if status and typeof(status.HasStatus) == "function" then
		local ok, result = pcall(status.HasStatus, statusName)
		return ok and result == true
	end

	return false
end

function Context.isUpgradeEnabled(upgradeName)
	local upgrades = safeRequire({ "ClientModules", "UpgradeHandler" })
	if upgrades and typeof(upgrades.IsUpgradeEnabled) == "function" then
		local ok, result = pcall(upgrades.IsUpgradeEnabled, upgradeName)
		return ok and result == true
	end

	return false
end

function Context.isEnemyEnabled(enemyName)
	local enemies = safeRequire({ "ClientModules", "EnemyHandler" })
	if enemies and typeof(enemies.IsEnemyEnabled) == "function" then
		local ok, result = pcall(enemies.IsEnemyEnabled, enemyName)
		return ok and result == true
	end

	return false
end

function Context.isCurseEnabled(curseName)
	local curses = safeRequire({ "ClientModules", "CurseHandler" })
	if curses and typeof(curses.IsCurseEnabled) == "function" then
		local ok, result = pcall(curses.IsCurseEnabled, curseName)
		return ok and result == true
	end

	return false
end

function Context.isGreaterCurseEnabled(curseName)
	local curses = safeRequire({ "ClientModules", "GreaterCurseHandler" })
	if curses and typeof(curses.IsCurseEnabled) == "function" then
		local ok, result = pcall(curses.IsCurseEnabled, curseName)
		return ok and result == true
	end

	return false
end

function Context.isKolonaActive()
	return shared.KolonaActive == true
end

function Context.isRazorbloomActive(character)
	character = character or Context.getCharacter()
	return character and character:FindFirstChild("Razorbloom") ~= nil
end

function Context.snapshot()
	return {
		Player = LocalPlayer,
		Character = Context.getCharacter(),
		Humanoid = Context.getHumanoid(),
		RootPart = Context.getRootPart(),
		Dead = Context.isDead(),
		InRound = Context.isInRound(),
		UsingAbility = Context.getUsingAbility(),
		ClassId = Context.getClassId(),
		KolonaActive = Context.isKolonaActive(),
		RazorbloomActive = Context.isRazorbloomActive(),
	}
end

return Context
