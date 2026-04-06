--[[
    ===============================================================
         Boss Aim Assist - Centralized Brain Orchestration v6       
      Scientifically Reorganized | Fully Decoupled | Brain Driven  
    ===============================================================
]]

local BUNDLED_SOURCES = {
    ["Data/Config.lua"] = [====[--[[
    Config.lua - Shared configuration
    Central options, prediction constants, and blacklist entries.
]]

local Config = {}

Config.Options = {
    AssistMode = "Off",
    HoldMouse2ToAssist = true,
    PredictionEnabled = true,
    TargetPlayersToggle = false,
    SmartPrediction = true,
    PredictionTechniqueMode = "Assisted",
    PredictionTechnique = "Linear",
    PredictionTechniqueDebug = false,
    TargetPart = "HumanoidRootPart",
    TargetingMethod = "FOV",
    AdaptiveTargetScan = true,
    TargetScanHz = 120,
    AimOffset = 0,
    FOV = 150,
    ShowFOV = true,
    Smoothness = 0.18,
    MaxDistance = 1500,
    ProjectileVelocity = 250,
    ToggleUIKey = "RightControl",
    NoSlowdown = false,
    NoDelay = false,
    NoStun = false,
    CustomMoveSpeedEnabled = false,
    CustomMoveSpeed = 16,
    GravityEnabled = false,
    GravityValue = 196.2,
    FloatEnabled = false,
    FloatFallSpeed = 8,
    JumpBoostEnabled = false,
    JumpBoostPower = 70,
    SpeedMultiplierEnabled = false,
    SpeedMultiplier = 1.0,
    SpeedSpoofEnabled = false,
    RuntimeStatsDebug = false,
    AutoCleanEnabled = true,
    SmartCleanupEnabled = true,
    AutoUpdateEnabled = false,
    AutoUpdateIntervalMinutes = 5,
    RejoinOnKickEnabled = false,
    NoclipEnabled = false,
    KillPartBypassEnabled = false,
    ProactiveEvadeEnabled = false,
    ProactiveEvadeStride = 4.5,
    ProactiveEvadeInterval = 0.42,
    ZenithDesyncEnabled = false,
    SilentDamageEnabled = false,
    TeleportMethod = "Tween",
    TeleportTweenSpeed = 150,
}

Config.Prediction = {
    TELEPORT_THRESHOLD = 350,
    MAX_LEAD_DIST = 340,
    MAX_STRAFE_LEAD = 280,
    BEAM_TIME_BIAS = 0.92,
    BEAM_STRAFE_BIAS = 0.78,
    DISTANCE_PREDICTION_START = 180,
    DISTANCE_PREDICTION_MAX = 1800,
    DISTANCE_TIME_GAIN = 0.68,
    DISTANCE_STRAFE_GAIN = 1.2,
    EXTREME_SPEED_THRESHOLD = 1600,
    EXTREME_DISTANCE_TIME_GAIN = 0.82,
    EXTREME_DISTANCE_STRAFE_GAIN = 1.18,
    SMART_PROJECTILE_SPEED_BASE = 5200,
    SMART_PROJECTILE_SPEED_MIN = 3400,
    SMART_PROJECTILE_SPEED_MAX = 6200,
    LINEAR_MOTION_DOT_THRESHOLD = 0.91,
    LINEAR_MOTION_TIME_BONUS = 0.02,
    STABILIZE_LOW_NOISE_RESPONSE_DAMP = 0.14,
    CLOSE_ORBIT_DISTANCE = 135,
    CLOSE_ORBIT_FULL_ALPHA_DISTANCE = 42,
    CLOSE_ORBIT_STRAFE_THRESHOLD = 14,
    CLOSE_ORBIT_LEAD_BONUS_TIME = 0.018,
    CLOSE_ORBIT_HIT_MEMORY = 0.65,
    TELEPORT_DETECTION_DISTANCE = 22,
    TELEPORT_DETECTION_SPEED_RATIO = 0.55,
    TELEPORT_MEMORY = 0.9,
    BRAIN_BASE_RESPONSE = 0.28,
    BRAIN_RESPONSE_SMOOTH = 0.2,
    BRAKE_ACCEL_THRESHOLD = 20,
    BRAKE_DISTANCE_MARGIN = 6,
    BRAKE_DISTANCE_SPEED_MARGIN = 0.032,
    ACCEL_CORRECTION_MAX_RATIO = 0.38,
    JERK_THRESHOLD = 220,
    DECEL_RESPONSE_THRESHOLD = 220,
    REVERSE_RESPONSE_DOT = -0.05,
    GRACE_PERIOD = 0.5,
}

Config.PvP = {
    PING_MULTIPLIER = 2.0,
    MAX_LEAD_DIST = 180,
    ZIGZAG_DAMPEN = 0.55,
    JUMP_GRAVITY = -196.2,
    JUMP_ARC_BLEND = 0.7,
    KALMAN_Q_BOOST = 0.3,
    ACCEL_CORRECTION_CAP = 0.25,
}

Config.Blacklist = {
    "statue", "tuong", "monument", "altar", "dummy",
    "bomb", "seed", "projectile", "effect", "particle",
    "bullet", "mine", "trap", "spawn", "debris",
    "decoration", "sculpture", "deco", "prop", "marker", "part",
    "object", "model", "tree", "rock", "stone", "grass",
    "tele", "rsbroad", "landscape", "terrain", "sign", "board",
}

return Config
]====],
    ["Data/Version.lua"] = [====[return 130 -- Version 1.2.0 (Auto Update Runtime / Player Mobility Additions)
]====],
    ["LocalLoader.lua"] = [====[--[[
    STAR GLITCHER ~ LOCAL LOADER
    Use this script to run the fixed version from your local computer.
    Instructions:
    1. Make sure the folder "STAR GLITCHER ~ REVITALIZED" is in your executor's workspace folder.
    2. Run this script in your executor.
]]

_G.BossAimAssist_LocalPath = "STAR GLITCHER ~ REVITALIZED/"

local function loadLocalFile(path)
    if readfile then
        local ok, content = pcall(readfile, _G.BossAimAssist_LocalPath .. path)
        if ok and content then
            return content
        end
    end
    return nil
end

local mainContent = loadLocalFile("Core/Main.lua")
if mainContent then
    print(" [Loader] Loading Star Glitcher from local workspace...")
    local chunk, err = loadstring(mainContent, "=Core/Main.lua")
    if chunk then
        chunk()
    else
        warn(" [Loader] Failed to compile Main.lua: " .. tostring(err))
    end
else
    warn(" [Loader] Could not find Core/Main.lua in workspace/" .. _G.BossAimAssist_LocalPath)
    warn("Please ensure you have copied the folder correctly to your executor's workspace.")
end

]====],
    ["Modules/Combat/Aimbot.lua"] = [====[local Workspace = game:GetService("Workspace")

local Aimbot = {}
Aimbot.__index = Aimbot

function Aimbot.new(config)
    local self = setmetatable({}, Aimbot)
    self.Config = config
    self.Options = config.Options
    self.Active = false
    return self
end

function Aimbot:Init()
    self.Active = false
end

function Aimbot:Update(targetPosition, smoothness)
    if not targetPosition then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local baseAlpha = math.clamp(smoothness or self.Options.Smoothness or 0.15, 0.01, 1)
    local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPosition)

    if targetPosition.X == targetPosition.X then
        local angleDot = math.clamp(camera.CFrame.LookVector:Dot(targetCFrame.LookVector), -1, 1)
        local angle = math.acos(angleDot)
        local angleBoost = math.clamp(angle / math.rad(15), 0, 1) * 0.45
        local alpha = math.clamp(baseAlpha + angleBoost, baseAlpha, 0.95)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
    end
end

function Aimbot:SetState(active)
    self.Active = active
end

function Aimbot:Destroy()
    self.Active = false
end

return Aimbot
]====],
    ["Modules/Combat/Prediction/Base.lua"] = [====[--[[
    Base.lua - Scientific Physics Core (Smart Prediction)
    Implements advanced kinematic equations:
    * Uniform Linear Motion: s = vt
    * Uniformly Accelerated Motion: s = v0t + 0.5at^2
    * Braking/Deceleration compensation
    * Jerk-aware extrapolation
]]

local Base = {}
Base.__index = Base

function Base.new(config)
    local self = setmetatable({}, Base)
    self.Config = config
    self.Options = config.Options
    return self
end

function Base:Calculate(origin, part, velocity, acceleration, jerk, dt)
    local targetPos = part.Position
    local dist = (targetPos - origin).Magnitude
    
    -- 1. Travel Time Estimation (Projectile/Spell flight)
    -- Neu la Beam (toc do anh sang), travelTime ~ 0.
    -- Voi phep thuat co van toc, travelTime = dist / bulletSpeed.
    local travelTime = (dist / 1000) * (self.Options.PredictionScale or 1)
    
    -- 2. Kinematic Equations Dispatch
    local predictedOffset = Vector3.zero
    
    if acceleration and acceleration.Magnitude > 0.05 then
        -- Chuyn dong co gia toc deu: s = vt + 0.5at^2
        predictedOffset = (velocity * travelTime) + (0.5 * acceleration * travelTime * travelTime)
        
        -- Jerk compensation: s += (1/6) * j * t^3
        if jerk and jerk.Magnitude > 0.01 then
            predictedOffset = predictedOffset + ( (1/6) * jerk * math.pow(travelTime, 3) )
        end
    else
        -- Chuyn dong thng deu: s = vt
        predictedOffset = velocity * travelTime
    end
    
    -- 3. Braking / Deceleration Logic (Quang duong phanh)
    -- Neu van toc dang giam manh (a nguoc chieu v), chung ta bu tru quang duong phanh
    local speed = velocity.Magnitude
    if speed > 1 and acceleration then
        local dot = velocity.Unit:Dot(acceleration.Unit)
        if dot < -0.7 then -- dang phanh/ham
            local deceleration = acceleration.Magnitude
            -- s_phanh = v^2 / 2a (Cong thuc quang duong ham)
            local brakingDist = (speed * speed) / (2 * deceleration)
            
            -- Gioi han bu tru phanh d tranh jitter
            brakingDist = math.min(brakingDist, 5) 
            predictedOffset = predictedOffset + (acceleration.Unit * brakingDist * 0.5)
        end
    end
    
    return targetPos + predictedOffset
end

return Base

]====],
    ["Modules/Combat/Prediction/Engine.lua"] = [====[--[[
    Engine.lua - Orthogonal Prediction Strategies
    Analogy: The Cognitive Decision Process.
    Job: Select exactly ONE strategy per frame: Intercept or Linear Extrapolation.
]]

local Engine = {}
Engine.__index = Engine

local Stats = game:GetService("Stats")
local DEFAULT_PROJECTILE_SPEED = 1000
local ZERO = Vector3.zero

local TARGET_PROFILE_BOX = "box"
local TARGET_PROFILE_SPHERE = "sphere"
local TARGET_PROFILE_MINI_HUMANOID = "mini_humanoid"
local TARGET_PROFILE_HUMANOID = "humanoid"

function Engine.new(config)
    local self = setmetatable({}, Engine)
    self.Config = config
    self.Options = config.Options
    self.Prediction = config.Prediction or {}
    self.PvP = config.PvP or {}
    self._cachedPing = 50
    self._lastPingCheck = 0
    return self
end

function Engine:_GetLatency()
    local now = os.clock()
    if now - self._lastPingCheck >= 1 then
        self._lastPingCheck = now
        pcall(function()
            local raw = Stats.Network.ServerStatsItem("Data Ping"):GetValueString()
            self._cachedPing = tonumber((raw:gsub("[^%d%.]", ""))) or self._cachedPing
        end)
    end
    return math.clamp(self._cachedPing / 2000, 0, 0.2)
end

function Engine:_GetPingMultiplier()
    if self.Options.TargetPlayersToggle then
        return math.clamp(self.PvP.PING_MULTIPLIER or 1.5, 1, 2.25)
    end
    return 1
end

function Engine:_ResolveTargetProfile(entry, part)
    if not part then
        return TARGET_PROFILE_BOX, 0
    end

    local size = part.Size
    local model = entry and entry.Model
    local humanoid = entry and entry.Humanoid

    if humanoid then
        local modelHeight = 0
        if model then
            local extents = model:GetExtentsSize()
            modelHeight = extents.Y
        end

        local isMiniHumanoid = size.Y <= 2.6
            or size.X <= 2.6
            or modelHeight > 0 and modelHeight <= 4.25
            or humanoid.HipHeight <= 1.5

        if isMiniHumanoid then
            return TARGET_PROFILE_MINI_HUMANOID, math.clamp(math.max(size.Y * 0.3, modelHeight * 0.12), 0.35, 0.85)
        end

        return TARGET_PROFILE_HUMANOID, math.clamp(size.Y * 0.08, 0.08, 0.3)
    end

    if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
        return TARGET_PROFILE_SPHERE, 0
    end

    return TARGET_PROFILE_BOX, 0
end

function Engine:_GetLateralTrust(profile, confidence, lateralAlpha, shockAlpha)
    local base
    local confGain
    local lateralGain
    local cap

    if profile == TARGET_PROFILE_MINI_HUMANOID then
        base = 0.24
        confGain = 0.28
        lateralGain = 0.24
        cap = 0.56
    elseif profile == TARGET_PROFILE_HUMANOID then
        base = 0.18
        confGain = 0.22
        lateralGain = 0.18
        cap = 0.42
    elseif profile == TARGET_PROFILE_SPHERE then
        base = 0.14
        confGain = 0.18
        lateralGain = 0.16
        cap = 0.36
    else
        base = 0.2
        confGain = 0.2
        lateralGain = 0.18
        cap = 0.4
    end

    return math.clamp((base + (confidence * confGain) + (lateralAlpha * lateralGain)) * (1 - shockAlpha * 0.35), 0.08, cap)
end

function Engine:_GetDistanceRatio(distance)
    local startDist = self.Prediction.DISTANCE_PREDICTION_START or 180
    local maxDist = self.Prediction.DISTANCE_PREDICTION_MAX or math.max(startDist + 1, 1800)
    if distance <= startDist then
        return 0
    end
    return math.clamp((distance - startDist) / math.max(maxDist - startDist, 1), 0, 1)
end

function Engine:_IsBeamLike(projectileSpeed)
    local beamFloor = self.Prediction.SMART_PROJECTILE_SPEED_MIN or 3400
    return projectileSpeed >= beamFloor
end

function Engine:_getTechniqueProfile(decision)
    local technique = decision and decision.Technique or "Linear"

    if technique == "Strafe" then
        return {
            TimeScale = 1.02,
            LateralScale = 1.22,
            AccelScale = 1.04,
            JerkScale = 0.92,
            VerticalScale = 0.95,
            TrustBias = 0.03,
        }
    end

    if technique == "Orbit" then
        return {
            TimeScale = 1.04,
            LateralScale = 1.34,
            AccelScale = 0.98,
            JerkScale = 0.82,
            VerticalScale = 0.92,
            TrustBias = 0.04,
        }
    end

    if technique == "Airborne" then
        return {
            TimeScale = 1.01,
            LateralScale = 0.9,
            AccelScale = 1.12,
            JerkScale = 0.88,
            VerticalScale = 1.26,
            TrustBias = 0.02,
        }
    end

    if technique == "Dash Recovery" then
        return {
            TimeScale = 0.82,
            LateralScale = 0.72,
            AccelScale = 0.42,
            JerkScale = 0.18,
            VerticalScale = 0.84,
            TrustBias = -0.12,
        }
    end

    return {
        TimeScale = 0.98,
        LateralScale = 0.86,
        AccelScale = 0.74,
        JerkScale = 0.52,
        VerticalScale = 0.94,
        TrustBias = 0.01,
    }
end

function Engine:Calculate(origin, targetPos, est, dt, entry, part, techniqueDecision)
    local Options = self.Options
    if not Options.PredictionEnabled then
        return targetPos
    end

    local velocity = est.Velocity or ZERO
    local accel = est.Acceleration or ZERO
    local jerk = est.Jerk or ZERO
    local confidence = math.clamp(est.Confidence or 0, 0, 1)
    local motionShock = est.MotionShock or 0
    local speed = velocity.Magnitude
    local technique = self:_getTechniqueProfile(techniqueDecision)
    local targetProfile, aimBiasY = self:_ResolveTargetProfile(entry, part)

    if aimBiasY ~= 0 then
        targetPos = targetPos + Vector3.new(0, aimBiasY, 0)
    end

    local toTarget = targetPos - origin
    local distance = toTarget.Magnitude
    if distance <= 0.001 then
        return targetPos
    end

    local projectileSpeed = Options.ProjectileVelocity or Options.ProjectileSpeed or DEFAULT_PROJECTILE_SPEED
    projectileSpeed = math.max(projectileSpeed, 1)
    local beamLike = self:_IsBeamLike(projectileSpeed)

    local travelTime = distance / projectileSpeed
    local latency = self:_GetLatency() * self:_GetPingMultiplier()
    local frameComp = math.min(math.max(est.TimeDelta or dt or 0, 0), 1 / 20) * 0.5
    local totalTime = (travelTime + latency + frameComp) * technique.TimeScale

    local shotDir = toTarget.Unit
    local forwardSpeed = velocity:Dot(shotDir)
    local lateralVelocity = velocity - (shotDir * forwardSpeed)
    local lateralSpeed = lateralVelocity.Magnitude

    local shockAlpha = math.clamp(motionShock / 180, 0, 1)
    local speedAlpha = math.clamp(speed / 140, 0, 1)
    local lateralAlpha = math.clamp(lateralSpeed / 110, 0, 1)
    local distanceRatio = self:_GetDistanceRatio(distance)
    local linearStability = math.clamp(1 - (accel.Magnitude / math.max(self.Prediction.BRAKE_ACCEL_THRESHOLD or 20, 1) * 0.06) - (shockAlpha * 0.35), 0, 1)
    local closeOrbitAlpha = 0
    local closeOrbitDistance = self.Prediction.CLOSE_ORBIT_DISTANCE or 135
    if distance <= closeOrbitDistance then
        local fullDistance = self.Prediction.CLOSE_ORBIT_FULL_ALPHA_DISTANCE or 42
        closeOrbitAlpha = math.clamp(1 - ((distance - fullDistance) / math.max(closeOrbitDistance - fullDistance, 1)), 0, 1)
    end

    if beamLike then
        totalTime = totalTime * math.clamp(self.Prediction.BEAM_TIME_BIAS or 0.92, 0.72, 1.1)
    end

    if distanceRatio > 0 then
        local distanceTimeGain = self.Prediction.DISTANCE_TIME_GAIN or 0.68
        local distanceBonus = distanceRatio * (0.01 + (distanceTimeGain * 0.035)) * (0.65 + (confidence * 0.35))
        totalTime = totalTime + distanceBonus
    end

    if linearStability >= (self.Prediction.LINEAR_MOTION_DOT_THRESHOLD or 0.91) then
        totalTime = totalTime + (self.Prediction.LINEAR_MOTION_TIME_BONUS or 0.02) * (0.55 + (distanceRatio * 0.45))
    end

    if lateralSpeed >= (self.Prediction.CLOSE_ORBIT_STRAFE_THRESHOLD or 14) and closeOrbitAlpha > 0 then
        totalTime = totalTime + (self.Prediction.CLOSE_ORBIT_LEAD_BONUS_TIME or 0.018) * closeOrbitAlpha
    end

    local predictedOffset = velocity * totalTime

    -- Strafing targets often miss because lateral movement needs slightly more
    -- aggressive lead than front/back motion under frame + ping delay.
    if lateralSpeed > 0.01 then
        local lateralTrust = self:_GetLateralTrust(targetProfile, confidence, lateralAlpha, shockAlpha) * technique.LateralScale
        local distanceStrafeGain = 1 + ((self.Prediction.DISTANCE_STRAFE_GAIN or 1.2) - 1) * distanceRatio * 0.35
        if beamLike then
            distanceStrafeGain = distanceStrafeGain * math.clamp(self.Prediction.BEAM_STRAFE_BIAS or 0.78, 0.5, 1.05)
        end
        if closeOrbitAlpha > 0 then
            distanceStrafeGain = distanceStrafeGain * (1 + (closeOrbitAlpha * 0.2))
        end
        predictedOffset = predictedOffset + (lateralVelocity * totalTime * lateralTrust)
        predictedOffset = predictedOffset + (lateralVelocity * totalTime * (distanceStrafeGain - 1) * (0.18 + (confidence * 0.12)))
    end

    if Options.SmartPrediction and (est.Stable or speed > 65) then
        local accelTrust = math.clamp(confidence * (1 - shockAlpha * 0.7), 0, 1)
        local jerkTrust = math.clamp(accelTrust * (1 - shockAlpha * 0.45), 0, 1)

        local profileBonus = targetProfile == TARGET_PROFILE_MINI_HUMANOID and 0.08 or (targetProfile == TARGET_PROFILE_BOX and 0.04 or 0)
        local accelWeight = math.clamp((1.08 - (totalTime * 0.3)) * (0.65 + (speedAlpha * 0.45) + (lateralAlpha * 0.2) + profileBonus), 0.24, 1.34) * accelTrust * technique.AccelScale
        local jerkWeight = math.clamp((0.58 - totalTime) * (0.45 + (speedAlpha * 0.35) + (lateralAlpha * 0.15) + (profileBonus * 0.5)), 0.05, 0.6) * jerkTrust * technique.JerkScale

        predictedOffset = predictedOffset + ((0.5 * accel * (totalTime ^ 2)) * accelWeight)
        predictedOffset = predictedOffset + (((1 / 6) * jerk * (totalTime ^ 3)) * jerkWeight)
    end

    if technique.VerticalScale ~= 1 then
        predictedOffset = Vector3.new(
            predictedOffset.X,
            predictedOffset.Y * technique.VerticalScale,
            predictedOffset.Z
        )
    end

    if forwardSpeed > 0.01 and accel.Magnitude > 0.01 then
        local accelDir = accel.Unit
        local brakeDot = accelDir:Dot(shotDir)
        if brakeDot <= (self.Prediction.REVERSE_RESPONSE_DOT or -0.05) then
            local brakeThreshold = self.Prediction.BRAKE_ACCEL_THRESHOLD or 20
            local brakeAlpha = math.clamp(accel.Magnitude / math.max(brakeThreshold, 1), 0, 1)
            local brakeCap = self.Prediction.ACCEL_CORRECTION_MAX_RATIO or 0.38
            local brakeReduction = math.clamp(brakeAlpha * (0.16 + (1 - confidence) * 0.08), 0.04, brakeCap)
            predictedOffset = predictedOffset - (shotDir * forwardSpeed * totalTime * brakeReduction)
        end
    end

    local leadCap = self.Prediction.MAX_LEAD_DIST or math.huge
    if self.Options.TargetPlayersToggle then
        leadCap = self.PvP.MAX_LEAD_DIST or leadCap
    end

    local maxOffset = math.max(
        18 + (speed * (0.14 + (confidence * 0.18))),
        distance * (0.22 + (speedAlpha * 0.18) + (lateralAlpha * 0.06))
    )
    if targetProfile == TARGET_PROFILE_MINI_HUMANOID then
        maxOffset = maxOffset * 1.08
    elseif targetProfile == TARGET_PROFILE_SPHERE then
        maxOffset = maxOffset * 0.96
    end
    maxOffset = math.min(maxOffset, leadCap)
    if predictedOffset.Magnitude > maxOffset then
        predictedOffset = predictedOffset.Unit * maxOffset
    end

    local predictedPos = targetPos + predictedOffset
    local trustFactor = math.clamp(
        (confidence * 0.75) + ((est.Stable and 0.15) or 0) + (speedAlpha * 0.12) + (lateralAlpha * 0.12) - (shockAlpha * 0.2) + technique.TrustBias,
        0.12,
        1
    )
    return targetPos:Lerp(predictedPos, trustFactor)
end

return Engine
]====],
    ["Modules/Combat/Prediction/Estimator.lua"] = [====[--[[
    Estimator.lua - State Estimation & Noise Removal (Physics Damping v2)
    Analogy: Inferior Colliculus (Auditory/Visual processing before perception).
    Job: Filtering raw velocity, detecting acceleration/jerk, and scoring confidence.
    Fixes: Jitter/Shakiness (rung) via progressive damping filters.
]]

local Estimator = {}
Estimator.__index = Estimator

local ZERO = Vector3.zero
local DEFAULT_DT = 1 / 60
local MIN_DT = 1 / 240
local MAX_DT = 0.25

function Estimator.new(kalman, config)
    local self = setmetatable({}, Estimator)
    self.Kalman = kalman
    self.Config = config
    self._prevVelocity = ZERO
    self._prevAcceleration = ZERO
    self._prevJerk = ZERO
    self._kalmanContext = {
        Confidence = 0.95,
        Shock = 0,
        IsTeleport = false,
    }
    self._result = {
        Velocity = ZERO,
        Acceleration = ZERO,
        Jerk = ZERO,
        Confidence = 1,
        Stable = true,
        MotionShock = 0,
        IsTeleport = false,
        RawVelocity = ZERO,
        PhysicsVelocity = ZERO,
        TimeDelta = DEFAULT_DT,
    }
    return self
end

function Estimator:Reset()
    self._prevVelocity = ZERO
    self._prevAcceleration = ZERO
    self._prevJerk = ZERO
    if self.Kalman then
        if self.Kalman.Reset then
            self.Kalman:Reset()
        else
            self.Kalman.Value = nil
            self.Kalman.P = 1
        end
    end
end

function Estimator:Estimate(raw, dt)
    local sampleDt = math.clamp((raw and raw.TimeDelta) or dt or DEFAULT_DT, MIN_DT, MAX_DT)
    local measurement = raw.Velocity or ZERO
    local sampleVelocity = raw.RawVelocity or measurement
    local physicsVelocity = raw.PhysicsVelocity or measurement

    local motionShock = (measurement - self._prevVelocity).Magnitude
    if raw.IsTeleport then
        motionShock = math.max(motionShock, 220)
    end

    local filteredVel = measurement
    if self.Kalman and self.Kalman.Update then
        local kalmanContext = self._kalmanContext
        kalmanContext.Confidence = raw.IsTeleport and 0.05 or 0.95
        kalmanContext.Shock = motionShock
        kalmanContext.IsTeleport = raw.IsTeleport
        filteredVel = self.Kalman:Update(measurement, sampleDt, kalmanContext)
    end

    if not raw.IsTeleport and physicsVelocity.Magnitude > 0.01 then
        local agreement = 1 - math.clamp((sampleVelocity - physicsVelocity).Magnitude / math.max(40, physicsVelocity.Magnitude * 0.8), 0, 1)
        local physicsBlend = math.clamp(0.18 + (agreement * 0.32), 0.08, 0.5)
        filteredVel = filteredVel:Lerp(physicsVelocity, physicsBlend)
    end

    local accel = ZERO
    local jerk = ZERO

    if raw.IsTeleport then
        filteredVel = physicsVelocity.Magnitude > 0.01 and physicsVelocity or filteredVel
    else
        local rawAccel = (filteredVel - self._prevVelocity) / sampleDt
        local accelResponse = math.clamp(sampleDt * (12 + math.min(motionShock / 12, 18)), 0.08, 0.95)
        accel = self._prevAcceleration:Lerp(rawAccel, accelResponse)

        local rawJerk = (accel - self._prevAcceleration) / sampleDt
        local jerkResponse = math.clamp(sampleDt * (8 + math.min(motionShock / 20, 12)), 0.05, 0.85)
        jerk = self._prevJerk:Lerp(rawJerk, jerkResponse)
    end

    local filterLag = (measurement - filteredVel).Magnitude
    local physicsDisagreement = 0
    if physicsVelocity.Magnitude > 0.01 and sampleVelocity.Magnitude > 0.01 then
        physicsDisagreement = (sampleVelocity - physicsVelocity).Magnitude
    end

    local score = 1.0
    if raw.IsTeleport then
        score = 0.05
    else
        score = score - math.clamp(filterLag / 160, 0, 0.32)
        score = score - math.clamp(accel.Magnitude / 260, 0, 0.28)
        score = score - math.clamp(jerk.Magnitude / 2200, 0, 0.18)
        score = score - math.clamp(motionShock / 200, 0, 0.22)
        score = score - math.clamp(physicsDisagreement / 220, 0, 0.12)
        score = math.clamp(score, 0.18, 1)
    end

    self._prevVelocity = filteredVel
    self._prevAcceleration = accel
    self._prevJerk = jerk

    local result = self._result
    result.Velocity = filteredVel
    result.Acceleration = accel
    result.Jerk = jerk
    result.Confidence = score
    result.Stable = score > 0.72 and motionShock < 110
    result.MotionShock = motionShock
    result.IsTeleport = raw.IsTeleport == true
    result.RawVelocity = measurement
    result.PhysicsVelocity = physicsVelocity
    result.TimeDelta = sampleDt
    return result
end

return Estimator

]====],
    ["Modules/Combat/Prediction/Sampler.lua"] = [====[--[[
    Sampler.lua - Pure Kinematic Data Extraction
    Analogy: The sensory nerves (Afferent fibers).
    Job: Extract raw position, velocity, and teleportation data without modification.
]]

local Sampler = {}
Sampler.__index = Sampler

local ZERO = Vector3.zero
local DEFAULT_DT = 1 / 60
local MIN_DT = 1 / 240
local MAX_DT = 0.25

function Sampler.new(config)
    local self = setmetatable({}, Sampler)
    local prediction = config and config.Prediction or nil
    self._teleportDistance = (prediction and prediction.TELEPORT_DETECTION_DISTANCE) or 22
    self._teleportRatio = (prediction and prediction.TELEPORT_DETECTION_SPEED_RATIO) or 0.55
    self._state = {
        Position = ZERO,
        Velocity = ZERO,
        RawVelocity = ZERO,
        PhysicsVelocity = ZERO,
        Displacement = ZERO,
        IsTeleport = false,
        Time = 0,
        TimeDelta = DEFAULT_DT,
    }
    return self
end

function Sampler:_ResolveVelocity(part, displacement, timeDelta)
    local physicsVelocity = part.AssemblyLinearVelocity or ZERO
    local sampledVelocity = ZERO

    if timeDelta > 0 then
        sampledVelocity = displacement / timeDelta
    end

    if physicsVelocity.Magnitude <= 0.01 then
        return sampledVelocity, sampledVelocity, physicsVelocity
    end

    if sampledVelocity.Magnitude <= 0.01 then
        return physicsVelocity, sampledVelocity, physicsVelocity
    end

    local disagreement = (sampledVelocity - physicsVelocity).Magnitude
    local blend = math.clamp(disagreement / math.max(24, sampledVelocity.Magnitude * 0.65), 0, 1)
    local resolvedVelocity = sampledVelocity:Lerp(physicsVelocity, 0.35 + (blend * 0.45))

    return resolvedVelocity, sampledVelocity, physicsVelocity
end

function Sampler:GetRawState(part, lastPos, lastTime, dt)
    local currentPos = part.Position
    local currentTime = os.clock()

    local displacement = lastPos and (currentPos - lastPos) or ZERO
    local timeDelta = dt or 0
    if lastTime then
        timeDelta = currentTime - lastTime
    end
    timeDelta = math.clamp((timeDelta and timeDelta > 0) and timeDelta or (dt or DEFAULT_DT), MIN_DT, MAX_DT)

    local velocity, sampledVelocity, physicsVelocity = self:_ResolveVelocity(part, displacement, timeDelta)

    local expectedTravel = velocity.Magnitude * timeDelta
    local teleportThreshold = math.max(self._teleportDistance, expectedTravel * (1 + self._teleportRatio) + 4)
    local isTeleport = lastPos ~= nil and displacement.Magnitude > teleportThreshold

    if isTeleport then
        velocity = physicsVelocity.Magnitude > 0.01 and physicsVelocity or ZERO
    end

    local state = self._state
    state.Position = currentPos
    state.Velocity = velocity
    state.RawVelocity = sampledVelocity
    state.PhysicsVelocity = physicsVelocity
    state.Displacement = displacement
    state.IsTeleport = isTeleport
    state.Time = currentTime
    state.TimeDelta = timeDelta
    return state
end

return Sampler

]====],
    ["Modules/Combat/Prediction/SilentResolver.lua"] = [====[--[[
    SilentResolver.lua - Silent Aim-Specific Aim Point Resolver
    Job: Convert raw prediction into a hitbox-safe aim point tuned for silent aim.
    Notes: Kept separate from aim-lock so packet aim can be sharper than visual aim.
]]

local SilentResolver = {}
SilentResolver.__index = SilentResolver

local function getEntryExtents(entry, part)
    local extents = part and part.Size or Vector3.new(2, 2, 2)
    local model = entry and entry.Model

    if model then
        local ok, modelExtents = pcall(model.GetExtentsSize, model)
        if ok and typeof(modelExtents) == "Vector3" then
            extents = Vector3.new(
                math.max(extents.X, modelExtents.X),
                math.max(extents.Y, modelExtents.Y),
                math.max(extents.Z, modelExtents.Z)
            )
        end
    end

    return extents
end

local function classifyAimProfile(entry, part, extents)
    if part and part:IsA("Part") and part.Shape == Enum.PartType.Ball then
        return "sphere"
    end

    if entry and entry.Humanoid then
        local isMini = math.min(extents.X, extents.Y, extents.Z) <= 2.4
            or extents.Y <= 4.3
            or (part and part.Size.Y <= 2.6)
            or entry.Humanoid.HipHeight <= 1.5

        return isMini and "mini_humanoid" or "humanoid"
    end

    return "box"
end

local function clampBoxOffset(offset, extents, innerScale)
    local half = extents * 0.5 * innerScale
    return Vector3.new(
        math.clamp(offset.X, -half.X, half.X),
        math.clamp(offset.Y, -half.Y, half.Y),
        math.clamp(offset.Z, -half.Z, half.Z)
    )
end

function SilentResolver.new(config)
    local self = setmetatable({}, SilentResolver)
    self.Options = config and config.Options or {}
    self.Prediction = config and config.Prediction or {}
    return self
end

function SilentResolver:Resolve(targetPart, targetPos, currentEntry)
    if not targetPart or not targetPos then
        return targetPos
    end

    local extents = getEntryExtents(currentEntry, targetPart)
    local minAxis = math.min(extents.X, extents.Y, extents.Z)
    local maxAxis = math.max(extents.X, extents.Y, extents.Z)
    local profile = classifyAimProfile(currentEntry, targetPart, extents)

    local center = targetPart.Position
    if profile == "mini_humanoid" then
        center = center + Vector3.new(0, math.clamp(extents.Y * 0.12, 0.16, 0.4), 0)
    elseif profile == "humanoid" then
        center = center + Vector3.new(0, math.clamp(extents.Y * 0.05, 0.08, 0.22), 0)
    end

    local rawOffset = targetPos - center
    if rawOffset.Magnitude <= 0.001 then
        return center
    end

    local tinyAlpha = math.clamp((2.8 - minAxis) / 1.8, 0, 1)
    local narrowAlpha = math.clamp((4.2 - maxAxis) / 2.6, 0, 1)
    local centerBias = math.max(tinyAlpha, narrowAlpha * 0.75)
    local innerScale = 0.42

    if profile == "mini_humanoid" then
        innerScale = 0.28
        centerBias = math.max(centerBias, 0.55)
    elseif profile == "humanoid" then
        innerScale = 0.34
        centerBias = math.max(centerBias, 0.2)
    elseif profile == "sphere" then
        innerScale = 0.4
    end

    local clampedOffset
    if profile == "sphere" then
        local radius = math.max(minAxis * 0.5 * innerScale, 0.2)
        clampedOffset = rawOffset.Magnitude > radius and (rawOffset.Unit * radius) or rawOffset
    else
        clampedOffset = clampBoxOffset(rawOffset, extents, innerScale)
    end

    local clampedPos = center + clampedOffset
    if centerBias > 0 then
        clampedPos = clampedPos:Lerp(center, math.clamp(centerBias * 0.45, 0, 0.4))
    end

    return clampedPos
end

return SilentResolver
]====],
    ["Modules/Combat/Prediction/Stabilizer.lua"] = [====[--[[
    Stabilizer.lua - Vision & Presentation Smoothing
    Analogy: The vestibulo-ocular reflex (Vision stabilization).
    Job: Resolve micro-jitters without modifying core prediction state.
]]

local Stabilizer = {}
Stabilizer.__index = Stabilizer

local DEFAULT_DT = 1 / 60
local ZERO = Vector3.zero

function Stabilizer.new()
    local self = setmetatable({}, Stabilizer)
    self.BaseSmoothing = 2.45
    self.CatchupSmoothing = 6.8
    self.SnapDistance = 4.25
    self._lastTarget = ZERO
    return self
end

function Stabilizer:Reset(targetPos)
    self._lastTarget = targetPos or ZERO
end

function Stabilizer:Smooth(targetPos, dt)
    local lastTarget = self._lastTarget
    if lastTarget == ZERO then
        self._lastTarget = targetPos
        return targetPos
    end

    local delta = targetPos - lastTarget
    local deltaMagnitude = delta.Magnitude
    if deltaMagnitude >= self.SnapDistance then
        self._lastTarget = targetPos
        return targetPos
    end

    local catchupAlpha = math.clamp((deltaMagnitude - 0.45) / 6.25, 0, 1)
    local smoothing = self.BaseSmoothing + ((self.CatchupSmoothing - self.BaseSmoothing) * catchupAlpha)
    local alpha = 1 - math.exp(-smoothing * math.max((dt or DEFAULT_DT) * 60, 1))
    local result = lastTarget:Lerp(targetPos, alpha)

    self._lastTarget = result
    return result
end

return Stabilizer
]====],
    ["Modules/Combat/Prediction/TechniqueSelector.lua"] = [====[local TechniqueSelector = {}
TechniqueSelector.__index = TechniqueSelector

local ZERO = Vector3.zero

local TECHNIQUE_LINEAR = "Linear"
local TECHNIQUE_STRAFE = "Strafe"
local TECHNIQUE_ORBIT = "Orbit"
local TECHNIQUE_AIRBORNE = "Airborne"
local TECHNIQUE_DASH = "Dash Recovery"

function TechniqueSelector.new(config)
    local self = setmetatable({}, TechniqueSelector)
    self.Options = config.Options
    self.Prediction = config.Prediction or {}
    self._states = setmetatable({}, { __mode = "k" })
    self._holdTime = 0.12
    self._stickMargin = 0.04
    return self
end

function TechniqueSelector:Prune(expiry, now)
    local pruneBefore = (now or os.clock()) - (expiry or 15)
    for entry, state in pairs(self._states) do
        if not entry
            or not entry.Model
            or not entry.Model.Parent
            or ((entry.LastSeen or 0) > 0 and (entry.LastSeen or 0) < pruneBefore) then
            self._states[entry] = nil
        elseif state and state.LastSwitch > 0 and state.LastSwitch < (pruneBefore - 8) then
            self._states[entry] = nil
        end
    end
end

function TechniqueSelector:Destroy()
    table.clear(self._states)
end

function TechniqueSelector:_getState(entry)
    if not entry then
        return nil
    end

    local state = self._states[entry]
    if state then
        return state
    end

    state = {
        Technique = nil,
        LastSwitch = 0,
        LastReason = nil,
    }
    self._states[entry] = state
    return state
end

function TechniqueSelector:_makeDecision(technique, reason, score, confidence)
    return {
        Technique = technique,
        Reason = reason,
        Score = score or 0,
        Confidence = confidence or 0,
    }
end

function TechniqueSelector:_getMode()
    local mode = tostring(self.Options.PredictionTechniqueMode or "Assisted")
    if mode == "Manual" then
        return "Manual"
    end
    return "Assisted"
end

function TechniqueSelector:_getManualTechnique()
    local technique = tostring(self.Options.PredictionTechnique or TECHNIQUE_LINEAR)
    if technique == TECHNIQUE_STRAFE
        or technique == TECHNIQUE_ORBIT
        or technique == TECHNIQUE_AIRBORNE
        or technique == TECHNIQUE_DASH then
        return technique
    end
    return TECHNIQUE_LINEAR
end

function TechniqueSelector:_collectMetrics(origin, targetPos, est)
    local velocity = est.Velocity or ZERO
    local accel = est.Acceleration or ZERO
    local jerk = est.Jerk or ZERO
    local confidence = math.clamp(est.Confidence or 0, 0, 1)
    local shockAlpha = math.clamp((est.MotionShock or 0) / 180, 0, 1)
    local toTarget = targetPos - origin
    local distance = toTarget.Magnitude
    local shotDir = distance > 0.001 and toTarget.Unit or Vector3.new(0, 0, 1)

    local forwardSpeed = velocity:Dot(shotDir)
    local lateralVelocity = velocity - (shotDir * forwardSpeed)
    local lateralSpeed = lateralVelocity.Magnitude
    local verticalSpeed = math.abs(velocity.Y)
    local verticalAccel = math.abs(accel.Y)
    local speed = velocity.Magnitude
    local distanceRatio = 0

    local startDist = self.Prediction.DISTANCE_PREDICTION_START or 180
    local maxDist = self.Prediction.DISTANCE_PREDICTION_MAX or math.max(startDist + 1, 1800)
    if distance > startDist then
        distanceRatio = math.clamp((distance - startDist) / math.max(maxDist - startDist, 1), 0, 1)
    end

    local orbitDistance = self.Prediction.CLOSE_ORBIT_DISTANCE or 135
    local orbitRatio = 0
    if distance <= orbitDistance * 1.2 then
        orbitRatio = math.clamp(1 - (distance / math.max(orbitDistance * 1.2, 1)), 0, 1)
    end

    return {
        Confidence = confidence,
        ShockAlpha = shockAlpha,
        Speed = speed,
        ForwardSpeed = forwardSpeed,
        LateralSpeed = lateralSpeed,
        VerticalSpeed = verticalSpeed,
        VerticalAccel = verticalAccel,
        Distance = distance,
        DistanceRatio = distanceRatio,
        OrbitRatio = orbitRatio,
        IsTeleport = est.IsTeleport == true,
        AccelMagnitude = accel.Magnitude,
        JerkMagnitude = jerk.Magnitude,
    }
end

function TechniqueSelector:_scoreLinear(metrics)
    local score = 0.38
        + (metrics.Confidence * 0.34)
        + ((1 - metrics.ShockAlpha) * 0.18)
        + ((1 - math.clamp(metrics.LateralSpeed / 120, 0, 1)) * 0.12)
    return score, "stable forward motion"
end

function TechniqueSelector:_scoreStrafe(metrics)
    local lateralAlpha = math.clamp(metrics.LateralSpeed / 110, 0, 1)
    local score = 0.18
        + (lateralAlpha * 0.46)
        + (metrics.Confidence * 0.16)
        + ((1 - metrics.ShockAlpha) * 0.08)
        + (metrics.DistanceRatio * 0.06)
    return score, "high lateral movement"
end

function TechniqueSelector:_scoreOrbit(metrics)
    local orbitiness = math.clamp(metrics.LateralSpeed / math.max(metrics.Speed, 1), 0, 1)
    local lowForward = 1 - math.clamp(math.abs(metrics.ForwardSpeed) / math.max(metrics.Speed, 1), 0, 1)
    local score = 0.12
        + (metrics.OrbitRatio * 0.28)
        + (orbitiness * 0.26)
        + (lowForward * 0.16)
        + (metrics.Confidence * 0.12)
    return score, "close circular strafe"
end

function TechniqueSelector:_scoreAirborne(metrics, entry)
    local airborneAlpha = math.clamp(metrics.VerticalSpeed / 50, 0, 1)
    local accelAlpha = math.clamp(metrics.VerticalAccel / 120, 0, 1)
    local score = 0.14
        + (airborneAlpha * 0.42)
        + (accelAlpha * 0.16)
        + (metrics.Confidence * 0.14)

    if entry and entry.PrimaryPart and math.abs(entry.PrimaryPart.AssemblyLinearVelocity.Y) > 6 then
        score = score + 0.08
    end

    return score, "strong vertical motion"
end

function TechniqueSelector:_scoreDash(metrics)
    local score = 0.08
        + (metrics.ShockAlpha * 0.44)
        + (math.clamp(metrics.AccelMagnitude / 260, 0, 1) * 0.14)
        + (math.clamp(metrics.JerkMagnitude / 2200, 0, 1) * 0.14)

    if metrics.IsTeleport then
        score = score + 0.22
    end

    return score, metrics.IsTeleport and "teleport / blink shock" or "dash or hard direction break"
end

function TechniqueSelector:_pickAssisted(entry, metrics)
    local scores = {}

    local linearScore, linearReason = self:_scoreLinear(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_LINEAR, linearReason, linearScore, metrics.Confidence)

    local strafeScore, strafeReason = self:_scoreStrafe(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_STRAFE, strafeReason, strafeScore, metrics.Confidence)

    local orbitScore, orbitReason = self:_scoreOrbit(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_ORBIT, orbitReason, orbitScore, metrics.Confidence)

    local airborneScore, airborneReason = self:_scoreAirborne(metrics, entry)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_AIRBORNE, airborneReason, airborneScore, metrics.Confidence)

    local dashScore, dashReason = self:_scoreDash(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_DASH, dashReason, dashScore, metrics.Confidence)

    local best = scores[1]
    local byTechnique = {}
    for i = 1, #scores do
        local decision = scores[i]
        byTechnique[decision.Technique] = decision
        if decision.Score > best.Score then
            best = decision
        end
    end

    local state = self:_getState(entry)
    local now = os.clock()
    if state and state.Technique then
        local current = byTechnique[state.Technique]
        if current then
            local withinHold = (now - state.LastSwitch) < self._holdTime
            local closeEnough = current.Score >= (best.Score - self._stickMargin)
            if withinHold or closeEnough then
                current.Reason = withinHold and ("holding " .. string.lower(state.Technique)) or current.Reason
                best = current
            end
        end
    end

    if state then
        if state.Technique ~= best.Technique then
            state.Technique = best.Technique
            state.LastSwitch = now
        end
        state.LastReason = best.Reason
    end

    return best
end

function TechniqueSelector:Decide(origin, targetPos, est, entry)
    if not entry or not targetPos then
        return self:_makeDecision(TECHNIQUE_LINEAR, "no target", 0, 0)
    end

    if self:_getMode() == "Manual" then
        return self:_makeDecision(self:_getManualTechnique(), "manual override", 1, math.clamp(est.Confidence or 0, 0, 1))
    end

    local metrics = self:_collectMetrics(origin, targetPos, est)
    return self:_pickAssisted(entry, metrics)
end

return TechniqueSelector
]====],
    ["Modules/Combat/Predictor.lua"] = [====[--[[
    Predictor.lua - High-Performance Layered Orchestrator
    Analogy: The Neural Motor Network.
    Job: Orchestrates the 4 layers: Sampler -> Estimator -> Engine -> Stabilizer.
    Architecture: Orthogonal-First design (Zero feedback loop).
]]

local Predictor = {}
Predictor.__index = Predictor

function Predictor.new(config, loader, kalman)
    local self = setmetatable({}, Predictor)
    self.Config = config
    self.Options = config.Options
    
    -- Load Layer Modules
    local Path = "Modules/Combat/Prediction/"
    local Sampler    = loader(Path.."Sampler.lua")
    local Estimator  = loader(Path.."Estimator.lua")
    local Engine     = loader(Path.."Engine.lua")
    local Stabilizer = loader(Path.."Stabilizer.lua")
    local TechniqueSelector = loader(Path.."TechniqueSelector.lua")
    
    -- Instantiate shared stateless layers
    self.Sampler = Sampler.new(config)
    self.Engine = Engine.new(config)
    self.TechniqueSelector = TechniqueSelector.new(config)

    -- Keep stateful layers isolated per target so target switching does not
    -- bleed velocity smoothing or screen stabilization across different entries.
    self._EstimatorClass = Estimator
    self._StabilizerClass = Stabilizer
    self._KalmanFactory = kalman and kalman.new or nil
    self._EntryStates = setmetatable({}, { __mode = "k" })
    self._lastPrune = 0
    self._pruneInterval = 5
    self._stateExpiry = 15
    return self
end

function Predictor:_PruneStates(now)
    local pruneBefore = now - self._stateExpiry
    for entry, state in pairs(self._EntryStates) do
        if not entry
            or not entry.Model
            or not entry.Model.Parent
            or ((entry.LastSeen or 0) > 0 and (entry.LastSeen or 0) < pruneBefore) then
            if state and state.Estimator and state.Estimator.Reset then
                state.Estimator:Reset()
            end
            self._EntryStates[entry] = nil
        end
    end

    if self.TechniqueSelector and self.TechniqueSelector.Prune then
        self.TechniqueSelector:Prune(self._stateExpiry, now)
    end
end

function Predictor:Prune(now)
    self:_PruneStates(now or os.clock())
end

function Predictor:_GetState(entry)
    local state = self._EntryStates[entry]
    if state then
        return state
    end

    local kalman = self._KalmanFactory and self._KalmanFactory(self.Config) or nil
    state = {
        Estimator = self._EstimatorClass.new(kalman, self.Config),
        Stabilizer = self._StabilizerClass.new(),
    }
    self._EntryStates[entry] = state
    return state
end

function Predictor:NotifyTargetChanged(entry, part)
    if not entry then
        return
    end

    local state = self:_GetState(entry)
    if state.Estimator and state.Estimator.Reset then
        state.Estimator:Reset()
    end
    if state.Stabilizer and state.Stabilizer.Reset then
        state.Stabilizer:Reset(part and part.Position or nil)
    end
end

function Predictor:Predict(origin, part, entry, dt)
    if not part then
        return nil, nil
    end

    -- GUARD: Ensure entry exists
    if not entry then return part.Position end

    local now = os.clock()
    if (now - self._lastPrune) >= self._pruneInterval then
        self._lastPrune = now
        self:_PruneStates(now)
    end

    local state = self:_GetState(entry)
    
    -- 1. SAMPLING (Input Only)
    local raw = self.Sampler:GetRawState(part, entry.LastPos, entry.LastTime, dt)
    
    -- 2. ESTIMATION (Cleaning State)
    local est = state.Estimator:Estimate(raw, dt)
    
    -- Update entry metadata (Monitoring only, No logic)
    entry.LastPos = raw.Position
    entry.LastTime = raw.Time
    
    -- 3. TECHNIQUE SELECTION
    local techniqueDecision = self.TechniqueSelector:Decide(origin, raw.Position, est, entry)

    -- 4. PREDICTION (Exactly one strategy profile)
    local predicted = self.Engine:Calculate(origin, raw.Position, est, dt, entry, part, techniqueDecision)
    
    -- 5. PRESENTATION (Smoothing)
    return state.Stabilizer:Smooth(predicted, dt), predicted, techniqueDecision
end

function Predictor:Destroy()
    if self.TechniqueSelector and self.TechniqueSelector.Destroy then
        self.TechniqueSelector:Destroy()
    end

    for entry, state in pairs(self._EntryStates) do
        if state and state.Estimator and state.Estimator.Reset then
            state.Estimator:Reset()
        end
        self._EntryStates[entry] = nil
    end
end

return Predictor

]====],
    ["Modules/Combat/SilentAim.lua"] = [====[--[[
    SilentAim.lua - High-Performance Neural Combat Hook
    Job: Safely redirect combat packets without interfering with user intent.
    Notes: Uses a singleton hook state to avoid stacking metamethod hooks on reload.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SilentAim = {}
SilentAim.__index = SilentAim

local GLOBAL_HOOK_KEY = "__STAR_GLITCHER_SILENT_AIM_HOOK"
local REDIRECT_WINDOW = 0.35
local clock = os.clock

local REMOTE_BLACKLIST = {
    "sprint", "speed", "walk", "jump", "action", "interact", "dialogue", "inventory", "tab",
    "shop", "trade", "quest", "mission", "chat", "menu", "equip", "unequip"
}

local function isCombatRemote(remote)
    local mName = tostring(remote):lower()
    for _, word in ipairs(REMOTE_BLACKLIST) do
        if mName:find(word) then return false end
    end
    return mName:find("shoot")
        or mName:find("fire")
        or mName:find("attack")
        or mName:find("hit")
        or mName:find("damage")
        or mName:find("impact")
end

local function isSpatialArg(value)
    local valueType = typeof(value)
    if valueType == "Vector3" or valueType == "CFrame" or valueType == "Ray" then
        return true
    end

    return valueType == "Instance" and (value:IsA("BasePart") or value:IsA("Model"))
end

local function hasSpatialPayload(args)
    for i = 1, args.n do
        if isSpatialArg(args[i]) then
            return true
        end
    end
    return false
end

local function isBossAggressiveRemote(selfRef, remote, args)
    local entry = selfRef and selfRef.CurrentTargetEntry
    if not (entry and entry.IsBoss) then
        return false
    end

    local remoteName = tostring(remote):lower()
    for _, word in ipairs(REMOTE_BLACKLIST) do
        if remoteName:find(word, 1, true) then
            return false
        end
    end

    return hasSpatialPayload(args)
end

local function buildTargetCFrame(targetPos)
    local camPos = Workspace.CurrentCamera.CFrame.Position
    return CFrame.lookAt(camPos, targetPos)
end

local function buildTargetRay(origin, targetPos, length)
    local direction = targetPos - origin
    if direction.Magnitude <= 0.001 then
        direction = Workspace.CurrentCamera.CFrame.LookVector
    else
        direction = direction.Unit * (length or (targetPos - origin).Magnitude)
    end
    return Ray.new(origin, direction)
end

local function ensureHookState()
    local hookState = getgenv()[GLOBAL_HOOK_KEY]
    if hookState then
        return hookState
    end

    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    hookState = {
        Instance = nil,
    }

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        local selfRef = hookState.Instance
        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef:_hasTargetLock()
            and selfRef:_isRedirectActive() then -- FIX: Only redirect mouse during firing window
            if inst == Mouse or (typeof(inst) == "Instance" and inst:IsA("Mouse")) then
                if index == "Hit" then
                    return buildTargetCFrame(selfRef.TargetPosCache)
                elseif index == "Target" then
                    return selfRef.TargetPartCache
                elseif index == "UnitRay" then
                    local camPos = Workspace.CurrentCamera.CFrame.Position
                    return buildTargetRay(camPos, selfRef.TargetPosCache, 1)
                end
            end
        end

        return oldIndex(inst, index)
    end))

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local selfRef = hookState.Instance
        local method = getnamecallmethod()
        local args = table.pack(...)

        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef:_hasTargetLock() then
            if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and inst == Workspace.CurrentCamera then
                local camPos = Workspace.CurrentCamera.CFrame.Position
                return buildTargetRay(camPos, selfRef.TargetPosCache, 1)
            end

            if selfRef:_isRedirectActive() then
                if (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and inst == Workspace then
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        args[1] = buildTargetRay(ray.Origin, selfRef.TargetPosCache, ray.Direction.Magnitude)
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end

                if (method == "FireServer" or method == "InvokeServer")
                    and (isCombatRemote(inst) or isBossAggressiveRemote(selfRef, inst, args)) then
                    local modified = false
                    local maxRewrites = (selfRef.CurrentTargetEntry and selfRef.CurrentTargetEntry.IsBoss) and 3 or 1
                    local rewrites = 0

                    for i = 1, args.n do
                        if rewrites >= maxRewrites then
                            break
                        end

                        local arg = args[i]
                        if typeof(arg) == "Vector3" then
                            args[i] = selfRef.TargetPosCache
                            modified = true
                            rewrites = rewrites + 1
                        elseif typeof(arg) == "Instance" and (arg:IsA("BasePart") or arg:IsA("Model")) then
                            local localCharacter = LocalPlayer.Character
                            if not (localCharacter and arg:IsDescendantOf(localCharacter)) then
                                args[i] = selfRef.TargetPartCache
                                modified = true
                                rewrites = rewrites + 1
                            end
                        elseif typeof(arg) == "CFrame" then
                            args[i] = buildTargetCFrame(selfRef.TargetPosCache)
                            modified = true
                            rewrites = rewrites + 1
                        elseif typeof(arg) == "Ray" then
                            args[i] = buildTargetRay(arg.Origin, selfRef.TargetPosCache, arg.Direction.Magnitude)
                            modified = true
                            rewrites = rewrites + 1
                        end
                    end

                    if modified then
                        selfRef._lastRedirectTime = clock()
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function SilentAim.new(config, synapse, resolver)
    local self = setmetatable({}, SilentAim)
    self.Options = config.Options
    self.Synapse = synapse
    self.Resolver = resolver

    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self._lastClickTime = 0
    self._lastRedirectTime = 0
    self._connections = {}
    self._destroyed = false
    self._hookState = nil
    return self
end

function SilentAim:_hasTargetLock()
    return self.Active and self.TargetPosCache ~= nil and self.TargetPartCache ~= nil
end

function SilentAim:_isRedirectActive()
    if not self:_hasTargetLock() then
        return false
    end

    local now = clock()
    return (now - self._lastClickTime) <= REDIRECT_WINDOW
        or (now - self._lastRedirectTime) <= REDIRECT_WINDOW
end

function SilentAim:Init()
    if not hookmetamethod then
        return
    end

    self._destroyed = false
    self._hookState = ensureHookState()
    self._hookState.Instance = self

    local selfRef = self
    local LocalPlayer = Players.LocalPlayer
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local now = clock()
            selfRef._lastClickTime = now
            if selfRef.Active and selfRef.CurrentTargetEntry then
                local char = LocalPlayer.Character
                local muzzlePos = (char and char:GetPivot().Position) or Vector3.zero
                selfRef.Synapse.fire("ShotFired", selfRef.CurrentTargetEntry.Model, now, muzzlePos)
            end
        end
    end))
end

function SilentAim:SetState(active, targetPart, targetPos, currentEntry, dt)
    self.Active = active
    self.TargetPartCache = targetPart
    self.TargetPosCache = active and self.Resolver and self.Resolver.Resolve and self.Resolver:Resolve(targetPart, targetPos, currentEntry) or targetPos
    self.CurrentTargetEntry = currentEntry
end

function SilentAim:Clear()
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self._lastClickTime = 0
    self._lastRedirectTime = 0
end

function SilentAim:Destroy()
    self._destroyed = true
    self:Clear()

    if self._hookState and self._hookState.Instance == self then
        self._hookState.Instance = nil
    end

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return SilentAim
]====],
    ["Modules/Combat/TargetSelector.lua"] = [====[--[[
    TargetSelector.lua - OOP Target Selection Class
    Logic for finding the most optimal target based on distance and FOV.
    Optimized for crosshair proximity with lightweight sticky targeting.
]]

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")

local TargetSelector = {}
TargetSelector.__index = TargetSelector

function TargetSelector.new(config, tracker, predictor)
    local self = setmetatable({}, TargetSelector)
    self.Options = config.Options
    self.Tracker = tracker
    self.Predictor = predictor
    self._stickyBias = 1.12
    self._destroyed = false
    return self
end

function TargetSelector:Init()
    self._destroyed = false
end

function TargetSelector:_getMethod()
    local method = tostring(self.Options.TargetingMethod or "FOV")
    if method == "Distance" or method == "Deadlock" then
        return method
    end
    return "FOV"
end

function TargetSelector:_isEntryValid(entry, localCharacter, originPos, maxDistance)
    if not entry or not entry.Model or entry.Model == localCharacter then
        return nil, nil, nil
    end

    local part = self.Tracker:GetTargetPart(entry)
    if not part or (localCharacter and part:IsDescendantOf(localCharacter)) then
        return nil, nil, nil
    end

    local toTarget = part.Position - originPos
    local distance = toTarget.Magnitude
    if distance > maxDistance then
        return nil, nil, nil
    end

    return part, distance, toTarget
end

function TargetSelector:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
    local part, distance = self:_isEntryValid(entry, localCharacter, originPos, maxDistance)
    if not part then
        return nil, nil
    end

    if method == "Distance" then
        return distance, part
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return nil, nil
    end

    local dx = screenPos.X - mouseX
    local dy = screenPos.Y - mouseY
    return (dx * dx) + (dy * dy), part
end

function TargetSelector:GetClosestTarget(mousePos, originPos, preferredEntry)
    if self._destroyed then
        return nil
    end

    local bestTarget = nil
    local localCharacter = Players.LocalPlayer.Character
    local mouseX = mousePos.X
    local mouseY = mousePos.Y
    local maxDistance = self.Options.MaxDistance or 2500
    local method = self:_getMethod()
    local fov = self.Options.FOV or 150
    local bestScore = method == "Distance" and maxDistance or (fov * fov)

    if method == "Deadlock" and preferredEntry then
        local lockedPart = self:_isEntryValid(preferredEntry, localCharacter, originPos, maxDistance)
        if lockedPart then
            return preferredEntry
        end
    end

    -- Keep the current target when it is still meaningfully valid to avoid
    -- rescoring churn and target thrash in crowded scenes.
    if preferredEntry then
        local preferredScore = self:_scoreEntry(preferredEntry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
        if preferredScore and preferredScore <= (bestScore * self._stickyBias) then
            bestTarget = preferredEntry
            bestScore = preferredScore
        end
    end

    local entries = self.Tracker:GetTargets()
    for i = 1, #entries do
        local entry = entries[i]
        if entry ~= preferredEntry then
            local score = self:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
            if score and score < bestScore then
                bestScore = score
                bestTarget = entry
            end
        end
    end

    return bestTarget
end

function TargetSelector:Destroy()
    self._destroyed = true
end

return TargetSelector
]====],
    ["Modules/Core/Bootstrap/Normalize.lua"] = [====[--[[
    Normalize.lua - Bootstrap option normalization helpers
    Job: Keep startup normalization logic out of Core/Main.lua.
]]

local Normalize = {}

function Normalize.ToggleUIKeyCode(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value
    end

    if type(value) == "string" then
        local keyCode = Enum.KeyCode[value]
        if keyCode then
            return keyCode
        end
    end

    return Enum.KeyCode.RightControl
end

function Normalize.ToggleUIKey(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value.Name
    end

    if type(value) == "string" and Enum.KeyCode[value] then
        return value
    end

    return "RightControl"
end

function Normalize.TargetingMethod(value)
    if type(value) ~= "string" then
        return "FOV"
    end

    local normalized = string.lower(value)
    if normalized == "fov" then
        return "FOV"
    end
    if normalized == "distance" then
        return "Distance"
    end
    if normalized == "deadlock" then
        return "Deadlock"
    end

    return "FOV"
end

return Normalize
]====],
    ["Modules/Core/Bootstrap/RayfieldUI.lua"] = [====[--[[
    RayfieldUI.lua - Bootstrap UI helper for Rayfield startup
    Job: Create the main window, discover Rayfield ScreenGuis, and load config safely.
]]

local Players = game:GetService("Players")

local RayfieldUI = {}

function RayfieldUI.CreateWindow(rayfield)
    return rayfield:CreateWindow({
        Name = "STAR GLITCHER ~ REVITALIZED",
        LoadingTitle = "Neural Interface Initializing...",
        LoadingSubtitle = "Scientific Neural Network Active",
        ConfigurationSaving = { Enabled = true, FolderName = "Boss_AimAssist", FileName = "Config" },
        Discord = { Enabled = false },
        KeySystem = false,
    })
end

function RayfieldUI.IsRayfieldScreenGui(screenGui)
    if not screenGui or not screenGui:IsA("ScreenGui") then
        return false
    end

    local guiName = string.lower(screenGui.Name)
    if guiName:find("rayfield", 1, true) or guiName:find("sirius", 1, true) then
        return true
    end

    for _, descendant in ipairs(screenGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local text = descendant.Text
            if text == "STAR GLITCHER ~ REVITALIZED" or text == "Neural Interface Initializing..." then
                return true
            end
        end
    end

    return false
end

function RayfieldUI.GetScreenGuis(coreGui)
    local matches = {}
    local seen = {}
    local containers = { coreGui }

    local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(containers, playerGui)
    end

    for _, container in ipairs(containers) do
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("ScreenGui") and not seen[descendant] and RayfieldUI.IsRayfieldScreenGui(descendant) then
                seen[descendant] = true
                matches[#matches + 1] = descendant
            end
        end
    end

    return matches
end

function RayfieldUI.SafeLoadConfiguration(rayfield)
    local ok, err = pcall(function()
        if rayfield and rayfield.LoadConfiguration then
            rayfield:LoadConfiguration()
        end
    end)

    return ok, err
end

return RayfieldUI
]====],
    ["Modules/Core/Brain.lua"] = [====[--[[
    Brain.lua - Central Nervous System (Orchestrator)
    Analogy: The Spinal Cord/CNS connecting all Brain Lobes.
    Job: Coordinates input, thought, and motor execution.
]]

local BrainFolder = "Modules/Core/Brain/"
local clock = os.clock

local Brain = {}
Brain.__index = Brain

function Brain.new(config, modules, loader)
    local self = setmetatable({}, Brain)
    self.Options = config.Options
    self.Config = config

    local Parietal = loader(BrainFolder .. "Parietal.lua")
    local Temporal = loader(BrainFolder .. "Temporal.lua")
    local Occipital = loader(BrainFolder .. "Occipital.lua")
    local Frontal = loader(BrainFolder .. "Frontal.lua")

    self.Parietal = Parietal.new(modules.Input, modules.Tracker)
    self.Temporal = Temporal.new(modules.Selector, modules.Predictor)
    self.Occipital = Occipital.new(modules.Visuals)
    self.Frontal = Frontal.new(modules.Aimbot, modules.SilentAim, self.Options)

    self._lastScan = 0
    self._scanInterval = 1 / 120
    self._scanAccumulator = 0
    self._frameDtEma = 1 / 60
    return self
end

function Brain:_isDeadlockMode()
    return tostring(self.Options.TargetingMethod or "FOV") == "Deadlock"
end

function Brain:_getScanInterval()
    local maxHz = math.clamp(tonumber(self.Options.TargetScanHz) or 120, 30, 240)
    return 1 / maxHz
end

function Brain:Scan(mousePos, originPos, dt)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local deadlockMode = self:_isDeadlockMode()
    if not shouldAssist then
        if deadlockMode and self.Options.AssistMode ~= "Off" then
            return
        end
        self.Parietal.Tracker.CurrentTargetEntry = nil
        self._scanAccumulator = 0
        return
    end

    local scanInterval = self:_getScanInterval()
    self._scanInterval = scanInterval

    if self.Options.AdaptiveTargetScan == false then
        local now = clock()
        if (now - self._lastScan) < scanInterval then
            return
        end
        self._lastScan = now
    else
        local step = math.max(tonumber(dt) or self._frameDtEma or (1 / 60), 1 / 240)
        self._frameDtEma = self._frameDtEma + ((step - self._frameDtEma) * 0.18)
        self._scanAccumulator = self._scanAccumulator + step
        if self._scanAccumulator < scanInterval then
            return
        end

        self._scanAccumulator = math.max(0, self._scanAccumulator - scanInterval)
        if self._scanAccumulator > (scanInterval * 1.5) then
            self._scanAccumulator = scanInterval
        end

        self._lastScan = clock()
    end

    local target = self.Temporal:Scan(mousePos, originPos)
    self.Parietal.Tracker.CurrentTargetEntry = target
end

function Brain:Update(dt, mousePos, camCFrame)
    self.Occipital:UpdateFOV(mousePos)

    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local entry = self.Parietal.Tracker.CurrentTargetEntry
    local maintainDeadlock = self:_isDeadlockMode() and self.Options.AssistMode ~= "Off" and entry ~= nil
    local shouldTrack = shouldAssist or maintainDeadlock

    if not shouldTrack or not entry then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local targetPart, targetPos, rawTargetPos, techniqueDecision = self.Temporal:Process(camCFrame.Position, dt)

    if not targetPart or not targetPos then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local sPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    self.Occipital:Process(mousePos, sPos, targetPart, onScreen, techniqueDecision, entry)
    self.Frontal:Execute(targetPos, targetPart, entry, dt, rawTargetPos)
end

function Brain:Destroy()
    local lobes = {
        self.Parietal,
        self.Temporal,
        self.Occipital,
        self.Frontal,
    }

    for _, lobe in ipairs(lobes) do
        if lobe and lobe.Destroy then
            pcall(function()
                lobe:Destroy()
            end)
        end
    end

    self.Parietal = nil
    self.Temporal = nil
    self.Occipital = nil
    self.Frontal = nil
end

return Brain
]====],
    ["Modules/Core/Brain/Frontal.lua"] = [====[--[[
    FrontalLobe.lua - Executive Function & Motor Control
    Analogy: Planning and executing movements (Aimbot/Silent Aim).
    Script Job: Dispatches actual aimbot actions based on brain decisions.
]]

local FrontalLobe = {}
FrontalLobe.__index = FrontalLobe

function FrontalLobe.new(aimbot, silentAim, options)
    local self = setmetatable({}, FrontalLobe)
    self.Aimbot = aimbot
    self.SilentAim = silentAim
    self.Options = options
    return self
end

function FrontalLobe:Execute(targetPos, part, entry, dt, rawTargetPos)
    local mode = self.Options.AssistMode
    
    if mode == "Camera Lock" then
        self.SilentAim:Clear()
        self.Aimbot:Update(targetPos, self.Options.Smoothness)
    elseif mode == "Silent Aim" then
        self.SilentAim:SetState(true, part, rawTargetPos or targetPos, entry, dt)
    elseif mode == "Highlight Only" then
        self.SilentAim:Clear()
    else
        self:Rest()
    end
end

function FrontalLobe:Rest()
    self.SilentAim:Clear()
end

return FrontalLobe

]====],
    ["Modules/Core/Brain/Occipital.lua"] = [====[--[[
    OccipitalLobe.lua - Visual Processing
    Analogy: Primary visual cortex.
    Job: Manages FOV, Highlight, and Target feedback dots.
]]

local OccipitalLobe = {}
OccipitalLobe.__index = OccipitalLobe

function OccipitalLobe.new(visuals)
    local self = setmetatable({}, OccipitalLobe)
    self.fov = visuals.fov
    self.highlight = visuals.highlight
    self.dot = visuals.dot
    self.technique = visuals.technique
    return self
end

function OccipitalLobe:Process(mousePos, targetPos, targetPart, onScreen, techniqueDecision, entry)
    -- GUARD: FOV Update should always happen to ensure crosshair feedback
    self.fov:Update(mousePos)

    if self.technique then
        self.technique:Update(techniqueDecision, entry)
    end
    
    -- GUARD: Resolution findings (Fragility fixes)
    -- Only set dot/highlight if we have a valid onscreen target
    if targetPos and targetPart and onScreen then
        self.dot:Set(targetPos, true)
        self.highlight:Set(targetPart, true)
    else
        self:Clear()
    end
end

function OccipitalLobe:UpdateFOV(mousePos)
    self.fov:Update(mousePos)
end

function OccipitalLobe:Clear()
    -- Safe cleanup: Ensure no trailing highlights or disconnected dots
    self.highlight:Clear()
    self.dot:Set(nil, false)
    if self.technique then
        self.technique:Clear()
    end
end

return OccipitalLobe

]====],
    ["Modules/Core/Brain/Parietal.lua"] = [====[--[[
    ParietalLobe.lua - Sensory & Input Processing
    Analogy: Integrates sensory information from various parts of the body.
    Script Job: Monitors user input and world entity tracking.
]]

local ParietalLobe = {}
ParietalLobe.__index = ParietalLobe

function ParietalLobe.new(input, tracker)
    local self = setmetatable({}, ParietalLobe)
    self.Input = input
    self.Tracker = tracker
    return self
end

function ParietalLobe:Process()
    local shouldAssist = self.Input:ShouldAssist()
    if not shouldAssist then
        return false, nil
    end
    return true, self.Tracker:GetTargets()
end

return ParietalLobe

]====],
    ["Modules/Core/Brain/Temporal.lua"] = [====[--[[
    TemporalLobe.lua - Processing sensory input into cognition.
    Analogy: High-level cognition and logic orchestration.
    Job: Orchestrates the target selection and prediction pipeline.
]]

local TemporalLobe = {}
TemporalLobe.__index = TemporalLobe

function TemporalLobe.new(selector, predictor)
    local self = setmetatable({}, TemporalLobe)
    self.Selector = selector
    self.Predictor = predictor

    self._targetEntry = nil
    self._targetPart = nil
    self._prediction = nil
    self._rawPrediction = nil
    self._techniqueDecision = nil
    self._lastEntry = nil
    self._lastPart = nil
    return self
end

function TemporalLobe:Scan(mousePos, originPos)
    local nextEntry = self.Selector:GetClosestTarget(mousePos, originPos, self._targetEntry)
    if nextEntry ~= self._targetEntry then
        self._targetEntry = nextEntry
        self._targetPart = nil
        self._prediction = nil
    else
        self._targetEntry = nextEntry
    end
    return self._targetEntry
end

function TemporalLobe:Process(originPos, dt)
    if not self._targetEntry then
        if self._lastEntry then
            self.Predictor:NotifyTargetChanged(nil)
            self._lastEntry = nil
            self._lastPart = nil
        end
        self._targetPart = nil
        self._prediction = nil
        self._rawPrediction = nil
        self._techniqueDecision = nil
        return nil, nil
    end

    if self._targetEntry.Humanoid and self._targetEntry.Humanoid.Health <= 0 then
        self._targetEntry = nil
        self._targetPart = nil
        self._prediction = nil
        self._rawPrediction = nil
        self._techniqueDecision = nil
        if self._lastEntry then
            self.Predictor:NotifyTargetChanged(nil)
            self._lastEntry = nil
            self._lastPart = nil
        end
        return nil, nil
    end

    self._targetPart = self.Selector.Tracker:GetTargetPart(self._targetEntry)
    if not self._targetPart then
        self._targetEntry = nil
        self._prediction = nil
        self._rawPrediction = nil
        self._techniqueDecision = nil
        if self._lastEntry then
            self.Predictor:NotifyTargetChanged(nil)
            self._lastEntry = nil
            self._lastPart = nil
        end
        return nil, nil
    end

    if self._targetEntry ~= self._lastEntry or self._targetPart ~= self._lastPart then
        self.Predictor:NotifyTargetChanged(self._targetEntry, self._targetPart)
        self._lastEntry = self._targetEntry
        self._lastPart = self._targetPart
    end

    self._prediction, self._rawPrediction, self._techniqueDecision = self.Predictor:Predict(originPos, self._targetPart, self._targetEntry, dt)

    return self._targetPart, self._prediction, self._rawPrediction, self._techniqueDecision
end

return TemporalLobe
]====],
    ["Modules/Legacy/Prediction/CompatAdapter.lua"] = [====[--[[
    CompatAdapter.lua - Bridge from the legacy PredictionCore interface to the modern predictor pipeline
    Job: Provide a compatibility seam so future callers can stop depending on the God-file API.
]]

local CompatAdapter = {}
CompatAdapter.__index = CompatAdapter

function CompatAdapter.new(predictor)
    local self = setmetatable({}, CompatAdapter)
    self.Predictor = predictor
    return self
end

function CompatAdapter:PredictTargetPosition(origin, part, entry, dt)
    if not self.Predictor or not part then
        return part and part.Position or nil
    end

    local predicted = select(1, self.Predictor:Predict(origin, part, entry, dt or (1 / 60)))
    return predicted
end

function CompatAdapter:PredictWithStrafe(origin, part, entry, dt)
    return self:PredictTargetPosition(origin, part, entry, dt)
end

function CompatAdapter:GetSelectionTargetPosition(origin, part, entry, _isCurrentTarget, dt)
    return self:PredictTargetPosition(origin, part, entry, dt)
end

function CompatAdapter:StabilizeTargetPosition(entry, _part, rawPos)
    if entry then
        entry.StabilizedTargetPos = rawPos
    end
    return rawPos
end

return CompatAdapter
]====],
    ["Modules/Movement/AntiSlowdown.lua"] = [====[--[[
    AntiSlowdown.lua - Neuro-Motor Defense Module
    Job: Preventing speed-related debuffs (Slows).
    Status: Decoupled with active walkspeed/jump monitoring.
]]

local RunService = game:GetService("RunService")
local clock = os.clock

local AntiSlowdown = {}
AntiSlowdown.__index = AntiSlowdown

function AntiSlowdown.new(options, localCharacter, movementArbiter)
    local self = setmetatable({}, AntiSlowdown)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.MovementArbiter = movementArbiter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.BaseJumpPower = 50
    self.TrackedHumanoid = nil

    self.Status = "Idle"
    self._lastAction = 0
    self._lastWriteTime = 0
    self._yieldingToSpeedOverride = false
    self._arbiterKey = "__STAR_GLITCHER_ANTI_SLOWDOWN"
    return self
end

function AntiSlowdown:_setStatus(status)
    if self.Status ~= status then
        self.Status = status
    end
end

function AntiSlowdown:CaptureBaseStats(humanoid)
    local hum = humanoid or (self.LocalCharacter and self.LocalCharacter:GetHumanoid())
    if not hum then
        return
    end

    self.TrackedHumanoid = hum
    self.BaseWalkSpeed = math.max(hum.WalkSpeed, 16)
    self.BaseJumpPower = math.max(hum.JumpPower, 50)
end

function AntiSlowdown:_learnLegitMovement(humanoid)
    local now = clock()
    if (now - self._lastWriteTime) < 0.25 then
        return
    end

    if humanoid.WalkSpeed > (self.BaseWalkSpeed + 1.5) then
        self.BaseWalkSpeed = humanoid.WalkSpeed
    end

    if humanoid.JumpPower > (self.BaseJumpPower + 1.5) then
        self.BaseJumpPower = humanoid.JumpPower
    end
end

function AntiSlowdown:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoSlowdown then
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self:_setStatus("Disabled")
            return
        end

        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self:_setStatus("Hum Missing")
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                self:CaptureBaseStats(hum)
            end
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._yieldingToSpeedOverride = false
            self:_setStatus("Respawn Grace")
            return
        end

        if self.Options.CustomMoveSpeedEnabled or self.Options.SpeedMultiplierEnabled then
            self._yieldingToSpeedOverride = true
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self:_setStatus("Yielding to Speed Override")
            return
        end

        if self._yieldingToSpeedOverride then
            self._yieldingToSpeedOverride = false
            self:CaptureBaseStats(hum)
            self:_setStatus("Recalibrated")
            return
        end

        self:_setStatus("Monitoring Speed")

        if hum ~= self.TrackedHumanoid then
            self:CaptureBaseStats(hum)
        end

        self:_learnLegitMovement(hum)

        local actionTaken = false
        if self.MovementArbiter then
            self.MovementArbiter:SetWalkMinimum(self._arbiterKey, self.BaseWalkSpeed)
            self.MovementArbiter:SetJumpMinimum(self._arbiterKey, self.BaseJumpPower)
            actionTaken = hum.WalkSpeed < self.BaseWalkSpeed or hum.JumpPower < self.BaseJumpPower
        else
            if hum.WalkSpeed < self.BaseWalkSpeed then
                hum.WalkSpeed = self.BaseWalkSpeed
                self._lastWriteTime = clock()
                actionTaken = true
            end

            if hum.JumpPower < self.BaseJumpPower then
                hum.JumpPower = self.BaseJumpPower
                self._lastWriteTime = clock()
                actionTaken = true
            end
        end

        if actionTaken then
            self._lastAction = clock()
        end

        if (clock() - self._lastAction) < 1.0 then
            self:_setStatus("Active: SPEED PROTECTED")
        end
    end)
end

function AntiSlowdown:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end
end

return AntiSlowdown
]====],
    ["Modules/Movement/AntiStun.lua"] = [====[--[[
    AntiStun.lua - Neurological Defense Module (Bug Fixed)
    Job: Preventing character CC (Stun, Ragdoll, Sit, Fall).
    Status: Fully decoupled with active monitoring.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local clock = os.clock

local AntiStun = {}
AntiStun.__index = AntiStun

function AntiStun.new(options, localCharacter)
    local self = setmetatable({}, AntiStun)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.TrackedHumanoid = nil

    self.Status = "Idle"
    self._lastAction = 0
    return self
end

function AntiStun:_setStatus(status)
    if self.Status ~= status then
        self.Status = status
    end
end

function AntiStun:_restoreStateGuards(humanoid)
    if not humanoid then
        return
    end
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
    end)
end

function AntiStun:_applyStateGuards(humanoid)
    if not humanoid then
        return
    end
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid.PlatformStand = false
        humanoid.Sit = false
    end)
end

function AntiStun:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local _, hum = self.LocalCharacter and self.LocalCharacter:GetState()
        
        -- PROACTIVE SCAN: If module says hum is missing, check the direct player object
        if not hum then
            local lp = Players.LocalPlayer
            local char = lp.Character
            hum = char and char:FindFirstChildOfClass("Humanoid")
        end

        if not self.Options.NoStun then
            self:_setStatus("Disabled")
            if hum == self.TrackedHumanoid then
                self:_restoreStateGuards(hum)
                self.TrackedHumanoid = nil
            end
            return
        end

        if not hum then
            self:_setStatus("Hum Missing")
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                if self.TrackedHumanoid then
                    self:_restoreStateGuards(self.TrackedHumanoid)
                end
                self.TrackedHumanoid = hum
            end
            self:_setStatus("Respawn Grace")
            return
        end

        self:_setStatus("Active: Monitoring")

        if hum ~= self.TrackedHumanoid then
            if self.TrackedHumanoid then
                self:_restoreStateGuards(self.TrackedHumanoid)
            end
            self.TrackedHumanoid = hum
            self:_applyStateGuards(hum)
        end

        local state = hum:GetState()
        local actionTaken = false

        if state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            actionTaken = true
        end

        if hum.PlatformStand then
            hum.PlatformStand = false
            actionTaken = true
        end

        if hum.Sit then
            hum.Sit = false
            actionTaken = true
        end

        if actionTaken then
            self._lastAction = clock()
        end

        if (clock() - self._lastAction) < 1.0 then
            self:_setStatus("Active: CC PROTECTED")
        end
    end)
end

function AntiStun:Destroy()
    if self.TrackedHumanoid then
        self:_restoreStateGuards(self.TrackedHumanoid)
        self.TrackedHumanoid = nil
    end
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AntiStun
]====],
    ["Modules/Movement/AttributeCleaner.lua"] = [====[local RunService = game:GetService("RunService")

local AttributeCleaner = {}
AttributeCleaner.__index = AttributeCleaner

function AttributeCleaner.new(options, localCharacter)
    local self = setmetatable({}, AttributeCleaner)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self._lastSweep = 0
    self._sweepInterval = 0.12
    return self
end

local function shouldClearName(lowerName)
    if not lowerName or lowerName == "" then
        return false
    end

    -- Only clear explicit movement-impairing debuffs.
    -- Avoid generic names like "delay", "cooldown", or "root" because
    -- many games use them for legitimate form-switch / ability logic.
    return lowerName:find("slow", 1, true)
        or lowerName:find("stun", 1, true)
        or lowerName:find("freeze", 1, true)
        or lowerName:find("ragdoll", 1, true)
        or lowerName:find("snare", 1, true)
        or lowerName:find("immobile", 1, true)
end

function AttributeCleaner:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoDelay then
            return
        end

        local now = os.clock()
        if (now - self._lastSweep) < self._sweepInterval then
            return
        end
        self._lastSweep = now

        local char = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        if not char then
            return
        end

        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("ValueBase") then
                local n = child.Name:lower()
                if shouldClearName(n) then
                    child:Destroy()
                end
            end
        end

        for attr, _ in pairs(char:GetAttributes()) do
            local lower = attr:lower()
            if shouldClearName(lower) then
                char:SetAttribute(attr, nil)
            end
        end
    end)
end

function AttributeCleaner:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AttributeCleaner
]====],
    ["Modules/Movement/CustomSpeed.lua"] = [====[local RunService = game:GetService("RunService")

local CustomSpeed = {}
CustomSpeed.__index = CustomSpeed

function CustomSpeed.new(options, localCharacter, movementArbiter)
    local self = setmetatable({}, CustomSpeed)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.MovementArbiter = movementArbiter
    self.Connection = nil
    self.TrackedHumanoid = nil
    self.BaseWalkSpeed = 16
    self._wasEnabled = false
    self._arbiterKey = "__STAR_GLITCHER_CUSTOM_SPEED"
    return self
end

function CustomSpeed:_captureBaseSpeed(humanoid)
    if humanoid then
        self.TrackedHumanoid = humanoid
        self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
    end
end

function CustomSpeed:_restoreBaseSpeed(humanoid)
    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
        return
    end

    if humanoid and math.abs(humanoid.WalkSpeed - self.BaseWalkSpeed) > 0.1 then
        humanoid.WalkSpeed = self.BaseWalkSpeed
    end
end

function CustomSpeed:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if hum and hum ~= self.TrackedHumanoid then
            self:_captureBaseSpeed(hum)
            self._wasEnabled = false
        end

        if not self.Options.CustomMoveSpeedEnabled then
            if hum and self._wasEnabled then
                self:_restoreBaseSpeed(hum)
            end
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._wasEnabled = false
            return
        end

        if self.Options.SpeedMultiplierEnabled then
            if hum and self._wasEnabled then
                self:_restoreBaseSpeed(hum)
            end
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._wasEnabled = false
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._wasEnabled = false
            return
        end

        if not hum then
            return
        end

        if not self._wasEnabled then
            self:_captureBaseSpeed(hum)
            self._wasEnabled = true
        end

        if self.MovementArbiter then
            self.MovementArbiter:SetWalkExact(self._arbiterKey, self.Options.CustomMoveSpeed, 100)
        elseif math.abs(hum.WalkSpeed - self.Options.CustomMoveSpeed) > 0.1 then
            hum.WalkSpeed = self.Options.CustomMoveSpeed
        end
    end)
end

function CustomSpeed:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end

    local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if hum and self._wasEnabled then
        self:_restoreBaseSpeed(hum)
    end
end

return CustomSpeed
]====],
    ["Modules/Movement/FloatController.lua"] = [====[local RunService = game:GetService("RunService")

local FloatController = {}
FloatController.__index = FloatController

local AIR_STATES = {
    [Enum.HumanoidStateType.Freefall] = true,
    [Enum.HumanoidStateType.Jumping] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
}

function FloatController.new(options, localCharacter)
    local self = setmetatable({}, FloatController)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self._connection = nil
    return self
end

function FloatController:Init()
    if self._connection then
        return
    end

    self._connection = RunService.Heartbeat:Connect(function()
        if not self.Options.FloatEnabled then
            self.Status = "Idle"
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            self.Status = "Respawn grace"
            return
        end

        local _, humanoid, root = self.LocalCharacter:GetState()
        if not humanoid or not root then
            self.Status = "Waiting for character"
            return
        end

        local state = humanoid:GetState()
        if not AIR_STATES[state] then
            self.Status = "Grounded"
            return
        end

        local velocity = root.AssemblyLinearVelocity
        local maxFallSpeed = -math.clamp(tonumber(self.Options.FloatFallSpeed) or 8, 0, 80)
        if velocity.Y < maxFallSpeed then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, maxFallSpeed, velocity.Z)
            self.Status = string.format("Softening fall: %.1f", math.abs(maxFallSpeed))
        else
            self.Status = "Airborne hold"
        end
    end)
end

function FloatController:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

return FloatController
]====],
    ["Modules/Movement/GravityController.lua"] = [====[local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GravityController = {}
GravityController.__index = GravityController

local DEFAULT_GRAVITY = 196.2

function GravityController.new(options)
    local self = setmetatable({}, GravityController)
    self.Options = options
    self.Status = "Idle"
    self.BaseGravity = Workspace.Gravity or DEFAULT_GRAVITY
    self._connection = nil
    self._applied = false
    return self
end

function GravityController:_restore()
    if self._applied and math.abs(Workspace.Gravity - self.BaseGravity) > 0.05 then
        Workspace.Gravity = self.BaseGravity
    end
    self._applied = false
end

function GravityController:Init()
    if self._connection then
        return
    end

    self._connection = RunService.Heartbeat:Connect(function()
        if self.Options.GravityEnabled then
            local desired = math.clamp(tonumber(self.Options.GravityValue) or DEFAULT_GRAVITY, 0, 1000)
            if math.abs(Workspace.Gravity - desired) > 0.05 then
                Workspace.Gravity = desired
            end
            self._applied = true
            self.Status = string.format("Active: %.1f", desired)
            return
        end

        if not self._applied then
            self.BaseGravity = Workspace.Gravity
            self.Status = "Idle"
            return
        end

        self:_restore()
        self.Status = "Idle"
    end)
end

function GravityController:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self:_restore()
end

return GravityController
]====],
    ["Modules/Movement/HitboxDesync.lua"] = [====[local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local SAFE_POS = Vector3.new(-1000, -250, -1000)
local SAFE_CFRAME = CFrame.new(SAFE_POS + Vector3.new(0, 3, 0))
local FLICKER_OFFSET = CFrame.new(0, 0, 1.5)
local FLICKER_DURATION = 0.06
local DEFAULT_SPEED = 16

local HitboxDesync = {}
HitboxDesync.__index = HitboxDesync

function HitboxDesync.new(options, localCharacter)
    local self = setmetatable({}, HitboxDesync)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self.IsActive = false
    self.Connections = {}
    self.MirrorBox = nil
    self.ActiveCharacter = nil
    self.ActiveHumanoid = nil
    self.ActiveRoot = nil
    self.VisualRoot = nil
    self.RootJoint = nil
    self.JointParent = nil
    self.VisualParts = {}
    self.VisualOffsets = {}
    self.NexusPos = Vector3.zero
    self.NexusRot = 0
    self.FlickerUntil = 0
    self.OriginalRootTransparency = 0
    self.OriginalAutoRotate = true
    self.OriginalCameraSubject = nil
    return self
end

function HitboxDesync:_setStatus(status)
    self.Status = status
end

function HitboxDesync:_getCharacterState()
    if not self.LocalCharacter or not self.LocalCharacter.GetState then
        return nil, nil, nil
    end
    return self.LocalCharacter:GetState()
end

function HitboxDesync:_isRespawning()
    return self.LocalCharacter
        and self.LocalCharacter.IsRespawning
        and self.LocalCharacter:IsRespawning()
end

function HitboxDesync:_isValidDamageTarget(target)
    return typeof(target) == "Instance"
        and target:IsA("BasePart")
        and target.Parent ~= nil
end

function HitboxDesync:_findRootJoint(character)
    for _, joint in ipairs(character:GetDescendants()) do
        if joint:IsA("Motor6D")
            and (joint.Name == "RootJoint" or joint.Name == "Root")
            and joint.Part0
            and joint.Part0.Name == "HumanoidRootPart"
            and joint.Part1
            and joint.Part1.Name == "Torso"
        then
            return joint
        end
    end
    return nil
end

function HitboxDesync:_validateR6Rig(character, humanoid, root)
    if not character or not humanoid or not root then
        return false, "Body Missing"
    end

    if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        return false, "R6 Only"
    end

    local torso = character:FindFirstChild("Torso")
    if not torso or not torso:IsA("BasePart") then
        return false, "R6 Torso Missing"
    end

    local rootJoint = self:_findRootJoint(character)
    if not rootJoint then
        return false, "RootJoint Missing"
    end

    return true, torso, rootJoint
end

function HitboxDesync:_clearVisualRig()
    table.clear(self.VisualParts)
    table.clear(self.VisualOffsets)
end

function HitboxDesync:_captureVisualRig(character, visualRoot, root)
    self:_clearVisualRig()

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") and obj ~= root then
            self.VisualParts[#self.VisualParts + 1] = obj
            self.VisualOffsets[obj] = visualRoot.CFrame:ToObjectSpace(obj.CFrame)
        end
    end
end

function HitboxDesync:_createMirrorBox()
    self:_destroyMirrorBox()

    local box = Instance.new("Part")
    box.Name = "Zenith_MirrorBox"
    box.Size = Vector3.new(10, 1, 10)
    box.CFrame = CFrame.new(SAFE_POS)
    box.Transparency = 1
    box.Anchored = true
    box.CanCollide = true
    box.Parent = Workspace
    self.MirrorBox = box
end

function HitboxDesync:_destroyMirrorBox()
    if self.MirrorBox then
        self.MirrorBox:Destroy()
        self.MirrorBox = nil
    end
end

function HitboxDesync:_clearSession()
    self.ActiveCharacter = nil
    self.ActiveHumanoid = nil
    self.ActiveRoot = nil
    self.VisualRoot = nil
    self.RootJoint = nil
    self.JointParent = nil
    self.FlickerUntil = 0
    self.OriginalCameraSubject = nil
    self:_clearVisualRig()
end

function HitboxDesync:_computeMoveVector(camera)
    local moveVec = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveVec += camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveVec -= camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveVec -= camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveVec += camera.CFrame.RightVector
    end

    moveVec = Vector3.new(moveVec.X, 0, moveVec.Z)
    if moveVec.Magnitude <= 0 then
        return Vector3.zero
    end

    return moveVec.Unit
end

function HitboxDesync:_getVisualSpeed()
    if self.Options.CustomMoveSpeedEnabled then
        return self.Options.CustomMoveSpeed or DEFAULT_SPEED
    end
    return DEFAULT_SPEED
end

function HitboxDesync:_updateNexusMotion(dt, humanoid, camera)
    local moveVec = self:_computeMoveVector(camera)
    if moveVec.Magnitude > 0 then
        self.NexusPos += (moveVec * self:_getVisualSpeed() * dt)
        self.NexusRot = math.atan2(moveVec.X, moveVec.Z)
        humanoid:Move(moveVec, true)
    else
        humanoid:Move(Vector3.zero, true)
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        humanoid.Jump = true
    end
end

function HitboxDesync:_applyVisualPose()
    if not self.VisualRoot or not self.VisualRoot.Parent then
        return false
    end

    local pose = CFrame.new(self.NexusPos) * CFrame.Angles(0, self.NexusRot, 0)
    for _, part in ipairs(self.VisualParts) do
        if part and part.Parent then
            local offset = self.VisualOffsets[part]
            if offset then
                part.CFrame = pose * offset
            end
        end
    end

    return true
end

function HitboxDesync:_beginSilentDamageWindow()
    if self.Options.SilentDamageEnabled and self:_isValidDamageTarget(_G.CurrentZTarget) then
        self.FlickerUntil = os.clock() + FLICKER_DURATION
    end
end

function HitboxDesync:_placeHitboxRoot(root)
    local target = _G.CurrentZTarget
    if self.Options.SilentDamageEnabled
        and self.FlickerUntil > os.clock()
        and self:_isValidDamageTarget(target)
    then
        root.CFrame = target.CFrame * FLICKER_OFFSET
        root.AssemblyLinearVelocity = Vector3.zero
        return
    end

    root.CFrame = SAFE_CFRAME
    root.AssemblyLinearVelocity = Vector3.zero
end

function HitboxDesync:_freezeHitboxRoot(root)
    root.Anchored = true
    root.Transparency = 1
    self:_placeHitboxRoot(root)
end

function HitboxDesync:_restoreRoot(root)
    if not root then
        return
    end

    root.Anchored = false
    root.Transparency = self.OriginalRootTransparency or 0
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.new(self.NexusPos) * CFrame.Angles(0, self.NexusRot, 0)
end

function HitboxDesync:_restoreCamera(restoreHumanoid)
    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CameraSubject = self.OriginalCameraSubject or restoreHumanoid or camera.CameraSubject
        end
    end)
end

function HitboxDesync:_stopCurrentSession(status)
    if not self.IsActive and not self.ActiveRoot and not self.RootJoint and not self.MirrorBox then
        self:_clearSession()
        self:_setStatus(status or "Disabled")
        return
    end

    if self.RootJoint and self.JointParent then
        self.RootJoint.Parent = self.JointParent
    end

    local _, humanoid, root = self:_getCharacterState()
    local restoreHumanoid = humanoid or self.ActiveHumanoid
    local restoreRoot = root or self.ActiveRoot

    if restoreHumanoid then
        restoreHumanoid.AutoRotate = self.OriginalAutoRotate
    end

    self:_restoreRoot(restoreRoot)
    self:_restoreCamera(restoreHumanoid)
    self:_destroyMirrorBox()
    self:_clearSession()
    self.IsActive = false
    self:_setStatus(status or "Disabled")
end

function HitboxDesync:_startSession(character, humanoid, root)
    if self.IsActive then
        self:_stopCurrentSession("Restarting")
    end

    local ok, visualRoot, rootJoint = self:_validateR6Rig(character, humanoid, root)
    if not ok then
        self:_setStatus(visualRoot)
        return false
    end

    self.ActiveCharacter = character
    self.ActiveHumanoid = humanoid
    self.ActiveRoot = root
    self.VisualRoot = visualRoot
    self.RootJoint = rootJoint
    self.JointParent = rootJoint.Parent
    self.NexusPos = visualRoot.Position
    self.NexusRot = root.Orientation.Y * math.pi / 180
    self.OriginalRootTransparency = root.Transparency
    self.OriginalAutoRotate = humanoid.AutoRotate
    self.OriginalCameraSubject = Workspace.CurrentCamera and Workspace.CurrentCamera.CameraSubject or nil

    self:_captureVisualRig(character, visualRoot, root)
    self:_createMirrorBox()

    rootJoint.Parent = nil
    humanoid.AutoRotate = false
    self:_freezeHitboxRoot(root)

    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CameraSubject = visualRoot
        end
    end)

    self.IsActive = true
    self:_setStatus("Zenith Active")
    return true
end

function HitboxDesync:_needsRestart(character, root)
    return not self.IsActive
        or character ~= self.ActiveCharacter
        or root ~= self.ActiveRoot
        or not self.VisualRoot
        or not self.VisualRoot.Parent
        or not self.RootJoint
        or not self.JointParent
end

function HitboxDesync:_onHeartbeat()
    if not self.Options.ZenithDesyncEnabled then
        if self.IsActive then
            self:_stopCurrentSession("Disabled")
        else
            self:_setStatus("Disabled")
        end
        return
    end

    local character, humanoid, root = self:_getCharacterState()
    if not character or not humanoid or not root then
        if self.IsActive then
            self:_stopCurrentSession("Body Missing")
        else
            self:_setStatus("Body Missing")
        end
        return
    end

    if self:_isRespawning() then
        if self.IsActive then
            self:_stopCurrentSession("Respawn Grace")
        else
            self:_setStatus("Respawn Grace")
        end
        return
    end

    if self:_needsRestart(character, root) and not self:_startSession(character, humanoid, root) then
        return
    end

    self:_beginSilentDamageWindow()
    self:_freezeHitboxRoot(root)
end

function HitboxDesync:_onRenderStepped(dt)
    if not self.IsActive then
        return
    end

    local humanoid = self.ActiveHumanoid
    local camera = Workspace.CurrentCamera
    if not humanoid or not camera then
        self:_setStatus(camera and "Humanoid Missing" or "Camera Missing")
        return
    end

    self:_updateNexusMotion(dt, humanoid, camera)
    if self:_applyVisualPose() then
        self:_setStatus("Zenith Active")
    else
        self:_setStatus("Visual Sync Lost")
    end
end

function HitboxDesync:Init()
    table.insert(self.Connections, RunService.Heartbeat:Connect(function()
        self:_onHeartbeat()
    end))

    table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
        self:_onRenderStepped(dt)
    end))
