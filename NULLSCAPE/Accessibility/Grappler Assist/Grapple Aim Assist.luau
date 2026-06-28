--!nocheck
-- [[
--  NULLSCAPE - Grapple Aim Assist
--  Temporarily replaces Grapple.Cast while enabled, then restores it fully when disabled.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local ClassProfiles = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/ClassProfiles.luau")
local EmergencyDecision = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/EmergencyDecision.luau")
local TerrainSense = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/TerrainSense.luau")
local IntentModel = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/IntentModel.luau")
local MapSense = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/MapSense.luau")
local HealthMonitor = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/HealthMonitor.luau")
local AssistArbiter = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/AssistArbiter.luau")
local VelocityAssist = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/VelocityAssist.luau")
local PhysicsProfile = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/PhysicsProfile.luau")
local ThreatModel = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/ThreatModel.luau")
local SafeLandingGuard = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/SafeLandingGuard.luau")
local TrajectoryAntiBonk = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/TrajectoryAntiBonk.luau")
local PredictionHorizon = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/PredictionHorizon.luau")

local function packValues(...)
    local values = { ... }
    values.n = select("#", ...)
    return values
end

local Logic = {
    Connections = {},
    InputConnections = {},
    Candidates = {},
    CandidateCursor = 1,
    Random = Random.new(),
    BellBypass = nil,
    BellBypassToken = 0,
    CurrentGrappleStep = nil,
    LastGrappleMovement = nil,
    SuppressBonkUntil = 0,
    FallbackHitbox = nil,
    NoCollisionMoveCastParams = nil,
    JumpPadStates = {},
    LastJumpPadUsesBypassEnabled = false,
    AdaptInputHeld = false,
    AdaptInputBeganAt = 0,
    LastAdaptInputPressed = 0,
    AdaptDriveActive = false,
    AdaptRecastToken = 0,
    LastKnownGrapple = nil,
    AdaptRecastPending = false,
    AdaptRecastReleaseIssued = false,
    AdaptRecastRequestedAt = 0,
    AdaptRecastReleaseAt = 0,
    LastAdaptPulseAt = 0,
    AdaptAwaitingAttachUntil = 0,
    AdaptRetryAt = 0,
    AutoRescueUntil = 0,
    LastAutoRescuePulseAt = 0,
    LastPanicRescuePulseAt = 0,
    LastPanicInputAt = 0,
    PanicInputCount = 0,
    PanicPressureUntil = 0,
    PanicStabilizeUntil = 0,
    LastPanicWatchdogAt = 0,
    LastPanicDangerEvalAt = 0,
    LastPanicDangerValue = false,
    EmergencyRescueLockUntil = 0,
    LastVoidRescueAt = 0,
    VoidRescueUntil = 0,
    TerrainFallState = nil,
    LastTerrainFallEvalAt = 0,
    EmergencyFloorRaycastParams = nil,
    EmergencyFloorRaycastCharacter = nil,
    LastSharkTailAssistAt = 0,
    LastSharkTailEvalAt = 0,
    NextSharkTailEvalDelay = 0.08,
    SharkTailPlanToken = 0,
    SharkTailPlannedAt = 0,
    SharkTailStabilizeUntil = 0,
    LastSmartReelStartAt = 0,
    LastAssistTargetInstance = nil,
    LastAssistTargetAt = 0,
    LastAssistDebug = nil,
    LastSmartReelEvalAt = 0,
    LastSmartReelDebug = nil,
    LastSmartReelDecision = nil,
    SmartReelLandingAssistUntil = 0,
    SmartReelLandingTargetPosition = nil,
    SmartReelLandingPlaneY = nil,
    MovementIntentState = "Freefall",
    MovementIntentUntil = 0,
    MovementIntentReason = nil,
    JumpPadCommitGuardUntil = 0,
    LastJumpPadCommitAt = 0,
    LastJumpPadCommitPart = nil,
    LastGravityProfileAt = 0,
    LastGravityProfile = nil,
    AssistArbiterState = AssistArbiter and AssistArbiter.new and AssistArbiter.new() or nil,
    LastIntentSnapshot = nil,
    LastIntentSnapshotAt = 0,
    LastIntentSnapshotGrapple = nil,
    LastIntentSnapshotRescueResult = nil,
    LastPhysicsProfile = nil,
    LastThreatSnapshot = nil,
    LastLandingGuard = nil,
    LastAntiBonkPrediction = nil,
    LastPredictionHorizon = nil,
    MapModel = nil,
    LastRuntimeCharacter = nil,
    LastRuntimeRootPart = nil,
    LastRuntimeMovement = nil,
    CurseHandler = nil,
    CurseHandlerLoaded = false,
}

Logic.MapModel = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler Assist/MapModel.luau")

local VALID_TARGETS = {
    GrapplePoint = true,
    JumpPad = true,
    Bell = true,
    TriaOrb = true,
}

local TARGET_OPTIONS = {
    "GrapplePoint",
    "JumpPad",
    "Bell",
    "TriaOrb",
}

local RANGE_OPTIONS = {
    "Nearest",
    "Farthest",
    "Closest To Cursor",
    "Random",
}

local GRAPPLER_CLASS_ID = ClassProfiles.GRAPPLER_CLASS_ID

local MOVEMENT_INTENT = {
    Freefall = "Freefall",
    JumpPadCommit = "JumpPadCommit",
    VoidRescue = "VoidRescue",
    LandingAssist = "LandingAssist",
    Reeling = "Reeling",
}

local CFG = {
    ADAPT_INPUT_PULSE_DURATION = 0.05,
    ADAPT_TAP_THRESHOLD = 0.16,
    ADAPT_RECAST_RELEASE_DELAY = 0.045,
    ADAPT_RECAST_COOLDOWN = 0.12,
    ADAPT_RECAST_MAX_WAIT = 0.35,
    ADAPT_ATTACH_GRACE = 0.18,
    ADAPT_RETRY_DELAY = 0.26,
    ADAPT_RECAST_SAFE_SPEED = 92,
    ADAPT_RECAST_CLAMP_SPEED = 78,
    ADAPT_RECAST_ARRIVAL_DISTANCE = 7,
    ADAPT_RECAST_TRIA_ARRIVAL_DISTANCE = 6,
    ADAPT_RECAST_GRAPPLEPOINT_DISTANCE = 15,
    ADAPT_RECAST_BOUNCE_DISTANCE = 7,
    ADAPT_DRIVE_FORWARD_BONUS = -34,
    ADAPT_DRIVE_BACKWARD_PENALTY = 70,
    ADAPT_DRIVE_CHAIN_LOOKAHEAD = 0.45,
    ADAPT_DRIVE_SPECIAL_FALL_SPEED = -45,
    ADAPT_DRIVE_BOUNCE_BONUS = -24,
    ADAPT_DRIVE_GRAPPLEPOINT_BONUS = -18,
    ADAPT_DRIVE_TRIA_STEER_BONUS = -26,
    ADAPT_DRIVE_TRIA_CENTER_BONUS = -14,
    ADAPT_DRIVE_SCREEN_WEIGHT = 65,
    ADAPT_DRIVE_DISTANCE_WEIGHT = 0.018,
    AUTO_RESCUE_SPEED = 135,
    AUTO_RESCUE_COOLDOWN = 0.45,
    AUTO_RESCUE_WINDOW = 0.3,
    PANIC_RESCUE_COOLDOWN = 0.16,
    EMERGENCY_RESCUE_RECAST_LOCK = 0.55,
    PANIC_RESCUE_WINDOW = 0.55,
    VOID_RESCUE_WINDOW = 0.9,
    VOID_RESCUE_COOLDOWN = 0.12,
    VOID_RESCUE_KILL_PLANE_BUFFER = 34,
    VOID_RESCUE_HARD_BUFFER = 10,
    VOID_RESCUE_PREDICT_TIME = 0.42,
    VOID_RESCUE_TARGET_UPWARD_BONUS = -58,
    VOID_RESCUE_LOW_TARGET_PENALTY = 95,
    VOID_RESCUE_SAFE_LANDING_DEPTH = 190,
    VOID_RESCUE_SAFE_LANDING_MAX_TIME = 1.55,
    VOID_RESCUE_SAFE_LANDING_NORMAL_Y = 0.45,
    VOID_RESCUE_SAFE_LANDING_KILL_MARGIN = 12,
    SHARK_TAIL_VOID_SAVER_ENABLED = false,
    SHARK_TAIL_VOID_SAVER_TRIGGER_BUFFER = 46,
    SHARK_TAIL_VOID_SAVER_USE_BUFFER = 28,
    SHARK_TAIL_VOID_SAVER_MIN_SPEED = 42,
    SHARK_TAIL_VOID_SAVER_MAX_UP_SPEED = 18,
    SHARK_TAIL_VOID_SAVER_LATERAL_OFFSET = 38,
    SHARK_TAIL_VOID_SAVER_FORWARD_OFFSET = 52,
    TERRAIN_SURFACE_SCREEN_WEIGHT = 110,
    TERRAIN_SURFACE_DISTANCE_WEIGHT = 0.035,
    TERRAIN_UPWARD_RESCUE_BONUS = -36,
    TERRAIN_LOW_VOID_PENALTY = 115,
    TERRAIN_WALL_RESCUE_PENALTY = 18,
    TERRAIN_CEILING_PENALTY = 140,
    TERRAIN_EDGE_PROBE_DISTANCE = 4,
    TERRAIN_EDGE_PENALTY = 42,
    TERRAIN_SAFE_FLOOR_BONUS = -16,
    TERRAIN_VOID_CONTEXT_TTL = 1.15,
    TERRAIN_VOID_RECENT_GROUND_WINDOW = 0.9,
    TERRAIN_VOID_INTENT_GRACE = 0.48,
    TERRAIN_VOID_GRACE_MIN_FALL_SPEED = 70,
    TERRAIN_VOID_GRACE_DROP_DISTANCE = 24,
    TERRAIN_VOID_FALL_SPEED = 22,
    TERRAIN_WALL_SLAM_MIN_SPEED = 115,
    TERRAIN_WALL_SLAM_PROBE_DISTANCE = 7,
    TERRAIN_WALL_SLAM_NORMAL_Y_MAX = 0.38,
    TERRAIN_WALL_SLAM_ALIGNMENT = 0.62,
    TERRAIN_WALL_SLAM_MEMORY = 0.35,
    TERRAIN_VOID_FORWARD_PROBE_DISTANCE = 30,
    TERRAIN_VOID_SIDE_PROBE_DISTANCE = 10,
    TERRAIN_VOID_DROP_DISTANCE = 11,
    TERRAIN_VOID_MIN_UNSAFE_SAMPLES = 2,
    TERRAIN_VOID_SCAN_INTERVAL = 0.1,
    TERRAIN_VOID_SAFE_SCAN_INTERVAL = 0.18,
    TERRAIN_VOID_FULL_SCAN_FALL_SPEED = 35,
    RAIL_EXIT_LANDING_GRACE = 0.95,
    RAIL_EXIT_MAX_HORIZONTAL_DRIFT = 90,
    RAIL_EXIT_FLOOR_DEPTH = 72,
    RAIL_EXIT_PROJECT_TIME = 0.42,
    RAIL_EXIT_MIN_NORMAL_Y = 0.38,
    INTENT_CONTROL_SUPPRESS_DOT = 0.34,
    INTENT_REEL_SUPPRESS_PENALTY = 58,
    INTENT_JUMPPAD_SUPPRESS_PENALTY = 72,
    MAP_ANCHOR_SCAN_INTERVAL = 1.2,
    MAP_ANCHOR_SCAN_MAX_DESCENDANTS = 9000,
    MAP_ANCHOR_MAX_CANDIDATES = 320,
    MAP_ANCHOR_DISTANCE_WEIGHT = 0.03,
    MAP_ANCHOR_SCREEN_WEIGHT = 36,
    MAP_ANCHOR_UPWARD_BONUS = -62,
    MAP_ANCHOR_LOW_PENALTY = 135,
    MAP_ANCHOR_SWING_IDEAL_DISTANCE = 72,
    MAP_ANCHOR_SWING_MIN_DISTANCE = 38,
    MAP_ANCHOR_SWING_DISTANCE_WEIGHT = 0.42,
    MAP_ANCHOR_SWING_LATERAL_MIN = 16,
    MAP_ANCHOR_SWING_LATERAL_IDEAL = 42,
    MAP_ANCHOR_SWING_LATERAL_WEIGHT = 0.65,
    MAP_ANCHOR_SWING_FLAT_MIN = 28,
    MAP_ANCHOR_SWING_FLAT_IDEAL = 58,
    MAP_ANCHOR_SWING_FLAT_WEIGHT = 1.15,
    MAP_ANCHOR_SWING_VERTICAL_RATIO_MAX = 1.35,
    MAP_ANCHOR_SWING_VERTICAL_RATIO_PENALTY = 82,
    MAP_ANCHOR_SWING_UNDERSIDE_PENALTY = 105,
    MAP_ANCHOR_SWING_WALL_BONUS = -14,
    MAP_ANCHOR_SWING_FORWARD_BONUS = -24,
    MAP_ANCHOR_SWING_BEHIND_PENALTY = 70,
    MAP_ANCHOR_SWING_CLEARANCE = 7,
    MAP_ANCHOR_SWING_CLEARANCE_BONUS = -18,
    MAP_ANCHOR_SWING_NARROW_PENALTY = 55,
    MAP_ANCHOR_OPT_MIN_MOMENTUM_SPEED = 28,
    MAP_ANCHOR_OPT_LOW_MOMENTUM_PENALTY = 18,
    MAP_ANCHOR_OPT_NO_FLAT_ROOM_PENALTY = 55,
    MAP_ANCHOR_OPT_LEAD_TIME = 0.42,
    MAP_ANCHOR_OPT_LEAD_WEIGHT = 0.22,
    MAP_ANCHOR_OPT_LATERAL_MIN = 18,
    MAP_ANCHOR_OPT_LATERAL_IDEAL = 48,
    MAP_ANCHOR_OPT_LATERAL_WEIGHT = 0.74,
    MAP_ANCHOR_OPT_FORWARD_BONUS = -22,
    MAP_ANCHOR_OPT_BACKWARD_PENALTY = 62,
    MAP_ANCHOR_OPT_VERTICAL_MIN = 8,
    MAP_ANCHOR_OPT_VERTICAL_MAX = 54,
    MAP_ANCHOR_OPT_LOW_APEX_WEIGHT = 1.15,
    MAP_ANCHOR_OPT_HIGH_APEX_WEIGHT = 0.55,
    MAP_ANCHOR_OPT_APEX_BONUS = -18,
    MAP_ANCHOR_OPT_PATH_WIDTH = 10,
    MAP_ANCHOR_OPT_WIDE_PATH_BONUS = -24,
    MAP_ANCHOR_OPT_PARTIAL_PATH_PENALTY = 10,
    MAP_ANCHOR_OPT_NARROW_PATH_PENALTY = 80,
    PANIC_RESCUE_GROUND_CHECK_HEIGHT = 10,
    PANIC_RESCUE_GROUND_CHECK_DEPTH = 90,
    PANIC_INPUT_WINDOW = 0.42,
    PANIC_INPUT_COUNT = 3,
    PANIC_INPUT_PRESSURE_DURATION = 0.7,
    PANIC_STABILIZE_WINDOW = 0.55,
    PANIC_STABILIZE_SPEED = 175,
    PANIC_STABILIZE_CLAMP = 128,
    PANIC_TARGET_UPWARD_WEIGHT = -0.22,
    PANIC_TARGET_FALL_ALIGNMENT_WEIGHT = 38,
    PANIC_BELL_NEAR_DISTANCE = 65,
    PANIC_JUMPPAD_NEAR_DISTANCE = 55,
    PANIC_GRAPPLEPOINT_NEAR_DISTANCE = 70,
    EMERGENCY_SMART_AUTO_THRESHOLD = 72,
    EMERGENCY_AUTO_THRESHOLD = 52,
    EMERGENCY_ACTIVE_INPUT_PENALTY = 22,
    EMERGENCY_NO_INPUT_BONUS = 10,
    PANIC_WATCHDOG_INTERVAL = 0.08,
    PANIC_DANGER_EVAL_INTERVAL = 0.08,
    PANIC_RESCUE_LOOKAHEADS = {
        0.16,
        0.32,
        0.52,
    },
    DEFAULT_MAX_RANGE = 90,
    MAX_CANDIDATES_PER_CAST = 48,
    FALLBACK_HITBOX_SIZE = Vector3.new(3, 2, 2),
    MOMENTUM_GUARD_SPEED = 115,
    MOMENTUM_GUARD_CLAMP = 88,
    MOMENTUM_GUARD_WINDOW = 0.8,
    SHARK_TAIL_PROJECT_TIME = 0.25,
    SHARK_TAIL_MIN_SPEED = 35,
    SHARK_TAIL_CHAIN_GRACE = 0.12,
    SHARK_TAIL_OVERPOP_UP_SPEED = 58,
    SHARK_TAIL_OVERPOP_PENALTY = 28,
    SHARK_TAIL_CEILING_CHECK_HEIGHT = 18,
    SHARK_TAIL_STABILIZE_WINDOW = 0.38,
    SHARK_TAIL_STABILIZE_HORIZONTAL_SPEED = 190,
    SHARK_TAIL_STABILIZE_HORIZONTAL_CLAMP = 148,
    SHARK_TAIL_STABILIZE_UP_SPEED = 96,
    SHARK_TAIL_STABILIZE_UP_CLAMP = 74,
    SHARK_TAIL_LOW_CEILING_PENALTY = 35,
    SHARK_TAIL_TURN_DOT = 0.72,
    SHARK_TAIL_CRUISE_DOT = 0.9,
    SHARK_TAIL_TURN_BONUS = 28,
    SHARK_TAIL_CRUISE_PENALTY = 24,
    CURSOR_INTENT_SCREEN_WEIGHT = 1000,
    CURSOR_INTENT_DISTANCE_WEIGHT = 0.015,
    CURSOR_INTENT_PREFERRED_BONUS = -4,
    CURSOR_INTENT_CONFIDENCE_LIMIT = 0.24,
    CURSOR_SPECIAL_FOCUS_LIMIT = 0.055,
    CURSOR_SPECIAL_FOCUS_BONUS = -18,
    ASSIST_INPUT_INTENT_WEIGHT = 32,
    ASSIST_VELOCITY_INTENT_WEIGHT = 14,
    ASSIST_TARGET_LOCK_DURATION = 0.22,
    ASSIST_TARGET_LOCK_BONUS = -10,
    ASSIST_CURSOR_PREFILTER_LIMIT = 0.32,
    ASSIST_ROUTE_LOOKAHEAD = 0.42,
    ASSIST_ROUTE_BONUS = -18,
    ASSIST_WRONG_ANCHOR_DOT = -0.35,
    ASSIST_WRONG_ANCHOR_PENALTY = 70,
    ASSIST_SPECIAL_TRIA_SPEED = 120,
    ASSIST_SPECIAL_BELL_FALL_SPEED = -45,
    ASSIST_SPECIAL_JUMPPAD_FALL_SPEED = -70,
    SOFT_OVERRIDE_MIN_SCORE_GAP = 34,
    SOFT_OVERRIDE_CURSOR_LIMIT = 0.18,
    SOFT_OVERRIDE_ORIGINAL_BAD_CURSOR = 0.28,
    SOFT_OVERRIDE_WRONG_ANCHOR_MIN = 34,
    SOFT_OVERRIDE_SURFACE_PENALTY = 46,
    SMART_REEL_EVAL_INTERVAL = 0.06,
    SMART_REEL_AUTO_THRESHOLD = 62,
    SMART_REEL_MANUAL_THRESHOLD = 36,
    SMART_REEL_MIN_ATTACH_TIME = 0.06,
    SMART_REEL_NEAR_CUTOFF = 8,
    SMART_REEL_EXIT_DISTANCE = 12,
    SMART_REEL_GOOD_DISTANCE = 30,
    SMART_REEL_FAR_DISTANCE = 82,
    SMART_REEL_HIGH_SPEED = 135,
    SMART_REEL_EXTREME_SPEED = 190,
    SMART_REEL_LOW_ARC_HEIGHT = 16,
    SMART_REEL_LOW_ARC_UP_SPEED = 42,
    SMART_REEL_OVERSHOOT_LOOKAHEAD = 0.18,
    SMART_REEL_ROUTE_LOOKAHEAD = 0.28,
    SMART_REEL_GOOD_ROUTE_BONUS = 18,
    SMART_REEL_ROUTE_GOOD_GAIN_RATIO = 0.14,
    SMART_REEL_CATCHUP_CLOSING_SPEED = 38,
    SMART_REEL_WORSENING_MARGIN = 4,
    SMART_REEL_START_COOLDOWN = 0.18,
    SMART_REEL_LANDING_PLANE_MIN_BELOW = 10,
    SMART_REEL_LANDING_FALL_SPEED = 18,
    SMART_REEL_LANDING_MAX_DISTANCE = 70,
    SMART_REEL_LANDING_ASSIST_DURATION = 0.35,
    SMART_REEL_LANDING_HORIZONTAL_SPEED = 72,
    SMART_REEL_LANDING_UP_SPEED_MIN = 28,
    SMART_REEL_LANDING_UP_SPEED_MAX = 92,
    SMART_REEL_LANDING_BLEND = 0.38,
    LOW_GRAVITY_PROFILE_TTL = 0.45,
    LOW_GRAVITY_FALL_THRESHOLD_SCALE = 0.72,
    LOW_GRAVITY_VOID_BUFFER_BONUS = 18,
    LOW_GRAVITY_VOID_PREDICT_BONUS = 0.28,
    LOW_GRAVITY_LANDING_FALL_SPEED = 6,
    LOW_GRAVITY_LANDING_MIN_BELOW = 6,
    LOW_GRAVITY_LANDING_MAX_DISTANCE = 86,
    LOW_GRAVITY_LANDING_SCORE_BONUS = 12,
    JUMPPAD_COMMIT_GUARD_BASE = 0.62,
    JUMPPAD_COMMIT_GUARD_FAST = 0.95,
    JUMPPAD_COMMIT_FAST_SPEED = 120,
    SMART_REEL_PLAYER_CONTROL_PENALTY = 24,
    SMART_REEL_BAD_INPUT_PENALTY = 34,
    SMART_REEL_AUTO_MIN_DOT = -0.2,
    SMART_REEL_MANUAL_MIN_DOT = -0.55,
    THREAT_SCAN_INTERVAL = 0.72,
    THREAT_SCAN_MAX_DESCENDANTS = 700,
    THREAT_SCAN_MAX_HAZARDS = 120,
    MAP_MODEL_CHUNK_SIZE = 64,
    MAP_MODEL_ACTIVE_RADIUS = 2,
    MAP_MODEL_KEEP_RADIUS = 4,
    MAP_MODEL_STEP_INTERVAL = 0.28,
    MAP_MODEL_RESCAN_INTERVAL = 2.5,
    MAP_MODEL_SCAN_HEIGHT = 260,
    MAP_MODEL_FLOOR_DEPTH = 280,
    MAP_MODEL_FLOOR_NORMAL_Y = 0.42,
    MAP_MODEL_KILL_MARGIN = 12,
    MAP_MODEL_MAX_PARTS_PER_CHUNK = 90,
    MAP_MODEL_MAX_ANCHORS_PER_CHUNK = 36,
    MAP_MODEL_DEBUG_3D_RENDER_INTERVAL = 0.24,
    MAP_MODEL_DEBUG_3D_MAX_MARKERS = 160,
    MAP_MODEL_DEBUG_3D_CHUNK_HEIGHT = 4,
    MAP_ANCHOR_THREAT_MAX_DISTANCE = 38,
    SAFE_LANDING_MAX_THREAT_SCORE = 52,
    CONTROLLED_LANDING_PROBE_TIME = 0.72,
    CONTROLLED_LANDING_MAX_TIME = 2.35,
    CONTROLLED_LANDING_MAX_PROBE_DISTANCE = 96,
    CONTROLLED_LANDING_COARSE_PROBE_DISTANCE = 180,
    CONTROLLED_LANDING_MIN_HORIZONTAL_SPEED = 20,
    VOID_RESCUE_MOMENTUM_GRACE_HEIGHT = 58,
    VOID_RESCUE_MOMENTUM_MIN_FALL_SPEED = 30,
    TRAJECTORY_ANTIBONK_INTERVAL = 0.055,
    TRAJECTORY_ANTIBONK_LOOKAHEAD = 0.28,
    TRAJECTORY_ANTIBONK_MIN_SPEED = 112,
    RECAST_ALIGNMENT_MAX_STEP = 0.16,
    RECAST_ALIGNMENT_MIN_DISTANCE = 12,
}

local SHARK_TAIL_STYLE_CONFIG = {
    Conservative = {
        Threshold = 76,
        ManualThreshold = 55,
        Cooldown = 0.48,
        DelayMin = 0.1,
        DelayMax = 0.18,
        EvalMin = 0.09,
        EvalMax = 0.14,
    },
    Balanced = {
        Threshold = 64,
        ManualThreshold = 48,
        Cooldown = 0.35,
        DelayMin = 0.06,
        DelayMax = 0.14,
        EvalMin = 0.07,
        EvalMax = 0.12,
    },
    Aggressive = {
        Threshold = 54,
        ManualThreshold = 42,
        Cooldown = 0.26,
        DelayMin = 0.04,
        DelayMax = 0.1,
        EvalMin = 0.06,
        EvalMax = 0.1,
    },
    ["Emergency Only"] = {
        Threshold = 46,
        ManualThreshold = 48,
        Cooldown = 0.22,
        DelayMin = 0.02,
        DelayMax = 0.07,
        EvalMin = 0.05,
        EvalMax = 0.08,
        EmergencyOnly = true,
    },
}

local SCREEN_RAY_OFFSETS = {
    Vector2.new(0, 0),
    Vector2.new(0.06, 0),
    Vector2.new(-0.06, 0),
    Vector2.new(0, 0.06),
    Vector2.new(0, -0.06),
    Vector2.new(0.1, 0.06),
    Vector2.new(-0.1, 0.06),
    Vector2.new(0.1, -0.06),
    Vector2.new(-0.1, -0.06),
}

function Logic.getGlobals()
    local env = getgenv()
    env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
    return env._NULLSCAPE_Globals
end

function Logic.getController()
    return Logic.getGlobals().activeAccessibilityController
end

function Logic.isEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAimAssistEnabled == true and controller.GrappleAssistSuiteEnabled == true
end

function Logic.isSuiteEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAssistSuiteEnabled == true
end

function Logic.isRescueEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleRescueAssistEnabled == true
end

function Logic.isEmergencyProtectionEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleEmergencyProtectionEnabled == true
end

function Logic.getEmergencyProtectionMode()
    local controller = Logic.getController()
    local mode = tostring(controller and controller.GrappleEmergencyProtectionMode or "Manual")
    if mode == "Smart Auto" then
        return "Smart Auto"
    end
    if mode == "Automatic" then
        return "Automatic"
    end
    return "Manual"
end

function Logic.getEmergencySpeedThreshold()
    local controller = Logic.getController()
    return math.clamp(tonumber(controller and controller.GrappleEmergencySpeedThreshold) or 220, 150, 320)
end

function Logic.getEmergencyFallThreshold()
    local controller = Logic.getController()
    return math.clamp(tonumber(controller and controller.GrappleEmergencyFallThreshold) or 125, 80, 220)
end

function Logic.isAntiBonkEnabled()
    local controller = Logic.getController()
    return controller and controller.AntiBonkEnabled == true
end

function Logic.isSmartReelEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleSmartReelEnabled == true
end

function Logic.isSharkTailHelperEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleSharkTailHelperEnabled == true
end

function Logic.isMomentumGuardEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleMomentumGuardEnabled == true
end

function Logic.isJumpPadUsesBypassEnabled()
    local controller = Logic.getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleJumpPadUsesBypassEnabled == true
end

function Logic.setMovementIntent(state, duration, reason)
    local now = time()
    local untilTime = now + math.max(tonumber(duration) or 0, 0)
    if untilTime < (Logic.MovementIntentUntil or 0) and Logic.MovementIntentState == state then
        return
    end

    Logic.MovementIntentState = state or MOVEMENT_INTENT.Freefall
    Logic.MovementIntentUntil = untilTime
    Logic.MovementIntentReason = reason
end

function Logic.getMovementIntentState()
    if time() > (Logic.MovementIntentUntil or 0) then
        Logic.MovementIntentState = MOVEMENT_INTENT.Freefall
        Logic.MovementIntentReason = nil
        return MOVEMENT_INTENT.Freefall
    end

    return Logic.MovementIntentState or MOVEMENT_INTENT.Freefall
end

function Logic.isMovementIntent(state)
    return Logic.getMovementIntentState() == state
end

function Logic.isAutomationSuppressedByIntent()
    return false
end

function Logic.clearLandingIntent()
    Logic.SmartReelLandingAssistUntil = 0
    Logic.SmartReelLandingTargetPosition = nil
    Logic.SmartReelLandingPlaneY = nil
    if Logic.isMovementIntent(MOVEMENT_INTENT.LandingAssist) then
        Logic.setMovementIntent(MOVEMENT_INTENT.Freefall, 0, nil)
    end
end

function Logic.isJumpPadCommitGuardActive()
    return time() <= (Logic.JumpPadCommitGuardUntil or 0)
end

function Logic.markJumpPadCommit(grapple, jumpPadPart)
    if not Logic.isJumpPadInstance(jumpPadPart) then
        return
    end

    local rootPart = grapple and grapple.RootPart
    local speed = Logic.getHorizontalVelocity(rootPart).Magnitude
    local guardDuration = speed >= CFG.JUMPPAD_COMMIT_FAST_SPEED and CFG.JUMPPAD_COMMIT_GUARD_FAST or CFG.JUMPPAD_COMMIT_GUARD_BASE
    local now = time()

    Logic.LastJumpPadCommitAt = now
    Logic.LastJumpPadCommitPart = jumpPadPart
    Logic.JumpPadCommitGuardUntil = math.max(Logic.JumpPadCommitGuardUntil or 0, now + guardDuration)
end

function Logic.isVoidRescueEnabled()
    local controller = Logic.getController()
    return controller
        and controller.GrappleAssistSuiteEnabled == true
        and controller.GrappleEmergencyProtectionEnabled == true
        and controller.GrappleVoidRescueEnabled ~= false
end

function Logic.isWallSlamRescueEnabled()
    local controller = Logic.getController()
    return controller
        and controller.GrappleAssistSuiteEnabled == true
        and controller.GrappleEmergencyProtectionEnabled == true
        and controller.GrappleWallSlamRescueEnabled == true
end

function Logic.getAdaptInputKeyCode()
    local controller = Logic.getController()
    local keyName = tostring(controller and controller.GrappleAdaptInputKey or "T")
    return Enum.KeyCode[keyName] or Enum.KeyCode.T
end

function Logic.isTextBoxFocused()
    local success, focused = pcall(function()
        return UserInputService:GetFocusedTextBox()
    end)
    return success and focused ~= nil
end

function Logic.getAirControlMultiplier()
    local controller = Logic.getController()
    if not (controller and controller.GrappleAssistSuiteEnabled == true) then
        return 0
    end

    return math.clamp(tonumber(controller.GrappleAirControlMultiplier) or 0, 0, 10)
end

function Logic.getReelPullMultiplier()
    local controller = Logic.getController()
    if not (controller and controller.GrappleAssistSuiteEnabled == true) then
        return 1
    end

    return math.clamp(tonumber(controller.GrappleReelPullMultiplier) or 1, 1, 5)
end

function Logic.getSharkTailPullMultiplier()
    local controller = Logic.getController()
    if not (controller and controller.GrappleAssistSuiteEnabled == true) then
        return 1
    end

    return math.clamp(tonumber(controller.GrappleSharkTailPullMultiplier) or 1, 1, 5)
end

function Logic.isInfiniteStamina()
    local controller = Logic.getController()
    return controller and controller.GrapplerStaminaMode == "Infinite Stamina"
end

function Logic.normalizeTargetPriority(value)
    value = tostring(value or "GrapplePoint")
    if VALID_TARGETS[value] then
        return value
    end
    return "GrapplePoint"
end

local function normalizeRangePriority(value)
    value = tostring(value or "Nearest")
    for _, option in ipairs(RANGE_OPTIONS) do
        if value == option then
            return value
        end
    end
    return "Nearest"
end

local function normalizeMode(value)
    value = tostring(value or "Manual")
    if value == "Automatic" then
        return "Automatic"
    end
    return "Manual"
end

local function normalizeStyle(value)
    value = tostring(value or "Balanced")
    if SHARK_TAIL_STYLE_CONFIG[value] then
        return value
    end
    return "Balanced"
end

local function getTargetPart(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") and instance.PrimaryPart then
        return instance.PrimaryPart
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getCandidateName(instance, part)
    if instance and VALID_TARGETS[instance.Name] then
        return instance.Name
    end
    if part and VALID_TARGETS[part.Name] then
        return part.Name
    end
    return nil
end

local function registerCandidate(instance)
    local part = getTargetPart(instance)
    local targetName = getCandidateName(instance, part)
    if not part or not targetName then
        return
    end

    Logic.Candidates[instance] = {
        Instance = instance,
        Part = part,
        Name = targetName,
    }
end

local function registerCandidateBranch(instance, root)
    local current = instance
    while current and current ~= root do
        registerCandidate(current)
        current = current.Parent
    end
end

local function unregisterCandidate(instance)
    if not instance then
        return
    end

    Logic.Candidates[instance] = nil
end

local function unregisterCandidateTree(instance)
    unregisterCandidate(instance)
    if not instance then
        return
    end

    for _, descendant in ipairs(instance:GetDescendants()) do
        unregisterCandidate(descendant)
    end
end

local function clearConnections()
    for _, connection in ipairs(Logic.Connections) do
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    table.clear(Logic.Connections)
end

local function clearInputConnections()
    for _, connection in ipairs(Logic.InputConnections) do
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    table.clear(Logic.InputConnections)
    Logic.AdaptInputHeld = false
    Logic.AdaptInputBeganAt = 0
    Logic.AdaptDriveActive = false
    Logic.AdaptRecastToken = Logic.AdaptRecastToken + 1
    Logic.AdaptRecastPending = false
    Logic.AdaptRecastReleaseIssued = false
    Logic.AdaptAwaitingAttachUntil = 0
    Logic.AdaptRetryAt = 0
end

local function getClassId(grapple)
    return ClassProfiles.getClassId(grapple)
end

local function hasClassCapability(grapple, capability)
    return ClassProfiles.hasCapability(grapple, capability)
end

local function hasAnyGrappleAssistCapability(grapple)
    return ClassProfiles.hasAnyCapability(grapple)
end

local function isActiveClassSpecial(grapple)
    return ClassProfiles.isActiveSpecial(grapple)
end

local function getTrackedGrapple()
    local grapple = Logic.CurrentGrappleStep or Logic.LastKnownGrapple
    if typeof(grapple) ~= "table" then
        return nil
    end

    local movement = grapple.Movement
    if not movement then
        return nil
    end

    if not isActiveClassSpecial(grapple) then
        return nil
    end

    if not hasAnyGrappleAssistCapability(grapple) then
        return nil
    end

    return grapple
end

local function fireSpecialAction(grapple, state)
    local movement = grapple and grapple.Movement
    if not (movement and typeof(movement.SpecialAction) == "function") then
        return false
    end

    local success = pcall(function()
        movement:SpecialAction(state)
    end)

    return success
end

local function pulseSpecialAction(grapple)
    if time() - Logic.LastAdaptPulseAt < CFG.ADAPT_RECAST_COOLDOWN then
        return false
    end
    if not fireSpecialAction(grapple, Enum.UserInputState.Begin) then
        return false
    end

    Logic.LastAdaptPulseAt = time()
    Logic.AdaptAwaitingAttachUntil = Logic.LastAdaptPulseAt + CFG.ADAPT_ATTACH_GRACE
    Logic.AdaptRetryAt = Logic.AdaptAwaitingAttachUntil + CFG.ADAPT_RETRY_DELAY

    local token = Logic.AdaptRecastToken + 1
    Logic.AdaptRecastToken = token

    task.delay(CFG.ADAPT_INPUT_PULSE_DURATION, function()
        if Logic.AdaptRecastToken ~= token then
            return
        end

        local activeGrapple = grapple
        if not (activeGrapple and isActiveClassSpecial(activeGrapple) and hasClassCapability(activeGrapple, "RescueAssist")) then
            activeGrapple = getTrackedGrapple()
        end
        if not activeGrapple then
            return
        end

        fireSpecialAction(activeGrapple, Enum.UserInputState.End)
    end)

    return true
end

local function armAutoRescueWindow()
    Logic.AutoRescueUntil = time() + CFG.AUTO_RESCUE_WINDOW
end

local function isAutoRescueWindowActive()
    return time() <= (Logic.AutoRescueUntil or 0)
end

local function isAwaitingAdaptAttach(grapple)
    local movement = grapple and grapple.Movement
    if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
        Logic.AdaptAwaitingAttachUntil = 0
        Logic.AdaptRetryAt = 0
        return false
    end

    return time() <= (Logic.AdaptAwaitingAttachUntil or 0)
end

local function isEmergencyRescueRecastBlocked(grapple, ignoreTimeLock)
    if not ignoreTimeLock and time() <= (Logic.EmergencyRescueLockUntil or 0) then
        return true
    end

    if not ignoreTimeLock and Logic.isJumpPadCommitGuardActive() then
        return true
    end

    local movement = grapple and grapple.Movement
    if movement and (movement.grappling == true or grapple.jumpPadReel == true or isAwaitingAdaptAttach(grapple)) then
        return true
    end

    return false
end

local function markEmergencyRescuePulse()
    Logic.EmergencyRescueLockUntil = math.max(
        Logic.EmergencyRescueLockUntil or 0,
        time() + CFG.EMERGENCY_RESCUE_RECAST_LOCK
    )
end

local function getAdaptHorizontalSpeed(grapple)
    local rootPart = grapple and grapple.RootPart
    local horizontal = Logic.getHorizontalVelocity(rootPart)
    return horizontal.Magnitude, horizontal
end

local function getActiveGrappleTargetPosition(grapple)
    local movement = grapple and grapple.Movement
    if movement and typeof(movement.grapplePoint) == "Vector3" then
        return movement.grapplePoint
    end

    local part = (movement and movement.grapplePart) or grapple and grapple.grapplePart
    if part and part.Parent and part:IsA("BasePart") then
        return part.Position
    end

    return nil
end

local function getAdaptArrivalDistance(grapple)
    local movement = grapple and grapple.Movement
    local part = (movement and movement.grapplePart) or grapple and grapple.grapplePart
    if part and part.Parent and part.Name == "TriaOrb" then
        return CFG.ADAPT_RECAST_TRIA_ARRIVAL_DISTANCE
    elseif part and part.Parent and part.Name == "GrapplePoint" then
        return CFG.ADAPT_RECAST_GRAPPLEPOINT_DISTANCE
    elseif part and part.Parent and (part.Name == "JumpPad" or part.Name == "Bell") then
        return CFG.ADAPT_RECAST_BOUNCE_DISTANCE
    end

    local size = part and part.Parent and part:IsA("BasePart") and part.Size.Magnitude * 0.45 or 0
    return math.max(CFG.ADAPT_RECAST_ARRIVAL_DISTANCE, size)
end

local function hasReachedGrappleDestination(grapple)
    local rootPart = grapple and grapple.RootPart
    local targetPosition = getActiveGrappleTargetPosition(grapple)
    if not (rootPart and targetPosition) then
        return true
    end

    local remainingDistance = (targetPosition - rootPart.Position).Magnitude
    if remainingDistance <= getAdaptArrivalDistance(grapple) then
        return true
    end

    local rootVelocity = rootPart.Velocity
    if not rootVelocity then
        return false
    end

    local toTarget = targetPosition - rootPart.Position
    if toTarget.Magnitude <= 0.001 then
        return true
    end

    return rootVelocity:Dot(toTarget.Unit) <= 0
end

local function clampAdaptRecastVelocity(grapple)
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return
    end

    local speed, horizontal = getAdaptHorizontalSpeed(grapple)
    if speed <= CFG.ADAPT_RECAST_SAFE_SPEED or speed <= 0 then
        return
    end

    local clampedHorizontal = horizontal.Unit * CFG.ADAPT_RECAST_CLAMP_SPEED
    rootPart.Velocity = Vector3.new(clampedHorizontal.X, rootPart.Velocity.Y, clampedHorizontal.Z)
end

local function requestAdaptRecast(grapple)
    if not hasClassCapability(grapple, "AimAssist") then
        return false
    end

    local now = time()
    if now - Logic.LastAdaptPulseAt < CFG.ADAPT_RECAST_COOLDOWN then
        return false
    end

    local movement = grapple and grapple.Movement
    if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
        if not hasReachedGrappleDestination(grapple) then
            return false
        end
        Logic.AdaptRecastPending = true
        Logic.AdaptRecastReleaseIssued = fireSpecialAction(grapple, Enum.UserInputState.End) == true
        Logic.AdaptRecastRequestedAt = now
        Logic.AdaptRecastReleaseAt = now
        Logic.markGrappleBonkGrace(grapple, 0.5)
        return Logic.AdaptRecastReleaseIssued
    end

    return pulseSpecialAction(grapple)
end

local function beginAdaptDrive(grapple)
    if Logic.AdaptDriveActive then
        return false
    end

    Logic.AdaptDriveActive = true
    Logic.LastAdaptInputPressed = time()

    if grapple then
        return requestAdaptRecast(grapple)
    end

    return false
end

local function applyGentleRecastAlignment(grapple, dt)
    local function flatUnit(vector)
        if typeof(vector) ~= "Vector3" then
            return nil
        end
        local flat = Vector3.new(vector.X, 0, vector.Z)
        if flat.Magnitude <= 0.05 then
            return nil
        end
        return flat.Unit
    end

    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return false
    end

    local movement = grapple and grapple.Movement
    local inputDirection = flatUnit(movement and movement.PlayerMoveDirection)
    local velocityDirection = flatUnit(rootPart.Velocity)
    if inputDirection and velocityDirection and inputDirection:Dot(velocityDirection) >= CFG.INTENT_CONTROL_SUPPRESS_DOT then
        return false
    end

    local targetPosition = getActiveGrappleTargetPosition(grapple)
    local targetDirection = flatUnit(targetPosition and (targetPosition - rootPart.Position))
    if not targetDirection then
        targetDirection = velocityDirection
    end
    if not targetDirection then
        return false
    end

    if targetPosition and (targetPosition - rootPart.Position).Magnitude < CFG.RECAST_ALIGNMENT_MIN_DISTANCE then
        return false
    end

    local currentLook = flatUnit(rootPart.CFrame.LookVector)
    if not currentLook then
        return false
    end

    local alpha = math.clamp((tonumber(dt) or 1 / 60) * 8, 0, CFG.RECAST_ALIGNMENT_MAX_STEP)
    local blended = currentLook:Lerp(targetDirection, alpha)
    if blended.Magnitude <= 0.05 then
        return false
    end

    local position = rootPart.Position
    rootPart.CFrame = CFrame.lookAt(position, position + blended.Unit, Vector3.yAxis)
    return true
end

local function updateAdaptRecast(grapple)
    if not Logic.AdaptRecastPending then
        return
    end
    if not (Logic.AdaptInputHeld and Logic.isSuiteEnabled()) then
        Logic.AdaptRecastPending = false
        Logic.AdaptRecastReleaseIssued = false
        return
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement) then
        return
    end

    local now = time()
    local releaseElapsed = now - Logic.AdaptRecastReleaseAt
    local requestElapsed = now - Logic.AdaptRecastRequestedAt
    local detached = movement.grappling ~= true and grapple.jumpPadReel ~= true
    local speed = getAdaptHorizontalSpeed(grapple)

    if speed > CFG.ADAPT_RECAST_SAFE_SPEED then
        clampAdaptRecastVelocity(grapple)
        Logic.markGrappleBonkGrace(grapple, 0.3)
        speed = getAdaptHorizontalSpeed(grapple)
    end

    applyGentleRecastAlignment(grapple, 1 / 60)

    if not Logic.AdaptRecastReleaseIssued then
        Logic.AdaptRecastReleaseIssued = fireSpecialAction(grapple, Enum.UserInputState.End) == true
        Logic.AdaptRecastReleaseAt = now
        return
    end

    if not detached then
        return
    end
    if releaseElapsed < CFG.ADAPT_RECAST_RELEASE_DELAY then
        return
    end
    if speed > CFG.ADAPT_RECAST_SAFE_SPEED and requestElapsed < CFG.ADAPT_RECAST_MAX_WAIT then
        return
    end

    Logic.AdaptRecastPending = false
    Logic.AdaptRecastReleaseIssued = false
    pulseSpecialAction(grapple)
end

local function maintainAdaptInputHold(grapple)
    if not (hasClassCapability(grapple, "AimAssist") and Logic.AdaptDriveActive and Logic.AdaptInputHeld and Logic.isSuiteEnabled() and Logic.isInAir(grapple)) then
        return
    end
    if Logic.AdaptRecastPending then
        return
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement) then
        return
    end
    if isAwaitingAdaptAttach(grapple) then
        return
    end
    if time() < (Logic.AdaptRetryAt or 0) then
        return
    end
    if time() - Logic.LastAdaptPulseAt < CFG.ADAPT_RECAST_COOLDOWN then
        return
    end

    if movement.grappling == true or grapple.jumpPadReel == true then
        if not hasReachedGrappleDestination(grapple) then
            return
        end
        requestAdaptRecast(grapple)
        return
    end

    if not Logic.hasAdaptDriveTarget(grapple) then
        Logic.AdaptRetryAt = time() + CFG.ADAPT_RETRY_DELAY
        return
    end

    pulseSpecialAction(grapple)
end

local function updateAdaptInputMode(grapple)
    if not (Logic.AdaptInputHeld and Logic.isSuiteEnabled()) then
        return
    end
    if Logic.AdaptDriveActive then
        return
    end
    if time() - (Logic.AdaptInputBeganAt or 0) < CFG.ADAPT_TAP_THRESHOLD then
        return
    end

    beginAdaptDrive(grapple)
end

local function watchAdaptInput()
    if #Logic.InputConnections > 0 then
        return
    end

    table.insert(Logic.InputConnections, UserInputService.InputBegan:Connect(function(input, _gameProcessed)
        if Logic.isTextBoxFocused() or input.KeyCode ~= Logic.getAdaptInputKeyCode() then
            return
        end

        Logic.AdaptInputHeld = true
        Logic.AdaptInputBeganAt = time()
    end))

    table.insert(Logic.InputConnections, UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode ~= Logic.getAdaptInputKeyCode() then
            return
        end

        local heldDuration = time() - (Logic.AdaptInputBeganAt or 0)
        local shouldTap = heldDuration <= CFG.ADAPT_TAP_THRESHOLD and Logic.AdaptDriveActive ~= true

        Logic.AdaptInputHeld = false
        Logic.AdaptInputBeganAt = 0
        Logic.AdaptDriveActive = false
        Logic.AdaptRecastPending = false
        Logic.AdaptRecastReleaseIssued = false
        Logic.AdaptAwaitingAttachUntil = 0
        Logic.AdaptRetryAt = 0

        if shouldTap and Logic.isSuiteEnabled() then
            local grapple = getTrackedGrapple()
            if grapple then
                Logic.LastAdaptInputPressed = time()
                requestAdaptRecast(grapple)
            end
        end
    end))
