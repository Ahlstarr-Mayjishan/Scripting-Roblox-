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
getgenv().Rayfield = Rayfield

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
local BlatantTab     = loadModule("Tabs/BlatantTab.lua")

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
BlatantTab(Window, Options, visuals)
PlayerTab(Window, Options, noSlowdown)
MiscTab(Window, Options, tracker)
SettingsTab(Window, Options)

Rayfield:LoadConfiguration()

-- ═══════════════════════════════════════════════════
-- MULTI-INSTANCE PROTECTION
-- ═══════════════════════════════════════════════════
local SESSION_ID = os.time()
if _G.BossAimAssist_Cleanup then
    warn("⚠️ [Main] Đang xóa phiên làm việc cũ...")
    _G.BossAimAssist_Cleanup()
end
_G.BossAimAssist_SessionID = SESSION_ID

-- ═══════════════════════════════════════════════════
-- CLEANUP SYSTEM
-- ═══════════════════════════════════════════════════
local _allConnections = {}
local TargetHealthConnection = nil
local function registerConn(conn) table.insert(_allConnections, conn) end

_G.BossAimAssist_Cleanup = function()
    warn("🔥 [Main] Khởi động tiến trình tự hủy...")
    
    -- Xóa UI
    pcall(function() Rayfield:Destroy() end)
    
    -- Disconnect signals
    for _, conn in ipairs(_allConnections) do
        if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
    end
    table.clear(_allConnections)

    -- Destroy objects
    local objs = {input, visuals, tracker, silentAim, noSlowdown}
    for _, obj in ipairs(objs) do
        if obj and obj.Destroy then pcall(function() obj:Destroy() end) end
    end

    if TargetHealthConnection then pcall(function() TargetHealthConnection:Disconnect() end) end
    
    _G.BossAimAssist_Cleanup = nil
    _G.BossAimAssist_Loaded = nil
    warn("✅ [Main] Đã ngừng mọi tiến trình.")
end

-- ═══════════════════════════════════════════════════
-- VERSION & UPDATE CHECKER
-- ═══════════════════════════════════════════════════
local CURRENT_VERSION = loadModule("Modules/Version.lua") or 0
warn("🚀 [Main] Phiên bản hiện tại: " .. tostring(CURRENT_VERSION))

local function checkForUpdates()
    while _G.BossAimAssist_SessionID == SESSION_ID do
        task.wait(45) -- Kiểm tra mỗi 45 giây
        
        local success, latestVer = pcall(function()
            local url = GITHUB_BASE .. "Modules/Version.lua"
            return loadstring(game:HttpGet(url))()
        end)

        if success and latestVer and latestVer > CURRENT_VERSION then
            warn("✨ [Main] Phát hiện phiên bản mới: " .. tostring(latestVer))
            warn("   Đang tự động cập nhật...")
            
            _G.BossAimAssist_Cleanup()
            
            task.wait(1)
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/Source/Main.lua"))()
            break
        end
    end
end
task.spawn(checkForUpdates)

-- ═══════════════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════════════
local function getShooterOrigin()
    local camPos = Camera.CFrame.Position
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    if rootPart then
        local charPos = rootPart.Position
        local offset = camPos - charPos
        if (offset.X*offset.X + offset.Y*offset.Y + offset.Z*offset.Z) < 40000 then
            return camPos
        end
        return charPos
    end
    return camPos
end

local function isValidPosition(v)
    return v.X == v.X and v.Y == v.Y and v.Z == v.Z
        and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function getPredictor(entry)
    if entry and tracker:IsTargetPlayer(entry) then
        return pvpPred
    end
    return npcPred
end

-- ═══════════════════════════════════════════════════
-- HEALTH TRACKING
-- ═══════════════════════════════════════════════════
local CurrentHitHumanoid = nil
local LastHealthValue = 0

-- ═══════════════════════════════════════════════════
-- PERF: Target scan trên Heartbeat (throttled)
-- ═══════════════════════════════════════════════════
local _scanFrame = 0
local SCAN_INTERVAL = 2
local _cachedMousePos = Vector2.new(0, 0)

registerConn(RunService.Heartbeat:Connect(function()
    _scanFrame = _scanFrame + 1
    _cachedMousePos = UserInputService:GetMouseLocation()

    if _scanFrame >= SCAN_INTERVAL then
        _scanFrame = 0

        -- 🎯 Target Scanning
        if input:ShouldAssist() then
            tracker.CurrentTargetEntry = selector:GetClosestTarget(_cachedMousePos, getShooterOrigin())
        end
    end
end))

-- ═══════════════════════════════════════════════════
-- MAIN RENDER LOOP (Silent Aim + Highlight Only)
-- ═══════════════════════════════════════════════════
registerConn(RunService.RenderStepped:Connect(function(deltaTime)
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

    -- State management
    if Options.AssistMode == "Camera Lock" then
        silentAim:Clear()
        visuals:SetHighlight(targetPart, true)
        
        -- 🔥 CAMERA LOCK (AIMBOT)
        -- Vì game không có Anti-Cheat Camera, chúng ta có thể Lerp CFrame trực tiếp
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPosition)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Options.Smoothness)
        
    elseif Options.AssistMode == "Silent Aim" then
        silentAim:SetState(true, targetPart, targetPosition, entry, deltaTime)
        visuals:SetHighlight(targetPart, true)
    elseif Options.AssistMode == "Highlight Only" then
        silentAim:Clear()
        visuals:SetHighlight(targetPart, true)
    else
        silentAim:Clear()
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
end))

