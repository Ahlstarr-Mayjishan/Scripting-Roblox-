--!nocheck
-- [[
--  NULLSCAPE - Better Jump Pad Simulation
--  Ref logic:
--    - JumpPad sets RootPart.Velocity.Y to 100 by default
--    - WeakJumpPads outside current rooms can reduce it to 60
--  This module keeps the original JumpPad behavior, then raises the vertical launch up to the configured value.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MIN_JUMP_PAD_POWER = 100
local MAX_JUMP_PAD_POWER = 200

local Logic = {
    JumpPadPower = MIN_JUMP_PAD_POWER,
    OriginalOnHitboxTouch = nil,
    Hooked = false
}

local function getMovementCore()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    if not movement then return nil end
    return movement:FindFirstChild("MovementCore")
end

local function applyJumpPadPower(controller, movement)
    if not controller.BetterJumpPadEnabled then return end
    if not movement or not movement.RootPart then return end

    local power = math.clamp(tonumber(controller.BetterJumpPadPower) or Logic.JumpPadPower, MIN_JUMP_PAD_POWER, MAX_JUMP_PAD_POWER)
    local velocity = movement.RootPart.Velocity
    if velocity.Y < power then
        movement.RootPart.Velocity = Vector3.new(velocity.X, power, velocity.Z)
    end
end

function Logic.start(controller, gc)
    local MovementCoreModule = getMovementCore()
    if not MovementCoreModule then return end

    local success, MovementCore = pcall(require, MovementCoreModule)
    if not success or not MovementCore or type(MovementCore) ~= "table" then return end

    if not MovementCore.__NULLSCAPE_original_OnHitboxTouch then
        MovementCore.__NULLSCAPE_original_OnHitboxTouch = MovementCore.OnHitboxTouch
    end
    Logic.OriginalOnHitboxTouch = MovementCore.__NULLSCAPE_original_OnHitboxTouch

    if Logic.Hooked or MovementCore.__NULLSCAPE_better_jump_pad_hooked then return end

    MovementCore.OnHitboxTouch = function(self, part)
        if controller.BetterJumpPadEnabled and part and part.Name == "JumpPad" then
            task.defer(function()
                applyJumpPadPower(controller, self)
            end)
        end

        return Logic.OriginalOnHitboxTouch(self, part)
    end

    MovementCore.__NULLSCAPE_better_jump_pad_hooked = true
    Logic.Hooked = true
end

function Logic.stop()
    if not Logic.Hooked then return end

    local MovementCoreModule = getMovementCore()
    if MovementCoreModule then
        local success, MovementCore = pcall(require, MovementCoreModule)
        if success and MovementCore and type(MovementCore) == "table" and MovementCore.__NULLSCAPE_original_OnHitboxTouch then
            MovementCore.OnHitboxTouch = MovementCore.__NULLSCAPE_original_OnHitboxTouch
            MovementCore.__NULLSCAPE_better_jump_pad_hooked = false
        end
    end

    Logic.OriginalOnHitboxTouch = nil
    Logic.Hooked = false
end

function Logic.setJumpPadPower(value)
    Logic.JumpPadPower = math.clamp(tonumber(value) or MIN_JUMP_PAD_POWER, MIN_JUMP_PAD_POWER, MAX_JUMP_PAD_POWER)
end

function Logic.getMinJumpPadPower()
    return MIN_JUMP_PAD_POWER
end

function Logic.getMaxJumpPadPower()
    return MAX_JUMP_PAD_POWER
end

return Logic