end

local function rebuildCandidateCache()
    table.clear(Logic.Candidates)

    local jumpPads = Workspace:FindFirstChild("JumpPads")
    if not jumpPads then
        return
    end

    for _, descendant in ipairs(jumpPads:GetDescendants()) do
        registerCandidateBranch(descendant, jumpPads)
    end
end

local function watchCandidateFolder()
    clearConnections()
    rebuildCandidateCache()

    local jumpPads = Workspace:FindFirstChild("JumpPads")
    if not jumpPads then
        local connection = Workspace.ChildAdded:Connect(function(child)
            if child.Name == "JumpPads" then
                watchCandidateFolder()
            end
        end)
        table.insert(Logic.Connections, connection)
        return
    end

    table.insert(Logic.Connections, jumpPads.DescendantAdded:Connect(function(descendant)
        registerCandidateBranch(descendant, jumpPads)
    end))
    table.insert(Logic.Connections, jumpPads.DescendantRemoving:Connect(unregisterCandidateTree))
end

local function getGrappleModule()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    local specials = movement and movement:FindFirstChild("Specials")
    local grappleScript = specials and specials:FindFirstChild("Grapple")
    if not grappleScript or not grappleScript:IsA("ModuleScript") then
        return nil
    end

    local success, grappleModule = pcall(require, grappleScript)
    if not success or typeof(grappleModule) ~= "table" then
        return nil
    end

    return grappleModule
