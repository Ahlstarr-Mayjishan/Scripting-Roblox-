--!nocheck
-- [[
--  NULLSCAPE - Gift Farm No-Tracking Rule
--  Arms a clean intermission rotation before long sessions become unstable.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local RuntimeHealth = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Runtime Health.luau")

local NoTracking = {}
local SESSION_ROTATION_LEVEL = 250
local INTERMISSION_STABLE_TIME = 4.25

local state = {
	Armed = false,
	ArmedLevel = nil,
	HealthReason = nil,
	IntermissionSince = nil,
}

local function getLevel()
	local levelValue = ReplicatedStorage:FindFirstChild("Level")
	return math.max(0, math.floor(tonumber(levelValue and levelValue.Value) or 0))
end

function NoTracking.reset()
	RuntimeHealth.stop()
	state.Armed = false
	state.ArmedLevel = nil
	state.HealthReason = nil
	state.IntermissionSince = nil
end

function NoTracking.step(controller)
	if not controller or controller.GiftFarmNoTrackingEnabled ~= true then
		NoTracking.reset()
		return nil
	end
	RuntimeHealth.start()

	local level = getLevel()
	if not state.Armed then
		local health = RuntimeHealth.getStatus()
		local sessionLimitReached = level >= SESSION_ROTATION_LEVEL
		if not sessionLimitReached and not health.Unhealthy then
			return nil
		end
		state.Armed = true
		state.ArmedLevel = level
		state.HealthReason = if sessionLimitReached
			then string.format("safe server rotation level %d reached", SESSION_ROTATION_LEVEL)
			else health.Reason or "client runtime health degraded"
	end

	if Context.isInRound() == true then
		state.IntermissionSince = nil
		return nil
	end

	local now = os.clock()
	state.IntermissionSince = state.IntermissionSince or now
	local stableFor = now - state.IntermissionSince
	local remaining = math.max(0, INTERMISSION_STABLE_TIME - stableFor)
	if remaining > 0 then
		return {
			Hold = true,
			Status = "NoTrackingExitPending",
			Detail = string.format(
				"%s at level %d; confirming stable intermission",
				state.HealthReason,
				state.ArmedLevel or level
			),
			OverlayText = "No-Tracking me\nConfirming intermission",
		}
	end

	return {
		Hold = true,
		RotateReady = true,
		Status = "NoTrackingRotation",
		Detail = string.format(
			"%s at level %d; stable intermission confirmed",
			state.HealthReason,
			state.ArmedLevel or level
		),
		OverlayText = "No-Tracking me\nStable intermission confirmed - rotating server",
	}
end

function NoTracking.getState()
	return state
end

return NoTracking
