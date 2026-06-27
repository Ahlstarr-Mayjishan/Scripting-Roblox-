--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Health Monitor
--  Keeps experimental assist branches from taking down the core Grapple hooks.
-- ]]

local HealthMonitor = {
	ErrorWindow = 8,
	ErrorLimit = 3,
	Cooldown = 12,
	States = {},
	LastStatus = "Core OK",
	LastStatusAt = 0,
}

local function now()
	return os.clock()
end

local function packValues(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local function getState(name)
	local state = HealthMonitor.States[name]
	if not state then
		state = {
			Errors = 0,
			WindowStartedAt = 0,
			DisabledUntil = 0,
			LastError = nil,
			LastErrorAt = 0,
		}
		HealthMonitor.States[name] = state
	end
	return state
end

function HealthMonitor.isEnabled(name)
	local state = getState(name)
	return now() >= (state.DisabledUntil or 0)
end

function HealthMonitor.recordSuccess(name)
	local state = getState(name)
	if now() - (state.WindowStartedAt or 0) > HealthMonitor.ErrorWindow then
		state.Errors = 0
		state.WindowStartedAt = now()
	end
end

function HealthMonitor.recordError(name, err)
	local state = getState(name)
	local currentTime = now()

	if currentTime - (state.WindowStartedAt or 0) > HealthMonitor.ErrorWindow then
		state.Errors = 0
		state.WindowStartedAt = currentTime
	end

	state.Errors = (state.Errors or 0) + 1
	state.LastError = tostring(err)
	state.LastErrorAt = currentTime

	if state.Errors >= HealthMonitor.ErrorLimit then
		state.DisabledUntil = currentTime + HealthMonitor.Cooldown
		state.Errors = 0
		HealthMonitor.LastStatus = tostring(name) .. " paused"
		HealthMonitor.LastStatusAt = currentTime
		warn("[NULLSCAPE] Grappler Assist branch paused: " .. tostring(name) .. " -> " .. tostring(err))
	else
		HealthMonitor.LastStatus = tostring(name) .. " error"
		HealthMonitor.LastStatusAt = currentTime
		warn("[NULLSCAPE] Grappler Assist branch error: " .. tostring(name) .. " -> " .. tostring(err))
	end
end

function HealthMonitor.try(name, callback, ...)
	if not HealthMonitor.isEnabled(name) then
		return false, nil
	end

	local results = packValues(pcall(callback, ...))
	local success = results[1]
	if not success then
		HealthMonitor.recordError(name, results[2])
		return false, nil
	end

	HealthMonitor.recordSuccess(name)
	results[1] = true
	return table.unpack(results, 1, results.n)
end

function HealthMonitor.getStatus()
	local activePauses = {}
	local currentTime = now()
	for name, state in pairs(HealthMonitor.States) do
		if (state.DisabledUntil or 0) > currentTime then
			table.insert(activePauses, tostring(name))
		end
	end
	table.sort(activePauses)

	if #activePauses > 0 then
		return "Core OK / paused: " .. table.concat(activePauses, ", ")
	end

	return HealthMonitor.LastStatus or "Core OK"
end

function HealthMonitor.reset()
	table.clear(HealthMonitor.States)
	HealthMonitor.LastStatus = "Core OK"
	HealthMonitor.LastStatusAt = now()
end

return HealthMonitor
