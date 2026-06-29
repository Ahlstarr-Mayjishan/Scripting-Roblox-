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
	if typeof(item) == "function" then
		pcall(item)
	elseif typeof(item) == "table" then
		if typeof(item.Disconnect) == "function" then
			pcall(function()
				item:Disconnect()
			end)
		elseif typeof(item.Destroy) == "function" then
			pcall(function()
				item:Destroy()
			end)
		end
	elseif typeof(item) == "Instance" then
		if item:IsA("RBXScriptConnection") then
			pcall(function()
				item:Disconnect()
			end)
		else
			pcall(function()
				item:Destroy()
			end)
		end
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
