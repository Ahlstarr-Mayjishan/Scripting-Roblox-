--!nocheck

local HttpService = game:GetService("HttpService")
local MASTER_URL =
	"https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/NULLSCAPE/Main%20UI/master.luau"
local fetchToken = tostring(os.time()) .. "-" .. HttpService:GenerateGUID(false)
local httpGet = (game :: any).HttpGet
local source = httpGet(game, MASTER_URL .. "?nullscape_boot=" .. HttpService:UrlEncode(fetchToken))

if string.sub(source, 1, 3) == "\239\187\191" then
	source = string.sub(source, 4)
end

local chunk, compileError = loadstring(source)
if not chunk then
	error("[NULLSCAPE] Loader compile failed: " .. tostring(compileError), 0)
end

return chunk()
