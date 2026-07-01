--!nocheck
-- [[
--  NULLSCAPE - Movement Context Momentum Memory
--  Tracks recent velocity samples and class-tech momentum injections.
-- ]]

local Workspace = game:GetService("Workspace")

local MomentumMemory = {
	Samples = {},
	Impulses = {},
}

local SAMPLE_TTL = 1.25
local IMPULSE_TTL = 1.5
local partIds = setmetatable({}, { __mode = "k" })
local nextPartId = 0

local function now()
	return time()
end

local function isAlive(instance)
	return instance and instance.Parent ~= nil and instance:IsDescendantOf(Workspace)
end

local function getPartId(part)
	if not part then
		return nil
	end

	local existing = partIds[part]
	if existing then
		return existing
	end

	nextPartId += 1
	local id = "part:" .. tostring(nextPartId)
	partIds[part] = id
	return id
end

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getVelocity(rootPart)
	return rootPart.AssemblyLinearVelocity or rootPart.Velocity
end

local function pruneStale(id, currentTime)
	local samples = MomentumMemory.Samples[id]
	if samples then
		for i = #samples, 1, -1 do
			if currentTime - samples[i].At > SAMPLE_TTL then
				table.remove(samples, i)
			end
		end
		if #samples == 0 then
			MomentumMemory.Samples[id] = nil
		end
	end

	local impulses = MomentumMemory.Impulses[id]
	if impulses then
		for i = #impulses, 1, -1 do
			if currentTime - impulses[i].At > IMPULSE_TTL then
				table.remove(impulses, i)
			end
		end
		if #impulses == 0 then
			MomentumMemory.Impulses[id] = nil
		end
	end
end

function MomentumMemory.record(rootPart, source)
	if not isAlive(rootPart) then
		return nil
	end

	local currentTime = now()
	local id = getPartId(rootPart)
	local velocity = getVelocity(rootPart)
	local samples = MomentumMemory.Samples[id] or {}
	MomentumMemory.Samples[id] = samples

	table.insert(samples, {
		At = currentTime,
		Source = source or "sample",
		Velocity = velocity,
		HorizontalSpeed = flatten(velocity).Magnitude,
		VerticalSpeed = math.abs(velocity.Y),
	})

	pruneStale(id, currentTime)
	return samples[#samples]
end

function MomentumMemory.noteImpulse(rootPart, source, beforeVelocity, afterVelocity, appliedDelta, metadata)
	if not isAlive(rootPart) then
		return nil
	end
	if typeof(beforeVelocity) ~= "Vector3" or typeof(afterVelocity) ~= "Vector3" then
		return nil
	end

	local currentTime = now()
	local id = getPartId(rootPart)
	local impulses = MomentumMemory.Impulses[id] or {}
	MomentumMemory.Impulses[id] = impulses

	local delta = typeof(appliedDelta) == "Vector3" and appliedDelta or afterVelocity - beforeVelocity
	local impulse = {
		At = currentTime,
		Source = source or "unknown",
		Before = beforeVelocity,
		After = afterVelocity,
		Delta = delta,
		HorizontalDelta = flatten(delta).Magnitude,
		VerticalDelta = math.abs(delta.Y),
		Metadata = metadata or {},
	}

	table.insert(impulses, impulse)
	pruneStale(id, currentTime)
	return impulse
end

function MomentumMemory.getState(rootPart, impulseWindow)
	if not isAlive(rootPart) then
		return nil
	end

	local currentTime = now()
	local id = getPartId(rootPart)
	pruneStale(id, currentTime)

	local velocity = getVelocity(rootPart)
	local samples = MomentumMemory.Samples[id] or {}
	local previous = samples[#samples]
	local acceleration = Vector3.zero
	if previous and previous.At and currentTime > previous.At then
		acceleration = (velocity - previous.Velocity) / math.max(currentTime - previous.At, 1 / 240)
	end

	local recentHorizontalImpulse = 0
	local recentVerticalImpulse = 0
	local recentSources = {}
	local window = tonumber(impulseWindow) or 0.35
	for _, impulse in ipairs(MomentumMemory.Impulses[id] or {}) do
		if currentTime - impulse.At <= window then
			recentHorizontalImpulse += impulse.HorizontalDelta or 0
			recentVerticalImpulse += impulse.VerticalDelta or 0
			recentSources[impulse.Source] = true
		end
	end

	return {
		Velocity = velocity,
		HorizontalSpeed = flatten(velocity).Magnitude,
		VerticalSpeed = math.abs(velocity.Y),
		Acceleration = acceleration,
		RecentHorizontalImpulse = recentHorizontalImpulse,
		RecentVerticalImpulse = recentVerticalImpulse,
		RecentSources = recentSources,
		SampledAt = currentTime,
	}
end

function MomentumMemory.clear()
	table.clear(MomentumMemory.Samples)
	table.clear(MomentumMemory.Impulses)
end

return MomentumMemory