end

function HitboxDesync:Start(character, root, humanoid)
    self:_startSession(character, humanoid, root)
end

function HitboxDesync:Stop()
    self:_stopCurrentSession("Disabled")
end

function HitboxDesync:Destroy()
    self:Stop()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    table.clear(self.Connections)
end

return HitboxDesync
]====],
    ["Modules/Movement/JumpBoost.lua"] = [====[local RunService = game:GetService("RunService")

local JumpBoost = {}
JumpBoost.__index = JumpBoost

local DEFAULT_JUMP_POWER = 50

function JumpBoost.new(options, localCharacter, movementArbiter)
    local self = setmetatable({}, JumpBoost)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.MovementArbiter = movementArbiter
    self.Status = "Idle"
    self.TrackedHumanoid = nil
    self.BaseJumpPower = DEFAULT_JUMP_POWER
    self._connection = nil
    self._applied = false
    self._arbiterKey = "__STAR_GLITCHER_JUMP_BOOST"
    return self
end

function JumpBoost:_captureBaseJump(humanoid)
    if humanoid then
        self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
    end
end

function JumpBoost:_restore()
    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
        self._applied = false
        return
    end

    local humanoid = self.TrackedHumanoid
    if humanoid and humanoid.Parent and self._applied then
        if math.abs(humanoid.JumpPower - self.BaseJumpPower) > 0.1 then
            humanoid.JumpPower = self.BaseJumpPower
        end
    end
    self._applied = false
end

function JumpBoost:Init()
    if self._connection then
        return
    end

    self._connection = RunService.Heartbeat:Connect(function()
        local humanoid = self.LocalCharacter:GetHumanoid()
        if humanoid ~= self.TrackedHumanoid then
            self.TrackedHumanoid = humanoid
            self:_captureBaseJump(humanoid)
            self._applied = false
        end

        if not humanoid then
            self.Status = "Waiting for humanoid"
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._applied = false
            self.Status = "Respawn grace"
            return
        end

        if not self.Options.JumpBoostEnabled then
            if not self._applied then
                self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
                if self.MovementArbiter then
                    self.MovementArbiter:ClearSource(self._arbiterKey)
                end
                self.Status = "Idle"
                return
            end

            self:_restore()
            self.Status = "Idle"
            return
        end

        local desired = math.clamp(tonumber(self.Options.JumpBoostPower) or DEFAULT_JUMP_POWER, 1, 300)
        if self.MovementArbiter then
            self.MovementArbiter:SetJumpExact(self._arbiterKey, desired, 50)
        else
            if not humanoid.UseJumpPower then
                humanoid.UseJumpPower = true
            end
            if math.abs(humanoid.JumpPower - desired) > 0.1 then
                humanoid.JumpPower = desired
            end
        end
        self._applied = true
        self.Status = string.format("Active: %.0f", desired)
    end)
end

function JumpBoost:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end
    self:_restore()
end

return JumpBoost
]====],
    ["Modules/Movement/KillPartBypass.lua"] = [====[--[[
    KillPartBypass.lua
    Job: Suppress touch/query hits on the local character so environmental
    kill parts are less likely to register against it.
]]

local RunService = game:GetService("RunService")

local KillPartBypass = {}
KillPartBypass.__index = KillPartBypass

function KillPartBypass.new(options, localCharacter)
    local self = setmetatable({}, KillPartBypass)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    return self
end

local function suppressPartSensors(part)
    pcall(function()
        if part.CanTouch then
            part.CanTouch = false
        end
        if part.CanQuery then
            part.CanQuery = false
        end
    end)
end

function KillPartBypass:Init()
    self.Connection = RunService.Stepped:Connect(function()
        if not self.Options.KillPartBypassEnabled then
            if self.Status ~= "Disabled" then
                self.Status = "Disabled"
            end
            return
        end

        local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()

        if not character then
            self.Status = "Char Missing"
            return
        end

        self.Status = "Active: Touch Mask"

        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                suppressPartSensors(obj)
            end
        end

        if rootPart then
            suppressPartSensors(rootPart)
        end
    end)
end

function KillPartBypass:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return KillPartBypass
]====],
    ["Modules/Movement/MovementArbiter.lua"] = [====[local RunService = game:GetService("RunService")

local MovementArbiter = {}
MovementArbiter.__index = MovementArbiter

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

function MovementArbiter.new(options, localCharacter)
    local self = setmetatable({}, MovementArbiter)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.TrackedHumanoid = nil
    self.BaseWalkSpeed = DEFAULT_WALK_SPEED
    self.BaseJumpPower = DEFAULT_JUMP_POWER
    self._requests = {}
    self._appliedWalk = false
    self._appliedJump = false
    self._lastWriteAt = 0
    self.Status = "Idle"
    return self
end

function MovementArbiter:_ensureRequest(source)
    local request = self._requests[source]
    if not request then
        request = {}
        self._requests[source] = request
    end
    return request
end

function MovementArbiter:SetWalkExact(source, value, priority)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.WalkExact = tonumber(value)
    request.WalkPriority = tonumber(priority) or 0
end

function MovementArbiter:SetWalkMinimum(source, value)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.WalkMin = tonumber(value)
end

function MovementArbiter:SetJumpExact(source, value, priority)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.JumpExact = tonumber(value)
    request.JumpPriority = tonumber(priority) or 0
end

function MovementArbiter:SetJumpMinimum(source, value)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.JumpMin = tonumber(value)
end

function MovementArbiter:ClearSource(source)
    if not source then
        return
    end
    self._requests[source] = nil
end

function MovementArbiter:GetBaseWalkSpeed()
    return self.BaseWalkSpeed
end

function MovementArbiter:_captureBase(humanoid)
    if not humanoid then
        return
    end

    self.TrackedHumanoid = humanoid
    self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, DEFAULT_WALK_SPEED)
    self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
end

function MovementArbiter:_learnBase(humanoid, hasWalkExact, hasWalkMin, hasJumpExact, hasJumpMin)
    if not humanoid or (os.clock() - self._lastWriteAt) < 0.3 then
        return
    end

    if not hasWalkExact and not hasWalkMin and humanoid.WalkSpeed > (self.BaseWalkSpeed + 0.75) then
        self.BaseWalkSpeed = humanoid.WalkSpeed
    end

    if not hasJumpExact and not hasJumpMin and humanoid.JumpPower > (self.BaseJumpPower + 1) then
        self.BaseJumpPower = humanoid.JumpPower
    end
end

function MovementArbiter:_pickExact(kind)
    local bestValue = nil
    local bestPriority = -math.huge

    for _, request in pairs(self._requests) do
        local value = request[kind]
        if value ~= nil then
            local priorityKey = (kind == "WalkExact") and "WalkPriority" or "JumpPriority"
            local priority = request[priorityKey] or 0
            if priority > bestPriority then
                bestPriority = priority
                bestValue = value
            end
        end
    end

    return bestValue ~= nil, bestValue
end

function MovementArbiter:_pickMinimum(kind)
    local best = nil
    for _, request in pairs(self._requests) do
        local value = request[kind]
        if value ~= nil then
            best = best and math.max(best, value) or value
        end
    end
    return best ~= nil, best
end

function MovementArbiter:_writeHumanoidProperty(humanoid, propertyName, value)
    if not humanoid or value == nil then
        return false
    end

    if math.abs((humanoid[propertyName] or 0) - value) <= 0.1 then
        return false
    end

    humanoid[propertyName] = value
    self._lastWriteAt = os.clock()
    return true
end

function MovementArbiter:_applyWalk(humanoid)
    local hasExact, exactValue = self:_pickExact("WalkExact")
    local hasMin, minValue = self:_pickMinimum("WalkMin")

    if hasExact then
        self._appliedWalk = self:_writeHumanoidProperty(humanoid, "WalkSpeed", exactValue) or self._appliedWalk
        return hasExact, hasMin
    end

    if hasMin and humanoid.WalkSpeed < minValue then
        self._appliedWalk = self:_writeHumanoidProperty(humanoid, "WalkSpeed", minValue) or self._appliedWalk
        return hasExact, hasMin
    end

    if self._appliedWalk then
        self:_writeHumanoidProperty(humanoid, "WalkSpeed", self.BaseWalkSpeed)
        self._appliedWalk = false
    end

    return hasExact, hasMin
end

function MovementArbiter:_applyJump(humanoid)
    local hasExact, exactValue = self:_pickExact("JumpExact")
    local hasMin, minValue = self:_pickMinimum("JumpMin")

    if hasExact then
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        self._appliedJump = self:_writeHumanoidProperty(humanoid, "JumpPower", exactValue) or self._appliedJump
        return hasExact, hasMin
    end

    if hasMin and humanoid.JumpPower < minValue then
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        self._appliedJump = self:_writeHumanoidProperty(humanoid, "JumpPower", minValue) or self._appliedJump
        return hasExact, hasMin
    end

    if self._appliedJump then
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        self:_writeHumanoidProperty(humanoid, "JumpPower", self.BaseJumpPower)
        self._appliedJump = false
    end

    return hasExact, hasMin
end

function MovementArbiter:_step()
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if humanoid ~= self.TrackedHumanoid then
        self:_captureBase(humanoid)
    end

    if not humanoid then
        self.Status = "Hum Missing"
        return
    end

    local hasWalkExact, hasWalkMin = self:_applyWalk(humanoid)
    local hasJumpExact, hasJumpMin = self:_applyJump(humanoid)
    self:_learnBase(humanoid, hasWalkExact, hasWalkMin, hasJumpExact, hasJumpMin)

    if hasWalkExact or hasJumpExact then
        self.Status = "Override Active"
    elseif hasWalkMin or hasJumpMin then
        self.Status = "Protection Active"
    else
        self.Status = "Idle"
    end
end

function MovementArbiter:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function()
        self:_step()
    end)
