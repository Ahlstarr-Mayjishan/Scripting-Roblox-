--!nocheck
-- [[ NULLSCAPE - Native SharkTail Window ]]
-- Owns the short native allowSharkTail window opened by Grapple:End(false).

local Window = {
	Pending = setmetatable({}, { __mode = "k" }),
}

local NATIVE_WINDOW = 0.25

function Window.arm(grapple, reason, now, duration)
	if not grapple then
		return false
	end

	Window.Pending[grapple] = {
		Reason = tostring(reason or "SharkTail"),
		Until = (tonumber(now) or time()) + math.clamp(tonumber(duration) or NATIVE_WINDOW, 0.05, NATIVE_WINDOW),
	}
	return true
end

function Window.isArmed(grapple, reason, now)
	local pending = grapple and Window.Pending[grapple]
	if not pending or pending.Reason ~= tostring(reason or "SharkTail") then
		return false
	end

	if (tonumber(now) or time()) > pending.Until then
		Window.Pending[grapple] = nil
		return false
	end

	return true
end

function Window.cancel(grapple, reason)
	if not grapple then
		return false
	end

	local pending = Window.Pending[grapple]
	if pending and (reason == nil or pending.Reason == tostring(reason)) then
		Window.Pending[grapple] = nil
		return true
	end

	return false
end

function Window.trigger(grapple, reason, now)
	if not Window.isArmed(grapple, reason, now) then
		return false
	end
	if not (grapple.allowSharkTail == true and grapple.sharkTailDisable ~= true) then
		return false
	end
	if typeof(grapple.SharkTail) ~= "function" then
		return false
	end

	local success = pcall(function()
		grapple:SharkTail()
	end)
	if success then
		Window.cancel(grapple, reason)
	end
	return success
end

function Window.reset(reason)
	for grapple, pending in pairs(Window.Pending) do
		if reason == nil or pending.Reason == tostring(reason) then
			Window.Pending[grapple] = nil
		end
	end
end

return Window
