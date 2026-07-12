--!nocheck
-- [[
--  NULLSCAPE - Accessibility Executor
--  Dispatches accessibility modules with fail-soft loading so one broken helper
--  cannot take down the whole Accessibility tab.
-- ]]

local MODULE_PATHS = {
	SpringerLogic = "NULLSCAPE/Accessibility/Auto jump - Springer.luau",
	InfiniteAirJump = "NULLSCAPE/Accessibility/Infinite Air Jump.luau",
	AntiBonk = "NULLSCAPE/Accessibility/Anti Bonk.luau",
	MomentumGuard = "NULLSCAPE/Accessibility/Momentum Guard.luau",
	StaminaAssist = "NULLSCAPE/Accessibility/Stamina Assist.luau",
	RailAssist = "NULLSCAPE/Accessibility/Rail Assist.luau",
	GrappleAssist = "NULLSCAPE/Accessibility/Grappler assistments/Grapple Assist.luau",
	CurseVisualAssist = "NULLSCAPE/Accessibility/Curse Visual Assist.luau",
}

local Modules = {}
local ModuleFailures = {}
local LoadingModules = {}
local PendingCalls = {}
local PendingAttempts = {}
local Executor = {}
local callModule

local LOAD_RETRY_COOLDOWN = 1.5
local CALL_RETRY_COOLDOWN = 0.75
local PENDING_RETRY_DELAY = 0.12
local PENDING_RETRY_LIMIT = 6

local function getNow()
	return time()
end

local function isQuarantined(name, kind)
	local failure = ModuleFailures[name]
	if not failure then
		return false
	end

	local cooldown = kind == "call" and CALL_RETRY_COOLDOWN or LOAD_RETRY_COOLDOWN
	return getNow() - (failure.At or 0) < cooldown
end

local function markFailure(name, phase, err)
	ModuleFailures[name] = {
		At = getNow(),
		Phase = phase,
		Error = tostring(err),
	}
end

local function clearFailure(name)
	ModuleFailures[name] = nil
end

local function getFailureText(name)
	local failure = ModuleFailures[name]
	if not failure then
		return nil
	end

	return tostring(failure.Phase or "error") .. ": " .. tostring(failure.Error or "unknown")
end

local function loadAccessibilityModule(name)
	if typeof(Modules[name]) == "table" then
		return Modules[name], "ready"
	end

	if LoadingModules[name] then
		return nil, "loading"
	end

	if isQuarantined(name, "load") then
		return nil, "quarantined"
	end

	local path = MODULE_PATHS[name]
	if not path then
		return nil, "missing"
	end

	LoadingModules[name] = true
	local success, module = pcall(function()
		return getgenv().loadModule(path)
	end)
	LoadingModules[name] = nil

	if not success or typeof(module) ~= "table" then
		warn("[NULLSCAPE] Accessibility module failed: " .. tostring(path) .. " -> " .. tostring(module))
		Modules[name] = nil
		markFailure(name, "load", module)
		return nil, "failed"
	end

	Modules[name] = module
	clearFailure(name)
	return module, "ready"
end

local function schedulePendingCall(name, methodName, args, attempt)
	local key = tostring(name) .. ":" .. tostring(methodName)
	if PendingCalls[key] then
		return
	end
	attempt = tonumber(attempt) or ((PendingAttempts[key] or 0) + 1)
	if attempt > PENDING_RETRY_LIMIT then
		PendingAttempts[key] = nil
		return
	end

	PendingCalls[key] = true
	PendingAttempts[key] = attempt
	task.delay(PENDING_RETRY_DELAY, function()
		PendingCalls[key] = nil
		callModule(name, methodName, table.unpack(args, 1, args.n))
	end)
end

function callModule(name, methodName, ...)
	if isQuarantined(name, "call") then
		return false
	end

	local args = {
		n = select("#", ...),
		...,
	}
	local module, state = loadAccessibilityModule(name)
	if state == "loading" then
		schedulePendingCall(name, methodName, args)
		return true
	end
	if not module or typeof(module[methodName]) ~= "function" then
		return false
	end

	PendingAttempts[tostring(name) .. ":" .. tostring(methodName)] = nil

	local success, result = pcall(function(...)
		return module[methodName](...)
	end, ...)
	if not success then
		warn(
			"[NULLSCAPE] Accessibility call failed: "
				.. tostring(name)
				.. "."
				.. tostring(methodName)
				.. " -> "
				.. tostring(result)
		)
		markFailure(name, "call:" .. tostring(methodName), result)
		return false
	end

	clearFailure(name)
	return result ~= false
end

function Executor.setupAutoJump(enemy, shockwave, controller, gc)
	return callModule("SpringerLogic", "setupAutoJump", enemy, shockwave, controller, gc)
end

function Executor.initializeInfiniteAirJump()
	return callModule("InfiniteAirJump", "initialize")
end

function Executor.disableInfiniteAirJump()
	callModule("InfiniteAirJump", "disable")
end

function Executor.getInfiniteAirJumpStatus()
	local failure = getFailureText("InfiniteAirJump")
	if failure then
		return failure
	end

	local module = loadAccessibilityModule("InfiniteAirJump")
	if module and typeof(module.getStatus) == "function" then
		local success, result = pcall(function()
			return module.getStatus()
		end)
		if success then
			return tostring(result)
		end
	end

	return "pending"
end

function Executor.initializeAntiBonk()
	return callModule("AntiBonk", "initialize")
end

function Executor.disableAntiBonk()
	callModule("AntiBonk", "disable")
end

function Executor.initializeMomentumGuard()
	return callModule("MomentumGuard", "initialize")
end

function Executor.disableMomentumGuard()
	callModule("MomentumGuard", "disable")
end

function Executor.initializeStaminaAssist()
	return callModule("StaminaAssist", "initialize")
end

function Executor.resetStaminaAssistRespawnState()
	return callModule("StaminaAssist", "resetRespawnState")
end

function Executor.disableStaminaAssist()
	callModule("StaminaAssist", "disable")
end

function Executor.setIgnoreFakeCount(enabled)
	return callModule("CurseVisualAssist", "setIgnoreFakeCount", enabled)
end

function Executor.setBeaconMirageIdentifier(enabled)
	return callModule("CurseVisualAssist", "setBeaconMirageIdentifier", enabled)
end

function Executor.initializeMirageSafety()
	return callModule("CurseVisualAssist", "initializeMirageSafety")
end

function Executor.disableMirageSafety()
	return callModule("CurseVisualAssist", "disableMirageSafety")
end

function Executor.disableCurseVisualAssist()
	callModule("CurseVisualAssist", "disable")
end

function Executor.initializeGrapplerInfiniteStamina()
	return Executor.initializeStaminaAssist()
end

function Executor.enableRailAssist()
	return callModule("RailAssist", "enable")
end

function Executor.disableRailAssist()
	callModule("RailAssist", "disable")
end

function Executor.initializeGrappleAssist(controller)
	return callModule("GrappleAssist", "initialize", controller)
end

function Executor.resetGrappleAssistRespawnState()
	return callModule("GrappleAssist", "resetRespawnState")
end

function Executor.disableGrappleAssist()
	callModule("GrappleAssist", "disable")
end

function Executor.triggerGrappleAssistSecondaryCast(controller)
	return callModule("GrappleAssist", "triggerSecondaryCast", controller)
end

function Executor.triggerGrappleReelSaver(controller)
	return callModule("GrappleAssist", "triggerReelSaver", controller)
end

return Executor
