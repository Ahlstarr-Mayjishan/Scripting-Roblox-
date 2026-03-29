--[[
    Config.lua — Shared Configuration Module
    Chứa toàn bộ Options, Constants, Blacklist, và PvP Profile.
    Mọi module khác đều đọc/ghi vào đây.
]]

local Config = {}

-- ═══════════════════════════════════════════════════
-- OPTIONS: Cấu hình người dùng (Rayfield sẽ ghi đè qua UI)
-- ═══════════════════════════════════════════════════
Config.Options = {
    AssistMode = "Off",
    HoldMouse2ToAssist = true,
    PredictionEnabled = true,
    TargetPlayersToggle = false,
    SmartPrediction = true,
    TargetPart = "HumanoidRootPart",
    AimOffset = 0,
    FOV = 150,
    ShowFOV = true,
    Smoothness = 0.18,
    MaxDistance = 1500,
    TargetRefreshInterval = 0.015,
    HomingProjectiles = false,
    InstantBullet = false,
    HomingStrength = 0.85,
    ProjectileVelocity = 250,
    SilentAim = true,
    NoSlowdown = false,
    NoDelay = false,
    OriginalWalkSpeed = nil, -- Lưu WalkSpeed gốc để khôi phục
}

-- ═══════════════════════════════════════════════════
-- PREDICTION CONSTANTS
-- ═══════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════
-- PVP PREDICTION PROFILE
-- ═══════════════════════════════════════════════════
Config.PvP = {
    PING_MULTIPLIER = 2.0,
    MAX_LEAD_DIST = 180,
    ZIGZAG_DAMPEN = 0.55,
    JUMP_GRAVITY = -196.2,
    JUMP_ARC_BLEND = 0.7,
    KALMAN_Q_BOOST = 0.3,
    ACCEL_CORRECTION_CAP = 0.25,
}

-- ═══════════════════════════════════════════════════
-- TARGET BLACKLIST
-- ═══════════════════════════════════════════════════
Config.Blacklist = {
    "statue", "tuong", "monument", "altar", "dummy",
    "bomb", "seed", "projectile", "effect", "particle",
    "bullet", "mine", "trap", "spawn", "debris",
}

return Config
