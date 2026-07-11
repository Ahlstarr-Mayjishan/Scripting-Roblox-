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

local function collectManifestMenus(manifest)
	local menus = normalizeList(manifest and (manifest.MenuChanges or manifest.menuChanges))
	local files = manifest and (manifest.Files or manifest.files)
	if typeof(files) == "table" then
		for _, fileInfo in ipairs(files) do
			if typeof(fileInfo) == "table" then
				for _, menuName in ipairs(normalizeList(fileInfo.Menu or fileInfo.menu or fileInfo.MenuChanges or fileInfo.menuChanges)) do
					addUnique(menus, menuName)
				end
			end
		end
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

function Updater:fetchText(pathOrUrl)
	local url = tostring(pathOrUrl or "")
	if not string.find(url, "^https?://") then
		url = self.GithubRawRoot .. url
	end
	url = encodePath(url)
	local ok, result = pcall(function()
		return game:HttpGet(url)
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

function Updater:installFile(fileInfo, changes, backups)
	local path = fileInfo.Path or fileInfo.path
	if typeof(path) ~= "string" or path == "" then
		return false, "Missing file path"
	end
	local sourcePath = fileInfo.Url or fileInfo.url or path
	local source, err = self:fetchText(sourcePath)
	if not source then
		return false, "Download failed for " .. path .. ": " .. tostring(err)
	end
	local expectedHash = fileInfo.Sha256 or fileInfo.sha256 or fileInfo.Hash or fileInfo.hash
	if expectedHash and expectedHash ~= "" then
		local actualHash = getHash(source)
		if not actualHash then
			return false, "Hash check unavailable for " .. path
		end
		if actualHash ~= string.lower(tostring(expectedHash)) then
			return false, "Hash mismatch for " .. path
		end
	end
	if sameContent(path, source) then
		return true, "unchanged"
	end

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

	table.insert(changes.Files, path)
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

function Updater:restartAfterInstall(changes)
	local client = self.Client
	if client and typeof(client.InvalidateModulePrefix) == "function" then
		client:InvalidateModulePrefix("NULLSCAPE/")
	end
	if client and typeof(client.PrepareForRuntimeUpdate) == "function" then
		pcall(function()
			client:PrepareForRuntimeUpdate("RuntimeUpdate")
		end)
	end
	if client and typeof(client.HotRestart) == "function" then
		client:HotRestart("RuntimeUpdate")
	else
		notify("Runtime Updater", "Update installed. Reload UI to use the new code.", 8)
	end
end

function Updater:checkAndInstall(manual)
	if checking then
		if manual then
			notify("Runtime Updater", "Update check is already running", 4)
		end
		return false
	end
	checking = true

	local ok, result = pcall(function()
		if not (writefile and readfile and isfile) then
			notify("Runtime Updater", "Executor file APIs are required for hot update", 7)
			return false
		end

		local manifest, err = self:fetchManifest()
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

		local manifestMenus = collectManifestMenus(manifest)
		local safe, blockers = isSafeToInstall(self.Client, manifestMenus)
		if not safe then
			local changedText = #manifestMenus > 0 and joinShort(manifestMenus, 5) or "Code modules"
			local blockerText = joinShort(blockers, 4)
			notify(
				"Runtime Update Available",
				string.format("Changed: %s | Turn off: %s", changedText, blockerText),
				10
			)
			return false
		end

		local changes = {
			Version = manifest.Version or manifest.version or "unknown",
			Files = {},
			Menus = manifestMenus,
		}
		local backups = {}

		for _, fileInfo in ipairs(files) do
			if typeof(fileInfo) == "table" then
				local installed, installState = self:installFile(fileInfo, changes, backups)
				if not installed then
					self:rollback(backups)
					notify("Runtime Updater", tostring(installState) .. " | rollback done", 8)
					return false
				end
			end
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
		writeJson(self.StateFile, self.State)

		local menuText = #changes.Menus > 0 and joinShort(changes.Menus, 6) or "Code modules"
		notify(
			"Runtime Updated",
			string.format("Version %s | Changed: %s", tostring(changes.Version), menuText),
			9
		)

		self:restartAfterInstall(changes)
		return true
	end)

	checking = false
	if not ok then
		notify("Runtime Updater", "Update failed: " .. tostring(result), 8)
		return false
	end
	return result == true
end

function Updater:CleanUp()
	self.Destroyed = true
end

function Updater:Destroy()
	self:CleanUp()
end

return Updater
