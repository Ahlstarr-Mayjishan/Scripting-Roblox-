--!nocheck
--[[
	NULLSCAPE - Native Choice Reroll
	Finds the native reroll prompt and verifies each refresh before another use.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChoiceReroll = {}

local REFRESH_TIMEOUT = 2
local REMAINING_NAMES = {
	"Rerolls",
	"RerollsLeft",
	"RerollCount",
	"RemainingRerolls",
	"Remaining",
	"UsesLeft",
}

local pendingSignature = nil
local pendingSince = 0
local pendingRemaining = nil
local pendingCategory = nil
local exhaustedSignature = nil
local exhaustedRemaining = nil
local exhaustedCategories = {}
local observedUses = 0
local requestedUses = 0
local cachedSelectFolder = nil
local cachedSelectDescendants = nil
local cachedSelectAt = -math.huge
local cachedBroadFolder = nil
local cachedBroadRemaining = nil
local cachedBroadAt = -math.huge
local BROAD_SCAN_CACHE_INTERVAL = 0.35

local function containsReroll(value)
	return string.find(string.lower(tostring(value or "")), "reroll", 1, true) ~= nil
end

local function categoryKey(category)
	return string.lower(tostring(category or ""))
end

local function getRerollCategory(root, prompt, boundary)
	local parts = {
		tostring(prompt and prompt.ActionText or ""),
		tostring(prompt and prompt.ObjectText or ""),
	}
	local current = root or prompt
	while current and current ~= workspace and current ~= boundary do
		parts[#parts + 1] = current.Name
		current = current.Parent
	end
	local text = string.lower(table.concat(parts, " "))
	if string.find(text, "greater", 1, true) and string.find(text, "curse", 1, true) then
		return "Greater Curses"
	end
	if string.find(text, "enemy", 1, true) then
		return "Enemies"
	end
	if string.find(text, "curse", 1, true) then
		return "Curses"
	end
	return nil
end

local function belongsToReroll(root, prompt)
	if containsReroll(prompt and prompt.ActionText) or containsReroll(prompt and prompt.ObjectText) then
		return true
	end

	local current = root or prompt
	while current and current ~= workspace do
		if containsReroll(current.Name) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function parseRemainingText(value)
	local text = tostring(value or "")
	local amount = string.match(text, "[Rr]erolls?%s*[:xX%(]?%s*(%d+)")
		or string.match(text, "(%d+)%s*[xX]?%s*[Rr]erolls?")
		or string.match(text, "[Rr]erolls?[^%d]*(%d+)%s*/%s*%d+")
	return amount and tonumber(amount) or nil
end

local function isRerollRelated(instance, boundary)
	local current = instance
	while current and current ~= boundary do
		if containsReroll(current.Name) then
			return true
		end
		current = current.Parent
	end
	return boundary ~= nil and containsReroll(boundary.Name)
end

local function readRemainingFromInstance(instance, includeDescendants)
	if not instance then
		return nil
	end

	for _, name in ipairs(REMAINING_NAMES) do
		local attribute = tonumber(instance:GetAttribute(name))
		if attribute then
			return math.max(0, math.floor(attribute))
		end
	end
	for name, value in pairs(instance:GetAttributes()) do
		if containsReroll(name) and tonumber(value) then
			return math.max(0, math.floor(tonumber(value)))
		end
	end

	local instances = includeDescendants and instance:GetDescendants() or instance:GetChildren()
	for _, descendant in ipairs(instances) do
		local related = isRerollRelated(descendant, instance)
		if related then
			if descendant:IsA("ValueBase") and tonumber(descendant.Value) then
				return math.max(0, math.floor(tonumber(descendant.Value)))
			end
		end
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			local amount = parseRemainingText(descendant.Text)
			if amount and (related or containsReroll(descendant.Text)) then
				return math.max(0, math.floor(amount))
			end
		end
	end
	return nil
end

local function readRemaining(root, prompt, selectFolder)
	local current = prompt
	while current and current ~= workspace and current ~= selectFolder do
		local amount = readRemainingFromInstance(current, false)
		if amount ~= nil then
			return amount
		end
		current = current.Parent
	end
	local now = os.clock()
	if selectFolder ~= cachedBroadFolder or now - cachedBroadAt >= BROAD_SCAN_CACHE_INTERVAL then
		cachedBroadFolder = selectFolder
		cachedBroadAt = now
		cachedBroadRemaining = nil
		for _, source in ipairs({
			{ Instance = selectFolder, Descendants = true },
			{ Instance = Players.LocalPlayer, Descendants = true },
			{ Instance = ReplicatedStorage, Descendants = false },
		}) do
			local amount = readRemainingFromInstance(source.Instance, source.Descendants)
			if amount ~= nil then
				cachedBroadRemaining = amount
				break
			end
		end
	end
	if cachedBroadRemaining ~= nil then
		return cachedBroadRemaining
	end

	local text = table.concat({
		tostring(prompt and prompt.ActionText or ""),
		tostring(prompt and prompt.ObjectText or ""),
		tostring(root and root.Name or ""),
	}, " ")
	return parseRemainingText(text)
end

local function getPromptPart(root, prompt)
	local parent = prompt and prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent
	end
	if root and root:IsA("BasePart") then
		return root
	end
	return root and root:FindFirstChildWhichIsA("BasePart", true)
end

function ChoiceReroll.find(selectFolder, hrp, signature, category)
	if not (selectFolder and hrp) then
		return nil
	end
	if exhaustedCategories[categoryKey(category)] == true then
		return nil
	end

	local now = os.clock()
	if selectFolder ~= cachedSelectFolder or now - cachedSelectAt >= BROAD_SCAN_CACHE_INTERVAL then
		cachedSelectFolder = selectFolder
		cachedSelectDescendants = selectFolder:GetDescendants()
		cachedSelectAt = now
	end
	for _, descendant in ipairs(cachedSelectDescendants or {}) do
		if descendant:IsA("ProximityPrompt") and belongsToReroll(descendant.Parent, descendant) then
			local prompt = descendant
			local root = prompt.Parent
			local rerollCategory = getRerollCategory(root, prompt, selectFolder)
			if category ~= nil and rerollCategory ~= nil and rerollCategory ~= category then
				continue
			end
			local part = getPromptPart(root, prompt)
			local remaining = readRemaining(root, prompt, selectFolder)
			if remaining ~= nil and remaining <= 0 then
				exhaustedCategories[categoryKey(rerollCategory or category)] = true
				continue
			end
			if signature ~= nil and signature == exhaustedSignature then
				if remaining ~= nil and exhaustedRemaining ~= nil and remaining < exhaustedRemaining then
					exhaustedSignature = nil
					exhaustedRemaining = nil
				else
					continue
				end
			end
			if
				part
				and prompt.Enabled == true
				and prompt:GetAttribute("Active") ~= false
				and (remaining == nil or remaining > 0)
			then
				return {
					Root = root,
					Prompt = prompt,
					Part = part,
					Category = "Reroll",
					ChoiceName = "Reroll",
					Distance = (part.Position - hrp.Position).Magnitude,
					Key = "REROLL|" .. prompt:GetFullName(),
					Remaining = remaining,
					RerollCategory = rerollCategory or category,
				}
			end
		end
	end
	return nil
end

function ChoiceReroll.getSignature(candidates)
	local parts = {}
	for _, candidate in ipairs(candidates) do
		parts[#parts + 1] = table.concat({
			tostring(candidate.Category or ""),
			tostring(candidate.ChoiceName or ""),
			tostring(candidate.ItemIndex or ""),
		}, "|")
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function ChoiceReroll.isWaitingForRefresh(signature)
	if not pendingSignature then
		return false
	end
	if signature == "" and os.clock() - pendingSince < REFRESH_TIMEOUT then
		return true
	end
	if signature ~= pendingSignature then
		if pendingRemaining ~= nil and pendingRemaining <= 1 then
			exhaustedCategories[categoryKey(pendingCategory)] = true
		end
		pendingSignature = nil
		pendingSince = 0
		pendingRemaining = nil
		pendingCategory = nil
		exhaustedSignature = nil
		exhaustedRemaining = nil
		observedUses += 1
		return false
	end
	if os.clock() - pendingSince < REFRESH_TIMEOUT then
		return true
	end
	pendingSignature = nil
	pendingSince = 0
	exhaustedSignature = signature
	exhaustedRemaining = pendingRemaining
	exhaustedCategories[categoryKey(pendingCategory)] = true
	pendingRemaining = nil
	pendingCategory = nil
	return false
end

function ChoiceReroll.markFired(signature, remaining, category)
	pendingSignature = signature
	pendingSince = os.clock()
	pendingRemaining = tonumber(remaining)
	pendingCategory = category
	requestedUses += 1
end

function ChoiceReroll.getDetail(category, remaining)
	local suffix = remaining and string.format(" | %d remaining", math.max(0, remaining - 1))
		or string.format(" | attempt %d (%d refreshes confirmed)", requestedUses, observedUses)
	return tostring(category or "Choices") .. suffix
end

function ChoiceReroll.reset()
	pendingSignature = nil
	pendingSince = 0
	pendingRemaining = nil
	pendingCategory = nil
	exhaustedSignature = nil
	exhaustedRemaining = nil
	table.clear(exhaustedCategories)
	observedUses = 0
	requestedUses = 0
	cachedSelectFolder = nil
	cachedSelectDescendants = nil
	cachedSelectAt = -math.huge
	cachedBroadFolder = nil
	cachedBroadRemaining = nil
	cachedBroadAt = -math.huge
end

return ChoiceReroll