end

function MovementArbiter:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if humanoid then
        if self._appliedWalk then
            self:_writeHumanoidProperty(humanoid, "WalkSpeed", self.BaseWalkSpeed)
        end
        if self._appliedJump then
            if not humanoid.UseJumpPower then
                humanoid.UseJumpPower = true
            end
            self:_writeHumanoidProperty(humanoid, "JumpPower", self.BaseJumpPower)
        end
    end

    self._appliedWalk = false
    self._appliedJump = false
    table.clear(self._requests)
end

return MovementArbiter
]====],
    ["Modules/Movement/Noclip.lua"] = [====[--[[
    Noclip.lua - Phase Shifting Module
    Job: Disable physics collisions only.
    Notes: Kill-part touch suppression lives in KillPartBypass.lua so it can
    be controlled independently from noclip.
]]

local RunService = game:GetService("RunService")

local Noclip = {}
Noclip.__index = Noclip

function Noclip.new(options, localCharacter)
    local self = setmetatable({}, Noclip)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    return self
end

function Noclip:Init()
    self.Connection = RunService.Stepped:Connect(function()
        if not self.Options.NoclipEnabled then
            if self.Status ~= "Disabled" then
                self.Status = "Disabled"
            end
            return
        end

        local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()
        
        if not character then
            self.Status = "Char Missing"
            return
        end

        self.Status = "Active: Noclip"
        
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                if obj.CanCollide then
                    obj.CanCollide = false
                end
            end
        end

        if rootPart then
            rootPart.CanCollide = false
        end
    end)
end

function Noclip:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return Noclip
]====],
    ["Modules/Movement/ProactiveEvade.lua"] = [====[local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PROACTIVE_STRIDE = 4.5
local PROACTIVE_INTERVAL = 0.42
local FORWARD_BLEND = 1.2

local ProactiveEvade = {}
ProactiveEvade.__index = ProactiveEvade

function ProactiveEvade.new(options, localCharacter)
    local self = setmetatable({}, ProactiveEvade)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    self._lastEvadeAt = 0
    self._lastDirection = 1
    return self
end

function ProactiveEvade:_isRespawning()
    return self.LocalCharacter
        and self.LocalCharacter.IsRespawning
        and self.LocalCharacter:IsRespawning()
end

function ProactiveEvade:_getPlanarBasis(root)
    local look = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector or root.CFrame.LookVector
    look = Vector3.new(look.X, 0, look.Z)
    if look.Magnitude <= 0.001 then
        look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    end

    if look.Magnitude <= 0.001 then
        look = Vector3.zAxis
    end

    look = look.Unit
    local right = Vector3.new(look.Z, 0, -look.X)
    if right.Magnitude <= 0.001 then
        right = Vector3.xAxis
    end

    return look, right.Unit
end

function ProactiveEvade:_pickOffset(character, root)
    local forward, right = self:_getPlanarBasis(root)
    local stride = tonumber(self.Options.ProactiveEvadeStride) or PROACTIVE_STRIDE
    local forwardBlend = math.clamp(stride * 0.28, 0.75, FORWARD_BLEND)

    local offsets = {
        (right * stride) + (forward * forwardBlend),
        (-right * stride) + (forward * forwardBlend),
    }

    if self._lastDirection < 0 then
        offsets[1], offsets[2] = offsets[2], offsets[1]
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.IgnoreWater = true

    for index, offset in ipairs(offsets) do
        local result = Workspace:Raycast(root.Position, offset, params)
        if not result then
            self._lastDirection = (index == 1) and 1 or -1
            return offset
        end
    end

    self._lastDirection = -self._lastDirection
    return offsets[1]
end

function ProactiveEvade:_step()
    if not self.Options.ProactiveEvadeEnabled then
        if self.Status ~= "Disabled" then
            self.Status = "Disabled"
        end
        return
    end

    if self:_isRespawning() then
        self.Status = "Respawn Grace"
        return
    end

    local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    local root = self.LocalCharacter and self.LocalCharacter:GetRootPart()

    if not character or not humanoid or not root then
        self.Status = "Char Missing"
        return
    end

    if humanoid.Health <= 0 then
        self.Status = "Dead"
        return
    end

    local now = os.clock()
    local interval = tonumber(self.Options.ProactiveEvadeInterval) or PROACTIVE_INTERVAL
    if (now - self._lastEvadeAt) < interval then
        self.Status = "Active: Weaving"
        return
    end

    local offset = self:_pickOffset(character, root)
    local targetCFrame = root.CFrame + offset

    character:PivotTo(targetCFrame)
    root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
    self._lastEvadeAt = now
    self.Status = "Active: Sidestepping"
end

function ProactiveEvade:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function()
        self:_step()
    end)
end

function ProactiveEvade:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return ProactiveEvade
]====],
    ["Modules/Movement/SpeedMultiplier.lua"] = [====[local RunService = game:GetService("RunService")

local SpeedMultiplier = {}
SpeedMultiplier.__index = SpeedMultiplier

function SpeedMultiplier.new(options, localCharacter, movementArbiter)
    local self = setmetatable({}, SpeedMultiplier)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.MovementArbiter = movementArbiter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.TrackedHumanoid = nil
    self.Status = "Idle"
    self._lastBoostTime = 0
    self._lastWalkWriteTime = 0
    self._fallbackWarmupUntil = 0
    self._wasEnabled = false
    self._preEnableBaseSpeed = 16
    self._arbiterKey = "__STAR_GLITCHER_SPEED_MULTIPLIER"
    self._respawnRecoveryUntil = 0
    self._respawnRecoveryDuration = 1.1
    return self
end

function SpeedMultiplier:_getBaselineWalkSpeed(humanoid)
    local arbiterBase = self.MovementArbiter and self.MovementArbiter.GetBaseWalkSpeed and self.MovementArbiter:GetBaseWalkSpeed() or nil
    if arbiterBase and arbiterBase > 0 then
        return math.max(arbiterBase, 16)
    end

    if humanoid then
        return math.max(humanoid.WalkSpeed, 16)
    end

    return math.max(self.BaseWalkSpeed or 16, 16)
end

function SpeedMultiplier:_captureBaseSpeed(humanoid)
    self.TrackedHumanoid = humanoid
    self.BaseWalkSpeed = self:_getBaselineWalkSpeed(humanoid)
end

function SpeedMultiplier:_beginRespawnRecovery(humanoid)
    if humanoid and humanoid ~= self.TrackedHumanoid then
        self:_captureBaseSpeed(humanoid)
    end

    self._respawnRecoveryUntil = os.clock() + self._respawnRecoveryDuration
    self._fallbackWarmupUntil = 0
    self._wasEnabled = false

    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end
end

function SpeedMultiplier:_learnRespawnBase(humanoid)
    if not humanoid then
        return
    end

    local observed = math.max(humanoid.WalkSpeed or 0, 16)
    if observed > self.BaseWalkSpeed then
        self.BaseWalkSpeed = observed
    end
end

function SpeedMultiplier:_writeWalkSpeed(humanoid, value)
    if self.MovementArbiter then
        self.MovementArbiter:SetWalkExact(self._arbiterKey, value, 20)
        self._lastWalkWriteTime = os.clock()
        return
    end

    if not humanoid then
        return
    end

    if math.abs(humanoid.WalkSpeed - value) > 0.1 then
        humanoid.WalkSpeed = value
        self._lastWalkWriteTime = os.clock()
    end
end

function SpeedMultiplier:_restoreBaseSpeed(humanoid)
    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
        return
    end

    if not humanoid then
        return
    end

    local restoreSpeed = math.max(self._preEnableBaseSpeed or self.BaseWalkSpeed or 16, 16)
    self.BaseWalkSpeed = restoreSpeed
    self:_writeWalkSpeed(humanoid, restoreSpeed)
end

function SpeedMultiplier:_learnLegitBaseSpeed(humanoid)
    local multiplier = math.max(self.Options.SpeedMultiplier or 1, 1)
    local now = os.clock()
    if (now - self._lastWalkWriteTime) < 0.35 then
        return
    end

    if not self.Options.SpeedMultiplierEnabled then
        self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
        return
    end

    local observedBase = humanoid.WalkSpeed / multiplier
    if observedBase > (self.BaseWalkSpeed + 0.75) then
        self.BaseWalkSpeed = observedBase
    end
end

function SpeedMultiplier:_applyVelocityFallback(humanoid, rootPart, desiredSpeed)
    if not rootPart or desiredSpeed <= 0 then
        return false
    end

    local now = os.clock()
    local moveDirection = humanoid.MoveDirection
    if moveDirection.Magnitude <= 0.05 then
        self._fallbackWarmupUntil = 0
        return false
    end

    local planarVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
    local currentSpeedAlongMove = planarVelocity:Dot(moveDirection)
    local perpendicularPlanarVelocity = planarVelocity - (moveDirection * currentSpeedAlongMove)
    local missingSpeed = desiredSpeed - currentSpeedAlongMove
    if missingSpeed <= 0.75 then
        self._fallbackWarmupUntil = 0
        return false
    end

    if self._fallbackWarmupUntil == 0 then
        self._fallbackWarmupUntil = now + 0.2
        return false
    end

    if now < self._fallbackWarmupUntil then
        return false
    end

    local targetAlongMove = math.min(desiredSpeed, math.max(currentSpeedAlongMove, 0) + math.max(missingSpeed * 0.45, 4))
    local targetPlanarVelocity = perpendicularPlanarVelocity + (moveDirection * targetAlongMove)
    local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
    rootPart.AssemblyLinearVelocity = Vector3.new(targetPlanarVelocity.X, verticalVelocity, targetPlanarVelocity.Z)
    self._lastBoostTime = now
    return true
end

function SpeedMultiplier:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            self.Status = "Hum Missing"
            return
        end

        if hum ~= self.TrackedHumanoid then
            self:_beginRespawnRecovery(hum)
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            self:_beginRespawnRecovery(hum)
            self.Status = "Respawn Grace"
            return
        end

        if now < self._respawnRecoveryUntil then
            self:_learnRespawnBase(hum)
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self.Status = "Rebuilding Sprint"
            return
        end

        if self.Options.SpeedMultiplierEnabled and self.Options.CustomMoveSpeedEnabled then
            self.Options.CustomMoveSpeedEnabled = false
        end

        if not self.Options.SpeedMultiplierEnabled then
            self._fallbackWarmupUntil = 0
            if self._wasEnabled then
                self:_restoreBaseSpeed(hum)
            else
                self.BaseWalkSpeed = self:_getBaselineWalkSpeed(hum)
                if self.MovementArbiter then
                    self.MovementArbiter:ClearSource(self._arbiterKey)
                end
            end
            self._wasEnabled = false
            self.Status = "Disabled"
            return
        end

        if not self._wasEnabled then
            self._preEnableBaseSpeed = self:_getBaselineWalkSpeed(hum)
            self.BaseWalkSpeed = self._preEnableBaseSpeed
            self._fallbackWarmupUntil = 0
            self._wasEnabled = true
        else
            self:_learnLegitBaseSpeed(hum)
        end

        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()
        local desiredSpeed = self.BaseWalkSpeed * self.Options.SpeedMultiplier
        local boosted = false

        self:_writeWalkSpeed(hum, desiredSpeed)

        -- Some games ignore WalkSpeed entirely and drive movement from custom controllers.
        -- When that happens, nudge the root part's horizontal velocity along MoveDirection.
        if self.Options.SpeedMultiplier > 1 then
            boosted = self:_applyVelocityFallback(hum, rootPart, desiredSpeed)
        end

        if boosted then
            self.Status = "Active: Velocity Fallback"
        elseif math.abs(hum.WalkSpeed - desiredSpeed) <= 0.1 then
            self.Status = "Active: WalkSpeed"
        elseif self.MovementArbiter and (os.clock() - self._lastWalkWriteTime) < 0.35 then
            self.Status = "Active: Arbiter Sync"
        else
            self.Status = "Contested"
        end
    end)
end

function SpeedMultiplier:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end

    local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if hum and self._wasEnabled then
        self:_restoreBaseSpeed(hum)
    end
end

return SpeedMultiplier
]====],
    ["Modules/Movement/SpeedSpoof.lua"] = [====[local SpeedSpoof = {}
SpeedSpoof.__index = SpeedSpoof

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

function SpeedSpoof.new(options, localCharacter)
    local self = setmetatable({}, SpeedSpoof)
    self.Options = options
    self.LocalCharacter = localCharacter
    self._isHooked = false
    return self
end

function SpeedSpoof:Init()
    if not hookmetamethod then
        return
    end

    local hookState = getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK
    if hookState then
        hookState.Options = self.Options
        hookState.LocalCharacter = self.LocalCharacter
        self._isHooked = true
        return
    end

    hookState = {
        Options = self.Options,
        LocalCharacter = self.LocalCharacter,
    }
    getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK = hookState

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(obj, index)
        local options = hookState.Options
        local localCharacter = hookState.LocalCharacter
        if not checkcaller()
            and typeof(obj) == "Instance"
            and obj:IsA("Humanoid")
            and localCharacter
            and localCharacter:IsLocalHumanoid(obj) then
            if options and options.SpeedSpoofEnabled then
                local realValue = oldIndex(obj, index)
                if type(realValue) ~= "number" then
                    return realValue
                end

                -- Let the game finish rebuilding sprint/state controllers after respawn.
                if localCharacter.IsRespawning and localCharacter:IsRespawning() then
                    return realValue
                end

                if index == "WalkSpeed" then
                    -- Preserve legitimate sprint or game-side boosts instead of forcing 16 forever.
                    if realValue > (DEFAULT_WALK_SPEED + 0.75) then
                        return realValue
                    end
                    return DEFAULT_WALK_SPEED
                end

                if index == "JumpPower" then
                    if realValue > (DEFAULT_JUMP_POWER + 1) then
                        return realValue
                    end
                    return DEFAULT_JUMP_POWER
                end
            end
        end
        return oldIndex(obj, index)
    end))

    self._isHooked = true
