--[[
    Boss Aim Assist - Scientific Entry Point (Bundled Loader)
    Version: 1.2.0
]]

local baseUrl = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/STAR%20GLITCHER%20~%20REVITALIZED/Core/Bundle.lua"
local cacheBust = tostring(os.time())
return loadstring(game:HttpGet(baseUrl .. "?v=" .. cacheBust))()
