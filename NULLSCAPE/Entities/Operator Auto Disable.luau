--!nocheck

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Logic = {
	Enabled = false,
	HookedTarget = nil,
	HookedScript = nil,
	OriginalStationary = nil,
	EnemiesRoot = nil,
	InstallGeneration = 0,
	Connections = {},
}

local INSTALL_RETRY_DELAYS = { 0, 0.05, 0.15, 0.35, 0.75 }

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

local function getOperatorScript(fn)
	local environment = getFunctionEnvironment(fn)
	local sourceScript = environment and environment.script
	if typeof(sourceScript) ~= "Instance" or sourceScript.Name ~= "Operator_AI" then
		return nil
	end

	local parent = sourceScript.Parent
	return parent ~= nil and parent.Name == "Operator" and sourceScript or nil
end

local function isOperatorFunction(fn)
	return getOperatorScript(fn) ~= nil
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
					return upvalue, getOperatorScript(callback)
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
	Logic.HookedScript = nil
	Logic.OriginalStationary = nil
end

local function installHook()
	if
		Logic.HookedTarget
		and Logic.HookedScript
		and Logic.HookedScript:IsDescendantOf(Workspace)
		and Logic.OriginalStationary
	then
		return true
	end
	restoreHook()

	local hookFunction = getExecutorFunction("hookfunction")
	if not hookFunction then
		return false
	end

	local target, sourceScript = findStationaryPredicate()
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
	Logic.HookedScript = sourceScript
	Logic.OriginalStationary = original
	return true
end

local function disconnect(name)
	local connection = Logic.Connections[name]
	if connection then
		connection:Disconnect()
		Logic.Connections[name] = nil
	end
end

local function isOperatorScript(instance)
	return instance:IsA("BaseScript")
		and instance.Name == "Operator_AI"
		and instance.Parent ~= nil
		and instance.Parent.Name == "Operator"
end

local function scheduleInstall()
	Logic.InstallGeneration += 1
	local generation = Logic.InstallGeneration

	task.spawn(function()
		for _, delaySeconds in ipairs(INSTALL_RETRY_DELAYS) do
			if delaySeconds > 0 then
				task.wait(delaySeconds)
			end
			if not Logic.Enabled or generation ~= Logic.InstallGeneration then
				return
			end
			if installHook() then
				return
			end
		end
	end)
end

local function attachEnemiesRoot(enemiesRoot)
	if Logic.EnemiesRoot == enemiesRoot then
		return
	end

	disconnect("OperatorAdded")
	disconnect("OperatorRemoving")
	Logic.EnemiesRoot = enemiesRoot
	Logic.Connections.OperatorAdded = enemiesRoot.DescendantAdded:Connect(function(instance)
		if isOperatorScript(instance) then
			scheduleInstall()
		end
	end)
	Logic.Connections.OperatorRemoving = enemiesRoot.DescendantRemoving:Connect(function(instance)
		if instance == Logic.HookedScript then
			Logic.InstallGeneration += 1
			restoreHook()
		end
	end)

	local operator = enemiesRoot:FindFirstChild("Operator")
	local operatorScript = operator and operator:FindFirstChild("Operator_AI", true)
	if operatorScript and isOperatorScript(operatorScript) then
		scheduleInstall()
	end
end

local function startLifecycle()
	local enemiesRoot = Workspace:FindFirstChild("Enemies")
	if enemiesRoot then
		attachEnemiesRoot(enemiesRoot)
	else
		scheduleInstall()
	end

	Logic.Connections.EnemiesRootAdded = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Enemies" then
			attachEnemiesRoot(child)
		end
	end)
end

local function stopLifecycle()
	Logic.InstallGeneration += 1
	disconnect("OperatorAdded")
	disconnect("OperatorRemoving")
	disconnect("EnemiesRootAdded")
	Logic.EnemiesRoot = nil
end

function Logic.setEnabled(enabled)
	enabled = enabled == true
	if enabled and Logic.Enabled then
		return true
	end

	Logic.Enabled = enabled
	if not Logic.Enabled then
		stopLifecycle()
		restoreHook()
		return true
	end

	if
		not getExecutorFunction("hookfunction")
		or not getExecutorFunction("getconnections")
		or not getExecutorFunction("getconstants")
		or not getExecutorFunction("getfenv")
		or (not getExecutorFunction("getupvalues") and not getExecutorFunction("getupvalue"))
	then
		Logic.Enabled = false
		return false
	end

	startLifecycle()
	return true
end

function Logic.disable()
	Logic.Enabled = false
	stopLifecycle()
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
