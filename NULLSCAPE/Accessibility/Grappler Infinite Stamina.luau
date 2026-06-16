--!nocheck
-- [[
--  NULLSCAPE - Grappler Infinite Stamina
--  Keeps the native Grapple stamina timer full while the accessibility mode is enabled.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {}

local MODE_INFINITE = "Infinite Stamina"

local function getGlobals()
    local env = getgenv()
    env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
    return env._NULLSCAPE_Globals
end

local function isEnabled()
    local controller = getGlobals().activeAccessibilityController
    return controller and controller.GrapplerStaminaMode == MODE_INFINITE
end

local function refillStamina(grapple)
    if not isEnabled() or typeof(grapple) ~= "table" then
        return
    end

    local maxTime = tonumber(grapple.usedGrappleTime) or tonumber(grapple.TimeClamp) or tonumber(grapple.Time)
    if not maxTime or maxTime <= 0 then
        return
    end

    grapple.Time = maxTime
    grapple.TimeClamp = maxTime
    grapple.TimeDrained = false

    local ui = grapple.UI
    local frame = ui and ui:FindFirstChild("Frame")
    local bar = frame and frame:FindFirstChild("Bar")
    if bar then
        pcall(function()
            bar.Size = UDim2.fromScale(1, 1)
        end)
    end
end

local function getGrappleModule()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    local specials = movement and movement:FindFirstChild("Specials")
    local grappleScript = specials and specials:FindFirstChild("Grapple")
    if not grappleScript or not grappleScript:IsA("ModuleScript") then
        return nil
    end

    local success, grappleModule = pcall(require, grappleScript)
    if not success or typeof(grappleModule) ~= "table" then
        return nil
    end

    return grappleModule
end

function Logic.initialize()
    local globals = getGlobals()
    if globals.GrapplerInfiniteStaminaHooked then
        return true
    end

    local grappleModule = getGrappleModule()
    if not grappleModule then
        return false
    end

    if typeof(grappleModule.Step) == "function" then
        local originalStep = grappleModule.Step
        globals.OriginalGrappleStep = originalStep

        grappleModule.Step = function(self, dt, ...)
            refillStamina(self)
            local result = originalStep(self, dt, ...)
            refillStamina(self)
            return result
        end
    end

    if typeof(grappleModule.Start) == "function" then
        local originalStart = grappleModule.Start
        globals.OriginalGrappleStart = originalStart

        grappleModule.Start = function(self, ...)
            refillStamina(self)
            local result = originalStart(self, ...)
            refillStamina(self)
            return result
        end
    end

    globals.GrapplerInfiniteStaminaHooked = true
    return true
end

return Logic
