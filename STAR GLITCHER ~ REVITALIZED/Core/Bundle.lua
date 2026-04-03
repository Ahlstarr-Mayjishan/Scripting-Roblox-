--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘     Boss Aim Assist â€” Centralized Brain Orchestration v6       â•‘
    â•‘  Scientifically Reorganized | Fully Decoupled | Brain Driven  â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
    TargetPart = "HumanoidRootPart",
    TargetingMethod = "FOV",
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
    ApocalypseEnabled = false,
    AutoCleanEnabled = true,
    SmartCleanupEnabled = true,
    AutoUpdateEnabled = false,
    AutoUpdateIntervalMinutes = 5,
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
    print("âœ… [Loader] Loading Star Glitcher from local workspace...")
    local chunk, err = loadstring(mainContent, "=Core/Main.lua")
    if chunk then
        chunk()
    else
        warn("âŒ [Loader] Failed to compile Main.lua: " .. tostring(err))
    end
else
    warn("âŒ [Loader] Could not find Core/Main.lua in workspace/" .. _G.BossAimAssist_LocalPath)
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

function Aimbot:Update(targetPosition, smoothness)
    if not targetPosition then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local alpha = smoothness or self.Options.Smoothness or 0.15
    local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPosition)

    if targetPosition.X == targetPosition.X then
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
    end
end

function Aimbot:SetState(active)
    self.Active = active
end

