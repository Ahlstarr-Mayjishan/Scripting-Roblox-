--!nocheck
--[[
 NULLSCAPE - Grappler Assist Arbiter
 Decides which assist may act during the current frame so helpers do not fight each other.
]]

local AssistArbiter = {}

local PRIORITY = {
    VoidRescue = 100,
    PanicRescue = 92,
    PanicStabilize = 82,
    JumpPadCommit = 76,
    SharkTail = 66,
    SmartReel = 58,
    ReelPull = 48,
    MomentumGuard = 34,
    AntiBonk = 30,
    AirControl = 20,
}

local DEFAULT_LOCKS = {
    VoidRescue = 0.7,
    PanicRescue = 0.45,
    PanicStabilize = 0.32,
    JumpPadCommit = 0.55,
    SharkTail = 0.28,
    SmartReel = 0.24,
    ReelPull = 0.12,
    MomentumGuard = 0.08,
    AntiBonk = 0.16,
    AirControl = 0.04,
}

function AssistArbiter.new()
    return {
        Active = nil,
        Until = 0,
        Reason = nil,
        LastDecision = nil,
    }
end

function AssistArbiter.getPriority(assistName)
    return PRIORITY[assistName] or 0
end

function AssistArbiter.releaseExpired(state, now)
    if state and state.Active and now >= (state.Until or 0) then
        state.Active = nil
        state.Until = 0
        state.Reason = nil
    end
end

function AssistArbiter.canRun(state, assistName, intent, options)
    state = state or AssistArbiter.new()
    options = options or {}
    local now = options.now or time()
    AssistArbiter.releaseExpired(state, now)

    local active = state.Active
    local activePriority = active and AssistArbiter.getPriority(active) or -1
    local nextPriority = AssistArbiter.getPriority(assistName)
    local blocked = false
    local reason = "Allowed"

    if active and active ~= assistName and activePriority > nextPriority then
        blocked = true
        reason = "LockedBy:" .. tostring(active)
    end

    if intent then
        if intent.JumpPadCommit and not intent.VoidDanger and (assistName == "PanicRescue" or assistName == "SmartReel" or assistName == "SharkTail") then
            blocked = true
            reason = "JumpPadCommit"
        elseif intent.State == "LandingIntent" and not intent.VoidDanger and (assistName == "PanicRescue" or assistName == "SmartReel" or assistName == "SharkTail") then
            blocked = true
            reason = "LandingIntent"
        elseif intent.State == "PlayerControlled" and (assistName == "PanicRescue" or assistName == "SmartReel") and not intent.VoidDanger then
            blocked = true
            reason = "PlayerControlled"
        end
    end

    state.LastDecision = {
        Assist = assistName,
        Allowed = not blocked,
        Reason = reason,
        Active = active,
        Intent = intent and intent.State or nil,
    }

    return not blocked, reason
end

function AssistArbiter.claim(state, assistName, reason, duration)
    if not state then
        return
    end

    state.Active = assistName
    state.Reason = reason or assistName
    state.Until = time() + (tonumber(duration) or DEFAULT_LOCKS[assistName] or 0.12)
end

function AssistArbiter.snapshot(state)
    if not state then
        return "NoArbiter"
    end

    local decision = state.LastDecision
    if not decision then
        return tostring(state.Active or "Idle")
    end

    return tostring(decision.Assist)
        .. ":"
        .. (decision.Allowed and "allowed" or "blocked")
        .. ":"
        .. tostring(decision.Reason)
end

return AssistArbiter
