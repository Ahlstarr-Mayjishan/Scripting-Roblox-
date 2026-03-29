--[[
    PredictionCore.lua — Base Prediction Engine (OOP)
    ═══════════════════════════════════════════════════
    Class cơ sở chứa toàn bộ thuật toán prediction:
      • Kalman Filter, Intercept Solver, Kinematics
      • Motion State Analysis, Teleport Detection
      • Brain Response, Hit Feedback, Stabilization
    
    NPC/PvP-specific tuning nằm trong self.Profile
    (được set bởi NPCPrediction hoặc PvPPrediction).
    
    PERF: Không có runtime branch cho NPC vs PvP.
    Mọi giá trị được đọc từ Profile table.
]]

local PredictionCore = {}
PredictionCore.__index = PredictionCore

-- ═══ STATIC: Kinematics Helpers (no self) ═══
-- Dùng PredictionCore.FuncName() thay vì self: để tránh overhead method lookup

local function uniformMotionOffset(velocity, time)
    if not velocity or not time or time <= 0 then return Vector3.zero end
    return velocity * time
end

local function uniformAccelOffset(velocity, acceleration, time)
    if not time or time <= 0 then return Vector3.zero end
    return uniformMotionOffset(velocity or Vector3.zero, time)
        + (0.5 * (acceleration or Vector3.zero) * (time * time))
end

local function velocityAfterAccel(velocity, acceleration, time)
    if not time or time <= 0 then return velocity or Vector3.zero end
    return (velocity or Vector3.zero) + ((acceleration or Vector3.zero) * time)
end

local function brakingDistance(speed, deceleration)
    if deceleration <= 1e-4 then return nil end
    return (speed * speed) / (2 * deceleration)
end

local function brakedSpeed(speed, deceleration, time)
    if speed <= 0 then return 0 end
    if deceleration <= 1e-4 or not time or time <= 0 then return speed end
    return math.max(0, speed - (deceleration * time))
end

local function brakingTravelDist(speed, deceleration, time)
    if speed <= 0 then return 0 end
    if deceleration <= 1e-4 or not time or time <= 0 then
        return speed * math.max(time or 0, 0)
    end
    local stopTime = speed / deceleration
    local ct = math.min(math.max(time, 0), stopTime)
    return (speed * ct) - (0.5 * deceleration * ct * ct)
end

local function clampLeadByBraking(leadOffset, velocity, brakeDist, margin)
    if not brakeDist or brakeDist <= 0 then return leadOffset end
    local speed = velocity.Magnitude
    if speed <= 0.5 then return leadOffset end
    local fwd = velocity.Unit
    local forwardLead = leadOffset:Dot(fwd)
    if forwardLead <= 0 then return leadOffset end
    local maxLead = brakeDist + (margin or 0)
    if forwardLead <= maxLead then return leadOffset end
    return leadOffset + (fwd * (maxLead - forwardLead))
end

-- Export static helpers cho subclasses
PredictionCore.uniformMotionOffset = uniformMotionOffset
PredictionCore.uniformAccelOffset = uniformAccelOffset
PredictionCore.velocityAfterAccel = velocityAfterAccel
PredictionCore.brakingDistance = brakingDistance
PredictionCore.brakedSpeed = brakedSpeed
PredictionCore.brakingTravelDist = brakingTravelDist
PredictionCore.clampLeadByBraking = clampLeadByBraking

-- ═══════════════════════════════════════════════════
-- CONSTRUCTOR
-- ═══════════════════════════════════════════════════

function PredictionCore.new(config, npcTracker)
    local self = setmetatable({}, PredictionCore)
    self.Config = config
    self.Options = config.Options
    self.C = config.Prediction
    self.NPCTracker = npcTracker

    -- Ping cache
    self._cachedPing = 50
    self._lastPingCheck = 0

    -- Profile: sẽ bị override bởi NPCPrediction / PvPPrediction
    self.Profile = {
        KalmanQBoost = 0,
        PingMultiplier = 1,
        ReversalPenalty = 0.6,
        LeadCap = config.Prediction.MAX_LEAD_DIST,
        JumpArcEnabled = false,
        JumpGravity = -196.2,
        JumpArcBlend = 0.7,
    }

    -- Reusable context table (tránh tạo table mới mỗi frame)
    self._brainCtx = {
        CloseOrbitAlpha = 0,
        HitFeedbackAlpha = 0,
        LinearMotionAlpha = 0,
        TeleportAlpha = 0,
        MotionShock = 0,
        BrakingAlpha = 0,
        JerkAlpha = 0,
        DistanceAlpha = 0,
        SpeedAlpha = 0,
        MotionState = "stable",
    }

    return self
end

-- ═══════════════════════════════════════════════════
-- UTILITY METHODS
-- ═══════════════════════════════════════════════════

function PredictionCore:GetNetworkLatency()
    local now = os.clock()
    if now - self._lastPingCheck >= 1 then
        self._lastPingCheck = now
        local ok, _ = pcall(function()
            local raw = game:GetService("Stats").Network.ServerStatsItem("Data Ping"):GetValueString()
            self._cachedPing = tonumber((raw:gsub("[^%d%.]", ""))) or 50
        end)
    end
    return math.clamp(self._cachedPing / 2000, 0, 0.2)
end

-- ═══ Alpha Calculators (inlined math, no table lookups) ═══

function PredictionCore:DistanceAlpha(distance)
    local C = self.C
    return math.clamp((distance - C.DISTANCE_PREDICTION_START) / math.max(C.DISTANCE_PREDICTION_MAX - C.DISTANCE_PREDICTION_START, 1), 0, 1)
end