return Aimbot
]====],
    ["Modules/Combat/Hijackers/Apocalypse.lua"] = [====[--[[
    Apocalypse.lua - The Ultimate Neural Hijacker
    Job: Parasitic locking of game projectiles and beams to boss entities.
    Notes: Uses a singleton hook state to avoid stacking hooks across reloads.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Apocalypse = {}
Apocalypse.__index = Apocalypse

local GLOBAL_HOOK_KEY = "__STAR_GLITCHER_APOCALYPSE_HOOK"

local function ensureHookState()
    local hookState = getgenv()[GLOBAL_HOOK_KEY]
    if hookState then
        return hookState
    end

    local mouse = LocalPlayer:GetMouse()
    hookState = {
        Instance = nil,
        Mouse = mouse,
    }

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local selfRef = hookState.Instance
        local method = getnamecallmethod()
        local args = table.pack(...)

        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef.Active
            and selfRef._bossExists then
            if method == "FireServer" or method == "InvokeServer" then
                for i = 1, args.n do
                    local value = args[i]
                    if typeof(value) == "Vector3" then
                        args[i] = selfRef._bossPos
                    elseif typeof(value) == "CFrame" then
                        args[i] = CFrame.new(selfRef._bossPos)
                    end
                end
                return oldNamecall(inst, unpack(args, 1, args.n))
            end

            if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and inst == Camera then
                return Ray.new(Camera.CFrame.Position, (selfRef._bossPos - Camera.CFrame.Position).Unit)
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        local selfRef = hookState.Instance
        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef.Active
            and selfRef._bossExists
            and inst == hookState.Mouse then
            if index == "Hit" then
                return CFrame.new(selfRef._bossPos)
            end
            if index == "Target" then
                return selfRef._bossModel
            end
        end

        return oldIndex(inst, index)
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function Apocalypse.new(config)
    local self = setmetatable({}, Apocalypse)
    self.Options = config.Options
    self.Active = config.Options.ApocalypseEnabled == true

    self._bossPos = Vector3.zero
    self._bossModel = nil
    self._bossExists = false
    self._connections = {}
    self._destroyed = false
    self._hookState = nil

    return self
end

function Apocalypse:Init()
    if not (hookmetamethod or hookfunction) then
        return
    end

    self._destroyed = false
    self._hookState = ensureHookState()
    self._hookState.Instance = self

    local selfRef = self
    local lastTrackerUpdate = 0
    local lastFullScan = 0

    table.insert(self._connections, RunService.Heartbeat:Connect(function()
        if selfRef._destroyed or not selfRef.Active then
            selfRef._bossExists = false
            return
        end

        local now = os.clock()
        if now - lastTrackerUpdate < 0.03 then
            return
        end
        lastTrackerUpdate = now

        local found = nil
        local entities = Workspace:FindFirstChild("Entities")

        if entities then
            for _, model in ipairs(entities:GetChildren()) do
                if model:IsA("Model") then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and model ~= LocalPlayer.Character then
                        found = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                        if found then
                            break
                        end
                    end
                end
            end
        end

        if not found and (now - lastFullScan > 1.5) then
            lastFullScan = now
            if entities then
                for _, descendant in ipairs(entities:GetDescendants()) do
                    if descendant:IsA("Humanoid") and descendant.Parent ~= LocalPlayer.Character and descendant.Health > 0 then
                        found = descendant.Parent:FindFirstChild("HumanoidRootPart") or descendant.Parent.PrimaryPart
                        if found then
                            break
                        end
                    end
                end
            end
        end

        if found then
            selfRef._bossPos = found.Position
            selfRef._bossModel = found.Parent
            selfRef._bossExists = true
        else
            selfRef._bossExists = false
            selfRef._bossModel = nil
        end
    end))

    local activeProjectiles = {}
    local effectCache = {}

    table.insert(self._connections, Workspace.ChildAdded:Connect(function(child)
        if child.Name == "BallOfLight" then
            activeProjectiles[#activeProjectiles + 1] = child
        end
    end))

    local function updateEffectCache()
        table.clear(effectCache)
        local char = LocalPlayer.Character
        if char then
            for _, descendant in ipairs(char:GetDescendants()) do
                if descendant:IsA("Beam") or descendant:IsA("Trail") then
                    effectCache[#effectCache + 1] = descendant
                end
            end
        end
    end

    table.insert(self._connections, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if not selfRef._destroyed then
            updateEffectCache()
        end
    end))
    updateEffectCache()

    table.insert(self._connections, RunService.RenderStepped:Connect(function()
        if selfRef._destroyed or not selfRef.Active or not selfRef._bossExists then
            return
        end

        local bossPos = selfRef._bossPos
        for i = #activeProjectiles, 1, -1 do
            local projectile = activeProjectiles[i]
            if projectile and projectile.Parent then
                pcall(function()
                    local attachment = projectile:FindFirstChild("Attachment1")
                    if attachment then
                        attachment.WorldPosition = bossPos
                    end
                    local targetCFrame = projectile:FindFirstChild("TargCF")
                    if targetCFrame then
                        targetCFrame.Value = CFrame.new(bossPos)
                    end
                end)
            else
                table.remove(activeProjectiles, i)
            end
        end

        for _, effect in ipairs(effectCache) do
            pcall(function()
                if effect.Attachment1 then
                    effect.Attachment1.WorldPosition = bossPos
                end
            end)
        end
    end))
end

function Apocalypse:SetState(active)
    self.Active = active
    if not active then
        self._bossExists = false
        self._bossModel = nil
    end
end

function Apocalypse:Destroy()
    self._destroyed = true
    self.Active = false
    self._bossExists = false
    self._bossModel = nil

    if self._hookState and self._hookState.Instance == self then
        self._hookState.Instance = nil
    end

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return Apocalypse
]====],
    ["Modules/Combat/Prediction/Base.lua"] = [====[--[[
    Base.lua â€” Scientific Physics Core (Smart Prediction)
    Implements advanced kinematic equations:
    â€¢ Uniform Linear Motion: s = vt
    â€¢ Uniformly Accelerated Motion: s = v0t + 0.5at^2
    â€¢ Braking/Deceleration compensation
    â€¢ Jerk-aware extrapolation
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
    -- Náº¿u lÃ  Beam (tá»‘c Ä‘á»™ Ã¡nh sÃ¡ng), travelTime ~ 0.
    -- Vá»›i phÃ©p thuáº­t cÃ³ váº­n tá»‘c, travelTime = dist / bulletSpeed.
    local travelTime = (dist / 1000) * (self.Options.PredictionScale or 1)
    
    -- 2. Kinematic Equations Dispatch
    local predictedOffset = Vector3.zero
    
    if acceleration and acceleration.Magnitude > 0.05 then
        -- Chuyá»ƒn Ä‘á»™ng cÃ³ gia tá»‘c Ä‘á»u: s = vt + 0.5at^2
        predictedOffset = (velocity * travelTime) + (0.5 * acceleration * travelTime * travelTime)
        
        -- Jerk compensation: s += (1/6) * j * t^3
        if jerk and jerk.Magnitude > 0.01 then
            predictedOffset = predictedOffset + ( (1/6) * jerk * math.pow(travelTime, 3) )
        end
    else
        -- Chuyá»ƒn Ä‘á»™ng tháº³ng Ä‘á»u: s = vt
        predictedOffset = velocity * travelTime
    end
    
    -- 3. Braking / Deceleration Logic (QuÃ£ng Ä‘Æ°á»ng phanh)
    -- Náº¿u váº­n tá»‘c Ä‘ang giáº£m máº¡nh (a ngÆ°á»£c chiá»u v), chÃºng ta bÃ¹ trá»« quÃ£ng Ä‘Æ°á»ng phanh
    local speed = velocity.Magnitude
    if speed > 1 and acceleration then
        local dot = velocity.Unit:Dot(acceleration.Unit)
        if dot < -0.7 then -- Äang phanh/hÃ£m
            local deceleration = acceleration.Magnitude
            -- s_phanh = v^2 / 2a (CÃ´ng thá»©c quÃ£ng Ä‘Æ°á»ng hÃ£m)
            local brakingDist = (speed * speed) / (2 * deceleration)
            
            -- Giá»›i háº¡n bÃ¹ trá»« phanh Ä‘á»ƒ trÃ¡nh jitter
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

    if part.Shape == Enum.PartType.Ball then
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

function Engine:Calculate(origin, targetPos, est, dt, entry, part)
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
    local totalTime = travelTime + latency + frameComp

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
        local lateralTrust = self:_GetLateralTrust(targetProfile, confidence, lateralAlpha, shockAlpha)
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
        local accelWeight = math.clamp((1.08 - (totalTime * 0.3)) * (0.65 + (speedAlpha * 0.45) + (lateralAlpha * 0.2) + profileBonus), 0.24, 1.34) * accelTrust
        local jerkWeight = math.clamp((0.58 - totalTime) * (0.45 + (speedAlpha * 0.35) + (lateralAlpha * 0.15) + (profileBonus * 0.5)), 0.05, 0.6) * jerkTrust

        predictedOffset = predictedOffset + ((0.5 * accel * (totalTime ^ 2)) * accelWeight)
        predictedOffset = predictedOffset + (((1 / 6) * jerk * (totalTime ^ 3)) * jerkWeight)
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
        (confidence * 0.75) + ((est.Stable and 0.15) or 0) + (speedAlpha * 0.12) + (lateralAlpha * 0.12) - (shockAlpha * 0.2),
        0.12,
        1
    )
    return targetPos:Lerp(predictedPos, trustFactor)
end

return Engine
]====],
    ["Modules/Combat/Prediction/Estimator.lua"] = [====[--[[
    Estimator.lua â€” State Estimation & Noise Removal (Physics Damping v2)
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
    result.RawVelocity = measurement
    result.PhysicsVelocity = physicsVelocity
    result.TimeDelta = sampleDt
    return result
end

return Estimator
]====],
    ["Modules/Combat/Prediction/Sampler.lua"] = [====[--[[
    Sampler.lua â€” Pure Kinematic Data Extraction
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
    if part and part.Shape == Enum.PartType.Ball then
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
    self.BaseSmoothing = 0.88
    self.CatchupSmoothing = 3.1
    self.SnapDistance = 7.5
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

    local catchupAlpha = math.clamp((deltaMagnitude - 0.75) / 8.5, 0, 1)
    local smoothing = self.BaseSmoothing + ((self.CatchupSmoothing - self.BaseSmoothing) * catchupAlpha)
    local alpha = 1 - math.exp(-smoothing * math.max((dt or DEFAULT_DT) * 60, 1))
    local result = lastTarget:Lerp(targetPos, alpha)

    self._lastTarget = result
    return result
end

return Stabilizer
]====],
    ["Modules/Combat/Predictor.lua"] = [====[--[[
    Predictor.lua â€” High-Performance Layered Orchestrator
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
    
    -- Instantiate shared stateless layers
    self.Sampler = Sampler.new(config)
    self.Engine = Engine.new(config)

    -- Keep stateful layers isolated per target so target switching does not
    -- bleed velocity smoothing or screen stabilization across different entries.
    self._EstimatorClass = Estimator
    self._StabilizerClass = Stabilizer
    self._KalmanFactory = kalman and kalman.new or nil
    self._EntryStates = setmetatable({}, { __mode = "k" })
    return self
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
    -- GUARD: Ensure entry exists
    if not entry then return part.Position end
    local state = self:_GetState(entry)
    
    -- 1. SAMPLING (Input Only)
    local raw = self.Sampler:GetRawState(part, entry.LastPos, entry.LastTime, dt)
    
    -- 2. ESTIMATION (Cleaning State)
    local est = state.Estimator:Estimate(raw, dt)
    
    -- Update entry metadata (Monitoring only, No logic)
    entry.LastPos = raw.Position
    entry.LastTime = raw.Time
    
    -- 3. PREDICTION (Exactly one strategy)
    local predicted = self.Engine:Calculate(origin, raw.Position, est, dt, entry, part)
    
    -- 4. PRESENTATION (Smoothing)
    return state.Stabilizer:Smooth(predicted, dt), predicted
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
    "sprint", "speed", "walk", "jump", "action", "interact", "dialogue", "inventory", "tab"
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

                if (method == "FireServer" or method == "InvokeServer") and isCombatRemote(inst) then
                    local modified = false

                    for i = 1, args.n do
                        local arg = args[i]
                        if typeof(arg) == "Vector3" then
                            args[i] = selfRef.TargetPosCache
                            modified = true
                            break -- FIX: Only modify the first Vector3 (Primary Target) to avoid breaking skills
                        elseif typeof(arg) == "Instance" and (arg:IsA("BasePart") or arg:IsA("Model")) then
                            local localCharacter = LocalPlayer.Character
                            if not (localCharacter and arg:IsDescendantOf(localCharacter)) then
                                args[i] = selfRef.TargetPartCache
                                modified = true
                                break -- FIX: Same for Instances
                            end
                        elseif typeof(arg) == "CFrame" then
                            args[i] = buildTargetCFrame(selfRef.TargetPosCache)
                            modified = true
                            break -- FIX: Same for CFrames
                        elseif typeof(arg) == "Ray" then
                            args[i] = buildTargetRay(arg.Origin, selfRef.TargetPosCache, arg.Direction.Magnitude)
                            modified = true
                            break
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
    return self
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
    self._scanInterval = 1 / 30
    return self
end

function Brain:_isDeadlockMode()
    return tostring(self.Options.TargetingMethod or "FOV") == "Deadlock"
end

function Brain:Scan(mousePos, originPos)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local deadlockMode = self:_isDeadlockMode()
    if not shouldAssist then
        if deadlockMode and self.Options.AssistMode ~= "Off" then
            return
        end
        self.Parietal.Tracker.CurrentTargetEntry = nil
        return
    end

    local now = clock()
    if (now - self._lastScan) < self._scanInterval then
        return
    end
    self._lastScan = now

    local target = self.Temporal:Scan(mousePos, originPos)
    self.Parietal.Tracker.CurrentTargetEntry = target
end

function Brain:Update(dt, mousePos, camCFrame)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local entry = self.Parietal.Tracker.CurrentTargetEntry
    local maintainDeadlock = self:_isDeadlockMode() and self.Options.AssistMode ~= "Off" and entry ~= nil
    local shouldTrack = shouldAssist or maintainDeadlock

    if not shouldTrack or not entry then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local targetPart, targetPos, rawTargetPos = self.Temporal:Process(camCFrame.Position, dt)

    if not targetPart or not targetPos then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local sPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    self.Occipital:Process(mousePos, sPos, targetPart, onScreen)
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
    FrontalLobe.lua â€” Executive Function & Motor Control
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
    OccipitalLobe.lua â€” Visual Processing
    Analogy: Primary visual cortex.
    Job: Manages FOV, Highlight, and Target feedback dots.
]]

local OccipitalLobe = {}
OccipitalLobe.__index = OccipitalLobe

function OccipitalLobe.new(visuals)
    local self = setmetatable({}, OccipitalLobe)
    self.fov = visuals.fov
    self.hit = visuals.hit
    self.highlight = visuals.highlight
    self.dot = visuals.dot
    return self
end

function OccipitalLobe:Process(mousePos, targetPos, targetPart, onScreen)
    -- GUARD: FOV Update should always happen to ensure crosshair feedback
    self.fov:Update(mousePos)
    
    -- GUARD: Resolution findings (Fragility fixes)
    -- Only set dot/highlight if we have a valid onscreen target
    if targetPos and targetPart and onScreen then
        self.dot:Set(targetPos, true)
        self.highlight:Set(targetPart, true)
    else
        self:Clear()
    end
end

function OccipitalLobe:Clear()
    -- Safe cleanup: Ensure no trailing highlights or disconnected dots
    self.highlight:Clear()
    self.dot:Set(nil, false)
end

return OccipitalLobe
]====],
    ["Modules/Core/Brain/Parietal.lua"] = [====[--[[
    ParietalLobe.lua â€” Sensory & Input Processing
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
        return nil, nil
    end

    if self._targetEntry.Humanoid and self._targetEntry.Humanoid.Health <= 0 then
        self._targetEntry = nil
        self._targetPart = nil
        self._prediction = nil
        self._rawPrediction = nil
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

    self._prediction, self._rawPrediction = self.Predictor:Predict(originPos, self._targetPart, self._targetEntry, dt)

    return self._targetPart, self._prediction, self._rawPrediction
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

    local predicted = self.Predictor:Predict(origin, part, entry, dt or (1 / 60))
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

function AntiSlowdown.new(options, localCharacter)
    local self = setmetatable({}, AntiSlowdown)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.BaseJumpPower = 50
    self.TrackedHumanoid = nil

    self.Status = "Idle"
    self._lastAction = 0
    self._lastWriteTime = 0
    self._yieldingToSpeedOverride = false
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
            self:_setStatus("Disabled")
            return
        end

        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            self:_setStatus("Hum Missing")
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                self:CaptureBaseStats(hum)
            end
            self._yieldingToSpeedOverride = false
            self:_setStatus("Respawn Grace")
            return
        end

        if self.Options.CustomMoveSpeedEnabled or self.Options.SpeedMultiplierEnabled then
            self._yieldingToSpeedOverride = true
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
end

return AntiSlowdown
]====],
    ["Modules/Movement/AntiStun.lua"] = [====[--[[
    AntiStun.lua - Neurological Defense Module
    Job: Preventing character CC (Stun, Ragdoll, Sit, Fall).
    Status: Fully decoupled with active monitoring.
]]

local RunService = game:GetService("RunService")
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

function CustomSpeed.new(options, localCharacter)
    local self = setmetatable({}, CustomSpeed)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.TrackedHumanoid = nil
    self.BaseWalkSpeed = 16
    self._wasEnabled = false
    return self
end

function CustomSpeed:_captureBaseSpeed(humanoid)
    if humanoid then
        self.TrackedHumanoid = humanoid
        self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
    end
end

function CustomSpeed:_restoreBaseSpeed(humanoid)
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
            self._wasEnabled = false
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
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

        if math.abs(hum.WalkSpeed - self.Options.CustomMoveSpeed) > 0.1 then
            hum.WalkSpeed = self.Options.CustomMoveSpeed
        end
    end)
end

function CustomSpeed:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
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
    ["Modules/Movement/JumpBoost.lua"] = [====[local RunService = game:GetService("RunService")

local JumpBoost = {}
JumpBoost.__index = JumpBoost

local DEFAULT_JUMP_POWER = 50

function JumpBoost.new(options, localCharacter)
    local self = setmetatable({}, JumpBoost)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self.TrackedHumanoid = nil
    self.BaseJumpPower = DEFAULT_JUMP_POWER
    self._connection = nil
    self._applied = false
    return self
end

function JumpBoost:_captureBaseJump(humanoid)
    if humanoid then
        self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
    end
end

function JumpBoost:_restore()
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
            self.Status = "Respawn grace"
            return
        end

        if not self.Options.JumpBoostEnabled then
            if not self._applied then
                self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
                self.Status = "Idle"
                return
            end

            self:_restore()
            self.Status = "Idle"
            return
        end

        local desired = math.clamp(tonumber(self.Options.JumpBoostPower) or DEFAULT_JUMP_POWER, 1, 300)
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        if math.abs(humanoid.JumpPower - desired) > 0.1 then
            humanoid.JumpPower = desired
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
    self:_restore()
end

return JumpBoost
]====],
    ["Modules/Movement/SpeedMultiplier.lua"] = [====[local RunService = game:GetService("RunService")

local SpeedMultiplier = {}
SpeedMultiplier.__index = SpeedMultiplier

function SpeedMultiplier.new(options, localCharacter)
    local self = setmetatable({}, SpeedMultiplier)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.TrackedHumanoid = nil
    self.Status = "Idle"
    self._lastBoostTime = 0
    self._lastWalkWriteTime = 0
    self._fallbackWarmupUntil = 0
    self._wasEnabled = false
    self._preEnableBaseSpeed = 16
    return self
end

function SpeedMultiplier:_captureBaseSpeed(humanoid)
    self.TrackedHumanoid = humanoid
    self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
end

function SpeedMultiplier:_writeWalkSpeed(humanoid, value)
    if not humanoid then
        return
    end

    if math.abs(humanoid.WalkSpeed - value) > 0.1 then
        humanoid.WalkSpeed = value
        self._lastWalkWriteTime = os.clock()
    end
end

function SpeedMultiplier:_restoreBaseSpeed(humanoid)
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
        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            self.Status = "Hum Missing"
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                self:_captureBaseSpeed(hum)
            end
            self._fallbackWarmupUntil = 0
            self._wasEnabled = false
            self.Status = "Respawn Grace"
            return
        end

        if hum ~= self.TrackedHumanoid then
            self:_captureBaseSpeed(hum)
        end

        if not self.Options.SpeedMultiplierEnabled or self.Options.CustomMoveSpeedEnabled then
            self._fallbackWarmupUntil = 0
            if self._wasEnabled then
                self:_restoreBaseSpeed(hum)
            else
                self.BaseWalkSpeed = math.max(hum.WalkSpeed, 16)
            end
            self._wasEnabled = false
            self.Status = self.Options.CustomMoveSpeedEnabled and "Blocked by Fixed Speed" or "Disabled"
            return
        end

        if not self._wasEnabled then
            self._preEnableBaseSpeed = math.max(hum.WalkSpeed, 16)
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

return SpeedSpoof
]====],
    ["Modules/NPCPrediction.lua"] = [====[--[[
    NPCPrediction.lua â€” NPC-Specific Prediction Profile
    â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Káº¿ thá»«a PredictionCore, tuning cho Boss/NPC:
      â€¢ Kalman tiÃªu chuáº©n (khÃ´ng boost Q)
      â€¢ Ping bÃ¹ 1x (NPC khÃ´ng cÃ³ ping riÃªng)
      â€¢ Lead cap cao (Boss di chuyá»ƒn quÃ£ng dÃ i, thuáº­t sÄ© bay xa)
      â€¢ Reversal penalty nháº¹ (Boss Ã­t zigzag hÆ¡n Player)
      â€¢ KhÃ´ng cÃ³ Jump Arc prediction
]]

return function(PredictionCore)
    local NPCPrediction = setmetatable({}, { __index = PredictionCore })
    NPCPrediction.__index = NPCPrediction
    NPCPrediction.__Legacy = true

    function NPCPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, NPCPrediction)

        -- â•â•â• NPC PROFILE â•â•â•
        self.Profile = {
            KalmanQBoost      = 0,           -- KhÃ´ng boost: NPC movement á»•n Ä‘á»‹nh hÆ¡n
            PingMultiplier    = 1,            -- Server-side NPC, khÃ´ng cáº§n bÃ¹ ping thÃªm
            ReversalPenalty   = 0.6,          -- Confidence giáº£m 40% khi Ä‘á»•i hÆ°á»›ng
            LeadCap           = config.Prediction.MAX_LEAD_DIST,  -- 340 studs
            JumpArcEnabled    = false,        -- NPC khÃ´ng jump theo kiá»ƒu Player
            JumpGravity       = -196.2,
            JumpArcBlend      = 0,
        }

        return self
    end

    return NPCPrediction
end
]====],
    ["Modules/PredictionCore.lua"] = [====[--[[
    PredictionCore.lua â€” Base Prediction Engine (OOP)
    â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Class cÆ¡ sá»Ÿ chá»©a toÃ n bá»™ thuáº­t toÃ¡n prediction:
      â€¢ Kalman Filter, Intercept Solver, Kinematics
      â€¢ Motion State Analysis, Teleport Detection
      â€¢ Brain Response, Hit Feedback, Stabilization
    
    NPC/PvP-specific tuning náº±m trong self.Profile
    (Ä‘Æ°á»£c set bá»Ÿi NPCPrediction hoáº·c PvPPrediction).
    
    PERF: KhÃ´ng cÃ³ runtime branch cho NPC vs PvP.
    Má»i giÃ¡ trá»‹ Ä‘Æ°á»£c Ä‘á»c tá»« Profile table.
]]

local PredictionCore = {}
PredictionCore.__index = PredictionCore

PredictionCore.__Legacy = true
PredictionCore.__RuntimeReplacement = "Modules/Combat/Predictor.lua"

-- â•â•â• STATIC: Kinematics Helpers (no self) â•â•â•
-- DÃ¹ng PredictionCore.FuncName() thay vÃ¬ self: Ä‘á»ƒ trÃ¡nh overhead method lookup

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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- CONSTRUCTOR
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

function PredictionCore.new(config, npcTracker)
    local self = setmetatable({}, PredictionCore)
    self.Config = config
    self.Options = config.Options
    self.C = config.Prediction
    self.NPCTracker = npcTracker

    -- Ping cache
    self._cachedPing = 50
    self._lastPingCheck = 0

    -- Profile: sáº½ bá»‹ override bá»Ÿi NPCPrediction / PvPPrediction
    self.Profile = {
        KalmanQBoost = 0,
        PingMultiplier = 1,
        ReversalPenalty = 0.6,
        LeadCap = config.Prediction.MAX_LEAD_DIST,
        JumpArcEnabled = false,
        JumpGravity = -196.2,
        JumpArcBlend = 0.7,
    }

    -- Reusable context table (trÃ¡nh táº¡o table má»›i má»—i frame)
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UTILITY METHODS
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

-- â•â•â• Alpha Calculators (inlined math, no table lookups) â•â•â•

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

-- â•â•â• Motion Shock â•â•â•

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

-- â•â•â• Smart Projectile Speed â•â•â•

function PredictionCore:SmartProjectileSpeed(distance, targetSpeed, motionShock)
    local C = self.C
    local dA = self:DistanceAlpha(distance)
    local edA = self:ExtremeDistAlpha(distance)
    local sA = self:SpeedAlpha(targetSpeed)

    local ps = C.SMART_PROJECTILE_SPEED_BASE + (dA * 220) + (edA * 380) - (sA * 650) - (motionShock * 700)
    return math.clamp(ps, C.SMART_PROJECTILE_SPEED_MIN, C.SMART_PROJECTILE_SPEED_MAX)
end

-- â•â•â• Intercept Solver â•â•â•

function PredictionCore:SolveInterceptTime(shooterPos, targetPos, targetVel, projSpeed)
    if projSpeed <= 0 then return nil end
    local r = targetPos - shooterPos
    local v = targetVel
    local a = v:Dot(v) - (projSpeed * projSpeed)
    local b = 2 * r:Dot(v)
    local c = r:Dot(r)
    if c <= 1e-6 then return 0 end
    if math.abs(a) < 1e-5 then -- TrÃ¡nh chia cho sá»‘ gáº§n báº±ng 0
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

-- â•â•â• Jerk / Motion State â•â•â•

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

-- â•â•â• Teleport Detection â•â•â•

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

-- â•â•â• Brain Response â•â•â•

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

-- â•â•â• Hit Feedback â•â•â•

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

-- â•â•â• Close Orbit â•â•â•

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

-- â•â•â• Base Position â•â•â•

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

-- â•â•â• Smooth Aim Velocity â•â•â•

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
        -- Alpha tháº¥p (0.12) cho Silent Aim: Æ°u tiÃªn Ä‘á»™ mÆ°á»£t hÆ¡n Ä‘á»™ nháº¡y
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

-- â•â•â• Entry Motion Velocity â•â•â•

function PredictionCore:EntryMotionVelocity(entry, part)
    if entry then
        if entry.SmoothedAimVelocity and entry.SmoothedAimVelocity.Magnitude > 0.01 then return entry.SmoothedAimVelocity end
        if entry.LastFilteredVelocity and entry.LastFilteredVelocity.Magnitude > 0.01 then return entry.LastFilteredVelocity end
        if entry.RealVelocity and entry.RealVelocity.Magnitude > 0.01 then return entry.RealVelocity end
    end
    if part then return part.AssemblyLinearVelocity end
    return Vector3.zero
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- CORE PREDICTION
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

function PredictionCore:PredictTargetPosition(origin, part, entry)
    local C = self.C
    local P = self.Profile
    local basePos = part.Position
    local att = part:FindFirstChild("RootRigAttachment") or part:FindFirstChild("WaistCenterAttachment") or part:FindFirstChild("NeckAttachment")
    if att and att:IsA("Attachment") then basePos = att.WorldPosition end

    if not self.Options.PredictionEnabled then
        local totalOffset = self.Options.AimOffset
        -- Cá»™ng thÃªm AimOffset tá»« BossProfile
        if entry and entry.BossProfile then
            totalOffset = totalOffset + (entry.BossProfile.AimOffset or 0)
        end
        if totalOffset ~= 0 then
            basePos = basePos + Vector3.new(0, totalOffset, 0)
        end
        return basePos
    end

    local now = os.clock()

    -- PERIODIC REFRESH: Reset partial state má»—i 15 giÃ¢y Ä‘á»ƒ trÃ¡nh drift
    if not entry._lastRefreshTime then entry._lastRefreshTime = now end
    if (now - entry._lastRefreshTime) >= 15 then
        entry._lastRefreshTime = now
        entry.KalmanP = math.clamp(entry.KalmanP, 0.5, 2) -- Normalize KalmanP
        entry.Confidence = math.max(entry.Confidence, 0.7)  -- Phá»¥c há»“i confidence
        if entry.Acceleration and entry.Acceleration.Magnitude > 200 then
            entry.Acceleration = entry.Acceleration.Unit * 100 -- Giáº£m acceleration tÃ­ch lÅ©y
        end
    end

    -- BÆ¯á»šC 1: Raw Velocity
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
        dt = math.max(now - entry.LastTime, 0.001) -- Chá»‘t cháº·n dt khÃ´ng Ä‘Æ°á»£c báº±ng 0
        if dt >= 0.015 then
            local newVel = (basePos - entry.LastPos) / dt
            -- Chá»‘t cháº·n váº­n tá»‘c quÃ¡ áº£o (do teleport hoáº·c lag cá»±c náº·ng)
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

    -- BÆ¯á»šC 2: Kalman Filter (Profile-tuned Q boost)
    local velErr = (rawVel - entry.KalmanV).Magnitude
    local q = 0.15 + math.clamp(velErr / 28, 0, 2.0) + P.KalmanQBoost
    local r = 0.3
    entry.KalmanP = math.clamp(entry.KalmanP + q, 0.01, 10) -- CLAMP: trÃ¡nh drift vÃ´ háº¡n
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

    -- BÆ¯á»šC 3: Confidence (vá»›i recovery nhanh hÆ¡n cho boss fights dÃ i)
    if entry.LastExpectedPos then
        local errDist = (basePos - entry.LastExpectedPos).Magnitude
        local errPenalty = math.clamp(errDist / 8, 0, 0.3)
        -- Recovery rate tÄƒng lÃªn 0.15 (tá»« 0.1) Ä‘á»ƒ confidence khÃ´ng bá»‹ stuck á»Ÿ 0.4
        local recovery = 0.15
        entry.Confidence = math.clamp(entry.Confidence - errPenalty + recovery, 0.4, 1)
    else
        entry.Confidence = 1
    end

    -- BÆ¯á»šC 4: Acceleration (vá»›i magnitude clamp trÃ¡nh drift)
    if entry.LastFilteredVelocity then
        local rawAcc = (filtVel - entry.LastFilteredVelocity) / dt
        -- Clamp acceleration magnitude Ä‘á»ƒ trÃ¡nh tÃ­ch lÅ©y sai sá»‘
        if rawAcc.Magnitude > 500 then rawAcc = rawAcc.Unit * 500 end
        local accSmooth = (rawAcc - entry.Acceleration).Magnitude > 80 and 0.8 or 0.2
        entry.Acceleration = entry.Acceleration:Lerp(rawAcc, accSmooth)
        -- Clamp káº¿t quáº£ cuá»‘i
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

    -- BÆ¯á»šC 5: Latency Compensation
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- STRAFE ENHANCED PREDICTION
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- SELECTION TARGET POSITION (Lightweight for scanning)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- STABILIZE TARGET POSITION
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

function PredictionCore:StabilizeTargetPosition(entry, part, rawPos, deltaTime)
    local C = self.C
    if not entry or not part or not rawPos then return rawPos end

    if self.Options.AssistMode == "Silent Aim" then
        local cur = entry.StabilizedTargetPos
        if not cur then entry.StabilizedTargetPos = rawPos; return rawPos end
        local d = rawPos - cur
        local dm = d.Magnitude

        -- Láº¥y tham sá»‘ tá»« BossProfile (náº¿u cÃ³)
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
    PvPPrediction.lua â€” PvP-Specific Prediction Profile
    â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Káº¿ thá»«a PredictionCore, tuning cho Player thá»±c:
      â€¢ Kalman Q boost +0.3 (nháº¡y hÆ¡n cho human input)
      â€¢ Ping bÃ¹ 2x (player cÃ³ latency riÃªng + reconciliation)
      â€¢ Lead cap tháº¥p (player di chuyá»ƒn ngáº¯n, Ä‘á»•i hÆ°á»›ng nhiá»u)
      â€¢ Zigzag dampen máº¡nh (confidence giáº£m 45% khi Ä‘áº£o chiá»u)
      â€¢ Jump Arc prediction (dá»± Ä‘oÃ¡n cung nháº£y parabola)
]]

return function(PredictionCore)
    local PvPPrediction = setmetatable({}, { __index = PredictionCore })
    PvPPrediction.__index = PvPPrediction
    PvPPrediction.__Legacy = true

    function PvPPrediction.new(config, npcTracker)
        local self = PredictionCore.new(config, npcTracker)
        setmetatable(self, PvPPrediction)

        -- â•â•â• PVP PROFILE â•â•â•
        self.Profile = {
            KalmanQBoost      = 0.3,          -- Kalman nháº¡y hÆ¡n cho input ngÆ°á»i tháº­t
            PingMultiplier    = 2.0,          -- BÃ¹ ping gáº¥p Ä‘Ã´i (player ping + reconciliation)
            ReversalPenalty   = 0.55,         -- Zigzag penalty máº¡nh hÆ¡n
            LeadCap           = 180,          -- Lead cap tháº¥p (player di chuyá»ƒn ngáº¯n)
            JumpArcEnabled    = true,         -- Dá»± Ä‘oÃ¡n cung nháº£y parabola
            JumpGravity       = -196.2,       -- Gia tá»‘c trá»ng lá»±c chuáº©n Roblox
            JumpArcBlend      = 0.7,          -- 70% Ã¡p dá»¥ng dá»± Ä‘oÃ¡n cung nháº£y
        }

        return self
    end

    return PvPPrediction
end
]====],
    ["Modules/Utils/BossClassifier.lua"] = [====[--[[
    BossClassifier.lua â€” Auto Boss Type Detection
    â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    PhÃ¢n loáº¡i Boss thÃ nh 3 loáº¡i dá»±a trÃªn kÃ­ch thÆ°á»›c model:
      â€¢ "humanoid"     : Boss dÃ¡ng ngÆ°á»i chuáº©n (R6/R15)
      â€¢ "humanoid_mini": Boss nhá» hÆ¡n ngÆ°á»i thÆ°á»ng
      â€¢ "large"        : Boss khá»•ng lá»“ / khÃ´ng humanoid
    
    Má»—i loáº¡i cÃ³ bá»™ aim parameters riÃªng:
      â€¢ AimOffset (Y) â€” Ä‘iá»ƒm ngáº¯m tá»‘i Æ°u
      â€¢ Deadzone      â€” vÃ¹ng bá» qua rung
      â€¢ LeadScale     â€” há»‡ sá»‘ lead (nhá» = Ã­t lead)
      â€¢ TargetPart    â€” pháº§n thÃ¢n Æ°u tiÃªn aim
]]

local BossClassifier = {}

-- â•â•â• NgÆ°á»¡ng Ä‘á»ƒ phÃ¢n loáº¡i â•â•â•
local MINI_HEIGHT_MAX = 3.5    -- Model dÆ°á»›i 3.5 studs â†’ mini
local STANDARD_HEIGHT_MAX = 8  -- Model 3.5-8 studs â†’ humanoid chuáº©n
-- TrÃªn 8 studs â†’ large boss

-- â•â•â• Profiles cho tá»«ng loáº¡i Boss â•â•â•
BossClassifier.Profiles = {
    humanoid = {
        AimOffset = 0,          -- Ngáº¯m chÃ­nh xÃ¡c root/torso
        Deadzone = 1.2,         -- Deadzone chuáº©n
        LeadScale = 1.0,        -- Lead bÃ¬nh thÆ°á»ng
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.08,  -- Smoothing chuáº©n
    },
    humanoid_mini = {
        AimOffset = -0.5,       -- Ngáº¯m tháº¥p hÆ¡n (hitbox nhá», center tháº¥p)
        Deadzone = 0.5,         -- Deadzone nhá» (hitbox nhá» cáº§n chÃ­nh xÃ¡c hÆ¡n)
        LeadScale = 0.7,        -- Lead Ã­t hÆ¡n (mini boss thÆ°á»ng di chuyá»ƒn nhanh, hitbox nhá»)
        PreferredPart = "Head", -- Head thÆ°á»ng á»Ÿ trung tÃ¢m mini model
        StabilizeAlpha = 0.06,  -- MÆ°á»£t hÆ¡n (trÃ¡nh aim trÆ°á»£t khá»i hitbox nhá»)
    },
    large = {
        AimOffset = 2,          -- Ngáº¯m cao hÆ¡n (boss to, center cao)
        Deadzone = 2.5,         -- Deadzone lá»›n (hitbox lá»›n, khÃ´ng cáº§n aim chÃ­nh xÃ¡c)
        LeadScale = 1.2,        -- Lead nhiá»u hÆ¡n (boss to di chuyá»ƒn quÃ£ng dÃ i)
        PreferredPart = "HumanoidRootPart",
        StabilizeAlpha = 0.12,  -- Ãt smooth (hitbox lá»›n, tha thá»© lá»‡ch nhiá»u hÆ¡n)
    },
}

-- â•â•â• Äo chiá»u cao model â•â•â•
function BossClassifier.MeasureModelHeight(model)
    if not model or not model:IsA("Model") then return 5 end -- Máº·c Ä‘á»‹nh 5 studs
    
    local ok, result = pcall(function()
        -- DÃ¹ng GetBoundingBox náº¿u cÃ³
        local _, size = model:GetBoundingBox()
        return size.Y
    end)
    
    if ok and result then
        return result
    end
    
    -- Fallback: Ä‘o tá»« parts
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

-- â•â•â• PhÃ¢n loáº¡i Boss â•â•â•
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
        -- KhÃ´ng cÃ³ Humanoid â†’ luÃ´n coi lÃ  large
        return "large", height
    end
end

-- â•â•â• Láº¥y profile theo loáº¡i â•â•â•
function BossClassifier.GetProfile(bossType)
    return BossClassifier.Profiles[bossType] or BossClassifier.Profiles.humanoid
end

return BossClassifier
]====],
    ["Modules/Utils/BossDetector.lua"] = [====[--[[
    BossDetector.lua â€” OOP Target Classification Class
    Identifies if an NPC is a boss based on common properties (Size, Health, Height).
]]

local BossDetector = {}
BossDetector.__index = BossDetector

function BossDetector.new()
    local self = setmetatable({}, BossDetector)
    self.CheckInterval = 10
    return self
end

function BossDetector:IsBoss(model, humanoid)
    local humanoid = humanoid or (model and model:FindFirstChildOfClass("Humanoid"))
    if not humanoid then return false end
    
    -- Size-based Boss check
    local cf, size = model:GetBoundingBox()
    local boundsScale = size.X * size.Y * size.Z
    
    -- Simple thresholds:
    -- Standard NPC Vol ~ 8-15
    -- Bosses usually scale > 2x
    if boundsScale > 70 then return true end
    
    -- Health-based check
    if humanoid.MaxHealth > 500 then return true end
    
    -- DisplayName check
    if humanoid.DisplayName:lower():find("boss") or humanoid.DisplayName:lower():find("king") then
        return true
    end
    
    return false
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
        local errorMsg = "âŒ Access Denied: This script only supports Star Glitcher! (Place ID: " .. tostring(TARGET_PLACE_ID) .. ")"
        
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
    ["Modules/Utils/GarbageCollector.lua"] = [====[--[[
    GarbageCollector.lua â€” Memory & Workspace Optimization v1.0
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

function GarbageCollector:_drainQueue(destroyBudget, gcStepSize)
    local destroyed = 0
    local processed = 0
    local startTime = os.clock()

    while self._queueSize > 0 and processed < destroyBudget do
        if (os.clock() - startTime) >= self._frameBudget then
            break
        end

        local instance = self._queued[self._queueSize]
        self._queued[self._queueSize] = nil
        self._queueSize = self._queueSize - 1
        processed = processed + 1

        self._queuedMap[instance] = nil
        if instance and instance.Parent then
            if self.ResourceManager then
                self.ResourceManager:DeferCleanup(function()
                    if instance and instance.Parent then
                        instance:Destroy()
                    end
                end)
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

    return destroyed
end

function GarbageCollector:_stepCleanup()
    local now = os.clock()
    local manualBoost = now < self._manualBoostUntil
    local scanBatchSize = manualBoost and math.ceil(self._scanBatchSize * 1.35) or self._scanBatchSize
    local destroyBudget = manualBoost and math.ceil(self._destroyBudget * 1.5) or self._destroyBudget
    local gcStepSize = manualBoost and math.ceil(self._collectStepSize * 1.5) or self._collectStepSize

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
        queuedCount, scanDone = self:_processScan(scanBatchSize)
    end

    local destroyed = self:_drainQueue(destroyBudget, gcStepSize)

    if self._scanList then
        self.Status = string.format("Scanning (%d queued)", self._queueSize)
    elseif self._queueSize > 0 then
        self.Status = string.format("Cleaning (%d left)", self._queueSize)
    elseif destroyed > 0 or queuedCount > 0 or not scanDone then
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
    self._manualBoostUntil = os.clock() + 3
    if self.ResourceManager then
        self.ResourceManager:Boost(1.5)
    end
    if not self._scanList then
        self._lastClean = 0
        self:_beginScan()
    end

    local queued = 0
    local destroyed = 0
    if self._scanList then
        queued = select(1, self:_processScan(self._scanBatchSize))
    end
    destroyed = self:_drainQueue(self._destroyBudget, self._collectStepSize)

    if self.ResourceManager and self.ResourceManager:GetPendingCount() > 0 then
        self.Status = string.format(
            "Smart Cleanup (%d local / %d deferred)",
            self._queueSize,
            self.ResourceManager:GetPendingCount()
        )
    else
        self.Status = self._queueSize > 0 and string.format("Cleaning (%d left)", self._queueSize) or "Cleanup Settled"
    end
    return destroyed, queued, self._queueSize
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
    Input.lua â€” OOP User Interaction Class
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
    InputHandler.lua â€” Input Management Class
    Quáº£n lÃ½ tráº¡ng thÃ¡i chuá»™t/bÃ n phÃ­m vÃ  logic shouldAssist().
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

function LocalCharacter.new()
    local self = setmetatable({}, LocalCharacter)
    self.Player = Players.LocalPlayer
    self.Character = nil
    self.Humanoid = nil
    self.RootPart = nil
    self.PlayerGui = nil
    self.LastSpawnTime = 0
    self.RespawnGracePeriod = 1.25
    self._connections = {}
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

function LocalCharacter:Init()
    self:_refresh(self.Player and self.Player.Character or nil)

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
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return LocalCharacter
]====],
    ["Modules/Utils/Math/Kalman.lua"] = [====[--[[
    KalmanFilter.lua â€” OOP Noise Reduction Class
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
    NPCTracker.lua â€” Neural Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
    Fixes: Non-humanoid boss support and performance bottlenecks.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local NPCTracker = {}
NPCTracker.__index = NPCTracker

function NPCTracker.new(config, detector)
    local self = setmetatable({}, NPCTracker)
    self.Options = config.Options
    self.Blacklist = config.Blacklist or {"statue", "tuong", "monument", "altar", "dummy", "board", "spawn", "shop", "gui", "display", "map", "portal"}
    self._blacklistLower = {}
    self.Detector = detector
    
    self.CurrentTargetEntry = nil
    self._entries = {}
    self._folders = {"Entities", "Enemies", "Monsters", "NPCs", "Bosses"} -- Expanded folder list
    
    -- Performance: Polling Strategy
    self._lastScan = 0
    self._scanInterval = 0.1 -- Scan every 100ms instead of every frame
    self._cachedTargets = {}
    self._folderRefs = {}
    self._lastFolderRefresh = 0
    self._folderRefreshInterval = 2

    for i, keyword in ipairs(self.Blacklist) do
        self._blacklistLower[i] = string.lower(keyword)
    end
    
    return self
end

function NPCTracker:Init()
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

function NPCTracker:_IsTargetCandidate(model)
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

    -- UNIVERSAL TARGETING: Support both Humanoid vÃ  Non-Humanoid (Bosses)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    
    if not primary then return false end

    -- STATIC OBJECT FILTER: Boss boards, shops, etc.
    -- Mobs/Bosses (even custom ones) usually have unanchored root parts.
    if not humanoid and primary.Anchored and not model:FindFirstChild("Health") then
        -- Only ignore if it has no health indicators vÃ  is anchored
        return false
    end

    return true
end

function NPCTracker:GetTargets()
    local now = os.clock()
    
    if (now - self._lastScan) < self._scanInterval then
        return self._cachedTargets
    end
    
    self._lastScan = now
    local result = self._cachedTargets
    table.clear(result)
    local seenModels = {}

    if (now - self._lastFolderRefresh) >= self._folderRefreshInterval then
        self._lastFolderRefresh = now
        for i = 1, #self._folders do
            self._folderRefs[i] = Workspace:FindFirstChild(self._folders[i])
        end
    end

    local function trackModel(model)
        if not model or seenModels[model] then return end
        seenModels[model] = true
        
        local entry = self:_GetOrCreateEntry(model)
        if entry then
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
    
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    if not self:_IsTargetCandidate(model) then
        self._entries[model] = nil
        return nil
    end

    if self._entries[model] then return self._entries[model] end
    
    local hum = model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    
    if not primary then return nil end
    
    local entry = {
        Model = model,
        Humanoid = hum,
        PrimaryPart = primary,
        IsBoss = self.Detector:IsBoss(model, hum),
        Name = model.Name,
        LastPos = primary.Position,
        LastTime = os.clock()
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

    return targetPart or entry.PrimaryPart or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    table.clear(self._cachedTargets)
    self.CurrentTargetEntry = nil
end

return NPCTracker
]====],
    ["Modules/Utils/ResourceManager.lua"] = [====[local RunService = game:GetService("RunService")

local ResourceManager = {}
ResourceManager.__index = ResourceManager

local DEFAULT_FRAME_BUDGET = 0.0008
local DEFAULT_GC_STEP = 16

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

    if boosted then
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

    while self:GetPendingCount() > 0 and (os.clock() - startTime) < budget do
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
    Synapse.lua â€” Communication Signal System
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
            for i, cb in ipairs(_events[name]) do
                if cb == callback then
                    table.remove(_events[name], i)
                    break
                end
            end
        end
    }
end

function Synapse.fire(name, ...)
    if not _events[name] then return end
    for _, callback in ipairs(_events[name]) do
        task.spawn(callback, ...)
    end
end

return Synapse
]====],
    ["Modules/Visuals.lua"] = [====[--[[
    Visuals.lua â€” Visual Feedback Class
    Quáº£n lÃ½ FOV Circle, Target Dot, Highlight, vÃ  Hitmarker system.
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
    TargetHighlight.lua â€” OOP Highlight Visualization Class
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
    ["Modules/Visuals/Hitmarker.lua"] = [====[--[[
    Hitmarker.lua - OOP Hit Confirmation Class
    Logic:
    - Pending Queue: Stores shot fired timestamps and targets.
    - Match Rule: Matches damage remotes with shots within a time window.
    - State Machine: Idle -> ShotPending -> Confirmed -> Expired.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local clock = os.clock

local Hitmarker = {}
Hitmarker.__index = Hitmarker

function Hitmarker.new(synapse)
    local self = setmetatable({}, Hitmarker)
    self.Synapse = synapse
    self.ConfirmWindow = 1.0
    self.Enabled = true

    self._pendingShots = {}
    self._fadeConnection = nil
    self._fadeUntil = 0

    self.Part = nil
    self.Drawing = nil

    return self
end

function Hitmarker:Init()
    self.Line1 = Drawing.new("Line")
    self.Line2 = Drawing.new("Line")
    self.Line3 = Drawing.new("Line")
    self.Line4 = Drawing.new("Line")
    self.Lines = { self.Line1, self.Line2, self.Line3, self.Line4 }

    for _, line in ipairs(self.Lines) do
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = false
    end

    self.Synapse.on("ShotFired", function(targetId, shotTime, muzzlePos)
        if not targetId then
            return
        end

        self._pendingShots[targetId] = {
            shotTime = shotTime,
            muzzlePos = muzzlePos,
            status = "ShotPending",
        }

        task.delay(self.ConfirmWindow, function()
            local pending = self._pendingShots[targetId]
            if pending and pending.status == "ShotPending" then
                self._pendingShots[targetId] = nil
            end
        end)
    end)

    self.Synapse.on("DamageApplied", function(targetId, hitTime)
        local pending = self._pendingShots[targetId]
        if pending and pending.status == "ShotPending" then
            local timeDiff = hitTime - pending.shotTime
            if timeDiff >= 0 and timeDiff <= self.ConfirmWindow then
                pending.status = "Confirmed"
                self:Show()
                self._pendingShots[targetId] = nil
            end
        end
    end)
end

function Hitmarker:Show()
    if not self.Enabled or not self.Lines then
        return
    end

    for _, line in ipairs(self.Lines) do
        line.Visible = true
    end

    self._fadeUntil = clock() + 0.4
    if self._fadeConnection then
        return
    end

    self._fadeConnection = RunService.RenderStepped:Connect(function()
        if clock() > self._fadeUntil then
            for _, line in ipairs(self.Lines) do
                line.Visible = false
            end
            self._fadeConnection:Disconnect()
            self._fadeConnection = nil
            return
        end

        local mouse = UserInputService:GetMouseLocation()
        local x, y = mouse.X, mouse.Y
        local size = 8
        local gap = 4

        self.Line1.From = Vector2.new(x - gap, y - gap)
        self.Line1.To = Vector2.new(x - gap - size, y - gap - size)

        self.Line2.From = Vector2.new(x + gap, y - gap)
        self.Line2.To = Vector2.new(x + gap + size, y - gap - size)

        self.Line3.From = Vector2.new(x - gap, y + gap)
        self.Line3.To = Vector2.new(x - gap - size, y + gap + size)

        self.Line4.From = Vector2.new(x + gap, y + gap)
        self.Line4.To = Vector2.new(x + gap + size, y + gap + size)
    end)
end

function Hitmarker:Destroy()
    if self._fadeConnection then
        self._fadeConnection:Disconnect()
        self._fadeConnection = nil
    end
    for _, line in ipairs(self.Lines or {}) do
        pcall(function()
            line:Remove()
        end)
    end
end

return Hitmarker
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
    ["UI/Tabs/AimbotTab.lua"] = [====[--[[
    AimTab.lua - Unified Combat Control Center
    Consolidated: Assist Mode, FOV, Target Part, and Source Management.
    Replaces: AimbotTab.lua vÃ  TargetingTab.lua.
]]

return function(Window, Options, Visuals, NPCTracker)
    local Tab = Window:CreateTab("Aim", 4483362458)

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- SECTION: ASSIST MODE
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- SECTION: TARGETING PARAMETERS
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- SECTION: AIM METHODS
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- SECTION: CAMERA SETTINGS
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    -- SECTION: TARGET SOURCE
    -- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

return function(Window, Options, apocalypse)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)

    Tab:CreateSection("Universal Hijacking")

    Tab:CreateToggle({
        Name = "Apocalypse Lock (Brilliance)",
        CurrentValue = Options.ApocalypseEnabled,
        Flag = "ApocalypseFlag",
        Callback = function(Value)
            Options.ApocalypseEnabled = Value
            if apocalypse then
                apocalypse:SetState(Value)
            end
            if Value then
                Rayfield:Notify({
                    Title = "Apocalypse Active",
                    Content = "Projectiles & Beams are now parasitically locked to bosses.",
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
            if Value then
                Rayfield:Notify({
                    Title = "Bypass Active",
                    Content = "Client-side WalkSpeed is now masked from server checks.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

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
    return self
end

function Controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost)
    local Tab = Window:CreateTab("Player", 4483362458)
    local refs = self.Layout.Build(Tab, Options)

    self.StatusLoop.Start(refs, {
        noSlowdown = noSlowdown,
        noStun = noStun,
        speedMultiplier = speedMultiplier,
        gravityController = gravityController,
        floatController = floatController,
        jumpBoost = jumpBoost,
    }, self.LabelUtils)

    return Tab
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
    task.spawn(function()
        local lastSlowdownText
        local lastStunText
        local lastSpeedText
        local lastJumpText
        local lastFloatText
        local lastGravityText

        while true do
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

            task.wait(0.5)
        end
    end)
end

return StatusLoop
]====],
    ["UI/Tabs/PlayerTab.lua"] = [====[--[[
    PlayerTab.lua - Compatibility wrapper
    Job: Delegate Player tab construction to an injected controller.
]]

return function(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, controller)
    if controller and controller.Build then
        return controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost)
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

return function(Window, Options, cleaner, resourceManager)
    local Tab = Window:CreateTab("Settings", 4483362458)

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
        Name = "Auto Clean + Update",
        CurrentValue = Options.AutoUpdateEnabled == true,
        Flag = "AutoUpdateEnabledFlag",
        Callback = function(Value)
            Options.AutoUpdateEnabled = Value
        end,
    })

    Tab:CreateButton({
        Name = "Clean Memory & Debris Now",
        Callback = function()
            if cleaner then
                local destroyed, queued, pending = cleaner:Clean()
                Rayfield:Notify({
                    Title = "Cleanup Scheduled",
                    Content = string.format(
                        "Destroyed %d now, queued %d, pending %d for smoother cleanup.",
                        destroyed or 0,
                        queued or 0,
                        pending or 0
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
                _G.BossAimAssist_Cleanup(true)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Run Clean + Update Now",
        Callback = function()
            local updater = _G.BossAimAssist_Update
            if updater then
                task.spawn(updater)
            elseif _G.BossAimAssist_Cleanup then
                _G.BossAimAssist_Cleanup(true)
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

        while true do
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- LOAD ALL MODULES (Scientific Order)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local Brain          = requireModule("Modules/Core/Brain.lua")
local InputHandler   = requireModule("Modules/Utils/Input.lua")
local Tracker        = requireModule("Modules/Utils/NPCTracker.lua")
local Detector       = requireModule("Modules/Utils/BossDetector.lua")
local LocalCharacter = requireModule("Modules/Utils/LocalCharacter.lua")
local Synapse         = requireModule("Modules/Utils/Synapse.lua")
local Kalman          = requireModule("Modules/Utils/Math/Kalman.lua")
local ResourceManager = requireModule("Modules/Utils/ResourceManager.lua")

local BasePred        = requireModule("Modules/Combat/Prediction/Base.lua")
local Predictor       = requireModule("Modules/Combat/Predictor.lua")
local SilentResolver  = requireModule("Modules/Combat/Prediction/SilentResolver.lua")
local Apocalypse      = requireModule("Modules/Combat/Hijackers/Apocalypse.lua")
local GarbageCollector = requireModule("Modules/Utils/GarbageCollector.lua")
local Selector        = requireModule("Modules/Combat/TargetSelector.lua")
local Aimbot          = requireModule("Modules/Combat/Aimbot.lua")
local SilentAim       = requireModule("Modules/Combat/SilentAim.lua")

local SpeedSpoof      = requireModule("Modules/Movement/SpeedSpoof.lua")
local SpeedMultiplier = requireModule("Modules/Movement/SpeedMultiplier.lua")
local CustomSpeed     = requireModule("Modules/Movement/CustomSpeed.lua")
local GravityController = requireModule("Modules/Movement/GravityController.lua")
local FloatController = requireModule("Modules/Movement/FloatController.lua")
local JumpBoost      = requireModule("Modules/Movement/JumpBoost.lua")
local AntiSlowdown    = requireModule("Modules/Movement/AntiSlowdown.lua")
local AntiStun        = requireModule("Modules/Movement/AntiStun.lua")
local Cleaner         = requireModule("Modules/Movement/AttributeCleaner.lua")

local FOVCircle       = requireModule("Modules/Visuals/FOVCircle.lua")
local Hitmarker       = requireModule("Modules/Visuals/Hitmarker.lua")
local Highlight       = requireModule("Modules/Visuals/Highlight.lua")
local TargetDot       = requireModule("Modules/Visuals/TargetDot.lua")
local PlayerLabelUtils = requireModule("UI/Tabs/Player/LabelUtils.lua")
local PlayerLayout = requireModule("UI/Tabs/Player/Layout.lua")
local PlayerStatusLoop = requireModule("UI/Tabs/Player/StatusLoop.lua")
local PlayerController = requireModule("UI/Tabs/Player/Controller.lua")

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- INSTANTIATE (OOP Injection)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local synapse    = Synapse
local input      = InputHandler.new(Config)
local localCharacter = LocalCharacter.new()
local detector   = Detector.new()
local tracker    = Tracker.new(Config, detector)
local aimbot     = Aimbot.new(Config)
local silentResolver = SilentResolver.new(Config)
local silentAim  = SilentAim.new(Config, synapse, silentResolver) 
local playerTabController = PlayerController.new(PlayerLayout, PlayerStatusLoop, PlayerLabelUtils)
local apocalypse = Apocalypse.new(Config)
local resourceManager = ResourceManager.new(Options)
local cleaner    = GarbageCollector.new(Options, resourceManager)

local pred       = Predictor.new(Config, loadModule, Kalman)
local selector   = Selector.new(Config, tracker, pred)

local visuals = {
    fov = FOVCircle.new(Options),
    hit = Hitmarker.new(synapse),
    highlight = Highlight.new(),
    dot = TargetDot.new()
}

local movementSuite = {
    spoof = SpeedSpoof.new(Options, localCharacter),
    multi = SpeedMultiplier.new(Options, localCharacter),
    fixed = CustomSpeed.new(Options, localCharacter),
    gravity = GravityController.new(Options),
    float = FloatController.new(Options, localCharacter),
    jump = JumpBoost.new(Options, localCharacter),
    slow  = AntiSlowdown.new(Options, localCharacter),
    stun  = AntiStun.new(Options, localCharacter),
    clean = Cleaner.new(Options, localCharacter)
}

-- THE CENTRAL BRAIN (CNS)
local brain = Brain.new(Config, {
    Input = input, Tracker = tracker, Predictor = pred, Selector = selector,
    Aimbot = aimbot, SilentAim = silentAim, Visuals = visuals
}, loadModule)

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- INITIALIZE & SETUP UI
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
input:Init()
localCharacter:Init()
tracker:Init()
silentAim:Init()
apocalypse:Init()
resourceManager:Init()
cleaner:Init()
visuals.hit:Init()

for _, m in pairs(movementSuite) do if m.Init then m:Init() end end

requireModule("UI/Tabs/AimbotTab.lua")(Window, Options, {FOVCircle = visuals.fov.Drawing}, tracker)
requireModule("UI/Tabs/PredictionTab.lua")(Window, Options)
requireModule("UI/Tabs/PlayerTab.lua")(Window, Options, movementSuite.slow, movementSuite.stun, movementSuite.multi, movementSuite.gravity, movementSuite.float, movementSuite.jump, playerTabController)
requireModule("UI/Tabs/BlatantTab.lua")(Window, Options, apocalypse)
requireModule("UI/Tabs/SettingsTab.lua")(Window, Options, cleaner, resourceManager)

local loadConfigOk, loadConfigErr = RayfieldUI.SafeLoadConfiguration(Rayfield)
if not loadConfigOk then
    warn("[Config] LoadConfiguration failed, continuing with runtime defaults | Error: " .. tostring(loadConfigErr))
end
Options.TargetingMethod = Normalize.TargetingMethod(Options.TargetingMethod)

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- MAIN ORCHESTRATION LOOP (Brain Powered)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
        input, localCharacter, tracker, aimbot, silentAim, apocalypse,
        cleaner, visuals.fov, visuals.hit, visuals.highlight, visuals.dot, brain
    }
    for _, obj in pairs(movementSuite) do
        objs[#objs + 1] = obj
    end

    if resourceManager then
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
    performCleanup(true)
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
reg(RunService.Heartbeat:Connect(function()
    brain:Scan(UserInputService:GetMouseLocation(), Camera.CFrame.Position)
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

warn("âœ… [Core] Brain Orchestration v6 Active.")
