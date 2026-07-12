--!nocheck
--[[
	NULLSCAPE - Native Context Sync
	Event-driven runtime facts shared by grappler helpers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sync = {
	Connections = {},
	Initialized = false,
	Revision = 0,
	State = {
		InRound = false,
		LastBellAt = -1000,
		LastVoidSignalAt = -1000,
		LastUpgradeAt = -1000,
		LastStatusAt = -1000,
		LastEnemyChangeAt = -1000,
	},
}

local function mark(name)
	Sync.State[name] = time()
	Sync.Revision += 1
end

local function connect(signal, callback)
	if not (signal and typeof(signal.Connect) == "function") then
		return
	end

	table.insert(Sync.Connections, signal:Connect(callback))
end

function Sync.initialize()
	if Sync.Initialized then
		return true
	end

	Sync.Initialized = true
	local events = ReplicatedStorage:FindFirstChild("Events")
	local inRound = ReplicatedStorage:FindFirstChild("InRound")
	if inRound and inRound:IsA("BoolValue") then
		Sync.State.InRound = inRound.Value == true
		connect(inRound:GetPropertyChangedSignal("Value"), function()
			Sync.State.InRound = inRound.Value == true
			Sync.Revision += 1
		end)
	end

	connect(events and events:FindFirstChild("UpgradesChanged") and events.UpgradesChanged.OnClientEvent, function()
		mark("LastUpgradeAt")
	end)
	connect(
		events and events:FindFirstChild("StatusEffectChanged") and events.StatusEffectChanged.OnClientEvent,
		function()
			mark("LastStatusAt")
		end
	)
	connect(events and events:FindFirstChild("Bell") and events.Bell.OnClientEvent, function()
		mark("LastBellAt")
	end)
	connect(events and events:FindFirstChild("VoidClient") and events.VoidClient.OnClientEvent, function()
		mark("LastVoidSignalAt")
	end)
	connect(events and events:FindFirstChild("EnemiesChanged") and events.EnemiesChanged.OnClientEvent, function()
		mark("LastEnemyChangeAt")
	end)
	connect(events and events:FindFirstChild("ResetGame") and events.ResetGame.OnClientEvent, function()
		Sync.State.LastBellAt = -1000
		Sync.State.LastVoidSignalAt = -1000
		Sync.Revision += 1
	end)

	return true
end

function Sync.getSnapshot()
	return {
		Revision = Sync.Revision,
		InRound = Sync.State.InRound == true,
		LastBellAt = Sync.State.LastBellAt,
		VoidSignalled = time() - Sync.State.LastVoidSignalAt <= 0.8,
		LastUpgradeAt = Sync.State.LastUpgradeAt,
		LastStatusAt = Sync.State.LastStatusAt,
		LastEnemyChangeAt = Sync.State.LastEnemyChangeAt,
	}
end

function Sync.reset()
	Sync.State.LastBellAt = -1000
	Sync.State.LastVoidSignalAt = -1000
	Sync.Revision += 1
end

function Sync.disable()
	for _, connection in ipairs(Sync.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(Sync.Connections)
	Sync.Initialized = false
	Sync.reset()
end

return Sync
