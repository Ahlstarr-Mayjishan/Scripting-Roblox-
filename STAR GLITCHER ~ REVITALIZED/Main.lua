--[[
    Boss Aim Assist - Scientific Entry Point (Bundled Loader)
    Version: 1.2.0
]]

local entryNow = os.clock()
local entryBootUntil = tonumber(_G.__STAR_GLITCHER_ENTRY_BOOT_UNTIL) or 0
if entryBootUntil > entryNow then
    warn("[Entry] Duplicate load suppressed.")
    return _G.BossAimAssist_SessionID
end
_G.__STAR_GLITCHER_ENTRY_BOOT_UNTIL = entryNow + 8

local function sanitizeLuaSource(source)
    source = tostring(source or "")
    if source:sub(1, 3) == "\239\187\191" then
        source = source:sub(4)
    end

    if utf8 then
        local feff = utf8.char(0xFEFF)
        if source:sub(1, #feff) == feff then
            source = source:sub(#feff + 1)
        end
    end

    return source
end

local function compileRemoteChunk(url, chunkName)
    local compiler = loadstring or load
    if not compiler then
        error("No Lua compiler available in this executor (loadstring/load missing)")
    end

    local source = sanitizeLuaSource(game:HttpGet(url))
    local chunk, compileErr = compiler(source, chunkName)
    if not chunk then
        error(string.format("Failed to compile %s: %s", chunkName, tostring(compileErr)))
    end
    return chunk
end

local cacheBust = tostring(os.time())
local base = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/STAR%20GLITCHER%20~%20REVITALIZED/Core/"

local primaryUrl = base .. "Bundle.lua?v=" .. cacheBust
local fallbackUrl = base .. "Main.lua?v=" .. cacheBust

local ok, result = pcall(function()
    return compileRemoteChunk(primaryUrl, "=Bundle.lua")()
end)

if ok then
    return result
end

warn("[Entry] Bundle loader failed, falling back to Core/Main.lua | Error: " .. tostring(result))
return compileRemoteChunk(fallbackUrl, "=Core/Main.lua")()

