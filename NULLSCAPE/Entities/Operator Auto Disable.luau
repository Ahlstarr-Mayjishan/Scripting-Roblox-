--!nocheck

local RunService = game:GetService("RunService")

local Logic = {
	Enabled = false,
	HookedTarget = nil,
	OriginalStationary = nil,
}

local REQUIRED_CONSTANTS = {
	PlayerMoveDirection = true,
	UsingAbility = true,
	Sliding = true,
	Fire = true,
}

local DIRECT_EXECUTOR_FUNCTIONS = {
	getconnections = getconnections,
	getconstants = getconstants,
	getfenv = getfenv,
	getupvalue = getupvalue,
	getupvalues = getupvalues,
	hookfunction = hookfunction,
}

local function getGlobals()
	local environment = getgenv()
	environment._NULLSCAPE_Globals = environment._NULLSCAPE_Globals or {}
	return environment._NULLSCAPE_Globals
end

local function getExecutorFunction(name)
	local captured = DIRECT_EXECUTOR_FUNCTIONS[name]
	if typeof(captured) == "function" then
		return captured
	end

	local environment = getgenv()
	local direct = environment[name]
	if typeof(direct) == "function" then
		return direct
	end

	local debugLibrary = environment.debug or debug
	local debugFunction = debugLibrary and debugLibrary[name]
	if typeof(debugFunction) == "function" then
		return debugFunction
	end

	return nil
end

local function getFunctionEnvironment(fn)
	local getEnvironment = getExecutorFunction("getfenv")
	if not getEnvironment then
		return nil
	end

	local success, environment = pcall(getEnvironment, fn)
	return success and environment or nil
end

local function isOperatorFunction(fn)
	local environment = getFunctionEnvironment(fn)
	local sourceScript = environment and environment.script
	if typeof(sourceScript) ~= "Instance" or sourceScript.Name ~= "Operator_AI" then
		return false
	end

	local parent = sourceScript.Parent
	return parent ~= nil and parent.Name == "Operator"
end

local function getUpvalues(fn)
	local getAllUpvalues = getExecutorFunction("getupvalues")
	if getAllUpvalues then
		local success, upvalues = pcall(getAllUpvalues, fn)
		if success and typeof(upvalues) == "table" then
			return upvalues
		end
	end

	local getUpvalue = getExecutorFunction("getupvalue")
	if not getUpvalue then
		return nil
	end

	local upvalues = {}
	for index = 1, 32 do
		local success, first, second = pcall(getUpvalue, fn, index)
		if not success or first == nil then
			break
		end
		upvalues[index] = second ~= nil and second or first
	end
	return upvalues
end

local function isStationaryPredicate(fn)
	if typeof(fn) ~= "function" or not isOperatorFunction(fn) then
		return false
	end

	local getConstants = getExecutorFunction("getconstants")
	if not getConstants then
		return false
	end

	local success, constants = pcall(getConstants, fn)
	if not success or typeof(constants) ~= "table" then
		return false
	end

	local remaining = 0
	local found = {}
	for name in pairs(REQUIRED_CONSTANTS) do
		remaining += 1
		found[name] = false
	end

	for _, constant in pairs(constants) do
		if typeof(constant) == "string" and REQUIRED_CONSTANTS[constant] and not found[constant] then
			found[constant] = true
			remaining -= 1
			if remaining == 0 then
				return true
			end
		end
	end

	return false
end

local function findStationaryPredicate()
	local getConnections = getExecutorFunction("getconnections")
	if not getConnections then
		return nil
	end

	local success, connections = pcall(getConnections, RunService.RenderStepped)
	if not success or typeof(connections) ~= "table" then
		return nil
	end

	for _, connection in ipairs(connections) do
		local callback = connection.Function
		if typeof(callback) == "function" and isOperatorFunction(callback) then
			local upvalues = getUpvalues(callback)
			for _, upvalue in pairs(upvalues or {}) do
				if isStationaryPredicate(upvalue) then
					return upvalue
				end
			end
		end
	end

	return nil
end

local function shouldReportStationary()
	if not Logic.Enabled or shared.OperatorActive ~= true then
		return false
	end

	local controller = getGlobals().activeEntitiesController
	return controller ~= nil and controller.OperatorAutoDisable == true
end

local function restoreHook()
	local hookFunction = getExecutorFunction("hookfunction")
	if Logic.HookedTarget and Logic.OriginalStationary and hookFunction then
		pcall(hookFunction, Logic.HookedTarget, Logic.OriginalStationary)
	end
	Logic.HookedTarget = nil
	Logic.OriginalStationary = nil
end

local function installHook()
	if Logic.HookedTarget and Logic.OriginalStationary then
		return true
	end
	local hookFunction = getExecutorFunction("hookfunction")
	if not hookFunction then
		return false
	end

	local target = findStationaryPredicate()
	if not target then
		return false
	end

	local original
	local success = pcall(function()
		original = hookFunction(target, function(...)
			if shouldReportStationary() then
				return true
			end
			return original(...)
		end)
	end)
	if not success or typeof(original) ~= "function" then
		return false
	end

	Logic.HookedTarget = target
	Logic.OriginalStationary = original
	return true
end

function Logic.setEnabled(enabled)
	Logic.Enabled = enabled == true
	if not Logic.Enabled then
		restoreHook()
		return true
	end

	return installHook()
end

function Logic.disable()
	Logic.Enabled = false
	restoreHook()

	local globals = getGlobals()
	if globals.OperatorAutoDisableOwner == Logic then
		globals.OperatorAutoDisableOwner = nil
		globals.OperatorAutoDisableRestore = nil
	end
end

do
	local globals = getGlobals()
	if typeof(globals.OperatorAutoDisableRestore) == "function" then
		pcall(globals.OperatorAutoDisableRestore)
	end
	globals.OperatorAutoDisableOwner = Logic
	globals.OperatorAutoDisableRestore = Logic.disable
end

return Logic
