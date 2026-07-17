--!nocheck
--[[
	NULLSCAPE - Native Choice Catalog
	Maps native ChoiceName keys to the user-facing names declared by index items.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChoiceCatalog = {}
local catalogs = {}
local loadCatalog

local RICH_TEXT_ENTITIES = {
	["&amp;"] = "&",
	["&apos;"] = "'",
	["&gt;"] = ">",
	["&lt;"] = "<",
	["&quot;"] = '"',
}

local function normalize(value)
	return string.lower(tostring(value or "")):gsub("[%s%p_]+", "")
end

local function cleanDisplayName(value)
	local display = tostring(value or "")
	display = display:gsub("<[bB][rR]%s*/?>", " ")
	display = display:gsub("<[^>]*>", "")
	display = display:gsub("&[%a]+;", function(entity)
		return RICH_TEXT_ENTITIES[string.lower(entity)] or entity
	end)
	display = display:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
	return display
end

local function getIndexModule(indexName)
	local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
	local core = sharedModules and sharedModules:FindFirstChild("Core")
	local indexRoot = core and core:FindFirstChild("Index")
	local indexModule = indexRoot and indexRoot:FindFirstChild(indexName)
	return indexModule and indexModule:IsA("ModuleScript") and indexModule or nil
end

local function getEnemyGroup(indexName, item)
	if indexName ~= "CurseIndex" and indexName ~= "GreaterCurseIndex" then
		return nil
	end
	local prerequisites = item and item.Prerequisites
	local enemies = prerequisites and prerequisites.Enemies
	local enemyKey = typeof(enemies) == "table" and enemies[1] or nil
	if typeof(enemyKey) ~= "string" or enemyKey == "" then
		return nil
	end

	local enemyCatalog = loadCatalog("EnemyIndex")
	return enemyCatalog.DisplayByKey[normalize(enemyKey)] or enemyKey
end

function loadCatalog(indexName)
	if catalogs[indexName] then
		return catalogs[indexName]
	end

	local catalog = {
		Entries = {},
		KeyByAlias = {},
		DisplayByKey = {},
	}
	local indexModule = getIndexModule(indexName)
	if not indexModule then
		return catalog
	end

	local loaded, index = pcall(require, indexModule)
	local items = loaded and typeof(index) == "table" and index.Items or {}
	for _, child in ipairs(indexModule:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name ~= "Template" then
			local key = child.Name
			local item = items[key]
			if typeof(item) ~= "table" then
				local itemLoaded, result = pcall(require, child)
				item = itemLoaded and typeof(result) == "table" and result or nil
			end
			local rawDisplay = tostring(item and item.Name or key)
			local display = cleanDisplayName(rawDisplay)
			if display == "" then
				display = key
			end
			local normalizedKey = normalize(key)
			catalog.KeyByAlias[normalizedKey] = normalizedKey
			catalog.KeyByAlias[normalize(rawDisplay)] = normalizedKey
			catalog.KeyByAlias[normalize(display)] = normalizedKey
			catalog.DisplayByKey[normalizedKey] = display
			catalog.Entries[#catalog.Entries + 1] = {
				Key = key,
				Display = display,
				Group = getEnemyGroup(indexName, item),
			}
		end
	end

	table.sort(catalog.Entries, function(left, right)
		local leftGroup = left.Group and ("0|" .. string.lower(left.Group)) or "1|"
		local rightGroup = right.Group and ("0|" .. string.lower(right.Group)) or "1|"
		if leftGroup ~= rightGroup then
			return leftGroup < rightGroup
		end
		return string.lower(left.Display) < string.lower(right.Display)
	end)
	catalogs[indexName] = catalog
	return catalog
end

function ChoiceCatalog.getDisplayOptions(indexName)
	local options = {}
	for _, entry in ipairs(loadCatalog(indexName).Entries) do
		if not table.find(options, entry.Display) then
			options[#options + 1] = entry.Display
		end
	end
	return options
end

function ChoiceCatalog.resolveKey(indexName, value)
	local normalized = normalize(value)
	return loadCatalog(indexName).KeyByAlias[normalized] or normalized
end

function ChoiceCatalog.toDisplaySelections(indexName, values)
	local catalog = loadCatalog(indexName)
	local selections = {}
	if typeof(values) ~= "table" then
		return selections
	end

	local function add(value)
		local key = catalog.KeyByAlias[normalize(value)]
		local display = key and catalog.DisplayByKey[key] or nil
		if display and display ~= "" and not table.find(selections, display) then
			selections[#selections + 1] = display
		end
	end
	for _, value in ipairs(values) do
		add(value)
	end
	for value, active in pairs(values) do
		if typeof(value) == "string" and active == true then
			add(value)
		end
	end
	return selections
end

return ChoiceCatalog
