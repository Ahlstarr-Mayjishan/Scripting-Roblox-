--!nocheck
--[[
	NULLSCAPE - Grappler Release Planner
	Aligns timed releases with native catapult and SharkTail windows.
]]

local ExitGuard = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Exit Corridor Guard.luau")

local Planner = {}

local function emergency(reason, metadata)
	local intent = metadata and metadata.Intent or reason
	return intent == "VoidRescue" or reason == "SharkVoid" or reason == "SharkEscape"
end

function Planner.suggestHoldTime(grapple, reason, holdTime, metadata)
	local velocity = grapple
		and grapple.RootPart
		and (grapple.RootPart.AssemblyLinearVelocity or grapple.RootPart.Velocity)
	local suggested = tonumber(holdTime) or 0.14
	if velocity and grapple then
		if grapple.yVelBelowMin == true and velocity.Y > 15 then
			suggested -= 0.025
		elseif velocity.Y < -35 then
			suggested += 0.025
		end
		if grapple.allowSharkTail == true and reason == "SharkVoid" then
			suggested -= 0.015
		end
	end
	return math.clamp(suggested, 0.04, 0.36)
end

function Planner.shouldRelease(grapple, reason, metadata, controller)
	if emergency(reason, metadata) then
		return true, "emergency"
	end
	if ExitGuard and typeof(ExitGuard.canRelease) == "function" then
		local safe, reasonName = ExitGuard.canRelease(grapple, controller)
		return safe, reasonName
	end
	return true, "clear"
end

return Planner
