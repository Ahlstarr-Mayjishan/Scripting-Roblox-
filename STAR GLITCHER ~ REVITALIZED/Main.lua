--[[
    Boss Aim Assist - Scientific Entry Point (Loader Redirect)
    Version: 1.1.8
]]

local baseUrl = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/STAR%20GLITCHER%20~%20REVITALIZED/Core/Main.lua"
local cacheBust = tostring(os.time())
return loadstring(game:HttpGet(baseUrl .. "?v=" .. cacheBust))()