function PredictionCore:SpeedAlpha(speed)
    local C = self.C
    return math.clamp((speed - C.TELEPORT_THRESHOLD) / math.max(C.EXTREME_SPEED_THRESHOLD - C.TELEPORT_THRESHOLD, 1), 0, 1)
end

function PredictionCore:ExtremeDistAlpha(distance)
    return math.clamp((distance - self.C.DISTANCE_PREDICTION_MAX) / math.max(self.C.DISTANCE_PREDICTION_MAX, 1), 0, 1)
end

-- ═══ Motion Shock ═══

function PredictionCore:MotionShockAlpha(entry, rawVel, filtVel)
    local C = self.C
    if not entry then return 0 end

    local prev = entry.PreviousRawVelocity or rawVel
    entry.PreviousRawVelocity = rawVel

    local prevSpd = prev.Magnitude
    local rawSpd = rawVel.Magnitude

    local revAlpha = 0
    if prevSpd > 8 and rawSpd > 6 then
        revAlpha = math.clamp((-prev.Unit:Dot(rawVel.Unit) - C.REVERSE_RESPONSE_DOT) / 0.9, 0, 1)
    end

    local decAlpha = 0
    if prevSpd > rawSpd then
        decAlpha = math.clamp((prevSpd - rawSpd) / C.DECEL_RESPONSE_THRESHOLD, 0, 1)
    end

    local filtSpd = filtVel.Magnitude
    local lagAlpha = 0
    if filtSpd > 0.01 or rawSpd > 0.01 then
        lagAlpha = math.clamp((rawVel - filtVel).Magnitude / math.max(80, rawSpd * 0.45), 0, 1)
    end

    local shock = math.clamp(math.max(revAlpha, decAlpha * 0.85, lagAlpha * 0.7), 0, 1)
    entry.MotionShock = shock
    return shock
end

-- ═══ Smart Projectile Speed ═══

function PredictionCore:SmartProjectileSpeed(distance, targetSpeed, motionShock)
    local C = self.C
    local dA = self:DistanceAlpha(distance)
    local edA = self:ExtremeDistAlpha(distance)
    local sA = self:SpeedAlpha(targetSpeed)

    local ps = C.SMART_PROJECTILE_SPEED_BASE + (dA * 220) + (edA * 380) - (sA * 650) - (motionShock * 700)
    return math.clamp(ps, C.SMART_PROJECTILE_SPEED_MIN, C.SMART_PROJECTILE_SPEED_MAX)
end

-- ═══ Intercept Solver ═══

function PredictionCore:SolveInterceptTime(shooterPos, targetPos, targetVel, projSpeed)
    if projSpeed <= 0 then return nil end
    local r = targetPos - shooterPos
    local v = targetVel
    local a = v:Dot(v) - (projSpeed * projSpeed)
    local b = 2 * r:Dot(v)
    local c = r:Dot(r)
    if c <= 1e-6 then return 0 end
    if math.abs(a) < 1e-5 then -- Tránh chia cho số gần bằng 0
        if math.abs(b) < 1e-5 then return nil end
        local t = -c / b
        return t > 0 and t or nil
    end
    local disc = (b * b) - (4 * a * c)
    if disc < 0 then return nil end
    local sq = math.sqrt(disc)
    local inv = 1 / (2 * a)
    local t1 = (-b - sq) * inv
    local t2 = (-b + sq) * inv
    local best = nil
    if t1 > 0 then best = t1 end
    if t2 > 0 and (not best or t2 < best) then best = t2 end
    return best
end

function PredictionCore:SolveInterceptPos(shooterPos, targetPos, targetVel, projSpeed)
    local t = self:SolveInterceptTime(shooterPos, targetPos, targetVel, projSpeed)
    if not t then return nil, nil end
    return targetPos + (targetVel * t), t
end

-- ═══ Jerk / Motion State ═══

function PredictionCore:JerkAlpha(entry, acceleration, dt)
    local C = self.C
    if not entry then return 0 end
    local prev = entry.PreviousAcceleration or acceleration
    entry.PreviousAcceleration = acceleration
    local safeDt = math.max(dt or 0, 1 / 240)
    local jerk = (acceleration - prev) / safeDt
    local ja = math.clamp(jerk.Magnitude / C.JERK_THRESHOLD, 0, 1)
    entry.JerkAlpha = ja
    return ja
end

function PredictionCore:UpdateMotionState(entry, velocity, acceleration, jerkAlpha)
    local C = self.C
    if not entry then return "stable", 0, 0 end

    local speed = velocity.Magnitude
    local fwdDecel = 0
    local brakeA = 0

    if speed > 0.5 and acceleration.Magnitude > 0.1 then
        fwdDecel = math.max(-acceleration:Dot(velocity.Unit), 0)
        brakeA = math.clamp((fwdDecel - C.BRAKE_ACCEL_THRESHOLD) / C.BRAKE_ACCEL_THRESHOLD, 0, 1)
    end

    local state = "stable"
    if jerkAlpha >= 0.68 then state = "volatile"
    elseif brakeA >= 0.2 then state = "braking" end

    entry.ForwardDeceleration = fwdDecel
    entry.BrakingAlpha = brakeA
    entry.MotionState = state
    return state, brakeA, fwdDecel
end

function PredictionCore:LinearMotionAlpha(entry, rawVel, filtVel)
    local C = self.C
    if not entry then return 0 end
    local rs = rawVel.Magnitude
    local fs = filtVel.Magnitude
    if rs < 8 or fs < 8 then return 0 end

    local align = rawVel.Unit:Dot(filtVel.Unit)
    if align <= C.LINEAR_MOTION_DOT_THRESHOLD then return 0 end

    local shock = entry.MotionShock or 0
    local accMag = entry.Acceleration and entry.Acceleration.Magnitude or 0
    local aAlpha = math.clamp((align - C.LINEAR_MOTION_DOT_THRESHOLD) / (1 - C.LINEAR_MOTION_DOT_THRESHOLD), 0, 1)
    local accPenalty = math.clamp(accMag / 140, 0, 1)
    local lma = math.clamp(aAlpha * (1 - shock) * (1 - (accPenalty * 0.65)), 0, 1)
    entry.LinearMotionAlpha = lma
    return lma
