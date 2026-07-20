--!nocheck

local HttpService = game:GetService("HttpService")
local SECURE_LOADER_URL = "https://nullscape-discord-auth.reynoldszlotapastevand.workers.dev/loader"
local fetchToken = tostring(os.time()) .. "-" .. HttpService:GenerateGUID(false)
local loaderUrl = SECURE_LOADER_URL .. "?nullscape_boot=" .. HttpService:UrlEncode(fetchToken)
local requestFn = request or http_request or (http and http.request) or (syn and syn.request)

local function fail(message)
	message = "[NULLSCAPE] " .. tostring(message)
	if typeof(messagebox) == "function" then
		pcall(messagebox, message, "NULLSCAPE Loader", 0)
	end
	error(message, 0)
end

local source = nil
if typeof(requestFn) == "function" then
	local success, response = pcall(requestFn, {
		Url = loaderUrl,
		Method = "GET",
		Headers = { ["Cache-Control"] = "no-cache" },
	})
	if not success then
		fail("Secure loader request failed: " .. tostring(response))
	end
	local statusCode = tonumber(response and (response.StatusCode or response.Status)) or 0
	if statusCode ~= 200 then
		fail("Secure loader returned HTTP " .. tostring(statusCode))
	end
	source = response and (response.Body or response.body)
else
	local success, response = pcall(function()
		return (game :: any):HttpGet(loaderUrl)
	end)
	if not success then
		fail("Secure loader download failed: " .. tostring(response))
	end
	source = response
end

if typeof(source) ~= "string" or #source == 0 then
	fail("Secure loader returned an empty response")
end

if string.sub(source, 1, 3) == "\239\187\191" then
	source = string.sub(source, 4)
end

local chunk, compileError = loadstring(source)
if not chunk then
	fail("Loader compile failed: " .. tostring(compileError))
end

return chunk()
