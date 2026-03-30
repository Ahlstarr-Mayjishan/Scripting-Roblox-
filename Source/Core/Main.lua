--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║     Boss Aim Assist — Scientific OOP Orchestrator v5          ║
    ║  Reorganized Hierarchy | Fully Decoupled | Zero Debt          ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local USE_GITHUB = true
local GITHUB_CONFIG = {
    User = "Ahlstarr-Mayjishan",
    Repo = "Scripting-Roblox-",
    Branch = "main",
    Folder = "Source"
}

local GITHUB_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s/",
    GITHUB_CONFIG.User,
    GITHUB_CONFIG.Repo,
    GITHUB_CONFIG.Branch,
    GITHUB_CONFIG.Folder:gsub(" ", "%%20")
)

local function loadModule(path)
    local url = GITHUB_BASE .. path
    local ok, res = pcall(function()
        local content = game:HttpGet(url)
        if content == "404: Not Found" then error("404: "..path) end
        return loadstring(content)()
    end)
    if ok then return res end
    warn("⚠️ [Loader] Failed: " .. path .. " | Error: " .. tostring(res))
    return nil
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
-- CORE DATA
-- ═══════════════════════════════════════════════════
local Config  = loadModule("Data/Config.lua")
local Version = loadModule("Data/Version.lua")
local Options = Config.Options

-- ═══════════════════════════════════════════════════
-- UI INITIALIZATION
-- ═══════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().Rayfield = Rayfield