end

local function getMovementCore()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
    if not movementCoreScript or not movementCoreScript:IsA("ModuleScript") then
        return nil
    end

    local success, movementCore = pcall(require, movementCoreScript)
    if not success or typeof(movementCore) ~= "table" then
        return nil
    end

    return movementCore
end

local function clearLegacyInfiniteStaminaHook(globals, grappleModule)
    if globals.GrappleAimAssistHooked or not globals.GrapplerInfiniteStaminaHooked then
        return
    end

    if grappleModule then
        if globals.OriginalGrappleStep then
            grappleModule.Step = globals.OriginalGrappleStep
        end
        if globals.OriginalGrappleStart then
            grappleModule.Start = globals.OriginalGrappleStart
        end
    end

    globals.OriginalGrappleStep = nil
    globals.OriginalGrappleStart = nil
    globals.GrapplerInfiniteStaminaHooked = nil
end

local function getEntitiesGC()
    local success, gc = pcall(function()
        return getgenv().loadModule("NULLSCAPE/Entities/GC.luau")
    end)
    if success and typeof(gc) == "table" then
        return gc
    end
    return nil
end

function Logic.isInAir(grapple)
    local humanoid = grapple and grapple.Humanoid
    if not humanoid then
        return false
    end

    return humanoid.FloorMaterial == Enum.Material.Air
end

local function isFallingFast(grapple)
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    return velocity and velocity.Y < -35
end

local function isHighMomentumDanger(grapple)
    if not (grapple and Logic.isInAir(grapple)) then
        return false
    end

    return Logic.getHorizontalVelocity(grapple.RootPart).Magnitude >= CFG.AUTO_RESCUE_SPEED
end

local function isEmergencyAssistDanger(grapple)
    return Logic.isEmergencyProtectionEnabled() and (isHighMomentumDanger(grapple) or Logic.getCachedPanicRescueDanger(grapple))
end

local function getEmergencyFloorRaycastParams(grapple)
    local character = grapple and grapple.Character
    if Logic.EmergencyFloorRaycastParams and Logic.EmergencyFloorRaycastCharacter == character then
        return Logic.EmergencyFloorRaycastParams
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true

    local filter = {}
    if character then
        table.insert(filter, character)
    end

    params.FilterDescendantsInstances = filter
    Logic.EmergencyFloorRaycastParams = params
    Logic.EmergencyFloorRaycastCharacter = character
    return params
end

local function hasFloorBelow(position, params)
    local origin = position + Vector3.new(0, CFG.PANIC_RESCUE_GROUND_CHECK_HEIGHT, 0)
    local direction = Vector3.new(0, -CFG.PANIC_RESCUE_GROUND_CHECK_DEPTH, 0)
    local hit = Workspace:Raycast(origin, direction, params)
    return hit ~= nil
end

local function getFloorHit(position, params)
    local origin = position + Vector3.new(0, CFG.PANIC_RESCUE_GROUND_CHECK_HEIGHT, 0)
    local direction = Vector3.new(0, -CFG.PANIC_RESCUE_GROUND_CHECK_DEPTH, 0)
    return Workspace:Raycast(origin, direction, params)
end

local function isSafeLandingFloorHit(result, killY)
    if not result then
        return false
    end

    local instance = result.Instance
    if instance and instance.Name == "KillVoid" then
        return false
    end
    if result.Normal and result.Normal.Y < CFG.VOID_RESCUE_SAFE_LANDING_NORMAL_Y then
        return false
    end
    if killY and result.Position.Y <= killY + CFG.VOID_RESCUE_SAFE_LANDING_KILL_MARGIN then
        return false
    end

    return true
end

local getPredictionHorizon

local function getSafeLandingFloorHit(grapple, killY)
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and velocity and velocity.Y < -2) then
        return nil
    end

    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    local horizon = getPredictionHorizon and getPredictionHorizon(grapple) or nil
    local tactical = tonumber(horizon and horizon.Tactical) or 0.72
    local route = tonumber(horizon and horizon.Route) or 1.3
    local gravityProfile = Logic.getGravityAssistProfile(grapple)
    local maxLandingTime = CFG.VOID_RESCUE_SAFE_LANDING_MAX_TIME + (gravityProfile.Active and 0.35 or 0)
    if Logic.MapModel and Logic.getMapModelDeps then
        local landing = Logic.MapModel.findLandingBelow(Logic.getMapModelDeps(), rootPart.Position, velocity, {
            Character = grapple.Character,
            Horizon = route,
            Radius = CFG.CONTROLLED_LANDING_COARSE_PROBE_DISTANCE,
            Depth = CFG.VOID_RESCUE_SAFE_LANDING_DEPTH,
        })
        local result = landing and landing.Result
        if isSafeLandingFloorHit(result, killY) then
            local distance = rootPart.Position.Y - result.Position.Y
            local fallSpeed = math.max(-velocity.Y, 8)
            if distance >= 0 and distance / fallSpeed <= maxLandingTime then
                return result
            end
        end
    end

    local params = getEmergencyFloorRaycastParams(grapple)
    local samples = {
        rootPart.Position,
        rootPart.Position + horizontal * 0.22,
        rootPart.Position + horizontal * 0.42,
        rootPart.Position + horizontal * math.min(tactical, 1.2),
    }
    if horizontal.Magnitude > 0.05 then
        table.insert(samples, rootPart.Position + horizontal.Unit * math.clamp(horizontal.Magnitude * route, 32, CFG.CONTROLLED_LANDING_COARSE_PROBE_DISTANCE))
    end

    local bestHit = nil
    local bestDistance = math.huge
    for _, sample in ipairs(samples) do
        local hit = Workspace:Raycast(sample, Vector3.new(0, -CFG.VOID_RESCUE_SAFE_LANDING_DEPTH, 0), params)
        if isSafeLandingFloorHit(hit, killY) then
            local distance = rootPart.Position.Y - hit.Position.Y
            if distance >= 0 and distance < bestDistance then
                bestHit = hit
                bestDistance = distance
            end
        end
    end

    if not bestHit then
        return nil
    end

    local fallSpeed = math.max(-velocity.Y, 8)
    local timeToLanding = bestDistance / fallSpeed
    if timeToLanding > maxLandingTime then
        return nil
    end

    return bestHit
end

local function isRailExitSafeFloorHit(result, killY)
    if not result then
        return false
    end

    local instance = result.Instance
    if instance and instance.Name == "KillVoid" then
        return false
    end
    if result.Normal and result.Normal.Y < CFG.RAIL_EXIT_MIN_NORMAL_Y then
        return false
    end
    if killY and result.Position.Y <= killY + CFG.VOID_RESCUE_SAFE_LANDING_KILL_MARGIN then
        return false
    end

    return true
end

local function isRailExitLandingGraceActive(grapple, killY)
    local rootPart = grapple and grapple.RootPart
    local movement = grapple and grapple.Movement
    if not (rootPart and movement) then
        return false
    end

    local exit = Logic.getGlobals().NullscapeRailLastExit
    if typeof(exit) ~= "table" then
        return false
    end

    local exitAt = tonumber(exit.At)
    if not exitAt or time() - exitAt > CFG.RAIL_EXIT_LANDING_GRACE then
        return false
    end

    if exit.Movement and exit.Movement ~= movement then
        return false
    end

    local exitPosition = exit.Position
    if typeof(exitPosition) == "Vector3" then
        local drift = Vector3.new(rootPart.Position.X - exitPosition.X, 0, rootPart.Position.Z - exitPosition.Z).Magnitude
        if drift > CFG.RAIL_EXIT_MAX_HORIZONTAL_DRIFT then
            return false
        end
    end

    local gravityProfile = Logic.getGravityAssistProfile(grapple)
    local voidBufferBonus = gravityProfile.VoidBufferBonus or 0
    if killY and rootPart.Position.Y <= killY + CFG.VOID_RESCUE_HARD_BUFFER + voidBufferBonus * 0.35 then
        return false
    end

    local params = getEmergencyFloorRaycastParams(grapple)
    local velocity = rootPart.Velocity
    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local samples = {
        rootPart.Position,
        rootPart.Position + horizontal * CFG.RAIL_EXIT_PROJECT_TIME,
    }

    local exitVelocity = exit.Velocity
    if typeof(exitVelocity) == "Vector3" then
        local exitHorizontal = Vector3.new(exitVelocity.X, 0, exitVelocity.Z)
        table.insert(samples, rootPart.Position + exitHorizontal * math.min(CFG.RAIL_EXIT_PROJECT_TIME, 0.28))
    end

    local height = CFG.PANIC_RESCUE_GROUND_CHECK_HEIGHT
    for _, sample in ipairs(samples) do
        local hit = Workspace:Raycast(
            sample + Vector3.new(0, height, 0),
            Vector3.new(0, -(CFG.RAIL_EXIT_FLOOR_DEPTH + height), 0),
            params
        )
        if isRailExitSafeFloorHit(hit, killY) then
            local distance = rootPart.Position.Y - hit.Position.Y
            if distance >= -2 then
                local fallSpeed = math.max(-velocity.Y, 12)
                local timeToLanding = math.max(distance, 0) / fallSpeed
                if timeToLanding <= CFG.RAIL_EXIT_LANDING_GRACE + 0.35 then
                    return true
                end
            end
        end
    end

    return false
end

local function getWallHit(position, direction, params)
    if not (position and direction and direction.Magnitude > 0) then
        return nil
    end

    return Workspace:Raycast(position, direction, params)
end

local function updateTerrainFallContext(grapple)
    if not (grapple and hasClassCapability(grapple, "VoidRescue") and (Logic.isVoidRescueEnabled() or Logic.isWallSlamRescueEnabled())) then
        Logic.TerrainFallState = nil
        return nil
    end

    local now = time()
    local previousState = Logic.TerrainFallState
    local airborne = Logic.isInAir(grapple)
    local scanInterval = (airborne or (previousState and previousState.Danger))
        and CFG.TERRAIN_VOID_SCAN_INTERVAL
        or CFG.TERRAIN_VOID_SAFE_SCAN_INTERVAL
    if previousState and now - (previousState.LastEvaluatedAt or 0) < scanInterval then
        return previousState
    end

    local params = getEmergencyFloorRaycastParams(grapple)
    local state = TerrainSense.analyzeVoidFall({
        CFG = CFG,
        now = time,
        getFloorHit = function(position)
            return getFloorHit(position, params)
        end,
        hasFloorBelow = function(position)
            return hasFloorBelow(position, params)
        end,
        getWallHit = function(position, direction)
            return getWallHit(position, direction, params)
        end,
        isWallSlamRescueEnabled = Logic.isWallSlamRescueEnabled,
    }, grapple, Logic.TerrainFallState)

    Logic.TerrainFallState = state
    Logic.LastTerrainFallEvalAt = now
    return state
end

local function getTerrainVoidFallState(grapple)
    local state = Logic.TerrainFallState
    if state and time() - (state.LastEvaluatedAt or 0) <= CFG.TERRAIN_VOID_CONTEXT_TTL then
        return state
    end

    return updateTerrainFallContext(grapple)
end

local function getKillVoidPart()
    local killVoid = Workspace:FindFirstChild("KillVoid")
    if killVoid and killVoid:IsA("BasePart") then
        return killVoid
    end

    return nil
end

local function getVoidKillPlaneY()
    local killVoid = getKillVoidPart()
    if killVoid then
        return killVoid.Position.Y
    end

    local fallenHeight = tonumber(Workspace.FallenPartsDestroyHeight)
    if fallenHeight then
        return fallenHeight
    end

    return nil
end

function Logic.getMapModelDeps()
    return {
        CFG = CFG,
        getVoidKillPlaneY = getVoidKillPlaneY,
        getAssistRange = getAssistRange,
        isLineClear = isLineClear,
        isUsableResult = Logic.isUsableResult,
    }
end

function Logic.updateMapModel(grapple, force)
    if not (Logic.MapModel and Logic.isSuiteEnabled() and hasClassCapability(grapple, "VoidRescue")) then
        return false
    end

    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return false
    end

    return Logic.MapModel.step(Logic.getMapModelDeps(), rootPart.Position, grapple.Character, force == true)
end

local getSafeLandingGuard
local isPanicPressureActive

local function getVoidDangerState(grapple)
    if not (hasClassCapability(grapple, "VoidRescue") and Logic.isVoidRescueEnabled()) then
        return false, nil
    end

    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    local killY = getVoidKillPlaneY()
    if not (rootPart and velocity) then
        return false, nil
    end

    local y = rootPart.Position.Y
    local gravityProfile = Logic.getGravityAssistProfile(grapple)
    local voidBufferBonus = gravityProfile.VoidBufferBonus or 0
    local landingGuard = getSafeLandingGuard and getSafeLandingGuard(grapple) or nil
    local safeLandingHit = (landingGuard and landingGuard.Safe and landingGuard.Hit) or getSafeLandingFloorHit(grapple, killY)
    if killY then
        if y <= killY + CFG.VOID_RESCUE_HARD_BUFFER + voidBufferBonus * 0.35 then
            return true, "BelowKillPlane"
        end

        if isRailExitLandingGraceActive(grapple, killY) then
            return false, "RailExitLandingGrace"
        end

        if safeLandingHit then
            return false, landingGuard and landingGuard.Reason or "SafeLandingFloor"
        end

        local nearKillPlane = y <= killY + CFG.VOID_RESCUE_KILL_PLANE_BUFFER + voidBufferBonus
        local enoughFallForMomentum = velocity.Y <= -CFG.VOID_RESCUE_MOMENTUM_MIN_FALL_SPEED
        if nearKillPlane and enoughFallForMomentum then
            return true, gravityProfile.Active and "LowGravityNearKillPlane" or "NearKillPlane"
        end

        if velocity.Y < (gravityProfile.Active and -2 or -8) then
            local projectedY = y + velocity.Y * (CFG.VOID_RESCUE_PREDICT_TIME + (gravityProfile.VoidPredictBonus or 0))
            if projectedY <= killY + CFG.VOID_RESCUE_HARD_BUFFER + voidBufferBonus * 0.5 then
                return true, gravityProfile.Active and "LowGravityProjectedKillPlane" or "ProjectedKillPlane"
            end
        end
    end

    if safeLandingHit then
        return false, landingGuard and landingGuard.Reason or "SafeLandingFloor"
    end

    if isRailExitLandingGraceActive(grapple, killY) then
        return false, "RailExitLandingGrace"
    end

    if Logic.MapModel and Logic.getMapModelDeps then
        local modelState = Logic.MapModel.getVoidRisk(Logic.getMapModelDeps(), rootPart.Position, velocity, {
            Character = grapple.Character,
            Depth = CFG.VOID_RESCUE_SAFE_LANDING_DEPTH,
            HardBuffer = CFG.VOID_RESCUE_HARD_BUFFER + voidBufferBonus * 0.35,
            Horizon = 0.72,
            MinFallSpeed = CFG.TERRAIN_VOID_FALL_SPEED,
            Radius = CFG.CONTROLLED_LANDING_COARSE_PROBE_DISTANCE,
        })
        if modelState and modelState.Danger then
            if killY and y > killY + CFG.VOID_RESCUE_MOMENTUM_GRACE_HEIGHT + voidBufferBonus and not isPanicPressureActive() then
                return false, "VoidMomentumGrace"
            end
            return true, modelState.Reason or "MapModelVoid"
        elseif modelState and modelState.Landing then
            return false, modelState.Reason or "MapModelLanding"
        end
    end

    local terrainState = getTerrainVoidFallState(grapple)
    if terrainState and terrainState.Danger then
        if killY and y > killY + CFG.VOID_RESCUE_MOMENTUM_GRACE_HEIGHT + voidBufferBonus and not isPanicPressureActive() then
            return false, "VoidMomentumGrace"
        end
        return true, terrainState.Reason or "TerrainVoidDrop"
    end

    return false, nil
end

local function isVoidRescueDanger(grapple)
    local danger = getVoidDangerState(grapple)
    return danger == true
end

local function markVoidRescueWindow()
    Logic.VoidRescueUntil = time() + CFG.VOID_RESCUE_WINDOW
    if not Logic.isMovementIntent(MOVEMENT_INTENT.JumpPadCommit) then
        Logic.setMovementIntent(MOVEMENT_INTENT.VoidRescue, CFG.VOID_RESCUE_WINDOW, "VoidDanger")
    end
end

local function isVoidRescueWindowActive()
    return time() <= (Logic.VoidRescueUntil or 0)
end

local function getProjectedUnsafeSampleCount(grapple)
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and velocity) then
        return 0, false
    end

    local killY = getVoidKillPlaneY()
    if isRailExitLandingGraceActive(grapple, killY) then
        return 0, false
    end

    local landing = getSafeLandingGuard and getSafeLandingGuard(grapple) or nil
    if (landing and landing.Safe) or getSafeLandingFloorHit(grapple, killY) then
        return 0, false
    end

    local terrainState = getTerrainVoidFallState(grapple)
    if terrainState and terrainState.Danger then
        return math.max(terrainState.UnsafeSamples or 0, CFG.TERRAIN_VOID_MIN_UNSAFE_SAMPLES), false
    end
    if killY and rootPart.Position.Y <= killY + 45 then
        return #CFG.PANIC_RESCUE_LOOKAHEADS, true
    end

    local unsafeSamples = 0
    local params = getEmergencyFloorRaycastParams(grapple)
    local horizon = getPredictionHorizon(grapple)
    local lookaheads = PredictionHorizon and PredictionHorizon.getPanicLookaheads and PredictionHorizon.getPanicLookaheads(horizon) or CFG.PANIC_RESCUE_LOOKAHEADS
    for _, lookahead in ipairs(lookaheads) do
        local projected = rootPart.Position + velocity * lookahead
        if not hasFloorBelow(projected, params) then
            unsafeSamples = unsafeSamples + 1
        end
    end

    return unsafeSamples, false
end

local function isProjectedPathUnsafe(grapple)
    local unsafeSamples, nearVoidKillPlane = getProjectedUnsafeSampleCount(grapple)
    if nearVoidKillPlane then
        return true
    end
    return unsafeSamples >= 2
end

local function notePanicInput(grapple)
    if not (grapple and Logic.isEmergencyProtectionEnabled() and Logic.isInAir(grapple)) then
        return
    end

    local now = time()
    if now - Logic.LastPanicInputAt <= CFG.PANIC_INPUT_WINDOW then
        Logic.PanicInputCount = Logic.PanicInputCount + 1
    else
        Logic.PanicInputCount = 1
    end

    Logic.LastPanicInputAt = now
    if Logic.PanicInputCount >= CFG.PANIC_INPUT_COUNT then
        Logic.PanicPressureUntil = now + CFG.PANIC_INPUT_PRESSURE_DURATION
    end
end

isPanicPressureActive = function()
    return time() <= (Logic.PanicPressureUntil or 0)
end

function Logic.isPanicRescueDanger(grapple)
    if not (grapple and Logic.isInAir(grapple)) then
        return false
    end

    if isVoidRescueDanger(grapple) then
        return true
    end

    local landing = getSafeLandingGuard and getSafeLandingGuard(grapple) or nil
    if landing and landing.Safe then
        return false
    end

    if isRailExitLandingGraceActive(grapple, getVoidKillPlaneY()) then
        return false
    end

    local terrainState = getTerrainVoidFallState(grapple)
    if terrainState and terrainState.IntentGrace then
        return false
    end
    if terrainState and terrainState.Danger then
        return true
    end

    local rootPart = grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not velocity then
        return false
    end

    local panicPressure = isPanicPressureActive()
    local speedDanger = Logic.getHorizontalVelocity(rootPart).Magnitude >= Logic.getEmergencySpeedThreshold()
    local fallDanger = velocity.Y <= -Logic.getEffectiveEmergencyFallThreshold(grapple)
    if not (speedDanger or fallDanger) then
        return false
    end

    return isProjectedPathUnsafe(grapple) or (panicPressure and fallDanger)
end

function Logic.getCachedPanicRescueDanger(grapple)
    local now = time()
    if now - Logic.LastPanicDangerEvalAt < CFG.PANIC_DANGER_EVAL_INTERVAL then
        return Logic.LastPanicDangerValue == true
    end

    Logic.LastPanicDangerEvalAt = now
    Logic.LastPanicDangerValue = Logic.isPanicRescueDanger(grapple) == true
    return Logic.LastPanicDangerValue
end

local function getModeValue(key)
    local controller = Logic.getController()
    return normalizeMode(controller and controller[key])
end

local function getSharkTailStyle()
    local controller = Logic.getController()
    return normalizeStyle(controller and controller.GrappleSharkTailStyle)
end

local function getSharkTailStyleConfig()
    return SHARK_TAIL_STYLE_CONFIG[getSharkTailStyle()] or SHARK_TAIL_STYLE_CONFIG.Balanced
end

local function hasUpgrade(movement, upgradeName)
    if not (movement and typeof(movement.HasUpgrade) == "function") then
        return false
    end

    local success, result = pcall(function()
        return movement:HasUpgrade(upgradeName)
    end)
    return success and result == true
end

local function getCurseHandler()
    if Logic.CurseHandlerLoaded then
        return Logic.CurseHandler
    end

    Logic.CurseHandlerLoaded = true
    local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
    local moduleScript = clientModules and clientModules:FindFirstChild("CurseHandler")
    if not moduleScript then
        return nil
    end

    local success, result = pcall(require, moduleScript)
    if success and typeof(result) == "table" then
        Logic.CurseHandler = result
    end

    return Logic.CurseHandler
end

local function isCurseEnabled(curseName)
    local curseHandler = getCurseHandler()
    if not (curseHandler and typeof(curseHandler.IsCurseEnabled) == "function") then
        return false
    end

    local success, result = pcall(function()
        return curseHandler.IsCurseEnabled(curseName)
    end)
    return success and result == true
end

function Logic.getGravityAssistProfile(grapple)
    local now = time()
    if Logic.LastGravityProfile and now - (Logic.LastGravityProfileAt or 0) < CFG.LOW_GRAVITY_PROFILE_TTL then
        return Logic.LastGravityProfile
    end

    local movement = grapple and grapple.Movement
    local levelValue = ReplicatedStorage:FindFirstChild("Level")
    local level = levelValue and tonumber(levelValue.Value) or 0
    local lowerGravity = isCurseEnabled("LowerGravity")
    local advancedCoil = hasUpgrade(movement, "AdvancedGravityCoil")
    local highriseGravity = level >= 23
    local active = lowerGravity or advancedCoil or highriseGravity

    local profile = {
        Active = active,
        LowerGravity = lowerGravity,
        AdvancedGravityCoil = advancedCoil,
        HighriseGravity = highriseGravity,
        FallThresholdScale = active and CFG.LOW_GRAVITY_FALL_THRESHOLD_SCALE or 1,
        VoidBufferBonus = active and CFG.LOW_GRAVITY_VOID_BUFFER_BONUS or 0,
        VoidPredictBonus = active and CFG.LOW_GRAVITY_VOID_PREDICT_BONUS or 0,
        LandingFallSpeed = active and CFG.LOW_GRAVITY_LANDING_FALL_SPEED or CFG.SMART_REEL_LANDING_FALL_SPEED,
        LandingMinBelow = active and CFG.LOW_GRAVITY_LANDING_MIN_BELOW or CFG.SMART_REEL_LANDING_PLANE_MIN_BELOW,
        LandingMaxDistance = active and CFG.LOW_GRAVITY_LANDING_MAX_DISTANCE or CFG.SMART_REEL_LANDING_MAX_DISTANCE,
        LandingScoreBonus = active and CFG.LOW_GRAVITY_LANDING_SCORE_BONUS or 0,
    }

    Logic.LastGravityProfileAt = now
    Logic.LastGravityProfile = profile
    return profile
end

function Logic.getEffectiveEmergencyFallThreshold(grapple)
    local profile = Logic.getGravityAssistProfile(grapple)
    return Logic.getEmergencyFallThreshold() * (profile.FallThresholdScale or 1)
end

local function getLevelValue()
    local levelValue = ReplicatedStorage:FindFirstChild("Level")
    return levelValue and tonumber(levelValue.Value) or 0
end

local function getPhysicsProfile(grapple, force)
    if not (PhysicsProfile and PhysicsProfile.get) then
        local fallback = Logic.getGravityAssistProfile(grapple)
        Logic.LastPhysicsProfile = fallback
        return fallback
    end

    local profile = PhysicsProfile.get({
        now = time,
        getLevel = getLevelValue,
        isCurseEnabled = isCurseEnabled,
    }, grapple, force)
    Logic.LastPhysicsProfile = profile
    return profile
