local GC = {
	ActiveConnections = {},
	EntityConnections = setmetatable({}, { __mode = "k" }),
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

function GC.registerConnection(connection)
	if connection then
		table.insert(GC.ActiveConnections, connection)
	end
end

function GC.cleanupEntity(instance)
	local connections = GC.EntityConnections[instance]
	if not connections then
		return
	end

	GC.EntityConnections[instance] = nil
	for _, connection in ipairs(connections) do
		cleanupItem(connection)
	end
	table.clear(connections)
end

function GC.registerEntityConnection(instance, connection)
	if not instance or not connection then
		return
	end

	local connections = GC.EntityConnections[instance]
	if not connections then
		connections = {}
		GC.EntityConnections[instance] = connections
		table.insert(connections, instance.Destroying:Connect(function()
			GC.cleanupEntity(instance)
		end))
	end
	table.insert(connections, connection)
end

function GC.cleanAll()
	for _, connection in ipairs(GC.ActiveConnections) do
		cleanupItem(connection)
	end
	table.clear(GC.ActiveConnections)

	local instances = {}
	for instance in pairs(GC.EntityConnections) do
		table.insert(instances, instance)
	end
	for _, instance in ipairs(instances) do
		GC.cleanupEntity(instance)
	end
end

return GC
