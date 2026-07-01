--!nocheck
-- [[
--  NULLSCAPE - Grappler Bad Anchor Memory
--  Temporary runtime penalty cache for anchors that look unsafe or repeatedly fail safety checks.
-- ]]

local Workspace = game:GetService("Workspace")

local BadAnchorMemory = {}

local DEFAULT_TTL = 7
local MAX_PENALTY = 60
local STORE = {}

local function isAlive(part)
	return part and part.Parent ~= nil and part:IsDescendantOf(Workspace)
end

local function getKey(part)
	if not (part and typeof(part.GetDebugId) == "function") then
		return nil
	end

	local success, id = pcall(function()
		return part:GetDebugId(0)
	end)
	return success and id or nil
end

local function prune(now)
	now = now or time()
	for key, entry in pairs(STORE) do
		if entry.ExpiresAt <= now or not isAlive(entry.Part) then
			STORE[key] = nil
		end
	end
end

function BadAnchorMemory.note(part, reason, severity, ttl)
	local key = getKey(part)
	if not key then
		return nil
	end

	local now = time()
	prune(now)

	local entry = STORE[key]
	if not entry then
		entry = {
			Part = part,
			Reasons = {},
			Score = 0,
			LastSeen = now,
			ExpiresAt = now,
		}
		STORE[key] = entry
	end

	entry.Part = part
	entry.LastSeen = now
	entry.ExpiresAt = math.max(entry.ExpiresAt, now + (tonumber(ttl) or DEFAULT_TTL))
	entry.Score = math.clamp((entry.Score or 0) + (tonumber(severity) or 1), 0, MAX_PENALTY)
	if reason then
		entry.Reasons[tostring(reason)] = now
	end

	return entry
end

function BadAnchorMemory.noteGood(part)
	local key = getKey(part)
	local entry = key and STORE[key]
	if not entry then
		return
	end

	entry.Score = math.max(0, (entry.Score or 0) - 10)
	if entry.Score <= 0 then
		STORE[key] = nil
	end
end

function BadAnchorMemory.getPenalty(part)
	local key = getKey(part)
	if not key then
		return 0
	end

	local now = time()
	prune(now)

	local entry = STORE[key]
	if not entry then
		return 0
	end

	local remaining = math.clamp((entry.ExpiresAt - now) / DEFAULT_TTL, 0, 1)
	return math.clamp((entry.Score or 0) * remaining, 0, MAX_PENALTY)
end

function BadAnchorMemory.clear()
	table.clear(STORE)
end

return BadAnchorMemory