end

-- ═══ Teleport Detection ═══

function PredictionCore:TeleportAlpha(entry)
    local C = self.C
    if not entry or not entry.LastTeleportTime then return 0 end
    local elapsed = os.clock() - entry.LastTeleportTime
    if elapsed >= C.TELEPORT_MEMORY then return 0 end
    return math.clamp((entry.TeleportStrength or 0) * (1 - (elapsed / C.TELEPORT_MEMORY)), 0, 1)
end

function PredictionCore:UpdateTeleportState(entry, pos)
    local C = self.C
    if not entry or not pos then return 0 end

    local now = os.clock()
    local prevPos = entry.LastTeleportSamplePos
    local prevTime = entry.LastTeleportSampleTime or now
    local tpAlpha = self:TeleportAlpha(entry)

    if prevPos then
        local dt = math.max(now - prevTime, 1 / 240)
        local disp = (pos - prevPos).Magnitude
        local sampSpd = disp / dt
        local trSpd = math.max(
            entry.RealVelocity and entry.RealVelocity.Magnitude or 0,
            entry.LastFilteredVelocity and entry.LastFilteredVelocity.Magnitude or 0,
            entry.SmoothedAimVelocity and entry.SmoothedAimVelocity.Magnitude or 0
        )
        local dynThresh = math.max(C.TELEPORT_DETECTION_DISTANCE, (trSpd * dt) + 10)

        if disp >= dynThresh and sampSpd >= (C.TELEPORT_THRESHOLD * C.TELEPORT_DETECTION_SPEED_RATIO) then
            entry.LastTeleportTime = now
            entry.TeleportStrength = math.clamp(((entry.TeleportStrength or 0) * 0.3) + 1, 0, 1.25)
            tpAlpha = self:TeleportAlpha(entry)
        end
    end

    entry.LastTeleportSamplePos = pos
    entry.LastTeleportSampleTime = now
    entry.TeleportAlpha = tpAlpha
    return tpAlpha
end

-- ═══ Brain Response ═══

function PredictionCore:UpdateBrain(entry, ctx)
    local C = self.C
    if not entry then return C.BRAIN_BASE_RESPONSE end

    local now = os.clock()
    local cur = entry.BrainResponse or C.BRAIN_BASE_RESPONSE
    local dt = math.max(now - (entry.LastBrainUpdate or now), 1 / 240)
    entry.LastBrainUpdate = now

    local demand = (ctx.CloseOrbitAlpha * 0.36) + (ctx.HitFeedbackAlpha * 0.24)
        + (ctx.LinearMotionAlpha * 0.18) + (ctx.TeleportAlpha * 0.34)
        + (ctx.DistanceAlpha * 0.1) + (ctx.SpeedAlpha * 0.08)

    local penalty = (ctx.MotionShock * 0.22) + (ctx.BrakingAlpha * 0.16)
    if ctx.MotionState == "volatile" then penalty = penalty + (ctx.JerkAlpha * 0.24)
    elseif ctx.MotionState == "braking" then penalty = penalty + (ctx.BrakingAlpha * 0.08) end

    local tgt = math.clamp(C.BRAIN_BASE_RESPONSE + demand - penalty, 0.08, 1)
    local bl = math.clamp(C.BRAIN_RESPONSE_SMOOTH + (ctx.CloseOrbitAlpha * 0.2) + (ctx.HitFeedbackAlpha * 0.12) + (ctx.TeleportAlpha * 0.18), C.BRAIN_RESPONSE_SMOOTH, 0.46)
    local alpha = 1 - math.pow(1 - bl, math.max(dt * 60, 1))
    local br = cur + ((tgt - cur) * alpha)
    entry.BrainResponse = br
    return br
end

-- ═══ Hit Feedback ═══

function PredictionCore:HitFeedbackAlpha(entry)
    if not entry or not entry.LastHitTime then return 0 end
    local elapsed = os.clock() - entry.LastHitTime
    if elapsed >= self.C.CLOSE_ORBIT_HIT_MEMORY then return 0 end
    return math.clamp((entry.HitFeedbackStrength or 0) * (1 - (elapsed / self.C.CLOSE_ORBIT_HIT_MEMORY)), 0, 1)
end

function PredictionCore:RegisterHitFeedback(entry, targetPosition)
    if not entry then return end
    entry.LastHitTime = os.clock()
    entry.HitFeedbackStrength = math.clamp(((entry.HitFeedbackStrength or 0) * 0.35) + 0.75, 0, 1.2)
    if targetPosition then entry.LastHitTargetPos = targetPosition end
end

-- ═══ Close Orbit ═══

function PredictionCore:CloseOrbitAlpha(origin, basePos, planarVel, lateralVel)
    local C = self.C
    if not origin or not basePos or not planarVel or not lateralVel then return 0 end
    local toTarget = basePos - origin
    local pd = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
    if pd <= 0.001 then return 0 end

    local dA = math.clamp((C.CLOSE_ORBIT_DISTANCE - pd) / math.max(C.CLOSE_ORBIT_DISTANCE - C.CLOSE_ORBIT_FULL_ALPHA_DISTANCE, 1), 0, 1)
    if dA <= 0 then return 0 end

    local ls = lateralVel.Magnitude
    if ls <= C.CLOSE_ORBIT_STRAFE_THRESHOLD then return 0 end
    local spd = planarVel.Magnitude
    if spd <= 0.001 then return 0 end

    local oR = math.clamp(ls / spd, 0, 1)
    local sA = math.clamp((ls - C.CLOSE_ORBIT_STRAFE_THRESHOLD) / 95, 0, 1)
    return math.clamp(dA * ((oR * 0.65) + (sA * 0.35)), 0, 1)
