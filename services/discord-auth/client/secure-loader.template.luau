--!nocheck

local API_BASE = "__NULLSCAPE_AUTH_BASE_URL__"
local getgenv = getgenv
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local requestFn = request
	or http_request
	or (http and http.request)
	or (syn and syn.request)
	or (fluxus and fluxus.request)
	or (krnl and krnl.request)
if typeof(requestFn) ~= "function" then
	local message = "[NULLSCAPE] This executor does not provide an HTTP request function"
	if typeof(messagebox) == "function" then
		pcall(messagebox, message, "NULLSCAPE Login", 0)
	end
	error(message, 0)
end
if string.sub(API_BASE, 1, 8) ~= "https://" or string.find(API_BASE, "__", 1, true) then
	error("[NULLSCAPE] Secure loader endpoint is not configured", 0)
end

local AUTH_FOLDER = "NULLSCAPE"
local AUTH_FILE = AUTH_FOLDER .. "/auth_session.json"
local MASTER_PATH = "NULLSCAPE/Main UI/master.luau"

local function decodeJson(value)
	local success, decoded = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	return success and typeof(decoded) == "table" and decoded or nil
end

local function post(path, payload)
	local requestSucceeded, response = pcall(requestFn, {
		Url = API_BASE .. path,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
		},
		Body = HttpService:JSONEncode(payload),
	})
	if not requestSucceeded then
		return nil, "REQUEST_FAILED: " .. tostring(response)
	end
	local statusCode = tonumber(response and (response.StatusCode or response.Status)) or 0
	local body = response and (response.Body or response.body) or ""
	local decoded = decodeJson(body)
	if statusCode < 200 or statusCode >= 300 then
		local code = decoded and decoded.error and decoded.error.code
			or ("HTTP_" .. tostring(statusCode) .. (body ~= "" and (": " .. tostring(body)) or ""))
		return nil, tostring(code)
	end
	return decoded
end

local function newClientToken()
	return HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)
end

local function readAuthState()
	if not (isfile and readfile and isfile(AUTH_FILE)) then
		return {}
	end
	local success, content = pcall(readfile, AUTH_FILE)
	return success and decodeJson(content) or {}
end

local function writeAuthState(state)
	if not (makefolder and writefile) then
		return false
	end
	pcall(makefolder, AUTH_FOLDER)
	return pcall(writefile, AUTH_FILE, HttpService:JSONEncode(state))
end

local function createLoginView()
	local gui = Instance.new("ScreenGui")
	gui.Name = "NULLSCAPEAuthentication"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000000

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -32, 0, 224)
	panel.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
	panel.BorderColor3 = Color3.fromRGB(63, 65, 72)
	panel.Parent = gui
	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MinSize = Vector2.new(288, 224)
	panelSize.MaxSize = Vector2.new(460, 224)
	panelSize.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(22, 18)
	title.Size = UDim2.new(1, -44, 0, 32)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "NULLSCAPE Login"
	title.TextColor3 = Color3.fromRGB(242, 243, 245)
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Position = UDim2.fromOffset(22, 58)
	status.Size = UDim2.new(1, -44, 0, 42)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "Preparing Discord authentication..."
	status.TextColor3 = Color3.fromRGB(196, 198, 204)
	status.TextSize = 15
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = panel

	local urlBox = Instance.new("TextBox")
	urlBox.Position = UDim2.fromOffset(22, 112)
	urlBox.Size = UDim2.new(1, -142, 0, 42)
	urlBox.BackgroundColor3 = Color3.fromRGB(18, 19, 22)
	urlBox.BorderColor3 = Color3.fromRGB(63, 65, 72)
	urlBox.ClearTextOnFocus = false
	urlBox.Editable = false
	urlBox.Font = Enum.Font.Code
	urlBox.PlaceholderText = "Discord authorization URL"
	urlBox.Text = ""
	urlBox.TextColor3 = Color3.fromRGB(220, 221, 225)
	urlBox.TextSize = 13
	urlBox.TextXAlignment = Enum.TextXAlignment.Left
	urlBox.Parent = panel

	local copyButton = Instance.new("TextButton")
	copyButton.Position = UDim2.new(1, -110, 0, 112)
	copyButton.Size = UDim2.fromOffset(88, 42)
	copyButton.BackgroundColor3 = Color3.fromRGB(43, 113, 190)
	copyButton.BorderSizePixel = 0
	copyButton.Font = Enum.Font.GothamMedium
	copyButton.Text = "Copy link"
	copyButton.TextColor3 = Color3.new(1, 1, 1)
	copyButton.TextSize = 14
	copyButton.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(22, 170)
	hint.Size = UDim2.new(1, -44, 0, 30)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.Text = "Authorize in your browser. This window continues automatically."
	hint.TextColor3 = Color3.fromRGB(142, 145, 151)
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = panel

	copyButton.Activated:Connect(function()
		local copy = setclipboard or toclipboard
		if typeof(copy) == "function" and urlBox.Text ~= "" then
			pcall(copy, urlBox.Text)
			status.Text = "Authorization link copied."
		end
	end)

	local guiParent = CoreGui
	if typeof(gethui) == "function" then
		local success, protectedGui = pcall(gethui)
		if success and typeof(protectedGui) == "Instance" then
			guiParent = protectedGui
		end
	end

	local mounted, mountError = pcall(function()
		gui.Parent = guiParent
	end)
	if not mounted then
		local message = "[NULLSCAPE] Unable to show the login window: " .. tostring(mountError)
		if typeof(messagebox) == "function" then
			pcall(messagebox, message, "NULLSCAPE Login", 0)
		end
		error(message, 0)
	end

	return {
		Gui = gui,
		Status = status,
		Url = urlBox,
	}
