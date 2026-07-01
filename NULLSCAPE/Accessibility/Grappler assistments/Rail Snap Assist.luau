--!nocheck
-- [[
--  NULLSCAPE - Grappler Rail Snap Assist
--  Gives rails near the user's aim a small targeting bias without forcing rail capture.
-- ]]

local RailMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory Proxy.luau")

local RailSnap = {}

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

function RailSnap.score(part, origin, aimDirection, intent)
	if not (RailMemory and typeof(RailMemory.isRailPart) == "function" and RailMemory.isRailPart(part)) then
		return 0
	end
	if not (origin and typeof(aimDirection) == "Vector3" and aimDirection.Magnitude > 0.001) then
		return 0
	end

	local toRail = part.Position - origin
	if toRail.Magnitude <= 0.001 then
		return 0
	end

	local aimDot = aimDirection.Unit:Dot(toRail.Unit)
	local flatAim = flatten(aimDirection)
	local railDirection = flatten(part.CFrame.LookVector)
	local alignment = 0
	if flatAim.Magnitude > 0.001 and railDirection.Magnitude > 0.001 then
		alignment = math.abs(flatAim.Unit:Dot(railDirection.Unit))
	end

	local intentBonus = intent and intent.Name == "RailCapture" and 18 or 0
	return math.clamp((aimDot - 0.72) * 55 + alignment * 10 + intentBonus, 0, 34)
end

return RailSnap