end

function SpeedSpoof:Destroy()
    local hookState = getgenv and getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK
    if hookState and hookState.LocalCharacter == self.LocalCharacter then
        hookState.Options = nil
        hookState.LocalCharacter = nil
    end

    self._isHooked = false
    self.LocalCharacter = nil
end

return SpeedSpoof
]====],
    ["Modules/Movement/WaypointTeleport.lua"] = [====[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WaypointTeleport = {}
WaypointTeleport.__index = WaypointTeleport

local DEFAULT_SPEED = 150
local MIN_SPEED = 10
local MAX_SPEED = 1000
local EMPTY_OPTION = "(No waypoints yet)"

function WaypointTeleport.new(options, localCharacter)
    local self = setmetatable({}, WaypointTeleport)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self.Waypoints = {}
    self.SelectedWaypointName = nil
    self.Dropdown = nil
    self._tweenConnection = nil
    return self
end

function WaypointTeleport:_getCharacterState()
    if self.LocalCharacter and self.LocalCharacter.GetState then
        return self.LocalCharacter:GetState()
    end

    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

function WaypointTeleport:_getRoot()
    local character, _, root = self:_getCharacterState()
    return character, root
end

function WaypointTeleport:_refreshDropdown()
    if not self.Dropdown then
        return
    end

    local options = self:GetWaypointNames()
    local currentOption = self.SelectedWaypointName or options[1]

    local ok = pcall(function()
        if type(self.Dropdown.Refresh) == "function" then
            self.Dropdown:Refresh(options, true)
        elseif type(self.Dropdown.SetOptions) == "function" then
            self.Dropdown:SetOptions(options)
        else
            self.Dropdown.Options = options
        end
    end)

    if not ok and typeof(self.Dropdown) == "Instance" then
        local textLabel = self.Dropdown:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then
            textLabel.Text = tostring(currentOption)
        end
    end

    if type(self.Dropdown.Set) == "function" then
        pcall(function()
            self.Dropdown:Set(currentOption)
        end)
    end
end

function WaypointTeleport:SetDropdown(dropdown)
    self.Dropdown = dropdown
    self:_refreshDropdown()
end

function WaypointTeleport:GetWaypointNames()
    if #self.Waypoints == 0 then
        return { EMPTY_OPTION }
    end

    local names = table.create(#self.Waypoints)
    for i = 1, #self.Waypoints do
        names[i] = self.Waypoints[i].Name
    end
    return names
end

function WaypointTeleport:SetSelectedWaypoint(name)
    if not name or name == EMPTY_OPTION then
        self.SelectedWaypointName = nil
        return
    end

    self.SelectedWaypointName = name
end

function WaypointTeleport:_findWaypointByName(name)
    if not name then
        return self.Waypoints[1]
    end

    for i = 1, #self.Waypoints do
        local waypoint = self.Waypoints[i]
        if waypoint.Name == name then
            return waypoint
        end
    end

    return self.Waypoints[1]
end

function WaypointTeleport:_formatWaypointName(root)
    local pos = root.Position
    return string.format("%s | %.0f, %.0f, %.0f", os.date("%H:%M:%S"), pos.X, pos.Y, pos.Z)
end

function WaypointTeleport:SetWaypoint()
    local _, root = self:_getRoot()
    if not root then
        self.Status = "Body Missing"
        return false, "Character body is not available."
    end

    local name = self:_formatWaypointName(root)
    table.insert(self.Waypoints, 1, {
        Name = name,
        CFrame = root.CFrame,
        CreatedAt = os.clock(),
    })

    self.SelectedWaypointName = name
    self.Status = "Saved Waypoint"
    self:_refreshDropdown()
    return true, name
end

function WaypointTeleport:_stopTween(status)
    if self._tweenConnection then
        self._tweenConnection:Disconnect()
        self._tweenConnection = nil
    end

    if status then
        self.Status = status
    end
end

function WaypointTeleport:_startTween(targetCFrame)
    self:_stopTween()
    self.Status = "Tweening"

    self._tweenConnection = RunService.Heartbeat:Connect(function(dt)
        local character, root = self:_getRoot()
        if not character or not root then
            self:_stopTween("Body Missing")
            return
        end

        local current = root.CFrame
        local delta = targetCFrame.Position - current.Position
        local distance = delta.Magnitude
        if distance <= 2 then
            character:PivotTo(targetCFrame)
            self:_stopTween("Arrived")
            return
        end

        local speed = math.clamp(tonumber(self.Options.TeleportTweenSpeed) or DEFAULT_SPEED, MIN_SPEED, MAX_SPEED)
        local alpha = math.clamp((speed * dt) / math.max(distance, 0.001), 0, 1)
        character:PivotTo(current:Lerp(targetCFrame, alpha))
    end)
end

function WaypointTeleport:GotoSelectedWaypoint()
    local waypoint = self:_findWaypointByName(self.SelectedWaypointName)
    if not waypoint then
        self.Status = "No Waypoint"
        return false, "No waypoint has been saved yet."
    end

    local character, root = self:_getRoot()
    if not character or not root then
        self.Status = "Body Missing"
        return false, "Character body is not available."
    end

    local method = tostring(self.Options.TeleportMethod or "Tween")
    if method == "Teleport" then
        character:PivotTo(waypoint.CFrame)
        self.Status = "Teleported"
        self:_stopTween()
        return true, waypoint.Name
    end

    self:_startTween(waypoint.CFrame)
    return true, waypoint.Name
end

function WaypointTeleport:Destroy()
    self:_stopTween("Destroyed")
    self.Dropdown = nil
end

return WaypointTeleport
]====],
    ["Modules/NPCPrediction.lua"] = [====[--[[
    NPCPrediction.lua - NPC-Specific Prediction Profile
    ===================================================
    Ke thua PredictionCore, tuning cho Boss/NPC:
      * Kalman tieu chun (khong boost Q)
      * Ping bu 1x (NPC khong co ping rieng)
      * Lead cap cao (Boss di chuyn quang dai, thuat si bay xa)
      * Reversal penalty nhe (Boss it zigzag hon Player)
      * Khong co Jump Arc prediction
]]

return function(PredictionCore)
    local NPCPrediction = setmetatable({}, { __index = PredictionCore })
    NPCPrediction.__index = NPCPrediction
    NPCPrediction.__Legacy = true

    function NPCPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, NPCPrediction)

        -- === NPC PROFILE ===
        self.Profile = {
            KalmanQBoost      = 0,           -- Khong boost: NPC movement n dinh hon
            PingMultiplier    = 1,            -- Server-side NPC, khong can bu ping them
            ReversalPenalty   = 0.6,          -- Confidence giam 40% khi di huong
            LeadCap           = config.Prediction.MAX_LEAD_DIST,  -- 340 studs
            JumpArcEnabled    = false,        -- NPC khong jump theo kiu Player
            JumpGravity       = -196.2,
            JumpArcBlend      = 0,
        }

        return self
    end

    return NPCPrediction
end

]====],
    ["Modules/PredictionCore.lua"] = [====[--[[
    PredictionCore.lua - Base Prediction Engine (OOP)
    ===================================================
    Class co s chua toan bo thuat toan prediction:
      * Kalman Filter, Intercept Solver, Kinematics
      * Motion State Analysis, Teleport Detection
      * Brain Response, Hit Feedback, Stabilization
    
    NPC/PvP-specific tuning nam trong self.Profile
    (duoc set bi NPCPrediction hoac PvPPrediction).
    
    PERF: Khong co runtime branch cho NPC vs PvP.
    Moi gia tri duoc doc tu Profile table.
]]

local PredictionCore = {}
PredictionCore.__index = PredictionCore

PredictionCore.__Legacy = true
PredictionCore.__RuntimeReplacement = "Modules/Combat/Predictor.lua"

-- === STATIC: Kinematics Helpers (no self) ===
-- Dung PredictionCore.FuncName() thay vi self: d tranh overhead method lookup

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

-- ===================================================
-- CONSTRUCTOR
-- ===================================================

function PredictionCore.new(config, npcTracker)
    local self = setmetatable({}, PredictionCore)
    self.Config = config
    self.Options = config.Options
    self.C = config.Prediction
    self.NPCTracker = npcTracker

    -- Ping cache
    self._cachedPing = 50
    self._lastPingCheck = 0

    -- Profile: se bi override bi NPCPrediction / PvPPrediction
    self.Profile = {
        KalmanQBoost = 0,
        PingMultiplier = 1,
        ReversalPenalty = 0.6,
        LeadCap = config.Prediction.MAX_LEAD_DIST,
        JumpArcEnabled = false,
        JumpGravity = -196.2,
        JumpArcBlend = 0.7,
    }

    -- Reusable context table (tranh tao table moi moi frame)
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

-- ===================================================
-- UTILITY METHODS
-- ===================================================

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

-- === Alpha Calculators (inlined math, no table lookups) ===

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

-- === Motion Shock ===

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

-- === Smart Projectile Speed ===

function PredictionCore:SmartProjectileSpeed(distance, targetSpeed, motionShock)
    local C = self.C
    local dA = self:DistanceAlpha(distance)
    local edA = self:ExtremeDistAlpha(distance)
    local sA = self:SpeedAlpha(targetSpeed)

    local ps = C.SMART_PROJECTILE_SPEED_BASE + (dA * 220) + (edA * 380) - (sA * 650) - (motionShock * 700)
    return math.clamp(ps, C.SMART_PROJECTILE_SPEED_MIN, C.SMART_PROJECTILE_SPEED_MAX)
end

-- === Intercept Solver ===

function PredictionCore:SolveInterceptTime(shooterPos, targetPos, targetVel, projSpeed)
    if projSpeed <= 0 then return nil end
    local r = targetPos - shooterPos
    local v = targetVel
    local a = v:Dot(v) - (projSpeed * projSpeed)
    local b = 2 * r:Dot(v)
    local c = r:Dot(r)
    if c <= 1e-6 then return 0 end
    if math.abs(a) < 1e-5 then -- Tranh chia cho so gan bang 0
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

-- === Jerk / Motion State ===

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

-- === Teleport Detection ===

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

-- === Brain Response ===

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

-- === Hit Feedback ===

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

-- === Close Orbit ===

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

-- === Base Position ===

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

-- === Smooth Aim Velocity ===

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
        -- Alpha thap (0.12) cho Silent Aim: uu tien do muot hon do nhay
        local a = 1 - math.pow(1 - 0.12, math.max(dt * 60, 1))
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

-- === Entry Motion Velocity ===

function PredictionCore:EntryMotionVelocity(entry, part)
    if entry then
        if entry.SmoothedAimVelocity and entry.SmoothedAimVelocity.Magnitude > 0.01 then return entry.SmoothedAimVelocity end
        if entry.LastFilteredVelocity and entry.LastFilteredVelocity.Magnitude > 0.01 then return entry.LastFilteredVelocity end
        if entry.RealVelocity and entry.RealVelocity.Magnitude > 0.01 then return entry.RealVelocity end
    end
    if part then return part.AssemblyLinearVelocity end
    return Vector3.zero
end

-- ===================================================
-- CORE PREDICTION
-- ===================================================

function PredictionCore:PredictTargetPosition(origin, part, entry)
    local C = self.C
    local P = self.Profile
    local basePos = part.Position
    local att = part:FindFirstChild("RootRigAttachment") or part:FindFirstChild("WaistCenterAttachment") or part:FindFirstChild("NeckAttachment")
    if att and att:IsA("Attachment") then basePos = att.WorldPosition end

    if not self.Options.PredictionEnabled then
        local totalOffset = self.Options.AimOffset
        -- Cong them AimOffset tu BossProfile
        if entry and entry.BossProfile then
            totalOffset = totalOffset + (entry.BossProfile.AimOffset or 0)
        end
        if totalOffset ~= 0 then
            basePos = basePos + Vector3.new(0, totalOffset, 0)
        end
        return basePos
    end

    local now = os.clock()

    -- PERIODIC REFRESH: Reset partial state moi 15 giay d tranh drift
    if not entry._lastRefreshTime then entry._lastRefreshTime = now end
    if (now - entry._lastRefreshTime) >= 15 then
        entry._lastRefreshTime = now
        entry.KalmanP = math.clamp(entry.KalmanP, 0.5, 2) -- Normalize KalmanP
        entry.Confidence = math.max(entry.Confidence, 0.7)  -- Phuc hoi confidence
        if entry.Acceleration and entry.Acceleration.Magnitude > 200 then
            entry.Acceleration = entry.Acceleration.Unit * 100 -- Giam acceleration tich luy
        end
    end

    -- BuoC 1: Raw Velocity
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
        dt = math.max(now - entry.LastTime, 0.001) -- Chot chan dt khong duoc bang 0
        if dt >= 0.015 then
            local newVel = (basePos - entry.LastPos) / dt
            -- Chot chan van toc qua ao (do teleport hoac lag cuc nang)
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

    -- BuoC 2: Kalman Filter (Profile-tuned Q boost)
    local velErr = (rawVel - entry.KalmanV).Magnitude
    local q = 0.15 + math.clamp(velErr / 28, 0, 2.0) + P.KalmanQBoost
    local r = 0.3
    entry.KalmanP = math.clamp(entry.KalmanP + q, 0.01, 10) -- CLAMP: tranh drift vo han
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

    -- BuoC 3: Confidence (voi recovery nhanh hon cho boss fights dai)
    if entry.LastExpectedPos then
        local errDist = (basePos - entry.LastExpectedPos).Magnitude
        local errPenalty = math.clamp(errDist / 8, 0, 0.3)
        -- Recovery rate tang len 0.15 (tu 0.1) d confidence khong bi stuck  0.4
        local recovery = 0.15
        entry.Confidence = math.clamp(entry.Confidence - errPenalty + recovery, 0.4, 1)
    else
        entry.Confidence = 1
    end

    -- BuoC 4: Acceleration (voi magnitude clamp tranh drift)
    if entry.LastFilteredVelocity then
        local rawAcc = (filtVel - entry.LastFilteredVelocity) / dt
        -- Clamp acceleration magnitude d tranh tich luy sai so
        if rawAcc.Magnitude > 500 then rawAcc = rawAcc.Unit * 500 end
        local accSmooth = (rawAcc - entry.Acceleration).Magnitude > 80 and 0.8 or 0.2
        entry.Acceleration = entry.Acceleration:Lerp(rawAcc, accSmooth)
        -- Clamp ket qua cuoi
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
        rawVel = Vector3.zero
        entry.Acceleration = Vector3.zero
        speed = 0
    end

    local jerkA = self:JerkAlpha(entry, entry.Acceleration, dt)
    local motState, brakeA, fwdDecel = self:UpdateMotionState(entry, filtVel, entry.Acceleration, jerkA)
    local tpAlpha = self:UpdateTeleportState(entry, basePos)
    if tpAlpha > 0 then
        filtVel = filtVel:Lerp(rawVel, 0.18 + (tpAlpha * 0.5))
        entry.KalmanV = filtVel
        entry.Confidence = math.max(entry.Confidence, 0.58 + (tpAlpha * 0.35))
    end

    -- BuoC 5: Latency Compensation
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

-- ===================================================
-- STRAFE ENHANCED PREDICTION
-- ===================================================

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

-- ===================================================
-- SELECTION TARGET POSITION (Lightweight for scanning)
-- ===================================================

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

-- ===================================================
-- STABILIZE TARGET POSITION
-- ===================================================

function PredictionCore:StabilizeTargetPosition(entry, part, rawPos, deltaTime)
    local C = self.C
    if not entry or not part or not rawPos then return rawPos end

    if self.Options.AssistMode == "Silent Aim" then
        local cur = entry.StabilizedTargetPos
        if not cur then entry.StabilizedTargetPos = rawPos; return rawPos end
        local d = rawPos - cur
        local dm = d.Magnitude

        -- Lay tham so tu BossProfile (neu co)
        local bpDeadzone = 1.2
        local bpAlpha = 0.08
        local bpSnap = 50
        if entry.BossProfile then
            bpDeadzone = entry.BossProfile.Deadzone or bpDeadzone
            bpAlpha = entry.BossProfile.StabilizeAlpha or bpAlpha
        end

        if dm > bpSnap then entry.StabilizedTargetPos = rawPos; return rawPos end
        if dm < bpDeadzone then return cur end
        local a = 1 - math.pow(1 - bpAlpha, math.max((deltaTime or (1/60)) * 60, 1))
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

]====],
    ["Modules/PvPPrediction.lua"] = [====[--[[
    PvPPrediction.lua - PvP-Specific Prediction Profile
    ===================================================
    Ke thua PredictionCore, tuning cho Player thuc:
      * Kalman Q boost +0.3 (nhay hon cho human input)
      * Ping bu 2x (player co latency rieng + reconciliation)
      * Lead cap thap (player di chuyn ngan, di huong nhieu)
      * Zigzag dampen manh (confidence giam 45% khi dao chieu)
      * Jump Arc prediction (du doan cung nhay parabola)
]]

return function(PredictionCore)
    local PvPPrediction = setmetatable({}, { __index = PredictionCore })
    PvPPrediction.__index = PvPPrediction
    PvPPrediction.__Legacy = true

    function PvPPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, PvPPrediction)

        -- === PVP PROFILE ===
        self.Profile = {
            KalmanQBoost      = 0.3,          -- Kalman nhay hon cho input nguoi that
            PingMultiplier    = 2.0,          -- Bu ping gap doi (player ping + reconciliation)
            ReversalPenalty   = 0.55,         -- Zigzag penalty manh hon
            LeadCap           = 180,          -- Lead cap thap (player di chuyn ngan)
            JumpArcEnabled    = true,         -- Du doan cung nhay parabola
            JumpGravity       = -196.2,       -- Gia toc trong luc chun Roblox
            JumpArcBlend      = 0.7,          -- 70% ap dung du doan cung nhay
        }

        return self
    end

    return PvPPrediction
end

]====],
    ["Modules/Utils/BossClassifier.lua"] = [====[--[[
    BossClassifier.lua - Auto Boss Type Detection
    ===================================================
    Phan loai Boss thanh 3 loai dua tren kich thuoc model:
      * "humanoid"     : Boss dang nguoi chun (R6/R15)
      * "humanoid_mini": Boss nho hon nguoi thuong
      * "large"        : Boss khng lo / khong humanoid
    
    Moi loai co bo aim parameters rieng:
      * AimOffset (Y) - dim ngam toi uu
      * Deadzone      - vung bo qua rung
      * LeadScale     - he so lead (nho = it lead)
      * TargetPart    - phan than uu tien aim
]]

local BossClassifier = {}

-- === Nguong d phan loai ===
local MINI_HEIGHT_MAX = 3.5    -- Model duoi 3.5 studs  mini
local STANDARD_HEIGHT_MAX = 8  -- Model 3.5-8 studs  humanoid chun
-- Tren 8 studs  large boss

-- === Profiles cho tung loai Boss ===
BossClassifier.Profiles = {
    humanoid = {
        AimOffset = 0,          -- Ngam chinh xac root/torso
        Deadzone = 1.2,         -- Deadzone chun
        LeadScale = 1.0,        -- Lead binh thuong
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.08,  -- Smoothing chun
    },
    humanoid_mini = {
        AimOffset = -0.5,       -- Ngam thap hon (hitbox nho, center thap)
        Deadzone = 0.5,         -- Deadzone nho (hitbox nho can chinh xac hon)
        LeadScale = 0.7,        -- Lead it hon (mini boss thuong di chuyn nhanh, hitbox nho)
        PreferredPart = "Head", -- Head thuong  trung tam mini model
        StabilizeAlpha = 0.06,  -- Muot hon (tranh aim truot khoi hitbox nho)
    },
    large = {
        AimOffset = 2,          -- Ngam cao hon (boss to, center cao)
        Deadzone = 2.5,         -- Deadzone lon (hitbox lon, khong can aim chinh xac)
        LeadScale = 1.2,        -- Lead nhieu hon (boss to di chuyn quang dai)
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.12,  -- it smooth (hitbox lon, tha thu lech nhieu hon)
    },
}

-- === do chieu cao model ===
function BossClassifier.MeasureModelHeight(model)
    if not model or not model:IsA("Model") then return 5 end -- Mac dinh 5 studs
    
    local ok, result = pcall(function()
        -- Dung GetBoundingBox neu co
        local _, size = model:GetBoundingBox()
        return size.Y
    end)
    
    if ok and result then
        return result
    end
    
    -- Fallback: do tu parts
    local minY, maxY = math.huge, -math.huge
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local pos = part.Position
            local halfSize = part.Size.Y / 2
            minY = math.min(minY, pos.Y - halfSize)
            maxY = math.max(maxY, pos.Y + halfSize)
        end
    end
    
    if minY < maxY then
        return maxY - minY
    end
    return 5
end

-- === Phan loai Boss ===
function BossClassifier.Classify(model)
    local height = BossClassifier.MeasureModelHeight(model)
    
    local hasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil
    
    if hasHumanoid then
        if height <= MINI_HEIGHT_MAX then
            return "humanoid_mini", height
        elseif height <= STANDARD_HEIGHT_MAX then
            return "humanoid", height
        else
            return "large", height
        end
    else
        -- Khong co Humanoid  luon coi la large
        return "large", height
    end
end

-- === Lay profile theo loai ===
function BossClassifier.GetProfile(bossType)
    return BossClassifier.Profiles[bossType] or BossClassifier.Profiles.humanoid
end

return BossClassifier

]====],
    ["Modules/Utils/BossDetector.lua"] = [====[--[[
    BossDetector.lua - OOP Target Classification Class
    Identifies bosses across humanoid and non-humanoid enemy types.
]]

local BossDetector = {}
BossDetector.__index = BossDetector

local NAME_HINTS = {
    "boss", "king", "queen", "lord", "orb", "sphere", "core",
}

local HEALTH_HINTS = {
    "Health", "HP", "HitPoints", "BossHealth", "EnemyHealth", "HealthValue",
}

local function containsBossHint(text)
    local lowered = string.lower(tostring(text or ""))
    for _, hint in ipairs(NAME_HINTS) do
        if lowered:find(hint, 1, true) then
            return true
        end
    end
    return false
end

local function getModelBounds(model)
    if not model or not model:IsA("Model") then
        return Vector3.new(0, 0, 0), 0
    end

    local ok, _, size = pcall(model.GetBoundingBox, model)
    if ok and typeof(size) == "Vector3" then
        return size, size.X * size.Y * size.Z
    end

    local minPos = Vector3.new(math.huge, math.huge, math.huge)
    local maxPos = Vector3.new(-math.huge, -math.huge, -math.huge)
    local foundPart = false

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            foundPart = true
            local half = descendant.Size * 0.5
            local pos = descendant.Position
            minPos = Vector3.new(
                math.min(minPos.X, pos.X - half.X),
                math.min(minPos.Y, pos.Y - half.Y),
                math.min(minPos.Z, pos.Z - half.Z)
            )
            maxPos = Vector3.new(
                math.max(maxPos.X, pos.X + half.X),
                math.max(maxPos.Y, pos.Y + half.Y),
                math.max(maxPos.Z, pos.Z + half.Z)
            )
        end
    end

    if not foundPart then
        return Vector3.new(0, 0, 0), 0
    end

    local size = maxPos - minPos
    return size, size.X * size.Y * size.Z
end

local function getLargestPart(model)
    local bestPart = nil
    local bestVolume = -1

    if not model then
        return nil
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
            if volume > bestVolume then
                bestPart = descendant
                bestVolume = volume
            end
        end
    end

    return bestPart
end

local function getPrimaryPart(model)
    if not model then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or getLargestPart(model)
end

local function readHealthLikeValue(model, humanoid)
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth
    end

    if not model then
        return nil, nil
    end

    for _, hint in ipairs(HEALTH_HINTS) do
        local child = model:FindFirstChild(hint, true)
        if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
            local value = tonumber(child.Value)
            if value then
                return value, value
            end
        end
    end

    local attrHealth = tonumber(model:GetAttribute("Health")) or tonumber(model:GetAttribute("HP"))
    local attrMaxHealth = tonumber(model:GetAttribute("MaxHealth")) or tonumber(model:GetAttribute("MaxHP"))
    if attrHealth or attrMaxHealth then
        return attrHealth or attrMaxHealth, attrMaxHealth or attrHealth
    end

    return nil, nil
end

function BossDetector.new()
    local self = setmetatable({}, BossDetector)
    self.CheckInterval = 10
    self._cache = setmetatable({}, { __mode = "k" })
    self._destroyed = false
    return self
end

function BossDetector:Init()
    self._destroyed = false
end

function BossDetector:IsBoss(model, humanoid)
    if self._destroyed then
        return false
    end

    if not model or not model:IsA("Model") then
        return false
    end

    local now = os.clock()
    local cached = self._cache[model]
    if cached and cached.ExpiresAt and cached.ExpiresAt > now then
        return cached.Value == true
    end

    local primary = getPrimaryPart(model)
    local size, boundsScale = getModelBounds(model)
    local health, maxHealth = readHealthLikeValue(model, humanoid or model:FindFirstChildOfClass("Humanoid"))
    local nameHint = containsBossHint(model.Name)
    local displayHint = humanoid and containsBossHint(humanoid.DisplayName)
    local primaryIsBall = primary and primary:IsA("Part") and primary.Shape == Enum.PartType.Ball
    local isBoss = false

    if displayHint or nameHint then
        isBoss = true
    elseif maxHealth and maxHealth > 500 then
        isBoss = true
    elseif boundsScale > 70 then
        isBoss = true
    elseif primaryIsBall then
        local maxAxis = math.max(size.X, size.Y, size.Z, primary.Size.X, primary.Size.Y, primary.Size.Z)
        local minAxis = math.min(primary.Size.X, primary.Size.Y, primary.Size.Z)

        if maxAxis >= 5 then
            isBoss = true
        elseif minAxis >= 3.5 and (health or 0) > 150 then
            isBoss = true
        end
    end

    self._cache[model] = {
        Value = isBoss,
        ExpiresAt = now + math.max(self.CheckInterval or 10, 1),
    }

    return isBoss
end

function BossDetector:Destroy()
    self._destroyed = true
    table.clear(self._cache)
end

return BossDetector
]====],
    ["Modules/Utils/CheckGame.lua"] = [====[--[[
    CheckGame.lua - Place ID Validation
    Job: Ensures the script only executes in the intended game environment.
    Target: Star Glitcher ~ Revitalized (ID: 11380216916)
]]

local TARGET_PLACE_ID = 11380216916
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function Check()
    if game.PlaceId ~= TARGET_PLACE_ID then
        local errorMsg = " Access Denied: This script only supports Star Glitcher! (Place ID: " .. tostring(TARGET_PLACE_ID) .. ")"
        
        -- Attempt to notify via executor if possible
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title = "Wrong Game Detected",
                Content = errorMsg,
                Duration = 10,
                Image = 4483362458,
            })
        end
        
        warn(errorMsg)
        -- Kick the player to prevent unexpected behavior in wrong games
        LocalPlayer:Kick(errorMsg)
        return false
    end
    return true
