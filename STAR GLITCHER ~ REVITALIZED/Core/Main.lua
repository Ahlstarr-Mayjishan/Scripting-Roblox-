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
    Folder = "STAR GLITCHER ~ REVITALIZED"
}

local GITHUB_BASE = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s/", GITHUB_CONFIG.User, GITHUB_CONFIG.Repo, GITHUB_CONFIG.Branch, GITHUB_CONFIG.Folder:gsub(" ", "%%20"):gsub("~", "%%7E"))

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
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera

-- Core Data
local Config  = loadModule("Data/Config.lua")
local Version = loadModule("Data/Version.lua")
local Options = Config.Options

local function resolveToggleUIKeyCode(value)
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

local function normalizeToggleUIKey(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value.Name
    end

    if type(value) == "string" and Enum.KeyCode[value] then
        return value
    end

    return "RightControl"
end

-- UI initialization
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().Rayfield = Rayfield

Options.ToggleUIKey = normalizeToggleUIKey(Options.ToggleUIKey)

local Window = Rayfield:CreateWindow({
    Name = "STAR GLITCHER ~ REVITALIZED",
    LoadingTitle = "Neural Interface Initializing...",
    LoadingSubtitle = "Scientific Neural Network Active",
    ConfigurationSaving = { Enabled = true, FolderName = "Boss_AimAssist", FileName = "Config" },
    Discord = { Enabled = false },
    KeySystem = false,
})

local function isRayfieldScreenGui(screenGui)
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

local function getRayfieldScreenGuis()
    local matches = {}
    local seen = {}
    local containers = {CoreGui}

    local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(containers, playerGui)
    end

    for _, container in ipairs(containers) do
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("ScreenGui") and not seen[descendant] and isRayfieldScreenGui(descendant) then
                seen[descendant] = true
                matches[#matches + 1] = descendant
            end
        end
    end

    return matches
end

-- ═══════════════════════════════════════════════════
-- LOAD ALL MODULES (Scientific Order)
-- ═══════════════════════════════════════════════════
local Brain          = loadModule("Modules/Core/Brain.lua")
local InputHandler   = loadModule("Modules/Utils/Input.lua")
local Tracker        = loadModule("Modules/Utils/NPCTracker.lua")
local Detector       = loadModule("Modules/Utils/BossDetector.lua")
local LocalCharacter = loadModule("Modules/Utils/LocalCharacter.lua")
local Synapse         = loadModule("Modules/Utils/Synapse.lua")
local Kalman          = loadModule("Modules/Utils/Math/Kalman.lua")

local BasePred        = loadModule("Modules/Combat/Prediction/Base.lua")
local Predictor       = loadModule("Modules/Combat/Predictor.lua")
local Selector        = loadModule("Modules/Combat/TargetSelector.lua")
local Aimbot          = loadModule("Modules/Combat/Aimbot.lua")
local SilentAim       = loadModule("Modules/Combat/SilentAim.lua")

local SpeedSpoof      = loadModule("Modules/Movement/SpeedSpoof.lua")
local SpeedMultiplier = loadModule("Modules/Movement/SpeedMultiplier.lua")
local CustomSpeed     = loadModule("Modules/Movement/CustomSpeed.lua")
local AntiSlowdown    = loadModule("Modules/Movement/AntiSlowdown.lua")
local AntiStun        = loadModule("Modules/Movement/AntiStun.lua")
local Cleaner         = loadModule("Modules/Movement/AttributeCleaner.lua")

local FOVCircle       = loadModule("Modules/Visuals/FOVCircle.lua")
local Hitmarker       = loadModule("Modules/Visuals/Hitmarker.lua")
local Highlight       = loadModule("Modules/Visuals/Highlight.lua")
local TargetDot       = loadModule("Modules/Visuals/TargetDot.lua")

-- ═══════════════════════════════════════════════════
-- INSTANTIATE (OOP Injection)
-- ═══════════════════════════════════════════════════
local synapse    = Synapse
local input      = InputHandler.new(Config)
local localCharacter = LocalCharacter.new()
local detector   = Detector.new()
local tracker    = Tracker.new(Config, detector)
local aimbot     = Aimbot.new(Config)
local silentAim  = SilentAim.new(Config, synapse) 

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
    slow  = AntiSlowdown.new(Options, localCharacter),
    stun  = AntiStun.new(Options, localCharacter),
    clean = Cleaner.new(Options, localCharacter)
}

-- THE CENTRAL BRAIN (CNS)
local brain = Brain.new(Config, {
    Input = input, Tracker = tracker, Predictor = pred, Selector = selector,
    Aimbot = aimbot, SilentAim = silentAim, Visuals = visuals
}, loadModule)

-- ═══════════════════════════════════════════════════
-- INITIALIZE & SETUP UI
-- ═══════════════════════════════════════════════════
input:Init()
localCharacter:Init()
tracker:Init()
silentAim:Init()
visuals.hit:Init()

for _, m in pairs(movementSuite) do if m.Init then m:Init() end end

loadModule("UI/Tabs/AimbotTab.lua")(Window, Options, {FOVCircle = visuals.fov.Drawing})
loadModule("UI/Tabs/TargetingTab.lua")(Window, Options, {FOVCircle = visuals.fov.Drawing}, tracker)
loadModule("UI/Tabs/PredictionTab.lua")(Window, Options)
loadModule("UI/Tabs/PlayerTab.lua")(Window, Options, movementSuite.slow)
loadModule("UI/Tabs/BlatantTab.lua")(Window, Options)
loadModule("UI/Tabs/SettingsTab.lua")(Window, Options)
loadModule("UI/Tabs/MiscTab.lua")(Window)

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
    local objs = {input, localCharacter, tracker, aimbot, silentAim, visuals.fov, visuals.hit, visuals.highlight, visuals.dot, brain}
    for _, o in pairs(movementSuite) do table.insert(objs, o) end
    for _, o in ipairs(objs) do if o.Destroy then pcall(function() o:Destroy() end) end end
    _G.BossAimAssist_Cleanup = nil
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

    if input.KeyCode ~= resolveToggleUIKeyCode(Options.ToggleUIKey) then
        return
    end

    local screenGuis = getRayfieldScreenGuis()
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

warn("✅ [Core] Brain Orchestration v6 Active.")
