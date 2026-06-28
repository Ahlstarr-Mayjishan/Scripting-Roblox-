--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Intent Model
--  Scores when emergency automation should yield to clear player control.
-- ]]

local IntentModel = {}

local function getFlatUnit(vector)
    if typeof(vector) ~= "Vector3" then
        return nil
    end

    local flat = vector * Vector3.new(1, 0, 1)
    if flat.Magnitude <= 0.05 then
        return nil
    end

    return flat.Unit
end

function IntentModel.classify(deps, grapple, rescueResult)
    local cfg = deps.CFG
    local rootPart = grapple and grapple.RootPart
    local movement = grapple and grapple.Movement
    local velocity = rootPart and rootPart.Velocity
    local snapshot = {
        State = "NoState",
        Reason = "NoIntent",
        Suppression = 0,
        InputDirection = nil,
        VelocityDirection = nil,
        ControlDot = nil,
        HorizontalSpeed = 0,
        FallSpeed = 0,
        IsReeling = false,
        JumpPadCommit = false,
        VoidDanger = false,
        PanicPressure = false,
        SafeLanding = false,
        RescueTarget = nil,
        Profile = nil,
        LowGravity = false,
        Concussion = false,
        Medal = false,
        WeakJumpPads = false,
    }

    if not (rootPart and movement and velocity) then
        return snapshot
    end

    local suppression = 0
    local reason = "IntentOpen"
    local state = "Freefall"
    local inputDirection = (deps.getAssistFlatUnit and deps.getAssistFlatUnit(movement.PlayerMoveDirection)) or getFlatUnit(movement.PlayerMoveDirection)
    local velocityDirection = (deps.getAssistFlatUnit and deps.getAssistFlatUnit(velocity)) or getFlatUnit(velocity)
    local controlDot = inputDirection and velocityDirection and inputDirection:Dot(velocityDirection) or nil
    local horizontalSpeed = (deps.getHorizontalVelocity and deps.getHorizontalVelocity(rootPart).Magnitude) or Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    local fallSpeed = math.max(-velocity.Y, 0)
    local panicPressure = deps.isPanicPressureActive and deps.isPanicPressureActive() == true
    local voidDanger = deps.isVoidRescueDanger and deps.isVoidRescueDanger(grapple) == true
    local jumpPadCommit = deps.isJumpPadCommitGuardActive and deps.isJumpPadCommitGuardActive() == true
    local safeLanding = deps.hasSafeLanding and deps.hasSafeLanding(grapple) == true
    local profile = deps.getPhysicsProfile and deps.getPhysicsProfile(grapple) or nil

    if inputDirection and velocityDirection and controlDot and controlDot >= cfg.INTENT_CONTROL_SUPPRESS_DOT and not panicPressure then
        suppression = suppression + cfg.EMERGENCY_ACTIVE_INPUT_PENALTY
        reason = "PlayerControlled"
        state = "PlayerControlled"
    elseif inputDirection and not panicPressure then
        state = "PlayerSteering"
    end

    if movement.grappling then
        suppression = suppression + cfg.INTENT_REEL_SUPPRESS_PENALTY
        reason = "AlreadyReeling"
        state = "Reeling"
    end

    if jumpPadCommit then
        suppression = suppression + cfg.INTENT_JUMPPAD_SUPPRESS_PENALTY
        reason = "JumpPadCommit"
        state = "JumpPadCommit"
    elseif safeLanding and not voidDanger then
        suppression = suppression + cfg.EMERGENCY_ACTIVE_INPUT_PENALTY
        reason = "SafeLanding"
        state = "LandingIntent"
    end

    local instance = rescueResult and rescueResult.Instance
    if instance and instance.Name == "JumpPad" and velocity.Y > cfg.ASSIST_SPECIAL_JUMPPAD_FALL_SPEED then
        local boostPenalty = profile and profile.CanTrustJumpPadBoost == false and cfg.INTENT_JUMPPAD_SUPPRESS_PENALTY * 0.45 or cfg.INTENT_JUMPPAD_SUPPRESS_PENALTY
        suppression = suppression + boostPenalty
        reason = "JumpPadRoute"
        state = "JumpPadRoute"
    end

    if profile and profile.Concussion and not voidDanger then
        suppression = math.max(suppression - 8, 0)
        if state == "Freefall" then
            state = "ConcussionFallback"
        end
    end

    if voidDanger then
        suppression = suppression * 0.2
        reason = "VoidOverridesIntent"
        state = "VoidRisk"
    elseif panicPressure then
        state = "PanicPressure"
    end

    snapshot.State = state
    snapshot.Reason = reason
    snapshot.Suppression = suppression
    snapshot.InputDirection = inputDirection
    snapshot.VelocityDirection = velocityDirection
    snapshot.ControlDot = controlDot
    snapshot.HorizontalSpeed = horizontalSpeed
    snapshot.FallSpeed = fallSpeed
    snapshot.IsReeling = movement.grappling == true
    snapshot.JumpPadCommit = jumpPadCommit
    snapshot.VoidDanger = voidDanger
    snapshot.PanicPressure = panicPressure
    snapshot.SafeLanding = safeLanding
    snapshot.RescueTarget = instance and instance.Name or nil
    snapshot.Profile = profile
    snapshot.LowGravity = profile and profile.LowGravity == true or false
    snapshot.Concussion = profile and profile.Concussion == true or false
    snapshot.Medal = profile and profile.Medal == true or false
    snapshot.WeakJumpPads = profile and profile.WeakJumpPads == true or false

    return snapshot
end

function IntentModel.getSuppression(deps, grapple, rescueResult)
    local snapshot = IntentModel.classify(deps, grapple, rescueResult)
    return snapshot.Suppression or 0, snapshot.Reason or "NoIntent"
end

return IntentModel
