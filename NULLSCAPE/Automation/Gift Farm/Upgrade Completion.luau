--!nocheck

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeCompletion = {}

local activeUpgrades = {}
local definitions = nil
local synced = false
local syncing = false
local started = false
local connections = {}

local function getUpgradeIndexModule()
	local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
	local core = sharedModules and sharedModules:FindFirstChild("Core")
	local index = core and core:FindFirstChild("Index")
	return index and index:FindFirstChild("UpgradeIndex")
end

local function loadDefinitions()
	if definitions then
		return definitions
	end

	local module = getUpgradeIndexModule()
	if not module then
		return nil
	end

	local ok, index = pcall(require, module)
	if not ok or typeof(index) ~= "table" then
		return nil
	end

	local deadline = os.clock() + 5
	repeat
		if typeof(index.Items) == "table" and next(index.Items) ~= nil then
			definitions = index.Items
			return definitions
		end
		task.wait()
	until os.clock() >= deadline

	return nil
end

local function getDifficulty()
	local value = ReplicatedStorage:FindFirstChild("Difficulty")
	return tonumber(value and value.Value) or 0
end

local function isPlayerCountEligible(prerequisites, playerCount)
	local minimumPlayers = tonumber(prerequisites.PlayerCount) or 0
	local maximumPlayers = tonumber(prerequisites.MaxPlayers)
	return playerCount >= minimumPlayers and (maximumPlayers == nil or playerCount <= maximumPlayers)
end

local function isEligible(definition, difficulty, playerCount)
	if typeof(definition) ~= "table" then
		return false
	end

	local maximum = tonumber(definition.MaxStack) or 0
	local prerequisites = definition.Prerequisites
	local price = definition.Price
	if maximum <= 0 or price == nil or typeof(prerequisites) ~= "table" then
		return false
	end

	if not isPlayerCountEligible(prerequisites, playerCount) then
		return false
	end

	if typeof(price) == "table" and price[difficulty] == nil then
		return false
	end
	local stage = tonumber(prerequisites.Stage) or 0
	-- Native marks default/non-shop entries such as TheOrb with an infinite stage.
	if stage == math.huge then
		return false
	end

	local minimumDifficulty = tonumber(prerequisites.Difficulty) or 0
	return difficulty >= minimumDifficulty
end

local function applyServerSnapshot(snapshot, replace)
	if typeof(snapshot) ~= "table" then
		return false
	end

	if replace then
		table.clear(activeUpgrades)
	end
	for upgradeName, stack in pairs(snapshot) do
		activeUpgrades[upgradeName] = tonumber(stack) or (stack == true and 1 or 0)
	end
	return true
end

local function getSyncRemote()
	local events = ReplicatedStorage:FindFirstChild("Events")
	local functions = events and events:FindFirstChild("Functions")
	return functions and functions:FindFirstChild("GetActiveUpgrades")
end

function UpgradeCompletion.refresh()
	if syncing then
		return false
	end

	syncing = true
	local remote = getSyncRemote()
	local ok, snapshot = pcall(function()
		return remote and remote:InvokeServer()
	end)
	syncing = false
	if not ok or not applyServerSnapshot(snapshot, true) then
		return false
	end

	synced = true
	return true
end

function UpgradeCompletion.evaluate()
	local items = definitions
	local difficulty = getDifficulty()
	local playerCount = #Players:GetPlayers()
	local result = {
		Complete = false,
		Trusted = synced and items ~= nil and difficulty >= 1 and difficulty <= 3,
		OwnedStacks = 0,
		RequiredStacks = 0,
		Missing = {},
	}
	if not result.Trusted then
		return result
	end

	for upgradeName, definition in pairs(items) do
		if isEligible(definition, difficulty, playerCount) then
			local maximum = math.max(0, tonumber(definition.MaxStack) or 0)
			local owned = math.clamp(tonumber(activeUpgrades[upgradeName]) or 0, 0, maximum)
			result.OwnedStacks += owned
			result.RequiredStacks += maximum
			if owned < maximum then
				result.Missing[#result.Missing + 1] = {
					Name = upgradeName,
					Owned = owned,
					Required = maximum,
				}
			end
		end
	end

	table.sort(result.Missing, function(a, b)
		return a.Name < b.Name
	end)
	result.Complete = result.RequiredStacks > 0 and #result.Missing == 0
	return result
end

function UpgradeCompletion.start(gc)
	if started then
		return true
	end
	started = true

	local events = ReplicatedStorage:FindFirstChild("Events")
	local changed = events and events:FindFirstChild("UpgradesChanged")
	if changed and changed:IsA("RemoteEvent") then
		connections[#connections + 1] = changed.OnClientEvent:Connect(function(snapshot)
			applyServerSnapshot(snapshot, false)
		end)
	end
	local resetGame = events and events:FindFirstChild("ResetGame")
	if resetGame and resetGame:IsA("RemoteEvent") then
		connections[#connections + 1] = resetGame.OnClientEvent:Connect(function()
			table.clear(activeUpgrades)
			synced = false
			task.delay(0.25, function()
				if started then
					UpgradeCompletion.refresh()
				end
			end)
		end)
	end

	for _, connection in ipairs(connections) do
		if gc and typeof(gc.registerConnection) == "function" then
			gc.registerConnection(connection)
		end
	end
	task.spawn(function()
		loadDefinitions()
		UpgradeCompletion.refresh()
	end)
	return true
end

function UpgradeCompletion.stop()
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(connections)
	table.clear(activeUpgrades)
	definitions = nil
	synced = false
	syncing = false
	started = false
end

return UpgradeCompletion
