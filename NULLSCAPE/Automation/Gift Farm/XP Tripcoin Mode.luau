--!nocheck

local UpgradeCompletion = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Upgrade Completion.luau")
local Beacon = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Beacon.luau")
local MovementLease = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/MovementLease.luau")
local PylonState = getgenv().loadModule("NULLSCAPE/Automation/Pylon State.luau")

local XpTripcoinMode = {}
local returnedThisRound = false

function XpTripcoinMode.start(gc)
	if UpgradeCompletion and typeof(UpgradeCompletion.start) == "function" then
		return UpgradeCompletion.start(gc)
	end
	return false
end

function XpTripcoinMode.stop(controller)
	if UpgradeCompletion and typeof(UpgradeCompletion.stop) == "function" then
		UpgradeCompletion.stop()
	end
	if controller then
		controller.GiftFarmXpTripcoinMode = false
	end
	returnedThisRound = false
end

function XpTripcoinMode.reset()
	returnedThisRound = false
end

function XpTripcoinMode.sync(controller)
	local completion = UpgradeCompletion and UpgradeCompletion.evaluate()
	local complete = completion and completion.Trusted == true and completion.Complete == true
	local changed = controller.GiftFarmXpTripcoinMode ~= complete
	controller.GiftFarmXpTripcoinMode = complete
	if changed then
		returnedThisRound = false
	end
	if completion and completion.Trusted then
		controller.GiftFarmUpgradeCompletion =
			string.format("%d/%d native upgrade stacks", completion.OwnedStacks, completion.RequiredStacks)
	else
		controller.GiftFarmUpgradeCompletion = "Waiting for native upgrade sync"
	end
	return complete, changed
end

function XpTripcoinMode.handleScan(controller, hrp, candidates, scanInfo, setStatus, currentSessionToken)
	if controller.GiftFarmXpTripcoinMode ~= true then
		return false
	end
	if returnedThisRound then
		setStatus(controller, "Paused", "At beacon; XP + Tripcoin round complete")
		task.wait(0.2)
		return true
	end

	local rawNormal = scanInfo and (tonumber(scanInfo.RawNormal) or 0) or 0
	local rawGolden = scanInfo and (tonumber(scanInfo.RawGolden) or 0) or 0
	local goldenFloor = scanInfo and (tonumber(scanInfo.GoldenTargetFloorPercent) or 0) or 0
	local waitingForRequiredGolden = goldenFloor > 0 and scanInfo.GoldenTargetReached ~= true
	if rawNormal > 0 or rawGolden > 0 or waitingForRequiredGolden then
		Beacon.suppressUntilReturn()
		if #candidates == 0 then
			local detail = if waitingForRequiredGolden
				then string.format(
					"LAP 2 | waiting for %.0f%% Golden Gifts (%d/%d)",
					goldenFloor,
					tonumber(scanInfo.GoldenCollected) or 0,
					tonumber(scanInfo.GoldenMax) or 0
				)
				else string.format("XP + Tripcoin | waiting for %d normal gifts to settle", rawNormal)
			setStatus(controller, "Paused", detail)
			task.wait(0.08)
			return true
		end
		return false
	end

	local pylonsPending, pylonSnapshot = PylonState.shouldWait(controller)
	if pylonsPending then
		Beacon.suppressUntilReturn()
		local detail = if pylonSnapshot.Maximum > 0
			then string.format(
				"XP + Tripcoin | waiting for pylons %d/%d",
				pylonSnapshot.Completed,
				pylonSnapshot.Maximum
			)
			else "XP + Tripcoin | waiting for active pylons"
		setStatus(controller, "Paused", detail, true)
		task.wait(0.08)
		return true
	end

	Beacon.restore(true)
	local lease = MovementLease.acquire("XpTripcoinReturn")
	local forceReturn = true
	setStatus(controller, "ReturningBeacon", "XP + Tripcoin complete; returning to beacon", true)
	local success = Beacon.returnToBeacon(
		controller,
		hrp,
		setStatus,
		"All normal gifts collected",
		lease,
		currentSessionToken,
		forceReturn
	)
	lease:release()
	if success then
		returnedThisRound = true
		setStatus(controller, "Paused", "At beacon; XP + Tripcoin round complete", true)
		task.wait(0.4)
	else
		setStatus(controller, "Recovering", "XP + Tripcoin beacon return failed; retrying", true)
		task.wait(0.25)
	end
	return true
end

return XpTripcoinMode