end

getPredictionHorizon = function(grapple)
    if not (PredictionHorizon and PredictionHorizon.get) then
        local rootPart = grapple and grapple.RootPart
        local speed = Logic.getHorizontalVelocity(rootPart).Magnitude
        local route = math.clamp(speed / 55, 1.2, 4.2)
        local fallback = {
            Speed = speed,
            Short = math.clamp(route * 0.24, 0.25, 0.85),
            Tactical = math.clamp(route * 0.58, 1.0, 2.2),
            Route = route,
            Coarse = math.clamp(route * 1.35, 2.0, 6.0),
            Summary = string.format("H%.1f", route),
        }
        Logic.LastPredictionHorizon = fallback
        return fallback
    end

    local horizon = PredictionHorizon.get({
        now = time,
    }, grapple, getPhysicsProfile(grapple))
    Logic.LastPredictionHorizon = horizon
    return horizon
end

local function getThreatModelDeps()
    return {
        Workspace = Workspace,
        now = time,
        ScanInterval = CFG.THREAT_SCAN_INTERVAL,
        MaxDescendants = CFG.THREAT_SCAN_MAX_DESCENDANTS,
        MaxHazards = CFG.THREAT_SCAN_MAX_HAZARDS,
    }
end

local function getRouteThreat(startPosition, endPosition)
    if not (ThreatModel and ThreatModel.getRouteThreat) then
        return {
            Score = 0,
            Reason = "ThreatModelUnavailable",
        }
    end

    local threat = ThreatModel.getRouteThreat(getThreatModelDeps(), startPosition, endPosition, {
        MaxDistance = CFG.MAP_ANCHOR_THREAT_MAX_DISTANCE,
    })
    Logic.LastThreatSnapshot = threat
    return threat
end

local function getLandingThreat(hit)
    if not (ThreatModel and ThreatModel.getLandingThreat) then
        return {
            Score = 0,
            Reason = "ThreatModelUnavailable",
        }
    end

    local threat = ThreatModel.getLandingThreat(getThreatModelDeps(), hit)
    Logic.LastThreatSnapshot = threat
    return threat
end

getSafeLandingGuard = function(grapple)
    if not (SafeLandingGuard and SafeLandingGuard.analyze) then
        return nil
    end

    local params = getEmergencyFloorRaycastParams(grapple)
    local horizon = getPredictionHorizon(grapple)
    local landing = SafeLandingGuard.analyze({
        now = time,
        VelocityAssist = VelocityAssist,
        getPhysicsProfile = getPhysicsProfile,
        getPredictionHorizon = getPredictionHorizon,
        getVoidKillPlaneY = getVoidKillPlaneY,
        getLandingThreat = getLandingThreat,
        getInputDirection = function(innerGrapple)
            return innerGrapple and innerGrapple.Movement and innerGrapple.Movement.PlayerMoveDirection
        end,
        canAirJump = function()
            local controller = Logic.getController()
            return controller and controller.InfiniteAirJumpEnabled == true
        end,
        raycastFloor = function(position, depth)
            local height = CFG.PANIC_RESCUE_GROUND_CHECK_HEIGHT
            return Workspace:Raycast(position + Vector3.new(0, height, 0), Vector3.new(0, -((depth or CFG.VOID_RESCUE_SAFE_LANDING_DEPTH) + height), 0), params)
        end,
        raycastCoarseFloor = function(position, depth)
            local height = CFG.PANIC_RESCUE_GROUND_CHECK_HEIGHT * 1.5
            return Workspace:Raycast(position + Vector3.new(0, height, 0), Vector3.new(0, -((depth or CFG.VOID_RESCUE_SAFE_LANDING_DEPTH) + height), 0), params)
        end,
    }, grapple, {
        Depth = CFG.VOID_RESCUE_SAFE_LANDING_DEPTH,
        MaxTime = CFG.VOID_RESCUE_SAFE_LANDING_MAX_TIME,
        ControlledMaxTime = math.max(CFG.CONTROLLED_LANDING_MAX_TIME, horizon.Route or CFG.CONTROLLED_LANDING_MAX_TIME),
        ControlProbeTime = math.max(CFG.CONTROLLED_LANDING_PROBE_TIME, horizon.Tactical or CFG.CONTROLLED_LANDING_PROBE_TIME),
        MaxControlProbeDistance = CFG.CONTROLLED_LANDING_MAX_PROBE_DISTANCE,
        MaxCoarseProbeDistance = CFG.CONTROLLED_LANDING_COARSE_PROBE_DISTANCE,
        MinControlledHorizontalSpeed = CFG.CONTROLLED_LANDING_MIN_HORIZONTAL_SPEED,
        MinNormalY = CFG.VOID_RESCUE_SAFE_LANDING_NORMAL_Y,
        KillMargin = CFG.VOID_RESCUE_SAFE_LANDING_KILL_MARGIN,
        MaxThreatScore = CFG.SAFE_LANDING_MAX_THREAT_SCORE,
    })
    Logic.LastLandingGuard = landing
    return landing
end

function Logic.getHorizontalVelocity(rootPart)
    local velocity = rootPart and rootPart.Velocity
    if not velocity then
        return Vector3.new(0, 0, 0)
    end

    return velocity * Vector3.new(1, 0, 1)
end

local function getFallbackHitbox(rootPart)
    if Logic.FallbackHitbox and Logic.FallbackHitbox.Parent then
        Logic.FallbackHitbox.CFrame = rootPart.CFrame
        return Logic.FallbackHitbox
    end

    local part = Instance.new("Part")
    part.Name = "NULLSCAPE_GrappleFallbackHitbox"
    part.Size = CFG.FALLBACK_HITBOX_SIZE
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CFrame = rootPart.CFrame
    part.Parent = Workspace
    Logic.FallbackHitbox = part

    return part
end

local function getStaminaRatio(grapple)
    if Logic.isInfiniteStamina() then
        return 1
    end

    local maxTime = tonumber(grapple and grapple.usedGrappleTime) or tonumber(grapple and grapple.TimeClamp) or 0
    local currentTime = tonumber(grapple and grapple.Time) or 0
    if maxTime <= 0 then
        return 1
    end

    return math.clamp(currentTime / maxTime, 0, 1)
end

local function refillStamina(grapple)
    if not Logic.isInfiniteStamina() or typeof(grapple) ~= "table" then
        return
    end

    local maxTime = tonumber(grapple.usedGrappleTime) or tonumber(grapple.TimeClamp) or tonumber(grapple.Time)
    if not maxTime or maxTime <= 0 then
        return
    end

    grapple.Time = maxTime
    grapple.TimeClamp = maxTime
    grapple.TimeDrained = false

    local ui = grapple.UI
    local frame = ui and ui:FindFirstChild("Frame")
    local bar = frame and frame:FindFirstChild("Bar")
    if bar then
        pcall(function()
            bar.Size = UDim2.fromScale(1, 1)
        end)
    end
end

local function getAssistRange(grapple, ignoreStamina)
    if ignoreStamina then
        return CFG.DEFAULT_MAX_RANGE
    end

    local staminaRatio = getStaminaRatio(grapple)
    if staminaRatio < 0.3 then
        return 45
    elseif staminaRatio < 0.6 then
        return 70
    end

    return CFG.DEFAULT_MAX_RANGE
end

local function shouldForceNearest(grapple)
    return not Logic.isInfiniteStamina() and getStaminaRatio(grapple) < 0.3
end

local function getScreenAnchor(camera, rangeMode)
    if rangeMode == "Closest To Cursor" then
        local mouseLocation = UserInputService:GetMouseLocation()
        local viewportSize = camera.ViewportSize
        if mouseLocation.X >= 0 and mouseLocation.Y >= 0 and mouseLocation.X <= viewportSize.X and mouseLocation.Y <= viewportSize.Y then
            return mouseLocation
        end
    end

    return camera.ViewportSize * 0.5
end

local function getCameraScreenScore(camera, worldPosition, anchor)
    local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
    if not onScreen or viewportPoint.Z <= 0 then
        return nil
    end

    local viewportSize = camera.ViewportSize
    if viewportPoint.X < 0 or viewportPoint.Y < 0 or viewportPoint.X > viewportSize.X or viewportPoint.Y > viewportSize.Y then
        return nil
    end

    local delta = Vector2.new(viewportPoint.X, viewportPoint.Y) - anchor
    return delta.Magnitude / math.max(viewportSize.X, viewportSize.Y)
end

local function isLineClear(grapple, targetInstance, targetPart, targetPosition, maxRange)
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return nil
    end

    local offset = targetPosition - rootPart.Position
    local distance = offset.Magnitude
    if distance <= 0 or distance > maxRange then
        return nil
    end

    local result = Workspace:Raycast(rootPart.Position, offset, grapple.grappleParams)
    if not result then
        return nil
    end

    if result.Instance == targetPart or result.Instance:IsDescendantOf(targetInstance) then
        return result, distance
    end

    return nil
end

local function isTargetHit(result, targetInstance, targetPart)
    if not result or not result.Instance then
        return false
    end

    return result.Instance == targetPart or result.Instance:IsDescendantOf(targetInstance)
end

local function isPathSafeForHitbox(grapple, targetInstance, targetPart, targetPosition, maxRange)
    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return nil
    end

    local offset = targetPosition - rootPart.Position
    local distance = offset.Magnitude
    if distance <= 0 or distance > maxRange then
        return nil
    end

    local hitbox = movement and movement.Hitbox
    if not (hitbox and hitbox.Parent and hitbox:IsA("BasePart")) then
        hitbox = getFallbackHitbox(rootPart)
    end

    local size = hitbox.Size or CFG.FALLBACK_HITBOX_SIZE
    local buffer = math.max(size.X, size.Y, size.Z) * 0.5
    local castDistance = math.max(distance - buffer, 0)
    if castDistance <= 0 then
        return true
    end

    local direction = offset.Unit * castDistance
    local success, result = pcall(function()
        return Workspace:Shapecast(hitbox, direction, movement and movement.moveCastParams or grapple.grappleParams)
    end)
    if not success then
        return true
    end

    if not result then
        return true
    end

    if isTargetHit(result, targetInstance, targetPart) then
        return true
    end

    if result.Normal and result.Normal.Y < 0.7 then
        return false
    end

    return false
end

local function isBellInstance(instance)
    return instance and instance.Name == "Bell"
end

function Logic.isJumpPadInstance(instance)
    return instance and instance.Name == "JumpPad" and instance:IsA("BasePart")
end

local function cacheJumpPadState(part)
    if not Logic.isJumpPadInstance(part) or Logic.JumpPadStates[part] then
        return
    end

    local textures = {}
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Texture") then
            textures[child] = {
                Color3 = child.Color3,
                Speed = child:GetAttribute("Speed"),
            }
        end
    end

    Logic.JumpPadStates[part] = {
        Uses = part:GetAttribute("Uses"),
        CanQuery = part.CanQuery,
        Color = part.Color,
        Textures = textures,
    }
end

local function normalizeJumpPadForReuse(part)
    if not Logic.isJumpPadInstance(part) then
        return
    end

    cacheJumpPadState(part)

    pcall(function()
        part:SetAttribute("Uses", nil)
    end)
    pcall(function()
        part.CanQuery = true
    end)

    local state = Logic.JumpPadStates[part]
    if state then
        pcall(function()
            part.Color = state.Color
        end)

        for texture, textureState in pairs(state.Textures or {}) do
            if texture and texture.Parent then
                pcall(function()
                    texture.Color3 = textureState.Color3
                    texture:SetAttribute("Speed", textureState.Speed)
                end)
            end
        end
    end
end

local function restoreJumpPad(part, state)
    if not (part and part.Parent and state) then
        return
    end

    pcall(function()
        part:SetAttribute("Uses", state.Uses)
    end)
    pcall(function()
        part.CanQuery = state.CanQuery
        part.Color = state.Color
    end)

    for texture, textureState in pairs(state.Textures or {}) do
        if texture and texture.Parent then
            pcall(function()
                texture.Color3 = textureState.Color3
                texture:SetAttribute("Speed", textureState.Speed)
            end)
        end
    end
end

local function restoreJumpPadBypassParts()
    for part, state in pairs(Logic.JumpPadStates) do
        restoreJumpPad(part, state)
    end
    table.clear(Logic.JumpPadStates)
end

local function maintainJumpPadUsesBypass()
    local enabled = Logic.isJumpPadUsesBypassEnabled()
    if not enabled then
        if Logic.LastJumpPadUsesBypassEnabled then
            restoreJumpPadBypassParts()
        end
        Logic.LastJumpPadUsesBypassEnabled = false
        return
    end

    Logic.LastJumpPadUsesBypassEnabled = true

    local jumpPads = Workspace:FindFirstChild("JumpPads")
    if not jumpPads then
        return
    end

    for _, child in ipairs(jumpPads:GetChildren()) do
        if Logic.isJumpPadInstance(child) then
            normalizeJumpPadForReuse(child)
        end
    end
end

local function getSavedBellData(part)
    local gc = getEntitiesGC()
    local data = gc and gc.SavedPartsData and gc.SavedPartsData[part]
    if data and data.enemyName and string.find(string.lower(data.enemyName), "bell") then
        return gc, data
    end
    return gc, nil
end

local function hasSavedBellImmunity(part)
    local _, data = getSavedBellData(part)
    return data ~= nil
end

local function releaseBellBypass()
    local bypass = Logic.BellBypass
    if not bypass then
        return
    end

    local part = bypass.Part
    local data = bypass.Data
    local _, currentData = getSavedBellData(part)
    if part and part.Parent and data and currentData == data then
        data.connections = data.connections or {}

        pcall(function()
            part.CanTouch = false
        end)

        local conn = part:GetPropertyChangedSignal("CanTouch"):Connect(function()
            if part.CanTouch then
                part.CanTouch = false
            end
        end)
        table.insert(data.connections, conn)
    elseif part and part.Parent and bypass.RestoreCanTouch ~= nil then
        pcall(function()
            part.CanTouch = bypass.RestoreCanTouch
        end)
    end

    Logic.BellBypass = nil
end

local function scheduleBellBypassRelease(delaySeconds)
    if not Logic.BellBypass then
        return
    end

    Logic.BellBypassToken = Logic.BellBypassToken + 1
    local token = Logic.BellBypassToken

    task.delay(delaySeconds or 0.5, function()
        if token ~= Logic.BellBypassToken then
            return
        end

        releaseBellBypass()
    end)
end

local function holdBellBypass(part)
    if not part or not part.Parent or part.Name ~= "Bell" then
        return
    end

    if Logic.BellBypass and Logic.BellBypass.Part == part then
        if not part.CanTouch then
            pcall(function()
                part.CanTouch = true
            end)
        end
        return
    end

    Logic.BellBypassToken = Logic.BellBypassToken + 1
    releaseBellBypass()

    local _, data = getSavedBellData(part)
    if data then
        for _, conn in ipairs(data.connections or {}) do
            if conn then
                pcall(function()
                    conn:Disconnect()
                end)
            end
        end
        data.connections = {}

        Logic.BellBypass = {
            Part = part,
            Data = data,
        }
    elseif not part.CanTouch then
        Logic.BellBypass = {
            Part = part,
            RestoreCanTouch = false,
        }
    end

    if Logic.BellBypass then
        pcall(function()
            part.CanTouch = true
        end)
    end
end

local function maintainBellBypass(grapple)
    if not hasClassCapability(grapple, "BellBypass") then
        scheduleBellBypassRelease(0.5)
        return
    end

    local movement = grapple and grapple.Movement
    local part = grapple and grapple.grapplePart
    if movement and movement.grappling and isBellInstance(part) then
        holdBellBypass(part)
    else
        scheduleBellBypassRelease(0.5)
    end
end

local function getCandidateList()
    local list = {}
    for _, candidate in pairs(Logic.Candidates) do
        table.insert(list, candidate)
    end
    return list
end



local function getMapSenseDeps()
    return {
        CFG = CFG,
        Workspace = Workspace,
        VALID_TARGETS = VALID_TARGETS,
        getTargetPart = getTargetPart,
        getAssistRange = getAssistRange,
        isLineClear = isLineClear,
        isUsableResult = Logic.isUsableResult,
        isPathSafeForHitbox = isPathSafeForHitbox,
        getRouteThreat = getRouteThreat,
        now = time,
    }
end

local function scanMapVoidAnchor(grapple, options)
    if Logic.MapModel and Logic.getMapModelDeps then
        local modelResult = Logic.MapModel.findBestAnchor(Logic.getMapModelDeps(), grapple, options)
        if modelResult then
            return modelResult
        end
    end

    return MapSense.findBestVoidAnchor(getMapSenseDeps(), grapple, options)
end

local function canUseKillVoidSharkTailSaver(grapple, requireUseWindow)
    if CFG.SHARK_TAIL_VOID_SAVER_ENABLED ~= true then
        return false
    end

    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (grapple and movement and rootPart and hasClassCapability(grapple, "SharkTail")) then
        return false
    end
    if not (Logic.isVoidRescueEnabled() and Logic.isSharkTailHelperEnabled() and Logic.isInAir(grapple)) then
        return false
    end
    if not (hasUpgrade(movement, "NinjaBelt") and hasUpgrade(movement, "SharkTail")) then
        return false
    end
    if grapple.sharkTailDisable == true then
        return false
    end
    if requireUseWindow and grapple.allowSharkTail ~= true then
        return false
    end

    local killY = getVoidKillPlaneY()
    if not killY then
        return false
    end

    local velocity = rootPart.Velocity
    local buffer = requireUseWindow and CFG.SHARK_TAIL_VOID_SAVER_USE_BUFFER or CFG.SHARK_TAIL_VOID_SAVER_TRIGGER_BUFFER
    if rootPart.Position.Y > killY + buffer then
        return false
    end
    if velocity.Y > CFG.SHARK_TAIL_VOID_SAVER_MAX_UP_SPEED then
        return false
    end

    return Logic.getHorizontalVelocity(rootPart).Magnitude >= CFG.SHARK_TAIL_VOID_SAVER_MIN_SPEED
end

local function getKillVoidSaverDirections(grapple)
    local function flatUnit(vector)
        local flat = vector and Vector3.new(vector.X, 0, vector.Z)
        if not flat or flat.Magnitude <= 0.05 then
            return nil
        end
        return flat.Unit
    end

    local rootPart = grapple and grapple.RootPart
    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local forward = flatUnit(horizontal)
    if not forward then
        local camera = Workspace.CurrentCamera
        forward = flatUnit(camera and camera.CFrame.LookVector)
    end
    if not forward then
        forward = Vector3.new(1, 0, 0)
    end

    local side = forward:Cross(Vector3.yAxis)
    if side.Magnitude <= 0.05 then
        side = Vector3.new(0, 0, 1)
    else
        side = side.Unit
    end

    return {
        forward * CFG.SHARK_TAIL_VOID_SAVER_FORWARD_OFFSET + side * CFG.SHARK_TAIL_VOID_SAVER_LATERAL_OFFSET,
        forward * CFG.SHARK_TAIL_VOID_SAVER_FORWARD_OFFSET - side * CFG.SHARK_TAIL_VOID_SAVER_LATERAL_OFFSET,
        side * CFG.SHARK_TAIL_VOID_SAVER_LATERAL_OFFSET,
        -side * CFG.SHARK_TAIL_VOID_SAVER_LATERAL_OFFSET,
    }
end

local function scanKillVoidSharkTailAnchor(grapple, options)
    if not canUseKillVoidSharkTailSaver(grapple, false) then
        return nil
    end

    local killVoid = getKillVoidPart()
    local rootPart = grapple and grapple.RootPart
    if not (killVoid and rootPart) then
        return nil
    end

    local maxRange = getAssistRange(grapple, typeof(options) == "table" and options.driveMode == true)
    local bestResult = nil
    local bestDistance = math.huge
    for _, offset in ipairs(getKillVoidSaverDirections(grapple)) do
        local targetPosition = Vector3.new(rootPart.Position.X, killVoid.Position.Y, rootPart.Position.Z) + offset
        local direction = targetPosition - rootPart.Position
        local distance = direction.Magnitude
        if distance > 0 and distance <= maxRange then
            local result = Workspace:Raycast(rootPart.Position, direction, grapple.grappleParams)
            if result and (result.Instance == killVoid or result.Instance:IsDescendantOf(killVoid)) and distance < bestDistance then
                bestResult = result
                bestDistance = distance
            end
        end
    end

    if not bestResult then
        return nil
    end

    Logic.LastAssistDebug = {
        Reason = "KillVoidSharkTailAnchor",
        Target = "KillVoid",
        Distance = bestDistance,
    }

    if typeof(options) == "table" and options.returnDecision == true then
        return {
            Result = bestResult,
            Instance = bestResult.Instance,
            Name = "KillVoid",
            Distance = bestDistance,
            ScreenScore = 0,
            Score = -220,
            Reason = "KillVoidSharkTailAnchor",
            VoidDanger = true,
        }
    end

    return bestResult
end