end

-- ═══ Base Position ═══

function PredictionCore:GetBaseTargetPosition(part)
    local model = part:FindFirstAncestorOfClass("Model")
    if model then
        local n = model.Name:lower()
        if n:find("ball") or n:find("sphere") or n:find("roll") then
            return part.Position
        end
    end
    local att = part:FindFirstChild("RootRigAttachment")
        or part:FindFirstChild("WaistCenterAttachment")
        or part:FindFirstChild("NeckAttachment")
    if att and att:IsA("Attachment") then return att.WorldPosition end
    return part.Position
end

-- ═══ Smooth Aim Velocity ═══

function PredictionCore:SmoothAimVelocity(entry, velocity)
    local C = self.C
    if not entry or not velocity then return velocity or Vector3.zero end

    local now = os.clock()
    if not entry.SmoothedAimVelocity or not entry.LastAimVelocityUpdate then
        entry.SmoothedAimVelocity = velocity
        entry.LastAimVelocityUpdate = now
        return velocity
    end

    local dt = math.max(now - entry.LastAimVelocityUpdate, 1 / 240)
    entry.LastAimVelocityUpdate = now

    if self.Options.AssistMode == "Silent Aim" then
        local cur = entry.SmoothedAimVelocity
        -- Alpha thấp (0.12) cho Silent Aim: ưu tiên độ mượt hơn độ nhạy
        local a = 1 - math.pow(0.12, math.max(dt * 60, 1))
        local s = cur + ((velocity - cur) * a)
        entry.SmoothedAimVelocity = s
        return s
    end

    local cur = entry.SmoothedAimVelocity
    local spd = velocity.Magnitude
    local delta = velocity - cur
    local ms = math.clamp(60 + (spd * 0.35), 60, 800)
    if delta.Magnitude > ms then delta = delta.Unit * ms end

    local bl = math.clamp(0.22 + (math.min(spd, 600) / 1400), 0.22, 0.65)
    bl = bl + ((entry.MotionShock or 0) * 0.1) + ((entry.LinearMotionAlpha or 0) * 0.12)
    local ms2 = entry.MotionState or "stable"
    if ms2 == "volatile" then bl = bl + ((entry.JerkAlpha or 0) * 0.06)
    elseif ms2 == "braking" then bl = bl + ((entry.BrakingAlpha or 0) * 0.05) end
    bl = bl + ((entry.BrainResponse or C.BRAIN_BASE_RESPONSE) * 0.06)
    if spd > C.TELEPORT_THRESHOLD then bl = math.min(bl, 0.35) end
    bl = math.clamp(bl, 0.2, 0.7)

    local a = 1 - math.pow(1 - bl, math.max(dt * 60, 1))
    local sv = cur + (delta * a)
    entry.SmoothedAimVelocity = sv
    return sv
end

-- ═══ Entry Motion Velocity ═══

function PredictionCore:EntryMotionVelocity(entry, part)
    if entry then
        if entry.SmoothedAimVelocity and entry.SmoothedAimVelocity.Magnitude > 0.01 then return entry.SmoothedAimVelocity end
        if entry.LastFilteredVelocity and entry.LastFilteredVelocity.Magnitude > 0.01 then return entry.LastFilteredVelocity end
        if entry.RealVelocity and entry.RealVelocity.Magnitude > 0.01 then return entry.RealVelocity end
    end
    if part then return part.AssemblyLinearVelocity end
    return Vector3.zero
end

-- ═══════════════════════════════════════════════════
-- CORE PREDICTION
-- ═══════════════════════════════════════════════════

