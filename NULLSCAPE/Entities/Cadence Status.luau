--!nocheck
--[[
	NULLSCAPE - Cadence Status
	Event-driven Cadence phase, chase, timer and instrument status display.
]]

local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Status = {
	Enabled = false,
	Enemy = nil,
	Gui = nil,
	Labels = nil,
	Connections = {},
	Stage = 1,
	Chasing = false,
	Stopped = false,
	InstrumentCount = 0,
	Remaining = nil,
	RemainingIsServer = false,
	LastUpdateAt = 0,
}

local UPDATE_INTERVAL = 0.25
local RECOVERY_RATE = 2
local TIMER_KEYS = { "Remaining", "TimeLeft", "Timer", "Countdown", "StageTime", "Time" }

local function disconnectAll()
	for _, connection in ipairs(Status.Connections) do
		connection:Disconnect()
	end
	table.clear(Status.Connections)
end

local function getTimerProfile()
	if #Players:GetPlayers() <= 1 then
		return { 90, 60, 30, 15, 0 }
	end
	return { 50, 30, 20, 10, 0 }
end

local function getInstrumentThreshold()
	local difficulty = ReplicatedStorage:FindFirstChild("Difficulty")
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

local function ensureGui()
	if Status.Gui and Status.Gui.Parent then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "NULLSCAPE_CadenceStatus"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.fromOffset(330, 128)
	frame.Position = UDim2.fromOffset(16, 115)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "StatusStroke"
	stroke.Color = Color3.fromRGB(85, 85, 90)
	stroke.Thickness = 1
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 25)
	title.Position = UDim2.fromOffset(10, 7)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "CADENCE STATUS"
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local phase = Instance.new("TextLabel")
	phase.Name = "Phase"
	phase.Size = UDim2.new(1, -20, 0, 24)
	phase.Position = UDim2.fromOffset(10, 34)
	phase.BackgroundTransparency = 1
	phase.Font = Enum.Font.GothamMedium
	phase.TextColor3 = Color3.fromRGB(100, 205, 255)
	phase.TextSize = 15
	phase.TextXAlignment = Enum.TextXAlignment.Left
	phase.Parent = frame

	local eta = phase:Clone()
	eta.Name = "ETA"
	eta.Position = UDim2.fromOffset(10, 61)
	eta.TextColor3 = Color3.fromRGB(205, 205, 210)
	eta.TextSize = 12
	eta.Parent = frame

	local details = phase:Clone()
	details.Name = "Details"
	details.Position = UDim2.fromOffset(10, 88)
	details.TextColor3 = Color3.fromRGB(180, 180, 185)
	details.TextSize = 12
	details.Parent = frame

	local parented = pcall(function()
		gui.Parent = CoreGui
	end)
	if not parented then
		local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		gui.Parent = playerGui
	end

	Status.Gui = gui
	Status.Labels = { Phase = phase, ETA = eta, Details = details, Stroke = stroke }
end

local function render()
	if not (Status.Enemy and Status.Enemy.Parent) then
		if Status.Gui then
			Status.Gui.Enabled = false
		end
		return
	end

	ensureGui()
	Status.Gui.Enabled = true
	local labels = Status.Labels
	if not labels then
		return
	end

	local profile = getTimerProfile()
	local estimated = not Status.RemainingIsServer
	local countdownActive = Status.InstrumentCount >= getInstrumentThreshold()
	local phaseColor = Color3.fromRGB(100, 205, 255)
	if Status.Stage == 2 then
		phaseColor = Color3.fromRGB(255, 190, 70)
	elseif Status.Stage == 3 then
		phaseColor = Color3.fromRGB(255, 105, 45)
	elseif Status.Stage >= 4 or Status.Chasing then
		phaseColor = Color3.fromRGB(255, 65, 65)
	end

	labels.Phase.Text = string.format(
		"Phase %d   |   Timer: %s",
		Status.Stage,
		formatSeconds(Status.Remaining, estimated)
	)
	labels.Phase.TextColor3 = phaseColor

	if Status.Chasing then
		labels.ETA.Text = "Chase active"
	elseif Status.Stopped then
		labels.ETA.Text = "Chase stopped"
	elseif not countdownActive then
		labels.ETA.Text = "Safe: timer recovering"
	else
		local p2 = formatSeconds(timeUntil(Status.Remaining, profile[2]), estimated)
		local p3 = formatSeconds(timeUntil(Status.Remaining, profile[3]), estimated)
		local chase = formatSeconds(timeUntil(Status.Remaining, profile[5]), estimated)
		labels.ETA.Text = string.format("P2: %s   |   P3: %s   |   Chase: %s", p2, p3, chase)
	end

	labels.Details.Text = string.format(
		"Chase: %s   |   Instruments: %d   |   Danger at: %d",
		Status.Chasing and "ACTIVE" or "Idle",
		Status.InstrumentCount,
		getInstrumentThreshold()
	)
	labels.Stroke.Color = if Status.Chasing then Color3.fromRGB(255, 65, 65) else phaseColor
