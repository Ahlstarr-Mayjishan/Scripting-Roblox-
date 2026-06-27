--!nocheck
-- [[
--  NULLSCAPE - Grappler Assist Emergency Decision
--  Pure-ish decision layer for Grappler emergency and void rescue scoring.
-- ]]

local EmergencyDecision = {}

local function isAssistDecision(result)
    return typeof(result) == "table"
end

local function getAssistResultInstance(result)
    if not result then
        return nil
    end

    if not isAssistDecision(result) then
        return result.Instance
    end

    if result.Instance then
        return result.Instance
    end
    if result.Result and result.Result.Instance then
        return result.Result.Instance
    end

    return nil
end

local function getAssistResultPosition(result)
    if not result then
        return nil
    end

    if not isAssistDecision(result) then
        return result.Position
    end

    if result.Position then
        return result.Position
    end
    if result.Result and result.Result.Position then
        return result.Result.Position
    end

    return nil
end

local function getAssistResultTargetName(deps, result)
    local instance = getAssistResultInstance(result)
    if instance and deps.isRescueTargetName(instance.Name) then
        return instance.Name
    end

    return nil
end

function EmergencyDecision.createSnapshot(deps, grapple, rescueResult)
    local rootPart = grapple and grapple.RootPart
    local movement = grapple and grapple.Movement
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and movement and velocity) then
        return nil
    end

    local classId = deps.getClassId(grapple)
    local unsafeSamples, nearVoidKillPlane = deps.getProjectedUnsafeSampleCount(grapple)
    local voidDanger, voidReason = deps.getVoidDangerState(grapple)
    local inputDirection = deps.getAssistFlatUnit(movement.PlayerMoveDirection)
    local velocityDirection = deps.getAssistFlatUnit(velocity)
    local resultInstance = getAssistResultInstance(rescueResult)
    local resultPosition = getAssistResultPosition(rescueResult)
    local targetName = getAssistResultTargetName(deps, rescueResult)
    local terrainReason = isAssistDecision(rescueResult) and rescueResult.Reason or nil
    local terrainScore = isAssistDecision(rescueResult) and rescueResult.Score or nil

    return {
        ClassId = classId,
        IsGrappler = classId == deps.GRAPPLER_CLASS_ID,
        Grapple = grapple,
        RootPart = rootPart,
        Movement = movement,
        Velocity = velocity,
        HorizontalSpeed = deps.getHorizontalVelocity(rootPart).Magnitude,
        FallSpeed = math.max(-velocity.Y, 0),
        UnsafeSamples = unsafeSamples,
        NearVoidKillPlane = nearVoidKillPlane,
        VoidDanger = voidDanger,
        VoidReason = voidReason,
        PanicPressure = deps.isPanicPressureActive(),
        EmergencyMode = deps.getEmergencyProtectionMode(),
        InputDirection = inputDirection,
        VelocityDirection = velocityDirection,
        RescueResult = rescueResult,
        RescueInstance = resultInstance,
        RescuePosition = resultPosition,
        RescueTargetName = targetName,
        TerrainReason = terrainReason,
        TerrainScore = terrainScore,
        IsReeling = movement.grappling == true,
    }
end

function EmergencyDecision.createDecision(deps, grapple, rescueResult)
    local cfg = deps.CFG
    local snapshot = EmergencyDecision.createSnapshot(deps, grapple, rescueResult)
    if not snapshot then
        return {
            Action = "DoNothing",
            Allowed = false,
            Score = 0,
            Threshold = math.huge,
            Reason = "NoState",
        }
    end

    local threshold = snapshot.EmergencyMode == "Smart Auto" and cfg.EMERGENCY_SMART_AUTO_THRESHOLD or cfg.EMERGENCY_AUTO_THRESHOLD
    if not snapshot.IsGrappler then
        return {
            Action = "DoNothing",
            Allowed = false,
            Score = 0,
            Threshold = threshold,
            Reason = "NotGrappler",
            ClassId = snapshot.ClassId,
        }
    end

    if snapshot.EmergencyMode == "Manual" then
        return {
            Action = "DoNothing",
            Allowed = false,
            Score = 0,
            Threshold = threshold,
            Reason = "ManualMode",
            ClassId = snapshot.ClassId,
        }
    end

    local score = 0
    local reason = "SmartAuto"
    if snapshot.VoidDanger then
        score = score + 96
        reason = snapshot.VoidReason or "VoidRescue"
    elseif snapshot.NearVoidKillPlane then
        score = score + 48
        reason = "KillPlane"
    end

    score = score + snapshot.UnsafeSamples * 18
    score = score + math.clamp((snapshot.HorizontalSpeed - cfg.AUTO_RESCUE_SPEED) / 120, 0, 1) * 24
    score = score + math.clamp((snapshot.FallSpeed - deps.getEmergencyFallThreshold(grapple)) / 120, 0, 1) * 34

    if snapshot.InputDirection and snapshot.VelocityDirection and not snapshot.PanicPressure then
        local controlDot = snapshot.InputDirection:Dot(snapshot.VelocityDirection)
        if controlDot > 0.2 then
            score = score - cfg.EMERGENCY_ACTIVE_INPUT_PENALTY * math.clamp(controlDot, 0, 1)
            reason = "PlayerSteering"
        elseif controlDot < -0.25 then
            score = score - cfg.EMERGENCY_ACTIVE_INPUT_PENALTY * 0.5
            reason = "PlayerBraking"
        end
    elseif not snapshot.InputDirection then
        score = score + cfg.EMERGENCY_NO_INPUT_BONUS
    end

    local intentSuppression, intentReason = deps.getPlayerIntentSuppression(grapple, rescueResult)
    if intentSuppression > 0 then
        score = score - intentSuppression
        reason = intentReason
    end

    if snapshot.PanicPressure then
        score = score + 30
        reason = "PanicInput"
    end

    if snapshot.RescueTargetName then
        local distance = snapshot.RescuePosition and (snapshot.RescuePosition - snapshot.RootPart.Position).Magnitude or math.huge
        if snapshot.RescueTargetName == "Bell" then
            score = score + (distance <= cfg.PANIC_BELL_NEAR_DISTANCE and 24 or 12)
        elseif snapshot.RescueTargetName == "JumpPad" then
            score = score + (distance <= cfg.PANIC_JUMPPAD_NEAR_DISTANCE and 18 or 8)
        elseif snapshot.RescueTargetName == "TriaOrb" then
            score = score + 14
        elseif snapshot.RescueTargetName == "GrapplePoint" then
            score = score + 6
        end
    elseif type(snapshot.TerrainReason) == "string" and string.find(snapshot.TerrainReason, "Terrain", 1, true) then
        local terrainScore = tonumber(snapshot.TerrainScore) or 80
        score = score - 20 + math.clamp((70 - terrainScore) / 70, -0.35, 0.5) * 18
        reason = snapshot.TerrainReason
    else
        score = score - 36
        reason = "NoRescueTarget"
    end

    local action = snapshot.VoidDanger and "VoidRescue" or "EmergencyRescue"
    return {
        Action = action,
        Allowed = score >= threshold,
        Score = score,
        Threshold = threshold,
        Reason = reason,
        ClassId = snapshot.ClassId,
        Target = snapshot.RescueTargetName or (snapshot.RescueInstance and snapshot.RescueInstance.Name) or "Surface",
        VoidDanger = snapshot.VoidDanger,
        Suppression = intentSuppression,
        SuppressionReason = intentReason,
    }
end

return EmergencyDecision