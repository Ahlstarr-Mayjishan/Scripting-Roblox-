--!nocheck
--[[
	NULLSCAPE - Gift Farm Network Dispatch
	Owns native collect tracking and one-way cluster dispatch for pipeline mode.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Distance = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Distance.luau")

local NetworkDispatch = {}

local ARRIVAL_TIMEOUT = 0.24
local ARRIVAL_TOLERANCE = 3
local POSITION_SYNC_MIN = 0.065
local POSITION_SYNC_MAX = 0.45
local POSITION_SYNC_MARGIN = 0.015

local tracking = false
local manualCollectDepth = 0
local comboCount = 0
local lastCollectTick = 0
local pendingById = {}
local wrappers = {}
local rejectConnection = nil

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

function NetworkDispatch.getPingSeconds()
	local ok, result = pcall(function()
		if Stats.Network and typeof(Stats.Network.GetPing) == "function" then
			return Stats.Network:GetPing()
		end
		return nil
	end)
	local ping = ok and normalizePingSeconds(result) or nil
	if ping then
		return ping
	end

	ok, result = pcall(function()
		local serverStats = Stats.Network and Stats.Network:FindFirstChild("ServerStatsItem")
		local dataPing = serverStats and serverStats:FindFirstChild("Data Ping")
		return dataPing and dataPing:GetValue() or nil
	end)
	return ok and normalizePingSeconds(result) or nil
end

local function clearVelocity(hrp)
	if not (hrp and hrp.Parent) then
		return
	end
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
end

local function isAborted(options, lease)
	if not (lease and lease:isValid()) then
		return true
	end
	return options and typeof(options.AbortCheck) == "function" and options.AbortCheck() == true
end

local function resolveRecord(record, status)
	if not record or record.Status ~= "Pending" then
		return
	end
	record.Status = status
	record.ResolvedAt = os.clock()
	local ticket = record.Ticket
	if ticket then
		ticket.Remaining = math.max(0, (ticket.Remaining or 1) - 1)
	end
	pendingById[record.Id] = nil
end

local function resolveGift(gift, status)
	local id = gift and tonumber(gift.Id)
	local record = id and pendingById[id] or nil
	if record then
		resolveRecord(record, status)
	end
end

local function parseRejectBuffer(rawBuffer)
	if typeof(rawBuffer) ~= "buffer" then
		return
	end
	local length = buffer.len(rawBuffer)
	for offset = 0, length - 2, 2 do
		local ok, giftId = pcall(buffer.readu16, rawBuffer, offset)
		if ok then
			resolveRecord(pendingById[giftId], "Rejected")
		end
	end
end

local function installTracking()
	if tracking then
		return true
	end

	local handler = Context.getGiftClientHandler()
	local classes = handler and handler.GiftClasses
	if typeof(classes) ~= "table" then
		return false
	end

	tracking = true
	for _, class in pairs(classes) do
		local original = typeof(class) == "table" and rawget(class, "Collect") or nil
		if typeof(original) == "function" then
			local wrapper = function(gift, alternate, clientCollect, ...)
				if clientCollect == true and manualCollectDepth <= 0 then
					return
				end
				local results = table.pack(original(gift, alternate, clientCollect, ...))
				if clientCollect ~= true then
					resolveGift(gift, "Accepted")
				end
				return table.unpack(results, 1, results.n)
			end
			class.Collect = wrapper
			wrappers[#wrappers + 1] = {
				Class = class,
				Original = original,
				Wrapper = wrapper,
			}
		end
	end

	local giftShared = ReplicatedStorage:FindFirstChild("GiftShared")
	local remotes = giftShared and giftShared:FindFirstChild("Remotes")
	local collection = remotes and remotes:FindFirstChild("Collection")
	if collection and collection:IsA("RemoteEvent") then
		rejectConnection = collection.OnClientEvent:Connect(parseRejectBuffer)
	end
	return true
end

function NetworkDispatch.beginTracking()
	return installTracking()
end

function NetworkDispatch.stopTracking()
	tracking = false
	if rejectConnection then
		rejectConnection:Disconnect()
		rejectConnection = nil
	end
	for index = #wrappers, 1, -1 do
		local entry = wrappers[index]
		if entry.Class.Collect == entry.Wrapper then
			entry.Class.Collect = entry.Original
		end
	end
	table.clear(wrappers)
	for _, record in pairs(pendingById) do
		resolveRecord(record, "Cancelled")
	end
	table.clear(pendingById)
end

local function waitForArrival(hrp, targetPosition, options, lease)
	local startedAt = os.clock()
	while os.clock() - startedAt <= ARRIVAL_TIMEOUT do
		if isAborted(options, lease) or not (hrp and hrp.Parent) then
			return false
		end
		clearVelocity(hrp)
		if (hrp.Position - targetPosition).Magnitude <= ARRIVAL_TOLERANCE then
			return true
		end
		lease:moveCollectTo(CFrame.new(targetPosition))
		RunService.Heartbeat:Wait()
	end
	return hrp and hrp.Parent and (hrp.Position - targetPosition).Magnitude <= ARRIVAL_TOLERANCE
end

local function waitForServerPosition()
	local ping = NetworkDispatch.getPingSeconds() or 0.08
	local waitTime = math.clamp(ping * 1.15 + POSITION_SYNC_MARGIN, POSITION_SYNC_MIN, POSITION_SYNC_MAX)
	local startedAt = os.clock()
	RunService.Heartbeat:Wait()
	local remaining = waitTime - (os.clock() - startedAt)
	if remaining > 0 then
		task.wait(remaining)
	end
end

local function nextCombo()
	local now = tick()
	if math.min(1.2, math.pow(1.1, comboCount) * 0.8) <= now - lastCollectTick then
		comboCount = 0
	end
	comboCount += 1
	lastCollectTick = now
	return comboCount
end

local function dispatchGift(ticket, item, collectedEvent)
	local gift = item and item.rawObj
	local id = gift and tonumber(gift.Id)
	if not id or gift.Destroyed or gift.Collected then
		return false
	end

	local record = {
		Id = id,
		Gift = gift,
		Item = item,
		Ticket = ticket,
		Status = "Pending",
		SentAt = os.clock(),
	}
	pendingById[id] = record
	ticket.Records[#ticket.Records + 1] = record
	ticket.Remaining += 1

	manualCollectDepth += 1
	local success = pcall(function()
		gift:Collect(false, true, nextCombo())
	end)
	manualCollectDepth -= 1
	if not success then
		pendingById[id] = nil
		record.Status = "DispatchFailed"
		ticket.Remaining -= 1
		return false
	end

	if collectedEvent then
		pcall(function()
			collectedEvent:Fire()
		end)
	end
	return true
end

local function waitForNativeFlush()
	RunService.RenderStepped:Wait()
	RunService.Heartbeat:Wait()
end

function NetworkDispatch.dispatchCluster(hrp, cluster, range, options, lease)
	if not tracking or not (hrp and hrp.Parent and cluster and cluster[1]) then
		return nil
	end
	options = options or {}
	local targetPosition = options.TargetPosition or cluster.TargetPosition or cluster[1].pos
	local safeRange = options.SafeRange or cluster.SafeRange or range
	local collectRange = safeRange + 3
	local standingPosition = Distance.getRootPosition(targetPosition)
	if Context.isInRound() then
		Context.waitForStreamedGround(standingPosition, 0.02)
	end
	if isAborted(options, lease) then
		return nil
	end

	hrp.Anchored = false
	lease:placeFoothold(standingPosition)
	if lease:moveCollectTo(CFrame.new(standingPosition)) == false then
		return nil
	end
	clearVelocity(hrp)
	if not waitForArrival(hrp, standingPosition, options, lease) then
		return nil
	end
	waitForServerPosition()
	if isAborted(options, lease) then
		return nil
	end

	local ticket = {
		Cluster = cluster,
		Records = {},
		Remaining = 0,
		StandingPosition = standingPosition,
		TargetPosition = targetPosition,
		SafeRange = safeRange,
		CollectRange = collectRange,
		DispatchedAt = os.clock(),
	}
	local collectedEvent = Context.getCollectedGiftEvent()
	local dispatched = 0
	for _, item in ipairs(cluster) do
		if isAborted(options, lease) then
			break
		end
		local livePosition = Context.getCandidatePosition(item)
		if livePosition and Distance.isWithinRange(livePosition, hrp.Position, collectRange) then
			if dispatchGift(ticket, item, collectedEvent) then
				dispatched += 1
			end
			local batchSize = tonumber(options.PacingBatchSize)
			if batchSize and dispatched > 0 and dispatched % batchSize == 0 then
				RunService.Heartbeat:Wait()
			end
		end
	end
	if dispatched > 0 then
		waitForNativeFlush()
	end
	ticket.Attempted = dispatched
	ticket.FlushedAt = os.clock()
	return ticket
end

function NetworkDispatch.settle(ticket, timeout, abortCheck)
	if not ticket then
		return nil
	end
	local deadline = (ticket.FlushedAt or os.clock()) + math.max(0.05, tonumber(timeout) or 0.25)
	while ticket.Remaining > 0 and os.clock() < deadline do
		if typeof(abortCheck) == "function" and abortCheck() == true then
			break
		end
		RunService.Heartbeat:Wait()
	end

	local result = {
		Attempted = ticket.Attempted or #ticket.Records,
		Accepted = 0,
		Rejected = 0,
		Unresolved = 0,
		RejectedItems = {},
		Latency = 0,
	}
	local settledAt = os.clock()
	for _, record in ipairs(ticket.Records) do
		local gift = record.Gift
		result.Latency = math.max(
			result.Latency,
			math.max(0, (record.ResolvedAt or settledAt) - (record.SentAt or ticket.DispatchedAt or settledAt))
		)
		local confirmed = record.Status == "Accepted"
		local speculative = record.Status == "Pending" and gift and (gift.Destroyed == true or gift.Collected == true)
		local accepted = confirmed or speculative
		if accepted then
			result.Accepted += 1
			if speculative then
				result.Unresolved += 1
			end
		else
			result.Rejected += 1
			result.RejectedItems[#result.RejectedItems + 1] = record.Item
		end
		if pendingById[record.Id] == record then
			pendingById[record.Id] = nil
		end
	end
	return result
end

return NetworkDispatch
