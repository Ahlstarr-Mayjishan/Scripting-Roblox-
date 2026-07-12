--!nocheck
--[[
	NULLSCAPE - Destroy Logic
	Quiesces feature controllers, restores native state, then lets the client remove UI resources.
]]

local Logic = {}

local SHUTDOWN_ORDER = {
	"CharacterActions",
	"FPSBoost",
	"AutomationController",
	"AccessibilityController",
	"EntitiesController",
	"UnlockController",
	"ClassAdjustmentController",
	"RuntimeUpdater",
}

local function runStep(safeStep, label, callback)
	if typeof(safeStep) == "function" then
		safeStep(label, callback)
		return
	end
	pcall(callback)
end

local function cleanupModule(name, module, safeStep)
	if typeof(module) ~= "table" then
		return
	end

	if typeof(module.CleanUp) == "function" then
		runStep(safeStep, "module " .. tostring(name), function()
			module:CleanUp()
		end)
	elseif typeof(module.disable) == "function" then
		runStep(safeStep, "module " .. tostring(name), function()
			module.disable()
		end)
	end
end

function Logic.shutdown(client, safeStep)
	if typeof(client) ~= "table" or client.NativeStateRestored then
		return false
	end

	client.ActionsStopped = true
	local modules = client.Modules or {}
	local pending = {}

	for name, module in pairs(modules) do
		if typeof(module) == "table" then
			module.Destroyed = true
			pending[name] = module
		end
	end

	for _, name in ipairs(SHUTDOWN_ORDER) do
		cleanupModule(name, pending[name], safeStep)
		pending[name] = nil
	end

	for name, module in pairs(pending) do
		if name ~= "DestroyLogic" then
			cleanupModule(name, module, safeStep)
		end
	end

	client.NativeStateRestored = true
	return true
end

function Logic.request(client)
	if client and typeof(client.Destroy) == "function" then
		return client:Destroy("User")
	end
	return false
end

return Logic
