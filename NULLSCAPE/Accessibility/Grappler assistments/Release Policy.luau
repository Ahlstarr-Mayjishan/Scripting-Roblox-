--!nocheck
--[[
	NULLSCAPE - Grappler Release Policy
	Preserves native voluntary-release windows for catapult and SharkTail transitions.
]]

local Policy = {}

local VOLUNTARY_REASONS = {
	SharkVoid = true,
	ReelSaver = true,
	SharkEscape = true,
	Catapult = true,
	ReleaseTiming = true,
}

function Policy.release(grapple, reason, metadata)
	if not (grapple and typeof(grapple.End) == "function") then
		return false
	end

	metadata = metadata or {}
	local wasCancelled = metadata.EndWasCancelled
	if wasCancelled == nil then
		wasCancelled = not VOLUNTARY_REASONS[tostring(reason or "")]
	end

	local success, result = pcall(function()
		return grapple:End(wasCancelled == true)
	end)
	return success and result ~= false
end

return Policy
