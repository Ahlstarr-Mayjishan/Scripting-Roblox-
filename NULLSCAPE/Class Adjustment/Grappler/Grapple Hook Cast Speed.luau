--!nocheck
-- [[
--  NULLSCAPE - Grapple Hook Cast Speed Adjustment
-- ]]

local TweenService = game:GetService("TweenService")

local HookCastSpeed = {}

local HooksInstalled = false
local OriginalCreate = nil
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

local function isHookTween(instance, tweenInfo, goals)
	local active = ActiveCast
	if not (active and active.Grapple and instance == active.Grapple.hook) then
		return false
	end
	if typeof(tweenInfo) ~= "TweenInfo" or type(goals) ~= "table" then
		return false
	end
	return goals.CFrame ~= nil
end

local function installHooks()
	if HooksInstalled then
		return true
	end
	if typeof(hookfunction) ~= "function" then
		return false
	end

	local createOk, oldCreate = pcall(function()
		return hookfunction(TweenService.Create, function(self, instance, tweenInfo, goals, ...)
			if self == TweenService and isHookTween(instance, tweenInfo, goals) then
				local newDuration = scaleDuration(tweenInfo.Time)
				ActiveCast.OriginalDuration = tweenInfo.Time
				ActiveCast.AdjustedDuration = newDuration
				tweenInfo = TweenInfo.new(
					newDuration,
					tweenInfo.EasingStyle,
					tweenInfo.EasingDirection,
					tweenInfo.RepeatCount,
					tweenInfo.Reverses,
					tweenInfo.DelayTime
				)
			end

			return OriginalCreate(self, instance, tweenInfo, goals, ...)
		end)
	end)

	if not createOk or typeof(oldCreate) ~= "function" then
		return false
	end

	OriginalCreate = oldCreate

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
		pcall(hookfunction, TweenService.Create, oldCreate)
		OriginalCreate = nil
		return false
	end

	OriginalDelay = oldDelay
	HooksInstalled = true
	return true
end

function HookCastSpeed.beforeStart(grapple)
	local multiplier = getMultiplier()
	if multiplier == 1 then
		return false
	end
	if not (grapple and grapple.hook) then
		return false
	end
	if not installHooks() then
		return false
	end

	ActiveCast = {
		Grapple = grapple,
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
	if OriginalCreate and typeof(hookfunction) == "function" then
		pcall(hookfunction, TweenService.Create, OriginalCreate)
	end
	if OriginalDelay and typeof(hookfunction) == "function" then
		pcall(hookfunction, task.delay, OriginalDelay)
	end
	OriginalCreate = nil
	OriginalDelay = nil
	HooksInstalled = false
end

return HookCastSpeed
