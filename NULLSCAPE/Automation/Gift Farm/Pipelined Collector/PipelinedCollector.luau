--!nocheck
--[[
	NULLSCAPE - Pipelined Network Collector
	Overlaps native ACK latency with movement while preserving precision barriers.
]]

local Collector = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Collector.luau")
local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local NetworkDispatch = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Pipelined Collector/NetworkDispatch.luau")
local RuntimeBudget = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Runtime Budget.luau")

local PipelinedCollector = {}

local MIN_WINDOW = 1
local INITIAL_WINDOW = 3
local CLEAN_TICKETS_TO_GROW = 2
local MIN_ACK_TIMEOUT = 0.18
local MAX_ACK_TIMEOUT = 0.7

local pipelineToken = 0
local adaptiveWindow = INITIAL_WINDOW
local cleanTickets = 0
local latencyEstimate = 0.12

local function isAborted(options)
	return options and typeof(options.AbortCheck) == "function" and options.AbortCheck() == true
end

local function getAckTimeout()
	local ping = NetworkDispatch.getPingSeconds() or 0.08
	return math.clamp(math.max(latencyEstimate * 1.5, ping * 2.8 + 0.08), MIN_ACK_TIMEOUT, MAX_ACK_TIMEOUT)
end

local function isPrecisionBarrier(step)
	local info = step and step.Info
	local score = info and info.Score
	if info and info.TailCleanup == true then
		return true, "tail"
	end
	if score and (tonumber(score.CollapseCount) or 0) > 0 then
		return true, "collapse"
	end
	for _, item in ipairs(step and step.Cluster or {}) do
		local gift = item.rawObj
		if item.passage == true or (gift and gift.Type == "PassageGift") then
			return true, "passage"
		end
	end
	return false, nil
end

local function updateController(controller, inFlight, stats)
	if not controller then
		return
	end
	controller.GiftFarmPipelineWindow = adaptiveWindow
	controller.GiftFarmPipelineInFlight = inFlight
	controller.GiftFarmPipelineDispatched = stats.Dispatched or stats.Attempted
	controller.GiftFarmPipelineAccepted = stats.Accepted
	controller.GiftFarmPipelineUnresolved = stats.Unresolved
	controller.GiftFarmPipelineTransientRejects = stats.TransientRejected
	controller.GiftFarmPipelineRejected = stats.Failed
	controller.GiftFarmPipelineRetries = stats.Retried
	controller.GiftFarmPipelineAckLatency = latencyEstimate
end

local function adaptFromSettlement(result, windowCap)
	local attempted = math.max(0, tonumber(result and result.Attempted) or 0)
	local rejected = math.clamp(tonumber(result and result.Rejected) or 0, 0, attempted)
	local unresolved = math.clamp(tonumber(result and result.Unresolved) or 0, 0, attempted)
	local latency = tonumber(result and result.Latency)
	if latency and latency > 0 then
		latencyEstimate = latencyEstimate * 0.75 + latency * 0.25
	end
	if attempted <= 0 then
		return
	end
	if rejected > 0 then
		cleanTickets = 0
		adaptiveWindow = math.max(MIN_WINDOW, math.floor(adaptiveWindow * 0.5))
		return
	end
	if unresolved > 0 then
		cleanTickets = 0
		adaptiveWindow = math.max(MIN_WINDOW, adaptiveWindow - 1)
		return
	end
	cleanTickets += 1
	if cleanTickets >= CLEAN_TICKETS_TO_GROW then
		cleanTickets = 0
		adaptiveWindow = math.min(windowCap, adaptiveWindow + 1)
	end
end

local function mergeCollectorResult(stats, result)
	if not result then
		return
	end
	stats.Attempted += tonumber(result.Attempted) or 0
	stats.Accepted += tonumber(result.Accepted) or 0
	stats.Failed += tonumber(result.Rejected) or 0
end

function PipelinedCollector.cancelPending(controller)
	pipelineToken += 1
	NetworkDispatch.stopTracking()
	if controller then
		controller.GiftFarmPipelineInFlight = 0
	end
end

function PipelinedCollector.resetAdaptive(controller)
	adaptiveWindow = INITIAL_WINDOW
	cleanTickets = 0
	latencyEstimate = 0.12
	if controller then
		controller.GiftFarmPipelineWindow = adaptiveWindow
		controller.GiftFarmPipelineInFlight = 0
		controller.GiftFarmPipelineDispatched = 0
		controller.GiftFarmPipelineAccepted = 0
		controller.GiftFarmPipelineUnresolved = 0
		controller.GiftFarmPipelineTransientRejects = 0
		controller.GiftFarmPipelineRejected = 0
		controller.GiftFarmPipelineRetries = 0
		controller.GiftFarmPipelineAckLatency = latencyEstimate
	end
end

