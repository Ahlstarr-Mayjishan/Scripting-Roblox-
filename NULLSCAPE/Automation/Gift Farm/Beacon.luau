--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local Beacon = {}
local SUPPRESS_REFRESH_INTERVAL = 0.25

local returnDone = false
local suppressed = false
local lastSuppressAt = 0

function Beacon.reset(inRound)
	returnDone = false
	lastSuppressAt = 0
	if not inRound and suppressed then
		Context.restoreBeaconInteraction()
		suppressed = false
	end
end

function Beacon.suppressUntilReturn()
	local contextSuppressed = typeof(Context.isBeaconInteractionSuppressed) == "function"
		and Context.isBeaconInteractionSuppressed()
	local now = os.clock()
	if (suppressed or contextSuppressed) and now - lastSuppressAt < SUPPRESS_REFRESH_INTERVAL then
		suppressed = true
		return true
	end

	lastSuppressAt = now
	suppressed = Context.suppressBeaconInteraction() == true
		or suppressed
		or contextSuppressed
	return suppressed
end

function Beacon.restore()
	local contextSuppressed = typeof(Context.isBeaconInteractionSuppressed) == "function"
		and Context.isBeaconInteractionSuppressed()
	if not suppressed and not contextSuppressed then
		return false
	end

	Context.restoreBeaconInteraction()
	suppressed = false
	lastSuppressAt = 0
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
