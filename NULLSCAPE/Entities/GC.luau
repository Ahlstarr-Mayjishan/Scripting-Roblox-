-- [[
--  NULLSCAPE - Entities Garbage Collector (GC)
--  Restores owned mutations and releases entity-scoped resources.
-- ]]

local getgenv = getgenv
local TouchInterest = getgenv().loadModule("NULLSCAPE/Entities/TouchInterest.luau")
local HuskEvasion = getgenv().loadModule("NULLSCAPE/Entities/HuskEvasion.luau")
local SpecialImmunity = getgenv().loadModule("NULLSCAPE/Entities/SpecialImmunity.luau")

local GC = {
	ActiveConnections = {},
	EntityConnections = {},
	SavedPartsData = setmetatable({}, { __mode = "k" }),
}

getgenv()._NULLSCAPE_Globals = getgenv()._NULLSCAPE_Globals or {}
getgenv()._NULLSCAPE_Globals.NullscapeEntitiesGC = GC

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
	pcall(function()
		TouchInterest.restoreAll(GC)
	end)

	pcall(function()
		HuskEvasion.disableHuskImmunity(GC)
	end)

	pcall(function()
		SpecialImmunity.disable()
	end)

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
