--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║     Boss Aim Assist — Modular OOP Loader v2 (Main.lua)       ║
    ║                                                               ║
    ║  PERF FIXES:                                                  ║
    ║    • Target scan on Heartbeat (throttled, off render thread)  ║
    ║    • Prediction only for current target on RenderStepped      ║
    ║    • NPC/PvP prediction auto-dispatched (zero branch)         ║
    ║    • Reusable brain context table (zero alloc per frame)      ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════
local USE_GITHUB = true -- Bật chế độ GitHub
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
local NPCPrediction    = loadModule("Modules/NPCPrediction.lua")  -- returns factory fn
local PvPPrediction    = loadModule("Modules/PvPPrediction.lua")  -- returns factory fn
local TargetSelector   = loadModule("Modules/TargetSelector.lua")
local SilentAim        = loadModule("Modules/SilentAim.lua")

-- Tab Modules
local AimbotTab      = loadModule("Tabs/AimbotTab.lua")
local AdjustmentsTab = loadModule("Tabs/AdjustmentsTab.lua")
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
local tracker    = NPCTracker.new(Config)
local npcPred    = NPCPredClass.new(Config, tracker)     -- Predictor cho NPC/Boss
local pvpPred    = PvPPredClass.new(Config, tracker)     -- Predictor cho Player
local selector   = TargetSelector.new(Config, tracker, npcPred) -- selector dùng npcPred cho scanning
local silentAim  = SilentAim.new(Config, visuals)

-- ═══════════════════════════════════════════════════
-- INITIALIZE
-- ═══════════════════════════════════════════════════
input:Init()
tracker:Init()
silentAim:Init()

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
MiscTab(Window, Options, tracker)
SettingsTab(Window, Options)

Rayfield:LoadConfiguration()

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
-- Heartbeat chạy SAU physics, TRƯỚC render.
-- Quét mục tiêu ở đây giúp giải phóng RenderStepped.
-- ═══════════════════════════════════════════════════
local _scanFrame = 0
local SCAN_INTERVAL = 2 -- Quét mỗi 2 frame (giảm 50% CPU cho scanning)
local _cachedMousePos = Vector2.new(0, 0)

RunService.Heartbeat:Connect(function()
    _scanFrame = _scanFrame + 1
    _cachedMousePos = UserInputService:GetMouseLocation()

    if _scanFrame >= SCAN_INTERVAL then
        _scanFrame = 0

        if input:ShouldAssist() then
            tracker.CurrentTargetEntry = selector:GetClosestTarget(_cachedMousePos, Camera.CFrame.Position)
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- MAIN RENDER LOOP (chỉ predict + visual cho 1 target)
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

    -- Predict & stabilize
    local targetPosition = pred:PredictWithStrafe(Camera.CFrame.Position, targetPart, entry)
    targetPosition = pred:StabilizeTargetPosition(entry, targetPart, targetPosition, deltaTime)

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

    -- ═══════════════════════════════════════════════════
    -- CAMERA LOCK SAFETY CHECK
    -- ═══════════════════════════════════════════════════
    if Options.AssistMode ~= "Camera Lock" then return end

    -- Kiểm tra vị trí có hợp lệ không (tránh NaN/Infinite khiến camera văng)
    local function isValid(v)
        return v.X == v.X and v.Y == v.Y and v.Z == v.Z -- NaN check
            and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6 -- Infinite check
    end

    if not isValid(targetPosition) then return end

    local camPos = Camera.CFrame.Position
    -- Đảm bảo khoảng cách không quá gần (tránh lỗi lookAt trùng vị trí)
    if (targetPosition - camPos).Magnitude < 0.1 then return end

    local desired = CFrame.lookAt(camPos, targetPosition)
    local alpha = 1 - math.pow(1 - math.clamp(Options.Smoothness, 0, 0.99), math.max(deltaTime * 60, 1))
    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
end)
