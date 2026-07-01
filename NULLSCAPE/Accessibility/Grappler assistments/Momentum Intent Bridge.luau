--!nocheck
-- [[
--  NULLSCAPE - Grappler Momentum Intent Bridge
--  Biases candidate anchors toward paths that stabilize high horizontal speed.
-- ]]

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local Bridge = {}

local DEFAULT_HIGH_SPEED = 120

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getState(rootPart)
	if MomentumMemory and typeof(MomentumMemory.getState) == "function" then
		local success, state = pcall(function()
			return MomentumMemory.getState(rootPart, 0.45)
		end)
		if success then
			return state
		end
	end
	return nil
end

function Bridge.score(grapple, hit, controller, intent)
	local rootPart = grapple and grapple.RootPart
	if not (rootPart and hit and hit.Position) then
		return 0
	end

	local state = getState(rootPart)
	local velocity = state and state.Velocity or rootPart.Velocity
	local horizontalVelocity = flatten(velocity)
	local speed = horizontalVelocity.Magnitude
	local highSpeed =
		math.clamp(tonumber(controller and controller.GrappleIntentHighSpeed) or DEFAULT_HIGH_SPEED, 40, 300)
	if speed < highSpeed then
		return 0
	end

	local toTarget = flatten(hit.Position - rootPart.Position)
	if toTarget.Magnitude <= 0.001 then
		return 0
	end

	local dot = horizontalVelocity.Unit:Dot(toTarget.Unit)
	local confidence = intent and tonumber(intent.Confidence) or 0.5
	if dot < -0.15 then
		return math.clamp((math.abs(dot) * 24 + confidence * 10), 0, 32)
	end
	if dot > 0.72 then
		return -math.clamp((dot - 0.72) * 45, 0, 18)
	end

	return math.clamp((1 - math.abs(dot)) * 8, 0, 10)
end

return Bridge
