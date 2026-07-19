--!nocheck
-- [[
--  Device-aware CPU budgets shared by Gift Farm workers.
--  Mobile uses smaller work slices and shorter routes to avoid frame spikes.
-- ]]

local UserInputService = game:GetService("UserInputService")

local isMobile = UserInputService.TouchEnabled
	and not (UserInputService.KeyboardEnabled and UserInputService.MouseEnabled)

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
	},
	Collector = {
		CleanupPulseInterval = isMobile and 0.03 or 0.015,
		PrecisionCleanupMaxPulses = isMobile and 4 or 6,
		TailCleanupMaxPulses = isMobile and 6 or 10,
	},
	Pipeline = {
		ControllerUpdateInterval = isMobile and 0.12 or 0,
		ProgressUpdateInterval = isMobile and 0.15 or 0,
	},
	Telemetry = {
		ObserveInterval = isMobile and 0.4 or 0.1,
	},
	AutoChoice = {
		LoopInterval = isMobile and 0.18 or 0.12,
		IdleLoopInterval = isMobile and 0.5 or 0.35,
	},
}

function Budget.shouldAppendTailRoute(route)
	return not isMobile or #(route or {}) < Budget.Planner.MaxRoutePoints
end

return Budget
