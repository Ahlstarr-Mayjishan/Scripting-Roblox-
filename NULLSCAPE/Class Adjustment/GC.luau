--!nocheck
-- [[
--  NULLSCAPE - Class Adjustment Garbage Collector (GC)
-- ]]

local GC = {
	ActiveConnections = {},
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
		elseif typeof(item.Destroy) == "function" then
			pcall(function()
				item:Destroy()
			end)
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

function GC.cleanAll()
	for _, conn in ipairs(GC.ActiveConnections) do
		cleanupItem(conn)
	end
	table.clear(GC.ActiveConnections)
end

return GC