end

local viewCreated, viewOrError = pcall(createLoginView)
if not viewCreated then
	local message = "[NULLSCAPE] Login UI initialization failed: " .. tostring(viewOrError)
	if typeof(messagebox) == "function" then
		pcall(messagebox, message, "NULLSCAPE Login", 0)
	end
	error(message, 0)
end
local view = viewOrError

local authState = readAuthState()
authState.client_token = typeof(authState.client_token) == "string" and authState.client_token or newClientToken()

local function setStatus(text)
	view.Status.Text = tostring(text)
end

local function verifySavedSession()
	if typeof(authState.session_token) ~= "string" then
		return false
	end
	local result = post("/v1/session/verify", {
		session_token = authState.session_token,
		client_token = authState.client_token,
	})
	return result and result.valid == true
end

local function authenticate()
	if verifySavedSession() then
		return true
	end
	authState.session_token = nil
	writeAuthState(authState)

	local started, startError = post("/v1/auth/start", {
		client_token = authState.client_token,
	})
	if not started then
		return false, startError
	end

	view.Url.Text = tostring(started.authorize_url or "")
	setStatus("Open the Discord link and approve access.")
	local copy = setclipboard or toclipboard
	if typeof(copy) == "function" then
		pcall(copy, view.Url.Text)
		setStatus("Discord link copied. Open it and approve access.")
	end

	local deadline = os.clock() + tonumber(started.expires_in or 600)
	local delaySeconds = math.max(tonumber(started.poll_after_seconds) or 4, 4)
	while os.clock() < deadline do
		task.wait(delaySeconds)
		local result, statusError = post("/v1/auth/status", {
			request_token = started.request_token,
			client_token = authState.client_token,
		})
		if result and result.status == "approved" and typeof(result.session_token) == "string" then
			authState.session_token = result.session_token
			authState.expires_at = result.expires_at
			writeAuthState(authState)
			return true
		end
		if statusError and statusError ~= "RATE_LIMITED" then
			return false, statusError
		end
	end
	return false, "AUTH_TIMEOUT"
end

local authenticated, authError = authenticate()
if not authenticated then
	setStatus("Login failed: " .. tostring(authError))
	error("[NULLSCAPE] Authentication failed: " .. tostring(authError), 0)
end

setStatus("Downloading protected runtime...")
local function fetchBundle()
	return post("/v1/source/bundle", {
		session_token = authState.session_token,
		client_token = authState.client_token,
	})
end

local bundle, bundleError = fetchBundle()
if not bundle or typeof(bundle.sources) ~= "table" then
	setStatus("Runtime download failed: " .. tostring(bundleError))
	error("[NULLSCAPE] Protected runtime download failed: " .. tostring(bundleError), 0)
end

local sources = bundle.sources
local masterPath = tostring(bundle.master_path or MASTER_PATH)
local masterSource = sources[masterPath]
if typeof(masterSource) ~= "string" or #masterSource == 0 then
	error("[NULLSCAPE] Protected bundle has no master source", 0)
end

getgenv()._NULLSCAPE_ProtectedSources = sources
getgenv()._NULLSCAPE_ProtectedVersion = bundle.version
getgenv()._NULLSCAPE_RefreshProtectedBundle = function()
	local refreshed, refreshError = fetchBundle()
	if not refreshed or typeof(refreshed.sources) ~= "table" then
		error(refreshError or "Protected bundle refresh failed")
	end
	table.clear(sources)
	for path, source in pairs(refreshed.sources) do
		sources[path] = source
	end
	getgenv()._NULLSCAPE_ProtectedVersion = refreshed.version
	return sources[tostring(refreshed.master_path or MASTER_PATH)]
end

view.Gui:Destroy()
local chunk, compileError = loadstring(masterSource)
if not chunk then
	error("[NULLSCAPE] Protected master compile failed: " .. tostring(compileError), 0)
end
return chunk()
