--!nocheck
-- [[
--  NULLSCAPE - Gift Farm Safe Server Rotation
--  Queues the latest loader and moves to a different public server.
-- ]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Rotation = {}
local localPlayer = Players.LocalPlayer
local httpGet = (game :: any).HttpGet
local LOADER_URL = "https://nullscape-discord-auth.reynoldszlotapastevand.workers.dev/loader"
local SERVER_LIST_URL = "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
local RETRY_INTERVAL = 5

local state = {
	Rotating = false,
	Queued = false,
	LastAttemptAt = -math.huge,
	LastError = nil,
	TargetServerId = nil,
	FailureConnection = nil,
}

local function disconnectFailureObserver()
	local connection = state.FailureConnection
	state.FailureConnection = nil
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function getQueueFunction()
	local environment = getgenv()
	local candidates = {
		environment and environment.queue_on_teleport,
		environment and environment.queueonteleport,
		environment and environment.syn and environment.syn.queue_on_teleport,
	}
	for _, candidate in ipairs(candidates) do
		if typeof(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

local function buildQueuedLoader()
	return string.format(
		[[
task.wait(1)
local HttpService = game:GetService("HttpService")
local url = %q .. "?nullscape_rotate=" .. HttpService:UrlEncode(tostring(os.time()) .. "-" .. HttpService:GenerateGUID(false))
local requestFn = request or http_request or (http and http.request) or (syn and syn.request)
local ok, source = pcall(function()
	if typeof(requestFn) == "function" then
		local response = requestFn({ Url = url, Method = "GET", Headers = { ["Cache-Control"] = "no-cache" } })
		local statusCode = tonumber(response and (response.StatusCode or response.Status)) or 0
		if statusCode ~= 200 then
			error("HTTP " .. tostring(statusCode))
		end
		return response and (response.Body or response.body)
	end
	return game:HttpGet(url)
end)
if ok and typeof(source) == "string" and #source > 0 then
	local chunk, compileError = loadstring(source)
	if chunk then
		chunk()
	else
		warn("[NULLSCAPE] Queued loader compile failed: " .. tostring(compileError))
	end
else
	warn("[NULLSCAPE] Queued loader download failed: " .. tostring(source))
end
]],
		LOADER_URL
	)
end

local function queueLatestLoader()
	if state.Queued then
		return true
	end
	local queue = getQueueFunction()
	if not queue then
		return false, "executor does not expose queue_on_teleport"
	end
	local ok, err = pcall(queue, buildQueuedLoader())
	if not ok then
		return false, tostring(err)
	end
	state.Queued = true
	return true
end

local function findPublicServer()
	local placeId = tonumber(game.PlaceId) or 0
	if placeId <= 0 then
		return nil
	end

	local ok, response = pcall(function()
		return httpGet(game, string.format(SERVER_LIST_URL, placeId))
	end)
	if not ok or typeof(response) ~= "string" then
		return nil
	end

	local decodedOk, payload = pcall(HttpService.JSONDecode, HttpService, response)
	if not decodedOk or typeof(payload) ~= "table" or typeof(payload.data) ~= "table" then
		return nil
	end

	for _, server in ipairs(payload.data) do
		local serverId = typeof(server) == "table" and server.id or nil
		local playing = typeof(server) == "table" and tonumber(server.playing) or nil
		local capacity = typeof(server) == "table" and tonumber(server.maxPlayers) or nil
		if
			typeof(serverId) == "string"
			and serverId ~= ""
			and serverId ~= game.JobId
			and playing
			and capacity
			and playing < capacity
		then
			return serverId
		end
	end
	return nil
end

local function observeTeleportFailure()
	disconnectFailureObserver()
	state.FailureConnection = TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		if player ~= localPlayer then
			return
		end
		state.Rotating = false
		state.LastError = string.format("%s: %s", tostring(result), tostring(message))
		disconnectFailureObserver()
	end)
end

function Rotation.begin()
	if state.Rotating then
		return true
	end
	local now = os.clock()
	if now - state.LastAttemptAt < RETRY_INTERVAL then
		return false, state.LastError or "waiting before retry"
	end
	state.LastAttemptAt = now

	local queued, queueError = queueLatestLoader()
	if not queued then
		state.LastError = queueError
		return false, queueError
	end

	local targetServerId = findPublicServer()
	state.TargetServerId = targetServerId
	state.Rotating = true
	state.LastError = nil
	observeTeleportFailure()

	local ok, teleportError = pcall(function()
		if targetServerId then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServerId, localPlayer)
		else
			TeleportService:Teleport(game.PlaceId, localPlayer)
		end
	end)
	if not ok then
		state.Rotating = false
		state.LastError = tostring(teleportError)
		disconnectFailureObserver()
		return false, state.LastError
	end
	return true
end

function Rotation.reset()
	state.Rotating = false
	state.Queued = false
	state.LastAttemptAt = -math.huge
	state.LastError = nil
	state.TargetServerId = nil
	disconnectFailureObserver()
end

function Rotation.getState()
	return state
end

return Rotation
