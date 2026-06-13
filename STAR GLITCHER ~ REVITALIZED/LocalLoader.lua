--[[
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
    print(" [Loader] Loading Star Glitcher from local workspace...")
    local compiler = loadstring or load
    local chunk, err
    if compiler then
        chunk, err = compiler(mainContent, "=Core/Main.lua")
    else
        err = "No Lua compiler available"
    end
    if chunk then
        chunk()
    else
        warn(" [Loader] Failed to compile Main.lua: " .. tostring(err))
    end
else
    warn(" [Loader] Could not find Core/Main.lua in workspace/" .. _G.BossAimAssist_LocalPath)
    warn("Please ensure you have copied the folder correctly to your executor's workspace.")
end

