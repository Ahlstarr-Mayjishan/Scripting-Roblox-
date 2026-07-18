--!strict

local GoldenEfficiency = require("../NULLSCAPE/Automation/GoldenEfficiency")

local function expectEqual(actual: unknown, expected: unknown, message: string)
	assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local disabledCap = GoldenEfficiency.evaluate(0, 9, 10)
expectEqual(disabledCap.TargetPercent, 100, "zero disables the collection cap")
expectEqual(disabledCap.Reached, false, "disabled cap still collects all Golden Gifts")

local partial = GoldenEfficiency.evaluate(60, 6, 10)
expectEqual(partial.TargetPercent, 60, "configured target")
expectEqual(partial.Reached, true, "partial target is reached")

local belowTarget = GoldenEfficiency.evaluate(60, 5, 10)
expectEqual(belowTarget.Reached, false, "collection continues below target")

local unavailable = GoldenEfficiency.evaluate(50, 0, 0)
expectEqual(unavailable.Reached, false, "missing counters cannot complete the target")

print("PASS - Golden Efficiency")
