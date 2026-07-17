--!nocheck

local HttpService = game:GetService("HttpService")

local Updater = {
	Initialized = false,
	AutoUpdateEnabled = false,
	SilentInstall = false,
	CheckInterval = 180,
	GithubRawRoot = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/",
	ManifestPath = "NULLSCAPE/update_manifest.json",
	StateFolder = "NULLSCAPE",
	StateFile = "NULLSCAPE/update_state.json",
	Destroyed = false,
	OperationGeneration = 0,
	FetchToken = nil,
}

local checking = false

local function notify(title, content, duration)
	if getgenv().Rayfield and typeof(getgenv().Rayfield.Notify) == "function" then
		pcall(function()
			getgenv().Rayfield:Notify({
				Title = title,
				Content = content,
				Duration = duration or 6,
			})
		end)
	end
end

local function encodePath(path)
	return tostring(path or ""):gsub(" ", "%%20")
end

local function readJson(path)
	if not (readfile and isfile and isfile(path)) then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	return ok and typeof(decoded) == "table" and decoded or {}
end

local function writeJson(path, data)
	if not (writefile and HttpService) then
		return false
	end
	local ok = pcall(function()
		writefile(path, HttpService:JSONEncode(data or {}))
	end)
	return ok == true
end

local function ensureFolder(folder)
	if makefolder and not (isfolder and isfolder(folder)) then
		pcall(makefolder, folder)
	end
end

local function ensureParentFolders(path)
	if not makefolder then
		return
	end
	local normalized = tostring(path or ""):gsub("\\", "/")
	local current = ""
	for folder in string.gmatch(normalized, "([^/]+)/") do
		current = current == "" and folder or (current .. "/" .. folder)
		if not (isfolder and isfolder(current)) then
			pcall(makefolder, current)
		end
	end
end

local function getHash(source)
	if typeof(source) ~= "string" then
		return nil
	end
	if crypt and typeof(crypt.hash) == "function" then
		local ok, result = pcall(function()
			return crypt.hash(source, "sha256")
		end)
		if ok and typeof(result) == "string" then
			return string.lower(result)
		end
	end
	if syn and syn.crypt and typeof(syn.crypt.hash) == "function" then
		local ok, result = pcall(function()
			return syn.crypt.hash(source, "sha256")
		end)
		if ok and typeof(result) == "string" then
			return string.lower(result)
		end
	end
	return nil
end

local function sameContent(path, source)
	if not (isfile and readfile and isfile(path)) then
		return false
	end
	local ok, current = pcall(readfile, path)
	return ok and current == source
end

local function getPendingFiles(files)
	if not (isfile and readfile) then
		return nil, "Executor file APIs are unavailable"
	end

	local pending = {}
	for _, fileInfo in ipairs(files) do
		if typeof(fileInfo) == "table" then
			local path = fileInfo.Path or fileInfo.path
			local expectedHash = fileInfo.Sha256 or fileInfo.sha256 or fileInfo.Hash or fileInfo.hash
			if typeof(path) ~= "string" or path == "" then
				return nil, "Missing local module path"
			end
			if typeof(expectedHash) ~= "string" or expectedHash == "" then
				return nil, "Missing manifest hash: " .. path
			end

			if not isfile(path) then
				table.insert(pending, fileInfo)
			else
				local readOk, source = pcall(readfile, path)
				if not readOk or typeof(source) ~= "string" then
					return nil, "Unreadable local module: " .. path
				end

				local actualHash = getHash(source)
				if not actualHash then
					return nil, "Hash check unavailable"
				end
				if actualHash ~= string.lower(expectedHash) then
					table.insert(pending, fileInfo)
				end
			end
		end
	end

	return pending
end

local function normalizeList(value)
	local list = {}
	if typeof(value) ~= "table" then
		return list
	end
	for _, item in ipairs(value) do
		if typeof(item) == "string" then
			table.insert(list, item)
		end
	end
	return list
end

