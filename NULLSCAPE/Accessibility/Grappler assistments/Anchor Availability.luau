--!nocheck
--[[
	NULLSCAPE - Anchor Availability
	Checks live special-anchor state before a cast can commit to it.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")
local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")

local Availability = {}

local function findPylonAncestor(part)
	local cursor = part and part.Parent
	while cursor and cursor ~= Workspace do
		local tagged = false
		pcall(function()
			tagged = CollectionService:HasTag(cursor, "Pylon")
		end)
		if tagged then
			return cursor
		end
		cursor = cursor.Parent
	end

	return nil
end

function Availability.evaluateBeacon(part)
	if not (part and part:IsA("BasePart") and part.Name == "Beacon") then
		return true, "not-beacon"
	end

	local worldBeacon = Workspace:FindFirstChild("Beacon")
	if part == worldBeacon then
		return part:GetAttribute("Beacon") == true, "world-beacon-inactive"
	end

	local pylon = findPylonAncestor(part)
	if pylon then
		return pylon:GetAttribute("Completed") == true, "pylon-beacon-inactive"
	end

	return false, "unknown-beacon"
end

function Availability.evaluate(grapple, part)
	if not (part and part.Parent and part:IsA("BasePart")) then
		return false, "missing-anchor"
	end
	if part.CanQuery == false then
		return false, "anchor-not-queryable"
	end

	local beaconAvailable, beaconReason = Availability.evaluateBeacon(part)
	if not beaconAvailable then
		return false, beaconReason
	end

	local anchorName = SpecialAnchors and SpecialAnchors.getName(part) or nil
	local humanoid = grapple and grapple.Humanoid
	if
		anchorName
		and anchorName ~= "JumpPad"
		and humanoid
		and humanoid:GetState() == Enum.HumanoidStateType.Running
	then
		-- Native Grapple.Start rejects every named target except JumpPad while
		-- Running. Do not let targeting present an impossible Bell cast.
		return false, "native-running-reject"
	end

	local movement = grapple and grapple.Movement
	if anchorName == "Bell" and part.CanTouch == false then
		local canTemporarilyAllow = TouchInterest
			and typeof(TouchInterest.canTemporarilyAllowPart) == "function"
			and TouchInterest.canTemporarilyAllowPart(part, "Bell")
		if not canTemporarilyAllow then
			return false, "bell-inactive"
		end
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
