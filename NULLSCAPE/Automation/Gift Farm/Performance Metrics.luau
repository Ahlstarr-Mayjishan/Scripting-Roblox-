--!nocheck

local Metrics = {}

local function createState()
	return {
		Planner = {
			Calls = 0,
			WallSeconds = 0,
			MaxWallSeconds = 0,
			CandidatePeak = 0,
			RoutePeak = 0,
			PlannedGiftPeak = 0,
		},
		Collector = {
			Calls = 0,
			WallSeconds = 0,
			MaxWallSeconds = 0,
			Attempted = 0,
			Accepted = 0,
			Failed = 0,
			Unresolved = 0,
			TransientRejected = 0,
			Retried = 0,
			Dispatched = 0,
		},
	}
end

local state = createState()

local function number(value)
	return math.max(0, tonumber(value) or 0)
end

local function rounded(value)
	return math.floor(number(value) * 1000000 + 0.5) / 1000000
end

function Metrics.reset()
	state = createState()
end

function Metrics.recordPlan(duration, candidateCount, routeCount, plannedGiftCount)
	local planner = state.Planner
	local elapsed = number(duration)
	planner.Calls += 1
	planner.WallSeconds += elapsed
	planner.MaxWallSeconds = math.max(planner.MaxWallSeconds, elapsed)
	planner.CandidatePeak = math.max(planner.CandidatePeak, number(candidateCount))
	planner.RoutePeak = math.max(planner.RoutePeak, number(routeCount))
	planner.PlannedGiftPeak = math.max(planner.PlannedGiftPeak, number(plannedGiftCount))
end

function Metrics.recordCollection(duration, routeStats)
	local collector = state.Collector
	local elapsed = number(duration)
	local stats = typeof(routeStats) == "table" and routeStats or {}
	collector.Calls += 1
	collector.WallSeconds += elapsed
	collector.MaxWallSeconds = math.max(collector.MaxWallSeconds, elapsed)
	collector.Attempted += number(stats.Attempted)
	collector.Accepted += number(stats.Accepted)
	collector.Failed += number(stats.Failed)
	collector.Unresolved += number(stats.Unresolved)
	collector.TransientRejected += number(stats.TransientRejected)
	collector.Retried += number(stats.Retried)
	collector.Dispatched += number(stats.Dispatched)
end

function Metrics.snapshot(scannerStats)
	local scanner = typeof(scannerStats) == "table" and scannerStats or {}
	local planner = table.clone(state.Planner)
	local collector = table.clone(state.Collector)
	planner.WallSeconds = rounded(planner.WallSeconds)
	planner.MaxWallSeconds = rounded(planner.MaxWallSeconds)
	collector.WallSeconds = rounded(collector.WallSeconds)
	collector.MaxWallSeconds = rounded(collector.MaxWallSeconds)

	local scans = number(scanner.Scans)
	local cacheHits = number(scanner.CacheHits)
	return {
		Scanner = {
			Calls = scans + cacheHits,
			FullScans = scans,
			CacheHits = cacheHits,
			WallSeconds = rounded(scanner.TotalDuration),
			MaxWallSeconds = rounded(scanner.MaxDuration),
			LastGiftCount = number(scanner.LastGiftCount),
		},
		Planner = planner,
		Collector = collector,
	}
end

return Metrics
