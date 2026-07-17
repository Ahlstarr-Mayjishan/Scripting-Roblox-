--!nocheck
--[[
	NULLSCAPE - Native Choice Reroll
	Finds the native reroll prompt and verifies each refresh before another use.
]]

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

local function readRemaining(root, prompt, selectFolder)
	local current = prompt
	while current and current ~= workspace and current ~= selectFolder do
		for _, name in ipairs(REMAINING_NAMES) do
			local attribute = tonumber(current:GetAttribute(name))
			if attribute then
				return math.max(0, math.floor(attribute))
			end
			local value = current:FindFirstChild(name)
			if value and value:IsA("ValueBase") then
				local amount = tonumber(value.Value)
				if amount then
					return math.max(0, math.floor(amount))
				end
			end
		end
		current = current.Parent
	end

	local text = table.concat({
		tostring(prompt and prompt.ActionText or ""),
		tostring(prompt and prompt.ObjectText or ""),
		tostring(root and root.Name or ""),
	}, " ")
	local amount = string.match(text, "[Rr]erolls?%s*[:xX%(]?%s*(%d+)")
		or string.match(text, "(%d+)%s*[xX]?%s*[Rr]erolls?")
	return amount and tonumber(amount) or nil
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

function ChoiceReroll.find(selectFolder, hrp)
	if not (selectFolder and hrp) then
		return nil
	end

	for _, descendant in ipairs(selectFolder:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and belongsToReroll(descendant.Parent, descendant) then
			local prompt = descendant
			local root = prompt.Parent
			local part = getPromptPart(root, prompt)
			local remaining = readRemaining(root, prompt, selectFolder)
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
		observedUses += 1
		return false
	end
	if os.clock() - pendingSince < REFRESH_TIMEOUT then
		return true
	end
	pendingSignature = nil
	pendingSince = 0
	return false
end

function ChoiceReroll.markFired(signature)
	pendingSignature = signature
	pendingSince = os.clock()
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
	observedUses = 0
	requestedUses = 0
end

return ChoiceReroll
