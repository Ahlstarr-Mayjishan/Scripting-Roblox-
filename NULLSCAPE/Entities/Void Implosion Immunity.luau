--!nocheck
-- [[
--  NULLSCAPE - Void Implosion Immunity
--  Prevents the client-side greater-curse handler from scheduling implosion hits.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
	Connections = {},
	DisabledConnections = setmetatable({}, { __mode = "k" }),
	Enabled = false,
}

local function suppressCallback(connection)
	if Logic.DisabledConnections[connection] then
		return
	end

	local disabled = pcall(function()
		connection:Disable()
	end)
	if disabled then
		Logic.DisabledConnections[connection] = true
	end
end

local function suppressRemote(remote)
	if not (Logic.Enabled and remote and remote:IsA("RemoteEvent") and remote.Name == "VoidImplosion") then
		return
	end
	if typeof(getconnections) ~= "function" then
		return
	end

	local ok, connections = pcall(getconnections, remote.OnClientEvent)
	if not ok or typeof(connections) ~= "table" then
		return
	end

	for _, connection in ipairs(connections) do
		suppressCallback(connection)
	end
end

local function disconnectObservers()
	for _, connection in ipairs(Logic.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(Logic.Connections)
end

local function restoreCallbacks()
	for connection in pairs(Logic.DisabledConnections) do
		pcall(function()
			connection:Enable()
		end)
	end
	Logic.DisabledConnections = setmetatable({}, { __mode = "k" })
end

function Logic.enable()
	if Logic.Enabled then
		return true
	end

	Logic.Enabled = true
	local events = ReplicatedStorage:FindFirstChild("Events")
	local remote = events and events:FindFirstChild("VoidImplosion")
	suppressRemote(remote)

	if events then
		table.insert(Logic.Connections, events.ChildAdded:Connect(suppressRemote))
	end

	return true
end

function Logic.disable()
	if not Logic.Enabled and #Logic.Connections == 0 and next(Logic.DisabledConnections) == nil then
		return
	end

	Logic.Enabled = false
	disconnectObservers()
	restoreCallbacks()
end

return Logic
