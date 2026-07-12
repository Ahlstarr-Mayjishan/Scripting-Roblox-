--!nocheck
--[[
	NULLSCAPE - Grappler Player Intent State
	Classifies short-lived player movement intent without interpreting cancels or repeated input.
]]

local Workspace = game:GetService("Workspace")

local IntentState = {
	Entries = setmetatable({}, { __mode = "k" }),
}

local SAMPLE_INTERVAL = 0.05
local COMMIT_TIME = 0.12
local AIM_STABILITY_DOT = math.cos(math.rad(12))

local function horizontal(vector)
	if typeof(vector) ~= "Vector3" then
		return Vector3.zero
	end

	local flat = Vector3.new(vector.X, 0, vector.Z)
	return flat.Magnitude > 0.001 and flat.Unit or Vector3.zero
end

local function getAimDirection(grapple)
	local rootPart = grapple and grapple.RootPart
	local camera = Workspace.CurrentCamera
	if not (rootPart and camera) then
		return Vector3.zero
	end

	return camera.CFrame.LookVector.Unit
end

local function getVelocity(rootPart)
	return rootPart and (rootPart.AssemblyLinearVelocity or rootPart.Velocity) or Vector3.zero
end

local function isAirborne(grapple)
	local humanoid = grapple and grapple.Humanoid
	if not humanoid then
		return false
	end

	return humanoid.FloorMaterial == Enum.Material.Air
end

function IntentState.shouldSample(grapple)
	local entry = grapple and IntentState.Entries[grapple]
	return not entry or time() - entry.SampledAt >= SAMPLE_INTERVAL
end

function IntentState.observe(grapple, aimDirection)
	if not grapple then
		return nil
	end

	local now = time()
	local entry = IntentState.Entries[grapple]
	if entry and now - entry.SampledAt < SAMPLE_INTERVAL then
		return entry
	end

	local rootPart = grapple.RootPart
	local humanoid = grapple.Humanoid
	if not (rootPart and rootPart.Parent) then
		IntentState.Entries[grapple] = nil
		return nil
	end

	if typeof(aimDirection) ~= "Vector3" or aimDirection.Magnitude <= 0.001 then
		aimDirection = getAimDirection(grapple)
	else
		aimDirection = aimDirection.Unit
	end
	local velocity = getVelocity(rootPart)
	local moveDirection = humanoid and humanoid.MoveDirection or Vector3.zero
	local flatAim = horizontal(aimDirection)
	local flatMove = horizontal(moveDirection)
	local flatVelocity = horizontal(velocity)
	local aimDot = entry and entry.AimDirection and aimDirection:Dot(entry.AimDirection) or 1
	local stableSince = entry and entry.StableSince or now
	if aimDot < AIM_STABILITY_DOT then
		stableSince = now
	end

	local moveAlignment = flatMove.Magnitude > 0 and flatMove:Dot(flatAim) or nil
	local velocityAlignment = flatVelocity.Magnitude > 0 and flatVelocity:Dot(flatAim) or nil
	local explicitAim = (entry and entry.ExplicitUntil or -1000) >= now
	explicitAim = explicitAim or grapple.specialHeld == true or grapple.charging == true
	local directionalCoherence = (moveAlignment and moveAlignment >= 0.1)
		or (flatVelocity.Magnitude >= 10 and velocityAlignment and velocityAlignment >= 0.1)
	local coherence = 0.5
	if moveAlignment then
		coherence += moveAlignment >= 0.1 and 0.25 or -0.2
	end
	if flatVelocity.Magnitude >= 10 then
		coherence += velocityAlignment and (velocityAlignment >= 0.1 and 0.25 or -0.15) or 0
	end
	coherence = math.clamp(coherence, 0, 1)

	local stableFor = now - stableSince
	local mode = "Explore"
	if grapple.grappleReel == true or grapple.jumpPadReel == true then
		mode = "Release"
	elseif isAirborne(grapple) and velocity.Y <= -45 then
		mode = "Recover"
	elseif flatVelocity.Magnitude >= 18 and coherence >= 0.55 then
		mode = "Traverse"
	elseif stableFor >= COMMIT_TIME and coherence >= 0.45 and (explicitAim or directionalCoherence) then
		mode = "Commit"
	end

	entry = {
		Mode = mode,
		Confidence = math.clamp((stableFor / COMMIT_TIME) * 0.55 + coherence * 0.45, 0, 1),
		AimDirection = aimDirection,
		Velocity = velocity,
		MoveDirection = moveDirection,
		MoveAlignment = moveAlignment,
		VelocityAlignment = velocityAlignment,
		StableSince = stableSince,
		StableFor = stableFor,
		SampledAt = now,
		ExplicitUntil = entry and entry.ExplicitUntil or -1000,
		IsUserCommitting = mode == "Commit" or mode == "Traverse",
		AllowsDeferredCast = (mode == "Commit" or mode == "Traverse")
			and stableFor >= COMMIT_TIME
			and (explicitAim or directionalCoherence),
	}
	IntentState.Entries[grapple] = entry
	return entry
end

function IntentState.get(grapple)
	return IntentState.observe(grapple)
end

function IntentState.noteCastIntent(grapple, aimDirection)
	if not grapple then
		return nil
	end

	local now = time()
	local entry = IntentState.Entries[grapple] or {}
	entry.ExplicitUntil = now + 1.15
	entry.StableSince = math.min(entry.StableSince or now, now - COMMIT_TIME)
	entry.SampledAt = -1000
	if typeof(aimDirection) == "Vector3" and aimDirection.Magnitude > 0.001 then
		entry.AimDirection = aimDirection.Unit
	end
	IntentState.Entries[grapple] = entry
	return IntentState.observe(grapple, aimDirection)
end

function IntentState.clear(grapple)
	if grapple then
		IntentState.Entries[grapple] = nil
	else
		table.clear(IntentState.Entries)
	end
end

return IntentState