function PredictionCore:PredictTargetPosition(origin, part, entry)
    local C = self.C
    local P = self.Profile
    local basePos = part.Position
    local att = part:FindFirstChild("RootRigAttachment") or part:FindFirstChild("WaistCenterAttachment") or part:FindFirstChild("NeckAttachment")
    if att and att:IsA("Attachment") then basePos = att.WorldPosition end

    if not self.Options.PredictionEnabled then
        if self.Options.AimOffset ~= 0 then
            basePos = basePos + Vector3.new(0, self.Options.AimOffset, 0)
        end
        return basePos
    end

    local now = os.clock()

    -- PERIODIC REFRESH: Reset partial state mỗi 15 giây để tránh drift
    if not entry._lastRefreshTime then entry._lastRefreshTime = now end
    if (now - entry._lastRefreshTime) >= 15 then
        entry._lastRefreshTime = now
        entry.KalmanP = math.clamp(entry.KalmanP, 0.5, 2) -- Normalize KalmanP
        entry.Confidence = math.max(entry.Confidence, 0.7)  -- Phục hồi confidence
        if entry.Acceleration and entry.Acceleration.Magnitude > 200 then
            entry.Acceleration = entry.Acceleration.Unit * 100 -- Giảm acceleration tích lũy
        end
    end

    -- BƯỚC 1: Raw Velocity
    local rawVel = Vector3.zero
    local dt = 0.03
    if not entry.LastPos then
        entry.LastPos = basePos
        entry.LastTime = now
        entry.Confidence = 1
        entry.Acceleration = Vector3.zero
        entry.KalmanV = Vector3.zero
        entry.KalmanP = 1
    else
        dt = math.max(now - entry.LastTime, 0.001) -- Chốt chặn dt không được bằng 0
        if dt >= 0.015 then
            local newVel = (basePos - entry.LastPos) / dt
            -- Chốt chặn vận tốc quá ảo (do teleport hoặc lag cực nặng)
            if newVel.Magnitude < 2000 then
                rawVel = newVel
            else
                rawVel = entry.RealVelocity or Vector3.zero
            end
            entry.LastPos = basePos
            entry.LastTime = now
        else
            rawVel = entry.RealVelocity or Vector3.zero
        end
    end
    entry.RealVelocity = rawVel

    -- BƯỚC 2: Kalman Filter (Profile-tuned Q boost)
    local velErr = (rawVel - entry.KalmanV).Magnitude
    local q = 0.15 + math.clamp(velErr / 28, 0, 2.0) + P.KalmanQBoost
    local r = 0.3
    entry.KalmanP = math.clamp(entry.KalmanP + q, 0.01, 10) -- CLAMP: tránh drift vô hạn
    local k = entry.KalmanP / (entry.KalmanP + r)
    entry.KalmanV = entry.KalmanV + k * (rawVel - entry.KalmanV)
    entry.KalmanP = math.clamp((1 - k) * entry.KalmanP, 0.01, 10)

    local filtVel = entry.KalmanV

    -- Physics blend
    local physVel = part.AssemblyLinearVelocity
    if physVel.Magnitude > 2 then
        local safeY = physVel.Y
        if math.abs(safeY) < 15 then safeY = 0 else safeY = math.clamp(safeY, -60, 60) end
        local adjPhys = Vector3.new(physVel.X, safeY, physVel.Z)
        local lma = entry.LinearMotionAlpha or 0
        filtVel = filtVel:Lerp(adjPhys, 0.45 + (lma * 0.25))
    end

    -- BEAM ZERO-LAG
    local lma = entry.LinearMotionAlpha or 0
    if lma > 0.3 then
        filtVel = filtVel:Lerp(rawVel, math.clamp((lma - 0.3) / 0.7, 0, 1) * 0.50)
        entry.KalmanV = filtVel
    end

    local motionShock = self:MotionShockAlpha(entry, rawVel, filtVel)
    if motionShock > 0 then
        filtVel = filtVel:Lerp(rawVel, 0.3 + (motionShock * 0.55))
        entry.KalmanV = filtVel
        entry.KalmanP = math.max(entry.KalmanP, 1 + motionShock)
    end

    -- BƯỚC 3: Confidence (với recovery nhanh hơn cho boss fights dài)
    if entry.LastExpectedPos then
        local errDist = (basePos - entry.LastExpectedPos).Magnitude
        local errPenalty = math.clamp(errDist / 8, 0, 0.3)
        -- Recovery rate tăng lên 0.15 (từ 0.1) để confidence không bị stuck ở 0.4
        local recovery = 0.15
        entry.Confidence = math.clamp(entry.Confidence - errPenalty + recovery, 0.4, 1)
    else
        entry.Confidence = 1
    end

    -- BƯỚC 4: Acceleration (với magnitude clamp tránh drift)
    if entry.LastFilteredVelocity then
        local rawAcc = (filtVel - entry.LastFilteredVelocity) / dt
        -- Clamp acceleration magnitude để tránh tích lũy sai số
        if rawAcc.Magnitude > 500 then rawAcc = rawAcc.Unit * 500 end
        local accSmooth = (rawAcc - entry.Acceleration).Magnitude > 80 and 0.8 or 0.2
        entry.Acceleration = entry.Acceleration:Lerp(rawAcc, accSmooth)
        -- Clamp kết quả cuối
        if entry.Acceleration.Magnitude > 400 then
            entry.Acceleration = entry.Acceleration.Unit * 400
        end
    end
    entry.LastFilteredVelocity = filtVel

    -- Reversal (Profile-tuned penalty)
    if rawVel.Magnitude > 5 and filtVel.Magnitude > 5 then
        if rawVel.Unit:Dot(filtVel.Unit) < -0.3 then
            entry.Confidence = math.max(entry.Confidence * P.ReversalPenalty, 0.4)
            entry.Acceleration = Vector3.zero
        end
    end

    -- Deadzone
    local speed = filtVel.Magnitude
    if speed < 3.5 then
        filtVel = Vector3.zero
        entry.Acceleration = Vector3.zero
    end

    local jerkA = self:JerkAlpha(entry, entry.Acceleration, dt)
    local motState, brakeA, fwdDecel = self:UpdateMotionState(entry, filtVel, entry.Acceleration, jerkA)
    local tpAlpha = self:UpdateTeleportState(entry, basePos)
    if tpAlpha > 0 then
        filtVel = filtVel:Lerp(rawVel, 0.18 + (tpAlpha * 0.5))
        entry.KalmanV = filtVel
        entry.Confidence = math.max(entry.Confidence, 0.58 + (tpAlpha * 0.35))
    end

    -- BƯỚC 5: Latency Compensation
    local latency = self:GetNetworkLatency()
    local totalTime = latency * P.PingMultiplier
    local leadOffset = Vector3.zero

    if speed > 0.5 then
        local dist = (basePos - origin).Magnitude
        local dA = self:DistanceAlpha(dist)
        local edA = self:ExtremeDistAlpha(dist)
        local sA = self:SpeedAlpha(speed)
        local linA = self:LinearMotionAlpha(entry, rawVel, filtVel)

        -- Reuse brain context table (zero alloc)
        local ctx = self._brainCtx
        ctx.LinearMotionAlpha = linA
        ctx.TeleportAlpha = tpAlpha
        ctx.MotionShock = motionShock
        ctx.BrakingAlpha = brakeA
        ctx.JerkAlpha = jerkA
        ctx.DistanceAlpha = dA
        ctx.SpeedAlpha = sA
        ctx.MotionState = motState
        ctx.CloseOrbitAlpha = 0
        ctx.HitFeedbackAlpha = 0

        local brainR = self:UpdateBrain(entry, ctx)
        local usedIntercept = false

        if self.Options.SmartPrediction then
            local ps = self:SmartProjectileSpeed(dist, speed, motionShock)
            local rbI = math.clamp(linA * 0.7, 0, 0.7)
            local iVel = filtVel:Lerp(rawVel, rbI)
            local iPos, iTime = self:SolveInterceptPos(origin, basePos, iVel, ps)
            if iTime then
                leadOffset = iPos - basePos
                totalTime = latency + iTime
                usedIntercept = true
            else
                totalTime = totalTime + 0.035 + (dist / C.SMART_PROJECTILE_SPEED_BASE)
                if speed > 40 then totalTime = (totalTime * math.clamp(speed / 80, 1.05, 1.9)) + 0.015 end
            end
        else
            totalTime = totalTime + 0.016 + (dist / 6800)
            if speed > 40 then totalTime = (totalTime * math.clamp(speed / 110, 1.02, 1.45)) + 0.008 end
        end

        totalTime = totalTime * C.BEAM_TIME_BIAS
        totalTime = totalTime + math.clamp(dt, 1/120, 1/30)
        totalTime = totalTime * (1 + (dA * C.DISTANCE_TIME_GAIN) + (edA * C.EXTREME_DISTANCE_TIME_GAIN) + (dA * sA * 0.35))
        totalTime = totalTime * (1 - (motionShock * 0.12))
        totalTime = totalTime + ((C.LINEAR_MOTION_TIME_BONUS + (dA * 0.008) + (edA * 0.012)) * linA * (0.9 + (brainR * 0.35)))
        if motState == "volatile" then totalTime = totalTime * (1 - (jerkA * 0.1)) end

        -- Accel correction
        local accelOff = uniformAccelOffset(Vector3.zero, entry.Acceleration, totalTime)
        if sA > 0 then accelOff = accelOff * (1 - (sA * 0.3)) end
        if motionShock > 0 then accelOff = accelOff * (1 - (motionShock * 0.35)) end
        if motState == "braking" then accelOff = accelOff * (1 - (brakeA * 0.7))
        elseif motState == "volatile" then accelOff = accelOff * (1 - (jerkA * 0.55)) end

        local accelCap = math.min(C.MAX_LEAD_DIST * 0.4, ((leadOffset.Magnitude > 0 and leadOffset.Magnitude or (speed * totalTime)) * C.ACCEL_CORRECTION_MAX_RATIO) + 10)
        if accelOff.Magnitude > accelCap then accelOff = accelOff.Unit * accelCap end

        if usedIntercept then
            local bVel = filtVel:Lerp(rawVel, math.clamp(linA * 0.55, 0, 0.55))
            local sLead = uniformMotionOffset(bVel, totalTime)
            local iBlend = math.clamp(0.78 + (dA * 0.1) + (edA * 0.1) + (linA * 0.06), 0.78, 0.95)
            leadOffset = leadOffset:Lerp(sLead, 1 - iBlend)
        else
            local bVel = filtVel:Lerp(rawVel, math.clamp(linA * 0.5, 0, 0.5))
            leadOffset = uniformMotionOffset(bVel, totalTime)
        end

        leadOffset = leadOffset + accelOff

        -- Braking clamp
        if motState == "braking" and fwdDecel > 0 then
            local bd = brakingDistance(speed, fwdDecel)
            local btd = brakingTravelDist(speed, fwdDecel, totalTime)
            local rbs = brakedSpeed(speed, fwdDecel, totalTime)
            local mbl = btd
            if bd then mbl = math.min(mbl, bd) end
            leadOffset = clampLeadByBraking(leadOffset, filtVel, mbl, C.BRAKE_DISTANCE_MARGIN + (rbs * C.BRAKE_DISTANCE_SPEED_MARGIN) + (dA * 4) + (edA * 6))
        end

        -- Catchup leads
        if linA > 0 then
            local lcl = uniformMotionOffset(filtVel, (0.013 + (dA * 0.01) + (edA * 0.015)) * linA * (0.78 + (brainR * 0.55)))
            local lcCap = C.MAX_LEAD_DIST * (0.12 + (dA * 0.12) + (edA * 0.16))
            if lcl.Magnitude > lcCap then lcl = lcl.Unit * lcCap end
            leadOffset = leadOffset + lcl
        end
        if dA > 0 or edA > 0 or sA > 0 then
            local cl = uniformMotionOffset(filtVel, (0.015 + (dA * 0.06) + (edA * 0.08) + (sA * 0.045)) * (0.82 + (brainR * 0.4)))
            local cCap = C.MAX_LEAD_DIST * (0.18 + (dA * 0.35) + (edA * 0.5) + (sA * 0.1))
            if cl.Magnitude > cCap then cl = cl.Unit * cCap end
            if motState == "braking" then cl = cl * (1 - (brakeA * 0.85))
            elseif motState == "volatile" then cl = cl * (1 - (jerkA * 0.45)) end
            leadOffset = leadOffset + cl
        end

        -- Confidence + Lead Cap (Profile-tuned)
        leadOffset = leadOffset * entry.Confidence
        local dynCap = P.LeadCap * (1 + (dA * 0.9) + (edA * 1.15) + (sA * 0.35))
        if leadOffset.Magnitude > dynCap then leadOffset = leadOffset.Unit * dynCap end

        -- Jump Arc (only if Profile enables it)
        if P.JumpArcEnabled and entry.Humanoid then
            if entry.Humanoid.FloorMaterial == Enum.Material.Air then
                local vy = rawVel.Y
                local jLead = (vy * totalTime) + (0.5 * P.JumpGravity * totalTime * totalTime)
                leadOffset = leadOffset + Vector3.new(0, jLead * P.JumpArcBlend, 0)
            end
        end
    end

    local finalPos = basePos + leadOffset

    -- Frame feedback cache
    entry.LastExpectedPos = basePos + uniformAccelOffset(filtVel, entry.Acceleration, dt)
    entry.LastExpectedVelocity = velocityAfterAccel(filtVel, entry.Acceleration, dt)

    if self.Options.AimOffset ~= 0 then
        finalPos = finalPos + Vector3.new(0, self.Options.AimOffset, 0)
    end

    return finalPos
