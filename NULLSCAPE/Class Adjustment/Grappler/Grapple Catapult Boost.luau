--!nocheck
-- [[
--  NULLSCAPE - Grapple Catapult Boost Adjustment
-- ]]

local CatapultBoost = {}

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local CachedControl = nil

local function getControl()
	if CachedControl then
		return CachedControl
	end
	CachedControl = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	return CachedControl
end

function CatapultBoost.apply(grapple, yBefore, yVelBelowMinBefore)
	if not grapple or not grapple.RootPart or not yBefore or not yVelBelowMinBefore then
		return
	end

	local Control = getControl()
	local multiplier = math.clamp(tonumber(Control and Control.GrappleCatapultMultiplier) or 1, 1, 3)
	if multiplier <= 1 then
		return
	end

	if yBefore > 15 and grapple.Movement and grapple.Movement.grappleJumping == true then
		local v5 = 1 - math.clamp(yBefore / 300, 0.2, 1)
		local nativeBoost = (yBefore / 2) * v5
		local extraBoost = nativeBoost * (multiplier - 1)

		if extraBoost > 0 then
			local rootPart = grapple.RootPart
			local beforeVelocity = rootPart.Velocity
			rootPart.Velocity = rootPart.Velocity + Vector3.new(0, extraBoost, 0)
			if MomentumMemory and typeof(MomentumMemory.noteImpulse) == "function" then
				pcall(function()
					MomentumMemory.noteImpulse(
						rootPart,
						"GrappleCatapultBoost",
						beforeVelocity,
						rootPart.Velocity,
						Vector3.new(0, extraBoost, 0),
						{
							Multiplier = multiplier,
							NativeBoost = nativeBoost,
						}
					)
				end)
			end
		end
	end
end

return CatapultBoost
