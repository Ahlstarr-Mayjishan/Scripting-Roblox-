--!nocheck
--[[
	NULLSCAPE - Grapple Time Budget
	Rejects long, ordinary pulls when the native Grapple timer cannot safely support them.
]]

local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")

local Budget = {}

local function isSpecial(part)
	return SpecialAnchors and typeof(SpecialAnchors.isSpecial) == "function" and SpecialAnchors.isSpecial(part)
end

function Budget.evaluate(grapple, hit, part, intent)
	local rootPart = grapple and grapple.RootPart
	local remaining = tonumber(grapple and grapple.Time) or 0
	local capacity = tonumber(grapple and (grapple.TimeClamp or grapple.usedGrappleTime)) or remaining
	if not (rootPart and hit and hit.Position and capacity > 0) then
		return { Accept = true, Penalty = 0, Reason = "unavailable" }
	end

	local distance = (hit.Position - rootPart.Position).Magnitude
	local special = isSpecial(part)
	local reserve = special and 0.18 or 0.42
	local projectedCost = math.clamp(distance / 105, 0.08, 1.8)
	if intent and (intent.Name == "VoidRescue" or intent.Name == "RazorbloomEscape") then
		reserve = 0.06
	end

	local penalty = 0
	if remaining <= reserve then
		return { Accept = false, Penalty = 100, Reason = "time-reserve-empty" }
	end
	if remaining < projectedCost + reserve then
		penalty = math.clamp((projectedCost + reserve - remaining) * 42, 8, 34)
	end

	return {
		Accept = true,
		Penalty = penalty,
		Reason = penalty > 0 and "time-tight" or "time-clear",
		Remaining = remaining,
		ProjectedCost = projectedCost,
	}
end

return Budget
