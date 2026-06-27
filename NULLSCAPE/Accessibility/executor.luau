-- [[
--  NULLSCAPE - Accessibility Executor
--  Dispatches accessibility modules with fail-soft loading so one broken helper
--  cannot take down the whole Accessibility tab.
-- ]]

local MODULE_PATHS = {
    SpringerLogic = "NULLSCAPE/Accessibility/Auto jump - Springer.luau",
    InfiniteAirJump = "NULLSCAPE/Accessibility/Infinite Air Jump.luau",
    AntiBonk = "NULLSCAPE/Accessibility/Anti Bonk.luau",
    GrapplerInfiniteStamina = "NULLSCAPE/Accessibility/Grappler Assist/Grappler Infinite Stamina.luau",
    GrappleAimAssist = "NULLSCAPE/Accessibility/Grappler Assist/Grapple Aim Assist.luau",
    RailAssist = "NULLSCAPE/Accessibility/Rail Assist.luau",
}

local Modules = {}
local Executor = {}

local function loadAccessibilityModule(name)
    if typeof(Modules[name]) == "table" then
        return Modules[name]
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
        return nil
    end

    Modules[name] = module
    return module
end

local function callModule(name, methodName, ...)
    local module = loadAccessibilityModule(name)
    if not module or typeof(module[methodName]) ~= "function" then
        return false
    end

    local success, result = pcall(function(...)
        return module[methodName](...)
    end, ...)
    if not success then
        warn("[NULLSCAPE] Accessibility call failed: " .. tostring(name) .. "." .. tostring(methodName) .. " -> " .. tostring(result))
        return false
    end

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

function Executor.initializeGrapplerInfiniteStamina()
    return callModule("GrapplerInfiniteStamina", "initialize")
end

function Executor.enableGrappleAimAssist()
    return callModule("GrappleAimAssist", "enable")
end

function Executor.disableGrappleAimAssist()
    callModule("GrappleAimAssist", "disable")
end

function Executor.getGrappleAimAssistHealthStatus()
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