end

-- ═══════════════════════════════════════════════════
-- STRAFE ENHANCED PREDICTION
-- ═══════════════════════════════════════════════════

function PredictionCore:PredictWithStrafe(origin, part, entry)
    local C = self.C
    local P = self.Profile
    local predicted = self:PredictTargetPosition(origin, part, entry)
    if not self.Options.PredictionEnabled or not entry or not part then return predicted end

    local basePos = self:GetBaseTargetPosition(part)
    local toTgt = basePos - origin
    local planarDir = Vector3.new(toTgt.X, 0, toTgt.Z)
    local planarDist = planarDir.Magnitude
    if planarDist < 0.001 then return predicted end
    planarDir = planarDir.Unit

    local dA = self:DistanceAlpha(planarDist)
    local edA = self:ExtremeDistAlpha(planarDist)

    local filtVel = entry.LastFilteredVelocity or part.AssemblyLinearVelocity or Vector3.zero
    local rawVel = entry.RealVelocity or filtVel

    local pFilt = Vector3.new(filtVel.X, 0, filtVel.Z)
    local pRaw = Vector3.new(rawVel.X, 0, rawVel.Z)
    if pRaw.Magnitude > 6 and pFilt.Magnitude > 0.1 then
        if pRaw.Unit:Dot(pFilt.Unit) < 0.2 then
            filtVel = Vector3.new(rawVel.X, filtVel.Y, rawVel.Z)
            pFilt = Vector3.new(filtVel.X, 0, filtVel.Z)
        end
    end

    filtVel = self:SmoothAimVelocity(entry, filtVel)
    pFilt = Vector3.new(filtVel.X, 0, filtVel.Z)

    local latVel = pFilt - planarDir * pFilt:Dot(planarDir)
    local strafeSpd = latVel.Magnitude
    local sA = self:SpeedAlpha(strafeSpd)
    local shock = entry.MotionShock or 0
    local jA = entry.JerkAlpha or 0
    local mSt = entry.MotionState or "stable"
    local bA = entry.BrakingAlpha or 0
    local linA = entry.LinearMotionAlpha or 0
    local hfA = self:HitFeedbackAlpha(entry)
    local tpA = entry.TeleportAlpha or 0
    local coA = self:CloseOrbitAlpha(origin, basePos, pFilt, latVel)

    -- Reuse context table
    local ctx = self._brainCtx
    ctx.CloseOrbitAlpha = coA
    ctx.HitFeedbackAlpha = hfA
    ctx.LinearMotionAlpha = linA
    ctx.TeleportAlpha = tpA
    ctx.MotionShock = shock
    ctx.BrakingAlpha = bA
    ctx.JerkAlpha = jA
    ctx.DistanceAlpha = dA
    ctx.SpeedAlpha = sA
    ctx.MotionState = mSt

    local brainR = self:UpdateBrain(entry, ctx)
    if strafeSpd < 6 then return predicted end

    local eTime = self.Options.SmartPrediction
        and math.clamp(0.022 + (planarDist / 5600) + (strafeSpd / 2400), 0.02, 0.11)
        or math.clamp(0.018 + (planarDist / 6800) + (strafeSpd / 3200), 0.018, 0.08)

    local eScale = math.clamp(0.9 + (planarDist / 1800) + (strafeSpd / 220), 0.9, 1.95)
    local confScale = math.clamp(0.55 + ((entry.Confidence or 1) * 0.45), 0.35, 1.0)

    eTime = eTime * C.BEAM_STRAFE_BIAS
    eTime = eTime * (1 + (dA * 0.75) + (edA * C.EXTREME_DISTANCE_STRAFE_GAIN) + (dA * sA * 0.35))
    eTime = eTime * (1 - (shock * 0.28))
    if mSt == "volatile" then eTime = eTime * (1 - (jA * 0.18))
    elseif mSt == "braking" then eTime = eTime * (1 - (bA * 0.25)) end
    if coA > 0 then eTime = eTime + (C.CLOSE_ORBIT_LEAD_BONUS_TIME * coA * (0.55 + brainR)) end

    eScale = math.clamp(eScale * (1 + (dA * C.DISTANCE_STRAFE_GAIN) + (edA * 1.25) + (sA * 0.25)), 0.9, 3.4)
    if coA > 0 then eScale = math.clamp(eScale * (1 + (coA * 0.18) + (brainR * 0.32)), 0.9, 3.7) end
    if shock > 0 then
        local rLat = pRaw - planarDir * pRaw:Dot(planarDir)
        latVel = latVel:Lerp(rLat, 0.25 + (shock * 0.45))
    end
    if coA > 0 then
        local rLat = pRaw - planarDir * pRaw:Dot(planarDir)
        latVel = latVel:Lerp(rLat, 0.14 + (coA * 0.18) + (brainR * 0.16))
    end

    local eLead = latVel * eTime * eScale * confScale
    if mSt == "braking" then eLead = eLead * (1 - (bA * 0.7))
    elseif mSt == "volatile" then eLead = eLead * (1 - (jA * 0.35)) end
    if coA > 0 then
        local ocl = uniformMotionOffset(latVel, (0.006 + (coA * 0.006) + (brainR * 0.012)) * (0.82 + (confScale * 0.35)))
        local ocCap = C.MAX_STRAFE_LEAD * (0.14 + (coA * 0.12) + (brainR * 0.14))
        if ocl.Magnitude > ocCap then ocl = ocl.Unit * ocCap end
        eLead = eLead + ocl
    end

    local dsCap = C.MAX_STRAFE_LEAD * (1 + (dA * 1.35) + (edA * 1.55) + (sA * 0.35))
    if eLead.Magnitude > dsCap then eLead = eLead.Unit * dsCap end

    return predicted + eLead