local function chooseRandomCandidate(validResults, preferredName)
    local preferred = {}
    for _, item in ipairs(validResults) do
        if item.Name == preferredName then
            table.insert(preferred, item)
        end
    end

    local source = #preferred > 0 and preferred or validResults
    if #source == 0 then
        return nil
    end

    local selected = source[Logic.Random:NextInteger(1, #source)]
    return selected.Result, selected.Instance, "Random"
end

local function getAssistFlatUnit(vector)
    if typeof(vector) ~= "Vector3" then
        return nil
    end

    local flat = vector * Vector3.new(1, 0, 1)
    if flat.Magnitude <= 0.05 then
        return nil
    end

    return flat.Unit
end

local function getAssistIntentDirections(grapple)
    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    local inputDirection = getAssistFlatUnit(movement and movement.PlayerMoveDirection)
    local velocityDirection = getAssistFlatUnit(rootPart and rootPart.Velocity)
    return inputDirection, velocityDirection
end

local function getAssistIntentPenalty(rootPart, targetPosition, inputDirection, velocityDirection)
    if not rootPart or typeof(targetPosition) ~= "Vector3" then
        return 0
    end

    local targetDirection = getAssistFlatUnit(targetPosition - rootPart.Position)
    if not targetDirection then
        return 0
    end

    local penalty = 0
    if inputDirection then
        local inputAlignment = math.clamp((targetDirection:Dot(inputDirection) + 1) * 0.5, 0, 1)
        penalty = penalty + (1 - inputAlignment) * CFG.ASSIST_INPUT_INTENT_WEIGHT
    end
    if velocityDirection then
        local velocityAlignment = math.clamp((targetDirection:Dot(velocityDirection) + 1) * 0.5, 0, 1)
        penalty = penalty + (1 - velocityAlignment) * CFG.ASSIST_VELOCITY_INTENT_WEIGHT
    end

    return penalty
end

local function getRouteAssistBonus(rootPart, targetPosition)
    if not rootPart or typeof(targetPosition) ~= "Vector3" then
        return 0
    end

    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local speed = horizontal.Magnitude
    if speed < 45 then
        return 0
    end

    local projectedPosition = rootPart.Position + horizontal * CFG.ASSIST_ROUTE_LOOKAHEAD
    local currentDistance = (targetPosition - rootPart.Position).Magnitude
    local projectedDistance = (targetPosition - projectedPosition).Magnitude
    if projectedDistance >= currentDistance then
        return 0
    end

    local improvement = math.clamp((currentDistance - projectedDistance) / math.max(currentDistance, 1), 0, 1)
    return CFG.ASSIST_ROUTE_BONUS * improvement
end

local function getWrongAnchorPenalty(rootPart, targetPosition, inputDirection, velocityDirection, allowPrecision)
    if allowPrecision or not rootPart or typeof(targetPosition) ~= "Vector3" then
        return 0
    end

    local targetDirection = getAssistFlatUnit(targetPosition - rootPart.Position)
    if not targetDirection then
        return 0
    end

    local worstDot = 1
    if inputDirection then
        worstDot = math.min(worstDot, targetDirection:Dot(inputDirection))
    end
    if velocityDirection then
        worstDot = math.min(worstDot, targetDirection:Dot(velocityDirection))
    end
    if worstDot >= CFG.ASSIST_WRONG_ANCHOR_DOT then
        return 0
    end

    return CFG.ASSIST_WRONG_ANCHOR_PENALTY * math.clamp((CFG.ASSIST_WRONG_ANCHOR_DOT - worstDot) / 1.65, 0, 1)
end

local function getSpecialAnchorBonus(grapple, targetName, targetPosition)
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not (rootPart and velocity) then
        return 0
    end

    local horizontalSpeed = Logic.getHorizontalVelocity(rootPart).Magnitude
    if targetName == "TriaOrb" and horizontalSpeed >= CFG.ASSIST_SPECIAL_TRIA_SPEED then
        return -22
    elseif targetName == "Bell" and velocity.Y <= CFG.ASSIST_SPECIAL_BELL_FALL_SPEED then
        return -16
    elseif targetName == "JumpPad" and velocity.Y <= CFG.ASSIST_SPECIAL_JUMPPAD_FALL_SPEED and targetPosition.Y >= rootPart.Position.Y - 8 then
        return -14
    end

    return 0
end

local function getAimAssistStrengthScale()
    local controller = Logic.getController()
    local value = tostring(controller and controller.GrappleAimAssistStrength or "Balanced")
    if value == "Light" then
        return 0.75
    elseif value == "Strong" then
        return 1.25
    elseif value == "Motor Accessibility" then
        return 1.6
    end

    return 1
end

local function getAdaptDriveScore(grapple, candidate, position, distance, screenScore)
    local rootPart = grapple and grapple.RootPart
    local movement = grapple and grapple.Movement
    if not (rootPart and movement) then
        return math.huge
    end

    local velocity = rootPart.Velocity
    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local horizontalSpeed = horizontal.Magnitude
    local targetDirection = getAssistFlatUnit(position - rootPart.Position)
    local velocityDirection = getAssistFlatUnit(horizontal)
    local inputDirection = getAssistFlatUnit(movement.PlayerMoveDirection)
    local cameraDirection = getAssistFlatUnit(Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector)
    local intentDirection = inputDirection or velocityDirection or cameraDirection

    local score = screenScore * CFG.ADAPT_DRIVE_SCREEN_WEIGHT + distance * CFG.ADAPT_DRIVE_DISTANCE_WEIGHT
    if candidate.Name == "GrapplePoint" then
        score = score + CFG.ADAPT_DRIVE_GRAPPLEPOINT_BONUS
    end

    if targetDirection and intentDirection then
        local intentDot = targetDirection:Dot(intentDirection)
        if intentDot > 0.25 then
            score = score + CFG.ADAPT_DRIVE_FORWARD_BONUS * math.clamp(intentDot, 0, 1)
        elseif intentDot < -0.15 then
            score = score + CFG.ADAPT_DRIVE_BACKWARD_PENALTY * math.clamp(-intentDot, 0, 1)
        end
    end

    if horizontalSpeed > 35 then
        local projected = rootPart.Position + horizontal * CFG.ADAPT_DRIVE_CHAIN_LOOKAHEAD
        local currentDistance = (position - rootPart.Position).Magnitude
        local projectedDistance = (position - projected).Magnitude
        if projectedDistance < currentDistance then
            score = score - math.clamp((currentDistance - projectedDistance) / math.max(currentDistance, 1), 0, 1) * 22
        end
    end

    if (candidate.Name == "JumpPad" or candidate.Name == "Bell") and velocity.Y <= CFG.ADAPT_DRIVE_SPECIAL_FALL_SPEED then
        score = score + CFG.ADAPT_DRIVE_BOUNCE_BONUS
    elseif candidate.Name == "TriaOrb" then
        if horizontalSpeed >= CFG.ASSIST_SPECIAL_TRIA_SPEED then
            score = score + CFG.ADAPT_DRIVE_TRIA_STEER_BONUS
        end
        if targetDirection and intentDirection and targetDirection:Dot(intentDirection) > 0.15 then
            score = score + CFG.ADAPT_DRIVE_TRIA_CENTER_BONUS
        end
    end

    return score
end

local function getAssistLockBonus(candidateInstance)
    if candidateInstance and candidateInstance == Logic.LastAssistTargetInstance and time() - Logic.LastAssistTargetAt <= CFG.ASSIST_TARGET_LOCK_DURATION then
        return CFG.ASSIST_TARGET_LOCK_BONUS
    end

    return 0
end

local function isRescueTargetName(targetName)
    return targetName == "Bell"
        or targetName == "JumpPad"
        or targetName == "TriaOrb"
        or targetName == "GrapplePoint"
end

local function getPanicTargetPriority(targetName, distance, verticalOffset)
    distance = tonumber(distance) or math.huge
    verticalOffset = tonumber(verticalOffset) or 0

    if targetName == "Bell" then
        if distance <= CFG.PANIC_BELL_NEAR_DISTANCE then
            return -140
        end
        return 35
    elseif targetName == "JumpPad" then
        if distance <= CFG.PANIC_JUMPPAD_NEAR_DISTANCE and verticalOffset >= -12 then
            return -45
        end
        return 95
    elseif targetName == "TriaOrb" then
        return 0
    elseif targetName == "GrapplePoint" then
        if distance <= CFG.PANIC_GRAPPLEPOINT_NEAR_DISTANCE and verticalOffset >= -18 then
            return 65
        end
        return 185
    end

    return 500
end

local function getPanicRescueScore(grapple, candidate, position, distance, screenScore)
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return math.huge
    end

    local velocity = rootPart.Velocity
    local toTarget = position - rootPart.Position
    local targetDirection = getAssistFlatUnit(toTarget)
    local fallDirection = getAssistFlatUnit(Vector3.new(velocity.X, math.min(velocity.Y, 0), velocity.Z) * Vector3.new(1, 0, 1))
    local fallAlignmentPenalty = 0
    if targetDirection and fallDirection then
        fallAlignmentPenalty = math.clamp((targetDirection:Dot(fallDirection) + 1) * 0.5, 0, 1) * CFG.PANIC_TARGET_FALL_ALIGNMENT_WEIGHT
    end

    local verticalOffset = position.Y - rootPart.Position.Y
    local upwardScore = math.clamp(verticalOffset, -35, 80) * CFG.PANIC_TARGET_UPWARD_WEIGHT
    local distanceScore = distance * 0.018
    local screenRescueScore = screenScore * 45
    local voidScore = 0
    if isVoidRescueWindowActive() or isVoidRescueDanger(grapple) then
        if verticalOffset < -8 then
            voidScore = voidScore + CFG.VOID_RESCUE_LOW_TARGET_PENALTY
        else
            voidScore = voidScore + CFG.VOID_RESCUE_TARGET_UPWARD_BONUS
        end

        if candidate.Name == "GrapplePoint" then
            voidScore = voidScore - 26
        elseif candidate.Name == "JumpPad" and verticalOffset >= -4 then
            voidScore = voidScore - 18
        elseif candidate.Name == "Bell" then
            voidScore = voidScore - 14
        end
    end

    return getPanicTargetPriority(candidate.Name, distance, verticalOffset)
        + distanceScore
        + screenRescueScore
        + fallAlignmentPenalty
        + upwardScore
        + voidScore
end

local function getTerrainSenseDeps()
    return {
        CFG = CFG,
        isVoidRescueWindowActive = isVoidRescueWindowActive,
        isVoidRescueDanger = isVoidRescueDanger,
    }
end

local function getTerrainSurfaceScore(grapple, result, screenScore, driveMode)
    return TerrainSense.scoreSurface(getTerrainSenseDeps(), grapple, result, screenScore, driveMode)
end

local function getIntentModelDeps()
    return {
        CFG = CFG,
        getAssistFlatUnit = getAssistFlatUnit,
        getHorizontalVelocity = Logic.getHorizontalVelocity,
        isPanicPressureActive = isPanicPressureActive,
        isVoidRescueDanger = isVoidRescueDanger,
        isJumpPadCommitGuardActive = Logic.isJumpPadCommitGuardActive,
        getPhysicsProfile = getPhysicsProfile,
        hasSafeLanding = function(grapple)
            local landing = getSafeLandingGuard(grapple)
            if landing then
                return landing.Safe == true
            end
            return getSafeLandingFloorHit(grapple, getVoidKillPlaneY()) ~= nil
        end,
    }
end

local function getIntentSnapshot(grapple, rescueResult)
    local now = time()
    if Logic.LastIntentSnapshot
        and Logic.LastIntentSnapshotGrapple == grapple
        and Logic.LastIntentSnapshotRescueResult == rescueResult
        and now - (Logic.LastIntentSnapshotAt or 0) <= 0.035
    then
        return Logic.LastIntentSnapshot
    end

    if not (IntentModel and typeof(IntentModel.classify) == "function") then
        local fallback = {
            State = "Unavailable",
            Reason = "IntentModelUnavailable",
            Suppression = 0,
            VoidDanger = false,
            JumpPadCommit = false,
            SafeLanding = false,
        }
        Logic.LastIntentSnapshot = fallback
        Logic.LastIntentSnapshotAt = now
        Logic.LastIntentSnapshotGrapple = grapple
        Logic.LastIntentSnapshotRescueResult = rescueResult
        return fallback
    end

    local snapshot = IntentModel.classify(getIntentModelDeps(), grapple, rescueResult)
    Logic.LastIntentSnapshot = snapshot
    Logic.LastIntentSnapshotAt = now
    Logic.LastIntentSnapshotGrapple = grapple
    Logic.LastIntentSnapshotRescueResult = rescueResult
    return snapshot
end

local function getPlayerIntentSuppression(grapple, rescueResult)
    local snapshot = getIntentSnapshot(grapple, rescueResult)
    return snapshot.Suppression or 0, snapshot.Reason or "NoIntent"
end

local function canRunAssist(assistName, grapple, options)
    if not (AssistArbiter and AssistArbiter.canRun) then
        return true
    end

    local intent = getIntentSnapshot(grapple, options and options.RescueResult)
    return AssistArbiter.canRun(Logic.AssistArbiterState, assistName, intent, options)
end

local function claimAssist(assistName, reason, duration)
    if AssistArbiter and AssistArbiter.claim then
        AssistArbiter.claim(Logic.AssistArbiterState, assistName, reason, duration)
    end
end

local function getGrapplerEmergencyDecisionDeps()
    return {
        CFG = CFG,
        GRAPPLER_CLASS_ID = GRAPPLER_CLASS_ID,
        getClassId = getClassId,
        getProjectedUnsafeSampleCount = getProjectedUnsafeSampleCount,
        getVoidDangerState = getVoidDangerState,
        getAssistFlatUnit = getAssistFlatUnit,
        getHorizontalVelocity = Logic.getHorizontalVelocity,
        isPanicPressureActive = isPanicPressureActive,
        getEmergencyProtectionMode = Logic.getEmergencyProtectionMode,
        getEmergencyFallThreshold = Logic.getEffectiveEmergencyFallThreshold,
        getPlayerIntentSuppression = getPlayerIntentSuppression,
        isRescueTargetName = isRescueTargetName,
        getPhysicsProfile = getPhysicsProfile,
    }
end

local function createGrapplerEmergencyDecision(grapple, rescueResult)
    return EmergencyDecision.createDecision(getGrapplerEmergencyDecisionDeps(), grapple, rescueResult)
end

local function rememberAssistTarget(candidateInstance, reason, score)
    Logic.LastAssistTargetInstance = candidateInstance
    Logic.LastAssistTargetAt = time()
    Logic.LastAssistDebug = {
        Reason = reason,
        Score = score,
    }
end

local function getEffectivePreferredTarget(grapple, preferredName)
    if isAutoRescueWindowActive() and isEmergencyAssistDanger(grapple) then
        return preferredName
    end

    return preferredName
end

local function scanNamedTargets(grapple, options)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end
    local rootPart = grapple and grapple.RootPart

    local driveMode = typeof(options) == "table" and options.driveMode == true
    local returnDecision = typeof(options) == "table" and options.returnDecision == true
    local fullScan = typeof(options) == "table" and options.fullScan == true

    local controller = Logic.getController()
    local preferredName = Logic.normalizeTargetPriority(controller and controller.GrappleAimAssistTargetPriority)
    local rescueMode = Logic.isRescueEnabled() and isFallingFast(grapple)
    local emergencyBrakeMode = isEmergencyAssistDanger(grapple) and isAutoRescueWindowActive()
    local panicMode = emergencyBrakeMode and Logic.getCachedPanicRescueDanger(grapple)
    preferredName = getEffectivePreferredTarget(grapple, preferredName)
    local rangeMode = normalizeRangePriority(controller and controller.GrappleAimAssistRangePriority)
    if emergencyBrakeMode or (not driveMode and shouldForceNearest(grapple)) then
        rangeMode = "Nearest"
    end

    local maxRange = getAssistRange(grapple, driveMode)
    local staminaRatio = getStaminaRatio(grapple)
    local screenAnchor = getScreenAnchor(camera, rangeMode)
    local inputDirection, velocityDirection = getAssistIntentDirections(grapple)
    local candidateList = getCandidateList()
    local candidateCount = #candidateList
    if candidateCount == 0 then
        return nil
    end

    local validResults = {}
    local rescuePriority = {
        Bell = 0,
        GrapplePoint = 1,
        JumpPad = 2,
        TriaOrb = 3,
    }
    local bestScore = math.huge
    local bestResult = nil
    local bestTargetInstance = nil
    local bestTargetName = nil
    local bestDistance = nil
    local bestScreenScore = nil
    local bestReason = nil
    local checks = (fullScan or driveMode or emergencyBrakeMode or rangeMode == "Closest To Cursor")
        and candidateCount
        or math.min(candidateCount, CFG.MAX_CANDIDATES_PER_CAST)

    for _ = 1, checks do
        if Logic.CandidateCursor > candidateCount then
            Logic.CandidateCursor = 1
        end

        local candidate = candidateList[Logic.CandidateCursor]
        Logic.CandidateCursor = Logic.CandidateCursor + 1

        local part = candidate and candidate.Part
        if part and part.Parent then
            if candidate.Name ~= "Bell" or part.CanTouch or hasSavedBellImmunity(part) then
                local position = part.Position
                local screenScore = getCameraScreenScore(camera, position, screenAnchor)
                if screenScore then
                    local isLockedTarget = candidate.Instance == Logic.LastAssistTargetInstance
                    if
                        rangeMode == "Closest To Cursor"
                        and not rescueMode
                        and not emergencyBrakeMode
                        and not isLockedTarget
                        and screenScore > CFG.ASSIST_CURSOR_PREFILTER_LIMIT
                    then
                        continue
                    end

                    local result, distance = isLineClear(grapple, candidate.Instance, part, position, maxRange)
                    if
                        result
                        and Logic.isUsableResult(grapple, result)
                        and isPathSafeForHitbox(grapple, candidate.Instance, part, position, maxRange)
                    then
                        local item = {
                            Name = candidate.Name,
                            Result = result,
                            Instance = candidate.Instance,
                            Distance = distance,
                            ScreenScore = screenScore,
                        }

                        if rangeMode == "Random" then
                            table.insert(validResults, item)
                        else
                            local priorityScore = candidate.Name == preferredName and 0 or 1000
                            local score
                            if (driveMode and not emergencyBrakeMode) or panicMode or emergencyBrakeMode then
                                priorityScore = 0
                            elseif rescueMode then
                                priorityScore = rescuePriority[candidate.Name] or 1000
                            elseif rangeMode == "Closest To Cursor" then
                                priorityScore = candidate.Name == preferredName and CFG.CURSOR_INTENT_PREFERRED_BONUS or 0
                                if candidate.Name ~= "GrapplePoint" and screenScore <= CFG.CURSOR_SPECIAL_FOCUS_LIMIT then
                                    priorityScore = priorityScore + CFG.CURSOR_SPECIAL_FOCUS_BONUS
                                end
                            end
                            local distanceScore = rangeMode == "Farthest" and -distance or distance
                            if rangeMode == "Closest To Cursor" then
                                distanceScore = distance * CFG.CURSOR_INTENT_DISTANCE_WEIGHT
                            end
                            local staminaPenalty = driveMode and 0 or (Logic.isInfiniteStamina() and 0 or distance * (1 - staminaRatio) * 0.12)
                            local intentPenalty = getAssistIntentPenalty(rootPart, position, inputDirection, velocityDirection)
                            local routeBonus = getRouteAssistBonus(rootPart, position)
                            local specialBonus = getSpecialAnchorBonus(grapple, candidate.Name, position)
                            local wrongAnchorPenalty = getWrongAnchorPenalty(
                                rootPart,
                                position,
                                inputDirection,
                                velocityDirection,
                                rangeMode == "Closest To Cursor" and screenScore <= CFG.CURSOR_SPECIAL_FOCUS_LIMIT
                            )
                            local lockBonus = getAssistLockBonus(candidate.Instance)
                            if driveMode and not emergencyBrakeMode then
                                score = getAdaptDriveScore(grapple, candidate, position, distance, screenScore)
                                    + specialBonus
                                    + wrongAnchorPenalty * 0.35
                                    + lockBonus
                            elseif panicMode or emergencyBrakeMode then
                                score = getPanicRescueScore(grapple, candidate, position, distance, screenScore)
                                    + lockBonus
                            elseif rangeMode == "Closest To Cursor" and not rescueMode and not emergencyBrakeMode then
                                score = priorityScore
                                    + screenScore * CFG.CURSOR_INTENT_SCREEN_WEIGHT
                                    + distanceScore
                                    + staminaPenalty
                                    + intentPenalty * 0.35
                                    + routeBonus * 0.35
                                    + specialBonus
                                    + wrongAnchorPenalty * 0.4
                                    + lockBonus
                            else
                                score = priorityScore
                                    + screenScore * 100
                                    + distanceScore * 0.01
                                    + staminaPenalty
                                    + intentPenalty
                                    + routeBonus
                                    + specialBonus
                                    + wrongAnchorPenalty
                                    + lockBonus
                            end

                            if score < bestScore then
                                bestScore = score
                                bestResult = result
                                bestTargetInstance = candidate.Instance
                                bestTargetName = candidate.Name
                                bestDistance = distance
                                bestScreenScore = screenScore
                                bestReason = rangeMode
                            end
                        end
                    end
                end
            end
        else
            unregisterCandidate(candidate and candidate.Instance)
        end
    end

    if rangeMode == "Random" then
        local result, instance, reason = chooseRandomCandidate(validResults, preferredName)
        if result then
            rememberAssistTarget(instance, reason, 0)
        end
        if returnDecision then
            return result and {
                Result = result,
                Instance = instance,
                Name = instance and instance.Name or nil,
                Score = 0,
                Reason = reason,
            } or nil
        end
        return result
    end

    if rangeMode == "Closest To Cursor" and bestResult and not rescueMode and not emergencyBrakeMode then
        local viewportPoint = camera:WorldToViewportPoint(bestResult.Position)
        local viewportSize = camera.ViewportSize
        local cursorDistance = (Vector2.new(viewportPoint.X, viewportPoint.Y) - screenAnchor).Magnitude / math.max(viewportSize.X, viewportSize.Y)
        if cursorDistance > CFG.CURSOR_INTENT_CONFIDENCE_LIMIT then
            return nil
        end
    end

    if bestResult then
        rememberAssistTarget(bestTargetInstance, bestReason, bestScore)
    end

    if returnDecision then
        return bestResult and {
            Result = bestResult,
            Instance = bestTargetInstance,
            Name = bestTargetName,
            Distance = bestDistance,
            ScreenScore = bestScreenScore,
            Score = bestScore,
            Reason = bestReason,
        } or nil
    end

    return bestResult
end

local function scanScreenSurface(grapple, options)
    local camera = Workspace.CurrentCamera
    local rootPart = grapple and grapple.RootPart
    if not camera or not rootPart then
        return nil
    end

    local driveMode = typeof(options) == "table" and options.driveMode == true
    local returnDecision = typeof(options) == "table" and options.returnDecision == true
    local viewportSize = camera.ViewportSize
    local maxRange = getAssistRange(grapple, driveMode)
    local bestResult = nil
    local bestScore = math.huge
    local bestReason = nil
    local bestScreenScore = nil

    for _, offset in ipairs(SCREEN_RAY_OFFSETS) do
        local screenPoint = Vector2.new(
            viewportSize.X * (0.5 + offset.X),
            viewportSize.Y * (0.5 + offset.Y)
        )
        local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
        local cameraHit = Workspace:Raycast(ray.Origin, ray.Direction.Unit * 2048, grapple.grappleParams)
        if cameraHit then
            local directOffset = cameraHit.Position - rootPart.Position
            if directOffset.Magnitude > 0 and directOffset.Magnitude <= maxRange then
                local directHit = Workspace:Raycast(rootPart.Position, directOffset, grapple.grappleParams)
                if
                    directHit
                    and Logic.isUsableResult(grapple, directHit)
                    and isPathSafeForHitbox(grapple, directHit.Instance, directHit.Instance, directHit.Position, maxRange)
                then
                    local screenScore = offset.Magnitude
                    local score, reason = getTerrainSurfaceScore(grapple, directHit, screenScore, driveMode)
                    if score < bestScore then
                        bestResult = directHit
                        bestScore = score
                        bestReason = reason
                        bestScreenScore = screenScore
                    end
                end
            end
        end
    end

    if bestResult then
        Logic.LastAssistDebug = {
            Reason = bestReason or "TerrainSurface",
            Score = bestScore,
            ScreenScore = bestScreenScore,
            Target = bestResult.Instance and bestResult.Instance.Name or "Surface",
        }
    end

    if returnDecision then
        return bestResult and {
            Result = bestResult,
            Instance = bestResult.Instance,
            Name = bestResult.Instance and bestResult.Instance.Name or nil,
            Position = bestResult.Position,
            Distance = (bestResult.Position - rootPart.Position).Magnitude,
            ScreenScore = bestScreenScore,
            Score = bestScore,
            Reason = bestReason,
        } or nil
    end

    return bestResult
end

local function getResultTargetName(result)
    local instance = result and result.Instance
    local current = instance
    while current do
        if VALID_TARGETS[current.Name] then
            return current.Name, current
        end
        current = current.Parent
    end

    return nil, instance
end

local function isSameAssistTarget(result, decision)
    if not (result and decision and decision.Instance) then
        return false
    end

    local instance = result.Instance
    if instance == decision.Instance then
        return true
    end
    if instance and instance:IsDescendantOf(decision.Instance) then
        return true
    end
    if decision.Instance and decision.Instance:IsDescendantOf(instance) then
        return true
    end

    return false
end

local function getDirectResultAssistScore(grapple, result)
    local camera = Workspace.CurrentCamera
    local rootPart = grapple and grapple.RootPart
    if not (camera and rootPart and result and typeof(result.Position) == "Vector3") then
        return math.huge, nil, 0, nil
    end

    local controller = Logic.getController()
    local rangeMode = normalizeRangePriority(controller and controller.GrappleAimAssistRangePriority)
    if shouldForceNearest(grapple) then
        rangeMode = "Nearest"
    end

    local maxRange = getAssistRange(grapple, false)
    local distance = (result.Position - rootPart.Position).Magnitude
    if distance <= 0 or distance > maxRange then
        return math.huge, nil, 0, nil
    end

    local screenAnchor = getScreenAnchor(camera, rangeMode)
    local screenScore = getCameraScreenScore(camera, result.Position, screenAnchor)
    if not screenScore then
        return math.huge, nil, 0, nil
    end

    local inputDirection, velocityDirection = getAssistIntentDirections(grapple)
    local targetName = getResultTargetName(result)
    local distanceScore = rangeMode == "Farthest" and -distance or distance
    if rangeMode == "Closest To Cursor" then
        distanceScore = distance * CFG.CURSOR_INTENT_DISTANCE_WEIGHT
    end

    local staminaRatio = getStaminaRatio(grapple)
    local staminaPenalty = Logic.isInfiniteStamina() and 0 or distance * (1 - staminaRatio) * 0.12
    local intentPenalty = getAssistIntentPenalty(rootPart, result.Position, inputDirection, velocityDirection)
    local routeBonus = getRouteAssistBonus(rootPart, result.Position)
    local specialBonus = targetName and getSpecialAnchorBonus(grapple, targetName, result.Position) or 0
    local wrongAnchorPenalty = getWrongAnchorPenalty(rootPart, result.Position, inputDirection, velocityDirection, false)
    local surfacePenalty = targetName and 0 or CFG.SOFT_OVERRIDE_SURFACE_PENALTY

    local score
    if rangeMode == "Closest To Cursor" then
        score = screenScore * CFG.CURSOR_INTENT_SCREEN_WEIGHT
            + distanceScore
            + staminaPenalty
            + intentPenalty * 0.35
            + routeBonus * 0.35
            + specialBonus
            + wrongAnchorPenalty * 0.4
            + surfacePenalty
    else
        score = screenScore * 100
            + distanceScore * 0.01
            + staminaPenalty
            + intentPenalty
            + routeBonus
            + specialBonus
            + wrongAnchorPenalty
            + surfacePenalty
    end

    return score, screenScore, wrongAnchorPenalty, targetName
end

local function getSoftOverrideResult(grapple, originalResult)
    if not (Logic.isEnabled() and Logic.isUsableResult(grapple, originalResult)) then
        return nil
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement and grapple.specialHeld and not movement.grappling and Logic.isInAir(grapple)) then
        return nil
    end

    local decision = scanNamedTargets(grapple, {
        returnDecision = true,
        fullScan = true,
    })
    if not (decision and decision.Result) then
        return nil
    end

    local originalTargetName = getResultTargetName(originalResult)
    local isSame = isSameAssistTarget(originalResult, decision)

    if isSame then
        -- Nếu cùng một mục tiêu (ví dụ đang aim vào JumpPad đó), cho phép snap thẳng vào tâm của nó
        return decision.Result
    elseif originalTargetName then
        -- Nếu đang aim vào một mục tiêu hợp lệ khác, không tự động bẻ lái sang mục tiêu này
        return nil
    end

    local originalScore = getDirectResultAssistScore(grapple, originalResult)
    local decisionScore = tonumber(decision.Score) or math.huge
    local decisionScreenScore = tonumber(decision.ScreenScore) or math.huge
    local strengthScale = getAimAssistStrengthScale()
    local requiredGap = CFG.SOFT_OVERRIDE_MIN_SCORE_GAP / strengthScale
    local scoreGap = originalScore - decisionScore
    if scoreGap < requiredGap then
        return nil
    end

    -- Bắt buộc mục tiêu thay thế phải nằm trong phạm vi giới hạn của con trỏ chuột nới rộng (38% thay vì 18% của SOFT_OVERRIDE_CURSOR_LIMIT)
    -- để người chơi vẫn có thể snap vào mục tiêu khi aim lệch sang địa hình (aim hụt),
    -- nhưng không bị tự động snap sang mục tiêu quá xa ở rìa màn hình.
    local maxCursorLimit = 0.38
    local hasClearCursorIntent = decisionScreenScore <= maxCursorLimit * strengthScale
    if not hasClearCursorIntent then
        return nil
    end

    Logic.LastAssistDebug = {
        Reason = "SoftOverride",
        Score = decisionScore,
        OriginalScore = originalScore,
        Gap = scoreGap,
        Target = decision.Name,
    }

    return decision.Result
end

function Logic.hasAdaptDriveTarget(grapple)
    local driveOptions = { driveMode = true }
    return scanNamedTargets(grapple, driveOptions) ~= nil
end

local function getEmergencyAutoConfidence(grapple, rescueResult)
    local decision = createGrapplerEmergencyDecision(grapple, rescueResult)
    return decision.Score, decision.Reason, decision
end

local function canAutoEmergencyRescue(grapple, rescueResult)
    local _, _, decision = getEmergencyAutoConfidence(grapple, rescueResult)
    Logic.LastAssistDebug = {
        Action = decision.Action,
        Reason = "Emergency" .. tostring(Logic.getEmergencyProtectionMode()),
        Score = decision.Score,
        Threshold = decision.Threshold,
        Detail = decision.Reason,
        Target = decision.Target,
        ClassId = decision.ClassId,
        VoidDanger = decision.VoidDanger,
        Suppression = decision.Suppression,
        SuppressionReason = decision.SuppressionReason,
    }

    return decision.Allowed == true
end

local function tryAutoMomentumRescue(grapple)
    if not (hasClassCapability(grapple, "EmergencyRescue") and Logic.isRescueEnabled() and Logic.isEmergencyProtectionEnabled() and isHighMomentumDanger(grapple)) then
        return false
    end
    if Logic.getEmergencyProtectionMode() == "Manual" then
        return false
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement and grapple.specialHeld and Logic.isInAir(grapple)) then
        return false
    end
    if isEmergencyRescueRecastBlocked(grapple, false) then
        return false
    end
    if time() - Logic.LastAutoRescuePulseAt < CFG.AUTO_RESCUE_COOLDOWN then
        return false
    end

    armAutoRescueWindow()
    local previewResult = scanNamedTargets(grapple)
    if not (previewResult and previewResult.Instance and isRescueTargetName(previewResult.Instance.Name)) then
        return false
    end
    if not canAutoEmergencyRescue(grapple, previewResult) then
        return false
    end

    Logic.LastAutoRescuePulseAt = time()
    if pulseSpecialAction(grapple) then
        markEmergencyRescuePulse()
        return true
    end

    return false
