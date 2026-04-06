--[[
    ===============================================================
         Boss Aim Assist - Centralized Brain Orchestration v6       
      Scientifically Reorganized | Fully Decoupled | Brain Driven  
    ===============================================================
]]

local GITHUB_CONFIG = {
    User = "Ahlstarr-Mayjishan",
    Repo = "Scripting-Roblox-",
    Branch = "main",
    Folder = "STAR GLITCHER ~ REVITALIZED"
}

local GITHUB_BASE = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s/", GITHUB_CONFIG.User, GITHUB_CONFIG.Repo, GITHUB_CONFIG.Branch, GITHUB_CONFIG.Folder:gsub(" ", "%%20"):gsub("~", "%%7E"))
local UPDATE_ENTRY_URL = GITHUB_BASE .. "Main.lua"
local VERSION_URL = GITHUB_BASE .. "Data/Version.lua"
local BUNDLE_URL = GITHUB_BASE .. "Core/Bundle.lua"
local loaderSession = tostring(os.time())
local runtimeModuleCache = {}

local function sanitizeLuaSource(content)
    content = tostring(content or "")
    if content:sub(1, 3) == "\239\187\191" then
        content = content:sub(4)
    end

    if utf8 then
        local feff = utf8.char(0xFEFF)
        if content:sub(1, #feff) == feff then
            content = content:sub(#feff + 1)
        end
    end

    return content
end

local function compileChunk(content, chunkName)
    local compiler = loadstring or load
    if not compiler then
        error("[compile] No Lua compiler available")
    end

    content = sanitizeLuaSource(content)
    local chunk, compileErr = compiler(content, chunkName)
    if not chunk then
        error("[compile] " .. tostring(compileErr))
    end
    return chunk
end

local function parseRemoteVersion(content)
    content = sanitizeLuaSource(content)

    local directReturn = content:match("^%s*return%s+(%d+)")
    if directReturn then
        return tonumber(directReturn)
    end

    local bundledReturn = content:match('%["Data/Version%.lua"%]%s*=%s*%[====%[return%s+(%d+)')
    if bundledReturn then
        return tonumber(bundledReturn)
    end

    local genericReturn = content:match("return%s+(%d+)")
    if genericReturn then
        return tonumber(genericReturn)
    end

    local chunk = compileChunk(content, "=remote-version")
    return tonumber(chunk())
end

local function fetchRemoteVersion()
    -- Enhanced Cache Buster: Use redundant timestamp + random string to bypass GitHub Raw CDN caching
    local timestamp = os.date("%Y%m%d%H%M")
    local buster = tostring(os.clock()):gsub("%.", "") .. tostring(math.random(100000, 999999))
    local sources = {
        VERSION_URL .. "?check=" .. timestamp .. "&r=" .. buster,
        BUNDLE_URL .. "?check=" .. timestamp .. "&r=" .. buster,
    }

    local lastError = nil
    for _, url in ipairs(sources) do
        local ok, result = pcall(function()
            local content = game:HttpGet(url)
            local parsedVersion = parseRemoteVersion(content)
            if not parsedVersion then
                error("Could not parse version from " .. url)
            end
            return parsedVersion
        end)

        if ok and result then
            return result
        end

        lastError = result
    end

    error(lastError or "Remote version sources exhausted")
end

local function loadModule(path)
    local cached = runtimeModuleCache[path]
    if cached ~= nil then
        return cached
    end

    local url = GITHUB_BASE .. path
    local finalError = nil

    local function compileAndCache(content)
        local chunk = compileChunk(content, "=" .. path)
        local value = chunk()
        runtimeModuleCache[path] = value
        return value
    end

    -- Local load strategy (if base path provided in _G)
    if _G.BossAimAssist_LocalPath then
        local localPath = _G.BossAimAssist_LocalPath .. path
        if readfile then
            local ok, content = pcall(readfile, localPath)
            if ok and content then
                local success, val = pcall(compileAndCache, content)
                if success then return val end
            end
        end
    end

    -- Remote load strategy
    for attempt = 1, 3 do
        local ok, res = pcall(function()
            local content = game:HttpGet(url .. "?v=" .. loaderSession .. "&attempt=" .. attempt)
            if content == "404: Not Found" then
                error("[http] 404: " .. path)
            end

            return compileAndCache(content)
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

local function requireModule(path)
    local module = loadModule(path)
    if module == nil then
        error("Required module failed to load: " .. tostring(path), 2)
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

local coreBootNow = os.clock()
local coreBootUntil = tonumber(_G.__STAR_GLITCHER_CORE_BOOT_UNTIL) or 0
if _G.BossAimAssist_SessionID and coreBootUntil > coreBootNow then
    warn("[Core] Duplicate runtime load suppressed.")
    return _G.BossAimAssist_SessionID
end
_G.__STAR_GLITCHER_CORE_BOOT_UNTIL = coreBootNow + 8

-- Core Data
local Config  = requireModule("Data/Config.lua")
local Version = requireModule("Data/Version.lua")
local Options = Config.Options
local Normalize = requireModule("Modules/Core/Bootstrap/Normalize.lua")
local RayfieldUI = requireModule("Modules/Core/Bootstrap/RayfieldUI.lua")
local RejoinOnKick = requireModule("Modules/Core/Bootstrap/RejoinOnKick.lua")
local RuntimeLifecycle = requireModule("Modules/Core/Bootstrap/RuntimeLifecycle.lua")
local runtimeCompiler = loadstring or load

if _G.BossAimAssist_Cleanup then
    _G.BossAimAssist_Cleanup()
end

-- UI initialization
if not runtimeCompiler then
    error("No Lua compiler available for Rayfield bootstrap")
end
local Rayfield = runtimeCompiler(game:HttpGet("https://sirius.menu/rayfield"), "=Rayfield")()
getgenv().Rayfield = Rayfield

Options.ToggleUIKey = Normalize.ToggleUIKey(Options.ToggleUIKey)
Options.TargetingMethod = Normalize.TargetingMethod(Options.TargetingMethod)

local Window = RayfieldUI.CreateWindow(Rayfield)

-- ===================================================
-- LOAD ALL MODULES (Scientific Order)
-- ===================================================
local Brain          = requireModule("Modules/Core/Brain.lua")
local InputHandler   = requireModule("Modules/Utils/Input.lua")
local Tracker        = requireModule("Modules/Utils/NPCTracker.lua")
local Detector       = requireModule("Modules/Utils/BossDetector.lua")
local LocalCharacter = requireModule("Modules/Utils/LocalCharacter.lua")
local Synapse         = requireModule("Modules/Utils/Synapse.lua")
local Kalman          = requireModule("Modules/Utils/Math/Kalman.lua")
local ResourceManager = requireModule("Modules/Utils/ResourceManager.lua")
local TaskScheduler   = requireModule("Modules/Utils/TaskScheduler.lua")
local DataPruner      = requireModule("Modules/Utils/DataPruner.lua")

local Predictor       = requireModule("Modules/Combat/Predictor.lua")
local SilentResolver  = requireModule("Modules/Combat/Prediction/SilentResolver.lua")
local GarbageCollector = requireModule("Modules/Utils/GarbageCollector.lua")
local Selector        = requireModule("Modules/Combat/TargetSelector.lua")
local Aimbot          = requireModule("Modules/Combat/Aimbot.lua")
local SilentAim       = requireModule("Modules/Combat/SilentAim.lua")

local SpeedSpoof      = requireModule("Modules/Movement/SpeedSpoof.lua")
local MovementArbiter = requireModule("Modules/Movement/MovementArbiter.lua")
local SpeedMultiplier = requireModule("Modules/Movement/SpeedMultiplier.lua")
local CustomSpeed     = requireModule("Modules/Movement/CustomSpeed.lua")
local GravityController = requireModule("Modules/Movement/GravityController.lua")
local FloatController = requireModule("Modules/Movement/FloatController.lua")
local JumpBoost      = requireModule("Modules/Movement/JumpBoost.lua")
local AntiSlowdown    = requireModule("Modules/Movement/AntiSlowdown.lua")
local AntiStun        = requireModule("Modules/Movement/AntiStun.lua")
local Noclip          = requireModule("Modules/Movement/Noclip.lua")
local KillPartBypass  = requireModule("Modules/Movement/KillPartBypass.lua")
local ProactiveEvade  = requireModule("Modules/Movement/ProactiveEvade.lua")
local HitboxDesync    = requireModule("Modules/Movement/HitboxDesync.lua")
local WaypointTeleport = requireModule("Modules/Movement/WaypointTeleport.lua")
local Cleaner         = requireModule("Modules/Movement/AttributeCleaner.lua")

local FOVCircle       = requireModule("Modules/Visuals/FOVCircle.lua")
local Highlight       = requireModule("Modules/Visuals/Highlight.lua")
local TechniqueOverlay = requireModule("Modules/Visuals/TechniqueOverlay.lua")
local TargetDot       = requireModule("Modules/Visuals/TargetDot.lua")
local PlayerLabelUtils = requireModule("UI/Tabs/Player/LabelUtils.lua")
local PlayerLayout = requireModule("UI/Tabs/Player/Layout.lua")
local PlayerStatusLoop = requireModule("UI/Tabs/Player/StatusLoop.lua")
local PlayerController = requireModule("UI/Tabs/Player/Controller.lua")

-- ===================================================
-- INSTANTIATE (OOP Injection)
-- ===================================================
local synapse    = Synapse
local taskScheduler = TaskScheduler.new(Options)
local input      = InputHandler.new(Config)
local localCharacter = LocalCharacter.new(taskScheduler)
local movementArbiter = MovementArbiter.new(Options, localCharacter)
local detector   = Detector.new()
local tracker    = Tracker.new(Config, detector, taskScheduler)
local aimbot     = Aimbot.new(Config)
local silentResolver = SilentResolver.new(Config)
local silentAim  = SilentAim.new(Config, synapse, silentResolver) 
local playerTabController = PlayerController.new(PlayerLayout, PlayerStatusLoop, PlayerLabelUtils)
local waypointTeleport = WaypointTeleport.new(Options, localCharacter)
local resourceManager = ResourceManager.new(Options)
local cleaner    = GarbageCollector.new(Options, resourceManager)
local rejoinOnKick = RejoinOnKick.new(Options, UPDATE_ENTRY_URL)

local pred       = Predictor.new(Config, loadModule, Kalman)
local selector   = Selector.new(Config, tracker, pred)
local dataPruner = DataPruner.new(taskScheduler, tracker, pred)

local visuals = {
    fov = FOVCircle.new(Options),
    highlight = Highlight.new(),
    technique = TechniqueOverlay.new(Options),
    dot = TargetDot.new()
}

local movementSuite = {
    spoof = SpeedSpoof.new(Options, localCharacter),
    arbiter = movementArbiter,
    multi = SpeedMultiplier.new(Options, localCharacter, movementArbiter),
    fixed = CustomSpeed.new(Options, localCharacter, movementArbiter),
    gravity = GravityController.new(Options),
    float = FloatController.new(Options, localCharacter),
    jump = JumpBoost.new(Options, localCharacter, movementArbiter),
    slow  = AntiSlowdown.new(Options, localCharacter, movementArbiter),
    stun  = AntiStun.new(Options, localCharacter),
    noclip = Noclip.new(Options, localCharacter),
    killPart = KillPartBypass.new(Options, localCharacter),
    proactiveEvade = ProactiveEvade.new(Options, localCharacter),
    zenith = HitboxDesync.new(Options, localCharacter),
    clean = Cleaner.new(Options, localCharacter)
}

-- THE CENTRAL BRAIN (CNS)
local brain = Brain.new(Config, {
    Input = input, Tracker = tracker, Predictor = pred, Selector = selector,
    Aimbot = aimbot, SilentAim = silentAim, Visuals = visuals
}, loadModule)

-- ===================================================
-- INITIALIZE & SETUP UI
-- ===================================================
input:Init()
taskScheduler:Init()
localCharacter:Init()
detector:Init()
tracker:Init()
aimbot:Init()
selector:Init()
silentAim:Init()
dataPruner:Init()
resourceManager:Init()
cleaner:Init()
for _, m in pairs(movementSuite) do if m.Init then m:Init() end end

requireModule("UI/Tabs/AimbotTab.lua")(Window, Options, {FOVCircle = visuals.fov.Drawing}, tracker)
requireModule("UI/Tabs/PredictionTab.lua")(Window, Options)
requireModule("UI/Tabs/PlayerTab.lua")(Window, Options, movementSuite.slow, movementSuite.stun, movementSuite.multi, movementSuite.gravity, movementSuite.float, movementSuite.jump, movementSuite.noclip, movementSuite.zenith, playerTabController)
requireModule("UI/Tabs/TeleportTab.lua")(Window, Options, waypointTeleport)
requireModule("UI/Tabs/BlatantTab.lua")(Window, Options, movementSuite.killPart, movementSuite.proactiveEvade)
local settingsTabController = requireModule("UI/Tabs/SettingsTab.lua")(Window, Options, cleaner, resourceManager, tracker, taskScheduler)

local loadConfigOk, loadConfigErr = RayfieldUI.SafeLoadConfiguration(Rayfield)
if not loadConfigOk then
    warn("[Config] LoadConfiguration failed, continuing with runtime defaults | Error: " .. tostring(loadConfigErr))
end
Options.TargetingMethod = Normalize.TargetingMethod(Options.TargetingMethod)

-- ===================================================
-- MAIN ORCHESTRATION LOOP (Brain Powered)
-- ===================================================
local function executeUpdatedEntry(url, chunkName)
    local content = game:HttpGet(url)
    local chunk = compileChunk(content, chunkName)
    return chunk()
end

local function getCleanupObjects()
    local objs = {
        input, localCharacter, detector, tracker, pred, selector, aimbot, silentAim,
        cleaner, visuals.fov, visuals.highlight, visuals.technique, visuals.dot, brain,
        taskScheduler, dataPruner, waypointTeleport, rejoinOnKick,
        playerTabController, settingsTabController
    }
    for _, obj in pairs(movementSuite) do
        objs[#objs + 1] = obj
    end
    return objs
end

local function resetGlobalState()
    local silentHook = getgenv and getgenv().__STAR_GLITCHER_SILENT_AIM_HOOK
    if silentHook then
        silentHook.Instance = nil
    end

    local apocalypseHook = getgenv and getgenv().__STAR_GLITCHER_APOCALYPSE_HOOK
    if apocalypseHook then
        apocalypseHook.Instance = nil
    end
end

local runtimeLifecycle = RuntimeLifecycle.new(
    Options,
    Version,
    Rayfield,
    resourceManager,
    cleaner,
    Synapse,
    UPDATE_ENTRY_URL,
    executeUpdatedEntry,
    fetchRemoteVersion,
    getCleanupObjects,
    resetGlobalState
)
runtimeLifecycle:BindGlobals()
runtimeLifecycle:StartAutoUpdateLoop()
rejoinOnKick:Init()

local function reg(connection)
    return runtimeLifecycle:RegisterConnection(connection)
end

-- Scanning (Heartbeat, Off render)
reg(RunService.Heartbeat:Connect(function(dt)
    brain:Scan(UserInputService:GetMouseLocation(), Camera.CFrame.Position, dt)
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

warn(" [Core] Brain Orchestration v6 Active.")