function PipelinedCollector.collectRoute(controller, hrp, route, range, options, lease, _currentSessionToken)
	if not (hrp and hrp.Parent and route and route[1]) then
		return false
	end

	options = options or {}
	pipelineToken += 1
	local routeToken = pipelineToken
	local inFlight = {}
	local retryQueue = {}
	local routeGiftCount = 0
	for _, step in ipairs(route) do
		routeGiftCount += #(step.Cluster or {})
	end
	local windowCap = RuntimeBudget.getPipelineWindowCap(routeGiftCount)
	adaptiveWindow = math.min(adaptiveWindow, windowCap)
	local stats = {
		Dispatched = 0,
		Attempted = 0,
		Accepted = 0,
		Failed = 0,
		Unresolved = 0,
		TransientRejected = 0,
		Retried = 0,
		Barriers = 0,
	}
	local routeIndex = 0
	local lastControllerUpdateAt = -math.huge
	local lastProgressUpdateAt = -math.huge

	local function publishController(force)
		local now = os.clock()
		local interval = RuntimeBudget.Pipeline.ControllerUpdateInterval
		if not force and interval > 0 and now - lastControllerUpdateAt < interval then
			return
		end
		lastControllerUpdateAt = now
		updateController(controller, #inFlight, stats)
	end

	local function reportProgress(stage)
		if typeof(options.ProgressCallback) ~= "function" then
			return
		end
		local now = os.clock()
		local interval = RuntimeBudget.Pipeline.ProgressUpdateInterval
		if stage ~= "draining" and interval > 0 and now - lastProgressUpdateAt < interval then
			return
		end
		lastProgressUpdateAt = now
		pcall(options.ProgressCallback, {
			Stage = stage,
			Index = routeIndex,
			Total = #route,
			InFlight = #inFlight,
			Window = adaptiveWindow,
			Dispatched = stats.Dispatched,
			Accepted = stats.Accepted,
			Rejected = stats.TransientRejected,
		})
	end

	local function shouldAbort()
		return routeToken ~= pipelineToken or not lease:isValid() or Context.getRootPart() ~= hrp or isAborted(options)
	end

	local function settleOldest()
		local ticket = table.remove(inFlight, 1)
		if not ticket then
			return true
		end
		local result = NetworkDispatch.settle(ticket, getAckTimeout(), shouldAbort)
		if not result then
			return false
		end
		stats.Attempted += tonumber(result.Attempted) or 0
		stats.Accepted += tonumber(result.Accepted) or 0
		stats.Unresolved += tonumber(result.Unresolved) or 0
		stats.TransientRejected += tonumber(result.Rejected) or 0
		if result.RejectedItems and #result.RejectedItems > 0 then
			retryQueue[#retryQueue + 1] = {
				Items = result.RejectedItems,
				Ticket = ticket,
			}
		end
		adaptFromSettlement(result, windowCap)
		if lease and typeof(lease.reportCollectResult) == "function" and result.Attempted > 0 then
			lease:reportCollectResult(result.Attempted, result.Rejected)
		end
		publishController(false)
		reportProgress("settling")
		return true
	end

	local function drainPipeline()
		while #inFlight > 0 do
			if not settleOldest() then
				return false
			end
		end
		return true
	end

	local function collectBarrier(step, reason)
		reportProgress("precision barrier")
		if not drainPipeline() then
			return false
		end
		NetworkDispatch.stopTracking()
		local info = step.Info
		local tailMode = reason == "tail" or reason == "passage"
		local result = Collector.collectCluster(controller, hrp, step.Cluster, range, {
			SafeRange = info and info.SafeRange,
			TargetPosition = info and info.TargetPosition,
			PrecisionMode = true,
			TailMode = tailMode,
			NormalPacingBatchSize = options.NormalPacingBatchSize,
			AbortCheck = shouldAbort,
		}, lease, _currentSessionToken)
		mergeCollectorResult(stats, result)
		stats.Barriers += 1
		if shouldAbort() then
			return false
		end
		return NetworkDispatch.beginTracking()
	end

	local ok, err = xpcall(function()
		if not NetworkDispatch.beginTracking() then
			error("native gift tracking unavailable")
		end
		for index, step in ipairs(route) do
			routeIndex = index
			if shouldAbort() then
				return
			end
			local cluster = step.Cluster or {}
			if #cluster == 0 then
				continue
			end

			local barrier, reason = isPrecisionBarrier(step)
			if barrier then
				if not collectBarrier(step, reason) then
					return
				end
			else
				while #inFlight >= adaptiveWindow do
					if shouldAbort() or not settleOldest() then
						return
					end
				end
				local info = step.Info
				local ticket = NetworkDispatch.dispatchCluster(hrp, cluster, range, {
					SafeRange = info and info.SafeRange,
					TargetPosition = info and info.TargetPosition,
					AbortCheck = shouldAbort,
				}, lease)
				if ticket and ticket.Attempted > 0 then
					inFlight[#inFlight + 1] = ticket
					stats.Dispatched += ticket.Attempted
				end
				publishController(false)
				reportProgress("streaming")
			end
		end

		reportProgress("draining")
		if not drainPipeline() or shouldAbort() then
			return
		end
		NetworkDispatch.stopTracking()

		for _, retry in ipairs(retryQueue) do
			if shouldAbort() then
				return
			end
			local ticket = retry.Ticket
			local result = Collector.collectCluster(controller, hrp, retry.Items, range, {
				SafeRange = ticket.SafeRange,
				TargetPosition = ticket.TargetPosition,
				PrecisionMode = true,
				TailMode = false,
				AbortCheck = shouldAbort,
			}, lease, _currentSessionToken)
			stats.Retried += #retry.Items
			mergeCollectorResult(stats, result)
		end
	end, debug.traceback)

	NetworkDispatch.stopTracking()
	updateController(controller, 0, stats)
	if not ok then
		error(err, 0)
	end
	if shouldAbort() then
		return false, stats
	end
	return true, stats
end

return PipelinedCollector
