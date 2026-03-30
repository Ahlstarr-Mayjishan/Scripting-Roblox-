--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║     Boss Aim Assist — Centralized Brain Orchestration v6       ║
    ║  Scientifically Reorganized | Fully Decoupled | Brain Driven  ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local USE_GITHUB = true
local GITHUB_CONFIG = {
    User = "Ahlstarr-Mayjishan",
    Repo = "Scripting-Roblox-",
    Branch = "main",
    Folder = "Source"
}

local GITHUB_BASE = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s/", GITHUB_CONFIG.User, GITHUB_CONFIG.Repo, GITHUB_CONFIG.Branch, GITHUB_CONFIG.Folder:gsub(" ", "%%20"))

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

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Core Data
local Config  = loadModule("Data/Config.lua")
local Version = loadModule("Data/Version.lua")
local Options = Config.Options

-- UI initialization
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().Rayfield = Rayfield

local Window = Rayfield:CreateWindow({
    Name = "Boss Aim Assist v"..tostring(Version),
    LoadingTitle = "Awakening Brain...",
    LoadingSubtitle = "Scientific Neural Network Active",
    ConfigurationSaving = { Enabled = true, FolderName = "Boss_AimAssist", FileName = "Config" },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ═══════════════════════════════════════════════════
-- LOAD ALL MODULES (Scientific Order)
-- ═══════════════════════════════════════════════════
local Brain          = loadModule("Modules/Core/Brain.lua")
local InputHandler   = loadModule("Modules/Utils/Input.lua")
local Tracker        = loadModule("Modules/Utils/NPCTracker.lua")
local Detector       = loadModule("Modules/Utils/BossDetector.lua")
local Kalman         = loadModule("Modules/Utils/Math/Kalman.lua")

local BasePred       = loadModule("Modules/Combat/Prediction/Base.lua")
local Predictor      = loadModule("Modules/Combat/Predictor.lua")
local Selector       = loadModule("Modules/Combat/TargetSelector.lua")
local Aimbot         = loadModule("Modules/Combat/Aimbot.lua")
local SilentAim      = loadModule("Modules/Combat/SilentAim.lua")

local SpeedSpoof      = loadModule("Modules/Movement/SpeedSpoof.lua")
local SpeedMultiplier = loadModule("Modules/Movement/SpeedMultiplier.lua")
local AntiSlowdown    = loadModule("Modules/Movement/AntiSlowdown.lua")
local AntiStun        = loadModule("Modules/Movement/AntiStun.lua")
local Cleaner         = loadModule("Modules/Movement/AttributeCleaner.lua")

local FOVCircle      = loadModule("Modules/Visuals/FOVCircle.lua")
local Hitmarker      = loadModule("Modules/Visuals/Hitmarker.lua")
local Highlight      = loadModule("Modules/Visuals/Highlight.lua")
local TargetDot      = loadModule("Modules/Visuals/TargetDot.lua")

-- ═══════════════════════════════════════════════════
-- INSTANTIATE (OOP Injection)
-- ═══════════════════════════════════════════════════
local input      = InputHandler.new(Config)
local detector   = Detector.new()
local tracker    = Tracker.new(Config, detector)
local aimbot     = Aimbot.new(Config)
local silentAim  = SilentAim.new(Config, nil) 

local pred       = Predictor.new(Config, BasePred, Kalman)
local selector   = Selector.new(Config, tracker, pred)

local visuals = {
    fov = FOVCircle.new(Options),
    hit = Hitmarker.new(),
    highlight = Highlight.new(),
    dot = TargetDot.new()
}

local movementSuite = {
    spoof = SpeedSpoof.new(Options),
    multi = SpeedMultiplier.new(Options),
    slow  = AntiSlowdown.new(Options),
    stun  = AntiStun.new(Options),
    clean = Cleaner.new(Options)
}

-- THE CENTRAL BRAIN
local brain = Brain.new(Config, {
    Input = input, Tracker = tracker, Predictor = pred, Selector = selector,
    Aimbot = aimbot, SilentAim = silentAim, Visuals = visuals
})

-- ═══════════════════════════════════════════════════
-- INITIALIZE & SETUP UI
-- ═══════════════════════════════════════════════════
input:Init()
tracker:Init()
silentAim:Init()
silentAim.Visuals = { ShowHitmarker = function() visuals.hit:Show() end }

for _, m in pairs(movementSuite) do if m.Init then m:Init() end end

loadModule("UI/Tabs/AimbotTab.lua")(Window, Options, {FOVCircle = visuals.fov.Drawing}) 
loadModule("UI/Tabs/AdjustmentsTab.lua")(Window, Options)
loadModule("UI/Tabs/BlatantTab.lua")(Window, Options)
loadModule("UI/Tabs/PlayerTab.lua")(Window, Options, nil)
loadModule("UI/Tabs/MiscTab.lua")(Window, Options, tracker)
loadModule("UI/Tabs/SettingsTab.lua")(Window, Options)

Rayfield:LoadConfiguration()

-- ═══════════════════════════════════════════════════
-- MAIN ORCHESTRATION LOOP (Brain Powered)
-- ═══════════════════════════════════════════════════
local SESSION_ID = os.time()
if _G.BossAimAssist_Cleanup then _G.BossAimAssist_Cleanup() end
_G.BossAimAssist_SessionID = SESSION_ID

local _conns = {}
local function reg(c) table.insert(_conns, c) end

_G.BossAimAssist_Cleanup = function()
    pcall(function() Rayfield:Destroy() end)
    for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
    local objs = {input, tracker, aimbot, silentAim, visuals.fov, visuals.hit, visuals.highlight, visuals.dot, brain}
    for _, o in pairs(movementSuite) do table.insert(objs, o) end
    for _, o in ipairs(objs) do if o.Destroy then pcall(function() o:Destroy() end) end end
    _G.BossAimAssist_Cleanup = nil
end

-- Scanning (Heartbeat, Off render)
reg(RunService.Heartbeat:Connect(function()
    brain:Scan(UserInputService:GetMouseLocation(), Camera.CFrame.Position)
end))

-- Execution (RenderStepped)
reg(RunService.RenderStepped:Connect(function(dt)
    brain:Update(dt, UserInputService:GetMouseLocation(), Camera.CFrame)
end))

warn("✅ [Core] Brain Orchestration v6 Active.")
