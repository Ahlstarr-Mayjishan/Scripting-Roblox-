--!nocheck
-- [[
--  NULLSCAPE - Rail Memory Proxy
--  Lazy wrapper to avoid re-entrant Rail Memory loads during Grappler Assist bootstrap.
-- ]]

local MODULE_PATH = "NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory.luau"

local Proxy = {}
local CachedRailMemory = nil
local Loading = false

local function getRailMemory()
	if CachedRailMemory then
		return CachedRailMemory
	end
	if Loading then
		return nil
	end
	if not (getgenv and typeof(getgenv().loadModule) == "function") then
		return nil
	end

	Loading = true
	local success, module = pcall(function()
		return getgenv().loadModule(MODULE_PATH)
	end)
	Loading = false

	if success and typeof(module) == "table" then
		CachedRailMemory = module
		return module
	end

	return nil
end

function Proxy.isRailPart(part)
	local railMemory = getRailMemory()
	return railMemory and typeof(railMemory.isRailPart) == "function" and railMemory.isRailPart(part) or false
end

function Proxy.refreshBudgeted(scanBudget)
	local railMemory = getRailMemory()
	if railMemory and typeof(railMemory.refreshBudgeted) == "function" then
		return railMemory.refreshBudgeted(scanBudget)
	end
	return nil
end

function Proxy.getNearbyRails(origin, radius)
	local railMemory = getRailMemory()
	if railMemory and typeof(railMemory.getNearbyRails) == "function" then
		return railMemory.getNearbyRails(origin, radius)
	end
	return {}
end

function Proxy.clear()
	local railMemory = getRailMemory()
	if railMemory and typeof(railMemory.clear) == "function" then
		return railMemory.clear()
	end
	return nil
end

return Proxy
