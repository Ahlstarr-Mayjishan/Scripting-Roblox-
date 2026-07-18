--!nocheck
-- [[
--  NULLSCAPE - Grapple Reel Pull Adjustment
-- ]]

local ReelPull = {}

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")

local CachedControl = nil
local PullScaleCache = setmetatable({}, { __mode = "k" })
local LastImpulseNoteAt = setmetatable({}, { __mode = "k" })
local PROFILE_TTL = 0.5
local IMPULSE_NOTE_INTERVAL = 0.1

local function getControl()
	if CachedControl then
		return CachedControl
	end
	CachedControl = getgenv().loadModule("NULLSCAPE/Class Adjustment/Control.luau")
	return CachedControl
end

local function hasUpgrade(movement, upgradeName)
	if not (movement and typeof(movement.HasUpgrade) == "function") then
		return false
	end
	local success, result = pcall(function()
		return movement:HasUpgrade(upgradeName)
	end)
	return success and result == true
end

local function hasMovementFlag(movement, flagName)
	if not movement then
		return false
	end

	local value = movement[flagName]
	return value == true or (typeof(value) == "number" and value > 0)
end

local function characterHas(grapple, name)
	local rootPart = grapple and grapple.RootPart
	local character = rootPart and rootPart.Parent
	return character and character:FindFirstChild(name) ~= nil
end

local function getPullScale(grapple)
	local now = time()
	local cached = PullScaleCache[grapple]
	if cached and now - cached.At < PROFILE_TTL then
		return cached.Scale
	end

	local movement = grapple and grapple.Movement
	local lowGravity = hasUpgrade(movement, "AdvancedGravityCoil")
		or characterHas(grapple, "HighriseLowGravity")
		or characterHas(grapple, "Highrise")
		or hasMovementFlag(movement, "HighriseLowGravity")

	local scale = lowGravity and 0.78 or 1
	PullScaleCache[grapple] = { At = now, Scale = scale }
	return scale
end

local function applyVelocityDelta(rootPart, delta, maxDelta)
	if not (rootPart and typeof(delta) == "Vector3") then
		return false
	end
	if delta.Magnitude > maxDelta then
		delta = delta.Unit * maxDelta
	end
	if delta.Magnitude <= 0.001 then
		return false
	end

	local beforeVelocity = rootPart.Velocity
	rootPart.Velocity += delta
	local now = time()
	if
		MomentumMemory
		and typeof(MomentumMemory.noteImpulse) == "function"
		and now - (LastImpulseNoteAt[rootPart] or 0) >= IMPULSE_NOTE_INTERVAL
	then
		LastImpulseNoteAt[rootPart] = now
		pcall(MomentumMemory.noteImpulse, rootPart, "GrappleReelPull", beforeVelocity, rootPart.Velocity, delta, {
			MaxDelta = maxDelta,
		})
	end
	return true
end

function ReelPull.apply(grapple, Control)
	local rootPart = grapple and grapple.RootPart
	if not (grapple and rootPart and grapple.jumpPadReel) then
		return
	end

	Control = Control or getControl()
	local multiplier = Control and Control.GrappleReelPullMultiplier or 1.1
	if multiplier <= 1 then
		return
	end

	multiplier = 1 + (multiplier - 1) * getPullScale(grapple)

	local desiredVelocity = rootPart.Velocity * multiplier
	applyVelocityDelta(rootPart, desiredVelocity - rootPart.Velocity, 38)
end

return ReelPull