end

local function tryPanicRescue(grapple)
    if not (hasClassCapability(grapple, "EmergencyRescue") and Logic.isEmergencyProtectionEnabled()) then
        return false
    end
    local allowed = canRunAssist("PanicRescue", grapple)
    if not allowed then
        return false
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement and Logic.isInAir(grapple)) then
        return false
    end
    if Logic.isJumpPadCommitGuardActive() then
        return false
    end
    local voidDanger = isVoidRescueDanger(grapple)
    local landing = getSafeLandingGuard and getSafeLandingGuard(grapple) or nil
    if not voidDanger and landing and landing.Safe then
        return false
    end
    if not voidDanger and isRailExitLandingGraceActive(grapple, getVoidKillPlaneY()) then
        return false
    end
    if isEmergencyRescueRecastBlocked(grapple, voidDanger) then
        return false
    end
    local rescueCooldown = voidDanger and CFG.VOID_RESCUE_COOLDOWN or CFG.PANIC_RESCUE_COOLDOWN
    if time() - Logic.LastPanicRescuePulseAt < rescueCooldown then
        return false
    end
    if not Logic.getCachedPanicRescueDanger(grapple) then
        return false
    end
    local emergencyMode = Logic.getEmergencyProtectionMode()
    if emergencyMode == "Manual" and not (isPanicPressureActive() or voidDanger) then
        return false
    end

    Logic.AutoRescueUntil = time() + CFG.PANIC_RESCUE_WINDOW
    if voidDanger then
        markVoidRescueWindow()
    end
    local previewResult
    if voidDanger then
        previewResult = scanKillVoidSharkTailAnchor(grapple, { driveMode = true, returnDecision = true })
            or scanMapVoidAnchor(grapple, { driveMode = true, returnDecision = true })
    end
    previewResult = previewResult or scanNamedTargets(grapple, { driveMode = true })
    if not previewResult and voidDanger then
        previewResult = scanScreenSurface(grapple, { driveMode = true, returnDecision = true })
    end
    if not previewResult then
        return false
    end
    if voidDanger and typeof(previewResult) == "table" then
        Logic.LastAssistDebug = {
            Reason = previewResult.Reason or "VoidAnchor",
            Target = previewResult.Name or (previewResult.Instance and previewResult.Instance.Name) or "Surface",
            Distance = previewResult.Distance,
            Score = previewResult.Score,
            Threat = previewResult.Threat and previewResult.Threat.Reason or nil,
            ThreatScore = previewResult.Threat and previewResult.Threat.Score or nil,
            AnchorReason = previewResult.Breakdown and previewResult.Breakdown.Reason or nil,
            Evaluated = previewResult.Evaluated,
        }
    end

    local instance = previewResult.Instance
    if not voidDanger and not (instance and isRescueTargetName(instance.Name)) then
        return false
    end
    if emergencyMode ~= "Manual" and not canAutoEmergencyRescue(grapple, previewResult) then
        return false
    end

    Logic.LastPanicRescuePulseAt = time()
    if pulseSpecialAction(grapple) then
        claimAssist(voidDanger and "VoidRescue" or "PanicRescue", voidDanger and "VoidDanger" or "PanicRescue", voidDanger and CFG.VOID_RESCUE_WINDOW or CFG.PANIC_RESCUE_WINDOW)
        markEmergencyRescuePulse()
        if voidDanger then
            Logic.LastVoidRescueAt = time()
            markVoidRescueWindow()
        end
        Logic.PanicStabilizeUntil = time() + CFG.PANIC_STABILIZE_WINDOW
        Logic.markGrappleBonkGrace(grapple, CFG.PANIC_STABILIZE_WINDOW)
        return true
    end

    return false
end

local function panicRescueWatchdog()
    local now = time()
    if now - Logic.LastPanicWatchdogAt < CFG.PANIC_WATCHDOG_INTERVAL then
        return
    end
    Logic.LastPanicWatchdogAt = now

    local grapple = Logic.LastKnownGrapple or getTrackedGrapple()
    if not grapple then
        return
    end

    tryPanicRescue(grapple)
end

function Logic.isUsableResult(grapple, result)
    if not result then
        return false
    end

    local instance = result.Instance
    if not instance then
        return false
    end

    if instance.Name == "Bell" and instance.CanTouch == false and not hasSavedBellImmunity(instance) then
        return false
    end

    local humanoid = grapple and grapple.Humanoid
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Running and instance.Name ~= "JumpPad" then
        return false
    end

    return true
end

local function assistedCast(grapple, forceRefresh, originalCast, ...)
    notePanicInput(grapple)
    local result, direction = originalCast(grapple, forceRefresh, ...)
    local canAssist = (hasClassCapability(grapple, "AimAssist") and Logic.isEnabled())
        or (hasClassCapability(grapple, "RescueAssist") and Logic.isRescueEnabled() and isFallingFast(grapple))
    if not canAssist then
        return result, direction
    end

    if Logic.isUsableResult(grapple, result) then
        local overrideResult = getSoftOverrideResult(grapple, result)
        if overrideResult then
            if hasClassCapability(grapple, "BellBypass") and overrideResult.Instance and overrideResult.Instance.Name == "Bell" then
                holdBellBypass(overrideResult.Instance)
            end
            return overrideResult
        end
        return result, direction
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement and grapple.specialHeld and not movement.grappling and Logic.isInAir(grapple)) then
        return result, direction
    end
    if Logic.isJumpPadCommitGuardActive() then
        return result, direction
    end

    local assistedResult
    if Logic.AdaptDriveActive then
        assistedResult = scanNamedTargets(grapple, { driveMode = true })
    else
        local mapResult
        if isVoidRescueWindowActive() or isVoidRescueDanger(grapple) then
            mapResult = scanKillVoidSharkTailAnchor(grapple, { driveMode = true })
                or scanMapVoidAnchor(grapple, { driveMode = true })
        end
        assistedResult = mapResult or scanNamedTargets(grapple) or scanScreenSurface(grapple)
    end
    if assistedResult then
        if hasClassCapability(grapple, "BellBypass") and assistedResult.Instance and assistedResult.Instance.Name == "Bell" then
            holdBellBypass(assistedResult.Instance)
        end
        return assistedResult
    end

    return result, direction
end

local function canUseSharkTail(grapple)
    local movement = grapple and grapple.Movement
    if not (grapple and movement and hasClassCapability(grapple, "SharkTail") and Logic.isSharkTailHelperEnabled()) then
        return false
    end
    if getModeValue("GrappleSharkTailMode") ~= "Automatic" and getModeValue("GrappleSharkTailMode") ~= "Manual" then
        return false
    end

    return grapple.allowSharkTail == true
        and grapple.sharkTailDisable ~= true
        and Logic.isInAir(grapple)
        and hasUpgrade(movement, "NinjaBelt")
        and hasUpgrade(movement, "SharkTail")
end

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

local function getSharkTailIntentDirection(grapple)
    local movement = grapple and grapple.Movement
    local inputDirection = getFlatUnit(movement and movement.PlayerMoveDirection)
    if inputDirection then
        return inputDirection, true
    end

    local camera = Workspace.CurrentCamera
    local cameraDirection = getFlatUnit(camera and camera.CFrame.LookVector)
    if cameraDirection then
        return cameraDirection, false
    end

    return getFlatUnit(grapple and grapple.RootPart and grapple.RootPart.Velocity), false
end

local function isSharkTailProjectedPathSafe(grapple, direction)
    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart and direction) then
        return false
    end

    local velocity = rootPart.Velocity
    local projectedSpeed = math.max(Logic.getHorizontalVelocity(rootPart).Magnitude, 70)
    local projected = direction * projectedSpeed * CFG.SHARK_TAIL_PROJECT_TIME
    if projected.Magnitude <= 1 then
        return true
    end

    local hitbox = movement.Hitbox
    if not (hitbox and hitbox.Parent and hitbox:IsA("BasePart")) then
        hitbox = getFallbackHitbox(rootPart)
    end

    local params = movement.moveCastParams or grapple.grappleParams
    local success, result = pcall(function()
        return Workspace:Shapecast(hitbox, projected, params)
    end)
    if success then
        if not result then
            return true
        end
        return result.Normal ~= nil and result.Normal.Y >= 0.72 and velocity.Y <= 0
    end

    local rayResult = Workspace:Raycast(rootPart.Position, projected, params)
    if not rayResult then
        return true
    end

    return rayResult.Normal ~= nil and rayResult.Normal.Y >= 0.72 and velocity.Y <= 0
end

local function isSharkTailLaunchSpaceSafe(grapple)
    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart) then
        return false
    end

    local hitbox = movement.Hitbox
    if not (hitbox and hitbox.Parent and hitbox:IsA("BasePart")) then
        hitbox = getFallbackHitbox(rootPart)
    end

    local params = movement.moveCastParams or grapple.grappleParams
    local upward = Vector3.new(0, CFG.SHARK_TAIL_CEILING_CHECK_HEIGHT, 0)
    local success, result = pcall(function()
        return Workspace:Shapecast(hitbox, upward, params)
    end)
    if success then
        return result == nil
    end

    return Workspace:Raycast(rootPart.Position, upward, params) == nil
end

local function getSharkTailOverpopPenalty(grapple, emergency, hasInput)
    if emergency then
        return 0
    end

    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    if not velocity then
        return 0
    end

    local penalty = 0
    if velocity.Y > CFG.SHARK_TAIL_OVERPOP_UP_SPEED then
        penalty = penalty + CFG.SHARK_TAIL_OVERPOP_PENALTY
        if not hasInput then
            penalty = penalty + 10
        end
    end

    if not isSharkTailLaunchSpaceSafe(grapple) then
        penalty = penalty + CFG.SHARK_TAIL_LOW_CEILING_PENALTY
    end

    if time() - (Logic.LastSmartReelStartAt or 0) < CFG.SHARK_TAIL_CHAIN_GRACE then
        penalty = penalty + 18
    end

    return penalty
end

local function getSharkTailScore(grapple)
    if not canUseSharkTail(grapple) then
        return 0, false
    end

    if Logic.AdaptRecastPending or isAwaitingAdaptAttach(grapple) then
        return 0, false
    end

    local rootPart = grapple.RootPart
    local movement = grapple.Movement
    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local speed = horizontal.Magnitude
    if speed < CFG.SHARK_TAIL_MIN_SPEED then
        return 0, false
    end

    local direction, hasInput = getSharkTailIntentDirection(grapple)
    if not direction then
        return 0, false
    end

    if not isSharkTailProjectedPathSafe(grapple, direction) then
        return 0, false
    end

    local emergency = isEmergencyAssistDanger(grapple)
    local velocityDirection = getFlatUnit(horizontal)
    local velocityDot = velocityDirection and direction:Dot(velocityDirection) or 0

    local intentScore = 45
    if hasInput then
        intentScore = math.clamp((velocityDot + 1) * 50, 0, 100)
    else
        local cameraDirection = getFlatUnit(Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector)
        intentScore = cameraDirection and math.clamp((direction:Dot(cameraDirection) + 1) * 50, 0, 100) or 45
    end

    local flowScore = math.clamp((speed - 35) / 95 * 100, 0, 100)
    if velocityDot < -0.1 and not emergency then
        flowScore = flowScore * 0.45
    elseif velocityDot > 0.35 then
        flowScore = math.min(flowScore + 18, 100)
    end

    local riskScore = 100
    if speed > 230 then
        riskScore = 20
    elseif speed > 180 then
        riskScore = 45
    elseif speed > 145 then
        riskScore = 70
    end
    if movement == Logic.LastGrappleMovement and time() < Logic.SuppressBonkUntil and speed > 115 then
        riskScore = math.min(riskScore, 55)
    end

    local emergencyScore = emergency and 100 or 0
    local launchPenalty = getSharkTailOverpopPenalty(grapple, emergency, hasInput)
    local vectorChangeScore = 0
    if hasInput and velocityDirection then
        if velocityDot <= CFG.SHARK_TAIL_TURN_DOT then
            vectorChangeScore = vectorChangeScore
                + math.clamp((CFG.SHARK_TAIL_TURN_DOT - velocityDot) / 1.2, 0, 1) * CFG.SHARK_TAIL_TURN_BONUS
        elseif velocityDot >= CFG.SHARK_TAIL_CRUISE_DOT and not emergency then
            vectorChangeScore = vectorChangeScore - CFG.SHARK_TAIL_CRUISE_PENALTY
        end
    elseif not emergency then
        vectorChangeScore = vectorChangeScore - 12
    end

    local score = 35
        + intentScore * 0.22
        + flowScore * 0.18
        + riskScore * 0.1
        + emergencyScore * 0.12
        + vectorChangeScore
        - launchPenalty
    return math.clamp(score, 0, 100), emergency
end

local function shouldUseSmartSharkTail(grapple, manual)
    local config = getSharkTailStyleConfig()
    local score, emergency = getSharkTailScore(grapple)
    if config.EmergencyOnly and not emergency and not manual then
        return false, score, emergency
    end

    local threshold = manual and config.ManualThreshold or config.Threshold
    return score >= threshold, score, emergency
end

local function tryUseSharkTail(grapple)
    if not canUseSharkTail(grapple) then
        return false
    end
    local allowed = canRunAssist("SharkTail", grapple)
    if not allowed then
        return false
    end

    local horizontal = Logic.getHorizontalVelocity(grapple.RootPart)
    if horizontal.Magnitude < 35 then
        return false
    end

    if typeof(grapple.SharkTail) == "function" then
        local success = pcall(function()
            grapple:SharkTail()
        end)
        if success then
            Logic.LastSharkTailAssistAt = time()
            claimAssist("SharkTail", "SharkTail", getSharkTailStyleConfig().Cooldown)
            Logic.SharkTailPlanToken = Logic.SharkTailPlanToken + 1
            Logic.SharkTailPlannedAt = 0
            Logic.SharkTailStabilizeUntil = time() + CFG.SHARK_TAIL_STABILIZE_WINDOW
            Logic.markGrappleBonkGrace(grapple, CFG.MOMENTUM_GUARD_WINDOW)
        end
        return success
    end

    return false
end

local function tryVoidSharkTailSaver(grapple)
    if not canUseKillVoidSharkTailSaver(grapple, true) then
        return false
    end
    if not isVoidRescueDanger(grapple) then
        return false
    end

    Logic.LastAssistDebug = {
        Reason = "VoidSharkTailSaver",
        Target = "KillVoid",
    }
    return tryUseSharkTail(grapple)
end

local function planSmartSharkTail(grapple)
    local allowed = canRunAssist("SharkTail", grapple)
    if not allowed then
        return false
    end

    if tryVoidSharkTailSaver(grapple) then
        return true
    end

    local config = getSharkTailStyleConfig()
    local now = time()
    if Logic.SharkTailPlannedAt > now then
        return true
    end

    if now - Logic.LastSharkTailEvalAt < Logic.NextSharkTailEvalDelay then
        return false
    end

    Logic.LastSharkTailEvalAt = now
    Logic.NextSharkTailEvalDelay = Logic.Random:NextNumber(config.EvalMin, config.EvalMax)

    if now - Logic.LastSharkTailAssistAt < config.Cooldown then
        return false
    end

    local shouldUse, score, emergency = shouldUseSmartSharkTail(grapple, false)
    if not shouldUse then
        return false
    end

    if not emergency and score < config.Threshold + 6 and Logic.Random:NextNumber() < 0.22 then
        return false
    end

    local delay = Logic.Random:NextNumber(config.DelayMin, config.DelayMax)
    local token = Logic.SharkTailPlanToken + 1
    Logic.SharkTailPlanToken = token
    Logic.SharkTailPlannedAt = now + delay

    task.delay(delay, function()
        if Logic.SharkTailPlanToken ~= token then
            return
        end

        local activeGrapple = grapple
        if not (activeGrapple and isActiveClassSpecial(activeGrapple) and hasClassCapability(activeGrapple, "SharkTail")) then
            activeGrapple = getTrackedGrapple()
        end
        if not activeGrapple then
            return
        end

        local latestConfig = getSharkTailStyleConfig()
        if time() - Logic.LastSharkTailAssistAt < latestConfig.Cooldown then
            return
        end
        if shouldUseSmartSharkTail(activeGrapple, false) then
            tryUseSharkTail(activeGrapple)
        end
    end)

    return true
end

local function isLiveBasePart(value)
    local success, result = pcall(function()
        return value and value.Parent and value:IsA("BasePart")
    end)
    return success and result == true
end

local function getSmartReelTarget(grapple)
    local movement = grapple and grapple.Movement
    local targetPosition = movement and movement.grapplePoint
    local targetPart = movement and movement.grapplePart

    if typeof(targetPosition) ~= "Vector3" then
        targetPosition = grapple and grapple.grapplePoint
    end
    if not isLiveBasePart(targetPart) then
        targetPart = grapple and grapple.grapplePart
    end

    if typeof(targetPosition) ~= "Vector3" and isLiveBasePart(targetPart) then
        targetPosition = targetPart.Position
    end
    if not isLiveBasePart(targetPart) then
        targetPart = nil
    end

    if typeof(targetPosition) ~= "Vector3" then
        return nil, nil
    end

    return targetPart, targetPosition
end

local function getSmartReelBaseState(grapple)
    local movement = grapple and grapple.Movement
    if not (grapple and movement and hasClassCapability(grapple, "SmartReel") and Logic.isSmartReelEnabled()) then
        return nil
    end
    if not Logic.isInAir(grapple) then
        return nil
    end
    if not hasUpgrade(movement, "NinjaBelt") then
        return nil
    end
    if not movement.grappling or grapple.jumpPadReel or grapple.reelCooldown or grapple.sharkTailDisable then
        return nil
    end
    if tonumber(grapple.Time) == 0 then
        return nil
    end

    local targetPart, targetPosition = getSmartReelTarget(grapple)
    if not targetPosition then
        return nil
    end

    local rootPart = grapple.RootPart
    if not rootPart then
        return nil
    end

    local offset = targetPosition - rootPart.Position
    local distance = offset.Magnitude
    if distance <= CFG.SMART_REEL_NEAR_CUTOFF or distance > CFG.DEFAULT_MAX_RANGE then
        return nil
    end

    return {
        Movement = movement,
        RootPart = rootPart,
        TargetPart = targetPart,
        TargetPosition = targetPosition,
        Offset = offset,
        Distance = distance,
    }
end

local function isSmartReelPathSafe(grapple, state)
    if not state.TargetPart then
        return true
    end

    return isPathSafeForHitbox(grapple, state.TargetPart, state.TargetPart, state.TargetPosition, CFG.DEFAULT_MAX_RANGE) == true
end

