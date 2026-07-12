--!nocheck
--[[
	NULLSCAPE - Anchor Availability
	Checks live special-anchor state before a cast can commit to it.
]]

local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")

local Availability = {}

function Availability.evaluate(grapple, part)
	if not (part and part.Parent and part:IsA("BasePart")) then
		return false, "missing-anchor"
	end
	if part.CanQuery == false then
		return false, "anchor-not-queryable"
	end

	local anchorName = SpecialAnchors and SpecialAnchors.getName(part) or nil
	local movement = grapple and grapple.Movement
	if anchorName == "Bell" and part.CanTouch == false then
		return false, "bell-inactive"
	end
	if anchorName == "TriaOrb" and movement then
		if movement.triaHold == true then
			return false, "tria-holding"
		end
		if movement.triaDebounce == true then
			return false, "tria-cooldown"
		end
		if movement.rail == true then
			return false, "tria-on-rail"
		end
	end

	return true, anchorName or "terrain"
end

return Availability
