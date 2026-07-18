--!nocheck
-- [[
--  NULLSCAPE - Native Gift Registry
--  Caches the native GiftClient handler and emits revisions from native replication.
-- ]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = {}

local connections = {}
local changedEvent = Instance.new("BindableEvent")
local cachedHandler = nil
local cachedHandlerModule = nil
local revision = 0
local lastReason = "Initial"
local started = false
local dirtyDeferred = false

local function disconnectAll()
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(connections)
end

local function connect(signal, callback)
	if signal and typeof(signal.Connect) == "function" then
		local connection = signal:Connect(callback)
		connections[#connections + 1] = connection
		return connection
	end
	return nil
end

local function resolveHandlerModule()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		or ReplicatedStorage:FindFirstChild("ClientModules")
	local giftClient = clientModules and clientModules:FindFirstChild("GiftClient")
	local handlerModule = giftClient and giftClient:FindFirstChild("GiftClientHandler")
	return handlerModule and handlerModule:IsA("ModuleScript") and handlerModule or nil
end

local function markDirty(reason)
	revision += 1
	lastReason = tostring(reason or "Changed")
	changedEvent:Fire(revision, lastReason)
end

local function deferDirty(reason)
	lastReason = tostring(reason or lastReason)
	if dirtyDeferred then
		return
	end
	dirtyDeferred = true
	task.defer(function()
		dirtyDeferred = false
		markDirty(lastReason)
	end)
end

local function bindCounter(counter)
	if not counter then
		return
	end
	connect(counter.Changed, function()
		deferDirty("GiftCounterValue")
	end)
	connect(counter.AttributeChanged, function()
		deferDirty("GiftCounterAttribute")
	end)
end

function Registry.start()
	if started then
		return true
	end
	started = true

	local giftShared = ReplicatedStorage:FindFirstChild("GiftShared")
	local remotes = giftShared and giftShared:FindFirstChild("Remotes")
	local replicate = remotes and remotes:FindFirstChild("Replicate")
	local collection = remotes and remotes:FindFirstChild("Collection")
	if replicate and replicate:IsA("RemoteEvent") then
		connect(replicate.OnClientEvent, function()
			deferDirty("GiftReplication")
		end)
	end
	if collection and collection:IsA("RemoteEvent") then
		connect(collection.OnClientEvent, function()
			deferDirty("GiftCollectionResult")
		end)
	end

	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local events = movement and movement:FindFirstChild("Events")
	local collectedGift = events and events:FindFirstChild("CollectedGift")
	if collectedGift and collectedGift:IsA("BindableEvent") then
		connect(collectedGift.Event, function()
			deferDirty("LocalGiftCollected")
		end)
	end

	local counters = ReplicatedStorage:FindFirstChild("GiftCounters")
	bindCounter(counters and counters:FindFirstChild("Gift"))
	bindCounter(counters and counters:FindFirstChild("GoldenGift"))

	local inRound = ReplicatedStorage:FindFirstChild("InRound")
	if inRound and inRound:IsA("BoolValue") then
		connect(inRound.Changed, function()
			markDirty("RoundChanged")
		end)
	end

	markDirty("Started")
	return true
end

function Registry.stop()
	if not started then
		return
	end
	started = false
	dirtyDeferred = false
	disconnectAll()
	cachedHandler = nil
	cachedHandlerModule = nil
	markDirty("Stopped")
end

function Registry.getHandler()
	local handlerModule = resolveHandlerModule()
	if cachedHandler and handlerModule == cachedHandlerModule then
		return cachedHandler
	end

	cachedHandler = nil
	cachedHandlerModule = handlerModule
	if not handlerModule then
		return nil
	end

	local ok, handler = pcall(require, handlerModule)
	if ok and typeof(handler) == "table" then
		cachedHandler = handler
	end
	return cachedHandler
end

function Registry.getRevision()
	return revision
end

function Registry.getLastReason()
	return lastReason
end

function Registry.markDirty(reason)
	markDirty(reason)
end

function Registry.connectChanged(callback)
	return changedEvent.Event:Connect(callback)
end

return Registry
