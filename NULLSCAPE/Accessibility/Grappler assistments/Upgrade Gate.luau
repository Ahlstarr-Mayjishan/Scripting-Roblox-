--!nocheck
--[[
	NULLSCAPE - Grappler Upgrade Gate
	Checks that a native upgrade exists in UpgradeIndex before allowing technique behavior.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeGate = {}

local ALIASES = {
	SharkBelt = "SharkTail",
	sharkbelt = "SharkTail",
	["Shark Belt"] = "SharkTail",
	["shark belt"] = "SharkTail",
}

local EXISTENCE_CACHE = {}

local function normalizeUpgradeName(upgradeName)
	local name = tostring(upgradeName or "")
	return ALIASES[name] or name
end

local function getUpgradeIndex()
	local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
	local core = sharedModules and sharedModules:FindFirstChild("Core")
	local index = core and core:FindFirstChild("Index")
	return index and index:FindFirstChild("UpgradeIndex")
end

function UpgradeGate.exists(upgradeName)
	local nativeName = normalizeUpgradeName(upgradeName)
	if nativeName == "" then
		return false, nil
	end

	if EXISTENCE_CACHE[nativeName] ~= nil then
		return EXISTENCE_CACHE[nativeName], nativeName
	end

	local upgradeIndex = getUpgradeIndex()
	if not upgradeIndex then
		return false, nativeName
	end

	local exists = upgradeIndex:FindFirstChild(nativeName) ~= nil
	EXISTENCE_CACHE[nativeName] = exists
	return exists, nativeName
end

function UpgradeGate.has(movement, upgradeName)
	local exists, nativeName = UpgradeGate.exists(upgradeName)
	if not (exists and movement and typeof(movement.HasUpgrade) == "function") then
		return false, nativeName
	end

	local success, enabled, stack = pcall(function()
		return movement:HasUpgrade(nativeName)
	end)

	return success and enabled == true, nativeName, stack
end

function UpgradeGate.hasAll(movement, upgradeNames)
	for _, upgradeName in ipairs(upgradeNames or {}) do
		local enabled = UpgradeGate.has(movement, upgradeName)
		if not enabled then
			return false
		end
	end

	return true
end

return UpgradeGate
