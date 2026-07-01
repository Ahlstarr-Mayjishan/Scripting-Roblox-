--!nocheck
-- [[
--  NULLSCAPE - SharkTail Cooldown Adjustment
-- ]]

local SharkTailCooldown = {}

local CachedControl = nil

local function getControl()
	if CachedControl then
		return CachedControl
	end
	CachedControl = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	return CachedControl
end

function SharkTailCooldown.apply(grapple)
	if not grapple then
		return
	end

	local Control = getControl()
	if Control and Control.GrappleSharkTailNoCooldown then
		grapple.sharkTailDisable = false
	end
end

return SharkTailCooldown
