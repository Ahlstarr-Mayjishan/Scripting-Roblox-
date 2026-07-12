--!nocheck
--[[
	NULLSCAPE - Local Route Hint
	A small two-step anchor lookahead for pilot and emergency decisions.
]]

local AnchorMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Anchor Memory.luau")
local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")
local SpecialAnchors = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Special Anchors.luau")

local Hint = {
	Cache = setmetatable({}, { __mode = "k" }),
}

local TTL = 0.35
local RADIUS = 58

local function eligible(intent)
	local mode = intent and intent.PilotMode
	return mode == "Pilot" or mode == "Emergency" or mode == "Technique"
end

function Hint.score(grapple, hit, part, intent)
	local special = SpecialAnchors and typeof(SpecialAnchors.isSpecial) == "function" and SpecialAnchors.isSpecial(part)
	local rail = RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part)
	if not (eligible(intent) and hit and hit.Position and part and (special or rail)) then
		return 0
	end

	local cached = Hint.Cache[part]
	if cached and time() - cached.At < TTL then
		return cached.Score
	end

	local bestDistance = math.huge
	if AnchorMemory and typeof(AnchorMemory.getNearbyAnchors) == "function" then
		for _, entry in ipairs(AnchorMemory.getNearbyAnchors(hit.Position, RADIUS)) do
			if entry.Part ~= part then
				bestDistance = math.min(bestDistance, (entry.Position - hit.Position).Magnitude)
			end
		end
	end
	if RailMemory and typeof(RailMemory.getNearbyRails) == "function" then
		for _, entry in ipairs(RailMemory.getNearbyRails(hit.Position, RADIUS)) do
			if entry.Part ~= part then
				bestDistance = math.min(bestDistance, (entry.Position - hit.Position).Magnitude)
			end
		end
	end

	local score = bestDistance < math.huge and math.clamp((RADIUS - bestDistance) * 0.28, 0, 14) or 0
	Hint.Cache[part] = { At = time(), Score = score }
	return score
end

function Hint.clear()
	table.clear(Hint.Cache)
end

return Hint
