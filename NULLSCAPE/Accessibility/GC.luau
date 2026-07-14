-- [[
--  NULLSCAPE - Accessibility Garbage Collector (GC)
--  Tracks and releases shared and per-entity event connections.
-- ]]

local GC = {
	ActiveConnections = {},
	EntityConnections = {},
}

local function cleanupItem(item)
	if not item then
		return
	end
	local itemType = typeof(item)
	if itemType == "RBXScriptConnection" then
		pcall(function()
			item:Disconnect()
		end)
	elseif itemType == "function" then
		pcall(item)
	elseif itemType == "table" then
		if typeof(item.Disconnect) == "function" then
			pcall(function()
				item:Disconnect()
			end)
		elseif typeof(item.disconnect) == "function" then
			pcall(item.disconnect)
		elseif typeof(item.Destroy) == "function" then
			pcall(function()
				item:Destroy()
			end)
		elseif typeof(item.destroy) == "function" then
			pcall(item.destroy)
		end
	elseif itemType == "Instance" then
		pcall(function()
			item:Destroy()
		end)
	end
end

function GC.registerConnection(conn)
	if conn then
		table.insert(GC.ActiveConnections, conn)
	end
end

function GC.registerEntityConnection(enemy, conn)
	if not enemy or not conn then
		return
	end
	GC.EntityConnections[enemy] = GC.EntityConnections[enemy] or {}
	table.insert(GC.EntityConnections[enemy], conn)
end

function GC.removeEntityConnections(enemy)
	if not enemy then
		return
	end
	local connections = GC.EntityConnections[enemy]
	if connections then
		for _, conn in ipairs(connections) do
			cleanupItem(conn)
		end
		GC.EntityConnections[enemy] = nil
	end
end

function GC.cleanAll()
	for _, connections in pairs(GC.EntityConnections) do
		for _, conn in ipairs(connections) do
			cleanupItem(conn)
		end
	end
	table.clear(GC.EntityConnections)

	for _, conn in ipairs(GC.ActiveConnections) do
		cleanupItem(conn)
	end
	table.clear(GC.ActiveConnections)
end

return GC
