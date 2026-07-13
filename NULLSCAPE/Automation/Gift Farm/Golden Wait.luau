--!nocheck

local GoldenWait = {}

local GOLDEN_SPAWN_WAIT = 2
local PASSAGE_GOLDEN_WAIT = 2.5
local NORMAL_CLEAR_GOLDEN_WAIT = 5
local PYLON_GOLDEN_WAIT = 5

local hasSeenGoldenThisRound = false
local goldenMissingSince = nil
local passageGoldenUntil = 0
local normalClearGoldenUntil = 0
local pylonGoldenUntil = 0
local pylonGoldenPending = false
local pylonGoldenObserved = false

function GoldenWait.reset()
	hasSeenGoldenThisRound = false
	goldenMissingSince = nil
	passageGoldenUntil = 0
	normalClearGoldenUntil = 0
	pylonGoldenUntil = 0
	pylonGoldenPending = false
	pylonGoldenObserved = false
end

function GoldenWait.noteScan(scanInfo)
	if scanInfo and scanInfo.RawGolden and scanInfo.RawGolden > 0 then
		hasSeenGoldenThisRound = true
		goldenMissingSince = nil
		normalClearGoldenUntil = 0
		if pylonGoldenPending then
			pylonGoldenObserved = true
		end
	end
end

function GoldenWait.hasSeenGolden()
	return hasSeenGoldenThisRound
end

function GoldenWait.startPassageWindow()
	passageGoldenUntil = math.max(passageGoldenUntil, os.clock() + PASSAGE_GOLDEN_WAIT)
	goldenMissingSince = os.clock()
end

function GoldenWait.startNormalClearWindow()
	normalClearGoldenUntil = math.max(normalClearGoldenUntil, os.clock() + NORMAL_CLEAR_GOLDEN_WAIT)
	goldenMissingSince = os.clock()
end

function GoldenWait.startPylonWindow()
	if pylonGoldenPending then
		return false
	end

	pylonGoldenPending = true
	pylonGoldenObserved = false
	pylonGoldenUntil = os.clock() + PYLON_GOLDEN_WAIT
	goldenMissingSince = os.clock()
	return true
end

function GoldenWait.finishPylonWindow()
	pylonGoldenUntil = 0
	pylonGoldenPending = false
	pylonGoldenObserved = false
end

function GoldenWait.isPylonWindowActive()
	return pylonGoldenPending and not pylonGoldenObserved and os.clock() < pylonGoldenUntil
end

function GoldenWait.canReleasePylonWithoutGolden()
	return pylonGoldenPending and not pylonGoldenObserved and os.clock() >= pylonGoldenUntil
end

function GoldenWait.isPassageWindowActive()
	return os.clock() < passageGoldenUntil
end

function GoldenWait.isNormalClearWindowActive()
	return os.clock() < normalClearGoldenUntil
end

function GoldenWait.getWaitTime()
	return GOLDEN_SPAWN_WAIT
end

function GoldenWait.shouldWait(controller, scanInfo, lastGiftSeenAt, setStatus, reason)
	local passageActive = GoldenWait.isPassageWindowActive()
	local normalClearActive = GoldenWait.isNormalClearWindowActive()
	local pylonActive = GoldenWait.isPylonWindowActive()
	if not (scanInfo and scanInfo.RawGolden == 0 and (passageActive or normalClearActive or pylonActive or lastGiftSeenAt > 0)) then
		goldenMissingSince = nil
		return false
	end

	-- Producer windows run in the background. Existing normal gifts must keep the
	-- route active; Scanner will preempt them as soon as a golden gift appears.
	if (tonumber(scanInfo.RawNormal) or 0) > 0 then
		return false
	end

	local waitTime = GoldenWait.getWaitTime()
	if passageActive then
		waitTime = math.max(waitTime, PASSAGE_GOLDEN_WAIT)
	end
	if normalClearActive then
		waitTime = math.max(waitTime, NORMAL_CLEAR_GOLDEN_WAIT)
	end
	if pylonActive then
		waitTime = math.max(waitTime, PYLON_GOLDEN_WAIT)
	end
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
