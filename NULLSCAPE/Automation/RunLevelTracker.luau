--!strict
-- [[
--  NULLSCAPE - Gift Farm Run Level Tracker
--  Tracks native level/round transitions and preserves the best Golden Gift
--  progress until the completed round reaches intermission.
-- ]]

local RunLevelTracker = {}

export type GoldenProgress = {
	GoldenMax: number?,
	GoldenCollected: number?,
	GoldenProgressRatio: number?,
}

export type Completion = {
	Level: number,
	GoldenMax: number,
	GoldenCollected: number,
	GoldenProgressRatio: number,
}

export type Snapshot = {
	Level: number,
	InRound: boolean,
	Completion: Completion?,
}

type TrackerState = {
	Initialized: boolean,
	LastInRound: boolean,
	RoundLevel: number?,
	GoldenMax: number,
	GoldenCollected: number,
	GoldenRatio: number,
}

local state: TrackerState = {
	Initialized = false,
	LastInRound = false,
	RoundLevel = nil,
	GoldenMax = 0,
	GoldenCollected = 0,
	GoldenRatio = 0,
}

local function resetProgress()
	state.GoldenMax = 0
	state.GoldenCollected = 0
	state.GoldenRatio = 0
end

local function mergeProgress(progress: GoldenProgress?)
	if not progress then
		return
	end

	local maximum = math.max(0, tonumber(progress.GoldenMax) or 0)
	local collected = math.max(0, tonumber(progress.GoldenCollected) or 0)
	local ratio = tonumber(progress.GoldenProgressRatio)
	if not ratio and maximum > 0 then
		ratio = collected / maximum
	end
	state.GoldenMax = math.max(state.GoldenMax, maximum)
	state.GoldenCollected = math.max(state.GoldenCollected, collected)
	state.GoldenRatio = math.max(state.GoldenRatio, math.clamp(tonumber(ratio) or 0, 0, 1))
end

local function completeRound(fallbackLevel: number, nativeProgress: GoldenProgress?): Completion
	mergeProgress(nativeProgress)
	local completion = {
		Level = math.max(0, math.floor(tonumber(state.RoundLevel or fallbackLevel) or 0)),
		GoldenMax = state.GoldenMax,
		GoldenCollected = state.GoldenCollected,
		GoldenProgressRatio = state.GoldenRatio,
	}
	resetProgress()
	return completion
end

function RunLevelTracker.update(
	level: number?,
	inRound: boolean?,
	scanInfo: GoldenProgress?,
	nativeProgress: GoldenProgress?
): Snapshot
	local currentLevel = math.max(0, math.floor(tonumber(level) or 0))
	local currentlyInRound = inRound == true
	local completion = nil

	if not state.Initialized then
		state.Initialized = true
		state.LastInRound = currentlyInRound
		state.RoundLevel = currentlyInRound and currentLevel or nil
		if currentlyInRound then
			mergeProgress(scanInfo)
		end
		return {
			Level = currentLevel,
			InRound = currentlyInRound,
			Completion = nil,
		}
	end

	if currentlyInRound then
		if state.LastInRound and state.RoundLevel and currentLevel > state.RoundLevel then
			completion = completeRound(state.RoundLevel, nil)
			state.RoundLevel = currentLevel
		elseif not state.LastInRound or not state.RoundLevel or currentLevel < state.RoundLevel then
			state.RoundLevel = currentLevel
			resetProgress()
		end
		mergeProgress(scanInfo)
	elseif state.LastInRound then
		completion = completeRound(currentLevel, nativeProgress)
	end

	state.LastInRound = currentlyInRound
	return {
		Level = currentLevel,
		InRound = currentlyInRound,
		Completion = completion,
	}
end

function RunLevelTracker.reset()
	state.Initialized = false
	state.LastInRound = false
	state.RoundLevel = nil
	resetProgress()
end

function RunLevelTracker.getState(): TrackerState
	return state
end

return RunLevelTracker
