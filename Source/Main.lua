--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║     Boss Aim Assist — Modular OOP Loader v3 (Main.lua)       ║
    ║                                                               ║
    ║  PERF FIXES:                                                  ║
    ║    • Target scan on Heartbeat (throttled, off render thread)  ║
    ║    • Prediction only for current target on RenderStepped      ║
    ║    • NPC/PvP prediction auto-dispatched (zero branch)         ║
    ║    • Reusable brain context table (zero alloc per frame)      ║
    ║    • Stable origin from HumanoidRootPart (no camera dependency)║
    ╚═══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════
local USE_GITHUB = true
local GITHUB_CONFIG = {
    User = "Ahlstarr-Mayjishan",
    Repo = "Scripting-Roblox-",
    Branch = "main",
    Folder = "Source"
}

-- ═══════════════════════════════════════════════════
-- MODULE LOADER (GitHub Optimized)
-- ═══════════════════════════════════════════════════
local GITHUB_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s/",
    GITHUB_CONFIG.User,
    GITHUB_CONFIG.Repo,
    GITHUB_CONFIG.Branch,
    GITHUB_CONFIG.Folder:gsub(" ", "%%20")
)

local function loadModule(path)
    if USE_GITHUB then
        local url = GITHUB_BASE .. path
        local ok, res = pcall(function()
            local content = game:HttpGet(url)
            if content == "404: Not Found" then error("File not found on GitHub") end
            return loadstring(content)()
        end)

        if ok then
            return res
        end

        warn("⚠️ [Loader] Load thất bại: " .. path)
        warn("   Lỗi: " .. tostring(res))
        warn("   URL: " .. url)
        return nil
    else
        local ok, res = pcall(function()
            return loadstring(readfile(path))()
        end)
        if ok then return res end
        warn("❌ [Loader] Local load failed: " .. path .. " — " .. tostring(res))
        return nil
    end
end

-- ═══════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════
-- LOAD RAYFIELD
-- ═══════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ═══════════════════════════════════════════════════
-- LOAD MODULES
-- ═══════════════════════════════════════════════════
local Config           = loadModule("Modules/Config.lua")
local InputHandler     = loadModule("Modules/InputHandler.lua")
local Visuals          = loadModule("Modules/Visuals.lua")
local NPCTracker       = loadModule("Modules/NPCTracker.lua")
local PredictionCore   = loadModule("Modules/PredictionCore.lua")
local NPCPrediction    = loadModule("Modules/NPCPrediction.lua")
local PvPPrediction    = loadModule("Modules/PvPPrediction.lua")
local TargetSelector   = loadModule("Modules/TargetSelector.lua")
local SilentAim        = loadModule("Modules/SilentAim.lua")
local NoSlowdownModule = loadModule("Modules/NoSlowdown.lua")
local BossClassifier   = loadModule("Modules/BossClassifier.lua")

-- Tab Modules
local AimbotTab      = loadModule("Tabs/AimbotTab.lua")
local AdjustmentsTab = loadModule("Tabs/AdjustmentsTab.lua")
local PlayerTab      = loadModule("Tabs/PlayerTab.lua")
local MiscTab        = loadModule("Tabs/MiscTab.lua")
local SettingsTab    = loadModule("Tabs/SettingsTab.lua")

-- ═══════════════════════════════════════════════════
-- BUILD NPC/PVP PREDICTION CLASSES FROM CORE
-- ═══════════════════════════════════════════════════
local NPCPredClass = NPCPrediction(PredictionCore)
local PvPPredClass = PvPPrediction(PredictionCore)

-- ═══════════════════════════════════════════════════
-- INSTANTIATE OBJECTS
-- ═══════════════════════════════════════════════════
local Options = Config.Options

local input      = InputHandler.new(Config)
local visuals    = Visuals.new(Config)
local tracker    = NPCTracker.new(Config, BossClassifier)
local npcPred    = NPCPredClass.new(Config, tracker)
local pvpPred    = PvPPredClass.new(Config, tracker)
local selector   = TargetSelector.new(Config, tracker, npcPred)
local silentAim  = SilentAim.new(Config, visuals)
local noSlowdown = NoSlowdownModule.new(Config)

-- ═══════════════════════════════════════════════════
-- INITIALIZE
-- ═══════════════════════════════════════════════════
input:Init()
tracker:Init()
silentAim:Init()
noSlowdown:Init()

-- ═══════════════════════════════════════════════════
-- RAYFIELD UI
-- ═══════════════════════════════════════════════════
Rayfield:LoadConfiguration()

