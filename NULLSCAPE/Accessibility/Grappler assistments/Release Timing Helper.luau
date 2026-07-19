--!nocheck
--[[
	NULLSCAPE - Grappler Release Timing Helper
	Shared tiny scheduler for techniques that need short reel/release windows.
]]

local Helper = {
	Pending = setmetatable({}, { __mode = "k" }),
}

local ReleaseAdvisor = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Reel Release Advisor.luau")
local ReleasePolicy = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Policy.luau")
local ReleasePlanner = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Release Planner.luau")

local function getNumber(value, fallback, minimum, maximum)
	return math.clamp(tonumber(value) or fallback, minimum, maximum)
end

function Helper.schedule(grapple, reason, holdTime, metadata)
	if not grapple then
		return false
	end

	if ReleaseAdvisor and typeof(ReleaseAdvisor.suggestHoldTime) == "function" then
		local success, suggested = pcall(ReleaseAdvisor.suggestHoldTime, grapple, reason, holdTime, metadata)
		if success and suggested then
			holdTime = suggested
		end
	end
	if ReleasePlanner and typeof(ReleasePlanner.suggestHoldTime) == "function" then
		local success, suggested = pcall(ReleasePlanner.suggestHoldTime, grapple, reason, holdTime, metadata)
		if success and suggested then
			holdTime = suggested
		end
	end

	local now = time()
	Helper.Pending[grapple] = {
		Reason = reason or "TimedRelease",
		ReleaseAt = now + getNumber(holdTime, 0.14, 0.03, 0.5),
		StartedAt = now,
		Metadata = metadata or {},
	}
	return true
end

function Helper.cancel(grapple)
	if grapple then
		Helper.Pending[grapple] = nil
	else
		table.clear(Helper.Pending)
	end
end

function Helper.cancelReason(grapple, reason)
	local pending = Helper.get(grapple)
	if pending and pending.Reason == reason then
		Helper.Pending[grapple] = nil
		return true
	end
	return false
end

function Helper.get(grapple)
	return grapple and Helper.Pending[grapple] or nil
end

function Helper.step(grapple)
	local pending = Helper.get(grapple)
	if not pending or time() < pending.ReleaseAt then
		return false
	end

	Helper.Pending[grapple] = nil
	local metadata = pending.Metadata or {}
	local function notifyFailure(reason)
		if typeof(metadata.OnReleaseFailed) == "function" then
			pcall(metadata.OnReleaseFailed, grapple, pending.Reason, reason)
		end
	end

	local movement = grapple and grapple.Movement
	if not (movement and movement.grappling == true and grapple.grappleReel == true) then
		notifyFailure("state-invalid")
		return false
	end

	if ReleasePlanner and typeof(ReleasePlanner.shouldRelease) == "function" then
		local controller = getgenv()._NULLSCAPE_Globals and getgenv()._NULLSCAPE_Globals.activeAccessibilityController
		local canRelease = ReleasePlanner.shouldRelease(grapple, pending.Reason, pending.Metadata, controller)
		if not canRelease and (pending.Deferrals or 0) < 2 then
			pending.Deferrals = (pending.Deferrals or 0) + 1
			pending.ReleaseAt = time() + 0.04
			Helper.Pending[grapple] = pending
			return false
		end
	end

	if not (ReleasePolicy and typeof(ReleasePolicy.release) == "function") then
		notifyFailure("policy-unavailable")
		return false
	end

	local released = ReleasePolicy.release(grapple, pending.Reason, metadata)
	if not released then
		notifyFailure("native-rejected")
	end
	return released
end

function Helper.reset()
	table.clear(Helper.Pending)
end

return Helper
