--!nocheck
--[[
	NULLSCAPE - Gift Farm Mode Isolation
	Keeps Normal and Pipelining mode sessions from sharing stale movement tasks.
]]

local ModeIsolation = {}

local activeMode = nil
local activeToken = 0

function ModeIsolation.enter(mode)
	if activeMode ~= mode then
		activeToken += 1
		activeMode = mode
	end
	return activeToken
end

function ModeIsolation.leave(mode, token)
	if activeMode == mode and (token == nil or token == activeToken) then
		activeToken += 1
		activeMode = nil
	end
	return activeToken
end

function ModeIsolation.isActive(mode, token)
	return activeMode == mode and token == activeToken
end

function ModeIsolation.current()
	return activeMode, activeToken
end

return ModeIsolation
