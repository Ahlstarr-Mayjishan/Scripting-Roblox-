--!nocheck
--[[
	NULLSCAPE - Cadence Status
	Compact multi-Cadence timeline. Each active Cadence owns one status row.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local View = getgenv().loadModule("NULLSCAPE/Entities/Cadence Status View.luau")

local Status = {
	Enabled = false,
	Entries = {},
	Connections = {},
	InstrumentCount = 0,
	NextOrdinal = 0,
	UpdateToken = nil,
}

local UPDATE_INTERVAL = 0.25
local RECOVERY_RATE = 2
local TIMER_KEYS = { "Remaining", "TimeLeft", "Timer", "Countdown", "StageTime", "Time" }
local SOLO_TIMER_PROFILE = { 90, 60, 30, 15, 0 }
local MULTIPLAYER_TIMER_PROFILE = { 50, 30, 20, 10, 0 }
local cachedDifficulty = nil

local function disconnectList(connections)
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(connections)
end

local function getTimerProfile()
	if #Players:GetPlayers() <= 1 then
		return SOLO_TIMER_PROFILE
	end
	return MULTIPLAYER_TIMER_PROFILE
end

local function getInstrumentThreshold()
	if not (cachedDifficulty and cachedDifficulty.Parent) then
		cachedDifficulty = ReplicatedStorage:FindFirstChild("Difficulty")
	end
	local difficulty = cachedDifficulty
	return if difficulty and tonumber(difficulty.Value) and tonumber(difficulty.Value) >= 3 then 1 else 2
end

local function readNumber(source)
	if typeof(source) ~= "table" then
		return nil
	end
	for _, key in ipairs(TIMER_KEYS) do
		local value = tonumber(source[key])
		if value then
			return value
		end
	end
	return nil
end

local function readReplicatedTimer(enemy)
	if not enemy then
		return nil
	end
	for _, key in ipairs(TIMER_KEYS) do
		local value = tonumber(enemy:GetAttribute(key))
		if value then
			return value
		end
		local child = enemy:FindFirstChild(key)
		if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
			return tonumber(child.Value)
		end
	end
	return nil
end

local function readAudioState(enemy)
	local layers = enemy and enemy:FindFirstChild("Layers")
	local stage = 1
	if layers then
		local tick2 = layers:FindFirstChild("TickStage2")
		local tick3 = layers:FindFirstChild("TickStage3")
		local alarm2 = layers:FindFirstChild("AlarmStage2")
		if alarm2 and alarm2:IsA("Sound") and alarm2.Volume > 0.25 then
			stage = 4
		elseif tick3 and tick3:IsA("Sound") and tick3.Volume > 0.25 then
			stage = 3
		elseif tick2 and tick2:IsA("Sound") and tick2.Volume > 0.25 then
			stage = 2
		end
	end

	local chase = enemy and enemy:FindFirstChild("Chase")
	local chasing = chase
		and chase:IsA("Sound")
		and chase.IsPlaying
		and chase.Volume > 0.1
		and chase.PlaybackSpeed > 0.1
	return stage, chasing == true
end

local function formatSeconds(value, estimated)
	if value == nil then
		return "--"
	end
	return string.format("%s%.1fs", estimated and "~" or "", math.max(0, value))
end

local function timeUntil(remaining, target)
	if not remaining or remaining <= target then
		return nil
	end
	return remaining - target
end

local function getPhaseColor(entry)
	if entry.Stage == 2 then
		return Color3.fromRGB(255, 190, 70)
	elseif entry.Stage == 3 then
		return Color3.fromRGB(255, 105, 45)
	elseif entry.Stage >= 4 or entry.Chasing then
		return Color3.fromRGB(255, 65, 65)
	end
	return Color3.fromRGB(100, 205, 255)
end

local function getSortedEntries()
	local entries = {}
	for enemy, entry in pairs(Status.Entries) do
		if enemy and enemy.Parent then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(left, right)
		local leftRemaining = tonumber(left.Remaining) or math.huge
		local rightRemaining = tonumber(right.Remaining) or math.huge
		if leftRemaining ~= rightRemaining then
			return leftRemaining < rightRemaining
		end
		return left.Ordinal < right.Ordinal
	end)
	return entries
end

local function getRowText(entry)
	local estimated = not entry.RemainingIsServer
	if entry.Chasing then
		return string.format("Cadence #%d   |   CHASE ACTIVE", entry.Ordinal)
	elseif entry.Stopped then
		return string.format(
			"Cadence #%d   |   Chase stopped   |   Timer: %s",
			entry.Ordinal,
			formatSeconds(entry.Remaining, estimated)
		)
	elseif Status.InstrumentCount < getInstrumentThreshold() then
		return string.format(
			"Cadence #%d   |   Phase %d   |   Timer recovering: %s",
			entry.Ordinal,
			entry.Stage,
			formatSeconds(entry.Remaining, estimated)
		)
	end

	local profile = getTimerProfile()
	return string.format(
		"Cadence #%d   |   P%d   |   Timer %s   |   P2 %s   |   P3 %s   |   Chase %s",
		entry.Ordinal,
		entry.Stage,
		formatSeconds(entry.Remaining, estimated),
		formatSeconds(timeUntil(entry.Remaining, profile[2]), estimated),
		formatSeconds(timeUntil(entry.Remaining, profile[3]), estimated),
		formatSeconds(timeUntil(entry.Remaining, profile[5]), estimated)
	)
end

local function render()
	local entries = getSortedEntries()
	local rows = table.create(#entries)
	for index, entry in ipairs(entries) do
		rows[index] = {
			Text = getRowText(entry),
			Color = getPhaseColor(entry),
		}
	end
	View.render(rows, Status.InstrumentCount, getInstrumentThreshold())
end

local function resetEstimate(entry, stage)
	local profile = getTimerProfile()
	entry.Stage = math.clamp(tonumber(stage) or 1, 1, 4)
	entry.Remaining = profile[entry.Stage]
	entry.RemainingIsServer = false
end

local function onClientEvent(entry, action, payload)
	if action == "Stage" then
		local stage = typeof(payload) == "table" and payload.Stage or payload
		resetEstimate(entry, stage)
		local serverRemaining = readNumber(payload)
		if serverRemaining then
			entry.Remaining = serverRemaining
			entry.RemainingIsServer = true
		end
		entry.Chasing = false
		entry.Stopped = false
	elseif action == "Chase" then
		entry.Chasing = true
		entry.Stopped = false
		entry.Remaining = 0
	elseif action == "ElasticStop" then
		entry.Chasing = false
		entry.Stopped = true
	end
	render()
end

local function updateEntry(entry, elapsed)
	local enemy = entry.Enemy
	if not (enemy and enemy.Parent) then
		return
	end

	local audioStage, audioChasing = readAudioState(enemy)
	if audioChasing ~= entry.Chasing then
		entry.Chasing = audioChasing
		entry.Stopped = not audioChasing
		if audioChasing then
			entry.Remaining = 0
		end
	end
	if not entry.Chasing and audioStage ~= entry.Stage then
		resetEstimate(entry, audioStage)
	end
	if entry.Stopped and Status.InstrumentCount >= getInstrumentThreshold() then
		entry.Stopped = false
	end

	local serverRemaining = readReplicatedTimer(enemy)
	if serverRemaining then
		entry.Remaining = serverRemaining
		entry.RemainingIsServer = true
	elseif not entry.Chasing and entry.Remaining then
		entry.RemainingIsServer = false
		local profile = getTimerProfile()
		if Status.InstrumentCount >= getInstrumentThreshold() then
			entry.Remaining = math.max(0, entry.Remaining - elapsed)
		else
			entry.Remaining = math.min(profile[1], entry.Remaining + elapsed * RECOVERY_RATE)
		end
	end
end

local function ensureRuntimeConnections()
	if #Status.Connections > 0 then
		return
	end

	local function updateInstrumentCount()
		Status.InstrumentCount = #CollectionService:GetTagged("CadenceOrb")
		render()
	end
	updateInstrumentCount()
	table.insert(
		Status.Connections,
		CollectionService:GetInstanceAddedSignal("CadenceOrb"):Connect(updateInstrumentCount)
	)
	table.insert(
		Status.Connections,
		CollectionService:GetInstanceRemovedSignal("CadenceOrb"):Connect(updateInstrumentCount)
	)
end

local function startUpdateLoop()
	if Status.UpdateToken then
		return
	end

	local token = {}
	Status.UpdateToken = token
	task.spawn(function()
		local lastUpdateAt = time()
		while Status.Enabled and Status.UpdateToken == token and next(Status.Entries) ~= nil do
			task.wait(UPDATE_INTERVAL)
			if not Status.Enabled or Status.UpdateToken ~= token or next(Status.Entries) == nil then
				break
			end
			local now = time()
			local elapsed = now - lastUpdateAt
			lastUpdateAt = now
			for _, entry in pairs(Status.Entries) do
				updateEntry(entry, elapsed)
			end
			render()
		end
		if Status.UpdateToken == token then
			Status.UpdateToken = nil
		end
	end)
end

local function findCadences()
	local result = {}
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return result
	end
	for _, enemy in ipairs(enemies:GetChildren()) do
		if string.find(string.lower(enemy.Name), "cadence", 1, true) then
			table.insert(result, enemy)
		end
	end
	return result
end

function Status.clearRuntime()
	Status.UpdateToken = nil
	disconnectList(Status.Connections)
	for _, entry in pairs(Status.Entries) do
		disconnectList(entry.Connections)
	end
	table.clear(Status.Entries)
	Status.InstrumentCount = 0
	Status.NextOrdinal = 0
	View.clear()
end

function Status.attach(enemy)
	if not (Status.Enabled and enemy and enemy.Parent) then
		return false
	end
	if Status.Entries[enemy] then
		return true
	end

	ensureRuntimeConnections()
	Status.NextOrdinal += 1
	local stage, chasing = readAudioState(enemy)
	local entry = {
		Enemy = enemy,
		Connections = {},
		Ordinal = Status.NextOrdinal,
		Stage = stage,
		Chasing = chasing,
		Stopped = false,
		Remaining = nil,
		RemainingIsServer = false,
	}
	resetEstimate(entry, stage)
	if chasing then
		entry.Remaining = 0
	end
	Status.Entries[enemy] = entry
	startUpdateLoop()

	local clientEvent = enemy:FindFirstChild("ClientEvent") or enemy:WaitForChild("ClientEvent", 5)
	if clientEvent and clientEvent:IsA("RemoteEvent") then
		table.insert(
			entry.Connections,
			clientEvent.OnClientEvent:Connect(function(action, payload)
				onClientEvent(entry, action, payload)
			end)
		)
	end
	table.insert(
		entry.Connections,
		enemy.AttributeChanged:Connect(function()
			local serverRemaining = readReplicatedTimer(enemy)
			if serverRemaining then
				entry.Remaining = serverRemaining
				entry.RemainingIsServer = true
				render()
			end
		end)
	)

	render()
	return true
end

function Status.detach(enemy)
	local entry = enemy and Status.Entries[enemy]
	if not entry then
		return
	end
	disconnectList(entry.Connections)
	Status.Entries[enemy] = nil
	if next(Status.Entries) == nil then
		Status.UpdateToken = nil
		disconnectList(Status.Connections)
		Status.InstrumentCount = 0
	end
	render()
end

function Status.setEnabled(enabled)
	Status.Enabled = enabled == true
	Status.clearRuntime()
	if not Status.Enabled then
		return
	end
	for _, enemy in ipairs(findCadences()) do
		Status.attach(enemy)
	end
end

function Status.cleanup()
	Status.Enabled = false
	Status.clearRuntime()
end

return Status
