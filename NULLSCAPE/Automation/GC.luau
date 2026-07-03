--!nocheck
-- [[
--  NULLSCAPE - Automation Garbage Collector
--  Owns cleanup for automation helpers and future background tasks.
-- ]]

local GC = {
	Connections = {},
	CleanupItems = {},
}

local function cleanupItem(item)
	if not item then
		return
	end

	if typeof(item) == "function" then
		pcall(item)
	elseif typeof(item) == "table" then
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
	elseif typeof(item) == "Instance" then
		pcall(function()
			item:Destroy()
		end)
	end
end

function GC.registerConnection(conn)
	if conn then
		table.insert(GC.Connections, conn)
	end
	return conn
end

function GC.registerCleanup(item)
	if item then
		table.insert(GC.CleanupItems, item)
	end
	return item
end

function GC.cleanAll()
	for _, conn in ipairs(GC.Connections) do
		cleanupItem(conn)
	end
	table.clear(GC.Connections)

	for _, item in ipairs(GC.CleanupItems) do
		cleanupItem(item)
	end
	table.clear(GC.CleanupItems)
end

return GC
