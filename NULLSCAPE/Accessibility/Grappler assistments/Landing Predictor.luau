--!nocheck
-- [[
--  NULLSCAPE - Grappler Landing Predictor
--  Lightweight trajectory/risk estimate used by target scoring.
-- ]]

local Workspace = game:GetService("Workspace")

local TerrainMemory =
	getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Terrain Memory.luau")
local PerformanceBudget = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Performance Budget.luau")

local Predictor = {}

local SAMPLE_TIMES = { 0.22, 0.38, 0.55, 0.72 }
local PROJECTED_PULL_SPEED = 42

local function getVoidY()
	if TerrainMemory and typeof(TerrainMemory.getVoidInfo) == "function" then
		local info = TerrainMemory.getVoidInfo()
		return info and info.Y or nil
	end

	local killVoid = Workspace:FindFirstChild("KillVoid")
	return killVoid and killVoid:IsA("BasePart") and killVoid.Position.Y or nil
end

local function getVelocity(rootPart)
	return rootPart.AssemblyLinearVelocity or rootPart.Velocity
end

function Predictor.evaluate(grapple, hit, candidatePart, _controller, intent)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and hit and hit.Position) then
		return {
			Penalty = 0,
			Bonus = 0,
			Reason = "none",
		}
	end

	local origin = rootPart.Position
	local toTarget = hit.Position - origin
	if toTarget.Magnitude <= 0.001 then
		return {
			Penalty = 20,
			Bonus = 0,
			Reason = "no-target-vector",
		}
	end

	local velocity = getVelocity(rootPart)
	local pullVelocity = toTarget.Unit * PROJECTED_PULL_SPEED
	local projectedVelocity = velocity * 0.45 + pullVelocity
	local voidY = getVoidY()
	local penalty = 0
	local bonus = 0
	local reason = "clear"

	local budget = PerformanceBudget and typeof(PerformanceBudget.get) == "function" and PerformanceBudget.get() or nil
	local sampleCount = math.clamp(tonumber(budget and budget.TrajectorySamples) or #SAMPLE_TIMES, 1, #SAMPLE_TIMES)
	for index = 1, sampleCount do
		local t = SAMPLE_TIMES[index]
		local point = origin + projectedVelocity * t + Vector3.new(0, -0.5 * Workspace.Gravity * t * t, 0)
		if voidY and point.Y - voidY < 12 and (not intent or intent.Name ~= "VoidRescue") then
			penalty += 18
			reason = "projected-void"
		end

		local floorHit = Workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -9, 0), grapple.grappleParams)
		if floorHit and floorHit.Instance ~= candidatePart then
			bonus += 2
		end
	end

	if hit.Normal and hit.Normal.Y > 0.45 then
		bonus += 8
	elseif hit.Normal and hit.Normal.Y < -0.2 then
		penalty += 14
		reason = "bad-landing-normal"
	end

	return {
		Penalty = math.clamp(penalty, 0, 60),
		Bonus = math.clamp(bonus, 0, 16),
		Reason = reason,
	}
end

return Predictor
