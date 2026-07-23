--!nocheck

local API_BASE = "__NULLSCAPE_AUTH_BASE_URL__"
local getgenv = getgenv
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
local AUTH_FALLBACK_FILE = "NULLSCAPE_auth_session.json"
local AUTH_FILES = { AUTH_FILE, AUTH_FALLBACK_FILE }
local RUNTIME_AUTH_KEY = "_NULLSCAPE_AuthSession"
local MASTER_PATH = "NULLSCAPE/Main UI/master.luau"
local REQUEST_RETRY_ATTEMPTS = 4
local REQUEST_RETRY_BASE_SECONDS = 0.75
local POLL_RETRY_MAX_SECONDS = 12

local runtimeEnvironment = _G
if typeof(getgenv) == "function" then
	local success, environment = pcall(getgenv)
	if success and typeof(environment) == "table" then
		runtimeEnvironment = environment
	end
end

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
		return nil, "REQUEST_FAILED: " .. tostring(response), 0
	end
	local statusCode = tonumber(response and (response.StatusCode or response.Status)) or 0
	local body = response and (response.Body or response.body) or ""
	local decoded = decodeJson(body)
	if statusCode < 200 or statusCode >= 300 then
		local code = decoded and decoded.error and decoded.error.code
			or ("HTTP_" .. tostring(statusCode) .. (body ~= "" and (": " .. tostring(body)) or ""))
		return nil, tostring(code), statusCode
	end
	return decoded, nil, statusCode
end

local function isTransientRequestError(errorCode, statusCode)
	local code = tostring(errorCode or "")
	local status = tonumber(statusCode) or 0
	if string.sub(code, 1, 14) == "REQUEST_FAILED" or code == "RATE_LIMITED" then
		return true
	end
	if code == "SESSION_ISSUE_FAILED" then
		return true
	end
	return status == 0 or status == 408 or status == 425 or status == 429 or status >= 500
end

local function postWithRetry(path, payload, attempts)
	attempts = math.max(1, math.floor(tonumber(attempts) or REQUEST_RETRY_ATTEMPTS))
	local lastError = nil
	local lastStatus = 0
	for attempt = 1, attempts do
		local result, requestError, statusCode = post(path, payload)
		if result then
			return result
		end
		lastError = requestError
		lastStatus = statusCode
		if not isTransientRequestError(requestError, statusCode) or attempt >= attempts then
			break
		end
		task.wait(math.min(REQUEST_RETRY_BASE_SECONDS * (2 ^ (attempt - 1)), 4))
	end
	return nil, lastError, lastStatus
end

local function newClientToken()
	return HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)
end

local function getDeviceLabel()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	end
	return "Desktop"
end

local DEVICE_LABEL = getDeviceLabel()
local authStorageMode = "runtime-only"

local function readAuthState()
	local cached = runtimeEnvironment and runtimeEnvironment[RUNTIME_AUTH_KEY]
	if typeof(cached) == "string" then
		local decoded = decodeJson(cached)
		if decoded then
			return decoded, "runtime-only"
		end
	end

	local newestState = nil
	local newestEncoded = nil
	local newestRevision = -1
	local newestUpdatedAt = -1
	if typeof(readfile) == "function" then
		for _, path in ipairs(AUTH_FILES) do
			local shouldRead = true
			if typeof(isfile) == "function" then
				local checked, exists = pcall(isfile, path)
				shouldRead = checked and exists == true
			end
			if shouldRead then
				local success, content = pcall(readfile, path)
				local decoded = success and decodeJson(content) or nil
				local revision = decoded and tonumber(decoded.revision) or 0
				local updatedAt = decoded and tonumber(decoded.updated_at) or -1
				if decoded and (revision > newestRevision or (revision == newestRevision and updatedAt > newestUpdatedAt)) then
					newestState = decoded
					newestRevision = revision
					newestEncoded = content
					newestUpdatedAt = updatedAt
				end
			end
		end
	end
	if newestState then
		runtimeEnvironment[RUNTIME_AUTH_KEY] = newestEncoded
		return newestState, "persistent"
	end

	return {}, "runtime-only"
