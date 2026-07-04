--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local Beacon = {}

local returnDone = false
local suppressed = false

function Beacon.reset(inRound)
	returnDone = false
	if not inRound and suppressed then
		Context.restoreBeaconInteraction()
		suppressed = false
	end
end

function Beacon.suppressUntilReturn()
	suppressed = Context.suppressBeaconInteraction() == true or suppressed
	return suppressed
end

function Beacon.restore()
	if not suppressed then
		return false
	end

	Context.restoreBeaconInteraction()
	suppressed = false
	return true
end

function Beacon.returnToBeacon(controller, hrp, setStatus, reason)
	if returnDone or controller.GiftFarmReturnToBeaconAfterGolden == false then
		return false
	end
	if not Context.isBeaconActive() then
		return false
	end

	local beacon = Context.getBeaconPart()
	if not (beacon and hrp and hrp.Parent) then
		return false
	end

	returnDone = true
	Beacon.restore()
	Context.moveCharacterTo(CFrame.new(beacon.Position + Vector3.new(0, 4, 0)))
	if typeof(setStatus) == "function" then
		setStatus(controller, "ReturningToBeacon", reason or "Golden gifts complete")
	end
	return true
end

return Beacon