end

return Check()

]====],
    ["Modules/Utils/DataPruner.lua"] = [====[local DataPruner = {}
DataPruner.__index = DataPruner

function DataPruner.new(taskScheduler, tracker, predictor)
    local self = setmetatable({}, DataPruner)
    self.TaskScheduler = taskScheduler
    self.Tracker = tracker
    self.Predictor = predictor
    self.Interval = 4
    self._alive = false
    return self
end

function DataPruner:Init()
    if self._alive then
        return
    end

    self._alive = true
    self:_queue()
end

function DataPruner:_run()
    local now = os.clock()

    if self.Tracker and self.Tracker.Prune then
        self.Tracker:Prune(now)
    end

    if self.Predictor and self.Predictor.Prune then
        self.Predictor:Prune(now)
    end
end

function DataPruner:_queue()
    if not self._alive then
        return
    end

    if not self.TaskScheduler then
        self:_run()
        task.delay(self.Interval, function()
            self:_queue()
        end)
        return
    end

    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if not selfRef._alive then
            return
        end

        selfRef:_run()
        task.delay(selfRef.Interval, function()
            selfRef:_queue()
        end)
    end, "__STAR_GLITCHER_DATA_PRUNER")
end

function DataPruner:Destroy()
    self._alive = false
end

return DataPruner
]====],
    ["Modules/Utils/GarbageCollector.lua"] = [====[--[[
    GarbageCollector.lua - Memory & Workspace Optimization v1.0
    Job: Proactive cleanup of visual debris, effects, and orphaned instances.
    Analogy: The Lymphatic System (Cleaning up cellular debris).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local GarbageCollector = {}
GarbageCollector.__index = GarbageCollector

function GarbageCollector.new(options, resourceManager)
    local self = setmetatable({}, GarbageCollector)
    self.Options = options
    self.ResourceManager = resourceManager
    self.Connection = nil
    self._lastClean = 0
    self._cleanInterval = 60 -- Default to every 60 seconds
    self._queued = {}
    self._queuedMap = setmetatable({}, { __mode = "k" })
    self._queueSize = 0
    self._scanIndex = 1
    self._scanList = nil
    self._scanBatchSize = 30
    self._destroyBudget = 4
    self._collectStepSize = 24
    self._manualBoostUntil = 0
    self._manualDrainCap = 80
    self._frameBudget = 0.0008
    self.Status = "Idle"
    return self
end

local DEBRIS_TAGS = {
    "Debris", "Effect", "Projectile", "Shell", "Bullet", 
    "Particle", "Emitter", "Orb", "Trail", "Beam", "Visual"
}

function GarbageCollector:_getPlayerPosition()
    local char = LocalPlayer and LocalPlayer.Character
    local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    return root and root.Position or nil
end

function GarbageCollector:_isDebrisCandidate(instance, playerPos)
    if not instance or not instance.Parent then
        return false
    end

    if not (instance:IsA("BasePart") or instance:IsA("Model") or instance:IsA("Folder")) then
        return false
    end

    local name = instance.Name:lower()
    local matched = false
    for _, tag in ipairs(DEBRIS_TAGS) do
        if name:find(tag:lower(), 1, true) then
            matched = true
            break
        end
    end
    if not matched or instance:FindFirstChildOfClass("Humanoid") then
        return false
    end

    if not playerPos then
        return true
    end

    local ok, position = pcall(function()
        return instance:GetPivot().Position
    end)
    if not ok then
        return false
    end

    return (position - playerPos).Magnitude > 300
end

function GarbageCollector:_queueInstance(instance)
    if self._queuedMap[instance] then
        return false
    end

    self._queuedMap[instance] = true
    self._queueSize = self._queueSize + 1
    self._queued[self._queueSize] = instance
    return true
end

function GarbageCollector:_beginScan()
    self._scanList = Workspace:GetChildren()
    self._scanIndex = 1
    self.Status = "Scanning Debris"
end

function GarbageCollector:_processScan(batchSize)
    local scanList = self._scanList
    if not scanList then
        return 0, true
    end

    local playerPos = self:_getPlayerPosition()
    local queuedCount = 0
    local endIndex = math.min(self._scanIndex + batchSize - 1, #scanList)

    for i = self._scanIndex, endIndex do
        local instance = scanList[i]
        if self:_isDebrisCandidate(instance, playerPos) and self:_queueInstance(instance) then
            queuedCount = queuedCount + 1
        end
    end

    self._scanIndex = endIndex + 1
    local done = self._scanIndex > #scanList
    if done then
        self._scanList = nil
        self._scanIndex = 1
    end

    return queuedCount, done
end

function GarbageCollector:_processFullScan(batchSize)
    local totalQueued = 0
    local scanBatchSize = math.max(batchSize or self._scanBatchSize, 1)
    local startTime = os.clock()

    while self._scanList do
        local queuedCount = 0
        local done = false
        queuedCount, done = self:_processScan(scanBatchSize)
        totalQueued = totalQueued + (queuedCount or 0)
        
        if done then
            break
        end

        -- Time-slicing: yield to avoid freezing the main thread
        if (os.clock() - startTime) >= 0.0022 then
            task.wait()
            startTime = os.clock() -- Reset timer after yield
        end
    end

    return totalQueued
end

function GarbageCollector:_drainQueue(destroyBudget, gcStepSize, ignoreFrameBudget)
    local destroyed = 0
    local deferred = 0
    local processed = 0
    local startTime = os.clock()

    while self._queueSize > 0 and (destroyBudget == nil or processed < destroyBudget) do
        if not ignoreFrameBudget and (os.clock() - startTime) >= self._frameBudget then
            break
        end

        local instance = self._queued[self._queueSize]
        self._queued[self._queueSize] = nil
        self._queueSize = self._queueSize - 1
        processed = processed + 1

        self._queuedMap[instance] = nil
        if instance and instance.Parent then
            if self.ResourceManager then
                self.ResourceManager:DeferDestroy(instance)
                deferred = deferred + 1
            else
                pcall(function()
                    instance:Destroy()
                end)
                destroyed = destroyed + 1
            end
        end
    end

    if destroyed > 0 and not self.ResourceManager then
        -- collectgarbage("step", gcStepSize) -- Restricted in some environments
    end

    return destroyed, deferred, processed
end

function GarbageCollector:_stepCleanup()
    local now = os.clock()
    local manualBoost = now < self._manualBoostUntil
    local localPressure = self._queueSize
    local deferredPressure = 0
    if self.ResourceManager and self.ResourceManager.GetPendingCount then
        deferredPressure = self.ResourceManager:GetPendingCount()
    end

    local scanMultiplier = 1
    local destroyMultiplier = 1
    if localPressure >= 1000 then
        scanMultiplier = 1.0
        destroyMultiplier = 6.0
    elseif localPressure >= 500 then
        scanMultiplier = 1.5
        destroyMultiplier = 3.0
    elseif localPressure >= 200 then
        scanMultiplier = 1.7
        destroyMultiplier = 1.5
    elseif localPressure >= 80 then
        scanMultiplier = 1.3
        destroyMultiplier = 1.2
    end

    local scanBatchSize = (manualBoost and math.ceil(self._scanBatchSize * 1.35) or self._scanBatchSize)
    scanBatchSize = math.max(scanBatchSize, math.ceil(scanBatchSize * scanMultiplier))

    local destroyBudget = (manualBoost and math.ceil(self._destroyBudget * 1.5) or self._destroyBudget)
    destroyBudget = math.max(destroyBudget, math.ceil(destroyBudget * destroyMultiplier))
    local gcStepSize = manualBoost and math.ceil(self._collectStepSize * 1.5) or self._collectStepSize

    if deferredPressure >= 400 then
        destroyBudget = math.max(1, math.floor(destroyBudget * 0.25))
    elseif deferredPressure >= 150 then
        destroyBudget = math.max(1, math.floor(destroyBudget * 0.45))
    elseif deferredPressure >= 50 then
        destroyBudget = math.max(1, math.floor(destroyBudget * 0.7))
    end

    if not self._scanList and self._queueSize == 0 then
        if now - self._lastClean < self._cleanInterval then
            self.Status = "Idle"
            return
        end
        self._lastClean = now
        self:_beginScan()
    end

    local queuedCount = 0
    local scanDone = true
    if self._scanList then
        if self._queueSize < 1500 then
            queuedCount, scanDone = self:_processScan(scanBatchSize)
        else
            scanDone = false
        end
    end

    local destroyed, deferred = self:_drainQueue(destroyBudget, gcStepSize, false)

    if self._scanList then
        self.Status = string.format("Scanning (%d queued)", self._queueSize)
    elseif self._queueSize > 0 then
        self.Status = string.format("Cleaning (%d left)", self._queueSize)
    elseif destroyed > 0 or deferred > 0 or queuedCount > 0 or not scanDone then
        self.Status = "Cleanup Settled"
    else
        self.Status = "Idle"
    end
end

function GarbageCollector:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.AutoCleanEnabled then return end

        self:_stepCleanup()
    end)
end

function GarbageCollector:Clean()
    self._manualBoostUntil = os.clock() + 4
    if self.ResourceManager then
        self.ResourceManager:Boost(2.5)
    end
    if not self._scanList then
        self._lastClean = 0
        self:_beginScan()
    end

    local found = 0
    local destroyed = 0
    local deferred = 0
    if self._scanList then
        found = self:_processFullScan(math.max(self._scanBatchSize * 8, 200))
    end
    local immediateDrain = math.min(self._queueSize, self._manualDrainCap)
    destroyed, deferred = self:_drainQueue(immediateDrain, self._collectStepSize, true)

    if self.ResourceManager and self.ResourceManager:GetPendingCount() > 0 then
        self.Status = string.format(
            "Smart Cleanup (%d local / %d deferred)",
            self._queueSize,
            self.ResourceManager:GetPendingCount()
        )
    else
        self.Status = self._queueSize > 0 and string.format("Cleaning (%d left)", self._queueSize) or "Cleanup Settled"
    end
    return destroyed, found, deferred, self._queueSize
end

function GarbageCollector:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    for i = 1, self._queueSize do
        local instance = self._queued[i]
        self._queuedMap[instance] = nil
    end
end

return GarbageCollector

]====],
    ["Modules/Utils/Input.lua"] = [====[--[[
    Input.lua - OOP User Interaction Class
    Handles mouseholding and assist availability checks.
]]

local UserInputService = game:GetService("UserInputService")

local Input = {}
Input.__index = Input

function Input.new(config)
    local self = setmetatable({}, Input)
    self.Options = config.Options
    self.Holding = false
    self._lastShot = 0
    self._connections = {}
    return self
end

function Input:Init()
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Holding = true
        end
    end))
    
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Holding = false
        end
    end))
    
    -- Hitmarker tracking (Register a shot)
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._lastShot = os.clock()
        end
    end))
