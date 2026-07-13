--!nocheck
--[[
	NULLSCAPE - Grappler Threat Target Policy
	Applies user threat filters shared by Grapple Dodge and SharkEscape.
]]

local Policy = {}

Policy.Options = {
	"Baby",
	"Bell",
	"Cadence",
	"Flesh",
	"Fleshling",
	"Guardian",
	"ICBM",
	"Mart",
	"nilEnemy",
	"nilMirage",
	"Oblivion",
	"Ponderer",
	"Quartz",
	"Random",
	"Scrapmaw",
	"ShadowBaby",
	"ShadowBabyConcept",
	"ShadowGuardian",
	"Sigil",
	"Slicer",
	"Springer",
	"Telefragger",
	"Voidbreaker",
}

local DEFAULT_IGNORED = {
	["kolona"] = true,
	["operator"] = true,
	["vboperator"] = true,
	["voidbound"] = true,
}

local cadenceConnections = setmetatable({}, { __mode = "k" })
local cadenceChasing = setmetatable({}, { __mode = "k" })

local function normalise(name)
	return string.lower(tostring(name or ""))
end

local function containsName(name, token)
	return string.find(normalise(name), token, 1, true) ~= nil
end

local function selected(options, name)
	if typeof(options) ~= "table" then
		return false
	end

	local key = normalise(name)
	if options[key] == true or options[name] == true then
		return true
	end

	for option, value in pairs(options) do
		if value == true and normalise(option) == key then
			return true
		end
	end

	return false
end

local function observeCadence(enemy)
	if not (enemy and enemy.Parent) or cadenceConnections[enemy] then
		return
	end

	local event = enemy:FindFirstChild("ClientEvent")
	if not (event and event:IsA("RemoteEvent")) then
		return
	end

	cadenceConnections[enemy] = event.OnClientEvent:Connect(function(action)
		if action == "Chase" then
			cadenceChasing[enemy] = true
		elseif action == "ElasticStop" then
			cadenceChasing[enemy] = false
		end
	end)
end

local function isCadenceChasing(enemy)
	observeCadence(enemy)

	local chase = enemy and enemy:FindFirstChild("Chase", true)
	if chase and chase:IsA("Sound") then
		return chase.IsPlaying == true
	end

	return cadenceChasing[enemy] == true
end

function Policy.shouldIgnore(threat, controller, technique)
	local enemy = threat and threat.Enemy
	local name = threat and threat.Name or enemy and enemy.Name
	local lowerName = normalise(name)
	if lowerName == "" then
		return true
	end

	if containsName(lowerName, "cadence") and not isCadenceChasing(enemy) then
		return true
	end

	if DEFAULT_IGNORED[lowerName] or containsName(lowerName, "voidbound") then
		return true
	end

	local whitelist = controller and controller.GrappleThreatWhitelist
	if selected(whitelist, name) then
		return true
	end

	local blacklist = controller and controller.GrappleThreatBlacklist
	if typeof(blacklist) == "table" and next(blacklist) ~= nil and not selected(blacklist, name) then
		return true
	end

	return false
end

function Policy.reset()
	for enemy, connection in pairs(cadenceConnections) do
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
		cadenceConnections[enemy] = nil
		cadenceChasing[enemy] = nil
	end
end

return Policy