end

-- ═══════════════════════════════════════════════════
-- SELECTION TARGET POSITION (Lightweight for scanning)
-- ═══════════════════════════════════════════════════

function PredictionCore:GetSelectionTargetPosition(origin, part, entry, isCurrentTarget)
    local C = self.C
    local pos = self:GetBaseTargetPosition(part)

    if self.Options.AimOffset ~= 0 then
        pos = pos + Vector3.new(0, self.Options.AimOffset, 0)
    end

    if isCurrentTarget and entry and entry.StabilizedTargetPos then
        return entry.StabilizedTargetPos
    end

    local vel = Vector3.zero
    if entry then
        vel = entry.SmoothedAimVelocity or entry.LastFilteredVelocity or entry.RealVelocity or Vector3.zero
    end
    if vel == Vector3.zero and part then
        vel = part.AssemblyLinearVelocity
    end

    local spd = vel.Magnitude
    if spd > 0.5 then
        local dist = (pos - origin).Magnitude
        local dA = self:DistanceAlpha(dist)
        local edA = self:ExtremeDistAlpha(dist)
        local sTime = (0.008 + (dist / 12000)) * (1 + (dA * 0.25) + (edA * 0.35))
        if spd > C.TELEPORT_THRESHOLD then sTime = sTime * 1.08 end
        pos = pos + uniformMotionOffset(vel, math.clamp(sTime, 0.008, 0.09))
    end

    return pos
