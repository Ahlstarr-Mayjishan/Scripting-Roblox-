--!nocheck
--[[
	NULLSCAPE - Grappler Technique Arbiter
	Keeps high-priority grapple techniques from fighting each other in the same moment.
]]

local Arbiter = {
	Active = setmetatable({}, { __mode = "k" }),
}

local DEFAULT_HOLD = 0.18

local function now()
	return time()
end

local function getEntry(grapple)
	local entry = grapple and Arbiter.Active[grapple] or nil
	if entry and now() > entry.ExpiresAt then
		Arbiter.Active[grapple] = nil
		return nil
	end

	return entry
end

function Arbiter.beginFrame(grapple)
	getEntry(grapple)
end

function Arbiter.getActive(grapple)
	return getEntry(grapple)
end

function Arbiter.isBlocked(grapple, name, priority)
	local entry = getEntry(grapple)
	if not entry or entry.Name == name then
		return false
	end

	return entry.Priority >= (tonumber(priority) or 0)
end

function Arbiter.claim(grapple, name, priority, holdTime)
	if not grapple then
		return false
	end

	priority = tonumber(priority) or 0
	local entry = getEntry(grapple)
	if entry and entry.Name ~= name and entry.Priority > priority then
		return false
	end

	Arbiter.Active[grapple] = {
		Name = name,
		Priority = priority,
		ExpiresAt = now() + (tonumber(holdTime) or DEFAULT_HOLD),
	}
	return true
end

function Arbiter.release(grapple, name)
	local entry = getEntry(grapple)
	if not entry then
		return
	end

	if not name or entry.Name == name then
		Arbiter.Active[grapple] = nil
	end
end

function Arbiter.reset(grapple)
	if grapple then
		Arbiter.Active[grapple] = nil
	else
		table.clear(Arbiter.Active)
	end
end

return Arbiter
