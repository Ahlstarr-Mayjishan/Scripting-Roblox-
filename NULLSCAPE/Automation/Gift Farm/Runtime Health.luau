--!nocheck
-- [[
--  NULLSCAPE - Gift Farm Runtime Health
--  Conservatively detects sustained client degradation without predicting crashes.
-- ]]

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local RuntimeHealth = {}

local SAMPLE_WINDOW = 2
local LOW_FPS_LIMIT = 12
local LOW_FPS_HOLD = 20
local STALL_SECONDS = 2.5
local SUSPENSION_SECONDS = 15
local STALL_RETENTION = 90
local STALL_LIMIT = 2
local MEMORY_SAMPLE_INTERVAL = 5
local MOBILE_MEMORY_LIMIT_MB = 1800
local DESKTOP_MEMORY_LIMIT_MB = 3200
local MEMORY_GROWTH_LIMIT_MB = 700

local isMobile = UserInputService.TouchEnabled
	and not (UserInputService.KeyboardEnabled and UserInputService.MouseEnabled)

local state = {
	Active = false,
	Focused = true,
	Connection = nil,
	FocusConnection = nil,
	BlurConnection = nil,
	WindowStartedAt = 0,
	WindowFrames = 0,
	FPS = 0,
	LowFPSSince = nil,
	LastMemorySampleAt = -math.huge,
	MemoryMB = 0,
	BaselineMemoryMB = nil,
	Stalls = {},
	Unhealthy = false,
	Reason = nil,
}

local function disconnect(name)
	local connection = state[name]
	state[name] = nil
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function clearWindow(now)
	state.WindowStartedAt = now
	state.WindowFrames = 0
	state.LowFPSSince = nil
end

local function trimStalls(now)
	local writeIndex = 1
	for _, timestamp in ipairs(state.Stalls) do
		if now - timestamp <= STALL_RETENTION then
			state.Stalls[writeIndex] = timestamp
			writeIndex += 1
		end
	end
	for index = #state.Stalls, writeIndex, -1 do
		state.Stalls[index] = nil
	end
end

local function markUnhealthy(reason)
	if state.Unhealthy then
		return
	end
	state.Unhealthy = true
	state.Reason = reason
end

local function sampleMemory(now)
	if now - state.LastMemorySampleAt < MEMORY_SAMPLE_INTERVAL then
		return
	end
	state.LastMemorySampleAt = now

	local ok, memory = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	if not ok or type(memory) ~= "number" or memory <= 0 then
		return
	end

	state.MemoryMB = memory
	state.BaselineMemoryMB = state.BaselineMemoryMB or memory
	state.BaselineMemoryMB = math.min(state.BaselineMemoryMB, memory)
	local hardLimit = isMobile and MOBILE_MEMORY_LIMIT_MB or DESKTOP_MEMORY_LIMIT_MB
	local growth = memory - state.BaselineMemoryMB
	if memory >= hardLimit or (memory >= hardLimit * 0.7 and growth >= MEMORY_GROWTH_LIMIT_MB) then
		markUnhealthy(string.format("client memory pressure %.0f MB", memory))
	end
end

local function onHeartbeat(deltaTime)
	if not state.Active or state.Unhealthy then
		return
	end

	local now = os.clock()
	if not state.Focused or deltaTime >= SUSPENSION_SECONDS then
		clearWindow(now)
		return
	end

	if deltaTime >= STALL_SECONDS then
		table.insert(state.Stalls, now)
	end
	trimStalls(now)
	if #state.Stalls >= STALL_LIMIT then
		markUnhealthy(string.format("scheduler stalled %d times", #state.Stalls))
		return
	end

	state.WindowFrames += 1
	local elapsed = now - state.WindowStartedAt
	if elapsed >= SAMPLE_WINDOW then
		state.FPS = state.WindowFrames / elapsed
		state.WindowStartedAt = now
		state.WindowFrames = 0
		if state.FPS < LOW_FPS_LIMIT then
			state.LowFPSSince = state.LowFPSSince or now
			if now - state.LowFPSSince >= LOW_FPS_HOLD then
				markUnhealthy(string.format("sustained low FPS %.1f", state.FPS))
				return
			end
		else
			state.LowFPSSince = nil
		end
	end

	sampleMemory(now)
end

function RuntimeHealth.start()
	if state.Active then
		return true
	end

	local now = os.clock()
	state.Active = true
	state.Focused = true
	state.FPS = 0
	state.MemoryMB = 0
	state.BaselineMemoryMB = nil
	state.LastMemorySampleAt = -math.huge
	state.Stalls = {}
	state.Unhealthy = false
	state.Reason = nil
	clearWindow(now)

	state.FocusConnection = UserInputService.WindowFocused:Connect(function()
		state.Focused = true
		clearWindow(os.clock())
	end)
	state.BlurConnection = UserInputService.WindowFocusReleased:Connect(function()
		state.Focused = false
		clearWindow(os.clock())
	end)
	state.Connection = RunService.Heartbeat:Connect(onHeartbeat)
	return true
end

function RuntimeHealth.stop()
	state.Active = false
	disconnect("Connection")
	disconnect("FocusConnection")
	disconnect("BlurConnection")
	return true
end

function RuntimeHealth.getStatus()
	return {
		Unhealthy = state.Unhealthy,
		Reason = state.Reason,
		FPS = state.FPS,
		MemoryMB = state.MemoryMB,
		StallCount = #state.Stalls,
	}
end

return RuntimeHealth
