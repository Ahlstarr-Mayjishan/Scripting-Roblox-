--!nocheck
-- [[
--  NULLSCAPE - SharkTail Cooldown Adjustment
-- ]]

local SharkTailCooldown = {}

local CachedControl = nil
local ReleaseState = setmetatable({}, { __mode = "k" })

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
	if not (Control and Control.GrappleSharkTailNoCooldown) then
		ReleaseState[grapple] = nil
		return
	end

	local releaseAt = tonumber(grapple.lastGrappleRelease)
	if not releaseAt or releaseAt <= 0 then
		ReleaseState[grapple] = nil
		return
	end

	local state = ReleaseState[grapple]
	if state == releaseAt then
		return
	end

	ReleaseState[grapple] = releaseAt
	grapple.sharkTailDisable = false
end

return SharkTailCooldown
