--!nocheck
-- [[
--  NULLSCAPE - Grapple Momentum Transfer
-- ]]

local MomentumTransfer = {}

local CachedControl = nil

local function getControl()
	if CachedControl then
		return CachedControl
	end
	CachedControl = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	return CachedControl
end

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

function MomentumTransfer.apply(grapple)
	if not grapple or not grapple.RootPart or not grapple.ropeAttachment then
		return
	end

	local Control = getControl()
	local percent = Control and Control.GrappleMomentumTransferPercent or 0
	if percent <= 0 then
		return
	end

	local globals = getGlobals()
	local lastReleaseSpeed = globals.GrappleLastReleaseSpeed or 0
	local lastReleaseAt = globals.GrappleLastReleaseAt or 0

	-- Only transfer if we cast within 1.5 seconds of releasing the last grapple
	if time() - lastReleaseAt > 1.5 or lastReleaseSpeed < 10 then
		return
	end

	local A = grapple.ropeAttachment.WorldPosition
	local rootPart = grapple.RootPart
	local P = rootPart.Position
	local R = (P - A).Unit
	local V = rootPart.Velocity

	-- Project current velocity onto the tangential plane of the new anchor
	local V_tangent = V - V:Dot(R) * R
	if V_tangent.Magnitude > 0.1 then
		-- Preserve the speed based on the multiplier (percent / 100)
		local targetSpeed = math.max(V.Magnitude, lastReleaseSpeed) * (percent / 100)
		rootPart.Velocity = V_tangent.Unit * targetSpeed
	end
end

return MomentumTransfer