local function compareVersions(left, right)
	local leftParts = {}
	local rightParts = {}
	for value in string.gmatch(tostring(left or ""), "%d+") do
		table.insert(leftParts, tonumber(value) or 0)
	end
	for value in string.gmatch(tostring(right or ""), "%d+") do
		table.insert(rightParts, tonumber(value) or 0)
	end
	if #leftParts == 0 or #rightParts == 0 then
		return nil
	end

	for index = 1, math.max(#leftParts, #rightParts) do
		local leftValue = leftParts[index] or 0
		local rightValue = rightParts[index] or 0
		if leftValue ~= rightValue then
			return leftValue < rightValue and -1 or 1
		end
	end
	return 0
end

local function joinShort(list, maxItems)
	local limit = maxItems or 6
	local out = {}
	for index, item in ipairs(list) do
		if index > limit then
			table.insert(out, "+" .. tostring(#list - limit) .. " more")
			break
		end
		table.insert(out, tostring(item))
	end
	return table.concat(out, ", ")
end

local function getAutomationController(client)
	return client
		and client.Modules
		and client.Modules.AutomationController
end

local function addUnique(list, value)
	if typeof(value) == "string" and value ~= "" and not table.find(list, value) then
		table.insert(list, value)
	end
end

local function collectFileMenus(files, fallbackMenus)
	local menus = {}
	if typeof(files) == "table" then
		for _, fileInfo in ipairs(files) do
			if typeof(fileInfo) == "table" then
				for _, menuName in ipairs(normalizeList(fileInfo.Menu or fileInfo.menu or fileInfo.MenuChanges or fileInfo.menuChanges)) do
					addUnique(menus, menuName)
				end
			end
		end
	end
	if #menus == 0 then
		menus = normalizeList(fallbackMenus)
	end
	return menus
end

local function menuMatches(menus, names)
	for _, menuName in ipairs(menus or {}) do
		local lower = string.lower(tostring(menuName))
		for _, name in ipairs(names) do
			if string.find(lower, string.lower(name), 1, true) then
				return true
			end
		end
	end
	return false
end

local function getBlockingFeatures(client, menus)
	local controller = getAutomationController(client)
	local blockers = {}

	if controller then
		if controller.GiftFarmEnabled == true and menuMatches(menus, { "Automation", "Gift Farm", "Pipelining" }) then
			addUnique(blockers, "Gift Farm")
		end
		if controller.PylonActivatorEnabled == true and menuMatches(menus, { "Automation", "Pylon" }) then
			addUnique(blockers, "Auto Activate Pylons")
		end
		if controller.AutoChooseThingsEnabled == true and menuMatches(menus, { "Automation", "Auto Choose" }) then
			addUnique(blockers, "Auto Choose Things")
		end
	end

	local accessibility = client and client.Modules and client.Modules.AccessibilityController
	if accessibility and menuMatches(menus, { "Accessibility", "Grapple", "Rail" }) then
		if accessibility.GrappleAssistEnabled == true then
			addUnique(blockers, "Grapple Assist")
		end
		if accessibility.RailAssistSuiteEnabled == true or accessibility.RailAutoEnabled == true then
			addUnique(blockers, "Rail Assist")
		end
	end

	local entities = client and client.Modules and client.Modules.EntitiesController
	if entities and menuMatches(menus, { "Entities", "Immunity", "Kolona", "Auto QTE" }) then
		if entities.StatusImmunityEnabled == true or entities.ImmunityEnabled == true then
			addUnique(blockers, "Entities/Immunity")
		end
		if entities.KolonaAutoQTEEnabled == true and menuMatches(menus, { "Kolona", "Auto QTE" }) then
			addUnique(blockers, "Kolona Auto QTE")
		end
	end

	return blockers
end

local function isSafeToInstall(client, menus)
	local blockers = getBlockingFeatures(client, menus or {})
	if #blockers > 0 then
		return false, blockers
	end
	return true
end

function Updater:initialize(client, options)
	if self.Initialized then
		return true
	end
	self.Client = client
	self.Destroyed = false
	self.OperationGeneration += 1
	options = options or {}
	self.GithubRawRoot = options.GithubRawRoot or self.GithubRawRoot
	self.ManifestPath = options.ManifestPath or self.ManifestPath
	ensureFolder(self.StateFolder)
	self.State = readJson(self.StateFile)
	self.AutoUpdateEnabled = self.State.AutoUpdateEnabled == true
	self.SilentInstall = self.State.SilentInstall == true
	self.Initialized = true

	task.spawn(function()
		while not self.Destroyed do
			task.wait(self.CheckInterval)
			if self.AutoUpdateEnabled == true then
				self:checkAndInstall(false)
			end
		end
	end)

	return true
end

function Updater:setAutoUpdateEnabled(value)
	self.AutoUpdateEnabled = value == true
	self.State = self.State or {}
	self.State.AutoUpdateEnabled = self.AutoUpdateEnabled
	writeJson(self.StateFile, self.State)
	notify("Runtime Updater", self.AutoUpdateEnabled and "Auto update enabled" or "Auto update disabled", 4)
	if self.AutoUpdateEnabled then
		task.spawn(function()
			self:checkAndInstall(false)
		end)
	end
end

function Updater:setSilentInstall(value)
	self.SilentInstall = value == true
	self.State = self.State or {}
	self.State.SilentInstall = self.SilentInstall
	writeJson(self.StateFile, self.State)
	notify("Runtime Updater", self.SilentInstall and "Silent install enabled" or "Silent install disabled", 4)
end

function Updater:fetchText(pathOrUrl, cacheToken)
	local url = tostring(pathOrUrl or "")
	if not string.find(url, "^https?://") then
		url = self.GithubRawRoot .. url
	end
	url = encodePath(url)
	local token = cacheToken or self.FetchToken
	if typeof(token) == "string" and token ~= "" then
		local separator = string.find(url, "?", 1, true) and "&" or "?"
		url = url .. separator .. "nullscape_fetch=" .. HttpService:UrlEncode(token)
	end
	local ok, result = pcall(function()
		local httpGet = (game :: any).HttpGet
		return httpGet(game, url)
	end)
	if not ok or typeof(result) ~= "string" or #result == 0 then
		return nil, tostring(result)
	end
	return result
end

function Updater:fetchManifest()
	local source, err = self:fetchText(self.ManifestPath)
	if not source then
		return nil, err
	end
	local ok, manifest = pcall(function()
		return HttpService:JSONDecode(source)
	end)
	if not ok or typeof(manifest) ~= "table" then
		return nil, "Invalid manifest"
	end
	return manifest
end

function Updater:stageFile(fileInfo, operationGeneration)
	local path = fileInfo.Path or fileInfo.path
	if typeof(path) ~= "string" or path == "" then
		return false, "Missing file path"
	end
	local sourcePath = fileInfo.Url or fileInfo.url or path
	local expectedHash = fileInfo.Sha256 or fileInfo.sha256 or fileInfo.Hash or fileInfo.hash
	if typeof(expectedHash) ~= "string" or expectedHash == "" then
		return false, "Missing SHA-256 for " .. path
	end
	expectedHash = string.lower(expectedHash)

	local source = nil
	local lastError = nil
	for attempt = 1, 3 do
		if self.Destroyed or self.OperationGeneration ~= operationGeneration then
			return false, "Update cancelled"
		end

		local fetchToken = tostring(self.FetchToken or operationGeneration)
			.. "-stage-"
			.. tostring(attempt)
			.. "-"
			.. HttpService:GenerateGUID(false)
		local candidate, fetchError = self:fetchText(sourcePath, fetchToken)
		if candidate then
			local candidateHash = getHash(candidate)
			if not candidateHash then
				return false, "Hash check unavailable for " .. path
			end
			if candidateHash == expectedHash then
				source = candidate
				break
			end
			lastError = "hash mismatch"
		else
			lastError = tostring(fetchError)
		end

		if attempt < 3 then
			task.wait(0.15 * attempt)
		end
	end

	if not source then
		return false, "Release source is not ready for " .. path .. ": " .. tostring(lastError)
	end

	return true, {
		FileInfo = fileInfo,
		Path = path,
		Source = source,
		ExpectedHash = expectedHash,
		Changed = not sameContent(path, source),
	}
end

function Updater:commitStagedFile(staged, changes, backups, operationGeneration)
	if self.Destroyed or self.OperationGeneration ~= operationGeneration then
		return false, "Update cancelled"
	end
	if staged.Changed ~= true then
		return true
	end

	local path = staged.Path
	local source = staged.Source

	local backup = nil
	if isfile and readfile and isfile(path) then
		local ok, current = pcall(readfile, path)
		if ok then
			backup = current
		end
	end
	table.insert(backups, {
		Path = path,
		Source = backup,
	})

	local ok, writeErr = pcall(function()
		ensureParentFolders(path)
		writefile(path, source)
	end)
	if not ok then
		return false, "Write failed for " .. path .. ": " .. tostring(writeErr)
	end

	local readOk, installedSource = pcall(readfile, path)
	local installedHash = readOk and getHash(installedSource) or nil
	if installedHash ~= staged.ExpectedHash then
		return false, "Post-write verification failed for " .. path
	end

	table.insert(changes.Files, path)
	local fileInfo = staged.FileInfo
	for _, menuName in ipairs(normalizeList(fileInfo.Menu or fileInfo.menu or fileInfo.MenuChanges or fileInfo.menuChanges)) do
		if not table.find(changes.Menus, menuName) then
			table.insert(changes.Menus, menuName)
		end
	end
	return true, "changed"
end

function Updater:rollback(backups)
	for index = #backups, 1, -1 do
		local backup = backups[index]
		if backup and backup.Path then
			pcall(function()
				if backup.Source ~= nil then
					writefile(backup.Path, backup.Source)
				elseif delfile and isfile and isfile(backup.Path) then
					delfile(backup.Path)
				end
			end)
		end
	end
end

function Updater:restartAfterInstall()
	if self.Destroyed then
		return false
	end

	local client = self.Client
	if client and typeof(client.HotRestart) == "function" then
		return client:HotRestart("RuntimeUpdate")
	else
		if client and typeof(client.PrepareForRuntimeUpdate) == "function" then
			pcall(function()
				client:PrepareForRuntimeUpdate("RuntimeUpdate")
			end)
		end
		notify("Runtime Updater", "Update installed. Reload UI to use the new code.", 8)
	end
	return false
end

function Updater:checkAndInstall(manual)
	if self.Destroyed then
		return false
	end
	if checking then
		if manual then
			notify("Runtime Updater", "Update check is already running", 4)
		end
		return false
	end
	checking = true
	local operationGeneration = self.OperationGeneration
	self.FetchToken = tostring(os.time()) .. "-" .. HttpService:GenerateGUID(false)
	local function isCurrent()
		return not self.Destroyed and self.OperationGeneration == operationGeneration
	end

	local ok, result = pcall(function()
		if not (writefile and readfile and isfile) then
			notify("Runtime Updater", "Executor file APIs are required for hot update", 7)
			return false
		end

		local manifest, err = self:fetchManifest()
		if not isCurrent() then
			return false
		end
		if not manifest then
			if manual then
				notify("Runtime Updater", "Manifest unavailable: " .. tostring(err), 6)
			end
			return false
		end

		local files = manifest.Files or manifest.files
		if typeof(files) ~= "table" then
			notify("Runtime Updater", "Manifest has no file list", 6)
			return false
		end
		local remoteVersion = tostring(manifest.Version or manifest.version or "unknown")
		local localManifest = readJson(self.ManifestPath)
		local localVersion = tostring(localManifest.Version or localManifest.version or "")
		local versionOrder = if localVersion ~= "" then compareVersions(remoteVersion, localVersion) else nil
		if versionOrder and versionOrder < 0 then
			if manual then
				notify("Runtime Updater", "Local release " .. localVersion .. " is newer than remote " .. remoteVersion, 5)
			end
			return true
		end

		local pendingFiles, pendingErr = getPendingFiles(files)
		if not isCurrent() then
			return false
		end
		if not pendingFiles then
			notify("Runtime Updater", tostring(pendingErr), 7)
			return false
		end

		if #pendingFiles == 0 then
			if not isCurrent() then
				return false
			end
			if not writeJson(self.ManifestPath, manifest) then
				notify("Runtime Updater", "Unable to store release manifest", 7)
				return false
			end
			self.LocalIntegrityVerifiedVersion = remoteVersion
			self.State = self.State or {}
			self.State.LastVersion = remoteVersion
			writeJson(self.StateFile, self.State)
			if manual then
				notify("Runtime Updater", "Already running release " .. remoteVersion, 5)
			end
			return true
		end

		local changedMenus = collectFileMenus(pendingFiles, manifest.MenuChanges or manifest.menuChanges)
		local safe, blockers = isSafeToInstall(self.Client, changedMenus)
		if not safe then
			local changedText = #changedMenus > 0 and joinShort(changedMenus, 5) or "Code modules"
			local blockerText = joinShort(blockers, 4)
			notify(
				"Runtime Update Available",
				string.format("Changed: %s | Turn off: %s", changedText, blockerText),
				10
			)
			return false
		end

		local changes = {
			Version = remoteVersion,
			Files = {},
			Menus = changedMenus,
		}
		local backups = {}
		local stagedFiles = {}

		for _, fileInfo in ipairs(pendingFiles) do
			if not isCurrent() then
				return false
			end
			if typeof(fileInfo) == "table" then
				local staged, stageResult = self:stageFile(fileInfo, operationGeneration)
				if not staged then
					if isCurrent() then
						notify("Runtime Updater", tostring(stageResult) .. " | local files unchanged", 8)
					end
					return false
				end
				table.insert(stagedFiles, stageResult)
			end
		end

		if not isCurrent() then
			return false
		end

		for _, stagedFile in ipairs(stagedFiles) do
			local installed, installError = self:commitStagedFile(
				stagedFile,
				changes,
				backups,
				operationGeneration
			)
			if not installed then
				self:rollback(backups)
				if isCurrent() then
					notify("Runtime Updater", tostring(installError) .. " | rollback done", 8)
				end
				return false
			end
		end

		if not writeJson(self.ManifestPath, manifest) then
			self:rollback(backups)
			notify("Runtime Updater", "Unable to store release manifest | rollback done", 8)
			return false
		end

		if #changes.Files == 0 then
			if manual then
				notify("Runtime Updater", "Already up to date (" .. tostring(changes.Version) .. ")", 5)
			end
			self.State = self.State or {}
			self.State.LastVersion = changes.Version
			writeJson(self.StateFile, self.State)
			return true
		end

		self.State = self.State or {}
		self.State.LastVersion = changes.Version
		self.State.LastUpdatedAt = os.time()
		self.LocalIntegrityVerifiedVersion = changes.Version
		writeJson(self.StateFile, self.State)
		if self.Client and typeof(self.Client.InvalidateModule) == "function" then
			for _, path in ipairs(changes.Files) do
				self.Client:InvalidateModule(path)
			end
		end

		local menuText = #changes.Menus > 0 and joinShort(changes.Menus, 6) or "Code modules"
		notify(
			"Runtime Updated",
			string.format("Version %s | Changed: %s", tostring(changes.Version), menuText),
			9
		)

		if not isCurrent() then
			return false
		end
		self:restartAfterInstall()
		return true
	end)

	checking = false
	self.FetchToken = nil
	if not ok then
		notify("Runtime Updater", "Update failed: " .. tostring(result), 8)
		return false
	end
	return result == true
end

function Updater:CleanUp()
	self.Destroyed = true
	self.OperationGeneration += 1
end

function Updater:Destroy()
	self:CleanUp()
end

return Updater
