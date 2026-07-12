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
		return {
			CandidateLimit = constrained and 30 or 42,
			TerrainCacheLimit = constrained and 120 or 180,
			CandidateCacheTTL = constrained and 5 or 3,
			AnchorScanBudget = constrained and 90 or 150,
			TrajectorySamples = constrained and 2 or 3,
		}
	end

	if stressed then
		return {
			CandidateLimit = 14,
			TerrainCacheLimit = 90,
			CandidateCacheTTL = 7,
			AnchorScanBudget = 60,
			TrajectorySamples = 1,
		}
	end

	if constrained then
		return {
			CandidateLimit = 22,
			TerrainCacheLimit = 140,
			CandidateCacheTTL = 5,
			AnchorScanBudget = 100,
			TrajectorySamples = 2,
		}
	end

	return {
		CandidateLimit = 40,
		TerrainCacheLimit = 220,
		CandidateCacheTTL = 3,
		AnchorScanBudget = 180,
		TrajectorySamples = 3,
	}
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
