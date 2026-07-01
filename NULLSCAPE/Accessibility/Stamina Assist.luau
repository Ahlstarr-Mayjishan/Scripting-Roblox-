--!nocheck
-- [[
--  NULLSCAPE - Stamina Assist
--  Shared accessibility helper for keeping native class stamina/timer resources full.
--  Any class special that exposes Time/TimeClamp style fields can use this module.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logic = {
    Connection = nil,
    LastRefillAt = 0,
    LastSpecial = nil,
}

local REFILL_INTERVAL = 0.05

local function getGlobals()
    local env = getgenv()
    env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
    return env._NULLSCAPE_Globals
end

local function getController()
    return getGlobals().activeAccessibilityController
end

local function getMode()
    local controller = getController()
    return tostring((controller and (controller.StaminaMode or controller.GrapplerStaminaMode)) or "Off")
end

local function getMovementCore()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
    if not movementCoreScript then
        return nil
    end

    local success, movementCore = pcall(require, movementCoreScript)
    if success and typeof(movementCore) == "table" then
        return movementCore
    end

    return nil
end

local function getMaxTime(special)
    return tonumber(special and special.usedGrappleTime)
        or tonumber(special and special.usedStaminaTime)
        or tonumber(special and special.StaminaClamp)
        or tonumber(special and special.TimeClamp)
        or tonumber(special and special.MaxStamina)
        or tonumber(special and special.MaxTime)
        or tonumber(special and special.Time)
        or tonumber(special and special.Stamina)
end

local function getCurrentTime(special)
    return tonumber(special and special.Stamina)
        or tonumber(special and special.Time)
        or tonumber(special and special.CurrentTime)
        or 0
end

function Logic.isEnabled()
    return getMode() == "Infinite Stamina"
end

function Logic.supports(special)
    return typeof(special) == "table" and getMaxTime(special) ~= nil
end

function Logic.getRatio(special)
    if Logic.isEnabled() then
        return 1
    end

    local maxTime = getMaxTime(special) or 0
    if maxTime <= 0 then
        return 1
    end

    return math.clamp(getCurrentTime(special) / maxTime, 0, 1)
end

function Logic.refill(special)
    if not Logic.isEnabled() or not Logic.supports(special) then
        return false
    end

    local maxTime = getMaxTime(special)
    if not maxTime or maxTime <= 0 then
        return false
    end

    if special.Time ~= nil then
        special.Time = maxTime
    end
    if special.Stamina ~= nil then
        special.Stamina = maxTime
    end
    if special.CurrentTime ~= nil then
        special.CurrentTime = maxTime
    end
    if special.TimeClamp ~= nil then
        special.TimeClamp = maxTime
    end
    if special.StaminaClamp ~= nil then
        special.StaminaClamp = maxTime
    end
    if special.TimeDrained ~= nil then
        special.TimeDrained = false
    end
    if special.StaminaDrained ~= nil then
        special.StaminaDrained = false
    end

    local ui = special.UI
    local frame = ui and ui:FindFirstChild("Frame")
    local bar = frame and frame:FindFirstChild("Bar")
    if bar then
        pcall(function()
            bar.Size = UDim2.fromScale(1, 1)
        end)
    end

    return true
end

local function getActiveMovementInstance()
    local movementCore = getMovementCore()
    if not movementCore then
        return nil
    end

    local Players = game:GetService("Players")

    -- Scan garbage collector for the active MovementCore instance
    if typeof(getgc) == "function" then
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" and getmetatable(obj) == movementCore then
                if obj.Player == Players.LocalPlayer then
                    return obj
                end
            end
        end
    end

    -- Fallback: scan registry
    if typeof(debug.getregistry) == "function" then
        for _, obj in pairs(debug.getregistry()) do
            if type(obj) == "table" and getmetatable(obj) == movementCore then
                if obj.Player == Players.LocalPlayer then
                    return obj
                end
            end
        end
    end

    return nil
end

function Logic.step()
    if not Logic.isEnabled() then
        return
    end

    local now = time()
    if now - (Logic.LastRefillAt or 0) < REFILL_INTERVAL then
        return
    end
    Logic.LastRefillAt = now

    local movementInstance = getActiveMovementInstance()
    local activeSpecial = movementInstance and movementInstance.ActiveSpecial
    if activeSpecial then
        Logic.LastSpecial = activeSpecial
        Logic.refill(activeSpecial)
    end
end

function Logic.initialize()
    if Logic.Connection then
        return true
    end

    Logic.Connection = RunService.Heartbeat:Connect(function()
        local success, err = pcall(Logic.step)
        if not success then
            warn("[NULLSCAPE] Stamina Assist step failed: " .. tostring(err))
        end
    end)

    return true
end

function Logic.disable()
    if Logic.Connection then
        pcall(function()
            Logic.Connection:Disconnect()
        end)
        Logic.Connection = nil
    end
    Logic.LastSpecial = nil
end

return Logic