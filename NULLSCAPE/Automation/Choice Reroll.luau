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
local exhaustedSignature = nil
local exhaustedRemaining = nil
local observedUses = 0
local requestedUses = 0

local function containsReroll(value)
	return string.find(string.lower(tostring(value or "")), "reroll", 1, true) ~= nil
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
	for _, source in ipairs({
		{ Instance = selectFolder, Descendants = true },
		{ Instance = Players.LocalPlayer, Descendants = true },
		{ Instance = ReplicatedStorage, Descendants = false },
	}) do
		local amount = readRemainingFromInstance(source.Instance, source.Descendants)
		if amount ~= nil then
			return amount
		end
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

function ChoiceReroll.find(selectFolder, hrp, signature)
	if not (selectFolder and hrp) then
		return nil
	end

	for _, descendant in ipairs(selectFolder:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and belongsToReroll(descendant.Parent, descendant) then
			local prompt = descendant
			local root = prompt.Parent
			local part = getPromptPart(root, prompt)
			local remaining = readRemaining(root, prompt, selectFolder)
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
		pendingSignature = nil
		pendingSince = 0
		pendingRemaining = nil
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
	pendingRemaining = nil
	return false
end

function ChoiceReroll.markFired(signature, remaining)
	pendingSignature = signature
	pendingSince = os.clock()
	pendingRemaining = tonumber(remaining)
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
	exhaustedSignature = nil
	exhaustedRemaining = nil
	observedUses = 0
	requestedUses = 0
end

return ChoiceReroll
