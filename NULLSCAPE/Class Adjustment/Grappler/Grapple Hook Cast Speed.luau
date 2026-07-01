--!nocheck
-- [[
--  NULLSCAPE - Grapple Hook Cast Speed Adjustment
-- ]]

local HookCastSpeed = {}

local HooksInstalled = false
local OriginalDelay = nil
local ActiveCast = nil

local MIN_INSTANT_TIME = 0
local MATCH_EPSILON = 0.01

local function getControl()
	return getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
end

local function getMultiplier()
	local Control = getControl()
	return math.clamp(tonumber(Control and Control.GrappleHookCastSpeedMultiplier) or 1, 0, 10)
end

local function scaleDuration(duration)
	duration = tonumber(duration) or 0
	local multiplier = getMultiplier()
	if multiplier == 1 or duration <= 0 then
		return duration
	end
	if multiplier <= 0 then
		return MIN_INSTANT_TIME
	end
	return duration / multiplier
end

local function installHooks()
	if HooksInstalled then
		return true
	end
	if typeof(hookfunction) ~= "function" then
		return false
	end

	local delayOk, oldDelay = pcall(function()
		return hookfunction(task.delay, function(delayTime, callback, ...)
			local active = ActiveCast
			if active and active.OriginalDuration then
				local numericDelay = tonumber(delayTime) or 0
				if math.abs(numericDelay - active.OriginalDuration) <= MATCH_EPSILON then
					delayTime = active.AdjustedDuration or numericDelay
				end
			end

			return OriginalDelay(delayTime, callback, ...)
		end)
	end)

	if not delayOk or typeof(oldDelay) ~= "function" then
		return false
	end

	OriginalDelay = oldDelay
	HooksInstalled = true
	return true
end

local function getNativeDuration(grapple, hit)
	local rootPart = grapple and grapple.RootPart
	local hitPosition = hit and hit.Position
	if not (rootPart and typeof(hitPosition) == "Vector3") then
		return nil
	end

	return (rootPart.Position - hitPosition).Magnitude / 90 * 0.2
end

function HookCastSpeed.beforeStart(grapple, hit)
	local multiplier = getMultiplier()
	if multiplier == 1 then
		return false
	end
	if not (grapple and grapple.hook) then
		return false
	end
	local nativeDuration = getNativeDuration(grapple, hit)
	if not nativeDuration then
		return false
	end
	if not installHooks() then
		return false
	end

	ActiveCast = {
		Grapple = grapple,
		OriginalDuration = nativeDuration,
		AdjustedDuration = scaleDuration(nativeDuration),
		StartedAt = time(),
	}
	return true
end

function HookCastSpeed.afterStart(grapple)
	if ActiveCast and ActiveCast.Grapple == grapple then
		ActiveCast = nil
	end
end

function HookCastSpeed.restore()
	ActiveCast = nil
	if OriginalDelay and typeof(hookfunction) == "function" then
		pcall(hookfunction, task.delay, OriginalDelay)
	end
	OriginalDelay = nil
	HooksInstalled = false
end

return HookCastSpeed