local function getSmartReelScore(grapple, manual)
    local state = getSmartReelBaseState(grapple)
    if not state then
        return 0, "Unavailable", nil
    end

    local rootPart = state.RootPart
    local velocity = rootPart.Velocity
    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local horizontalSpeed = horizontal.Magnitude
    local toTarget = state.Offset.Unit
    local flatToTarget = getAssistFlatUnit(state.Offset)
    local velocityDirection = getAssistFlatUnit(velocity)
    local inputDirection = getAssistFlatUnit(state.Movement.PlayerMoveDirection)
    local velocityDot = velocityDirection and velocityDirection:Dot(toTarget) or 0
    local flatVelocityDot = (flatToTarget and velocityDirection) and flatToTarget:Dot(velocityDirection) or velocityDot
    local inputDot = (flatToTarget and inputDirection) and flatToTarget:Dot(inputDirection) or 0
    local panic = Logic.isEmergencyProtectionEnabled() and Logic.getCachedPanicRescueDanger(grapple)
    local closingSpeed = velocity:Dot(toTarget)

    local attachAge = time() - (tonumber(grapple.reelStart) or 0)
    if not manual and not panic and attachAge < CFG.SMART_REEL_MIN_ATTACH_TIME then
        return 0, "CommitDelay", state
    end
    if not manual and not panic and time() - (Logic.LastSharkTailAssistAt or 0) < CFG.SHARK_TAIL_CHAIN_GRACE then
        return 0, "SharkTailChainGuard", state
    end

    local minDot = manual and CFG.SMART_REEL_MANUAL_MIN_DOT or CFG.SMART_REEL_AUTO_MIN_DOT
    if not panic and flatVelocityDot < minDot and inputDot < 0.35 then
        return 0, "AngleGate", state
    end

    if not isSmartReelPathSafe(grapple, state) then
        return 0, "UnsafePath", state
    end

    local projectedDistance = (state.TargetPosition - (rootPart.Position + velocity * CFG.SMART_REEL_OVERSHOOT_LOOKAHEAD)).Magnitude
    local routeProjectedDistance = (state.TargetPosition - (rootPart.Position + velocity * CFG.SMART_REEL_ROUTE_LOOKAHEAD)).Magnitude
    local routeGain = state.Distance - routeProjectedDistance
    local naturalRoute = routeGain > state.Distance * CFG.SMART_REEL_ROUTE_GOOD_GAIN_RATIO
        and flatVelocityDot > 0.35
        and inputDot > 0.15
    local catchupNeeded = closingSpeed < CFG.SMART_REEL_CATCHUP_CLOSING_SPEED
        and state.Distance >= CFG.SMART_REEL_GOOD_DISTANCE
    local routeWorsening = routeProjectedDistance > state.Distance + CFG.SMART_REEL_WORSENING_MARGIN
    local overshootRisk = projectedDistance > state.Distance
        and state.Distance <= CFG.SMART_REEL_EXIT_DISTANCE + horizontalSpeed * 0.045
    local brakeNeeded = horizontalSpeed >= CFG.SMART_REEL_HIGH_SPEED
        and velocityDot > 0.2
        and state.Distance > CFG.SMART_REEL_EXIT_DISTANCE
        and (overshootRisk or routeWorsening)
    local targetHeight = state.TargetPosition.Y - rootPart.Position.Y
    local gravityProfile = Logic.getGravityAssistProfile(grapple)
    local landingPullNeeded = targetHeight >= gravityProfile.LandingMinBelow
        and velocity.Y <= -gravityProfile.LandingFallSpeed
        and state.Distance <= gravityProfile.LandingMaxDistance
        and state.Distance > CFG.SMART_REEL_EXIT_DISTANCE

    state.ClosingSpeed = closingSpeed
    state.RouteGain = routeGain
    state.ProjectedDistance = projectedDistance
    state.RouteProjectedDistance = routeProjectedDistance
    state.TargetHeight = targetHeight
    state.LandingPullNeeded = landingPullNeeded

    if not manual and not panic then
        if naturalRoute and not overshootRisk and not routeWorsening and not landingPullNeeded then
            return 0, "NaturalRouteGuard", state
        end
        if inputDirection and inputDot < -0.15 then
            return 0, "InputBrakeGuard", state
        end
        if not (catchupNeeded or brakeNeeded or routeWorsening or landingPullNeeded) then
            return 0, "NoPullNeed", state
        end
        if targetHeight > CFG.SMART_REEL_LOW_ARC_HEIGHT and velocity.Y > CFG.SMART_REEL_LOW_ARC_UP_SPEED and not landingPullNeeded then
            return 0, "LowArcGuard", state
        end
        if horizontalSpeed >= CFG.SMART_REEL_EXTREME_SPEED and not brakeNeeded then
            return 0, "ExtremeSpeedGuard", state
        end
    end

    local score = 28
    local reason = "SoftReel"

    if state.Distance >= CFG.SMART_REEL_GOOD_DISTANCE then
        score = score + math.clamp((state.Distance - CFG.SMART_REEL_GOOD_DISTANCE) / (CFG.SMART_REEL_FAR_DISTANCE - CFG.SMART_REEL_GOOD_DISTANCE), 0, 1) * 18
    end

    if velocityDot > 0.35 then
        score = score + 16
    elseif velocityDot < -0.15 then
        score = score - 18
    end

    if inputDirection then
        score = score + math.clamp((inputDot + 1) * 0.5, 0, 1) * 12
        if not manual and not panic then
            if inputDot > 0.45 and flatVelocityDot > 0.25 and not routeWorsening then
                score = score - CFG.SMART_REEL_PLAYER_CONTROL_PENALTY
                reason = "PlayerControlGuard"
            end
        end
    end

    if routeGain > 0 and state.Distance > CFG.SMART_REEL_EXIT_DISTANCE then
        score = score + math.clamp(routeGain / math.max(state.Distance, 1), 0, 1) * CFG.SMART_REEL_GOOD_ROUTE_BONUS
    end

    if catchupNeeded then
        score = score + 22
        reason = "CatchUpPull"
    end

    if routeWorsening then
        score = score + 24
        reason = "RouteRecovery"
    end

    if overshootRisk then
        score = score + 30
        reason = "OvershootBrake"
    elseif brakeNeeded then
        score = score + 22
        reason = "BrakeReel"
    end

    if landingPullNeeded then
        score = score + 30 + (gravityProfile.LandingScoreBonus or 0)
        reason = gravityProfile.Active and "LowGravityLandingPull" or "LandingPull"
    end

    if manual and not panic and targetHeight > CFG.SMART_REEL_LOW_ARC_HEIGHT and velocity.Y > CFG.SMART_REEL_LOW_ARC_UP_SPEED then
        score = score - 34
        reason = "LowArcGuard"
    end

    if manual and horizontalSpeed >= CFG.SMART_REEL_EXTREME_SPEED and not panic then
        score = score - 16
        reason = "ExtremeSpeedGuard"
    end

    if panic then
        score = score + 38
        reason = "PanicPull"
    end

    if state.Distance <= CFG.SMART_REEL_EXIT_DISTANCE and not panic then
        score = score - 32
        reason = "ExitAssist"
    end

    if manual then
        score = score + 10
        if reason == "SoftReel" then
            reason = "ManualPull"
        end
    end

    return math.clamp(score, 0, 100), reason, state
end

local function canStartSmartReel(grapple, manual)
    local now = time()
    if not manual and Logic.isJumpPadCommitGuardActive() then
        return false
    end
    if not manual and now - (Logic.LastSmartReelStartAt or 0) < CFG.SMART_REEL_START_COOLDOWN then
        return false
    end
    if not manual and now - Logic.LastSmartReelEvalAt < CFG.SMART_REEL_EVAL_INTERVAL then
        return false
    end
    if not manual then
        Logic.LastSmartReelEvalAt = now
    end

    local score, reason, state = getSmartReelScore(grapple, manual)
    local threshold = manual and CFG.SMART_REEL_MANUAL_THRESHOLD or CFG.SMART_REEL_AUTO_THRESHOLD
    Logic.LastSmartReelDebug = {
        Score = score,
        Reason = reason,
        Manual = manual == true,
        Distance = state and state.Distance or nil,
        ClosingSpeed = state and state.ClosingSpeed or nil,
        RouteGain = state and state.RouteGain or nil,
        TargetHeight = state and state.TargetHeight or nil,
    }
    Logic.LastSmartReelDecision = {
        Score = score,
        Reason = reason,
        State = state,
        Manual = manual == true,
    }

    return score >= threshold
end

local function startSmartReel(grapple, manual)
    if not manual then
        local allowed = canRunAssist("SmartReel", grapple)
        if not allowed then
            return false
        end
    end

    if not canStartSmartReel(grapple, manual == true) then
        return false
    end

    grapple.jumpPadReel = true
    claimAssist("SmartReel", Logic.LastSmartReelDecision and Logic.LastSmartReelDecision.Reason or "SmartReel", CFG.SMART_REEL_START_COOLDOWN)
    grapple.reelStart = time()
    grapple.grappleReel = true
    Logic.LastSmartReelStartAt = time()
    Logic.markGrappleBonkGrace(grapple, CFG.MOMENTUM_GUARD_WINDOW)

    local decision = Logic.LastSmartReelDecision
    local state = decision and decision.State
    if decision and (decision.Reason == "LandingPull" or decision.Reason == "LowGravityLandingPull") and state and state.TargetPosition then
        Logic.SmartReelLandingAssistUntil = time() + CFG.SMART_REEL_LANDING_ASSIST_DURATION
        Logic.SmartReelLandingTargetPosition = state.TargetPosition
        Logic.SmartReelLandingPlaneY = state.TargetPosition.Y
        Logic.setMovementIntent(MOVEMENT_INTENT.LandingAssist, CFG.SMART_REEL_LANDING_ASSIST_DURATION, decision.Reason)
    else
        Logic.clearLandingIntent()
    end

    if grapple.SFX and grapple.SFX.PlaySound then
        pcall(function()
            grapple.SFX:PlaySound("GrapplerReel")
        end)
    end

    return true
end

local function applyMomentumGuard(grapple)
    if not (hasClassCapability(grapple, "MomentumGuard") and Logic.isMomentumGuardEnabled()) then
        return
    end
    local allowed = canRunAssist("MomentumGuard", grapple)
    if not allowed then
        return
    end

    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart) then
        return
    end
    if movement ~= Logic.LastGrappleMovement or time() > Logic.SuppressBonkUntil then
        return
    end

    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local speed = horizontal.Magnitude
    if speed <= CFG.MOMENTUM_GUARD_SPEED then
        return
    end

    local targetSpeed = math.max(CFG.MOMENTUM_GUARD_CLAMP, speed - (speed - CFG.MOMENTUM_GUARD_CLAMP) * 0.35)
    local clampedHorizontal = horizontal.Unit * targetSpeed
    if VelocityAssist and VelocityAssist.blendHorizontal then
        VelocityAssist.blendHorizontal(rootPart, clampedHorizontal, 1, 28, "MomentumGuard")
    else
        rootPart.Velocity = Vector3.new(clampedHorizontal.X, rootPart.Velocity.Y, clampedHorizontal.Z)
    end
    claimAssist("MomentumGuard", "MomentumGuard", 0.08)
end

local function applySafeLandingGuard(grapple)
    if not (Logic.isSuiteEnabled() and hasClassCapability(grapple, "VoidRescue")) then
        return false
    end
    local landing = getSafeLandingGuard(grapple)
    if not (landing and landing.Safe) then
        return false
    end
    local allowed = canRunAssist("MomentumGuard", grapple)
    if not allowed then
        return false
    end

    if SafeLandingGuard and SafeLandingGuard.applyDamping then
        local applied = SafeLandingGuard.applyDamping({
            now = time,
            VelocityAssist = VelocityAssist,
            getPhysicsProfile = getPhysicsProfile,
            getVoidKillPlaneY = getVoidKillPlaneY,
            getLandingThreat = getLandingThreat,
            raycastFloor = function(position, depth)
                local params = getEmergencyFloorRaycastParams(grapple)
                local height = CFG.PANIC_RESCUE_GROUND_CHECK_HEIGHT
                return Workspace:Raycast(position + Vector3.new(0, height, 0), Vector3.new(0, -((depth or CFG.VOID_RESCUE_SAFE_LANDING_DEPTH) + height), 0), params)
            end,
        }, grapple, landing)
        if applied then
            claimAssist("MomentumGuard", "SafeLanding", 0.08)
        end
        return applied == true
    end

    return false
end

local function applyPanicStabilize(grapple)
    if not Logic.isEmergencyProtectionEnabled() or time() > (Logic.PanicStabilizeUntil or 0) then
        return
    end
    local allowed = canRunAssist("PanicStabilize", grapple)
    if not allowed then
        return
    end

    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return
    end

    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local speed = horizontal.Magnitude
    if speed <= CFG.PANIC_STABILIZE_SPEED or speed <= 0 then
        return
    end

    local targetSpeed = math.max(CFG.PANIC_STABILIZE_CLAMP, speed - (speed - CFG.PANIC_STABILIZE_CLAMP) * 0.45)
    local clampedHorizontal = horizontal.Unit * targetSpeed
    if VelocityAssist and VelocityAssist.blendHorizontal then
        VelocityAssist.blendHorizontal(rootPart, clampedHorizontal, 1, 36, "PanicStabilize")
    else
        rootPart.Velocity = Vector3.new(clampedHorizontal.X, rootPart.Velocity.Y, clampedHorizontal.Z)
    end
    claimAssist("PanicStabilize", "PanicStabilize", 0.16)
end

local function applySharkTailStabilize(grapple)
    if time() > (Logic.SharkTailStabilizeUntil or 0) then
        return
    end
    local allowed = canRunAssist("SharkTail", grapple)
    if not allowed then
        return
    end

    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return
    end

    local velocity = rootPart.Velocity
    local horizontal = Logic.getHorizontalVelocity(rootPart)
    local speed = horizontal.Magnitude
    local nextHorizontal = horizontal
    if speed > CFG.SHARK_TAIL_STABILIZE_HORIZONTAL_SPEED then
        local targetSpeed = math.max(
            CFG.SHARK_TAIL_STABILIZE_HORIZONTAL_CLAMP,
            speed - (speed - CFG.SHARK_TAIL_STABILIZE_HORIZONTAL_CLAMP) * 0.4
        )
        nextHorizontal = horizontal.Unit * targetSpeed
    end

    local nextY = velocity.Y
    if nextY > CFG.SHARK_TAIL_STABILIZE_UP_SPEED then
        nextY = math.max(CFG.SHARK_TAIL_STABILIZE_UP_CLAMP, nextY - (nextY - CFG.SHARK_TAIL_STABILIZE_UP_CLAMP) * 0.5)
    end

    if nextHorizontal ~= horizontal or nextY ~= velocity.Y then
        if VelocityAssist and VelocityAssist.blendHorizontal then
            VelocityAssist.blendHorizontal(rootPart, nextHorizontal, 1, 34, "SharkTailStabilize")
            VelocityAssist.setVerticalSoft(rootPart, nextY, 1, 22, "SharkTailStabilizeY")
        else
            rootPart.Velocity = Vector3.new(nextHorizontal.X, nextY, nextHorizontal.Z)
        end
        claimAssist("SharkTail", "SharkTailStabilize", 0.08)
    end
end

local function applyAirControlMultiplier(grapple, dt)
    local controlLevel = Logic.getAirControlMultiplier()
    if controlLevel <= 0 then
        return
    end
    local allowed = canRunAssist("AirControl", grapple)
    if not allowed then
        return
    end

    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart and movement.grappling and not grapple.jumpPadReel) then
        return
    end

    local playerMoveDirection = movement.PlayerMoveDirection
    if typeof(playerMoveDirection) ~= "Vector3" or playerMoveDirection.Magnitude <= 0.01 then
        return
    end

    local dtClamped = math.clamp(tonumber(dt) or 0, 0, 1 / 20)
    if dtClamped <= 0 then
        return
    end

    local levelAlpha = math.clamp(controlLevel / 10, 0, 1)
    local velocity = rootPart.Velocity
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local profile = getPhysicsProfile(grapple)
    local graceWingsMultiplier = hasUpgrade(movement, "GraceWings") and 1.5 or 1
    local profileAirScale = tonumber(profile and profile.AirControlScale) or 1
    local movementSpeedMultiplier = tonumber(movement.movementSpeedMulti) or 1

    local inputUnit = playerMoveDirection.Unit
    local alongInputSpeed = horizontalVelocity:Dot(inputUnit)
    local lateralVelocity = horizontalVelocity - inputUnit * alongInputSpeed
    local assistAcceleration = (28 + controlLevel * 22) * movementSpeedMultiplier * graceWingsMultiplier * profileAirScale
    local authority = levelAlpha ^ 1.35
    local maxControlSpeed = 62 + controlLevel * 13
    local desiredAlongSpeed = math.clamp(
        alongInputSpeed + assistAcceleration * dtClamped,
        -maxControlSpeed * 0.35,
        maxControlSpeed
    )
    local alongDelta = math.clamp(desiredAlongSpeed - alongInputSpeed, -assistAcceleration * dtClamped, assistAcceleration * dtClamped)
    local nextHorizontal = horizontalVelocity + inputUnit * alongDelta

    local lateralBrakeAlpha = math.clamp((0.025 + authority * 0.14) * dtClamped * 60, 0, 0.28)
    local lateralBrake = lateralVelocity * lateralBrakeAlpha
    local maxBrakeDelta = (12 + controlLevel * 7) * dtClamped
    if lateralBrake.Magnitude > maxBrakeDelta then
        lateralBrake = lateralBrake.Unit * maxBrakeDelta
    end
    nextHorizontal -= lateralBrake

    local maxHorizontalSpeed = 128 + controlLevel * 15
    if nextHorizontal.Magnitude > maxHorizontalSpeed then
        nextHorizontal = nextHorizontal.Unit * maxHorizontalSpeed
    end

    local gravityCancel = (math.clamp((controlLevel - 3) / 7, 0, 1) ^ 1.35) * 0.82
    if profile and profile.LowGravity then
        gravityCancel *= 0.65
    end
    local nextY = velocity.Y
    if gravityCancel > 0 then
        nextY += Workspace.Gravity * gravityCancel * dtClamped
    end

    local desiredVelocity = Vector3.new(nextHorizontal.X, nextY, nextHorizontal.Z)
    if VelocityAssist and VelocityAssist.applyDelta then
        VelocityAssist.applyDelta(rootPart, desiredVelocity - rootPart.Velocity, 26 + controlLevel * 4, "AirControl")
    else
        rootPart.Velocity = desiredVelocity
    end
    claimAssist("AirControl", "AirControl", 0.04)
end

local function applySmartReelLandingAssist(grapple)
    if time() > (Logic.SmartReelLandingAssistUntil or 0) then
        return false
    end
    local allowed = canRunAssist("ReelPull", grapple)
    if not allowed then
        return false
    end

    local rootPart = grapple and grapple.RootPart
    local targetPosition = Logic.SmartReelLandingTargetPosition
    local planeY = Logic.SmartReelLandingPlaneY
    if not (rootPart and typeof(targetPosition) == "Vector3" and type(planeY) == "number") then
        return false
    end

    local heightToPlane = planeY - rootPart.Position.Y
    if heightToPlane <= 1 then
        Logic.clearLandingIntent()
        return false
    end

    local velocity = rootPart.Velocity
    local horizontalOffset = Vector3.new(
        targetPosition.X - rootPart.Position.X,
        0,
        targetPosition.Z - rootPart.Position.Z
    )
    local nextHorizontal = Logic.getHorizontalVelocity(rootPart)
    if horizontalOffset.Magnitude > 1 then
        local desiredHorizontalSpeed = math.clamp(
            horizontalOffset.Magnitude / 0.65,
            18,
            CFG.SMART_REEL_LANDING_HORIZONTAL_SPEED
        )
        local desiredHorizontal = horizontalOffset.Unit * desiredHorizontalSpeed
        nextHorizontal = nextHorizontal:Lerp(desiredHorizontal, CFG.SMART_REEL_LANDING_BLEND)
    end

    local fallSpeed = math.max(-velocity.Y, 0)
    local desiredY = math.clamp(
        heightToPlane * 1.85 + fallSpeed * 0.3,
        CFG.SMART_REEL_LANDING_UP_SPEED_MIN,
        CFG.SMART_REEL_LANDING_UP_SPEED_MAX
    )
    if heightToPlane < 6 then
        desiredY = math.min(desiredY, 42)
    end

    local nextY = velocity.Y
    if nextY < desiredY then
        nextY = nextY + (desiredY - nextY) * CFG.SMART_REEL_LANDING_BLEND
    elseif nextY > CFG.SMART_REEL_LANDING_UP_SPEED_MAX then
        nextY = CFG.SMART_REEL_LANDING_UP_SPEED_MAX
    end

    local desiredVelocity = Vector3.new(nextHorizontal.X, nextY, nextHorizontal.Z)
    if VelocityAssist and VelocityAssist.applyDelta then
        VelocityAssist.applyDelta(rootPart, desiredVelocity - rootPart.Velocity, 44, "LandingAssist")
    else
        rootPart.Velocity = desiredVelocity
    end
    claimAssist("ReelPull", "LandingAssist", 0.12)
    Logic.LastSmartReelDebug = Logic.LastSmartReelDebug or {}
    Logic.LastSmartReelDebug.LandingAssist = true
    Logic.LastSmartReelDebug.LandingHeight = heightToPlane
    return true
end

local function applyReelPullMultiplier(grapple)

    local rootPart = grapple and grapple.RootPart
    if not (grapple and rootPart and grapple.jumpPadReel) then
        return
    end
    local allowed = canRunAssist("ReelPull", grapple)
    if not allowed then
        return
    end

    if applySmartReelLandingAssist(grapple) then
        return
    end

    local multiplier = Logic.getReelPullMultiplier()
    if multiplier <= 1 then
        return
    end
    local profile = getPhysicsProfile(grapple)
    multiplier = 1 + (multiplier - 1) * (tonumber(profile and profile.PullScale) or 1)

    local desiredVelocity = rootPart.Velocity * multiplier
    if VelocityAssist and VelocityAssist.applyDelta then
        VelocityAssist.applyDelta(rootPart, desiredVelocity - rootPart.Velocity, 38, "ReelPull")
    else
        rootPart.Velocity = desiredVelocity
    end
    claimAssist("ReelPull", "ReelPull", 0.12)
end

local function applySharkTailPullMultiplier(grapple, previousVelocity)

    local multiplier = Logic.getSharkTailPullMultiplier()
    if multiplier <= 1 then
        return
    end
    local profile = getPhysicsProfile(grapple)
    multiplier = 1 + (multiplier - 1) * (tonumber(profile and profile.PullScale) or 1)
    local allowed = canRunAssist("SharkTail", grapple)
    if not allowed then
        return
    end

    local rootPart = grapple and grapple.RootPart
    if not (grapple and rootPart) then
        return
    end

    local beforeVelocity = previousVelocity
    if typeof(beforeVelocity) ~= "Vector3" then
        beforeVelocity = Vector3.new(0, 0, 0)
    end

    local deltaVelocity = rootPart.Velocity - beforeVelocity
    if deltaVelocity.Magnitude <= 0.01 then
        return
    end

    local desiredVelocity = beforeVelocity + deltaVelocity * multiplier
    if VelocityAssist and VelocityAssist.applyDelta then
        VelocityAssist.applyDelta(rootPart, desiredVelocity - rootPart.Velocity, 42, "SharkTailPull")
    else
        rootPart.Velocity = desiredVelocity
    end
    claimAssist("SharkTail", "SharkTailPull", 0.12)
end

local function shouldSuppressGrappleBonk(movement)
    if not Logic.isAntiBonkEnabled() then
        return false
    end

    local grapple = Logic.CurrentGrappleStep
    if grapple and grapple.Movement == movement then
        if not hasClassCapability(grapple, "MomentumGuard") then
            return false
        end
        return movement.grappling == true or grapple.jumpPadReel == true
    end

    if movement == Logic.LastGrappleMovement and time() < Logic.SuppressBonkUntil then
        local rootPart = movement.RootPart
        local speed = rootPart and rootPart.Velocity and rootPart.Velocity.Magnitude or 0
        return speed > 70
    end

    return false
end

local function getNoCollisionMoveCastParams()
    if Logic.NoCollisionMoveCastParams then
        return Logic.NoCollisionMoveCastParams
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Workspace }
    params.RespectCanCollide = true
    Logic.NoCollisionMoveCastParams = params

    return params
end

local function shouldSuppressGrappleCollisionCheck(grapple)
    if not (hasClassCapability(grapple, "MomentumGuard") and Logic.isAntiBonkEnabled()) then
        return false
    end

    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart) then
        return false
    end

    if movement.grappling == true or grapple.jumpPadReel == true then
        return true
    end

    local lastRelease = tonumber(grapple.lastGrappleRelease)
    return lastRelease ~= nil and time() - lastRelease < 1.5 and rootPart.Velocity.Magnitude > 70
end

local function beginGrappleCollisionBypass(grapple)
    if not shouldSuppressGrappleCollisionCheck(grapple) then
        return nil
    end

    local movement = grapple.Movement
    local previousMoveCastParams = movement.moveCastParams
    movement.moveCastParams = getNoCollisionMoveCastParams()

    return function()
        if movement then
            movement.moveCastParams = previousMoveCastParams
        end
    end
end

function Logic.markGrappleBonkGrace(grapple, duration)
    local movement = grapple and grapple.Movement
    if not movement then
        return
    end

    Logic.LastGrappleMovement = movement
    Logic.SuppressBonkUntil = math.max(Logic.SuppressBonkUntil, time() + duration)
end