local Window = Rayfield:CreateWindow({
    Name = "Boss Aim Assist",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Client-side boss assist",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Boss_AimAssist",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

AimbotTab(Window, Options, visuals)
AdjustmentsTab(Window, Options)
PlayerTab(Window, Options, noSlowdown)
MiscTab(Window, Options, tracker)
SettingsTab(Window, Options)

Rayfield:LoadConfiguration()

-- ═══════════════════════════════════════════════════
-- STABLE ORIGIN — Luôn dùng vị trí nhân vật
-- Không bao giờ phụ thuộc vào Camera.CFrame.Position
-- ═══════════════════════════════════════════════════
local function getShooterOrigin()
    local camPos = Camera.CFrame.Position
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    if rootPart then
        local charPos = rootPart.Position
        -- Camera trong khoảng hợp lệ → dùng Camera (chính xác cho 3rd person)
        -- Camera bị hỏng/văng quá xa → fallback về character position
        if (camPos - charPos).Magnitude < 200 then
            return camPos
        end
        return charPos
    end

    return camPos
end

-- Validate vị trí (không NaN, không Infinite)
local function isValidPosition(v)
    return v.X == v.X and v.Y == v.Y and v.Z == v.Z
        and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

-- ═══════════════════════════════════════════════════
-- HEALTH TRACKING
-- ═══════════════════════════════════════════════════
local CurrentHitHumanoid = nil
local LastHealthValue = 0
local TargetHealthConnection = nil

-- ═══════════════════════════════════════════════════
-- AUTO-DISPATCH: Chọn predictor phù hợp cho entry
-- ═══════════════════════════════════════════════════
local function getPredictor(entry)
    if entry and tracker:IsTargetPlayer(entry) then
        return pvpPred
    end
    return npcPred
end

-- ═══════════════════════════════════════════════════
-- PERF: Target scan trên Heartbeat (throttled)
-- ═══════════════════════════════════════════════════
local _scanFrame = 0
local SCAN_INTERVAL = 2
local _cachedMousePos = Vector2.new(0, 0)

RunService.Heartbeat:Connect(function()
    _scanFrame = _scanFrame + 1
    _cachedMousePos = UserInputService:GetMouseLocation()

    if _scanFrame >= SCAN_INTERVAL then
        _scanFrame = 0

        if input:ShouldAssist() then
            tracker.CurrentTargetEntry = selector:GetClosestTarget(_cachedMousePos, getShooterOrigin())
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- MAIN RENDER LOOP (Silent Aim + Highlight Only)
-- Không can thiệp Camera — game không phải FPS
-- ═══════════════════════════════════════════════════
RunService.RenderStepped:Connect(function(deltaTime)
    local mousePos = _cachedMousePos

    -- FOV Circle
    visuals:UpdateFOV(mousePos)
    visuals:SetTargetDot(nil, false)

    if not input:ShouldAssist() then
        tracker.CurrentTargetEntry = nil
        silentAim:Clear()
        visuals:ClearHighlight()
        if TargetHealthConnection then
            TargetHealthConnection:Disconnect()
            TargetHealthConnection = nil
        end
        CurrentHitHumanoid = nil
        return
    end

    local entry = tracker.CurrentTargetEntry
    if not entry then
        silentAim:Clear()
        visuals:ClearHighlight()
        CurrentHitHumanoid = nil
        return
    end

    local targetPart = tracker:GetTargetPart(entry)
    if not targetPart then
        tracker.CurrentTargetEntry = nil
        silentAim:Clear()
        visuals:ClearHighlight()
        CurrentHitHumanoid = nil
        return
    end

    -- Auto-dispatch: NPC hay PvP predictor
    local pred = getPredictor(entry)

    -- Dùng vị trí nhân vật ổn định thay vì camera
    local shooterOrigin = getShooterOrigin()

    -- Predict & stabilize
    local targetPosition = pred:PredictWithStrafe(shooterOrigin, targetPart, entry)
    targetPosition = pred:StabilizeTargetPosition(entry, targetPart, targetPosition, deltaTime)

    -- Safety: nếu prediction trả về dữ liệu hỏng → reset state
    if not isValidPosition(targetPosition) then
        entry.LastPos = nil
        entry.LastTime = nil
        entry.KalmanV = Vector3.zero
        entry.KalmanP = 1
        entry.Confidence = 1
        entry.Acceleration = Vector3.zero
        entry.LastFilteredVelocity = nil
        entry.SmoothedAimVelocity = nil
        return
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPosition)
    if onScreen then
        visuals:SetTargetDot(screenPos, true)
    end

    -- Silent Aim state
    silentAim:SetState(false, targetPart, targetPosition, entry)

    if Options.AssistMode == "Silent Aim" then
        silentAim.Active = true
        visuals:SetHighlight(targetPart, true)
    elseif Options.AssistMode == "Highlight Only" then
        visuals:SetHighlight(targetPart, true)
    else
        visuals:ClearHighlight()
    end

    -- Health tracking → Hitmarker
    local humanoid = entry.Humanoid
    if humanoid and humanoid ~= CurrentHitHumanoid then
        if TargetHealthConnection then
            TargetHealthConnection:Disconnect()
        end
        local trackedEntry = entry
        CurrentHitHumanoid = humanoid
        LastHealthValue = humanoid.Health
        TargetHealthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            local hp = humanoid.Health
            if hp < LastHealthValue then
                if input:WasShotRecently(1.5) then
                    task.spawn(function() visuals:ShowHitmarker() end)
                end
                pred:RegisterHitFeedback(trackedEntry, silentAim.TargetPosCache)
            end
            LastHealthValue = hp
        end)
    elseif humanoid then
        local hp = humanoid.Health
        if hp > LastHealthValue then LastHealthValue = hp end
    end
end)
