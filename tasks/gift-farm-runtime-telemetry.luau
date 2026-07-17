--!nocheck
--[[
	NULLSCAPE - Gift Farm Runtime Telemetry Probe

	Standalone, passive instrumentation for the native gift protocols. This file is
	intentionally outside the Rojo tree and update manifest. It never moves the
	character, invokes collection, or changes Gift Farm tuning.

	Run this file in the same client environment as NULLSCAPE. Re-running it stops
	the previous probe first.

	Console/API:
		getgenv().NULLSCAPE_GiftTelemetryProbe.report()
		getgenv().NULLSCAPE_GiftTelemetryProbe.reset()
		getgenv().NULLSCAPE_GiftTelemetryProbe.stop()
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local REPORT_INTERVAL = 5
local SETTLE_SCAN_INTERVAL = 0.25
local MAX_LATENCY_SAMPLES = 512
local MAX_PENDING_AGE = 5

local env = getgenv()
local previous = env.NULLSCAPE_GiftTelemetryProbe
if typeof(previous) == "table" and typeof(previous.stop) == "function" then
	pcall(previous.stop)
end

local state = {
	Running = true,
	StartedAt = os.clock(),
	Connections = {},
	PendingById = {},
	PendingCount = 0,
	OriginalSendCollect = nil,
	WrappedSendCollect = nil,
	ReplicationClient = nil,
	GiftHandler = nil,
	CollectWrappers = {},
	RenderEpoch = 0,
	CurrentBatch = nil,
	BatchOutcomes = {},
	LastRootPosition = nil,
	LastRootMoveAt = os.clock(),
	RootConnection = nil,
	Attempts = 0,
	Accepted = 0,
	Rejected = 0,
	TimedOut = 0,
	UnmatchedRejects = 0,
	LegacyAccepted = 0,
	LegacyRejected = 0,
	LocalCollectedSignals = 0,
	FailureLatencies = table.create(MAX_LATENCY_SAMPLES),
	FailureLatencyHead = 1,
	FailureLatencyCount = 0,
	AckLatencies = table.create(MAX_LATENCY_SAMPLES),
	AckLatencyHead = 1,
	AckLatencyCount = 0,
	PositionDeltas = table.create(MAX_LATENCY_SAMPLES),
	PositionDeltaHead = 1,
	PositionDeltaCount = 0,
	AcceptedGiftDistances = table.create(MAX_LATENCY_SAMPLES),
	AcceptedGiftDistanceHead = 1,
	AcceptedGiftDistanceCount = 0,
	AcceptedSettledTimes = table.create(MAX_LATENCY_SAMPLES),
	AcceptedSettledTimeHead = 1,
	AcceptedSettledTimeCount = 0,
	RejectGiftDistances = table.create(MAX_LATENCY_SAMPLES),
	RejectGiftDistanceHead = 1,
	RejectGiftDistanceCount = 0,
	RejectSettledTimes = table.create(MAX_LATENCY_SAMPLES),
	RejectSettledTimeHead = 1,
	RejectSettledTimeCount = 0,
	LastReport = nil,
}

local function getRootPart()
	local player = Players.LocalPlayer
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getPosition()
	local root = getRootPart()
	return root and root.Position or nil
end

local function normalizePingSeconds(value)
	local ping = tonumber(value)
	if not ping or ping <= 0 then
		return nil
	end
	if ping > 1 then
		ping /= 1000
	end
	return ping
end

local function getPingSeconds()
	local ok, value = pcall(function()
		if Stats.Network and typeof(Stats.Network.GetPing) == "function" then
			return Stats.Network:GetPing()
		end
		return nil
	end)
	local ping = ok and normalizePingSeconds(value) or nil
	if ping then
		return ping
	end

	ok, value = pcall(function()
		local serverStats = Stats.Network and Stats.Network:FindFirstChild("ServerStatsItem")
		local dataPing = serverStats and serverStats:FindFirstChild("Data Ping")
		return dataPing and dataPing:GetValue() or nil
	end)
	return ok and normalizePingSeconds(value) or nil
end

local function pushBounded(array, headKey, countKey, value)
	local head = state[headKey]
	array[head] = value
	state[headKey] = head % MAX_LATENCY_SAMPLES + 1
	state[countKey] = math.min(state[countKey] + 1, MAX_LATENCY_SAMPLES)
end

local function copySamples(array, head, count)
	local result = table.create(count)
	if count <= 0 then
		return result
	end

	local start = count < MAX_LATENCY_SAMPLES and 1 or head
	for offset = 0, count - 1 do
		local index = (start + offset - 1) % MAX_LATENCY_SAMPLES + 1
		result[#result + 1] = array[index]
	end
	return result
end

local function percentile(array, head, count, fraction)
	local samples = copySamples(array, head, count)
	if #samples == 0 then
		return nil
	end
	table.sort(samples)
	local index = math.clamp(math.ceil(#samples * fraction), 1, #samples)
	return samples[index]
end

local function recordAttempt(giftId)
	local id = tonumber(giftId)
	if not id then
		return
	end

	local now = os.clock()
	local ping = getPingSeconds()
	local position = getPosition()
	local gift = state.GiftHandler and state.GiftHandler.Gifts and state.GiftHandler.Gifts[id]
	local giftPosition = gift and gift.Position
	local giftDistance = position and typeof(giftPosition) == "Vector3" and (giftPosition - position).Magnitude or nil
	local frame = state.RenderEpoch
	local batch = state.CurrentBatch
	if not batch or batch.Frame ~= frame then
		batch = {
			Frame = frame,
			Count = 0,
		}
		state.CurrentBatch = batch
	end
	batch.Count += 1

	if state.PendingById[id] == nil then
		state.PendingCount += 1
	end
	state.PendingById[id] = {
		At = now,
		Position = position,
		Ping = ping,
		GiftDistance = giftDistance,
		SettledFor = math.max(0, now - state.LastRootMoveAt),
		Batch = batch,
	}
	state.Attempts += 1
end

local function recordBatchOutcome(pending, accepted)
	local batchSize = pending.Batch and pending.Batch.Count or 0
	if batchSize <= 0 then
		return
	end

	local outcome = state.BatchOutcomes[batchSize]
	if not outcome then
		outcome = {
			Accepted = 0,
			Rejected = 0,
		}
		state.BatchOutcomes[batchSize] = outcome
	end
	if accepted then
		outcome.Accepted += 1
	else
		outcome.Rejected += 1
	end
end

local function recordPositionDelta(pending)
	local currentPosition = getPosition()
	if not (pending.Position and currentPosition) then
		return nil
	end

	local delta = (currentPosition - pending.Position).Magnitude
	pushBounded(state.PositionDeltas, "PositionDeltaHead", "PositionDeltaCount", delta)
	return delta
end

local function resolveAccept(giftId)
	local id = tonumber(giftId)
	if not id then
		return
	end

	local pending = state.PendingById[id]
	if not pending then
		return
	end

	state.PendingById[id] = nil
	state.PendingCount -= 1
	state.Accepted += 1
	recordBatchOutcome(pending, true)

	local latency = os.clock() - pending.At
	pushBounded(state.AckLatencies, "AckLatencyHead", "AckLatencyCount", latency)
	recordPositionDelta(pending)
	if pending.GiftDistance then
		pushBounded(
			state.AcceptedGiftDistances,
			"AcceptedGiftDistanceHead",
			"AcceptedGiftDistanceCount",
			pending.GiftDistance
		)
	end
	pushBounded(state.AcceptedSettledTimes, "AcceptedSettledTimeHead", "AcceptedSettledTimeCount", pending.SettledFor)
end

local function resolveReject(giftId, protocol)
	local id = tonumber(giftId)
	if not id or id == 0 then
		return
	end

	local pending = state.PendingById[id]
	if not pending then
		state.UnmatchedRejects += 1
		warn(string.format("[GiftTelemetry] %s reject id=%d unmatched", protocol, id))
		return
	end

	state.PendingById[id] = nil
	state.PendingCount -= 1
	state.Rejected += 1
	recordBatchOutcome(pending, false)

	local latency = os.clock() - pending.At
	pushBounded(state.FailureLatencies, "FailureLatencyHead", "FailureLatencyCount", latency)
	pushBounded(state.AckLatencies, "AckLatencyHead", "AckLatencyCount", latency)
	local delta = recordPositionDelta(pending)
	if pending.GiftDistance then
		pushBounded(
			state.RejectGiftDistances,
			"RejectGiftDistanceHead",
			"RejectGiftDistanceCount",
			pending.GiftDistance
		)
	end
	pushBounded(state.RejectSettledTimes, "RejectSettledTimeHead", "RejectSettledTimeCount", pending.SettledFor)

	warn(
		string.format(
			"[GiftTelemetry] %s reject id=%d latency=%.3fs ping=%s positionDelta=%s giftDistance=%s settledFor=%.3fs batchSize=%s",
			protocol,
			id,
			latency,
			pending.Ping and string.format("%.3fs", pending.Ping) or "n/a",
			delta and string.format("%.2f", delta) or "n/a",
			pending.GiftDistance and string.format("%.2f", pending.GiftDistance) or "n/a",
			pending.SettledFor,
			pending.Batch and tostring(pending.Batch.Count) or "n/a"
		)
	)
end

local function parseRejectedBuffer(rawBuffer)
	if typeof(rawBuffer) ~= "buffer" then
		return
	end

	local length = buffer.len(rawBuffer)
	for offset = 0, length - 2, 2 do
		local ok, giftId = pcall(buffer.readu16, rawBuffer, offset)
		if ok and giftId ~= 0 then
			resolveReject(giftId, "GiftShared.Collection")
		end
	end
end

local function expirePending(now)
	for giftId, pending in state.PendingById do
		if now - pending.At > MAX_PENDING_AGE then
			state.PendingById[giftId] = nil
			state.PendingCount -= 1
			state.TimedOut += 1
		end
	end
end

local function buildReport()
	local resolved = state.Accepted + state.Rejected
	local rejectRate = resolved > 0 and state.Rejected / resolved or 0
	local ping = getPingSeconds()
	local failureP95 = percentile(state.FailureLatencies, state.FailureLatencyHead, state.FailureLatencyCount, 0.95)
	local ackP95 = percentile(state.AckLatencies, state.AckLatencyHead, state.AckLatencyCount, 0.95)
	local positionP95 = percentile(state.PositionDeltas, state.PositionDeltaHead, state.PositionDeltaCount, 0.95)
	local acceptedDistanceP95 =
		percentile(state.AcceptedGiftDistances, state.AcceptedGiftDistanceHead, state.AcceptedGiftDistanceCount, 0.95)
	local acceptedSettledP50 =
		percentile(state.AcceptedSettledTimes, state.AcceptedSettledTimeHead, state.AcceptedSettledTimeCount, 0.5)
	local rejectDistanceP95 =
		percentile(state.RejectGiftDistances, state.RejectGiftDistanceHead, state.RejectGiftDistanceCount, 0.95)
	local rejectSettledP50 =
		percentile(state.RejectSettledTimes, state.RejectSettledTimeHead, state.RejectSettledTimeCount, 0.5)
	local validationFloor = math.max((ping or 0.08) * 1.2, ackP95 or 0)
	local batchParts = {}
	for batchSize, outcome in state.BatchOutcomes do
		local batchResolved = outcome.Accepted + outcome.Rejected
		local batchRejectRate = batchResolved > 0 and outcome.Rejected / batchResolved or 0
		batchParts[#batchParts + 1] = {
			Size = batchSize,
			Text = string.format(
				"%d:%d/%d(%.1f%%)",
				batchSize,
				outcome.Accepted,
				outcome.Rejected,
				batchRejectRate * 100
			),
		}
	end
	table.sort(batchParts, function(left, right)
		return left.Size < right.Size
	end)
	local batchOutcomeStrings = table.create(#batchParts)
	for index, part in batchParts do
		batchOutcomeStrings[index] = part.Text
	end

	return {
		Runtime = os.clock() - state.StartedAt,
		Attempts = state.Attempts,
		Accepted = state.Accepted,
		Rejected = state.Rejected,
		TimedOut = state.TimedOut,
		Pending = state.PendingCount,
		UnmatchedRejects = state.UnmatchedRejects,
		RejectRate = rejectRate,
		Ping = ping,
		AckP95 = ackP95,
		FailureP95 = failureP95,
		PositionDeltaP95 = positionP95,
		AcceptedGiftDistanceP95 = acceptedDistanceP95,
		AcceptedSettledP50 = acceptedSettledP50,
		RejectGiftDistanceP95 = rejectDistanceP95,
		RejectSettledP50 = rejectSettledP50,
		BatchOutcomes = table.concat(batchOutcomeStrings, ","),
		ObservedWaitFloor = math.clamp(validationFloor + 0.02, 0.065, 0.5),
		LegacyAccepted = state.LegacyAccepted,
		LegacyRejected = state.LegacyRejected,
		LocalCollectedSignals = state.LocalCollectedSignals,
	}
end

local function printReport()
	local report = buildReport()
	state.LastReport = report
	print(
		string.format(
			"[GiftTelemetry] runtime=%.1fs attempts=%d accepted=%d rejected=%d timedOut=%d pending=%d rejectRate=%.1f%% ping=%s ackP95=%s failP95=%s positionDeltaP95=%s acceptedGiftDistanceP95=%s acceptedSettledP50=%s rejectGiftDistanceP95=%s rejectSettledP50=%s observedWaitFloor=%.3fs batches=[%s]",
			report.Runtime,
			report.Attempts,
			report.Accepted,
			report.Rejected,
			report.TimedOut,
			report.Pending,
			report.RejectRate * 100,
			report.Ping and string.format("%.3fs", report.Ping) or "n/a",
			report.AckP95 and string.format("%.3fs", report.AckP95) or "n/a",
			report.FailureP95 and string.format("%.3fs", report.FailureP95) or "n/a",
			report.PositionDeltaP95 and string.format("%.2f", report.PositionDeltaP95) or "n/a",
			report.AcceptedGiftDistanceP95 and string.format("%.2f", report.AcceptedGiftDistanceP95) or "n/a",
			report.AcceptedSettledP50 and string.format("%.3fs", report.AcceptedSettledP50) or "n/a",
			report.RejectGiftDistanceP95 and string.format("%.2f", report.RejectGiftDistanceP95) or "n/a",
			report.RejectSettledP50 and string.format("%.3fs", report.RejectSettledP50) or "n/a",
			report.ObservedWaitFloor,
			report.BatchOutcomes
		)
	)
	return report
end

local function installCollectAckWrappers(handler)
	local classes = handler.GiftClasses
	if typeof(classes) ~= "table" then
		return 0
	end

	local installed = 0
	for _, class in classes do
		if typeof(class) == "table" and typeof(class.Collect) == "function" then
			local original = class.Collect
			local wrapper = function(gift, alternate, clientCollect, ...)
				local results = table.pack(original(gift, alternate, clientCollect, ...))
				if clientCollect ~= true then
					resolveAccept(gift and gift.Id)
				end
				return table.unpack(results, 1, results.n)
			end
			class.Collect = wrapper
			state.CollectWrappers[#state.CollectWrappers + 1] = {
				Class = class,
				Original = original,
				Wrapper = wrapper,
			}
			installed += 1
		end
	end
	return installed
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	state.Connections[#state.Connections + 1] = connection
	return connection
end

local function installNewProtocol()
	local giftShared = ReplicatedStorage:FindFirstChild("GiftShared")
	local remotes = giftShared and giftShared:FindFirstChild("Remotes")
	local collection = remotes and remotes:FindFirstChild("Collection")
	if collection and collection:IsA("RemoteEvent") then
		connect(collection.OnClientEvent, parseRejectedBuffer)
	end

	local modules = ReplicatedFirst:FindFirstChild("ClientModules")
	local giftClient = modules and modules:FindFirstChild("GiftClient")
	local handlerScript = giftClient and giftClient:FindFirstChild("GiftClientHandler")
	if not handlerScript then
		return false, "GiftClientHandler not found"
	end

	local ok, handler = pcall(require, handlerScript)
	if not ok or typeof(handler) ~= "table" then
		return false, "GiftClientHandler unavailable"
	end

	local replicationClient = handler.ReplicationClient
	if typeof(replicationClient) ~= "table" then
		local replicationScript = giftClient:FindFirstChild("ReplicationClient")
		local loaded = false
		local result = nil
		if replicationScript then
			loaded, result = pcall(require, replicationScript)
		end
		replicationClient = loaded and result or nil
	end
	if typeof(replicationClient) ~= "table" or typeof(replicationClient.SendCollect) ~= "function" then
		return false, "ReplicationClient.SendCollect unavailable"
	end

	local original = replicationClient.SendCollect
	local wrapper = function(giftId, ...)
		recordAttempt(giftId)
		return original(giftId, ...)
	end
	state.ReplicationClient = replicationClient
	state.GiftHandler = handler
	state.OriginalSendCollect = original
	state.WrappedSendCollect = wrapper
	replicationClient.SendCollect = wrapper
	local ackWrappers = installCollectAckWrappers(handler)
	return true, nil, ackWrappers
end

local function installLegacyProtocol()
	local events = ReplicatedStorage:FindFirstChild("Events")
	local accepted = events and events:FindFirstChild("GiftCollected")
	local rejected = events and events:FindFirstChild("GiftCollectFailed")
	if accepted and accepted:IsA("RemoteEvent") then
		connect(accepted.OnClientEvent, function(player, giftType, giftId)
			if player == Players.LocalPlayer then
				state.LegacyAccepted += 1
				print(
					string.format("[GiftTelemetry] legacy accept type=%s id=%s", tostring(giftType), tostring(giftId))
				)
			end
		end)
	end
	if rejected and rejected:IsA("RemoteEvent") then
		connect(rejected.OnClientEvent, function(giftType, giftId)
			state.LegacyRejected += 1
			warn(string.format("[GiftTelemetry] legacy reject type=%s id=%s", tostring(giftType), tostring(giftId)))
		end)
	end

	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementEvents = movement and movement:FindFirstChild("Events")
	local collectedGift = movementEvents and movementEvents:FindFirstChild("CollectedGift")
	if collectedGift and collectedGift:IsA("BindableEvent") then
		connect(collectedGift.Event, function()
			state.LocalCollectedSignals += 1
		end)
	end
end

local api = {}

function api.report()
	expirePending(os.clock())
	return printReport()
end

function api.reset()
	table.clear(state.PendingById)
	table.clear(state.BatchOutcomes)
	state.PendingCount = 0
	state.CurrentBatch = nil
	state.Attempts = 0
	state.Accepted = 0
	state.Rejected = 0
	state.TimedOut = 0
	state.UnmatchedRejects = 0
	state.LegacyAccepted = 0
	state.LegacyRejected = 0
	state.LocalCollectedSignals = 0
	table.clear(state.FailureLatencies)
	state.FailureLatencyHead = 1
	state.FailureLatencyCount = 0
	table.clear(state.AckLatencies)
	state.AckLatencyHead = 1
	state.AckLatencyCount = 0
	table.clear(state.PositionDeltas)
	state.PositionDeltaHead = 1
	state.PositionDeltaCount = 0
	table.clear(state.AcceptedGiftDistances)
	state.AcceptedGiftDistanceHead = 1
	state.AcceptedGiftDistanceCount = 0
	table.clear(state.AcceptedSettledTimes)
	state.AcceptedSettledTimeHead = 1
	state.AcceptedSettledTimeCount = 0
	table.clear(state.RejectGiftDistances)
	state.RejectGiftDistanceHead = 1
	state.RejectGiftDistanceCount = 0
	table.clear(state.RejectSettledTimes)
	state.RejectSettledTimeHead = 1
	state.RejectSettledTimeCount = 0
	state.StartedAt = os.clock()
	state.LastReport = nil
	print("[GiftTelemetry] counters reset")
end

function api.stop()
	if not state.Running then
		return
	end
	state.Running = false

	for _, connection in state.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(state.Connections)

	if
		state.ReplicationClient
		and state.ReplicationClient.SendCollect == state.WrappedSendCollect
		and state.OriginalSendCollect
	then
		state.ReplicationClient.SendCollect = state.OriginalSendCollect
	end
	for _, entry in state.CollectWrappers do
		if entry.Class.Collect == entry.Wrapper then
			entry.Class.Collect = entry.Original
		end
	end
	table.clear(state.CollectWrappers)

	table.clear(state.PendingById)
	table.clear(state.BatchOutcomes)
	state.PendingCount = 0
	if env.NULLSCAPE_GiftTelemetryProbe == api then
		env.NULLSCAPE_GiftTelemetryProbe = nil
	end
	print("[GiftTelemetry] stopped and restored")
end

api.state = state
env.NULLSCAPE_GiftTelemetryProbe = api

connect(RunService.RenderStepped, function()
	state.RenderEpoch += 1
	state.CurrentBatch = nil
end)

local function bindRootTracking(character)
	local root = character
		and (character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5))
	if not root then
		return
	end
	if state.RootConnection then
		state.RootConnection:Disconnect()
		state.RootConnection = nil
	end
	state.LastRootPosition = root.Position
	state.LastRootMoveAt = os.clock()
	state.RootConnection = connect(root:GetPropertyChangedSignal("CFrame"), function()
		local position = root.Position
		local previousPosition = state.LastRootPosition
		if not previousPosition or (position - previousPosition).Magnitude >= 0.5 then
			state.LastRootPosition = position
			state.LastRootMoveAt = os.clock()
		end
	end)
end

connect(Players.LocalPlayer.CharacterAdded, bindRootTracking)
bindRootTracking(Players.LocalPlayer.Character)

local newProtocolOk, newProtocolError, ackWrapperCount = installNewProtocol()
installLegacyProtocol()

task.spawn(function()
	local lastReportAt = os.clock()
	while state.Running do
		task.wait(SETTLE_SCAN_INTERVAL)
		local now = os.clock()
		expirePending(now)
		if now - lastReportAt >= REPORT_INTERVAL then
			lastReportAt = now
			printReport()
		end
	end
end)

if newProtocolOk then
	print(
		string.format(
			"[GiftTelemetry] armed: native GiftShared attempts, success ACKs, and rejects (%d class wrappers)",
			ackWrapperCount or 0
		)
	)
else
	warn("[GiftTelemetry] new protocol unavailable: " .. tostring(newProtocolError))
end
print(
	"[GiftTelemetry] no position ACK remote exists in the inspected client protocol; positionDelta is correlation only"
)

return api
