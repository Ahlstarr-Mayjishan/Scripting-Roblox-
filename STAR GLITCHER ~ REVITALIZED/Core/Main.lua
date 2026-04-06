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
local autoUpdateLoopStarted = false

local function compileChunk(content, chunkName)
    local compiler = loadstring or load
    if not compiler then
        error("[compile] No Lua compiler available")
    end

    content = tostring(content):gsub("^\239\187\191", ""):gsub("^", "")
    local chunk, compileErr = compiler(content, chunkName)
    if not chunk then
        error("[compile] " .. tostring(compileErr))
    end
    return chunk
end

local function parseRemoteVersion(content)
    content = tostring(content or ""):gsub("^\239\187\191", ""):gsub("^", "")

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
local TeleportService = game:GetService("TeleportService")
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

local function attemptRejoinAfterKick(reason)
    if Options.RejoinOnKickEnabled ~= true then
        return
    end

    local player = Players.LocalPlayer
    if not player then
        return
    end

    task.spawn(function()
        task.wait(1.5)

        local teleported = false
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
            teleported = true
        end)

        if not ok or not teleported then
            warn("[KickRejoin] Teleport failed, trying same instance | Error: " .. tostring(err))
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            end)
        end
    end)
end

reg(Players.LocalPlayer.Kicked:Connect(function(reason)
    attemptRejoinAfterKick(reason)
end))

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
        input, localCharacter, detector, tracker, pred, selector, aimbot, silentAim,
        cleaner, visuals.fov, visuals.highlight, visuals.technique, visuals.dot, brain,
        taskScheduler, dataPruner, waypointTeleport,
        playerTabController, settingsTabController
    }
    for _, obj in pairs(movementSuite) do
        objs[#objs + 1] = obj
    end

    if resourceManager then
        resourceManager:DeferCleanup(function()
            Synapse.clearAll()
        end)

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

        Synapse.clearAll()
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
    task.defer(function()
        performCleanup(true)
    end)
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

