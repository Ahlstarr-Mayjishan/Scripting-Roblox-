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
local UPDATE_ENTRY_URL = GITHUB_BASE .. "Main.lua"

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

local function requireModule(path)
    local module = loadModule(path)
    if not module then
        error("Required module failed to load: " .. tostring(path))
    end
    return module
end

do
    local loaderSession = tostring(os.time())
    local runtimeModuleCache = {}

    local function compileChunk(content, chunkName)
        local chunk, compileErr = loadstring(content, chunkName)
        if not chunk then
            error("[compile] " .. tostring(compileErr))
        end
        return chunk
    end

    loadModule = function(path)
        local cached = runtimeModuleCache[path]
        if cached ~= nil then
            return cached
        end

        local url = GITHUB_BASE .. path
        local finalError = nil

        for attempt = 1, 3 do
            local ok, res = pcall(function()
                local content = game:HttpGet(url .. "?v=" .. loaderSession .. "&attempt=" .. attempt)
                if content == "404: Not Found" then
                    error("[http] 404: " .. path)
                end

                local chunk = compileChunk(content, "=" .. path)
                local value = chunk()
                runtimeModuleCache[path] = value
                return value
            end)

            if ok then
                return res
            end

            finalError = res
            task.wait(0.15 * attempt)
        end

        warn("[Loader] Failed: " .. path .. " | Error: " .. tostring(finalError))
        return nil
    end

    requireModule = function(path)
        local module = loadModule(path)
        if not module then
            error("Required module failed to load: " .. tostring(path), 2)
        end
        return module
    end
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

if _G.BossAimAssist_Cleanup then
    _G.BossAimAssist_Cleanup()
end

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
local Brain          = requireModule("Modules/Core/Brain.lua")
local InputHandler   = requireModule("Modules/Utils/Input.lua")
local Tracker        = requireModule("Modules/Utils/NPCTracker.lua")
local Detector       = requireModule("Modules/Utils/BossDetector.lua")
local LocalCharacter = requireModule("Modules/Utils/LocalCharacter.lua")
local Synapse         = requireModule("Modules/Utils/Synapse.lua")
local Kalman          = requireModule("Modules/Utils/Math/Kalman.lua")

local BasePred        = requireModule("Modules/Combat/Prediction/Base.lua")
local Predictor       = requireModule("Modules/Combat/Predictor.lua")
local Apocalypse      = requireModule("Modules/Combat/Hijackers/Apocalypse.lua")
local GarbageCollector = requireModule("Modules/Utils/GarbageCollector.lua")
local Selector        = requireModule("Modules/Combat/TargetSelector.lua")
local Aimbot          = requireModule("Modules/Combat/Aimbot.lua")
local SilentAim       = requireModule("Modules/Combat/SilentAim.lua")

local SpeedSpoof      = requireModule("Modules/Movement/SpeedSpoof.lua")
local SpeedMultiplier = requireModule("Modules/Movement/SpeedMultiplier.lua")
local CustomSpeed     = requireModule("Modules/Movement/CustomSpeed.lua")
local AntiSlowdown    = requireModule("Modules/Movement/AntiSlowdown.lua")
local AntiStun        = requireModule("Modules/Movement/AntiStun.lua")
local Cleaner         = requireModule("Modules/Movement/AttributeCleaner.lua")

local FOVCircle       = requireModule("Modules/Visuals/FOVCircle.lua")
local Hitmarker       = requireModule("Modules/Visuals/Hitmarker.lua")
local Highlight       = requireModule("Modules/Visuals/Highlight.lua")
local TargetDot       = requireModule("Modules/Visuals/TargetDot.lua")

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
local apocalypse = Apocalypse.new(Config)
local cleaner    = GarbageCollector.new(Options)

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
apocalypse:Init()
cleaner:Init()
visuals.hit:Init()

for _, m in pairs(movementSuite) do if m.Init then m:Init() end end

requireModule("UI/Tabs/AimbotTab.lua")(Window, Options, {FOVCircle = visuals.fov.Drawing}, tracker)
requireModule("UI/Tabs/PredictionTab.lua")(Window, Options)
requireModule("UI/Tabs/PlayerTab.lua")(Window, Options, movementSuite.slow, movementSuite.stun, movementSuite.multi)
requireModule("UI/Tabs/BlatantTab.lua")(Window, Options, apocalypse)
requireModule("UI/Tabs/SettingsTab.lua")(Window, Options, cleaner)

Rayfield:LoadConfiguration()

-- ═══════════════════════════════════════════════════
-- MAIN ORCHESTRATION LOOP (Brain Powered)
-- ═══════════════════════════════════════════════════
local SESSION_ID = os.time()
_G.BossAimAssist_SessionID = SESSION_ID

local _conns = {}
local function reg(c) table.insert(_conns, c) end

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

    for _, obj in ipairs(objs) do
        if obj and obj.Destroy then
            pcall(function()
                obj:Destroy()
            end)
        end
    end

    _G.BossAimAssist_SessionID = nil
    _G.BossAimAssist_Update = nil
    _G.BossAimAssist_Cleanup = nil

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
        pcall(function()
            collectgarbage("collect")
            collectgarbage("collect")
        end)
    end
end

_G.BossAimAssist_Cleanup = function(fullSweep)
    performCleanup(fullSweep == true)
end

_G.BossAimAssist_Update = function()
    performCleanup(true)
    task.wait(0.2)
    local updateUrl = UPDATE_ENTRY_URL .. "?update=" .. tostring(os.time())
    return loadstring(game:HttpGet(updateUrl))()
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
