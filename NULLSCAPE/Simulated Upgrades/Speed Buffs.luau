--!nocheck
-- [[
--  NULLSCAPE - Speed Buffs Simulation
--  Adds stacked movement speed bonuses after MovementCore.UpdateSpeed runs.
--  Ref logic:
--    - SwiftnessRing = +10%
--    - Adrenaline = +20%
--    - SportShoes = +40%
--    - Adrenaline is limited by the native index to MaxPlayers = 2
--    - Last Man/Solo +20% is native movement.lastMan, not a simulated upgrade
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BUFF_VALUES = {
    ["Swiftness Ring I (+10%)"] = 0.10,
    ["Swiftness Ring II (+10%)"] = 0.10,
    ["Swiftness Ring III (+10%)"] = 0.10,
    ["Adrenaline (+20%)"] = 0.20,
    ["Sport Shoes (+40%)"] = 0.40,
}

local BUFF_UPGRADE_KEYS = {
    ["Swiftness Ring I (+10%)"] = "SwiftnessRing",
    ["Swiftness Ring II (+10%)"] = "SwiftnessRing",
    ["Swiftness Ring III (+10%)"] = "SwiftnessRing",
    ["Adrenaline (+20%)"] = "Adrenaline",
    ["Sport Shoes (+40%)"] = "SportShoes",
}

local Logic = {
    SelectedBuffs = {},
    OriginalUpdateSpeed = nil,
    Hooked = false,
}

local function isAdrenalineAvailable()
    local solo = ReplicatedStorage:FindFirstChild("Solo")
    if solo and solo.Value == true then
        return true
    end

    return #Players:GetPlayers() <= 2
end

local function isNativeUpgradeAlreadyActive(movement, option)
    local upgradeKey = BUFF_UPGRADE_KEYS[option]
    if not (movement and upgradeKey and typeof(movement.HasUpgrade) == "function") then
        return false
    end

    local success, enabled = pcall(function()
        return movement:HasUpgrade(upgradeKey)
    end)

    return success and enabled == true
end

local function getMovementCore()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    if not movement then return nil end
    return movement:FindFirstChild("MovementCore")
end

local function getSimulatedBonus(controller, movement)
    local selectedBuffs = controller.SpeedBuffSelections or Logic.SelectedBuffs or {}
    local total = 0

    if typeof(selectedBuffs) ~= "table" then
        return 0
    end

    for _, option in ipairs(selectedBuffs) do
        if option == "Adrenaline (+20%)" and not isAdrenalineAvailable() then
            continue
        end
        if not isNativeUpgradeAlreadyActive(movement, option) then
            total += BUFF_VALUES[option] or 0
        end
    end

    return total
end

local function applySpeedBuffs(controller, movement)
    if not controller.SpeedBuffsEnabled then return end
    if not movement then return end

    local totalBonus = getSimulatedBonus(controller, movement)
    if totalBonus <= 0 then
        return
    end

    movement.movementSpeedMulti = (tonumber(movement.movementSpeedMulti) or 1) + totalBonus
end

function Logic.start(controller, _gc)
    local MovementCoreModule = getMovementCore()
    if not MovementCoreModule then return end

    local success, MovementCore = pcall(require, MovementCoreModule)
    if not success or not MovementCore or type(MovementCore) ~= "table" then return end
    if type(MovementCore.UpdateSpeed) ~= "function" then return end

    if not MovementCore.__NULLSCAPE_original_UpdateSpeed then
        MovementCore.__NULLSCAPE_original_UpdateSpeed = MovementCore.UpdateSpeed
    end
    Logic.OriginalUpdateSpeed = MovementCore.__NULLSCAPE_original_UpdateSpeed

    if Logic.Hooked or MovementCore.__NULLSCAPE_speed_buffs_hooked then return end

    MovementCore.UpdateSpeed = function(self, ...)
        local result = Logic.OriginalUpdateSpeed(self, ...)
        applySpeedBuffs(controller, self)
        return result
    end

    MovementCore.__NULLSCAPE_speed_buffs_hooked = true
    Logic.Hooked = true
end

function Logic.stop()
    if not Logic.Hooked then return end

    local MovementCoreModule = getMovementCore()
    if MovementCoreModule then
        local success, MovementCore = pcall(require, MovementCoreModule)
        if success and MovementCore and type(MovementCore) == "table" and MovementCore.__NULLSCAPE_original_UpdateSpeed then
            MovementCore.UpdateSpeed = MovementCore.__NULLSCAPE_original_UpdateSpeed
            MovementCore.__NULLSCAPE_speed_buffs_hooked = false
        end
    end

    Logic.OriginalUpdateSpeed = nil
    Logic.Hooked = false
end

function Logic.setSelectedBuffs(selectedBuffs)
    if typeof(selectedBuffs) ~= "table" then
        Logic.SelectedBuffs = {}
        return
    end

    local normalized = {}
    for _, option in ipairs(selectedBuffs) do
        if BUFF_VALUES[option] and not table.find(normalized, option) then
            table.insert(normalized, option)
        end
    end
    Logic.SelectedBuffs = normalized
end

function Logic.getOptions()
    return {
        "Swiftness Ring I (+10%)",
        "Swiftness Ring II (+10%)",
        "Swiftness Ring III (+10%)",
        "Adrenaline (+20%)",
        "Sport Shoes (+40%)",
    }
end

return Logic
