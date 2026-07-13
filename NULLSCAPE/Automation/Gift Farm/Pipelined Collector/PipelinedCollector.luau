--!nocheck
-- [[
--  NULLSCAPE - Pipelined Collector Submodule
--  Runs a route through the shared, server-validated collector.
-- ]]

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Collector = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Collector.luau")

local PipelinedCollector = {}
local pipelineToken = 0

local function isAborted(options)
	return options and typeof(options.AbortCheck) == "function" and options.AbortCheck() == true
end

function PipelinedCollector.cancelPending()
	pipelineToken += 1
end

function PipelinedCollector.resetAdaptive()
	-- Collector owns the shared adaptive network timing for both farm modes.
end

function PipelinedCollector.collectRoute(_controller, hrp, route, range, options, lease, _currentSessionToken)
	if not (hrp and hrp.Parent and route and route[1]) then
		return false
	end

	options = options or {}
	pipelineToken += 1
	local routeToken = pipelineToken
	local stats = {
		Attempted = 0,
		Accepted = 0,
		Failed = 0,
	}
	
	local function shouldAbort()
		return routeToken ~= pipelineToken
			or not lease:isValid()
			or Context.getRootPart() ~= hrp
			or isAborted(options)
	end

	local ok, err = pcall(function()
		for _, step in ipairs(route) do
			if shouldAbort() then
				return
			end

			local cluster = step.Cluster or {}
			if #cluster == 0 then
				continue
			end

			local planInfo = step.Info
			local tailMode = planInfo and planInfo.TailCleanup == true
			local result = Collector.collectCluster(_controller, hrp, cluster, range, {
				SafeRange = planInfo and planInfo.SafeRange,
				TargetPosition = planInfo and planInfo.TargetPosition,
				PrecisionMode = tailMode,
				TailMode = tailMode,
				NormalPacingBatchSize = options.NormalPacingBatchSize,
				AbortCheck = shouldAbort,
			}, lease, _currentSessionToken)
			if result then
				stats.Attempted += tonumber(result.Attempted) or 0
				stats.Accepted += tonumber(result.Accepted) or 0
				stats.Failed += tonumber(result.Rejected) or 0
			end
			if shouldAbort() then
				return
			end
		end
	end)

	if not ok then
		error(err, 0)
	end

	if shouldAbort() then
		return false, stats
	end

	return true, stats
end

return PipelinedCollector