end

local function readBackAuthState(path, expectedClientToken, expectedRevision)
	if typeof(readfile) ~= "function" then
		return false
	end
	local success, content = pcall(readfile, path)
	local decoded = success and decodeJson(content) or nil
	return decoded ~= nil
		and decoded.client_token == expectedClientToken
		and decoded.revision == expectedRevision
end

local function writeAuthState(state)
	state.revision = (tonumber(state.revision) or 0) + 1
	state.updated_at = os.time()
	local encoded = HttpService:JSONEncode(state)
	runtimeEnvironment[RUNTIME_AUTH_KEY] = encoded

	if typeof(writefile) ~= "function" or typeof(readfile) ~= "function" then
		authStorageMode = "runtime-only"
		return false, authStorageMode
	end
	if typeof(makefolder) == "function" then
		pcall(makefolder, AUTH_FOLDER)
	end

	local durableCopies = 0
	for _, path in ipairs(AUTH_FILES) do
		local success = pcall(writefile, path, encoded)
		if success and readBackAuthState(path, state.client_token, state.revision) then
			durableCopies += 1
		end
	end

	if durableCopies > 0 then
		authStorageMode = "persistent"
		return true, authStorageMode
	end
	authStorageMode = "runtime-only"
	return false, authStorageMode
end

local function isTerminalSessionError(errorCode)
	return errorCode == "SESSION_INVALID_OR_EXPIRED"
		or errorCode == "INVALID_SESSION_TOKEN"
		or errorCode == "INVALID_CLIENT_TOKEN"
		or errorCode == "NETWORK_REAUTH_REQUIRED"
end

local function isTerminalAuthenticationError(errorCode)
	return errorCode == "ROLE_REQUIRED"
		or errorCode == "GUILD_MEMBERSHIP_REQUIRED"
		or errorCode == "DISCORD_AUTH_FAILED"
		or errorCode == "DEVICE_LIMIT_REACHED"
		or errorCode == "DEVICE_TRANSFER_COOLDOWN"
		or errorCode == "INVALID_REQUEST_TOKEN"
		or errorCode == "INVALID_CLIENT_TOKEN"