local function applyTrajectoryAntiBonk(grapple)
    if not (TrajectoryAntiBonk and TrajectoryAntiBonk.apply and Logic.isAntiBonkEnabled() and hasClassCapability(grapple, "MomentumGuard")) then
        return false
    end

    local allowed = canRunAssist("AntiBonk", grapple)
    if not allowed then
        return false
    end

    local params = getEmergencyFloorRaycastParams(grapple)
    local applied, prediction = TrajectoryAntiBonk.apply({
        now = time,
        VelocityAssist = VelocityAssist,
        getPhysicsProfile = getPhysicsProfile,
        Interval = CFG.TRAJECTORY_ANTIBONK_INTERVAL,
        Lookahead = CFG.TRAJECTORY_ANTIBONK_LOOKAHEAD,
        MinSpeed = CFG.TRAJECTORY_ANTIBONK_MIN_SPEED,
        raycast = function(position, direction)
            return Workspace:Raycast(position, direction, params)
        end,
    }, grapple)
    Logic.LastAntiBonkPrediction = prediction
    if applied then
        Logic.markGrappleBonkGrace(grapple, 0.45)
        claimAssist("AntiBonk", "TrajectoryAntiBonk", 0.16)
    end
    return applied == true
end

function Logic.ensureDiveBonkHook(globals)
    if globals.GrappleAimAssistOriginalDiveBonk then
        return
    end

    local movementCore = getMovementCore()
    if not (movementCore and typeof(movementCore.DiveBonk) == "function") then
        return
    end

    local originalDiveBonk = movementCore.DiveBonk
    globals.GrappleAimAssistOriginalDiveBonk = originalDiveBonk

    movementCore.DiveBonk = function(self, ...)
        if globals.activeGrappleAimAssist ~= Logic then
            return originalDiveBonk(self, ...)
        end
        if shouldSuppressGrappleBonk(self) then
            self.diveBonked = false
            self.bonkedOffPlayer = false
            return nil
        end

        return originalDiveBonk(self, ...)
    end
end

function Logic.resetRuntimeState(grapple, reason)
    Logic.CurrentGrappleStep = nil
    Logic.LastKnownGrapple = grapple
    Logic.LastGrappleMovement = grapple and grapple.Movement or nil
    Logic.LastRuntimeCharacter = grapple and grapple.Character or nil
    Logic.LastRuntimeRootPart = grapple and grapple.RootPart or nil
    Logic.LastRuntimeMovement = grapple and grapple.Movement or nil
    Logic.SuppressBonkUntil = 0
    Logic.AdaptDriveActive = false
    Logic.AdaptRecastToken = Logic.AdaptRecastToken + 1
    Logic.AdaptRecastPending = false
    Logic.AdaptRecastReleaseIssued = false
    Logic.AdaptRecastRequestedAt = 0
    Logic.AdaptRecastReleaseAt = 0
    Logic.AdaptAwaitingAttachUntil = 0
    Logic.AdaptRetryAt = 0
    Logic.AutoRescueUntil = 0
    Logic.LastAutoRescuePulseAt = 0
    Logic.LastPanicRescuePulseAt = 0
    Logic.LastPanicInputAt = 0
    Logic.PanicInputCount = 0
    Logic.PanicPressureUntil = 0
    Logic.PanicStabilizeUntil = 0
    Logic.LastPanicWatchdogAt = 0
    Logic.LastPanicDangerEvalAt = 0
    Logic.LastPanicDangerValue = false
    Logic.EmergencyRescueLockUntil = 0
    Logic.LastVoidRescueAt = 0
    Logic.VoidRescueUntil = 0
    Logic.TerrainFallState = nil
    Logic.LastTerrainFallEvalAt = 0
    Logic.EmergencyFloorRaycastParams = nil
    Logic.EmergencyFloorRaycastCharacter = nil
    Logic.LastSharkTailAssistAt = 0
    Logic.LastSharkTailEvalAt = 0
    Logic.NextSharkTailEvalDelay = 0.08
    Logic.SharkTailPlanToken = Logic.SharkTailPlanToken + 1
    Logic.SharkTailPlannedAt = 0
    Logic.SharkTailStabilizeUntil = 0
    Logic.LastSmartReelStartAt = 0
    Logic.LastAssistTargetInstance = nil
    Logic.LastAssistTargetAt = 0
    Logic.LastAssistDebug = reason and ("RuntimeReset:" .. tostring(reason)) or nil
    Logic.LastSmartReelEvalAt = 0
    Logic.LastSmartReelDebug = nil
    Logic.LastSmartReelDecision = nil
    Logic.SmartReelLandingAssistUntil = 0
    Logic.SmartReelLandingTargetPosition = nil
    Logic.SmartReelLandingPlaneY = nil
    Logic.MovementIntentState = MOVEMENT_INTENT.Freefall
    Logic.MovementIntentUntil = 0
    Logic.MovementIntentReason = nil
    Logic.JumpPadCommitGuardUntil = 0
    Logic.LastJumpPadCommitAt = 0
    Logic.LastJumpPadCommitPart = nil
    Logic.LastIntentSnapshot = nil
    Logic.LastIntentSnapshotAt = 0
    Logic.LastIntentSnapshotGrapple = nil
    Logic.LastIntentSnapshotRescueResult = nil
    Logic.LastPhysicsProfile = nil
    Logic.LastThreatSnapshot = nil
    Logic.LastLandingGuard = nil
    Logic.LastAntiBonkPrediction = nil
    Logic.LastPredictionHorizon = nil
    Logic.AssistArbiterState = AssistArbiter and AssistArbiter.new and AssistArbiter.new() or nil

    if HealthMonitor and typeof(HealthMonitor.reset) == "function" then
        HealthMonitor.reset()
    end
    if PhysicsProfile and PhysicsProfile.clear then
        PhysicsProfile.clear()
    end
    if ThreatModel and ThreatModel.clear then
        ThreatModel.clear()
    end
    if SafeLandingGuard and SafeLandingGuard.clear then
        SafeLandingGuard.clear()
    end
    if TrajectoryAntiBonk and TrajectoryAntiBonk.clear then
        TrajectoryAntiBonk.clear()
    end

    Logic.BellBypassToken = Logic.BellBypassToken + 1
    releaseBellBypass()
    restoreJumpPadBypassParts()
    Logic.LastJumpPadUsesBypassEnabled = false
    if Logic.FallbackHitbox then
        pcall(function()
            Logic.FallbackHitbox:Destroy()
        end)
        Logic.FallbackHitbox = nil
    end
    Logic.NoCollisionMoveCastParams = nil
    MapSense.clear()
    table.clear(Logic.Candidates)
    Logic.CandidateCursor = 1
end

function Logic.enable()
    local globals = Logic.getGlobals()
    Logic.resetRuntimeState(nil, "Enable")
    if Logic.MapModel and Logic.MapModel.start then
        Logic.MapModel.start()
    end
    if globals.GrappleAimAssistHooked then
        globals.activeGrappleAimAssist = Logic
        Logic.ensureDiveBonkHook(globals)
        watchAdaptInput()
        watchCandidateFolder()
        return true
    end

    local grappleModule = getGrappleModule()
    if not grappleModule or typeof(grappleModule.Cast) ~= "function" then
        return false
    end
    clearLegacyInfiniteStaminaHook(globals, grappleModule)

    local originalCast = grappleModule.Cast
    globals.GrappleAimAssistOriginalCast = originalCast

    grappleModule.Cast = function(self, forceRefresh, ...)
        if globals.activeGrappleAimAssist ~= Logic then
            return originalCast(self, forceRefresh, ...)
        end
        local assistedResults = packValues(HealthMonitor.try("CastAssist", assistedCast, self, forceRefresh, originalCast, ...))
        if assistedResults[1] then
            return table.unpack(assistedResults, 2, assistedResults.n)
        end

        return originalCast(self, forceRefresh, ...)
    end

    if typeof(grappleModule.Start) == "function" then
        local originalStart = grappleModule.Start
        globals.GrappleAimAssistOriginalStart = originalStart

        grappleModule.Start = function(self, result, ...)
            if globals.activeGrappleAimAssist ~= Logic then
                return originalStart(self, result, ...)
            end
            Logic.LastKnownGrapple = self
            refillStamina(self)
            if hasClassCapability(self, "JumpPadBypass") then
                maintainJumpPadUsesBypass()
            end
            local jumpPadTarget = result and result.Instance
            if Logic.isJumpPadInstance(jumpPadTarget) then
                Logic.markJumpPadCommit(self, jumpPadTarget)
            end
            if hasClassCapability(self, "JumpPadBypass") and Logic.isJumpPadUsesBypassEnabled() and Logic.isJumpPadInstance(jumpPadTarget) then
                normalizeJumpPadForReuse(jumpPadTarget)
            end

            if hasClassCapability(self, "BellBypass") and result and result.Instance and result.Instance.Name == "Bell" then
                holdBellBypass(result.Instance)
            end

            local startResult = originalStart(self, result, ...)
            refillStamina(self)
            if hasClassCapability(self, "JumpPadBypass") and Logic.isJumpPadUsesBypassEnabled() and Logic.isJumpPadInstance(jumpPadTarget) then
                normalizeJumpPadForReuse(jumpPadTarget)
            end
            maintainBellBypass(self)
            return startResult
        end
    end

    if typeof(grappleModule.AltSpecialAction) == "function" then
        local originalAltSpecialAction = grappleModule.AltSpecialAction
        globals.GrappleAimAssistOriginalAltSpecialAction = originalAltSpecialAction

        grappleModule.AltSpecialAction = function(self, state, ...)
            if globals.activeGrappleAimAssist ~= Logic then
                return originalAltSpecialAction(self, state, ...)
            end
            if Logic.isSuiteEnabled() and hasAnyGrappleAssistCapability(self) and state == Enum.UserInputState.Begin then
                local shouldManualSharkTail = Logic.isSharkTailHelperEnabled()
                    and getModeValue("GrappleSharkTailMode") == "Manual"
                    and shouldUseSmartSharkTail(self, true)
                if shouldManualSharkTail then
                    local ok, used = HealthMonitor.try("ManualSharkTail", tryUseSharkTail, self)
                    if ok and used then
                        return nil
                    end
                end

                if Logic.isSmartReelEnabled() and getModeValue("GrappleSmartReelMode") == "Manual" then
                    local ok, started = HealthMonitor.try("ManualSmartReel", startSmartReel, self, true)
                    if ok and started then
                        return nil
                    end
                end
            end

            return originalAltSpecialAction(self, state, ...)
        end
    end

    if typeof(grappleModule.SharkTail) == "function" then
        local originalSharkTail = grappleModule.SharkTail
        globals.GrappleAimAssistOriginalSharkTail = originalSharkTail

        grappleModule.SharkTail = function(self, ...)
            if globals.activeGrappleAimAssist ~= Logic then
                return originalSharkTail(self, ...)
            end
            local previousVelocity = self and self.RootPart and self.RootPart.Velocity
            local result = originalSharkTail(self, ...)
            HealthMonitor.try("SharkTailPull", applySharkTailPullMultiplier, self, previousVelocity)
            return result
        end
    end

    if typeof(grappleModule.Step) == "function" then
        local originalStep = grappleModule.Step
        globals.GrappleAimAssistOriginalStep = originalStep

        grappleModule.Step = function(self, dt, ...)
            if globals.activeGrappleAimAssist ~= Logic then
                return originalStep(self, dt, ...)
            end
            if self
                and (self.Character ~= Logic.LastRuntimeCharacter
                    or self.RootPart ~= Logic.LastRuntimeRootPart
                    or self.Movement ~= Logic.LastRuntimeMovement) then
                Logic.resetRuntimeState(self, "RuntimeChanged")
            end
            Logic.LastKnownGrapple = self
            HealthMonitor.try("RefillStamina", refillStamina, self)
            if hasClassCapability(self, "JumpPadBypass") then
                HealthMonitor.try("JumpPadBypass", maintainJumpPadUsesBypass)
            end
            HealthMonitor.try("BellBypass", maintainBellBypass, self)
            if Logic.isSuiteEnabled() and hasAnyGrappleAssistCapability(self) then
                HealthMonitor.try("MapModel", Logic.updateMapModel, self, false)
                HealthMonitor.try("TerrainSense", updateTerrainFallContext, self)
                HealthMonitor.try("SafeLandingGuard", getSafeLandingGuard, self)
                HealthMonitor.try("IntentClassifier", getIntentSnapshot, self)
            end
            if hasClassCapability(self, "MomentumGuard") and self.Movement and (self.Movement.grappling or self.jumpPadReel) then
                Logic.markGrappleBonkGrace(self, 0.45)
            end

            if Logic.isSuiteEnabled() and hasAnyGrappleAssistCapability(self) and Logic.isInAir(self) then
                if hasClassCapability(self, "AimAssist") then
                    HealthMonitor.try("AdaptInputMode", updateAdaptInputMode, self)
                end

                local sharkTailPlanned = false
                if Logic.isSharkTailHelperEnabled() and getModeValue("GrappleSharkTailMode") == "Automatic" then
                    local ok, planned = HealthMonitor.try("AutoSharkTail", planSmartSharkTail, self)
                    sharkTailPlanned = ok and planned == true
                end

                if not sharkTailPlanned and not Logic.isJumpPadCommitGuardActive() and Logic.isSmartReelEnabled() and getModeValue("GrappleSmartReelMode") == "Automatic" then
                    HealthMonitor.try("AutoSmartReel", startSmartReel, self, false)
                end

                if not Logic.isJumpPadCommitGuardActive() then
                    HealthMonitor.try("PanicRescue", tryPanicRescue, self)
                end
                HealthMonitor.try("AutoMomentumRescue", tryAutoMomentumRescue, self)
                HealthMonitor.try("AdaptInputHold", maintainAdaptInputHold, self)
            end

            Logic.CurrentGrappleStep = self
            local _, restoreCollisionCheck = HealthMonitor.try("CollisionBypass", beginGrappleCollisionBypass, self)
            local stepResults = packValues(pcall(originalStep, self, dt, ...))
            local success = stepResults[1]
            Logic.CurrentGrappleStep = nil
            if restoreCollisionCheck then
                HealthMonitor.try("CollisionBypassRestore", restoreCollisionCheck)
            end
            if not success then
                error(stepResults[2], 0)
            end
            HealthMonitor.try("BellBypass", maintainBellBypass, self)
            HealthMonitor.try("RefillStamina", refillStamina, self)
            HealthMonitor.try("SafeLandingDamping", applySafeLandingGuard, self)
            HealthMonitor.try("TrajectoryAntiBonk", applyTrajectoryAntiBonk, self)
            HealthMonitor.try("ReelPull", applyReelPullMultiplier, self)
            HealthMonitor.try("AirControl", applyAirControlMultiplier, self, dt)
            HealthMonitor.try("MomentumGuard", applyMomentumGuard, self)
            HealthMonitor.try("PanicStabilize", applyPanicStabilize, self)
            HealthMonitor.try("SharkTailStabilize", applySharkTailStabilize, self)
            HealthMonitor.try("AdaptRecast", updateAdaptRecast, self)
            return table.unpack(stepResults, 2, stepResults.n)
        end
    end

    Logic.ensureDiveBonkHook(globals)

    if typeof(grappleModule.End) == "function" then
        local originalEnd = grappleModule.End
        globals.GrappleAimAssistOriginalEnd = originalEnd

        grappleModule.End = function(self, ...)
            if globals.activeGrappleAimAssist ~= Logic then
                return originalEnd(self, ...)
            end
            Logic.LastKnownGrapple = self
            if hasClassCapability(self, "MomentumGuard") then
                Logic.markGrappleBonkGrace(self, 0.45)
            end
            local endResult = originalEnd(self, ...)
            scheduleBellBypassRelease(0.5)
            return endResult
        end
    end

    globals.GrappleAimAssistHooked = true
    globals.activeGrappleAimAssist = Logic
    watchAdaptInput()
    watchCandidateFolder()
    table.insert(Logic.Connections, RunService.Heartbeat:Connect(panicRescueWatchdog))
    return true
end

function Logic.disable()
    local globals = Logic.getGlobals()
    if HealthMonitor and typeof(HealthMonitor.reset) == "function" then
        HealthMonitor.reset()
    end
    if globals.activeGrappleAimAssist == Logic then
        globals.activeGrappleAimAssist = nil
    end
    local grappleModule = getGrappleModule()
    if grappleModule and globals.GrappleAimAssistOriginalCast then
        grappleModule.Cast = globals.GrappleAimAssistOriginalCast
    end
    if grappleModule and globals.GrappleAimAssistOriginalStart then
        grappleModule.Start = globals.GrappleAimAssistOriginalStart
    end
    if grappleModule and globals.GrappleAimAssistOriginalStep then
        grappleModule.Step = globals.GrappleAimAssistOriginalStep
    end
    if grappleModule and globals.GrappleAimAssistOriginalEnd then
        grappleModule.End = globals.GrappleAimAssistOriginalEnd
    end
    if grappleModule and globals.GrappleAimAssistOriginalAltSpecialAction then
        grappleModule.AltSpecialAction = globals.GrappleAimAssistOriginalAltSpecialAction
    end
    if grappleModule and globals.GrappleAimAssistOriginalSharkTail then
        grappleModule.SharkTail = globals.GrappleAimAssistOriginalSharkTail
    end
    local movementCore = getMovementCore()
    if movementCore and globals.GrappleAimAssistOriginalDiveBonk then
        movementCore.DiveBonk = globals.GrappleAimAssistOriginalDiveBonk
    end

    globals.GrappleAimAssistOriginalCast = nil
    globals.GrappleAimAssistOriginalStart = nil
    globals.GrappleAimAssistOriginalStep = nil
    globals.GrappleAimAssistOriginalEnd = nil
    globals.GrappleAimAssistOriginalAltSpecialAction = nil
    globals.GrappleAimAssistOriginalSharkTail = nil
    globals.GrappleAimAssistOriginalDiveBonk = nil
    globals.GrappleAimAssistHooked = false
    Logic.CurrentGrappleStep = nil
    Logic.LastKnownGrapple = nil
    Logic.LastGrappleMovement = nil
    Logic.LastRuntimeCharacter = nil
    Logic.LastRuntimeRootPart = nil
    Logic.LastRuntimeMovement = nil
    Logic.SuppressBonkUntil = 0
    Logic.LastSharkTailAssistAt = 0
    Logic.LastSharkTailEvalAt = 0
    Logic.NextSharkTailEvalDelay = 0.08
    Logic.SharkTailPlanToken = Logic.SharkTailPlanToken + 1
    Logic.SharkTailPlannedAt = 0
    Logic.SharkTailStabilizeUntil = 0
    Logic.LastSmartReelStartAt = 0
    Logic.LastPanicInputAt = 0
    Logic.PanicInputCount = 0
    Logic.PanicPressureUntil = 0
    Logic.PanicStabilizeUntil = 0
    Logic.LastPanicWatchdogAt = 0
    Logic.LastPanicDangerEvalAt = 0
    Logic.LastPanicDangerValue = false
    Logic.EmergencyRescueLockUntil = 0
    Logic.LastVoidRescueAt = 0
    Logic.VoidRescueUntil = 0
    Logic.TerrainFallState = nil
    Logic.LastTerrainFallEvalAt = 0
    Logic.EmergencyFloorRaycastParams = nil
    Logic.EmergencyFloorRaycastCharacter = nil
    Logic.LastAssistTargetInstance = nil
    Logic.LastAssistTargetAt = 0
    Logic.LastAssistDebug = nil
    Logic.LastSmartReelEvalAt = 0
    Logic.LastSmartReelDebug = nil
    Logic.LastSmartReelDecision = nil
    Logic.LastIntentSnapshot = nil
    Logic.LastIntentSnapshotAt = 0
    Logic.LastIntentSnapshotGrapple = nil
    Logic.LastIntentSnapshotRescueResult = nil
    Logic.LastPhysicsProfile = nil
    Logic.LastThreatSnapshot = nil
    Logic.LastLandingGuard = nil
    Logic.LastAntiBonkPrediction = nil
    Logic.LastPredictionHorizon = nil
    Logic.AssistArbiterState = AssistArbiter and AssistArbiter.new and AssistArbiter.new() or nil
    if PhysicsProfile and PhysicsProfile.clear then
        PhysicsProfile.clear()
    end
    if ThreatModel and ThreatModel.clear then
        ThreatModel.clear()
    end
    if SafeLandingGuard and SafeLandingGuard.clear then
        SafeLandingGuard.clear()
    end
    if TrajectoryAntiBonk and TrajectoryAntiBonk.clear then
        TrajectoryAntiBonk.clear()
    end
    Logic.SmartReelLandingAssistUntil = 0
    Logic.SmartReelLandingTargetPosition = nil
    Logic.SmartReelLandingPlaneY = nil
    Logic.MovementIntentState = MOVEMENT_INTENT.Freefall
    Logic.MovementIntentUntil = 0
    Logic.MovementIntentReason = nil
    Logic.JumpPadCommitGuardUntil = 0
    Logic.LastJumpPadCommitAt = 0
    Logic.LastJumpPadCommitPart = nil
    Logic.BellBypassToken = Logic.BellBypassToken + 1
    releaseBellBypass()
    restoreJumpPadBypassParts()
    Logic.LastJumpPadUsesBypassEnabled = false
    if Logic.FallbackHitbox then
        pcall(function()
            Logic.FallbackHitbox:Destroy()
        end)
        Logic.FallbackHitbox = nil
    end
    Logic.NoCollisionMoveCastParams = nil
    clearInputConnections()
    clearConnections()
    MapSense.clear()
    if Logic.MapModel and Logic.MapModel.stop then
        Logic.MapModel.stop()
    elseif Logic.MapModel and Logic.MapModel.clear then
        Logic.MapModel.clear()
    end
    table.clear(Logic.Candidates)
end

function Logic.getTargetOptions()
    local options = {}
    for _, option in ipairs(TARGET_OPTIONS) do
        table.insert(options, option)
    end
    return options
end

function Logic.getRangeOptions()
    local options = {}
    for _, option in ipairs(RANGE_OPTIONS) do
        table.insert(options, option)
    end
    return options
end

function Logic.isAdaptInputHeld()
    return Logic.AdaptInputHeld == true
end

function Logic.getLastAdaptInputPressed()
    return Logic.LastAdaptInputPressed
end

function Logic.getHealthStatus()
    local baseStatus = "Core OK"
    if HealthMonitor and typeof(HealthMonitor.getStatus) == "function" then
        baseStatus = HealthMonitor.getStatus()
    end

    local intent = Logic.LastIntentSnapshot
    local intentText = intent and (tostring(intent.State) .. "/" .. tostring(intent.Reason)) or "Intent:pending"
    local arbiterText = AssistArbiter and AssistArbiter.snapshot and AssistArbiter.snapshot(Logic.AssistArbiterState) or "Arbiter:pending"
    local profileText = PhysicsProfile and PhysicsProfile.describe and PhysicsProfile.describe(Logic.LastPhysicsProfile) or "Profile:pending"
    local threatText = ThreatModel and ThreatModel.snapshot and ThreatModel.snapshot() or "Threat:pending"
    local landingText = SafeLandingGuard and SafeLandingGuard.snapshot and SafeLandingGuard.snapshot() or "Landing:pending"
    local bonkText = TrajectoryAntiBonk and TrajectoryAntiBonk.snapshot and TrajectoryAntiBonk.snapshot() or "Bonk:pending"
    local horizonText = PredictionHorizon and PredictionHorizon.snapshot and PredictionHorizon.snapshot(Logic.LastPredictionHorizon) or "Horizon:pending"
    local mapText = Logic.MapModel and Logic.MapModel.snapshot and Logic.MapModel.snapshot() or "MapModel:pending"
    return tostring(baseStatus)
        .. " | "
        .. intentText
        .. " | "
        .. tostring(arbiterText)
        .. " | "
        .. tostring(profileText)
        .. " | "
        .. tostring(threatText)
        .. " | "
        .. tostring(landingText)
        .. " | "
        .. tostring(bonkText)
        .. " | "
        .. tostring(horizonText)
        .. " | "
        .. tostring(mapText)
end

function Logic.clearMapModel()
    if Logic.MapModel and Logic.MapModel.clear then
        Logic.MapModel.clear()
    end
end

function Logic.setMapModelDebugEnabled(value)
    if Logic.MapModel and Logic.MapModel.setDebugEnabled then
        Logic.MapModel.setDebugEnabled(value == true)
    end
end

function Logic.setMapModelDebugMode(mode)
    if Logic.MapModel and Logic.MapModel.setDebugMode then
        Logic.MapModel.setDebugMode(mode)
    end
end

function Logic.setMapModel3DDebugEnabled(value)
    if Logic.MapModel and Logic.MapModel.setDebug3DEnabled then
        Logic.MapModel.setDebug3DEnabled(value == true)
    end
end

return Logic