end

local function updateInstrumentCount()
	Status.InstrumentCount = #CollectionService:GetTagged("CadenceOrb")
	render()
end

local function resetEstimate(stage)
	local profile = getTimerProfile()
	Status.Stage = math.clamp(tonumber(stage) or 1, 1, 4)
	Status.Remaining = profile[Status.Stage]
	Status.RemainingIsServer = false
end

local function onClientEvent(action, payload)
	if action == "Stage" then
		local stage = typeof(payload) == "table" and payload.Stage or payload
		resetEstimate(stage)
		local serverRemaining = readNumber(payload)
		if serverRemaining then
			Status.Remaining = serverRemaining
			Status.RemainingIsServer = true
		end
		Status.Chasing = false
		Status.Stopped = false
	elseif action == "Chase" then
		Status.Chasing = true
		Status.Stopped = false
		Status.Remaining = 0
	elseif action == "ElasticStop" then
		Status.Chasing = false
		Status.Stopped = true
	end
	render()
end

local function findCadence()
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	for _, enemy in ipairs(enemies:GetChildren()) do
		if string.find(string.lower(enemy.Name), "cadence", 1, true) then
			return enemy
		end
	end
	return nil
end

function Status.clearRuntime()
	disconnectAll()
	Status.Enemy = nil
	Status.Labels = nil
	if Status.Gui then
		Status.Gui:Destroy()
		Status.Gui = nil
	end
	Status.Stage = 1
	Status.Chasing = false
	Status.Stopped = false
	Status.Remaining = nil
	Status.RemainingIsServer = false
	Status.LastUpdateAt = 0
end

function Status.attach(enemy)
	if not (Status.Enabled and enemy and enemy.Parent) then
		return false
	end
	if Status.Enemy == enemy then
		return true
	end

	Status.clearRuntime()
	Status.Enemy = enemy
	local initialStage, initialChase = readAudioState(enemy)
	resetEstimate(initialStage)
	Status.Chasing = initialChase
	if initialChase then
		Status.Remaining = 0
	end
	updateInstrumentCount()

	local clientEvent = enemy:FindFirstChild("ClientEvent") or enemy:WaitForChild("ClientEvent", 5)
	if clientEvent and clientEvent:IsA("RemoteEvent") then
		table.insert(Status.Connections, clientEvent.OnClientEvent:Connect(onClientEvent))
	end
	table.insert(Status.Connections, enemy.AttributeChanged:Connect(function()
		local serverRemaining = readReplicatedTimer(enemy)
		if serverRemaining then
			Status.Remaining = serverRemaining
			Status.RemainingIsServer = true
			render()
		end
	end))
	table.insert(Status.Connections, CollectionService:GetInstanceAddedSignal("CadenceOrb"):Connect(updateInstrumentCount))
	table.insert(Status.Connections, CollectionService:GetInstanceRemovedSignal("CadenceOrb"):Connect(updateInstrumentCount))
	table.insert(Status.Connections, RunService.Heartbeat:Connect(function(deltaTime)
		Status.LastUpdateAt += deltaTime
		if Status.LastUpdateAt < UPDATE_INTERVAL then
			return
		end
		local elapsed = Status.LastUpdateAt
		Status.LastUpdateAt = 0
		local audioStage, audioChasing = readAudioState(enemy)
		if audioChasing ~= Status.Chasing then
			Status.Chasing = audioChasing
			Status.Stopped = not audioChasing
			if audioChasing then
				Status.Remaining = 0
			end
		end
		if not Status.Chasing and audioStage ~= Status.Stage then
			resetEstimate(audioStage)
		end
		if Status.Stopped and Status.InstrumentCount >= getInstrumentThreshold() then
			Status.Stopped = false
		end

		local serverRemaining = readReplicatedTimer(enemy)
		if serverRemaining then
			Status.Remaining = serverRemaining
			Status.RemainingIsServer = true
		elseif not Status.Chasing and Status.Remaining then
			Status.RemainingIsServer = false
			local profile = getTimerProfile()
			if Status.InstrumentCount >= getInstrumentThreshold() then
				Status.Remaining = math.max(0, Status.Remaining - elapsed)
			else
				Status.Remaining = math.min(profile[1], Status.Remaining + elapsed * RECOVERY_RATE)
			end
		end
		render()
	end))
	render()
	return true
end

function Status.detach(enemy)
	if enemy == nil or Status.Enemy == enemy then
		Status.clearRuntime()
	end
end

function Status.setEnabled(enabled)
	Status.Enabled = enabled == true
	Status.clearRuntime()
	if not Status.Enabled then
		return
	end
	local enemy = findCadence()
	if enemy then
		Status.attach(enemy)
	end
end

function Status.cleanup()
	Status.Enabled = false
	Status.clearRuntime()
end

return Status
