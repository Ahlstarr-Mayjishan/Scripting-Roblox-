--!nocheck

local UpgradeCompletion = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Upgrade Completion.luau")
local Beacon = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Beacon.luau")
local MovementLease = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/MovementLease.luau")

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
	if rawNormal > 0 then
		Beacon.suppressUntilReturn()
		if #candidates == 0 then
			setStatus(
				controller,
				"Paused",
				string.format("XP + Tripcoin | waiting for %d normal gifts to settle", rawNormal)
			)
			task.wait(0.08)
			return true
		end
		return false
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
