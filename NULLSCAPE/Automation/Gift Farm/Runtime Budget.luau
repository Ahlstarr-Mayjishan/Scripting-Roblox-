--!nocheck
-- [[
--  Device-aware CPU budgets shared by Gift Farm workers.
--  Mobile uses smaller work slices and shorter routes to avoid frame spikes.
-- ]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local isMobile = UserInputService.TouchEnabled
	and not (UserInputService.KeyboardEnabled and UserInputService.MouseEnabled)

local function getLevel()
	local level = ReplicatedStorage:FindFirstChild("Level")
	return tonumber(level and level.Value) or 0
end

local function isHighLoad(candidateCount)
	return isMobile and (getLevel() >= 50 or (tonumber(candidateCount) or 0) >= 1800)
end

local Budget = {
	IsMobile = isMobile,
	Coordinator = {
		LoopInterval = isMobile and 0.08 or 0.04,
		StatusUpdateInterval = isMobile and 0.25 or 0.15,
		GoldenPreemptInterval = isMobile and 0.1 or 0.03,
	},
	Scanner = {
		SafetyInterval = isMobile and 1 or 0.65,
		FrameBudget = isMobile and 0.00125 or 0.003,
		CheckInterval = isMobile and 24 or 48,
		FannyPackCacheInterval = isMobile and 0.8 or 0.4,
	},
	Planner = {
		FrameBudget = isMobile and 0.00125 or 0.003,
		CheckInterval = isMobile and 24 or 64,
		MaxRoutePoints = isMobile and 16 or 36,
		MaxTailRoutePoints = isMobile and 8 or 32,
		MaxRefinedCenters = isMobile and 4 or 6,
		HighLoadMaxRoutePoints = 10,
		HighLoadMaxTailRoutePoints = 4,
		HighLoadMaxRefinedCenters = 3,
	},
	Collector = {
		CleanupPulseInterval = isMobile and 0.03 or 0.015,
		PrecisionCleanupMaxPulses = isMobile and 4 or 6,
		TailCleanupMaxPulses = isMobile and 6 or 10,
		CollectBatchSize = isMobile and 8 or nil,
		HighLoadCollectBatchSize = 5,
	},
	Pipeline = {
		ControllerUpdateInterval = isMobile and 0.12 or 0,
		ProgressUpdateInterval = isMobile and 0.15 or 0,
		MaxWindow = isMobile and 6 or 8,
		HighLoadMaxWindow = 3,
	},
	Telemetry = {
		ObserveInterval = isMobile and 0.4 or 0.1,
	},
	AutoChoice = {
		LoopInterval = isMobile and 0.18 or 0.12,
		IdleLoopInterval = isMobile and 0.5 or 0.35,
	},
}

function Budget.getPlannerRouteLimit(tailCleanup, candidateCount)
	if isHighLoad(candidateCount) then
		return tailCleanup and Budget.Planner.HighLoadMaxTailRoutePoints or Budget.Planner.HighLoadMaxRoutePoints
	end
	return tailCleanup and Budget.Planner.MaxTailRoutePoints or Budget.Planner.MaxRoutePoints
end

function Budget.getMaxRefinedCenters(candidateCount)
	if isHighLoad(candidateCount) then
		return Budget.Planner.HighLoadMaxRefinedCenters
	end
	return Budget.Planner.MaxRefinedCenters
end

function Budget.getCollectBatchSize(clusterSize)
	if not isMobile then
		return nil
	end
	if isHighLoad(clusterSize) then
		return Budget.Collector.HighLoadCollectBatchSize
	end
	return Budget.Collector.CollectBatchSize
end

function Budget.getPipelineWindowCap(candidateCount)
	if isHighLoad(candidateCount) then
		return Budget.Pipeline.HighLoadMaxWindow
	end
	return Budget.Pipeline.MaxWindow
end

function Budget.shouldAppendTailRoute(route, candidateCount)
	return not isMobile or #(route or {}) < Budget.getPlannerRouteLimit(false, candidateCount)
end

return Budget
