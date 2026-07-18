--!nocheck
--[[
	NULLSCAPE - Automation Auto Choose Things
	Chooses workspace.Select orbs by ChoiceType/ChoiceName while InRound is false.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementLease = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/MovementLease.luau")
local ChoicePolicy = getgenv().loadModule("NULLSCAPE/Automation/Choice Policy.luau")
local ChoiceReroll = getgenv().loadModule("NULLSCAPE/Automation/Choice Reroll.luau")

local AutoChooseThings = {}

local CATEGORY_ORDER = {
	"Continue",
	"Selection - Medal Curses",
	"Selection - Curses",
	"Upgrades",
	"Enemies",
	"Curses",
	"Greater Curses",
	"Chaos",
}

local CHOOSE_DISTANCE = 6
local LOOP_INTERVAL = 0.12
local ACTION_COOLDOWN = 0.65
local RETRY_COOLDOWN = 1.2
local MOVE_SETTLE = 0.08
local CONTINUE_COOLDOWN = 1.5
local CONTINUE_AFTER_PRIMARY_GRACE = 1.25
local PRIORITY_UPGRADES = {
	fannypack = 1,
	businesslicense = 2,
	paycheck = 3,
}
local MEDAL_MODE_REWARD = "Golden Gifts (No Rerolls)"
local MEDAL_MODE_REROLLS = "Rerolls (No Golden Gifts)"

local enabled = false
local running = false
local lastActionAt = 0
local lastContinueAt = 0
local lastPrimaryChoiceAt = 0
local lastSelectFolder = nil
local attemptedAt = {}

local function setStatus(controller, status, detail)
	if controller then
		controller.AutoChooseThingsStatus = status or "Idle"
		controller.AutoChooseThingsDetail = detail or ""
	end
end

local function isInRound()
	local inRound = ReplicatedStorage:FindFirstChild("InRound")
	return inRound and inRound:IsA("BoolValue") and inRound.Value == true
end

local function getCurrencyAmount(currencyType)
	local currencyName = tostring(currencyType or "GoldenGifts")
	if currencyName == "GoldenGifts" then
		local goldenGifts = ReplicatedStorage:FindFirstChild("GoldenGifts")
		if goldenGifts and (goldenGifts:IsA("NumberValue") or goldenGifts:IsA("IntValue")) then
			return tonumber(goldenGifts.Value) or 0
		end
	end

	local player = Players.LocalPlayer
	local direct = player and player:FindFirstChild(currencyName)
	if direct and (direct:IsA("NumberValue") or direct:IsA("IntValue")) then
		return tonumber(direct.Value) or 0
	end

	local leaderstats = player and player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(currencyName)
	if stat and (stat:IsA("NumberValue") or stat:IsA("IntValue")) then
		return tonumber(stat.Value) or 0
	end

	return 0
end

local function getRootPart()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getPrompt(root)
	if not root then
		return nil
	end
	return root:IsA("ProximityPrompt") and root or root:FindFirstChildWhichIsA("ProximityPrompt", true)
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

local function readAttribute(root, prompt, name)
	local value = root and root:GetAttribute(name)
	if value ~= nil then
		return value
	end
	return prompt and prompt.Parent and prompt.Parent:GetAttribute(name) or nil
end

local function hasAncestorNamed(instance, name)
	local current = instance
	while current and current ~= workspace do
		if current.Name == name then
			return true
		end
		current = current.Parent
	end
	return false
end

local function textContains(value, needle)
	return string.find(string.lower(tostring(value or "")), needle, 1, true) ~= nil
end

local function normalizeUpgradeName(value)
	return string.lower(tostring(value or "")):gsub("[%s%p_]+", "")
end

local function getUpgradeBuyPriority(choiceName)
	return PRIORITY_UPGRADES[normalizeUpgradeName(choiceName)] or 999
end

local function isContinuePromptRoot(root, prompt)
	if hasAncestorNamed(root, "Sign") or hasAncestorNamed(prompt, "Sign") then
		return true
	end

	return textContains(root and root.Name, "continue")
		or textContains(prompt and prompt.Name, "continue")
		or textContains(prompt and prompt.ActionText, "continue")
		or textContains(prompt and prompt.ObjectText, "continue")
		or textContains(prompt and prompt.ActionText, "proceed")
		or textContains(prompt and prompt.ObjectText, "proceed")
end

local function isPromptReady(prompt)
	return prompt
		and prompt:IsDescendantOf(workspace)
		and prompt.Enabled == true
		and prompt:GetAttribute("Active") ~= false
end

local function canAffordPrompt(prompt)
	local cost = tonumber(prompt and prompt:GetAttribute("Cost"))
	if not cost or cost <= 0 then
		return true
	end
	return getCurrencyAmount(prompt:GetAttribute("CurrencyType")) >= cost
end

local function getContinueButton()
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local endScreen = playerGui and playerGui:FindFirstChild("EndScreen")
	if not (endScreen and endScreen:IsA("LayerCollector") and endScreen.Enabled == true) then
		return nil
	end

	local main = endScreen:FindFirstChild("Main")
	local continue = main and main:FindFirstChild("Continue", true)
	if continue and continue:IsA("GuiButton") and continue.Visible ~= false then
		return continue
	end
	return nil
end

local function activateButton(button)
	if not button then
		return false
	end
	if typeof(firesignal) == "function" then
		local clicked = pcall(function()
			firesignal(button.MouseButton1Click)
		end) == true
		if clicked then
			return true
		end
	end
	return pcall(function()
		button:Activate()
	end) == true
end

local function classifyMedalChoice(root, prompt, itemIndex)
	local identityValues = {
		tostring(root and root.Name or ""),
		tostring(prompt and prompt.ActionText or ""),
		tostring(prompt and prompt.ObjectText or ""),
		tostring(itemIndex or ""),
	}
	for _, identity in ipairs(identityValues) do
		local normalizedIdentity = normalizeUpgradeName(identity)
		if string.find(normalizedIdentity, "cursemedal", 1, true) then
			return MEDAL_MODE_REROLLS
		end
		if normalizedIdentity == "medal" then
			return MEDAL_MODE_REWARD
		end
	end
	if root then
		local hasMedalLabel = false
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				local normalizedText = normalizeUpgradeName(descendant.Text)
				if normalizedText == "cursemedal" then
					return MEDAL_MODE_REROLLS
				elseif normalizedText == "medal" then
					hasMedalLabel = true
				end
			end
		end
		if hasMedalLabel then
			return MEDAL_MODE_REWARD
		end
	end

	for _, instance in ipairs({ root, prompt }) do
		if instance then
			for name, value in pairs(instance:GetAttributes()) do
				if textContains(name, "reroll") then
					if value == true or (tonumber(value) or 0) > 0 then
						return MEDAL_MODE_REROLLS
					elseif value == false or tonumber(value) == 0 then
						return MEDAL_MODE_REWARD
					end
				end
			end
		end
	end

	local visibleText = table.concat({
		tostring(root and root.Name or ""),
		tostring(prompt and prompt.ActionText or ""),
		tostring(prompt and prompt.ObjectText or ""),
	}, " ")
	if textContains(visibleText, "no reroll") or textContains(visibleText, "without reroll") then
		return MEDAL_MODE_REWARD
	end
	if textContains(visibleText, "reroll") then
		return MEDAL_MODE_REROLLS
	end
	if
		textContains(visibleText, "golden gift")
		or textContains(visibleText, "reward")
		or textContains(visibleText, "money")
	then
		return MEDAL_MODE_REWARD
	end

	local indexText = tostring(itemIndex or "")
	if textContains(indexText, "reroll") then
		return MEDAL_MODE_REROLLS
	end
	if textContains(indexText, "golden") or textContains(indexText, "reward") then
		return MEDAL_MODE_REWARD
	end
	return nil
end

local function tryContinue(controller)
	if os.clock() - lastContinueAt < CONTINUE_COOLDOWN then
		return false
	end

	local button = getContinueButton()
	if not button then
		return false
	end

	lastContinueAt = os.clock()
	local activated = activateButton(button)
	setStatus(controller, activated and "Continued" or "ContinueFailed", "EndScreen")
	return true
end

local function normalizeCategory(choiceType, choiceName, root, prompt)
	local rawType = tostring(choiceType or ""):upper()
	local rawName = tostring(choiceName or "")

	if hasAncestorNamed(root, "Reroll") or hasAncestorNamed(prompt, "Reroll") then
		return nil
	elseif isContinuePromptRoot(root, prompt) then
		return "Continue"
	elseif rawType == "SELECTION" and rawName == "MedalCurses" then
		return "Selection - Medal Curses"
	elseif rawType == "SELECTION" and rawName == "Curses" then
		return "Selection - Curses"
	elseif rawType == "ENEMIES" then
		return "Enemies"
	elseif rawType == "UPGRADES" or rawType == "WINGS" then
		return "Upgrades"
	elseif rawType == "CURSES" then
		return "Curses"
	elseif rawType == "GREATER CURSES" then
		return "Greater Curses"
	elseif rawType == "CHAOS" then
		return "Chaos"
	end

	return nil
end

local function buildSelectionPriority()
	local selected, priority = {}, {}
	for index, category in ipairs(CATEGORY_ORDER) do
		selected[category] = true
		priority[category] = index
	end
	priority.Upgrades = 0
	return selected, priority
end

local function hasAnySelection(selected)
	for _ in pairs(selected) do
		return true
	end
	return false
end

local function getChoiceKey(root, choiceType, choiceName, itemIndex)
	return table.concat({
		root and root:GetFullName() or "?",
		tostring(choiceType or ""),
		tostring(choiceName or ""),
		tostring(itemIndex or ""),
	}, "|")
end

local function addCandidate(candidates, seen, root, selected, priority, hrp)
	if not (root and root:IsDescendantOf(workspace)) or seen[root] then
		return
	end
	seen[root] = true

	local prompt = getPrompt(root)
	local part = isPromptReady(prompt) and getPromptPart(root, prompt) or nil
	if not part then
		return
	end

	local choiceType = readAttribute(root, prompt, "ChoiceType")
	local choiceName = readAttribute(root, prompt, "ChoiceName")
	local itemIndex = readAttribute(root, prompt, "ItemIndex")
	local category = normalizeCategory(choiceType, choiceName, root, prompt)
	if not (category and selected[category]) then
		return
	end
	if category == "Upgrades" and not canAffordPrompt(prompt) then
		return
	end

	local key = getChoiceKey(root, choiceType, choiceName, itemIndex)
	if attemptedAt[key] and os.clock() - attemptedAt[key] < RETRY_COOLDOWN then
		return
	end

	table.insert(candidates, {
		Root = root,
		Prompt = prompt,
		Part = part,
		Category = category,
		ChoiceName = choiceName,
		ItemIndex = itemIndex,
		MedalChoiceMode = category == "Selection - Medal Curses"
			and classifyMedalChoice(root, prompt, itemIndex)
			or nil,
		Cost = tonumber(prompt:GetAttribute("Cost")) or 0,
		UpgradeBuyPriority = category == "Upgrades" and getUpgradeBuyPriority(choiceName) or 999,
		Priority = priority[category] or 999,
		Distance = (part.Position - hrp.Position).Magnitude,
		Key = key,
	})
end

local function hasReadyPrimaryChoice(root, selected)
	if not (root and root:IsDescendantOf(workspace)) then
		return false
	end

	local prompt = getPrompt(root)
	if not isPromptReady(prompt) then
		return false
	end

	local choiceType = readAttribute(root, prompt, "ChoiceType")
	local choiceName = readAttribute(root, prompt, "ChoiceName")
	local category = normalizeCategory(choiceType, choiceName, root, prompt)
	if not (category and category ~= "Continue" and selected[category]) then
		return false
	end

	return category ~= "Upgrades" or canAffordPrompt(prompt)
end

local function collectTarget(controller, hrp)
	local selected, priority = buildSelectionPriority()
	if not hasAnySelection(selected) then
		return nil, "NoCategories"
	end

	local selectFolder = workspace:FindFirstChild("Select")
	if selectFolder ~= lastSelectFolder then
		lastSelectFolder = selectFolder
		attemptedAt = {}
		lastPrimaryChoiceAt = 0
		ChoiceReroll.reset()
	end
	if not selectFolder then
		return nil, "WaitingForSelect"
	end

	local candidates, seen = {}, {}
	for _, child in ipairs(selectFolder:GetChildren()) do
		addCandidate(candidates, seen, child, selected, priority, hrp)
	end
	for _, descendant in ipairs(selectFolder:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and isContinuePromptRoot(descendant.Parent, descendant) then
			addCandidate(candidates, seen, descendant.Parent or descendant, selected, priority, hrp)
		end
	end
	for _, tagged in ipairs(CollectionService:GetTagged("ChoiceOrb")) do
		addCandidate(candidates, seen, tagged, selected, priority, hrp)
	end

	local hasPrimaryChoice = false
	for _, candidate in ipairs(candidates) do
		if candidate.Category ~= "Continue" then
			hasPrimaryChoice = true
			break
		end
	end
	local waitingForChoiceRefresh = not hasPrimaryChoice and os.clock() - lastPrimaryChoiceAt < CONTINUE_AFTER_PRIMARY_GRACE
	if waitingForChoiceRefresh then
		for _, child in ipairs(selectFolder:GetChildren()) do
			if hasReadyPrimaryChoice(child, selected) then
				hasPrimaryChoice = true
				break
			end
		end
		if not hasPrimaryChoice then
			for _, tagged in ipairs(CollectionService:GetTagged("ChoiceOrb")) do
				if hasReadyPrimaryChoice(tagged, selected) then
					hasPrimaryChoice = true
					break
				end
			end
		end
	end
	if waitingForChoiceRefresh and not hasPrimaryChoice then
		return nil, "WaitingForChoiceRefresh"
	end
	if hasPrimaryChoice then
		for index = #candidates, 1, -1 do
			local category = candidates[index].Category
			if category == "Continue" then
				table.remove(candidates, index)
			end
		end
	end
	local medalModeResolved
	candidates, medalModeResolved = ChoicePolicy.applyMedalChoiceMode(controller, candidates)
	if medalModeResolved == false then
		return nil, "WaitingForMedalChoiceMetadata"
	end
	local signature = ChoiceReroll.getSignature(candidates)
	if ChoiceReroll.isWaitingForRefresh(signature) then
		return nil, "WaitingForRerollRefresh"
	end

	local decision
	candidates, decision = ChoicePolicy.applyWithDecision(controller, candidates)
	if decision.AllBlacklisted == true then
		local reroll = ChoiceReroll.find(selectFolder, hrp, signature)
		if reroll then
			reroll.BatchSignature = signature
			reroll.RerollCategory = decision.Category
			return reroll
		end
		decision.Fallback = true
	end

	table.sort(candidates, function(a, b)
		local aPolicy = tonumber(a.PolicyPriority) or 999
		local bPolicy = tonumber(b.PolicyPriority) or 999
		if aPolicy ~= bPolicy then
			return aPolicy < bPolicy
		end
		if a.Category == "Upgrades" and b.Category == "Upgrades" then
			if a.UpgradeBuyPriority ~= b.UpgradeBuyPriority then
				return a.UpgradeBuyPriority < b.UpgradeBuyPriority
			end
			if a.Cost ~= b.Cost then
				return a.Cost > b.Cost
			end
		end
		return a.Priority == b.Priority and a.Distance < b.Distance or a.Priority < b.Priority
	end)
	local target = candidates[1]
	if target and decision.Fallback == true then
		target.PolicyFallback = true
	end
	return target, #candidates == 0 and "NoReadyChoice" or nil
end

local function moveInsidePromptRange(target, lease)
	local hrp = getRootPart()
	if not (hrp and target and target.Part and lease and lease:isValid()) then
		return false
	end

	local maxDistance = tonumber(target.Prompt.MaxActivationDistance) or 8
	local desiredDistance = math.min(CHOOSE_DISTANCE, math.max(2, maxDistance - 1))
	if (hrp.Position - target.Part.Position).Magnitude <= desiredDistance then
		return true
	end

	local offset = Vector3.new(0, math.clamp(target.Part.Size.Y * 0.25 + 1.5, 2, 5), 0)
	return lease:moveTo(CFrame.new(target.Part.Position + offset))
end

local function firePrompt(prompt)
	local oldHoldDuration = prompt.HoldDuration
	local fired = false
	pcall(function()
		prompt.HoldDuration = 0
	end)
	if typeof(fireproximityprompt) == "function" then
		fired = pcall(function()
			fireproximityprompt(prompt)
		end) == true
	elseif typeof(prompt.InputHoldBegin) == "function" and typeof(prompt.InputHoldEnd) == "function" then
		fired = pcall(function()
			prompt:InputHoldBegin()
			task.wait(math.max(0.02, oldHoldDuration))
			prompt:InputHoldEnd()
		end) == true
	end
	pcall(function()
		prompt.HoldDuration = oldHoldDuration
	end)
	return fired
end

local function run(controller)
	if running then
		return
	end
	running = true
	task.spawn(function()
		while enabled and controller and not controller.Destroyed do
			if controller.GiftFarmPolicyHolding == true or controller.GiftFarmRestPending == true then
				setStatus(controller, "WaitingForGiftFarmPolicy", controller.GiftFarmDetail)
				task.wait(0.25)
				continue
			end
			if isInRound() then
				attemptedAt, lastSelectFolder = {}, nil
				ChoiceReroll.reset()
				setStatus(controller, "WaitingForIntermission")
				task.wait(0.4)
				continue
			end
			if tryContinue(controller) then
				task.wait(LOOP_INTERVAL)
				continue
			end

			local hrp = getRootPart()
			if not hrp then
				setStatus(controller, "WaitingForCharacter")
				task.wait(0.4)
				continue
			end

			local target, reason = collectTarget(controller, hrp)
			if not target then
				setStatus(controller, reason or "Waiting")
				task.wait(LOOP_INTERVAL)
				continue
			end

			local lease = MovementLease.tryAcquire("AutoChoose")
			if not lease then
				setStatus(controller, "WaitingForMovement", MovementLease.getActiveOwner() or "Movement busy")
				task.wait(LOOP_INTERVAL)
				continue
			end

			local moved = moveInsidePromptRange(target, lease)
			task.wait(MOVE_SETTLE)
			if not moved
				or not lease:isValid()
				or not enabled
				or controller.Destroyed
				or isInRound()
				or controller.GiftFarmPolicyHolding == true
				or controller.GiftFarmRestPending == true
			then
				lease:release()
				task.wait(LOOP_INTERVAL)
				continue
			end

			if os.clock() - lastActionAt >= ACTION_COOLDOWN then
				lastActionAt = os.clock()
				attemptedAt[target.Key] = os.clock()
				local fired = firePrompt(target.Prompt)
				if fired and target.Category == "Reroll" then
					ChoiceReroll.markFired(target.BatchSignature, target.Remaining)
				elseif fired and target.Category ~= "Continue" then
					lastPrimaryChoiceAt = os.clock()
				end
				local name = tostring(target.MedalChoiceMode or target.ChoiceName or target.Root.Name)
				if fired and target.Category == "Reroll" then
					setStatus(
						controller,
						"Rerolled",
						ChoiceReroll.getDetail(target.RerollCategory, target.Remaining)
					)
				else
					local detail = target.Category .. " | " .. name
					if target.PolicyFallback == true then
						detail ..= " | blacklist fallback after rerolls"
					end
					setStatus(controller, fired and "Chosen" or "PromptFailed", detail)
				end
			end
			lease:release()
			task.wait(LOOP_INTERVAL)
		end
		setStatus(controller, "Idle")
		running = false
	end)
end

function AutoChooseThings.update(controller)
	enabled = controller and controller.AutoChooseThingsEnabled == true
	if enabled then
		run(controller)
	else
		setStatus(controller, "Idle")
	end
	return true
end

function AutoChooseThings.disable(controller)
	enabled = false
	attemptedAt, lastSelectFolder = {}, nil
	ChoiceReroll.reset()
	setStatus(controller, "Idle")
	return true
end

function AutoChooseThings.getStatus(controller)
	return {
		Status = controller and controller.AutoChooseThingsStatus or "Idle",
		Detail = controller and controller.AutoChooseThingsDetail or "",
	}
end

return AutoChooseThings
