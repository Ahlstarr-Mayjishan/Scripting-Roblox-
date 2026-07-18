--!nocheck
--[[
	NULLSCAPE - Grappler Performance Budget
	Keeps expensive map scans and target probes proportional to the current device load.
]]

local UserInputService = game:GetService("UserInputService")

local Budget = {
	FrameAverage = 1 / 60,
	LastRun = setmetatable({}, { __mode = "k" }),
}

local PROFILES = {
	Emergency = {
		CandidateLimit = 42,
		TerrainCacheLimit = 180,
		CandidateCacheTTL = 3,
		AnchorScanBudget = 150,
		TrajectorySamples = 3,
	},
	EmergencyConstrained = {
		CandidateLimit = 30,
		TerrainCacheLimit = 120,
		CandidateCacheTTL = 5,
		AnchorScanBudget = 90,
		TrajectorySamples = 2,
	},
	Stressed = {
		CandidateLimit = 14,
		TerrainCacheLimit = 90,
		CandidateCacheTTL = 7,
		AnchorScanBudget = 60,
		TrajectorySamples = 1,
	},
	Constrained = {
		CandidateLimit = 22,
		TerrainCacheLimit = 140,
		CandidateCacheTTL = 5,
		AnchorScanBudget = 100,
		TrajectorySamples = 2,
	},
	Normal = {
		CandidateLimit = 40,
		TerrainCacheLimit = 220,
		CandidateCacheTTL = 3,
		AnchorScanBudget = 180,
		TrajectorySamples = 3,
	},
}

local function isMobile()
	return UserInputService.TouchEnabled
end

function Budget.observeFrame(dt)
	if type(dt) ~= "number" or dt <= 0 or dt > 0.5 then
		return
	end

	Budget.FrameAverage = Budget.FrameAverage * 0.9 + dt * 0.1
end

function Budget.get(urgency)
	local frameAverage = Budget.FrameAverage
	local constrained = isMobile() or frameAverage > 1 / 42
	local stressed = frameAverage > 1 / 28

	if urgency == "Emergency" then
		return constrained and PROFILES.EmergencyConstrained or PROFILES.Emergency
	end

	if stressed then
		return PROFILES.Stressed
	end

	if constrained then
		return PROFILES.Constrained
	end

	return PROFILES.Normal
end

function Budget.shouldRun(grapple, name, interval)
	if not grapple then
		return false
	end

	local now = time()
	local runs = Budget.LastRun[grapple]
	if not runs then
		runs = {}
		Budget.LastRun[grapple] = runs
	end

	if now - (runs[name] or -1000) < (tonumber(interval) or 0) then
		return false
	end

	runs[name] = now
	return true
end

function Budget.reset(grapple)
	if grapple then
		Budget.LastRun[grapple] = nil
	else
		table.clear(Budget.LastRun)
	end
end

return Budget