end
local function createLoginView()
	local compactHeight = 202
	local manualLinkHeight = 250
	local gui = Instance.new("ScreenGui")
	gui.Name = "NULLSCAPEAuthentication"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = true

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.47)
	panel.Size = UDim2.new(1, -32, 0, compactHeight)
	panel.BackgroundColor3 = Color3.fromRGB(25, 26, 31)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(72, 75, 83)
	panelStroke.Transparency = 0.2
	panelStroke.Thickness = 1
	panelStroke.Parent = panel
	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MinSize = Vector2.new(280, compactHeight)
	panelSize.MaxSize = Vector2.new(400, compactHeight)
	panelSize.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(18, 16)
	title.Size = UDim2.new(1, -36, 0, 28)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "NULLSCAPE Login"
	title.TextColor3 = Color3.fromRGB(242, 243, 245)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Position = UDim2.fromOffset(18, 50)
	status.Size = UDim2.new(1, -36, 0, 28)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "Preparing Discord authentication..."
	status.TextColor3 = Color3.fromRGB(196, 198, 204)
	status.TextSize = 14
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = panel

	local copyButton = Instance.new("TextButton")
	copyButton.Position = UDim2.fromOffset(18, 90)
	copyButton.Size = UDim2.new(1, -36, 0, 36)
	copyButton.BackgroundColor3 = Color3.fromRGB(43, 113, 190)
	copyButton.BorderSizePixel = 0
	copyButton.Font = Enum.Font.GothamMedium
	copyButton.Text = "Copy Discord link"
	copyButton.TextColor3 = Color3.new(1, 1, 1)
	copyButton.TextSize = 14
	copyButton.Parent = panel
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = copyButton

	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(18, 132)
	hint.Size = UDim2.new(1, -36, 0, 24)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.Text = "Approval continues automatically."
	hint.TextColor3 = Color3.fromRGB(142, 145, 151)
	hint.TextSize = 12
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = panel

	local recoveryBox = Instance.new("TextBox")
	recoveryBox.Position = UDim2.fromOffset(18, 132)
	recoveryBox.Size = UDim2.new(1, -128, 0, 32)
	recoveryBox.BackgroundColor3 = Color3.fromRGB(17, 18, 22)
	recoveryBox.BorderSizePixel = 0
	recoveryBox.ClearTextOnFocus = false
	recoveryBox.Font = Enum.Font.Code
	recoveryBox.PlaceholderText = "Recovery code"
	recoveryBox.Text = ""
	recoveryBox.TextColor3 = Color3.fromRGB(224, 226, 231)
	recoveryBox.PlaceholderColor3 = Color3.fromRGB(126, 129, 136)
	recoveryBox.TextSize = 12
	recoveryBox.TextXAlignment = Enum.TextXAlignment.Left
	recoveryBox.Parent = panel
	local recoveryCorner = Instance.new("UICorner")
	recoveryCorner.CornerRadius = UDim.new(0, 6)
	recoveryCorner.Parent = recoveryBox
	local recoveryPadding = Instance.new("UIPadding")
	recoveryPadding.PaddingLeft = UDim.new(0, 10)
	recoveryPadding.PaddingRight = UDim.new(0, 10)
	recoveryPadding.Parent = recoveryBox

	local resumeButton = Instance.new("TextButton")
	resumeButton.AnchorPoint = Vector2.new(1, 0)
	resumeButton.Position = UDim2.new(1, -18, 0, 132)
	resumeButton.Size = UDim2.fromOffset(84, 32)
	resumeButton.BackgroundColor3 = Color3.fromRGB(51, 54, 61)
	resumeButton.BorderSizePixel = 0
	resumeButton.Font = Enum.Font.GothamMedium
	resumeButton.Text = "Resume"
	resumeButton.TextColor3 = Color3.fromRGB(232, 233, 237)
	resumeButton.TextSize = 13
	resumeButton.Parent = panel
	local resumeCorner = Instance.new("UICorner")
	resumeCorner.CornerRadius = UDim.new(0, 6)
	resumeCorner.Parent = resumeButton

	hint.Position = UDim2.fromOffset(18, 172)

	local linkBox = Instance.new("TextBox")
	linkBox.Position = UDim2.fromOffset(18, 174)
	linkBox.Size = UDim2.new(1, -36, 0, 36)
	linkBox.BackgroundColor3 = Color3.fromRGB(17, 18, 22)
	linkBox.BorderSizePixel = 0
	linkBox.ClearTextOnFocus = false
	linkBox.Font = Enum.Font.Code
	linkBox.PlaceholderText = "Discord authorization link"
	linkBox.Text = ""
	linkBox.TextColor3 = Color3.fromRGB(224, 226, 231)
	linkBox.TextSize = 12
	linkBox.TextTruncate = Enum.TextTruncate.AtEnd
	linkBox.TextXAlignment = Enum.TextXAlignment.Left
	linkBox.TextEditable = true
	linkBox.Visible = false
	linkBox.Parent = panel
	local linkCorner = Instance.new("UICorner")
	linkCorner.CornerRadius = UDim.new(0, 6)
	linkCorner.Parent = linkBox
	local linkPadding = Instance.new("UIPadding")
	linkPadding.PaddingLeft = UDim.new(0, 10)
	linkPadding.PaddingRight = UDim.new(0, 10)
	linkPadding.Parent = linkBox

	local authorizeUrl = ""
	local manualLinkShown = false
	local queuedRecoveryCode = nil
	local buttonBaseColor = copyButton.BackgroundColor3
	local function showManualLink(focus)
		if authorizeUrl == "" then
			return
		end
		linkBox.Text = authorizeUrl
		if not manualLinkShown then
			manualLinkShown = true
			linkBox.Visible = true
			hint.Position = UDim2.fromOffset(18, 216)
			hint.Text = "Select and copy this link, then open it in your browser."
			panelSize.MinSize = Vector2.new(280, manualLinkHeight)
			panelSize.MaxSize = Vector2.new(400, manualLinkHeight)
			TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -32, 0, manualLinkHeight),
			}):Play()
		end
		if focus then
			linkBox:CaptureFocus()
		end
	end

	local function tryCopyAuthorizeUrl()
		local copy = setclipboard or toclipboard
		if typeof(copy) ~= "function" or authorizeUrl == "" then
			return false
		end
		return pcall(copy, authorizeUrl)
	end

	linkBox.Focused:Connect(function()
		task.defer(function()
			if linkBox.Parent and linkBox.Text ~= "" then
				linkBox.CursorPosition = #linkBox.Text + 1
				linkBox.SelectionStart = 1
			end
		end)
	end)
	copyButton.MouseEnter:Connect(function()
		TweenService:Create(copyButton, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(57, 128, 207),
		}):Play()
	end)
	copyButton.MouseLeave:Connect(function()
		TweenService:Create(copyButton, TweenInfo.new(0.12), {
			BackgroundColor3 = buttonBaseColor,
		}):Play()
	end)
	copyButton.Activated:Connect(function()
		if tryCopyAuthorizeUrl() then
			status.Text = "Authorization link copied."
			copyButton.Text = "Link copied"
			task.delay(1.2, function()
				if copyButton.Parent then
					copyButton.Text = "Copy Discord link"
				end
			end)
		else
			showManualLink(true)
		end
	end)
	resumeButton.Activated:Connect(function()
		local value = string.upper((recoveryBox.Text or ""):gsub("[%s%-]", ""))
		if string.match(value, "^[A-F0-9]+$") and #value == 16 then
			queuedRecoveryCode = value
			recoveryBox.Text = ""
			status.Text = "Checking one-time recovery code..."
		else
			status.Text = "Enter the 16-character recovery code from Discord."
		end
	end)

	local guiParents = {}
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui and localPlayer then
		local success, result = pcall(function()
			return localPlayer:WaitForChild("PlayerGui", 8)
		end)
		if success and typeof(result) == "Instance" then
			playerGui = result
		end
	end
	if playerGui then
		table.insert(guiParents, playerGui)
	end
	if typeof(gethui) == "function" then
		local success, protectedGui = pcall(gethui)
		if success and typeof(protectedGui) == "Instance" then
			table.insert(guiParents, protectedGui)
		end
	end
	table.insert(guiParents, CoreGui)

	local mounted = false
	local mountError = nil
	for _, guiParent in ipairs(guiParents) do
		local success, err = pcall(function()
			gui.Parent = guiParent
		end)
		if success and gui.Parent == guiParent then
			mounted = true
			break
		end
		gui.Parent = nil
		mountError = err
	end
	if not mounted then
		local message = "[NULLSCAPE] Unable to show the login window: " .. tostring(mountError)
		warn(message)
		if typeof(messagebox) == "function" then
			pcall(messagebox, message, "NULLSCAPE Login", 0)
		end
		error(message, 0)
	end
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()

	return {
		Gui = gui,
		Status = status,
		SetAuthorizationUrl = function(url)
			authorizeUrl = tostring(url or "")
			if typeof(setclipboard or toclipboard) ~= "function" then
				showManualLink(false)
			end
		end,
		CopyAuthorizationUrl = function()
			return tryCopyAuthorizeUrl()
		end,
		ShowManualAuthorizationUrl = function()
			showManualLink(true)
		end,
		SetHint = function(text)
			hint.Text = tostring(text or "")
		end,
		SetRecoveryCode = function(code)
			local value = tostring(code or "")
			if value ~= "" then
				hint.Text = "Recovery: " .. value .. " (save only if Roblox closes)"
			end
		end,
		ConsumeRecoveryCode = function()
			local value = queuedRecoveryCode
			queuedRecoveryCode = nil
			return value
		end,
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

local authState, loadedStorageMode = readAuthState()
authStorageMode = loadedStorageMode or authStorageMode
authState.client_token = typeof(authState.client_token) == "string" and authState.client_token or newClientToken()
writeAuthState(authState)

if authStorageMode == "persistent" then
	view.SetHint("Session storage: persistent.")
else
	view.SetHint("Session storage: runtime only; keep Roblox open during approval.")
end

local function setStatus(text)
	view.Status.Text = tostring(text)
end

local function clearPendingAuthentication()
	authState.pending_auth = nil
	writeAuthState(authState)
end

local function clearSession()
	authState.session_token = nil
	authState.expires_at = nil
	writeAuthState(authState)
end

local function verifySavedSession()
	if typeof(authState.session_token) ~= "string" then
		return false, "MISSING_SESSION"
	end
	local result, verifyError = postWithRetry("/v1/session/verify", {
		session_token = authState.session_token,
		client_token = authState.client_token,
		device_label = DEVICE_LABEL,
	}, 3)
	if result and result.valid == true then
		authState.expires_at = result.expires_at
		writeAuthState(authState)
		return true
	end
	return false, verifyError or "SESSION_VERIFY_FAILED"
end

local function showPendingAuthentication(pending, resumed)
	view.SetAuthorizationUrl(pending.authorize_url)
	view.SetRecoveryCode(pending.recovery_code)
	if resumed then
		setStatus("Resuming Discord approval...")
		return
	end
	setStatus("Open the Discord link and approve access.")
	if view.CopyAuthorizationUrl() then
		setStatus("Discord link copied. Open it and approve access.")
	else
		view.ShowManualAuthorizationUrl()
		setStatus("Copy the Discord link, then approve access in your browser.")
	end
end

local function acceptSession(result)
	authState.session_token = result.session_token
	authState.expires_at = result.expires_at
	authState.pending_auth = nil
	writeAuthState(authState)
	return true
end

local function recoverAuthentication(recoveryCode)
	local result, recoveryError = postWithRetry("/v1/auth/recover", {
		recovery_code = recoveryCode,
		client_token = authState.client_token,
		device_label = DEVICE_LABEL,
	}, 3)
	if result and result.status == "approved" and typeof(result.session_token) == "string" then
		setStatus("Login recovered on this device.")
		return acceptSession(result)
	end
	return false, recoveryError or "RECOVERY_FAILED"
end

local function pollPendingAuthentication(pending, resumed)
	showPendingAuthentication(pending, resumed)
	local delaySeconds = math.max(tonumber(pending.poll_after_seconds) or 4, 4)
	local networkRetrySeconds = delaySeconds

	while os.time() < tonumber(pending.expires_at) do
		local recoveryCode = view.ConsumeRecoveryCode()
		if recoveryCode then
			local recovered, recoveryError = recoverAuthentication(recoveryCode)
			if recovered then
				return true
			end
			if recoveryError == "DEVICE_LIMIT_REACHED" then
				return false, recoveryError
			end
			if recoveryError == "DEVICE_TRANSFER_COOLDOWN" then
				return false, recoveryError
			end
			setStatus("Recovery code is invalid, expired, or already used.")
		end
		local result, statusError, statusCode = post("/v1/auth/status", {
			request_token = pending.request_token,
			client_token = authState.client_token,
			device_label = DEVICE_LABEL,
		})
		if result and result.status == "approved" and typeof(result.session_token) == "string" then
			return acceptSession(result)
		end

		if result and result.status == "pending" then
			delaySeconds = math.max(tonumber(result.poll_after_seconds) or 4, 4)
			networkRetrySeconds = delaySeconds
		elseif statusError then
			if isTerminalAuthenticationError(statusError) then
				clearPendingAuthentication()
				return false, statusError
			end
			if statusError == "AUTH_REQUEST_NOT_FOUND" then
				clearPendingAuthentication()
				return false, statusError
			end
			if isTransientRequestError(statusError, statusCode) then
				setStatus("Connection interrupted. Login will resume automatically...")
				networkRetrySeconds = math.min(math.max(networkRetrySeconds * 1.5, 4), POLL_RETRY_MAX_SECONDS)
				delaySeconds = networkRetrySeconds
			else
				clearPendingAuthentication()
				return false, statusError
			end
		end

		task.wait(delaySeconds)
	end

	clearPendingAuthentication()
	return false, "AUTH_TIMEOUT"
end

local function resumePendingAuthentication()
	local pending = authState.pending_auth
	if typeof(pending) ~= "table" then
		return false, nil, false
	end
	if typeof(pending.request_token) ~= "string"
		or typeof(pending.authorize_url) ~= "string"
		or tonumber(pending.expires_at) == nil
	then
		clearPendingAuthentication()
		return false, "INVALID_PENDING_AUTH", false
	end
	if os.time() >= tonumber(pending.expires_at) then
		clearPendingAuthentication()
		return false, "AUTH_TIMEOUT", false
	end

	local resumed, resumeError = pollPendingAuthentication(pending, true)
	return resumed, resumeError, true
end

local function authenticate()
	local sessionVerified, verifyError = verifySavedSession()
	if sessionVerified then
		return true
	end
	if typeof(authState.session_token) == "string" and not isTerminalSessionError(verifyError) then
		setStatus("Saved login could not be checked; continuing with saved session.")
		return true
	end
	if typeof(authState.session_token) == "string" then
		clearSession()
	end

	local resumed, resumeError, hadPending = resumePendingAuthentication()
	if resumed then
		return true
	end
	if hadPending and isTerminalAuthenticationError(resumeError) then
		return false, resumeError
	end

	local started, startError = postWithRetry("/v1/auth/start", {
		client_token = authState.client_token,
		device_label = DEVICE_LABEL,
	}, 3)
	if not started then
		return false, startError
	end

	local now = os.time()
	authState.pending_auth = {
		request_token = started.request_token,
		authorize_url = tostring(started.authorize_url or ""),
		recovery_code = tostring(started.recovery_code or ""),
		expires_at = now + math.max(tonumber(started.expires_in) or 600, 1),
		poll_after_seconds = math.max(tonumber(started.poll_after_seconds) or 4, 4),
	}
	writeAuthState(authState)

	return pollPendingAuthentication(authState.pending_auth, false)
end

local authenticated, authError = authenticate()
if not authenticated then
	setStatus("Login failed: " .. tostring(authError))
	error("[NULLSCAPE] Authentication failed: " .. tostring(authError), 0)
end

setStatus("Downloading protected runtime...")
local function fetchBundle()
	return postWithRetry("/v1/source/bundle", {
		session_token = authState.session_token,
		client_token = authState.client_token,
		device_label = DEVICE_LABEL,
	}, REQUEST_RETRY_ATTEMPTS)
end

local bundle, bundleError = fetchBundle()
if (not bundle or typeof(bundle.sources) ~= "table") and isTerminalSessionError(bundleError) then
	clearSession()
	setStatus("Saved login expired. Reconnecting Discord...")
	local reauthenticated, reauthError = authenticate()
	if not reauthenticated then
		setStatus("Login failed: " .. tostring(reauthError))
		error("[NULLSCAPE] Authentication failed: " .. tostring(reauthError), 0)
	end
	setStatus("Downloading protected runtime...")
	bundle, bundleError = fetchBundle()
end
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
