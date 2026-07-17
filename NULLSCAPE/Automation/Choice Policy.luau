--!nocheck
--[[
	NULLSCAPE - Auto Choice Policy
	Separates native enemy, curse, and greater-curse policies. Upgrades bypass
	name policies because every affordable upgrade should be purchased.
]]

local ChoicePolicy = {}

local CATEGORY_FIELDS = {
	Enemies = {
		Whitelist = "EnemyChoiceWhitelist",
		Blacklist = "EnemyChoiceBlacklist",
	},
	Curses = {
		Whitelist = "CurseChoiceWhitelist",
		Blacklist = "CurseChoiceBlacklist",
	},
	["Greater Curses"] = {
		Whitelist = "GreaterCurseChoiceWhitelist",
		Blacklist = "GreaterCurseChoiceBlacklist",
	},
}

local function normalizeName(value)
	return string.lower(tostring(value or "")):gsub("[%s%p_]+", "")
end

local function buildNamePolicy(values)
	local selected, priority = {}, {}
	if typeof(values) ~= "table" then
		return selected, priority
	end

	for index, value in ipairs(values) do
		local key = normalizeName(value)
		if key ~= "" then
			selected[key] = true
			priority[key] = priority[key] or index
		end
	end
	for value, active in pairs(values) do
		if typeof(value) == "string" and active == true then
			selected[normalizeName(value)] = true
		end
	end
	return selected, priority
end

local function getCategoryPolicy(controller, category)
	local fields = CATEGORY_FIELDS[category]
	if not fields then
		return nil
	end

	local whitelist, whitelistPriority = buildNamePolicy(controller and controller[fields.Whitelist])
	local blacklist = buildNamePolicy(controller and controller[fields.Blacklist])
	return whitelist, whitelistPriority, blacklist
end

function ChoicePolicy.applyWithDecision(controller, candidates)
	local decision = {
		AllBlacklisted = false,
		Category = nil,
		CandidateCount = 0,
	}
	local upgrades = {}
	for _, candidate in ipairs(candidates) do
		if candidate.Category == "Upgrades" then
			table.insert(upgrades, candidate)
		end
	end
	if #upgrades > 0 then
		return upgrades, decision
	end

	if not controller or controller.GiftFarmRulesEnabled ~= true then
		return candidates, decision
	end

	local preferred = {}
	local allowed = {}
	local hasPolicyCandidate = false
	local allCandidatesUsePolicy = #candidates > 0
	local allPolicyCandidatesBlacklisted = true
	for _, candidate in ipairs(candidates) do
		local whitelist, whitelistPriority, blacklist = getCategoryPolicy(controller, candidate.Category)
		if whitelist then
			hasPolicyCandidate = true
			decision.CandidateCount += 1
			if decision.Category == nil then
				decision.Category = candidate.Category
			elseif decision.Category ~= candidate.Category then
				decision.Category = false
			end
			local key = normalizeName(candidate.ChoiceName)
			if whitelist[key] then
				candidate.PolicyPriority = whitelistPriority[key] or 999
				table.insert(preferred, candidate)
			end
			if not blacklist[key] then
				allPolicyCandidatesBlacklisted = false
				table.insert(allowed, candidate)
			end
		else
			allCandidatesUsePolicy = false
			table.insert(allowed, candidate)
		end
	end

	if #preferred > 0 then
		return preferred, decision
	end
	if #allowed > 0 then
		return allowed, decision
	end
	if hasPolicyCandidate then
		decision.AllBlacklisted = allCandidatesUsePolicy and allPolicyCandidatesBlacklisted
		if decision.Category == false then
			decision.Category = nil
		end
		return candidates, decision
	end
	return allowed, decision
end

function ChoicePolicy.apply(controller, candidates)
	local filtered = ChoicePolicy.applyWithDecision(controller, candidates)
	return filtered
end

function ChoicePolicy.getOptions(indexName)
	local names = {}
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
	local core = sharedModules and sharedModules:FindFirstChild("Core")
	local indexRoot = core and core:FindFirstChild("Index")
	local indexModule = indexRoot and indexRoot:FindFirstChild(indexName)
	if indexModule and indexModule:IsA("ModuleScript") then
		local loaded, index = pcall(require, indexModule)
		local items = loaded and typeof(index) == "table" and index.Items or nil
		if typeof(items) == "table" then
			for itemName in pairs(items) do
				local name = tostring(itemName)
				if name ~= "" then
					table.insert(names, name)
				end
			end
		end
		if #names == 0 then
			-- Native indexes populate Items in a deferred task. Child module names are
			-- the same ChoiceName keys and are available immediately.
			for _, child in ipairs(indexModule:GetChildren()) do
				if child:IsA("ModuleScript") and child.Name ~= "Template" then
					table.insert(names, child.Name)
				end
			end
		end
	end

	table.sort(names, function(left, right)
		return string.lower(left) < string.lower(right)
	end)
	return names
end

return ChoicePolicy
