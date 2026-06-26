--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Intent Model
--  Scores when emergency automation should yield to clear player control.
-- ]]

local IntentModel = {}

function IntentModel.getSuppression(deps, grapple, rescueResult)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    local movement = grapple and grapple.Movement
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and movement and velocity) then
        return 0, "NoIntent"
    end

    local suppression = 0
    local reason = "IntentOpen"
    local inputDirection = deps.getAssistFlatUnit(movement.PlayerMoveDirection)
    local velocityDirection = deps.getAssistFlatUnit(velocity)
    if inputDirection and velocityDirection and inputDirection:Dot(velocityDirection) >= cfg.INTENT_CONTROL_SUPPRESS_DOT and not deps.isPanicPressureActive() then
        suppression = suppression + cfg.EMERGENCY_ACTIVE_INPUT_PENALTY
        reason = "PlayerControlled"
    end

    if movement.grappling then
        suppression = suppression + cfg.INTENT_REEL_SUPPRESS_PENALTY
        reason = "AlreadyReeling"
    end

    local instance = rescueResult and rescueResult.Instance
    if instance and instance.Name == "JumpPad" and velocity.Y > cfg.ASSIST_SPECIAL_JUMPPAD_FALL_SPEED then
        suppression = suppression + cfg.INTENT_JUMPPAD_SUPPRESS_PENALTY
        reason = "JumpPadRoute"
    end

    if deps.isVoidRescueDanger(grapple) then
        suppression = suppression * 0.2
        reason = "VoidOverridesIntent"
    end

    return suppression, reason
end

return IntentModel