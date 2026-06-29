--!nocheck
-- [[
--  NULLSCAPE - Status Effect and Knockback Immunity Controller
--  Manages status effect immunities and physical shockwave knockbacks.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

local StatusImmunity = {
    ActiveImmunities = {},
    ActiveCallbacks = {},
    Hooked = false,
}

local function getController()
    local globals = getgenv()._NULLSCAPE_Globals
    return globals and globals.activeEntitiesController
end

function StatusImmunity.isImmune(statusName)
    if StatusImmunity.ActiveImmunities[statusName] == true then
        return true
    end

    local controller = getController()
    if controller and controller.SpringerImmunityMode == "Blatant" then
        if statusName ~= "Medal" and statusName ~= "Overtuned" then
            return true
        end
    end

    return false
end

function StatusImmunity.GetActiveImmunities()
    local list = {}
    for name, active in pairs(StatusImmunity.ActiveImmunities) do
        if active then
            table.insert(list, name)
        end
    end
    table.sort(list)
    return list
end

function StatusImmunity.SetActiveImmunities(options)
    local previous = {}
    for k, v in pairs(StatusImmunity.ActiveImmunities) do
        previous[k] = v
    end

    table.clear(StatusImmunity.ActiveImmunities)
    for _, opt in ipairs(options) do
        StatusImmunity.ActiveImmunities[opt] = true
    end

    local controller = getController()
    if not controller then return end

    -- Immediately remove active debuffs if newly immune
    for _, debuffName in ipairs({ "Flesh", "Panic", "Concussion", "Fire", "Insanity", "Overtuned" }) do
        if StatusImmunity.ActiveImmunities[debuffName] and not previous[debuffName] then
            for _, callback in ipairs(StatusImmunity.ActiveCallbacks) do
                pcall(callback, debuffName, false)
            end
        end
    end

    -- Update Springer Shockwaves
    if StatusImmunity.ActiveImmunities["Springer Knockback"] ~= previous["Springer Knockback"] then
        if typeof(controller.SetSpringerKnockbackImmune) == "function" then
            controller:SetSpringerKnockbackImmune(StatusImmunity.ActiveImmunities["Springer Knockback"] == true)
        end
    end

    -- Update Bell Touch
    if StatusImmunity.ActiveImmunities["Bell Knockback"] ~= previous["Bell Knockback"] then
        if typeof(controller.SetBellKnockbackImmune) == "function" then
            controller:SetBellKnockbackImmune(StatusImmunity.ActiveImmunities["Bell Knockback"] == true)
        end
    end
end

function StatusImmunity.initialize()
    local globals = getgenv()._NULLSCAPE_Globals
    if globals.StatusEffectHooked or StatusImmunity.Hooked then
        return
    end

    local StatusEffectChanged = ReplicatedStorage:FindFirstChild("Events")
        and ReplicatedStorage.Events:FindFirstChild("StatusEffectChanged")
    if StatusEffectChanged and StatusEffectChanged:IsA("RemoteEvent") then
        pcall(function()
            if typeof(hookfunction) == "function" then
                local oldConnect
                oldConnect = hookfunction(StatusEffectChanged.OnClientEvent.Connect, function(self, callback)
                    local isTarget = false
                    pcall(function()
                        isTarget = (self == StatusEffectChanged.OnClientEvent)
                    end)
                    
                    if isTarget then
                        if not table.find(StatusImmunity.ActiveCallbacks, callback) then
                            table.insert(StatusImmunity.ActiveCallbacks, callback)
                        end
                        local newCallback = function(statusName, isActive, ...)
                            if StatusImmunity.isImmune(statusName) then
                                return
                            end
                            return callback(statusName, isActive, ...)
                        end
                        return oldConnect(self, newCallback)
                    end
                    return oldConnect(self, callback)
                end)
                globals.OriginalOnClientEventConnect = oldConnect
            end
        end)

        -- Hook existing connections
        pcall(function()
            if typeof(getconnections) == "function" and typeof(hookfunction) == "function" then
                for _, connection in ipairs(getconnections(StatusEffectChanged.OnClientEvent)) do
                    local originalFunction = connection.Function
                    if typeof(originalFunction) == "function" then
                        if not table.find(StatusImmunity.ActiveCallbacks, originalFunction) then
                            table.insert(StatusImmunity.ActiveCallbacks, originalFunction)
                        end
                        local oldFunc
                        oldFunc = hookfunction(originalFunction, function(statusName, isActive, ...)
                            if StatusImmunity.isImmune(statusName) then
                                return
                            end
                            return oldFunc(statusName, isActive, ...)
                        end)
                    end
                end
            end
        end)
    end

    pcall(function()
        local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
        local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
        if handlerModule and handlerModule:IsA("ModuleScript") then
            local StatusEffectHandler = require(handlerModule)
            if typeof(StatusEffectHandler) == "table" and typeof(StatusEffectHandler.HasStatus) == "function" then
                if typeof(hookfunction) == "function" then
                    local oldHasStatus
                    oldHasStatus = hookfunction(StatusEffectHandler.HasStatus, function(statusName, ...)
                        if StatusImmunity.isImmune(statusName) then
                            return false
                        end
                        return oldHasStatus(statusName, ...)
                    end)
                    globals.OriginalHasStatus = oldHasStatus
                else
                    local oldHasStatus = StatusEffectHandler.HasStatus
                    globals.OriginalHasStatus = oldHasStatus
                    StatusEffectHandler.HasStatus = function(statusName, ...)
                        if StatusImmunity.isImmune(statusName) then
                            return false
                        end
                        return oldHasStatus(statusName, ...)
                    end
                end
            end
        end
    end)

    globals.StatusEffectHooked = true
    StatusImmunity.Hooked = true
end

function StatusImmunity.removeAllStatuses()
    local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
    local handlerModule = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
    if handlerModule and handlerModule:IsA("ModuleScript") then
        local StatusEffectHandler = require(handlerModule)
        if typeof(StatusEffectHandler) == "table" and typeof(StatusEffectHandler.RemoveAllStatuses) == "function" then
            pcall(StatusEffectHandler.RemoveAllStatuses)
        end
    end
    for _, debuffName in ipairs({ "Flesh", "Panic", "Concussion", "Fire", "Insanity", "Overtuned" }) do
        for _, callback in ipairs(StatusImmunity.ActiveCallbacks) do
            pcall(callback, debuffName, false)
        end
    end
end

return StatusImmunity