local Window = Rayfield:CreateWindow({
    Name = "Boss Aim Assist v"..tostring(Version),
    LoadingTitle = "Initializing Core...",
    LoadingSubtitle = "Scientific Reorganization Active",
    ConfigurationSaving = { Enabled = true, FolderName = "Boss_AimAssist", FileName = "Config" },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ═══════════════════════════════════════════════════
-- LOAD OOP MODULES (Scientific Hierarchy)
-- ═══════════════════════════════════════════════════
-- Utils
local InputHandler   = loadModule("Modules/Utils/Input.lua")
local Tracker        = loadModule("Modules/Utils/NPCTracker.lua")
local DetectorClass  = loadModule("Modules/Utils/BossDetector.lua")
local MathKalman     = loadModule("Modules/Utils/Math/Kalman.lua")

-- Combat
local Aimbot         = loadModule("Modules/Combat/Aimbot.lua")
local SilentAim      = loadModule("Modules/Combat/SilentAim.lua")
local Selector       = loadModule("Modules/Combat/TargetSelector.lua")
local BasePred       = loadModule("Modules/Combat/Prediction/Base.lua")
local Predictor      = loadModule("Modules/Combat/Predictor.lua")

-- Movement
local SpeedSpoof      = loadModule("Modules/Movement/SpeedSpoof.lua")
local SpeedMultiplier = loadModule("Modules/Movement/SpeedMultiplier.lua")
local AntiSlowdown    = loadModule("Modules/Movement/AntiSlowdown.lua")
local AntiStun        = loadModule("Modules/Movement/AntiStun.lua")
local AttributeCleaner = loadModule("Modules/Movement/AttributeCleaner.lua")

-- Visuals
local FOVCircle      = loadModule("Modules/Visuals/FOVCircle.lua")
local Hitmarker      = loadModule("Modules/Visuals/Hitmarker.lua")
local Highlight      = loadModule("Modules/Visuals/Highlight.lua")
local TargetDot      = loadModule("Modules/Visuals/TargetDot.lua")

-- ═══════════════════════════════════════════════════
-- INSTANTIATE OBJECTS (OOP STYLE)
-- ═══════════════════════════════════════════════════
local input      = InputHandler.new(Config)
local detector   = DetectorClass.new()
local tracker    = Tracker.new(Config, detector)
local aimbot     = Aimbot.new(Config)
local silentAim  = SilentAim.new(Config, nil) 

-- Prediction Engine
local predictor  = Predictor.new(Config, BasePred, MathKalman)
local selector   = Selector.new(Config, tracker, predictor)

-- Movement Suite
local movementSuite = {
    spoof = SpeedSpoof.new(Options),
    multi = SpeedMultiplier.new(Options),
    slow  = AntiSlowdown.new(Options),
    stun  = AntiStun.new(Options),
    clean = AttributeCleaner.new(Options)
}

-- Visuals
local fov        = FOVCircle.new(Options)
local hitmarker  = Hitmarker.new()
local highlight  = Highlight.new()
local targetDot  = TargetDot.new()

-- Inject dependencies
silentAim.Visuals = { ShowHitmarker = function() hitmarker:Show() end }

-- ═══════════════════════════════════════════════════
-- INITIALIZE MODULES
-- ═══════════════════════════════════════════════════
input:Init()
tracker:Init()
silentAim:Init()

for _, module in pairs(movementSuite) do
    if module.Init then module:Init() end
end

-- ═══════════════════════════════════════════════════
-- UI TABS
-- ═══════════════════════════════════════════════════
loadModule("UI/Tabs/AimbotTab.lua")(Window, Options, {FOVCircle = fov.Drawing}) 
loadModule("UI/Tabs/AdjustmentsTab.lua")(Window, Options)
loadModule("UI/Tabs/BlatantTab.lua")(Window, Options)
loadModule("UI/Tabs/PlayerTab.lua")(Window, Options, nil) -- Passing nil for now as tabs are mostly static
loadModule("UI/Tabs/MiscTab.lua")(Window, Options, tracker)
loadModule("UI/Tabs/SettingsTab.lua")(Window, Options)

Rayfield:LoadConfiguration()

-- ═══════════════════════════════════════════════════
-- SESSION & CLEANUP
-- ═══════════════════════════════════════════════════
local SESSION_ID = os.time()
if _G.BossAimAssist_Cleanup then _G.BossAimAssist_Cleanup() end
_G.BossAimAssist_SessionID = SESSION_ID

local _conns = {}
local function reg(c) table.insert(_conns, c) end

_G.BossAimAssist_Cleanup = function()
    pcall(function() Rayfield:Destroy() end)
    for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    
    local objs = {input, tracker, aimbot, silentAim, fov, hitmarker, highlight, targetDot}
    for _, o in pairs(movementSuite) do table.insert(objs, o) end
    for _, o in ipairs(objs) do if o.Destroy then pcall(function() o:Destroy() end) end end
    
    _G.BossAimAssist_Cleanup = nil
end

-- ═══════════════════════════════════════════════════
-- MAIN ORCHESTRATION LOOP
-- ═══════════════════════════════════════════════════
local _scanFrame = 0
local SCAN_INTERVAL = 2
local _mousePos = Vector2.new(0,0)

-- Heartbeat: Scanning (Off render thread)
reg(RunService.Heartbeat:Connect(function()
    _scanFrame = _scanFrame + 1
    _mousePos = UserInputService:GetMouseLocation()
    if _scanFrame >= SCAN_INTERVAL then
        _scanFrame = 0
        if input:ShouldAssist() then
            tracker.CurrentTargetEntry = selector:GetClosestTarget(_mousePos, Camera.CFrame.Position)
        end
    end
end))

-- RenderStepped: Visuals & Locked Aim
reg(RunService.RenderStepped:Connect(function(dt)
    fov:Update(_mousePos)
    targetDot:Set(nil, false)
    
    local entry = tracker.CurrentTargetEntry
    if not input:ShouldAssist() or not entry then
        silentAim:Clear()
        highlight:Clear()
        return
    end

    local part = tracker:GetTargetPart(entry)
    if not part then return end

    -- Calculation
    local targetPos = predictor:Predict(Camera.CFrame.Position, part, entry, dt)
    
    -- Visual Feedback
    local sPos, onScreen = Camera:WorldToViewportPoint(targetPos)
    targetDot:Set(sPos, onScreen)
    highlight:Set(part, true)

    -- Action Dispatch
    if Options.AssistMode == "Camera Lock" then
        silentAim:Clear()
        aimbot:Update(targetPos, Options.Smoothness)
    elseif Options.AssistMode == "Silent Aim" then
        silentAim:SetState(true, part, targetPos, entry, dt)
    elseif Options.AssistMode == "Highlight Only" then
        silentAim:Clear()
    else
        silentAim:Clear()
        highlight:Clear()
    end
end))

warn("✅ [Core] Scientific OOP Reorganization v5 Active.")