end

function Input:ShouldAssist()
    if self.Options.HoldMouse2ToAssist then
        return self.Holding
    end
    return true -- Mode is always active otherwise
end

function Input:WasShotRecently(seconds)
    return (os.clock() - self._lastShot) < (seconds or 1.5)
end

function Input:Destroy()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return Input

]====],
    ["Modules/Utils/InputHandler.lua"] = [====[--[[
    InputHandler.lua - Input Management Class
    Quan ly trang thai chuot/ban phim va logic shouldAssist().
]]

local UserInputService = game:GetService("UserInputService")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler.new(config)
    local self = setmetatable({}, InputHandler)
    self.Config = config
    self.Options = config.Options
    self.RightMouseHeld = false
    self.LastShotTick = 0
    self._connections = {}
    return self
end

function InputHandler:Init()
    local conn1 = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed then
            local inputType = input.UserInputType
            if inputType == Enum.UserInputType.MouseButton1
                or inputType == Enum.UserInputType.MouseButton2
                or inputType == Enum.UserInputType.Keyboard then
                self.LastShotTick = os.clock()
            end
        end

        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.RightMouseHeld = true
        end
    end)

    local conn2 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.RightMouseHeld = false
        end
    end)

    table.insert(self._connections, conn1)
    table.insert(self._connections, conn2)
end

function InputHandler:ShouldAssist()
    if self.Options.AssistMode == "Off" then
        return false
    end
    if self.Options.HoldMouse2ToAssist and not self.RightMouseHeld then
        return false
    end
    return true
end

function InputHandler:WasShotRecently(windowSeconds)
    return (os.clock() - self.LastShotTick) <= (windowSeconds or 1.5)
end

function InputHandler:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    table.clear(self._connections)
end

return InputHandler

]====],
    ["Modules/Utils/LocalCharacter.lua"] = [====[local Players = game:GetService("Players")
local clock = os.clock

local LocalCharacter = {}
LocalCharacter.__index = LocalCharacter

function LocalCharacter.new(taskScheduler)
    local self = setmetatable({}, LocalCharacter)
    self.Player = Players.LocalPlayer
    self.TaskScheduler = taskScheduler
    self.Character = nil
    self.Humanoid = nil
    self.RootPart = nil
    self.PlayerGui = nil
    self.LastSpawnTime = 0
    self.RespawnGracePeriod = 1.25
    self._connections = {}
    self._schedulerAlive = false
    return self
end

function LocalCharacter:_refresh(character)
    self.Character = character
    self.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    self.RootPart = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChildWhichIsA("BasePart")
    ) or nil
    self.PlayerGui = self.Player and self.Player:FindFirstChildOfClass("PlayerGui") or nil
end

function LocalCharacter:_queueRefresh()
    if not self.TaskScheduler or not self._schedulerAlive then
        return
    end

    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if not selfRef._schedulerAlive then
            return
        end

        local currentCharacter = selfRef.Player and selfRef.Player.Character or nil
        selfRef:_refresh(currentCharacter)

        task.delay(0.25, function()
            if selfRef._schedulerAlive then
                selfRef:_queueRefresh()
            end
        end)
    end, "__STAR_GLITCHER_LOCAL_CHARACTER_REFRESH")
end

function LocalCharacter:Init()
    self:_refresh(self.Player and self.Player.Character or nil)
    self._schedulerAlive = true

    if self.Character then
        self.LastSpawnTime = clock()
    end

    if not self.Player then
        return
    end

    table.insert(self._connections, self.Player.CharacterAdded:Connect(function(character)
        self.LastSpawnTime = clock()
        self:_refresh(character)
    end))

    table.insert(self._connections, self.Player.CharacterRemoving:Connect(function(character)
        if self.Character == character then
            self:_refresh(nil)
        end
    end))

    self:_queueRefresh()
end

function LocalCharacter:GetCharacter()
    local character = self.Player and self.Player.Character or nil
    if character ~= self.Character then
        self:_refresh(character)
        if character then
            self.LastSpawnTime = clock()
        end
    end
    return self.Character
end

function LocalCharacter:GetHumanoid()
    local character = self:GetCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    if humanoid ~= self.Humanoid then
        self.Humanoid = humanoid
    end
    return self.Humanoid
end

function LocalCharacter:GetRootPart()
    local character = self:GetCharacter()
    local rootPart = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChildWhichIsA("BasePart")
    ) or nil
    if rootPart ~= self.RootPart then
        self.RootPart = rootPart
    end
    return self.RootPart
end

function LocalCharacter:GetState()
    return self:GetCharacter(), self:GetHumanoid(), self:GetRootPart()
end

function LocalCharacter:IsLocalHumanoid(instance)
    local humanoid = self:GetHumanoid()
    return humanoid ~= nil and instance == humanoid
end

function LocalCharacter:IsRespawning()
    if not self.Character then
        return false
    end
    return (clock() - (self.LastSpawnTime or 0)) < self.RespawnGracePeriod
end