end

-- ═══════════════════════════════════════════════════
-- STABILIZE TARGET POSITION
-- ═══════════════════════════════════════════════════

function PredictionCore:StabilizeTargetPosition(entry, part, rawPos, deltaTime)
    local C = self.C
    if not entry or not part or not rawPos then return rawPos end

    if self.Options.AssistMode == "Silent Aim" then
        local cur = entry.StabilizedTargetPos
        if not cur then entry.StabilizedTargetPos = rawPos; return rawPos end
        local d = rawPos - cur
        local dm = d.Magnitude
        -- Snap ngay nếu thay đổi quá lớn (target mới hoặc teleport)
        if dm > 50 then entry.StabilizedTargetPos = rawPos; return rawPos end
        -- Deadzone: bỏ qua rung nhỏ hơn 1.2 studs
        if dm < 1.2 then return cur end
        -- Smoothing mạnh (0.08) để giảm rung đáng kể
        local a = 1 - math.pow(0.08, math.max((deltaTime or (1/60)) * 60, 1))
        local r = cur:Lerp(rawPos, a)
        entry.StabilizedTargetPos = r
        return r
    end

    local now = os.clock()
    if not entry.StabilizedTargetPos or not entry.LastStabilizedUpdate then
        entry.StabilizedTargetPos = rawPos
        entry.LastStabilizedUpdate = now
        return rawPos
    end

    local dt = math.max(deltaTime or (now - entry.LastStabilizedUpdate), 1 / 240)
    entry.LastStabilizedUpdate = now

    local cur = entry.StabilizedTargetPos
    local delta = rawPos - cur
    local dMag = delta.Magnitude
    local vel = self:EntryMotionVelocity(entry, part)
    local spd = vel.Magnitude
    local shock = entry.MotionShock or 0
    local brainR = entry.BrainResponse or C.BRAIN_BASE_RESPONSE
    local linA = entry.LinearMotionAlpha or 0
    local bp = self:GetBaseTargetPosition(part)
    local leadMag = (rawPos - bp).Magnitude
    local lowNoise = math.clamp((1 - shock) * (1 - math.clamp((entry.Acceleration and entry.Acceleration.Magnitude or 0) / 120, 0, 1)), 0, 1)

    local snapDist = math.clamp(12 + (spd * 0.04) + (leadMag * 0.4), 12, 180)
    if dMag >= snapDist then entry.StabilizedTargetPos = rawPos; return rawPos end

    local dz = math.clamp(0.1 + (leadMag * 0.01) + (math.min(spd, 900) / 1200), 0.08, 1.8)
    local mSt = entry.MotionState or "stable"
    if mSt == "volatile" then dz = math.max(dz * (1 - ((entry.JerkAlpha or 0) * 0.4)), 0.05)
    elseif mSt == "braking" then dz = dz * (1 - ((entry.BrakingAlpha or 0) * 0.3))
    elseif mSt == "stable" then dz = dz * (1 - (linA * 0.3)) end
    dz = dz * (1 - (brainR * 0.25))
    if dMag <= dz then return cur end

    local resp = math.clamp(0.35 + (math.min(spd, 500) / 800) + (leadMag / 200), 0.35, 0.85)
    resp = resp * (1 - (lowNoise * C.STABILIZE_LOW_NOISE_RESPONSE_DAMP * 0.5)) + (linA * 0.15)
    local a = 1 - math.pow(1 - resp, math.max(dt * 60, 1))
    local stab = cur:Lerp(rawPos, a)
    entry.StabilizedTargetPos = stab
    return stab
end

return PredictionCore
