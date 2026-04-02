--[[
    Boss Aim Assist - Scientific Entry Point (Bundled Loader)
    Version: 1.2.0
]]

local function compileRemoteChunk(url, chunkName)
    local source = game:HttpGet(url)
    local chunk, compileErr = loadstring(source, chunkName)
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