function LocalCharacter:Destroy()
    self._schedulerAlive = false

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return LocalCharacter
]====],
    ["Modules/Utils/Math/Kalman.lua"] = [====[--[[
    KalmanFilter.lua - OOP Noise Reduction Class
    A scientific implementation of 1D Kalman Filter for linear motion smoothing.
]]

local Kalman = {}
Kalman.__index = Kalman

local DEFAULT_DT = 1 / 60
local MIN_DT = 1 / 240
local MAX_DT = 0.25

function Kalman.new()
    local self = setmetatable({}, Kalman)
    self.P = 1.2 -- Estimation error covariance
    self.Q = 0.08 -- Process noise covariance
    self.R = 0.45 -- Measurement noise covariance
    self.Value = nil
    self.Trend = Vector3.zero
    self.Velocity = Vector3.zero
    return self
end

function Kalman:Reset(seed)
    self.P = 1.2
    self.Value = seed
    self.Trend = Vector3.zero
    self.Velocity = seed or Vector3.zero
end

function Kalman:Update(measurement, dt, context)
    if measurement == nil then
        return self.Value or Vector3.zero
    end

    dt = math.clamp(dt or DEFAULT_DT, MIN_DT, MAX_DT)

    if not self.Value then
        self:Reset(measurement)
        return measurement
    end

    if context and context.IsTeleport then
        self:Reset(measurement)
        return measurement
    end

    local confidence = math.clamp((context and context.Confidence) or 1, 0.05, 1)
    local shock = math.max((context and context.Shock) or 0, 0)
    local shockAlpha = math.clamp(shock / 180, 0, 1)
    local dtScale = dt / DEFAULT_DT

    -- Predict next velocity using the currently estimated trend before blending.
    local predicted = self.Value + (self.Trend * dt)
    local innovation = measurement - predicted

    local adaptiveQ = self.Q * (0.8 + dtScale + (shockAlpha * 2.6))
    local adaptiveR = self.R * (1.25 - (confidence * 0.55))

    self.P = math.clamp(self.P + adaptiveQ, 0.01, 12)

    local gain = self.P / (self.P + adaptiveR)
    self.Value = predicted + (innovation * gain)

    local trendGain = math.clamp((0.10 + (gain * 0.55) + (shockAlpha * 0.2)) / dtScale, 0.08, 0.95)
    self.Trend = self.Trend + ((innovation / dt) * trendGain)

    if shockAlpha < 0.2 then
        local damping = math.clamp((0.12 + ((1 - confidence) * 0.18)) * dtScale * 0.35, 0, 0.35)
        self.Trend = self.Trend * (1 - damping)
    end

    self.P = math.clamp((1 - gain) * self.P, 0.01, 12)
    self.Velocity = self.Value

    return self.Value
end

return Kalman

]====],
    ["Modules/Utils/NPCTracker.lua"] = [====[--[[
    NPCTracker.lua - Neural Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
    Fixes: Non-humanoid boss support and performance bottlenecks.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local NPCTracker = {}
NPCTracker.__index = NPCTracker

function NPCTracker.new(config, detector, taskScheduler)
    local self = setmetatable({}, NPCTracker)
    self.Options = config.Options
    self.Blacklist = config.Blacklist or {"statue", "tuong", "monument", "altar", "dummy", "board", "spawn", "shop", "gui", "display", "map", "portal", "tele", "rsbroad", "landscape", "terrain", "sign"}
    self._blacklistLower = {}
    self.Detector = detector
    self.TaskScheduler = taskScheduler
    
    self.CurrentTargetEntry = nil
    self._entries = {}
    self._folders = {"Entities", "Enemies", "Monsters", "NPCs", "Bosses"} -- Expanded folder list
    
    -- Performance: Polling Strategy
    self._lastScan = 0
    self._scanInterval = 0.1 -- Scan every 100ms instead of every frame
    self._cachedTargets = {}
    self._cacheDirty = true
    self._folderRefs = {}
    self._lastFolderRefresh = 0
    self._folderRefreshInterval = 2
    self._staleSweepInterval = 3
    self._entryExpiry = 18
    self._deadEntryExpiry = 6
    self._maxEntries = 180
    self._bossRefreshInterval = 8
    self._schedulerAlive = false
    self._staleSweepScheduled = false
    self._staleSweepGeneration = 0

    for i, keyword in ipairs(self.Blacklist) do
        self._blacklistLower[i] = string.lower(keyword)
    end
    
    return self
end

function NPCTracker:Init()
    self._schedulerAlive = true
    self._cacheDirty = true
    self:_refreshFolderRefs()
    self:_queueStaleSweep()
end

function NPCTracker:Prune(now)
    now = now or os.clock()
    local entryCount = 0

    for model, entry in pairs(self._entries) do
        entryCount = entryCount + 1
        local lastSeen = entry and entry.LastSeen or 0
        local isDead = entry and entry.Humanoid and entry.Humanoid.Health <= 0
        local expiry = isDead and self._deadEntryExpiry or self._entryExpiry

        if not model
            or not model.Parent
            or not entry
            or not entry.PrimaryPart
            or not entry.PrimaryPart.Parent
            or self:_HasBlacklistedName(model) then
            self._entries[model] = nil
        elseif lastSeen > 0 and (now - lastSeen) > expiry then
            self._entries[model] = nil
        end
    end

    if entryCount > self._maxEntries then
        for model, entry in pairs(self._entries) do
            if not entry or (entry.LastSeen or 0) < (now - 4) then
                self._entries[model] = nil
            end
        end
    end
end

function NPCTracker:_refreshFolderRefs()
    for i = 1, #self._folders do
        self._folderRefs[i] = Workspace:FindFirstChild(self._folders[i])
    end
    self._cacheDirty = true
end

function NPCTracker:_queueFolderRefresh()
    if not self.TaskScheduler or not self._schedulerAlive then
        self:_refreshFolderRefs()
        return
    end

    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if selfRef._schedulerAlive then
            selfRef:_refreshFolderRefs()
        end
    end, "__STAR_GLITCHER_TRACKER_FOLDER_REFRESH")
end

function NPCTracker:_queueStaleSweep()
    if not self.TaskScheduler or not self._schedulerAlive or self._staleSweepScheduled then
        return
    end

    self._staleSweepScheduled = true
    self._staleSweepGeneration = self._staleSweepGeneration + 1
    local generation = self._staleSweepGeneration
    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if not selfRef._schedulerAlive then
            selfRef._staleSweepScheduled = false
            return
        end

        if generation ~= selfRef._staleSweepGeneration then
            selfRef._staleSweepScheduled = false
            return
        end

        selfRef:Prune(os.clock())
        selfRef._staleSweepScheduled = false

        task.delay(selfRef._staleSweepInterval, function()
            if selfRef._schedulerAlive and generation == selfRef._staleSweepGeneration then
                selfRef:_queueStaleSweep()
            end
        end)
    end, "__STAR_GLITCHER_TRACKER_STALE_SWEEP")
end

function NPCTracker:IsLocalCharacterModel(model)
    return model ~= nil and model == Players.LocalPlayer.Character
end

function NPCTracker:_HasBlacklistedName(model)
    if not model then return false end
    local modelName = string.lower(model.Name)
    for _, keyword in ipairs(self._blacklistLower) do
        if modelName:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

function NPCTracker:_GetPrimaryPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or model:FindFirstChildWhichIsA("BasePart")
end

function NPCTracker:_IsTargetCandidate(model, existingEntry)
    -- GUARD: Ensure model validity
    if not model or not model:IsA("Model") or self:IsLocalCharacterModel(model) or not model.Parent then
        return false
    end

    -- PVP Check
    local isPlayerCharacter = Players:GetPlayerFromCharacter(model) ~= nil
    if isPlayerCharacter then
        return self.Options.TargetPlayersToggle == true
    end

    -- Blacklist/Sanity
    if self:_HasBlacklistedName(model) then
        return false
    end

    -- UNIVERSAL TARGETING: Support both Humanoid va Non-Humanoid (Bosses)
    local humanoid = existingEntry and existingEntry.Humanoid or model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    local isBoss = existingEntry and existingEntry.IsBoss
    if isBoss == nil then
        isBoss = self.Detector and self.Detector.IsBoss and self.Detector:IsBoss(model, humanoid)
    end
    
    if not primary then return false end

    -- STATIC OBJECT FILTER: Boss boards, shops, etc.
    -- Mobs/Bosses (even custom ones) usually have unanchored root parts.
    if not humanoid and primary.Anchored and not isBoss and not model:FindFirstChild("Health", true) then
        -- Only ignore if it has no health indicators va is anchored
        return false
    end

    return true
end

function NPCTracker:GetTargets()
    local now = os.clock()

    if not self._cacheDirty and (now - self._lastScan) < self._scanInterval then
        return self._cachedTargets
    end

    self._lastScan = now
    local result = self._cachedTargets
    table.clear(result)
    local seenModels = {}

    if (now - self._lastFolderRefresh) >= self._folderRefreshInterval then
        self._lastFolderRefresh = now
        self:_queueFolderRefresh()
    end

    local function trackModel(model)
        if not model or seenModels[model] then return end
        seenModels[model] = true
        
        local entry = self:_GetOrCreateEntry(model)
        if entry then
            entry.LastSeen = now
            entry.PrimaryPart = self:_GetPrimaryPart(model) or entry.PrimaryPart
            entry.Humanoid = model:FindFirstChildOfClass("Humanoid") or entry.Humanoid
            if (entry.LastBossCheck or 0) <= 0 or (now - entry.LastBossCheck) >= self._bossRefreshInterval then
                entry.IsBoss = self.Detector:IsBoss(model, entry.Humanoid)
                entry.LastBossCheck = now
            end
            if entry.PrimaryPart then
                entry.LastPos = entry.PrimaryPart.Position
            end

            -- Only include alive targets
            if not entry.Humanoid or entry.Humanoid.Health > 0 then
                result[#result + 1] = entry
                return true
            end
        end
        return false
    end
    
    -- 1. Scan Folders (Entities)
    local foundFolderTarget = false
    for i = 1, #self._folderRefs do
        local f = self._folderRefs[i]
        if f then
            for _, model in ipairs(f:GetChildren()) do
                if model:IsA("Model") and trackModel(model) then
                    foundFolderTarget = true
                end
            end
        end
    end

    -- 2. Fallback Scan (Entities directly in Workspace)
    -- Skip this broad scan if dedicated entity folders already yielded targets.
    if not foundFolderTarget then
        -- Avoid GetDescendants() which is catastrophic for performance.
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") then
                trackModel(obj)
            end
        end
    end
    
    -- 3. Scan Players (PvP Mode)
    if self.Options.TargetPlayersToggle then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer and p.Character then
                trackModel(p.Character)
            end
        end
    end

    self._cacheDirty = false
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    local existingEntry = self._entries[model]
    if existingEntry then
        if not self:_IsTargetCandidate(model, existingEntry) then
            self._entries[model] = nil
            return nil
        end
        return existingEntry
    end

    if not self:_IsTargetCandidate(model) then
        self._entries[model] = nil
        return nil
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    local now = os.clock()
    
    if not primary then return nil end
    
    local entry = {
        Model = model,
        Humanoid = hum,
        PrimaryPart = primary,
        IsBoss = self.Detector:IsBoss(model, hum),
        Name = model.Name,
        LastPos = primary.Position,
        LastTime = now,
        LastSeen = now,
        LastBossCheck = now,
    }
    
    self._entries[model] = entry
    return entry
end

function NPCTracker:GetTargetPart(entry)
    local model = entry.Model
    if not model or not model.Parent or self:IsLocalCharacterModel(model) then return nil end
    
    local targetPart = model:FindFirstChild(self.Options.TargetPart)
    if not targetPart then
        if self.Options.TargetPart == "Torso" then
            targetPart = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
        elseif self.Options.TargetPart == "Head" then
            targetPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        end
    end

    local resolvedPart = targetPart or entry.PrimaryPart or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if resolvedPart then
        entry.PrimaryPart = resolvedPart
    end
    return resolvedPart
end

function NPCTracker:GetEntryCount()
    local count = 0
    for _ in pairs(self._entries) do
        count = count + 1
    end
    return count
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    table.clear(self._cachedTargets)
    self.CurrentTargetEntry = nil
    self._cacheDirty = true
    self._lastScan = 0
end

function NPCTracker:Destroy()
    self._schedulerAlive = false
    self._staleSweepScheduled = false
    self._staleSweepGeneration = self._staleSweepGeneration + 1
    self:ClearCache()
end

return NPCTracker

]====],
    ["Modules/Utils/ResourceManager.lua"] = [====[local RunService = game:GetService("RunService")

local ResourceManager = {}
ResourceManager.__index = ResourceManager

local DEFAULT_FRAME_BUDGET = 0.0008
local DEFAULT_GC_STEP = 16
local COMPACT_THRESHOLD = 256

function ResourceManager.new(options)
    local self = setmetatable({}, ResourceManager)
    self.Options = options
    self.Status = "Idle"
    self.Connection = nil
    self._trackedConnections = {}
    self._trackedObjects = {}
    self._cleanupQueue = {}
    self._queueHead = 1
    self._queueTail = 0
    self._frameBudget = DEFAULT_FRAME_BUDGET
    self._gcStep = DEFAULT_GC_STEP
    self._manualBoostUntil = 0
    self._lastHitch = 0
    return self
end

function ResourceManager:_compactQueue()
    if self._queueHead <= 1 then
        return
    end

    local pending = self:GetPendingCount()
    if pending <= 0 then
        self._queueHead = 1
        self._queueTail = 0
        return
    end

    local compacted = table.create and table.create(pending) or {}
    local nextIndex = 1
    for i = self._queueHead, self._queueTail do
        local job = self._cleanupQueue[i]
        if job ~= nil then
            compacted[nextIndex] = job
            nextIndex = nextIndex + 1
        end
    end

    self._cleanupQueue = compacted
    self._queueHead = 1
    self._queueTail = nextIndex - 1
end

function ResourceManager:_maybeCompactQueue()
    if self._queueHead > COMPACT_THRESHOLD and self._queueHead > (self._queueTail * 0.5) then
        self:_compactQueue()
    end
end

function ResourceManager:_pushJob(kind, payload)
    self._queueTail = self._queueTail + 1
    self._cleanupQueue[self._queueTail] = {
        Kind = kind,
        Payload = payload,
    }
end

function ResourceManager:_popJob()
    if self._queueHead > self._queueTail then
        return nil
    end

    local job = self._cleanupQueue[self._queueHead]
    self._cleanupQueue[self._queueHead] = nil
    self._queueHead = self._queueHead + 1

    if self._queueHead > self._queueTail then
        self._queueHead = 1
        self._queueTail = 0
    end

    return job
end

function ResourceManager:GetPendingCount()
    return math.max(0, self._queueTail - self._queueHead + 1)
end

function ResourceManager:TrackConnection(connection)
    if connection then
        self._trackedConnections[#self._trackedConnections + 1] = connection
    end
    return connection
end

function ResourceManager:TrackObject(object)
    if object then
        self._trackedObjects[#self._trackedObjects + 1] = object
    end
    return object
end

function ResourceManager:DeferDestroy(object)
    if object then
        self:_pushJob("destroy", object)
    end
end

function ResourceManager:DeferDisconnect(connection)
    if connection then
        self:_pushJob("disconnect", connection)
    end
end

function ResourceManager:DeferCleanup(callback)
    if callback then
        self:_pushJob("callback", callback)
    end
end

function ResourceManager:_getBudget(dt)
    local budget = self._frameBudget
    local now = os.clock()
    local boosted = now < self._manualBoostUntil
    local pending = self:GetPendingCount()

    if boosted then
        budget = budget * 1.6
    end

    if pending >= 400 then
        budget = budget * 4
    elseif pending >= 150 then
        budget = budget * 2.5
    elseif pending >= 50 then
        budget = budget * 1.6
    end

    if dt and dt > (1 / 35) then
        self._lastHitch = now
        budget = budget * 0.45
    elseif (now - self._lastHitch) < 0.75 then
        budget = budget * 0.7
    end

    return budget
end

function ResourceManager:_runJob(job)
    if not job then
        return false
    end

    if job.Kind == "destroy" then
        local object = job.Payload
        if object and object.Destroy then
            pcall(function()
                object:Destroy()
            end)
        elseif object and object.Parent then
            pcall(function()
                object:Destroy()
            end)
        end
        return true
    end

    if job.Kind == "disconnect" then
        local connection = job.Payload
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
        return true
    end

    if job.Kind == "callback" then
        pcall(job.Payload)
        return true
    end

    return false
end

function ResourceManager:_step(dt)
    local budget = self:_getBudget(dt)
    local startTime = os.clock()
    local processed = 0
    local pendingCount = self:GetPendingCount()
    
    local minProcess = 0
    if pendingCount >= 1500 then
        minProcess = 50
    elseif pendingCount >= 500 then
        minProcess = 15
    end

    local iterations = 0
    local maxIterations = math.max(minProcess, 150)

    while self:GetPendingCount() > 0 do
        iterations = iterations + 1
        if iterations > maxIterations then
            break
        end

        if (os.clock() - startTime) >= budget and processed >= minProcess then
            break
        end

        local job = self:_popJob()
        if not job then
            break
        end
        if self:_runJob(job) then
            processed = processed + 1
        end
    end

    if processed > 0 then
        -- collectgarbage("step", self._gcStep) -- Restricted in some environments
    end

    local pending = self:GetPendingCount()
    self:_maybeCompactQueue()
    if pending > 0 then
        self.Status = string.format("Draining (%d pending)", pending)
    elseif processed > 0 then
        self.Status = "Settled"
    else
        self.Status = "Idle"
    end
end

function ResourceManager:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function(dt)
        if self.Options and self.Options.SmartCleanupEnabled == false then
            return
        end
        self:_step(dt)
    end)
end

function ResourceManager:ScheduleTrackedCleanup()
    for i = #self._trackedConnections, 1, -1 do
        local connection = self._trackedConnections[i]
        self._trackedConnections[i] = nil
        self:DeferDisconnect(connection)
    end

    for i = #self._trackedObjects, 1, -1 do
        local object = self._trackedObjects[i]
        self._trackedObjects[i] = nil
        self:DeferDestroy(object)
    end
end

function ResourceManager:Boost(duration)
    self._manualBoostUntil = math.max(self._manualBoostUntil, os.clock() + (duration or 1.5))
end

function ResourceManager:Flush(maxSeconds)
    local deadline = os.clock() + (maxSeconds or 1.25)
    self:Boost(maxSeconds or 1.25)

    while self:GetPendingCount() > 0 and os.clock() < deadline do
        self:_step(1 / 60)
        task.wait()
    end

    return self:GetPendingCount()
end

function ResourceManager:Destroy()
    self:ScheduleTrackedCleanup()
    self:Flush(0.2)

    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return ResourceManager
]====],
    ["Modules/Utils/Synapse.lua"] = [====[--[[
    Synapse.lua - Communication Signal System
    Analogy: The neural synapses connecting different regions of the brain.
    Allows decoupled cross-module communication (Events).
]]

local Synapse = {}
Synapse.__index = Synapse

local _events = {}

function Synapse.on(name, callback)
    if not _events[name] then _events[name] = {} end
    table.insert(_events[name], callback)
    
    return {
        Disconnect = function()
            local listeners = _events[name]
            if not listeners then
                return
            end

            for i, cb in ipairs(listeners) do
                if cb == callback then
                    table.remove(listeners, i)
                    if #listeners == 0 then
                        _events[name] = nil
                    end
                    break
                end
            end
        end
    }
end

function Synapse.fire(name, ...)
    if not _events[name] then return end
    local listeners = table.clone and table.clone(_events[name]) or {table.unpack(_events[name])}
    for _, callback in ipairs(listeners) do
        task.spawn(callback, ...)
    end
end

function Synapse.clear(name)
    if name == nil then
        return
    end

    _events[name] = nil
end

function Synapse.clearAll()
    table.clear(_events)
end

function Synapse.getListenerCount(name)
    local listeners = _events[name]
    return listeners and #listeners or 0
end

return Synapse

]====],
    ["Modules/Utils/TaskScheduler.lua"] = [====[local RunService = game:GetService("RunService")

local TaskScheduler = {}
TaskScheduler.__index = TaskScheduler

local DEFAULT_FRAME_BUDGET = 0.001
local COMPACT_THRESHOLD = 256

function TaskScheduler.new(options)
    local self = setmetatable({}, TaskScheduler)
    self.Options = options
    self.Connection = nil
    self.Status = "Idle"
    self._queue = {}
    self._head = 1
    self._tail = 0
    self._activeKeys = {}
    self._frameBudget = DEFAULT_FRAME_BUDGET
    self._lastHitch = 0
    return self
end

function TaskScheduler:_compactQueue()
    if self._head <= 1 then
        return
    end

    local pending = self:GetPendingCount()
    if pending <= 0 then
        self._head = 1
        self._tail = 0
        return
    end

    local compacted = table.create and table.create(pending) or {}
    local nextIndex = 1
    for i = self._head, self._tail do
        local job = self._queue[i]
        if job ~= nil then
            compacted[nextIndex] = job
            nextIndex = nextIndex + 1
        end
    end

    self._queue = compacted
    self._head = 1
    self._tail = nextIndex - 1
end

function TaskScheduler:_maybeCompactQueue()
    if self._head > COMPACT_THRESHOLD and self._head > (self._tail * 0.5) then
        self:_compactQueue()
    end
end

function TaskScheduler:_push(job)
    self._tail = self._tail + 1
    self._queue[self._tail] = job
end

function TaskScheduler:_pop()
    if self._head > self._tail then
        return nil
    end

    local job = self._queue[self._head]
    self._queue[self._head] = nil
    self._head = self._head + 1

    if self._head > self._tail then
        self._head = 1
        self._tail = 0
    end

    return job
end

function TaskScheduler:GetPendingCount()
    return math.max(0, self._tail - self._head + 1)
end

function TaskScheduler:Enqueue(callback, key)
    if type(callback) ~= "function" then
        return false
    end

    if key ~= nil then
        if self._activeKeys[key] then
            return false
        end
        self._activeKeys[key] = true
    end

    self:_push({
        Callback = callback,
        Key = key,
    })
    return true
end

function TaskScheduler:_getBudget(dt)
    local budget = self._frameBudget
    local now = os.clock()

    if dt and dt > (1 / 35) then
        self._lastHitch = now
        budget = budget * 0.5
    elseif (now - self._lastHitch) < 0.75 then
        budget = budget * 0.7
    end

    return budget
end

function TaskScheduler:_runJob(job)
    if not job then
        return false
    end

    if job.Key ~= nil then
        self._activeKeys[job.Key] = nil
    end

    local ok, err = pcall(job.Callback)
    if not ok then
        warn("[TaskScheduler] Job failed | Error: " .. tostring(err))
    end
    return ok
end

function TaskScheduler:_step(dt)
    local startTime = os.clock()
    local budget = self:_getBudget(dt)
    local processed = 0

    local iterations = 0
    local maxIterations = 100

    while self:GetPendingCount() > 0 do
        iterations = iterations + 1
        if iterations > maxIterations then
            break
        end

        if (os.clock() - startTime) >= budget then
            break
        end

        local job = self:_pop()
        if not job then
            break
        end

        if self:_runJob(job) then
            processed = processed + 1
        end
    end

    local pending = self:GetPendingCount()
    self:_maybeCompactQueue()
    if pending > 0 then
        self.Status = string.format("Batching (%d pending)", pending)
    elseif processed > 0 then
        self.Status = "Settled"
    else
        self.Status = "Idle"
    end
end

function TaskScheduler:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function(dt)
        self:_step(dt)
    end)
end

function TaskScheduler:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    table.clear(self._queue)
    table.clear(self._activeKeys)
    self._head = 1
    self._tail = 0
    self.Status = "Idle"
end

return TaskScheduler
]====],
    ["Modules/Visuals.lua"] = [====[--[[
    Visuals.lua - Visual Feedback Class
    Quan ly FOV Circle, Target Dot, Highlight, va Hitmarker system.
]]

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local Visuals = {}
Visuals.__index = Visuals

function Visuals.new(config)
    local self = setmetatable({}, Visuals)
    self.Config = config
    self.Options = config.Options

    -- FOV Circle
    self.FOVCircle = Drawing.new("Circle")
    self.FOVCircle.Position = UserInputService:GetMouseLocation()
    self.FOVCircle.Radius = self.Options.FOV
    self.FOVCircle.Filled = false
    self.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    self.FOVCircle.Visible = self.Options.ShowFOV
    self.FOVCircle.Thickness = 1.5

    -- Target Dot
    self.TargetDot = Drawing.new("Circle")
    self.TargetDot.Visible = false
    self.TargetDot.Filled = true
    self.TargetDot.Radius = 4
    self.TargetDot.Color = Color3.fromRGB(255, 80, 80)
    self.TargetDot.Thickness = 1

    -- Hitmarker Lines
    local HitmarkerColor = Color3.fromRGB(255, 40, 40)
    self.HitmarkerLine1 = Drawing.new("Line")
    self.HitmarkerLine1.Visible = false
    self.HitmarkerLine1.Thickness = 1.5
    self.HitmarkerLine1.Color = HitmarkerColor

    self.HitmarkerLine2 = Drawing.new("Line")
    self.HitmarkerLine2.Visible = false
    self.HitmarkerLine2.Thickness = 1.5
    self.HitmarkerLine2.Color = HitmarkerColor

    -- Hitmarker Sound
    self.HitSound = Instance.new("Sound")
    pcall(function() self.HitSound.Parent = CoreGui end)
    self.HitSound.SoundId = "rbxassetid://160432334"
    self.HitSound.Volume = 1.6

    -- Target Highlight
    self.TargetHighlight = Instance.new("Highlight")
    self.TargetHighlight.FillColor = Color3.fromRGB(255, 50, 50)
    self.TargetHighlight.FillTransparency = 0.5
    self.TargetHighlight.OutlineColor = Color3.new(1, 1, 1)
    self.TargetHighlight.OutlineTransparency = 0
    self.TargetHighlight.Enabled = false
    pcall(function() self.TargetHighlight.Parent = CoreGui end)
    if not self.TargetHighlight.Parent then
        self.TargetHighlight.Parent = Workspace.CurrentCamera
    end

    self._lastHitTick = 0
    return self
end

function Visuals:ShowHitmarker()
    pcall(function()
        local mousePos = UserInputService:GetMouseLocation()
        local size = 7

        self.HitmarkerLine1.From = Vector2.new(mousePos.X - size, mousePos.Y - size)
        self.HitmarkerLine1.To = Vector2.new(mousePos.X + size, mousePos.Y + size)
        self.HitmarkerLine1.Visible = true

        self.HitmarkerLine2.From = Vector2.new(mousePos.X + size, mousePos.Y - size)
        self.HitmarkerLine2.To = Vector2.new(mousePos.X - size, mousePos.Y + size)
        self.HitmarkerLine2.Visible = true

        self.HitSound:Play()

        local currentTick = os.clock()
        self._lastHitTick = currentTick
        task.delay(0.25, function()
            if self._lastHitTick == currentTick then
                self.HitmarkerLine1.Visible = false
                self.HitmarkerLine2.Visible = false
            end
        end)
    end)
end

function Visuals:UpdateFOV(mousePos)
    if self.Options.ShowFOV then
        self.FOVCircle.Position = mousePos
        self.FOVCircle.Visible = true
    else
        self.FOVCircle.Visible = false
    end
end

function Visuals:SetTargetDot(screenPos, visible)
    if visible then
        self.TargetDot.Position = Vector2.new(screenPos.X, screenPos.Y)
        self.TargetDot.Visible = true
    else
        self.TargetDot.Visible = false
    end
end

function Visuals:SetHighlight(part, enabled)
    self.TargetHighlight.Adornee = part
    self.TargetHighlight.Enabled = enabled
end

function Visuals:ClearHighlight()
    self.TargetHighlight.Adornee = nil
    self.TargetHighlight.Enabled = false
end

function Visuals:Destroy()
    pcall(function() self.FOVCircle:Remove() end)
    pcall(function() self.TargetDot:Remove() end)
    pcall(function() self.HitmarkerLine1:Remove() end)
    pcall(function() self.HitmarkerLine2:Remove() end)
    pcall(function() self.HitSound:Destroy() end)
    pcall(function() self.TargetHighlight:Destroy() end)
end

return Visuals

]====],
    ["Modules/Visuals/FOVCircle.lua"] = [====[--[[
    FOVCircle.lua - OOP FOV Visualization Class
]]

local UserInputService = game:GetService("UserInputService")

local FOVCircle = {}
FOVCircle.__index = FOVCircle

function FOVCircle.new(options)
    local self = setmetatable({}, FOVCircle)
    self.Options = options
    self._visible = false
    self._radius = options.FOV or 150
    self._x = nil
    self._y = nil

    self.Drawing = Drawing.new("Circle")
    self.Drawing.Position = UserInputService:GetMouseLocation()
    self.Drawing.Radius = self._radius
    self.Drawing.Filled = false
    self.Drawing.Color = Color3.fromRGB(255, 255, 255)
    self.Drawing.Visible = false
    self.Drawing.Thickness = 1.5

    return self
end

function FOVCircle:_shouldShow()
    local method = tostring(self.Options.TargetingMethod or "FOV")
    return method ~= "Distance"
end

function FOVCircle:Update(mousePos)
    if self:_shouldShow() then
        if self._x ~= mousePos.X or self._y ~= mousePos.Y then
            self.Drawing.Position = mousePos
            self._x = mousePos.X
            self._y = mousePos.Y
        end
        if not self._visible then
            self.Drawing.Visible = true
            self._visible = true
        end
        if self._radius ~= self.Options.FOV then
            self.Drawing.Radius = self.Options.FOV
            self._radius = self.Options.FOV
        end
    elseif self._visible then
        self.Drawing.Visible = false
        self._visible = false
    end
end

function FOVCircle:Destroy()
    pcall(function()
        self.Drawing:Remove()
    end)
end

return FOVCircle
]====],
    ["Modules/Visuals/Highlight.lua"] = [====[--[[
    TargetHighlight.lua - OOP Highlight Visualization Class
]]

local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local TargetHighlight = {}
TargetHighlight.__index = TargetHighlight

function TargetHighlight.new()
    local self = setmetatable({}, TargetHighlight)
    
    self.Instance = Instance.new("Highlight")
    self.Instance.FillColor = Color3.fromRGB(240, 60, 60)
    self.Instance.FillTransparency = 0.5
    self.Instance.OutlineColor = Color3.new(1, 1, 1)
    self.Instance.OutlineTransparency = 0
    self.Instance.Enabled = false
    
    pcall(function() self.Instance.Parent = CoreGui end)
    if not self.Instance.Parent then
        self.Instance.Parent = Workspace.CurrentCamera
    end
    
    return self
end

function TargetHighlight:Set(part, enabled)
    self.Instance.Adornee = part
    self.Instance.Enabled = enabled
end

function TargetHighlight:Clear()
    self.Instance.Adornee = nil
    self.Instance.Enabled = false
end

function TargetHighlight:Destroy()
    pcall(function() self.Instance:Destroy() end)
end

return TargetHighlight

]====],
    ["Modules/Visuals/TargetDot.lua"] = [====[--[[
    TargetDot.lua - OOP Target Locking Dot Visualization Class
]]

local TargetDot = {}
TargetDot.__index = TargetDot

function TargetDot.new()
    local self = setmetatable({}, TargetDot)
    self._visible = false
    self._x = nil
    self._y = nil

    self.Drawing = Drawing.new("Circle")
    self.Drawing.Visible = false
    self.Drawing.Filled = true
    self.Drawing.Radius = 4
    self.Drawing.Color = Color3.fromRGB(240, 60, 60)
    self.Drawing.Thickness = 1

    return self
end

function TargetDot:Set(screenPos, visible)
    if visible and screenPos then
        if self._x ~= screenPos.X or self._y ~= screenPos.Y then
            self.Drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
            self._x = screenPos.X
            self._y = screenPos.Y
        end
        if not self._visible then
            self.Drawing.Visible = true
            self._visible = true
        end
    elseif self._visible then
        self.Drawing.Visible = false
        self._visible = false
    end
end

function TargetDot:Destroy()
    pcall(function()
        self.Drawing:Remove()
    end)
end

return TargetDot
]====],
    ["Modules/Visuals/TechniqueOverlay.lua"] = [====[local TechniqueOverlay = {}
TechniqueOverlay.__index = TechniqueOverlay

function TechniqueOverlay.new(options)
    local self = setmetatable({}, TechniqueOverlay)
    self.Options = options
    self.Drawing = Drawing.new("Text")
    self.Drawing.Visible = false
    self.Drawing.Size = 16
    self.Drawing.Color = Color3.fromRGB(255, 236, 236)
    self.Drawing.Outline = true
    self.Drawing.Center = false
    self.Drawing.Font = 2
    return self
end

function TechniqueOverlay:Update(decision, entry)
    if not self.Options.PredictionTechniqueDebug then
        self.Drawing.Visible = false
        return
    end

    if not decision then
        self.Drawing.Visible = false
        return
    end

    local technique = tostring(decision.Technique or "Unknown")
    local reason = tostring(decision.Reason or "n/a")
    local confidence = math.floor(((decision.Confidence or 0) * 100) + 0.5)
    local targetName = entry and entry.Name or "No target"

    self.Drawing.Position = Vector2.new(18, 160)
    self.Drawing.Text = string.format(
        "Technique: %s\nTarget: %s\nConfidence: %d%%\nReason: %s",
        technique,
        targetName,
        confidence,
        reason
    )
    self.Drawing.Visible = true
end

function TechniqueOverlay:Clear()
    self.Drawing.Visible = false
end

function TechniqueOverlay:Destroy()
    pcall(function()
        self.Drawing:Remove()
    end)
end

return TechniqueOverlay
]====],
    ["Tools/HitConfidenceProbe.lua"] = [====[--[[
    HitConfidenceProbe.lua
    Standalone internal test helper for validating "did my shot likely deal damage?"

    Usage:
    1. Run your main runtime first if you want the probe to reuse its highlight target.
    2. Copy this file and execute it standalone.
    3. Left click to register a shot. The probe tracks the target at shot time.
    4. It watches health-like values on that exact target and reports damage deltas.

    Classification:
    - CONFIRMED: reserved for future remote/projectile ACK signals.
    - PROBABLE: the tracked target lost health inside the shot confirmation window.
    - MISS: no health drop observed in time.

    Notes:
    - This intentionally does not claim perfect attribution in multiplayer.
    - It is strongest when you test alone on a boss or on a target few others are hitting.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local clock = os.clock

local SETTINGS = {
    WindowSeconds = 1.1,
    GraceSeconds = 0.06,
    MaxRows = 10,
    PollInterval = 0.03,
    HighlightFillColor = Color3.fromRGB(240, 60, 60),
    HighlightTolerance = 8,
}

local HEALTH_HINTS = {
    "Health", "HP", "HitPoints", "BossHealth", "EnemyHealth", "HealthValue",
}

local Probe = {
    Shots = {},
    Alive = true,
    LastPoll = 0,
    NextId = 0,
}

local function round(n)
    if typeof(n) ~= "number" then
        return n
    end
    return math.floor(n * 100 + 0.5) / 100
end

local function findCharacterAncestor(instance)
    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Model") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function getLargestPart(model)
    local bestPart = nil
    local bestVolume = -1
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local size = descendant.Size
            local volume = size.X * size.Y * size.Z
            if volume > bestVolume then
                bestPart = descendant
                bestVolume = volume
            end
        end
    end
    return bestPart
end

local function getPrimaryPart(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or getLargestPart(model)
end

local function getHealthObject(model)
    if not model then
        return nil, nil
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid, "Humanoid"
    end

    for _, hint in ipairs(HEALTH_HINTS) do
        local child = model:FindFirstChild(hint, true)
        if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
            return child, child.ClassName
        end
    end

    if model:GetAttribute("Health") ~= nil or model:GetAttribute("HP") ~= nil then
        return model, "Attribute"
    end

    return nil, nil
end

local function readHealth(model)
    local source, sourceType = getHealthObject(model)
    if not source then
        return nil, nil, "Missing"
    end

    if sourceType == "Humanoid" then
        return tonumber(source.Health), tonumber(source.MaxHealth), "Humanoid"
    end

    if sourceType == "Attribute" then
        local current = tonumber(model:GetAttribute("Health")) or tonumber(model:GetAttribute("HP"))
        local max = tonumber(model:GetAttribute("MaxHealth")) or tonumber(model:GetAttribute("MaxHP")) or current
        return current, max, "Attribute"
    end

    local value = tonumber(source.Value)
    return value, value, source.Name
end

local function findProbeHighlight()
    local best = nil

    local function scan(container)
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("Highlight") and descendant.Enabled and descendant.Adornee then
                local fill = descendant.FillColor
                local diff = math.abs(fill.R * 255 - SETTINGS.HighlightFillColor.R * 255)
                    + math.abs(fill.G * 255 - SETTINGS.HighlightFillColor.G * 255)
                    + math.abs(fill.B * 255 - SETTINGS.HighlightFillColor.B * 255)
                if diff <= SETTINGS.HighlightTolerance * 3 then
                    best = descendant
                    return true
                end
            end
        end
        return false
    end

    pcall(function()
        if scan(CoreGui) then
            return
        end
    end)

    if not best then
        pcall(function()
            local camera = Workspace.CurrentCamera
            if camera then
                scan(camera)
            end
        end)
    end

    return best
end

local function resolveCurrentTarget()
    local highlight = findProbeHighlight()
    if highlight and highlight.Adornee then
        local model = findCharacterAncestor(highlight.Adornee)
        if model then
            return model, highlight.Adornee, "highlight"
        end
    end

    local mouseTarget = Mouse.Target
    local model = findCharacterAncestor(mouseTarget)
    if model then
        return model, mouseTarget, "mouse"
    end

    return nil, nil, "none"
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StarGlitcherHitProbe"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    screenGui.Parent = CoreGui
end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.Size = UDim2.fromOffset(430, 250)
frame.Position = UDim2.new(1, -450, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = screenGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 90, 90)
stroke.Transparency = 0.2
stroke.Parent = frame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 24)
title.Font = Enum.Font.Code
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 240, 240)
title.Text = "Hit Confidence Probe"
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(12, 30)
subtitle.Size = UDim2.new(1, -24, 0, 18)
subtitle.Font = Enum.Font.Code
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(180, 190, 205)
subtitle.Text = "Left click = register shot | highlight target first for best results"
subtitle.Parent = frame

local logLabel = Instance.new("TextLabel")
logLabel.BackgroundTransparency = 1
logLabel.Position = UDim2.fromOffset(12, 56)
logLabel.Size = UDim2.new(1, -24, 1, -68)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 14
logLabel.TextWrapped = false
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.RichText = false
logLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
logLabel.Text = "Waiting for shots..."
logLabel.Parent = frame

local function formatShot(shot)
    local age = round(clock() - shot.Time)
    local prefix = string.format("#%d [%s]", shot.Id, shot.State)
    local modelName = shot.ModelName or "Unknown"
    local source = shot.TargetSource or "?"

    if shot.State == "PROBABLE" then
        return string.format(
            "%s dmg=%s dt=%ss target=%s via=%s health=%s->%s",
            prefix,
            tostring(round(shot.Damage or 0)),
            tostring(round((shot.HitTime or shot.Time) - shot.Time)),
            modelName,
            source,
            tostring(round(shot.HealthBefore)),
            tostring(round(shot.HealthAfter))
        )
    end

    if shot.State == "MISS" then
        return string.format(
            "%s no drop age=%ss target=%s via=%s start=%s",
            prefix,
            tostring(age),
            modelName,
            source,
            tostring(round(shot.HealthBefore))
        )
    end

    return string.format(
        "%s pending age=%ss target=%s via=%s health=%s source=%s",
        prefix,
        tostring(age),
        modelName,
        source,
        tostring(round(shot.HealthBefore)),
        tostring(shot.HealthKind or "?")
    )
end

local function refreshLog()
    local lines = {
        string.format("Active shots: %d", #Probe.Shots),
    }

    local count = 0
    for i = #Probe.Shots, 1, -1 do
        count = count + 1
        if count > SETTINGS.MaxRows then
            break
        end
        lines[#lines + 1] = formatShot(Probe.Shots[i])
    end

    logLabel.Text = table.concat(lines, "\n")
end

local function pushShot(shot)
    Probe.Shots[#Probe.Shots + 1] = shot
    while #Probe.Shots > SETTINGS.MaxRows do
        table.remove(Probe.Shots, 1)
    end
    refreshLog()
end

local function registerShot()
    local model, part, source = resolveCurrentTarget()
    Probe.NextId = Probe.NextId + 1

    if not model then
        pushShot({
            Id = Probe.NextId,
            Time = clock(),
            State = "MISS",
            Model = nil,
            ModelName = "No target",
            TargetSource = source,
            HealthBefore = nil,
            HealthAfter = nil,
            Damage = 0,
        })
        return
    end

    local health, maxHealth, kind = readHealth(model)
    pushShot({
        Id = Probe.NextId,
        Time = clock(),
        ExpiresAt = clock() + SETTINGS.WindowSeconds,
        State = "PENDING",
        Model = model,
        ModelName = model.Name,
        Part = part or getPrimaryPart(model),
        TargetSource = source,
        HealthBefore = health,
        HealthAfter = health,
        MaxHealth = maxHealth,
        HealthKind = kind,
        Damage = 0,
    })
end

local function updateShots()
    local now = clock()
    if (now - Probe.LastPoll) < SETTINGS.PollInterval then
        return
    end
    Probe.LastPoll = now

    local dirty = false

    for _, shot in ipairs(Probe.Shots) do
        if shot.State == "PENDING" and shot.Model and shot.Model.Parent then
            local health = readHealth(shot.Model)
            if typeof(health) == "number" and typeof(shot.HealthBefore) == "number" then
                if health < shot.HealthBefore and (now - shot.Time) >= SETTINGS.GraceSeconds then
                    shot.HealthAfter = health
                    shot.Damage = shot.HealthBefore - health
                    shot.HitTime = now
                    shot.State = "PROBABLE"
                    dirty = true
                elseif now >= shot.ExpiresAt then
                    shot.HealthAfter = health
                    shot.State = "MISS"
                    dirty = true
                end
            elseif now >= shot.ExpiresAt then
                shot.State = "MISS"
                dirty = true
            end
        end
    end

    if dirty then
        refreshLog()
    end
end

local inputConnection
local renderConnection

inputConnection = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not Probe.Alive then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        registerShot()
    elseif input.KeyCode == Enum.KeyCode.Delete then
        Probe.Alive = false
        if inputConnection then
            inputConnection:Disconnect()
        end
        if renderConnection then
            renderConnection:Disconnect()
        end
        screenGui:Destroy()
    end
end)

renderConnection = RunService.RenderStepped:Connect(function()
    if Probe.Alive then
        updateShots()
    end
end)

refreshLog()

return Probe
]====],
    ["UI/Tabs/AimbotTab.lua"] = [====[--[[
    AimTab.lua - Unified Combat Control Center
    Consolidated: Assist Mode, FOV, Target Part, and Source Management.
    Replaces: AimbotTab.lua va TargetingTab.lua.
]]

return function(Window, Options, Visuals, NPCTracker)
    local Tab = Window:CreateTab("Aim", 4483362458)

    -- ===================================================
    -- SECTION: ASSIST MODE
    -- ===================================================
    Tab:CreateSection("Assist Mode")

    Tab:CreateDropdown({
        Name = "Main Assist Mode",
        Options = {"Off", "Camera Lock", "Silent Aim", "Highlight Only"},
        CurrentOption = {Options.AssistMode or "Off"},
        Flag = "AssistModeDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.AssistMode = selected
        end,
    })

    Tab:CreateToggle({
        Name = "Require Right Mouse Hold",
        CurrentValue = Options.HoldMouse2ToAssist,
        Flag = "HoldMouse2Toggle",
        Callback = function(Value)
            Options.HoldMouse2ToAssist = Value
        end,
    })

    -- ===================================================
    -- SECTION: TARGETING PARAMETERS
    -- ===================================================
    Tab:CreateSection("Targeting Parameters")

    Tab:CreateDropdown({
        Name = "Target Body Part",
        Options = {"HumanoidRootPart", "Torso", "Head"},
        CurrentOption = {Options.TargetPart or "HumanoidRootPart"},
        Flag = "TargetPartDropdown",
        Callback = function(Value)
            Options.TargetPart = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateSlider({
        Name = "Vertical Aim Offset (Y)",
        Range = {-50, 50},
        Increment = 5,
        Suffix = " (x0.1 Studs)",
        CurrentValue = Options.AimOffset and (Options.AimOffset * 10) or 0,
        Flag = "YOffsetSlider",
        Callback = function(Value)
            Options.AimOffset = Value / 10
        end,
    })

    -- ===================================================
    -- SECTION: AIM METHODS
    -- ===================================================
    Tab:CreateSection("Aim Methods")

    Tab:CreateDropdown({
        Name = "Aim Method",
        Options = {"FOV", "Distance", "Deadlock"},
        CurrentOption = {Options.TargetingMethod or "FOV"},
        Flag = "TargetingMethodDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.TargetingMethod = selected
            if Visuals and Visuals.FOVCircle then
                Visuals.FOVCircle.Visible = (selected ~= "Distance")
            end
        end,
    })

    Tab:CreateSlider({
        Name = "FOV / Lock Radius",
        Range = {0, 1000},
        Increment = 10,
        Suffix = "px",
        CurrentValue = Options.FOV or 100,
        Flag = "FOVSlider",
        Callback = function(Value)
            Options.FOV = Value
            if Visuals and Visuals.FOVCircle then
                Visuals.FOVCircle.Radius = Value
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Distance Detect",
        Range = {0, 5000},
        Increment = 25,
        Suffix = " studs",
        CurrentValue = Options.MaxDistance or 1500,
        Flag = "DistanceDetectSlider",
        Callback = function(Value)
            Options.MaxDistance = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Adaptive Target Scan",
        CurrentValue = Options.AdaptiveTargetScan ~= false,
        Flag = "AdaptiveTargetScanToggle",
        Callback = function(Value)
            Options.AdaptiveTargetScan = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Target Scan Cap",
        Range = {30, 240},
        Increment = 5,
        Suffix = " Hz",
        CurrentValue = Options.TargetScanHz or 120,
        Flag = "TargetScanHzSlider",
        Callback = function(Value)
            Options.TargetScanHz = Value
        end,
    })

    -- ===================================================
    -- SECTION: CAMERA SETTINGS
    -- ===================================================
    Tab:CreateSection("Camera Lock (Aimbot)")

    Tab:CreateSlider({
        Name = "Lock Smoothness",
        Range = {1, 100},
        Increment = 1,
        Suffix = "%",
        CurrentValue = math.floor((Options.Smoothness or 0.1) * 100),
        Flag = "SmoothnessSlider",
        Callback = function(Value)
            Options.Smoothness = math.clamp(Value / 100, 0.01, 1)
        end,
    })

    -- ===================================================
    -- SECTION: TARGET SOURCE
    -- ===================================================
    Tab:CreateSection("Target Filter")

    Tab:CreateToggle({
        Name = "Target Other Players (PvP)",
        CurrentValue = Options.TargetPlayersToggle,
        Flag = "TargetPlayersFlag",
        Callback = function(Value)
            Options.TargetPlayersToggle = Value
            if NPCTracker and NPCTracker.ClearCache then
                NPCTracker:ClearCache()
            end
        end,
    })

    return Tab
end

]====],
    ["UI/Tabs/BlatantTab.lua"] = [====[--[[
    BlatantTab.lua - Tab Blatant & Bypass
    Contains only explicit bypass-style options.
]]

local function setLabelText(label, text)
    if not label then
        return
    end

    if type(label) == "table" and type(label.Set) == "function" then
        local ok = pcall(function()
            label:Set(text)
        end)
        if ok then
            return
        end
    end

    if typeof(label) == "Instance" then
        local textLabel = label:IsA("TextLabel") and label or label:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then
            textLabel.Text = text
        end
    end
end

return function(Window, Options, killPartBypass, proactiveEvade)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)
    local statusLabel = Tab:CreateLabel("Zenith Status: Idle")
    local killPartLabel = Tab:CreateLabel("Kill Part Bypass: Idle")
    local proactiveEvadeLabel = Tab:CreateLabel("Proactive Evade: Idle")

    Tab:CreateSection("Zenith Desync Architecture")

    Tab:CreateToggle({
        Name = "Zenith Desync (Soul Mode)",
        CurrentValue = Options.ZenithDesyncEnabled,
        Flag = "ZenithDesyncFlag",
        Callback = function(Value)
            Options.ZenithDesyncEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Soul Separated",
                    Content = "Your physical hitbox is now hidden. You are visually desynced.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Silent Damage Sync",
        CurrentValue = Options.SilentDamageEnabled,
        Flag = "SilentDamageFlag",
        Callback = function(Value)
            Options.SilentDamageEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Combat Sync Active",
                    Content = "Hitbox will flicker to targets for damage registration.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("Client Masking")

    Tab:CreateToggle({
        Name = "Speed Spoof (Bypass)",
        CurrentValue = Options.SpeedSpoofEnabled,
        Flag = "SpeedSpoofFlag",
        Callback = function(Value)
            Options.SpeedSpoofEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Kill Part Bypass",
        CurrentValue = Options.KillPartBypassEnabled,
        Flag = "KillPartBypassFlag",
        Callback = function(Value)
            Options.KillPartBypassEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Kill Part Bypass Active",
                    Content = "Touch/query kill parts are now being masked separately from noclip.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("Auto Evasion")

    Tab:CreateToggle({
        Name = "Proactive Evade",
        CurrentValue = Options.ProactiveEvadeEnabled,
        Flag = "ProactiveEvadeFlag",
        Callback = function(Value)
            Options.ProactiveEvadeEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Proactive Evade Active",
                    Content = "Your character will sidestep automatically without needing target detection.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Evade Stride",
        Range = {2, 8},
        Increment = 0.25,
        Suffix = "studs",
        CurrentValue = tonumber(Options.ProactiveEvadeStride) or 4.5,
        Flag = "ProactiveEvadeStrideFlag",
        Callback = function(Value)
            Options.ProactiveEvadeStride = tonumber(Value) or 4.5
        end,
    })

    Tab:CreateSlider({
        Name = "Evade Interval",
        Range = {0.2, 1.2},
        Increment = 0.05,
        Suffix = "s",
        CurrentValue = tonumber(Options.ProactiveEvadeInterval) or 0.42,
        Flag = "ProactiveEvadeIntervalFlag",
        Callback = function(Value)
            Options.ProactiveEvadeInterval = tonumber(Value) or 0.42
        end,
    })

    task.spawn(function()
        local lastKillPartText = nil
        local lastProactiveText = nil
        while task.wait(0.2) do
            if killPartBypass then
                local nextText = "Kill Part Bypass: " .. tostring(killPartBypass.Status or "Idle")
                if nextText ~= lastKillPartText then
                    lastKillPartText = nextText
                    setLabelText(killPartLabel, nextText)
                end
            end

            if proactiveEvade then
                local nextText = "Proactive Evade: " .. tostring(proactiveEvade.Status or "Idle")
                if nextText ~= lastProactiveText then
                    lastProactiveText = nextText
                    setLabelText(proactiveEvadeLabel, nextText)
                end
            end
        end
    end)

    return Tab
end
]====],
    ["UI/Tabs/Player/Controller.lua"] = [====[--[[
    Controller.lua - Player tab controller
    Job: Compose layout and status refresh helpers for the Player tab.
]]

local Controller = {}
Controller.__index = Controller

function Controller.new(layout, statusLoop, labelUtils)
    local self = setmetatable({}, Controller)
    self.Layout = layout
    self.StatusLoop = statusLoop
    self.LabelUtils = labelUtils
    self._statusLoopHandle = nil
    return self
end

function Controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, zenith)
    local Tab = Window:CreateTab("Player", 4483362458)
    local refs = self.Layout.Build(Tab, Options)

    if self._statusLoopHandle and self._statusLoopHandle.Destroy then
        self._statusLoopHandle:Destroy()
    end

    self._statusLoopHandle = self.StatusLoop.Start(refs, {
        noSlowdown = noSlowdown,
        noStun = noStun,
        speedMultiplier = speedMultiplier,
        gravityController = gravityController,
        floatController = floatController,
        jumpBoost = jumpBoost,
        noclip = noclip,
        zenith = zenith,
    }, self.LabelUtils)

    return Tab
end

function Controller:Destroy()
    if self._statusLoopHandle and self._statusLoopHandle.Destroy then
        self._statusLoopHandle:Destroy()
        self._statusLoopHandle = nil
    end
end

return Controller
]====],
    ["UI/Tabs/Player/LabelUtils.lua"] = [====[--[[
    LabelUtils.lua - Shared label helpers for Player tab UI
]]

local LabelUtils = {}

function LabelUtils.SetText(label, text)
    if not label then
        return
    end

    if type(label) == "table" and type(label.Set) == "function" then
        local ok = pcall(function()
            label:Set(text)
        end)
        if ok then
            return
        end
    end

    if typeof(label) == "Instance" then
        local textLabel = label:IsA("TextLabel") and label or label:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then
            textLabel.Text = text
        end
    end
end

return LabelUtils
]====],
    ["UI/Tabs/Player/Layout.lua"] = [====[--[[
    Layout.lua - Player tab layout builder
]]

local Layout = {}

function Layout.Build(Tab, Options)
    local refs = {}

    Tab:CreateSection("Movement")

    Tab:CreateToggle({
        Name = "Fixed Move Speed",
        CurrentValue = Options.CustomMoveSpeedEnabled,
        Flag = "CustomMoveSpeedEnabledFlag",
        Callback = function(Value)
            Options.CustomMoveSpeedEnabled = Value
            if Value then
                Options.SpeedMultiplierEnabled = false
            end
        end,
    })

    Tab:CreateSection("Legit Multiplier")

    Tab:CreateToggle({
        Name = "Speed Multiplier",
        CurrentValue = Options.SpeedMultiplierEnabled,
        Flag = "SpeedMultiplierEnabledFlag",
        Callback = function(Value)
            Options.SpeedMultiplierEnabled = Value
            if Value then
                Options.CustomMoveSpeedEnabled = false
            end
        end,
    })

    refs.speedMultiplierLabel = Tab:CreateLabel("Multi Speed Status: Idle")

    Tab:CreateSection("Mobility")

    Tab:CreateToggle({
        Name = "Jump Boost",
        CurrentValue = Options.JumpBoostEnabled,
        Flag = "JumpBoostEnabledFlag",
        Callback = function(Value)
            Options.JumpBoostEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Noclip",
        CurrentValue = Options.NoclipEnabled,
        Flag = "NoclipEnabledFlag",
        Callback = function(Value)
            Options.NoclipEnabled = Value
        end,
    })
    
    refs.noclipLabel = Tab:CreateLabel("Noclip Status: Idle")

    refs.zenithLabel = Tab:CreateLabel("Zenith Desync: Idle")

    Tab:CreateToggle({
        Name = "Float",
        CurrentValue = Options.FloatEnabled,
        Flag = "FloatEnabledFlag",
        Callback = function(Value)
            Options.FloatEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Custom Gravity",
        CurrentValue = Options.GravityEnabled,
        Flag = "GravityEnabledFlag",
        Callback = function(Value)
            Options.GravityEnabled = Value
        end,
    })

    refs.jumpBoostLabel = Tab:CreateLabel("Jump Boost Status: Idle")
    refs.floatLabel = Tab:CreateLabel("Float Status: Idle")
    refs.gravityLabel = Tab:CreateLabel("Gravity Status: Idle")

    Tab:CreateSection("Anti-Debuff")

    refs.slowdownLabel = Tab:CreateLabel("No Slowdown: Idle")
    Tab:CreateToggle({
        Name = "No Slowdown",
        CurrentValue = Options.NoSlowdown,
        Flag = "NoSlowdownFlag",
        Callback = function(Value)
            Options.NoSlowdown = Value
        end,
    })

    refs.stunLabel = Tab:CreateLabel("No Stun: Idle")
    Tab:CreateToggle({
        Name = "No Stun",
        CurrentValue = Options.NoStun,
        Flag = "NoStunFlag",
        Callback = function(Value)
            Options.NoStun = Value
        end,
    })

    Tab:CreateToggle({
        Name = "No Delay (Attribute Cleaner)",
        CurrentValue = Options.NoDelay,
        Flag = "NoDelayFlag",
        Callback = function(Value)
            Options.NoDelay = Value
        end,
    })

    Tab:CreateSection("Custom")

    Tab:CreateSlider({
        Name = "Walk Speed (Fixed)",
        Range = { 1, 250 },
        Increment = 1,
        CurrentValue = Options.CustomMoveSpeed or 16,
        Flag = "CustomMoveSpeedFlag",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.CustomMoveSpeed = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Multiplier Factor",
        Range = { 1, 5 },
        Increment = 0.1,
        CurrentValue = Options.SpeedMultiplier or 1.0,
        Flag = "SpeedMultiplierFlag",
        Suffix = "x",
        Callback = function(Value)
            Options.SpeedMultiplier = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Jump Power",
        Range = { 1, 300 },
        Increment = 1,
        CurrentValue = Options.JumpBoostPower or 70,
        Flag = "JumpBoostPowerFlag",
        Callback = function(Value)
            Options.JumpBoostPower = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Float Fall Speed",
        Range = { 0, 40 },
        Increment = 1,
        CurrentValue = Options.FloatFallSpeed or 8,
        Flag = "FloatFallSpeedFlag",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.FloatFallSpeed = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Gravity Value",
        Range = { 0, 500 },
        Increment = 1,
        CurrentValue = Options.GravityValue or 196.2,
        Flag = "GravityValueFlag",
        Callback = function(Value)
            Options.GravityValue = Value
        end,
    })

    return refs
end

return Layout
]====],
    ["UI/Tabs/Player/StatusLoop.lua"] = [====[--[[
    StatusLoop.lua - Player tab active status refresh loop
]]

local StatusLoop = {}

function StatusLoop.Start(refs, deps, labelUtils)
    local handle = {
        Alive = true,
    }

    task.spawn(function()
        local lastSlowdownText
        local lastStunText
        local lastSpeedText
        local lastJumpText
        local lastFloatText
        local lastGravityText
        local lastNoclipText
        local lastGodText

        while handle.Alive do
            if deps.noSlowdown then
                local nextText = "Slowdown Status: " .. tostring(deps.noSlowdown.Status)
                if nextText ~= lastSlowdownText then
                    labelUtils.SetText(refs.slowdownLabel, nextText)
                    lastSlowdownText = nextText
                end
            end

            if deps.noStun then
                local nextText = "Stun Status: " .. tostring(deps.noStun.Status)
                if nextText ~= lastStunText then
                    labelUtils.SetText(refs.stunLabel, nextText)
                    lastStunText = nextText
                end
            end

            if deps.speedMultiplier then
                local nextText = "Multi Speed Status: " .. tostring(deps.speedMultiplier.Status)
                if nextText ~= lastSpeedText then
                    labelUtils.SetText(refs.speedMultiplierLabel, nextText)
                    lastSpeedText = nextText
                end
            end

            if deps.jumpBoost then
                local nextText = "Jump Boost Status: " .. tostring(deps.jumpBoost.Status)
                if nextText ~= lastJumpText then
                    labelUtils.SetText(refs.jumpBoostLabel, nextText)
                    lastJumpText = nextText
                end
            end

            if deps.floatController then
                local nextText = "Float Status: " .. tostring(deps.floatController.Status)
                if nextText ~= lastFloatText then
                    labelUtils.SetText(refs.floatLabel, nextText)
                    lastFloatText = nextText
                end
            end

            if deps.gravityController then
                local nextText = "Gravity Status: " .. tostring(deps.gravityController.Status)
                if nextText ~= lastGravityText then
                    labelUtils.SetText(refs.gravityLabel, nextText)
                    lastGravityText = nextText
                end
            end

            if deps.noclip then
                local nextText = "Noclip Status: " .. tostring(deps.noclip.Status)
                if nextText ~= lastNoclipText then
                    labelUtils.SetText(refs.noclipLabel, nextText)
                    lastNoclipText = nextText
                end
            end

            if deps.zenith then
                local nextText = "Zenith Desync: " .. tostring(deps.zenith.Status)
                if nextText ~= lastGodText then
                    labelUtils.SetText(refs.zenithLabel, nextText)
                    lastGodText = nextText
                end
            end

            task.wait(0.5)
        end
    end)

    function handle:Destroy()
        self.Alive = false
    end

    return handle
end

return StatusLoop
]====],
    ["UI/Tabs/PlayerTab.lua"] = [====[--[[
    PlayerTab.lua - Compatibility wrapper
    Job: Delegate Player tab construction to an injected controller.
]]

return function(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, zenith, controller)
    if controller and controller.Build then
        return controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, zenith)
    end

    error("PlayerTab controller was not provided", 2)
end
]====],
    ["UI/Tabs/PredictionTab.lua"] = [====[--[[
    PredictionTab.lua - Tab Prediction
    Prediction engine switches and range controls.
]]

return function(Window, Options)
    local Tab = Window:CreateTab("Prediction", 4483362458)

    Tab:CreateSection("Prediction Engine")

    Tab:CreateToggle({
        Name = "Enable Aim Prediction",
        CurrentValue = Options.PredictionEnabled,
        Flag = "PredictToggle",
        Callback = function(Value)
            Options.PredictionEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Smart Prediction (Auto)",
        CurrentValue = Options.SmartPrediction,
        Flag = "SmartPredictToggle",
        Callback = function(Value)
            Options.SmartPrediction = Value
        end,
    })

    Tab:CreateDropdown({
        Name = "Technique Control",
        Options = {"Assisted", "Manual"},
        CurrentOption = {Options.PredictionTechniqueMode or "Assisted"},
        Flag = "PredictionTechniqueModeFlag",
        Callback = function(Value)
            Options.PredictionTechniqueMode = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateDropdown({
        Name = "Manual Technique",
        Options = {"Linear", "Strafe", "Orbit", "Airborne", "Dash Recovery"},
        CurrentOption = {Options.PredictionTechnique or "Linear"},
        Flag = "PredictionTechniqueFlag",
        Callback = function(Value)
            Options.PredictionTechnique = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateToggle({
        Name = "Technique Debug Overlay",
        CurrentValue = Options.PredictionTechniqueDebug == true,
        Flag = "PredictionTechniqueDebugFlag",
        Callback = function(Value)
            Options.PredictionTechniqueDebug = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Projectile Velocity",
        Range = {50, 5000},
        Increment = 25,
        Suffix = " studs/s",
        CurrentValue = Options.ProjectileVelocity,
        Flag = "ProjectileVelocitySlider",
        Callback = function(Value)
            Options.ProjectileVelocity = Value
        end,
    })

    Tab:CreateSection("Target Response")

    Tab:CreateSlider({
        Name = "Maximum Distance",
        Range = {100, 5000},
        Increment = 50,
        Suffix = " Studs",
        CurrentValue = Options.MaxDistance,
        Flag = "DistanceSlider",
        Callback = function(Value)
            Options.MaxDistance = Value
        end,
    })

    return Tab
end
]====],
    ["UI/Tabs/SettingsTab.lua"] = [====[--[[
    SettingsTab.lua - Settings and script management
    UI toggle key, config actions, and maintenance tools.
]]

return function(Window, Options, cleaner, resourceManager, tracker, taskScheduler)
    local Tab = Window:CreateTab("Settings", 4483362458)
    local controller = {
        Tab = Tab,
        Alive = true,
    }

    local function setLabelText(label, text)
        if not label then
            return
        end

        if type(label) == "table" and type(label.Set) == "function" then
            local ok = pcall(function()
                label:Set(text)
            end)
            if ok then
                return
            end
        end

        if typeof(label) == "Instance" then
            local textLabel = label:IsA("TextLabel") and label or label:FindFirstChildWhichIsA("TextLabel", true)
            if textLabel then
                textLabel.Text = text
            end
        end
    end

    Tab:CreateSection("Optimization & Safety")

    local cleanerLabel = Tab:CreateLabel("Cleanup Status: Idle")
    local resourceLabel = Tab:CreateLabel("Resource Manager: Idle")
    local trackerLabel = Tab:CreateLabel("Tracker Entries: Hidden")
    local schedulerLabel = Tab:CreateLabel("Task Scheduler: Hidden")
    local resourcePendingLabel = Tab:CreateLabel("Resource Pending: Hidden")

    Tab:CreateToggle({
        Name = "Auto-Clean Debris",
        CurrentValue = Options.AutoCleanEnabled,
        Flag = "AutoCleanFlag",
        Callback = function(Value)
            Options.AutoCleanEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Smart Cleanup Scheduler",
        CurrentValue = Options.SmartCleanupEnabled ~= false,
        Flag = "SmartCleanupEnabledFlag",
        Callback = function(Value)
            Options.SmartCleanupEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Runtime Stats Debug",
        CurrentValue = Options.RuntimeStatsDebug == true,
        Flag = "RuntimeStatsDebugFlag",
        Callback = function(Value)
            Options.RuntimeStatsDebug = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Auto Clean + Update",
        CurrentValue = Options.AutoUpdateEnabled == true,
        Flag = "AutoUpdateEnabledFlag",
        Callback = function(Value)
            Options.AutoUpdateEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Rejoin on Kick",
        CurrentValue = Options.RejoinOnKickEnabled == true,
        Flag = "RejoinOnKickEnabledFlag",
        Callback = function(Value)
            Options.RejoinOnKickEnabled = Value
        end,
    })

    Tab:CreateButton({
        Name = "Clean Memory & Debris Now",
        Callback = function()
            if cleaner then
                local destroyed, found, deferred, remaining = cleaner:Clean()
                Rayfield:Notify({
                    Title = "Cleanup Scheduled",
                    Content = string.format(
                        "Found %d debris, destroyed %d now, deferred %d, remaining local %d.",
                        found or 0,
                        destroyed or 0,
                        deferred or 0,
                        remaining or 0
                    ),
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("UI & Controls")

    Tab:CreateDropdown({
        Name = "UI Toggle Key (saved for next reload)",
        Options = {
            "RightControl", "LeftControl", "RightShift", "LeftShift",
            "RightAlt", "LeftAlt", "Backquote", "Insert",
            "Home", "End", "PageUp", "PageDown",
            "F1", "F2", "F3", "F4", "F6", "F7", "F8", "F9", "F10",
        },
        CurrentOption = { Options.ToggleUIKey or "RightControl" },
        Flag = "ToggleUIKey",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.ToggleUIKey = selected
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = "UI Key Updated",
                    Content = "UI toggle key saved as " .. tostring(selected) .. ". It applies immediately and will persist after reload.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateButton({
        Name = "Destroy Script (Emergency Stop)",
        Callback = function()
            if _G.BossAimAssist_Cleanup then
                task.defer(function()
                    _G.BossAimAssist_Cleanup(true)
                end)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Run Clean + Update Now",
        Callback = function()
            local updater = _G.BossAimAssist_Update
            if updater then
                task.defer(updater)
            elseif _G.BossAimAssist_Cleanup then
                task.defer(function()
                    _G.BossAimAssist_Cleanup(true)
                end)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Check for Updates",
        Callback = function()
            if _G.BossAimAssist_CheckForUpdates then
                _G.BossAimAssist_CheckForUpdates(true)
            elseif Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = "Updater Unavailable",
                    Content = "This runtime does not expose the update checker yet. Reload from Main.lua.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("Configuration")

    Tab:CreateButton({
        Name = "Save Current Config",
        Callback = function()
            Rayfield:SaveConfiguration()
        end,
    })

    Tab:CreateButton({
        Name = "Rejoin Server (Same Instance)",
        Callback = function()
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
        end,
    })

    Tab:CreateButton({
        Name = "Server Hop (Join New Instance)",
        Callback = function()
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            local http = game:GetService("HttpService")

            pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
                local content = game:HttpGet(url)
                local data = http:JSONDecode(content)

                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        ts:TeleportToPlaceInstance(game.PlaceId, s.id, p)
                        return
                    end
                end

                Rayfield:Notify({
                    Title = "Server Hop Failed",
                    Content = "No suitable new servers found at this time.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end)
        end,
    })

    Tab:CreateSection("Script Management")

    task.spawn(function()
        local lastCleanerText
        local lastResourceText
        local lastTrackerText
        local lastSchedulerText
        local lastResourcePendingText

        while controller.Alive do
            if cleaner then
                local nextText = "Cleanup Status: " .. tostring(cleaner.Status)
                if nextText ~= lastCleanerText then
                    setLabelText(cleanerLabel, nextText)
                    lastCleanerText = nextText
                end
            end
            if resourceManager then
                local nextText = string.format(
                    "Resource Manager: %s",
                    tostring(resourceManager.Status)
                )
                if nextText ~= lastResourceText then
                    setLabelText(resourceLabel, nextText)
                    lastResourceText = nextText
                end
            end

            local statsEnabled = Options.RuntimeStatsDebug == true
            local trackerText = statsEnabled
                and string.format("Tracker Entries: %d", tracker and tracker.GetEntryCount and tracker:GetEntryCount() or 0)
                or "Tracker Entries: Hidden"
            if trackerText ~= lastTrackerText then
                setLabelText(trackerLabel, trackerText)
                lastTrackerText = trackerText
            end

            local schedulerText = statsEnabled
                and string.format("Task Scheduler: %d pending", taskScheduler and taskScheduler.GetPendingCount and taskScheduler:GetPendingCount() or 0)
                or "Task Scheduler: Hidden"
            if schedulerText ~= lastSchedulerText then
                setLabelText(schedulerLabel, schedulerText)
                lastSchedulerText = schedulerText
            end

            local resourcePendingText = statsEnabled
                and string.format("Resource Pending: %d", resourceManager and resourceManager.GetPendingCount and resourceManager:GetPendingCount() or 0)
                or "Resource Pending: Hidden"
            if resourcePendingText ~= lastResourcePendingText then
                setLabelText(resourcePendingLabel, resourcePendingText)
                lastResourcePendingText = resourcePendingText
            end

            task.wait(0.5)
        end
    end)

    Tab:CreateToggle({
        Name = "Auto-Execute",
        CurrentValue = Options.AutoExecuteEnabled or false,
        Flag = "AutoExecuteFlag",
        Callback = function(Value)
            Options.AutoExecuteEnabled = Value
            if Value then
                local command = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/STAR%20GLITCHER%20~%20REVITALIZED/Main.lua?v=" .. tostring(os.time())))()]]
                if writefile then
                    pcall(function()
                        writefile("BossAimAssist_Loader.lua", command)
                        Rayfield:Notify({
                            Title = "Auto-Execute Enabled",
                            Content = "Loader saved to workspace/BossAimAssist_Loader.lua. Move this to your autoexec folder.",
                            Duration = 5,
                            Image = 4483362458,
                        })
                    end)
                else
                    Rayfield:Notify({
                        Title = "Error",
                        Content = "Your executor does not support writefile.",
                        Duration = 5,
                        Image = 4483362458,
                    })
                end
            else
                if delfile then
                    pcall(function()
                        delfile("BossAimAssist_Loader.lua")
                        Rayfield:Notify({
                            Title = "Auto-Execute Disabled",
                            Content = "Loader file removed from workspace.",
                            Duration = 5,
                            Image = 4483362458,
                        })
                    end)
                end
            end
        end,
    })

    Tab:CreateSection("Custom")

    Tab:CreateSlider({
        Name = "Update Check Interval",
        Range = { 1, 30 },
        Increment = 1,
        CurrentValue = Options.AutoUpdateIntervalMinutes or 5,
        Flag = "AutoUpdateIntervalMinutesFlag",
        Suffix = " min",
        Callback = function(Value)
            Options.AutoUpdateIntervalMinutes = Value
        end,
    })

    function controller:Destroy()
        self.Alive = false
    end

    return controller
end
]====],
    ["UI/Tabs/TeleportTab.lua"] = [====[return function(Window, Options, waypointTeleport)
    local Tab = Window:CreateTab("Teleport", 4483362458)

    local waypointDropdown = Tab:CreateDropdown({
        Name = "Waypoint List",
        Options = waypointTeleport and waypointTeleport:GetWaypointNames() or { "(No waypoints yet)" },
        CurrentOption = { waypointTeleport and waypointTeleport.SelectedWaypointName or "(No waypoints yet)" },
        Flag = "TeleportWaypointDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            if waypointTeleport then
                waypointTeleport:SetSelectedWaypoint(selected)
            end
        end,
    })

    if waypointTeleport then
        waypointTeleport:SetDropdown(waypointDropdown)
    end

    Tab:CreateButton({
        Name = "Set Waypoint",
        Callback = function()
            if not waypointTeleport then
                return
            end

            local ok, detail = waypointTeleport:SetWaypoint()
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = ok and "Waypoint Saved" or "Waypoint Failed",
                    Content = ok and ("Saved " .. tostring(detail)) or tostring(detail),
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateButton({
        Name = "Go To Selected Waypoint",
        Callback = function()
            if not waypointTeleport then
                return
            end

            local ok, detail = waypointTeleport:GotoSelectedWaypoint()
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = ok and "Teleport Started" or "Teleport Failed",
                    Content = ok and ("Heading to " .. tostring(detail) .. " via " .. tostring(Options.TeleportMethod or "Tween")) or tostring(detail),
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateDropdown({
        Name = "Method",
        Options = { "Tween", "Teleport" },
        CurrentOption = { Options.TeleportMethod or "Tween" },
        Flag = "TeleportMethodDropdown",
        Callback = function(Value)
            Options.TeleportMethod = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateSection("Custom")

    Tab:CreateSlider({
        Name = "Tween Speed",
        Range = { 10, 1000 },
        Increment = 10,
        CurrentValue = Options.TeleportTweenSpeed or 150,
        Flag = "TeleportTweenSpeedSlider",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.TeleportTweenSpeed = Value
        end,
    })

    return Tab
end
]====]
}

local function loadBundledModule(path)
    local source = BUNDLED_SOURCES[path]
    if not source then
        error("Missing bundled module: " .. tostring(path))
    end

    local chunk, compileErr = loadstring(source, "=" .. path)
    if not chunk then
        error("Bundled compile failed for " .. tostring(path) .. ": " .. tostring(compileErr))
    end

    return chunk()
end

local function loadModule(path)
    local ok, result = pcall(loadBundledModule, path)
    if ok then
        return result
    end

    warn("[Bundle] Failed: " .. tostring(path) .. " | Error: " .. tostring(result))
    return nil
end

local function requireModule(path)
    local module = loadModule(path)
    if module == nil then
        error("Required module failed to load: " .. tostring(path))
    end
    return module
end

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera

-- Core Data
local Config  = requireModule("Data/Config.lua")
local Version = requireModule("Data/Version.lua")
local Options = Config.Options
local Normalize = requireModule("Modules/Core/Bootstrap/Normalize.lua")
local RayfieldUI = requireModule("Modules/Core/Bootstrap/RayfieldUI.lua")

if _G.BossAimAssist_Cleanup then
    _G.BossAimAssist_Cleanup()
end

-- UI initialization
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().Rayfield = Rayfield

Options.ToggleUIKey = Normalize.ToggleUIKey(Options.ToggleUIKey)
Options.TargetingMethod = Normalize.TargetingMethod(Options.TargetingMethod)

local Window = RayfieldUI.CreateWindow(Rayfield)

-- ===================================================
-- LOAD ALL MODULES (Scientific Order)
-- ===================================================
local Brain          = requireModule("Modules/Core/Brain.lua")
local InputHandler   = requireModule("Modules/Utils/Input.lua")
local Tracker        = requireModule("Modules/Utils/NPCTracker.lua")
local Detector       = requireModule("Modules/Utils/BossDetector.lua")
local LocalCharacter = requireModule("Modules/Utils/LocalCharacter.lua")
local Synapse         = requireModule("Modules/Utils/Synapse.lua")
local Kalman          = requireModule("Modules/Utils/Math/Kalman.lua")
local ResourceManager = requireModule("Modules/Utils/ResourceManager.lua")
local TaskScheduler   = requireModule("Modules/Utils/TaskScheduler.lua")
local DataPruner      = requireModule("Modules/Utils/DataPruner.lua")

local Predictor       = requireModule("Modules/Combat/Predictor.lua")
local SilentResolver  = requireModule("Modules/Combat/Prediction/SilentResolver.lua")
local GarbageCollector = requireModule("Modules/Utils/GarbageCollector.lua")
local Selector        = requireModule("Modules/Combat/TargetSelector.lua")
local Aimbot          = requireModule("Modules/Combat/Aimbot.lua")
local SilentAim       = requireModule("Modules/Combat/SilentAim.lua")

local SpeedSpoof      = requireModule("Modules/Movement/SpeedSpoof.lua")
local MovementArbiter = requireModule("Modules/Movement/MovementArbiter.lua")
local SpeedMultiplier = requireModule("Modules/Movement/SpeedMultiplier.lua")
local CustomSpeed     = requireModule("Modules/Movement/CustomSpeed.lua")
local GravityController = requireModule("Modules/Movement/GravityController.lua")
local FloatController = requireModule("Modules/Movement/FloatController.lua")
local JumpBoost      = requireModule("Modules/Movement/JumpBoost.lua")
local AntiSlowdown    = requireModule("Modules/Movement/AntiSlowdown.lua")
local AntiStun        = requireModule("Modules/Movement/AntiStun.lua")
local Noclip          = requireModule("Modules/Movement/Noclip.lua")
local KillPartBypass  = requireModule("Modules/Movement/KillPartBypass.lua")
local ProactiveEvade  = requireModule("Modules/Movement/ProactiveEvade.lua")
local HitboxDesync    = requireModule("Modules/Movement/HitboxDesync.lua")
local WaypointTeleport = requireModule("Modules/Movement/WaypointTeleport.lua")
local Cleaner         = requireModule("Modules/Movement/AttributeCleaner.lua")

local FOVCircle       = requireModule("Modules/Visuals/FOVCircle.lua")
local Highlight       = requireModule("Modules/Visuals/Highlight.lua")
local TechniqueOverlay = requireModule("Modules/Visuals/TechniqueOverlay.lua")
local TargetDot       = requireModule("Modules/Visuals/TargetDot.lua")
local PlayerLabelUtils = requireModule("UI/Tabs/Player/LabelUtils.lua")
local PlayerLayout = requireModule("UI/Tabs/Player/Layout.lua")
local PlayerStatusLoop = requireModule("UI/Tabs/Player/StatusLoop.lua")
local PlayerController = requireModule("UI/Tabs/Player/Controller.lua")

-- ===================================================
-- INSTANTIATE (OOP Injection)
-- ===================================================
local synapse    = Synapse
local taskScheduler = TaskScheduler.new(Options)
local input      = InputHandler.new(Config)
local localCharacter = LocalCharacter.new(taskScheduler)
local movementArbiter = MovementArbiter.new(Options, localCharacter)
local detector   = Detector.new()
local tracker    = Tracker.new(Config, detector, taskScheduler)
local aimbot     = Aimbot.new(Config)
local silentResolver = SilentResolver.new(Config)
local silentAim  = SilentAim.new(Config, synapse, silentResolver) 
local playerTabController = PlayerController.new(PlayerLayout, PlayerStatusLoop, PlayerLabelUtils)
local waypointTeleport = WaypointTeleport.new(Options, localCharacter)
local resourceManager = ResourceManager.new(Options)
local cleaner    = GarbageCollector.new(Options, resourceManager)

local pred       = Predictor.new(Config, loadModule, Kalman)
local selector   = Selector.new(Config, tracker, pred)
local dataPruner = DataPruner.new(taskScheduler, tracker, pred)

local visuals = {
    fov = FOVCircle.new(Options),
    highlight = Highlight.new(),
    technique = TechniqueOverlay.new(Options),
    dot = TargetDot.new()
}

local movementSuite = {
    spoof = SpeedSpoof.new(Options, localCharacter),
    arbiter = movementArbiter,
    multi = SpeedMultiplier.new(Options, localCharacter, movementArbiter),
    fixed = CustomSpeed.new(Options, localCharacter, movementArbiter),
    gravity = GravityController.new(Options),
    float = FloatController.new(Options, localCharacter),
    jump = JumpBoost.new(Options, localCharacter, movementArbiter),
    slow  = AntiSlowdown.new(Options, localCharacter, movementArbiter),
    stun  = AntiStun.new(Options, localCharacter),
    noclip = Noclip.new(Options, localCharacter),
    killPart = KillPartBypass.new(Options, localCharacter),
    proactiveEvade = ProactiveEvade.new(Options, localCharacter),
    zenith = HitboxDesync.new(Options, localCharacter),
    clean = Cleaner.new(Options, localCharacter)
}

-- THE CENTRAL BRAIN (CNS)
local brain = Brain.new(Config, {
    Input = input, Tracker = tracker, Predictor = pred, Selector = selector,
    Aimbot = aimbot, SilentAim = silentAim, Visuals = visuals
}, loadModule)

-- ===================================================
-- INITIALIZE & SETUP UI
-- ===================================================
input:Init()
taskScheduler:Init()
localCharacter:Init()
detector:Init()
tracker:Init()
aimbot:Init()
selector:Init()
silentAim:Init()
dataPruner:Init()
resourceManager:Init()
cleaner:Init()
for _, m in pairs(movementSuite) do if m.Init then m:Init() end end

requireModule("UI/Tabs/AimbotTab.lua")(Window, Options, {FOVCircle = visuals.fov.Drawing}, tracker)
requireModule("UI/Tabs/PredictionTab.lua")(Window, Options)
requireModule("UI/Tabs/PlayerTab.lua")(Window, Options, movementSuite.slow, movementSuite.stun, movementSuite.multi, movementSuite.gravity, movementSuite.float, movementSuite.jump, movementSuite.noclip, movementSuite.zenith, playerTabController)
requireModule("UI/Tabs/TeleportTab.lua")(Window, Options, waypointTeleport)
requireModule("UI/Tabs/BlatantTab.lua")(Window, Options, movementSuite.killPart, movementSuite.proactiveEvade)
local settingsTabController = requireModule("UI/Tabs/SettingsTab.lua")(Window, Options, cleaner, resourceManager, tracker, taskScheduler)

local loadConfigOk, loadConfigErr = RayfieldUI.SafeLoadConfiguration(Rayfield)
if not loadConfigOk then
    warn("[Config] LoadConfiguration failed, continuing with runtime defaults | Error: " .. tostring(loadConfigErr))
end
Options.TargetingMethod = Normalize.TargetingMethod(Options.TargetingMethod)

-- ===================================================
-- MAIN ORCHESTRATION LOOP (Brain Powered)
-- ===================================================
local SESSION_ID = os.time()
_G.BossAimAssist_SessionID = SESSION_ID

local _conns = {}
local function reg(c)
    table.insert(_conns, c)
    if resourceManager then
        resourceManager:TrackConnection(c)
    end
    return c
end

local function attemptRejoinAfterKick(reason)
    if Options.RejoinOnKickEnabled ~= true then
        return
    end

    local player = Players.LocalPlayer
    if not player then
        return
    end

    task.spawn(function()
        task.wait(1.5)

        local teleported = false
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
            teleported = true
        end)

        if not ok or not teleported then
            warn("[KickRejoin] Teleport failed, trying same instance | Error: " .. tostring(err))
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            end)
        end
    end)
end

local function isKickLikeMessage(message)
    local text = string.lower(tostring(message or ""))
    if text == "" then
        return false
    end

    return text:find("kick", 1, true) ~= nil
        or text:find("kicked", 1, true) ~= nil
        or text:find("banned", 1, true) ~= nil
        or text:find("disconnected", 1, true) ~= nil
        or text:find("connection error", 1, true) ~= nil
end

reg(GuiService.ErrorMessageChanged:Connect(function()
    local message = GuiService:GetErrorMessage()
    if isKickLikeMessage(message) then
        attemptRejoinAfterKick(message)
    end
end))

local function performCleanup(fullSweep)
    pcall(function()
        Rayfield:Destroy()
    end)

    for _, connection in ipairs(_conns) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(_conns)

    local objs = {
        input, localCharacter, detector, tracker, pred, selector, aimbot, silentAim,
        cleaner, visuals.fov, visuals.highlight, visuals.technique, visuals.dot, brain,
        taskScheduler, dataPruner, waypointTeleport,
        playerTabController, settingsTabController
    }
    for _, obj in pairs(movementSuite) do
        objs[#objs + 1] = obj
    end

    if resourceManager then
        resourceManager:DeferCleanup(function()
            Synapse.clearAll()
        end)

        for _, obj in ipairs(objs) do
            resourceManager:TrackObject(obj)
        end
        resourceManager:ScheduleTrackedCleanup()
        resourceManager:Flush(fullSweep and 1.5 or 0.75)
    else
        for _, obj in ipairs(objs) do
            if obj and obj.Destroy then
                pcall(function()
                    obj:Destroy()
                end)
            end
        end

        Synapse.clearAll()
    end

    _G.BossAimAssist_SessionID = nil
    _G.BossAimAssist_Update = nil
    _G.BossAimAssist_Cleanup = nil
    _G.BossAimAssist_CheckForUpdates = nil
    _G.__STAR_GLITCHER_AUTOUPDATE_BOOTED = nil

    local silentHook = getgenv and getgenv().__STAR_GLITCHER_SILENT_AIM_HOOK
    if silentHook then
        silentHook.Instance = nil
    end

    local apocalypseHook = getgenv and getgenv().__STAR_GLITCHER_APOCALYPSE_HOOK
    if apocalypseHook then
        apocalypseHook.Instance = nil
    end

    if fullSweep then
        pcall(function()
            if cleaner and cleaner.Clean then
                cleaner:Clean()
            end
        end)
        if resourceManager then
            resourceManager:Boost(1.5)
            resourceManager:Flush(1.5)
        end
        pcall(function()
            collectgarbage("count")
            collectgarbage("count")
        end)
    end

    if resourceManager then
        pcall(function()
            resourceManager:Destroy()
        end)
    end
end

_G.BossAimAssist_Cleanup = function(fullSweep)
    performCleanup(fullSweep == true)
end

local function executeUpdatedEntry(url, chunkName)
    local content = game:HttpGet(url)
    local chunk = compileChunk(content, chunkName)
    return chunk()
end

_G.BossAimAssist_Update = function()
    local updateUrl = UPDATE_ENTRY_URL .. "?update=" .. tostring(os.time())
    task.spawn(function()
        task.wait(0.15)
        local ok, result = pcall(function()
            return executeUpdatedEntry(updateUrl, "=updated-entry")
        end)
        if not ok then
            warn("[Update] Reload failed after cleanup | Error: " .. tostring(result))
        end
    end)
    task.defer(function()
        performCleanup(true)
    end)
end

_G.BossAimAssist_CheckForUpdates = function(manual)
    local ok, remoteVersion = pcall(fetchRemoteVersion)

    if not ok then
        if manual and Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title = "Update Check Failed",
                Content = "Version check failed. The remote file responded, but parsing or access failed.",
                Duration = 5,
                Image = 4483362458,
            })
        end
        return false
    end

    remoteVersion = tonumber(remoteVersion) or 0
    local currentVersion = tonumber(Version) or 0

    if remoteVersion > currentVersion then
        if Rayfield and Rayfield.Notify then
            Rayfield:Notify({
                Title = "Update Found",
                Content = string.format("Updating from r%d to r%d.", currentVersion, remoteVersion),
                Duration = 3,
                Image = 4483362458,
            })
        end
        task.spawn(function()
            task.wait(0.35)
            local updater = _G.BossAimAssist_Update
            if updater then
                updater()
            end
        end)
        return true
    end

    if manual and Rayfield and Rayfield.Notify then
        Rayfield:Notify({
            Title = "Up To Date",
            Content = string.format("Current runtime r%d is already the newest version.", currentVersion),
            Duration = 4,
            Image = 4483362458,
        })
    end

    return false
end

if not _G.__STAR_GLITCHER_AUTOUPDATE_BOOTED then
    _G.__STAR_GLITCHER_AUTOUPDATE_BOOTED = true
    task.spawn(function()
        task.wait(1)
        if _G.BossAimAssist_CheckForUpdates then
            _G.BossAimAssist_CheckForUpdates(false)
        end
    end)
end

if not autoUpdateLoopStarted then
    autoUpdateLoopStarted = true
    task.spawn(function()
        local lastCheck = 0

        while _G.BossAimAssist_SessionID == SESSION_ID do
            task.wait(5)

            if not Options.AutoUpdateEnabled then
                lastCheck = os.clock()
                continue
            end

            local now = os.clock()
            local intervalSeconds = math.max(1, tonumber(Options.AutoUpdateIntervalMinutes) or 5) * 60
            if (now - lastCheck) < intervalSeconds then
                continue
            end

            lastCheck = now
            local checker = _G.BossAimAssist_CheckForUpdates
            if checker then
                checker(false)
            end
        end
    end)
end

-- Scanning (Heartbeat, Off render)
reg(RunService.Heartbeat:Connect(function(dt)
    brain:Scan(UserInputService:GetMouseLocation(), Camera.CFrame.Position, dt)
end))

reg(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    if input.KeyCode ~= Normalize.ToggleUIKeyCode(Options.ToggleUIKey) then
        return
    end

    local screenGuis = RayfieldUI.GetScreenGuis(CoreGui)
    if #screenGuis == 0 then
        return
    end

    local nextEnabledState = true
    for _, ui in ipairs(screenGuis) do
        if ui.Enabled then
            nextEnabledState = false
            break
        end
    end

    for _, ui in ipairs(screenGuis) do
        ui.Enabled = nextEnabledState
    end
end))

-- Execution (RenderStepped)
reg(RunService.RenderStepped:Connect(function(dt)
    brain:Update(dt, UserInputService:GetMouseLocation(), Camera.CFrame)
end))

warn(" [Core] Brain Orchestration v6 Active.")

