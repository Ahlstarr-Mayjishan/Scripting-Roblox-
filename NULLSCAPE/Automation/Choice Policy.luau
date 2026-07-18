--!nocheck
--[[
	NULLSCAPE - Auto Choice Policy
	Separates native curse and greater-curse policies. Upgrades bypass
	name policies because every affordable upgrade should be purchased.
]]

local ChoiceCatalog = getgenv().loadModule("NULLSCAPE/Automation/Choice Catalog.luau")

local ChoicePolicy = {}

local CATEGORY_FIELDS = {
	Enemies = {
		Index = "EnemyIndex",
		Whitelist = "EnemyChoiceWhitelist",
		Blacklist = "EnemyChoiceBlacklist",
	},
	Curses = {
		Index = "CurseIndex",
		Whitelist = "CurseChoiceWhitelist",
		Blacklist = "CurseChoiceBlacklist",
	},
	["Greater Curses"] = {
		Index = "GreaterCurseIndex",
		Whitelist = "GreaterCurseChoiceWhitelist",
		Blacklist = "GreaterCurseChoiceBlacklist",
	},
}

function ChoicePolicy.applyMedalChoiceMode(controller, candidates)
	local configured = controller and controller.MedalChoiceMode
	if typeof(configured) ~= "string" or configured == "" then
		return candidates, true
	end

	local matching = {}
	local hasMedalChoices = false
	for _, candidate in ipairs(candidates) do
		if candidate.Category == "Selection - Medal Curses" then
			hasMedalChoices = true
			if candidate.MedalChoiceMode == configured then
				matching[#matching + 1] = candidate
			end
		end
	end
	if not hasMedalChoices then
		return candidates, true
	end
	if #matching > 0 then
		return matching, true
	end
	return {}, false
end

local function buildNamePolicy(values, indexName)
	local selected, priority = {}, {}
	if typeof(values) ~= "table" then
		return selected, priority
	end

	for index, value in ipairs(values) do
		local key = ChoiceCatalog.resolveKey(indexName, value)
		if key ~= "" then
			selected[key] = true
			priority[key] = priority[key] or index
		end
	end
	for value, active in pairs(values) do
		if typeof(value) == "string" and active == true then
			local key = ChoiceCatalog.resolveKey(indexName, value)
			if key ~= "" then
				selected[key] = true
			end
		end
	end
	return selected, priority
end

local function getCategoryPolicy(controller, category)
	local fields = CATEGORY_FIELDS[category]
	if not fields then
		return nil
	end

	local whitelist, whitelistPriority = buildNamePolicy(controller and controller[fields.Whitelist], fields.Index)
	local blacklist = buildNamePolicy(controller and controller[fields.Blacklist], fields.Index)
	return whitelist, whitelistPriority, blacklist, fields.Index
end

function ChoicePolicy.applyWithDecision(controller, candidates)
	local decision = {
		AllBlacklisted = false,
		Fallback = false,
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
		local policyCategory = candidate.Category
		if policyCategory == "Chaos" then
			policyCategory = ChoiceCatalog.resolveChaosCategory(candidate.ChoiceName) or policyCategory
		end
		local whitelist, whitelistPriority, blacklist, indexName = getCategoryPolicy(controller, policyCategory)
		if whitelist then
			hasPolicyCandidate = true
			decision.CandidateCount += 1
			if decision.Category == nil then
				decision.Category = policyCategory
			elseif decision.Category ~= policyCategory then
				decision.Category = false
			end
			local key = ChoiceCatalog.resolveKey(indexName, candidate.ChoiceName)
			local blacklisted = blacklist[key] == true
			if whitelist[key] and not blacklisted then
				candidate.PolicyPriority = whitelistPriority[key] or 999
				table.insert(preferred, candidate)
			end
			if not blacklisted then
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
		decision.Fallback = decision.AllBlacklisted
		return candidates, decision
	end
	return allowed, decision
end

function ChoicePolicy.apply(controller, candidates)
	local filtered = ChoicePolicy.applyWithDecision(controller, candidates)
	return filtered
end

function ChoicePolicy.getOptions(indexName)
	return ChoiceCatalog.getDisplayOptions(indexName)
end

function ChoicePolicy.normalizeSelections(indexName, values)
	return ChoiceCatalog.toDisplaySelections(indexName, values)
end

function ChoicePolicy.excludeSelections(indexName, options, excluded)
	local excludedKeys = {}
	if typeof(excluded) == "table" then
		for _, value in ipairs(excluded) do
			excludedKeys[ChoiceCatalog.resolveKey(indexName, value)] = true
		end
		for value, active in pairs(excluded) do
			if typeof(value) == "string" and active == true then
				excludedKeys[ChoiceCatalog.resolveKey(indexName, value)] = true
			end
		end
	end

	local filtered = {}
	for _, option in ipairs(options or {}) do
		if not excludedKeys[ChoiceCatalog.resolveKey(indexName, option)] then
			filtered[#filtered + 1] = option
		end
	end
	return filtered
end

return ChoicePolicy
