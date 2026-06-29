-- [[
--  NULLSCAPE - Accessibility Executor
--  Dispatches accessibility modules with fail-soft loading so one broken helper
--  cannot take down the whole Accessibility tab.
-- ]]

local MODULE_PATHS = {
    SpringerLogic = "NULLSCAPE/Accessibility/Auto jump - Springer.luau",
    InfiniteAirJump = "NULLSCAPE/Accessibility/Infinite Air Jump.luau",
    AntiBonk = "NULLSCAPE/Accessibility/Anti Bonk.luau",
    StaminaAssist = "NULLSCAPE/Accessibility/Stamina Assist.luau",
    GrappleAimAssist = "NULLSCAPE/Accessibility/Grappler Assist/Grapple Aim Assist.luau",
    RailAssist = "NULLSCAPE/Accessibility/Rail Assist.luau",
}

local Modules = {}
local ModuleFailures = {}
local Executor = {}

local LOAD_RETRY_COOLDOWN = 1.5
local CALL_RETRY_COOLDOWN = 0.75

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
        return Modules[name]
    end

    if isQuarantined(name, "load") then
        return nil
    end

    local path = MODULE_PATHS[name]
    if not path then
        return nil
    end

    local success, module = pcall(function()
        return getgenv().loadModule(path)
    end)
    if not success or typeof(module) ~= "table" then
        warn("[NULLSCAPE] Accessibility module failed: " .. tostring(path) .. " -> " .. tostring(module))
        Modules[name] = nil
        markFailure(name, "load", module)
        return nil
    end

    Modules[name] = module
    clearFailure(name)
    return module
end

local function callModule(name, methodName, ...)
    if isQuarantined(name, "call") then
        return false
    end

    local module = loadAccessibilityModule(name)
    if not module or typeof(module[methodName]) ~= "function" then
        return false
    end

    local success, result = pcall(function(...)
        return module[methodName](...)
    end, ...)
    if not success then
        warn("[NULLSCAPE] Accessibility call failed: " .. tostring(name) .. "." .. tostring(methodName) .. " -> " .. tostring(result))
        markFailure(name, "call:" .. tostring(methodName), result)
        return false
    end

    clearFailure(name)
    return result ~= false
end

function Executor.setupAutoJump(enemy, shockwave, controller, gc)
    callModule("SpringerLogic", "setupAutoJump", enemy, shockwave, controller, gc)
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

function Executor.initializeStaminaAssist()
    return callModule("StaminaAssist", "initialize")
end

function Executor.disableStaminaAssist()
    callModule("StaminaAssist", "disable")
end

function Executor.initializeGrapplerInfiniteStamina()
    return Executor.initializeStaminaAssist()
end

function Executor.enableGrappleAimAssist()
    return callModule("GrappleAimAssist", "enable")
end

function Executor.disableGrappleAimAssist()
    callModule("GrappleAimAssist", "disable")
end

function Executor.clearGrappleMapModel()
    callModule("GrappleAimAssist", "clearMapModel")
end

function Executor.setGrappleMapModel3DDebug(value)
    callModule("GrappleAimAssist", "setMapModel3DDebugEnabled", value == true)
end

function Executor.getGrappleAimAssistHealthStatus()
    local failure = getFailureText("GrappleAimAssist")
    if failure then
        return failure
    end

    local module = loadAccessibilityModule("GrappleAimAssist")
    if module and typeof(module.getHealthStatus) == "function" then
        local success, result = pcall(function()
            return module.getHealthStatus()
        end)
        if success then
            return tostring(result)
        end
    end

    return "Core pending"
end

function Executor.enableRailAssist()
    return callModule("RailAssist", "enable")
end

function Executor.disableRailAssist()
    callModule("RailAssist", "disable")
end

return Executor
