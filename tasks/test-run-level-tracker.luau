--!strict

local Tracker = require("../NULLSCAPE/Automation/RunLevelTracker")

local function expectEqual(actual: unknown, expected: unknown, message: string)
	assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

Tracker.reset()
local first = Tracker.update(10, true, {
	GoldenMax = 10,
	GoldenCollected = 8,
	GoldenProgressRatio = 0.8,
})
expectEqual(first.Completion, nil, "round start must not complete")

Tracker.update(10, true, {
	GoldenMax = 10,
	GoldenCollected = 10,
	GoldenProgressRatio = 1,
})
local intermission = Tracker.update(10, false, nil, {
	GoldenMax = 10,
	GoldenCollected = 10,
	GoldenProgressRatio = 1,
})
local intermissionCompletion = assert(intermission.Completion, "intermission must emit completion")
expectEqual(intermissionCompletion.Level, 10, "intermission completion level")
expectEqual(intermissionCompletion.GoldenProgressRatio, 1, "intermission keeps best Golden progress")
expectEqual(Tracker.update(10, false).Completion, nil, "completion must emit once")

Tracker.reset()
Tracker.update(20, true, {
	GoldenMax = 5,
	GoldenCollected = 5,
	GoldenProgressRatio = 1,
})
local skippedIntermission = Tracker.update(21, true, {
	GoldenMax = 7,
	GoldenCollected = 0,
	GoldenProgressRatio = 0,
})
local skippedCompletion = assert(skippedIntermission.Completion, "level increase must emit fallback completion")
expectEqual(skippedCompletion.Level, 20, "level increase fallback completion")
expectEqual(skippedCompletion.GoldenMax, 5, "fallback must not consume next-level counters")

print("PASS - Run Level Tracker")
