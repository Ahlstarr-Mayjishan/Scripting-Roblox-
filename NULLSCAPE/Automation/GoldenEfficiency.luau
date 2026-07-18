--!strict

local GoldenEfficiency = {}

export type Evaluation = {
	ConfiguredPercent: number,
	TargetPercent: number,
	TargetRatio: number,
	ProgressRatio: number,
	Reached: boolean,
}

function GoldenEfficiency.evaluate(configuredPercent: number?, collected: number?, maximum: number?): Evaluation
	local configured = math.clamp(tonumber(configuredPercent) or 100, 0, 100)
	local targetPercent = if configured <= 0 then 100 else configured
	local maxCount = math.max(0, tonumber(maximum) or 0)
	local collectedCount = math.max(0, tonumber(collected) or 0)
	local progressRatio = if maxCount > 0 then math.clamp(collectedCount / maxCount, 0, 1) else 0
	local targetRatio = targetPercent / 100

	return {
		ConfiguredPercent = configured,
		TargetPercent = targetPercent,
		TargetRatio = targetRatio,
		ProgressRatio = progressRatio,
		Reached = maxCount > 0 and progressRatio + 1e-6 >= targetRatio,
	}
end

return GoldenEfficiency
