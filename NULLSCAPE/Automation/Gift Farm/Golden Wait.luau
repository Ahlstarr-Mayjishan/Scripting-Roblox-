--!nocheck

local GoldenWait = {}

local GOLDEN_SPAWN_WAIT = 2
local PASSAGE_GOLDEN_WAIT = 2.5

local hasSeenGoldenThisRound = false
local goldenMissingSince = nil
local passageGoldenUntil = 0

function GoldenWait.reset()
	hasSeenGoldenThisRound = false
	goldenMissingSince = nil
	passageGoldenUntil = 0
end

function GoldenWait.noteScan(scanInfo)
	if scanInfo and scanInfo.RawGolden and scanInfo.RawGolden > 0 then
		hasSeenGoldenThisRound = true
		goldenMissingSince = nil
	end
end

function GoldenWait.hasSeenGolden()
	return hasSeenGoldenThisRound
end

function GoldenWait.startPassageWindow()
	passageGoldenUntil = math.max(passageGoldenUntil, os.clock() + PASSAGE_GOLDEN_WAIT)
	goldenMissingSince = os.clock()
end

function GoldenWait.isPassageWindowActive()
	return os.clock() < passageGoldenUntil
end

function GoldenWait.getWaitTime()
	return GOLDEN_SPAWN_WAIT
end

function GoldenWait.shouldWait(controller, scanInfo, lastGiftSeenAt, setStatus, reason)
	local passageActive = GoldenWait.isPassageWindowActive()
	if not (scanInfo and scanInfo.RawGolden == 0 and (passageActive or lastGiftSeenAt > 0)) then
		goldenMissingSince = nil
		return false
	end

	if not passageActive and not hasSeenGoldenThisRound and (tonumber(scanInfo.RawNormal) or 0) > 0 then
		return false
	end

	local waitTime = passageActive and PASSAGE_GOLDEN_WAIT or GoldenWait.getWaitTime()
	if waitTime <= 0 then
		return false
	end

	goldenMissingSince = goldenMissingSince or os.clock()
	local elapsed = os.clock() - goldenMissingSince
	if elapsed < waitTime then
		if typeof(setStatus) == "function" then
			setStatus(
				controller,
				"WaitingForGoldenSpawn",
				string.format("%s %.1fs/%.1fs", reason or "Golden settle", elapsed, waitTime)
			)
		end
		return true
	end

	return false
end

function GoldenWait.shouldHoldAfterRoute(scanInfo, totalPlanned)
	local rawNormal = scanInfo and (tonumber(scanInfo.RawNormal) or 0) or 0
	local rawGolden = scanInfo and (tonumber(scanInfo.RawGolden) or 0) or 0
	return rawGolden == 0
		and rawNormal > 0
		and rawNormal <= totalPlanned
		and GoldenWait.getWaitTime() > 0
end

function GoldenWait.holdNow()
	goldenMissingSince = os.clock()
end

return GoldenWait
