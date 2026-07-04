--!nocheck
--[[
	NULLSCAPE - Automation Auto Choose Things
	Chooses workspace.Select orbs by ChoiceType/ChoiceName while InRound is false.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

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

local enabled = false
local running = false
local lastActionAt = 0
local lastContinueAt = 0
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
	local activated = pcall(function()
		button:Activate()
	end) == true
	if activated then
		return true
	end
	if typeof(firesignal) == "function" then
		return pcall(function()
			firesignal(button.MouseButton1Click)
		end) == true
	end
	return false
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

local function normalizeCategory(choiceType, choiceName, root)
	local rawType = tostring(choiceType or ""):upper()
	local rawName = tostring(choiceName or "")

	if root and root.Name == "Reroll" then
		return nil
	elseif root and root.Name == "Sign" then
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

local function buildSelectionPriority(controller)
	local selected, priority = {}, {}
	local selections = controller and controller.AutoChooseThingSelections
	local anySelected = false
	if typeof(selections) == "table" then
		for index, category in ipairs(selections) do
			if typeof(category) == "string" and category ~= "" then
				selected[category] = true
				priority[category] = priority[category] or index
				anySelected = true
			end
		end
		for category, active in pairs(selections) do
			if typeof(category) == "string" and active == true then
				selected[category] = true
				anySelected = true
			end
		end
	end
	for index, category in ipairs(CATEGORY_ORDER) do
		if not anySelected then
			selected[category] = true
			priority[category] = index
		elseif selected[category] and not priority[category] then
			priority[category] = index
		end
	end
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
	local category = normalizeCategory(choiceType, choiceName, root)
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
		Cost = tonumber(prompt:GetAttribute("Cost")) or 0,
		Priority = priority[category] or 999,
		Distance = (part.Position - hrp.Position).Magnitude,
		Key = key,
	})
end

local function collectTarget(controller, hrp)
	local selected, priority = buildSelectionPriority(controller)
	if not hasAnySelection(selected) then
		return nil, "NoCategories"
	end

	local selectFolder = workspace:FindFirstChild("Select")
	if selectFolder ~= lastSelectFolder then
		lastSelectFolder = selectFolder
		attemptedAt = {}
	end
	if not selectFolder then
		return nil, "WaitingForSelect"
	end

	local candidates, seen = {}, {}
	for _, child in ipairs(selectFolder:GetChildren()) do
		addCandidate(candidates, seen, child, selected, priority, hrp)
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
	if hasPrimaryChoice then
		for index = #candidates, 1, -1 do
			local category = candidates[index].Category
			if category == "Continue" then
				table.remove(candidates, index)
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.Category == "Upgrades" and b.Category == "Upgrades" and a.Cost ~= b.Cost then
			return a.Cost > b.Cost
		end
		return a.Priority == b.Priority and a.Distance < b.Distance or a.Priority < b.Priority
	end)
	return candidates[1], #candidates == 0 and "NoReadyChoice" or nil
end

local function moveInsidePromptRange(target)
	local hrp = getRootPart()
	if not (hrp and target and target.Part) then
		return false
	end

	local maxDistance = tonumber(target.Prompt.MaxActivationDistance) or 8
	local desiredDistance = math.min(CHOOSE_DISTANCE, math.max(2, maxDistance - 1))
	if (hrp.Position - target.Part.Position).Magnitude <= desiredDistance then
		return true
	end

	local offset = Vector3.new(0, math.clamp(target.Part.Size.Y * 0.25 + 1.5, 2, 5), 0)
	return Context.moveCharacterTo(CFrame.new(target.Part.Position + offset))
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
			if tryContinue(controller) then
				task.wait(LOOP_INTERVAL)
				continue
			end

			if isInRound() then
				attemptedAt, lastSelectFolder = {}, nil
				setStatus(controller, "WaitingForIntermission")
				task.wait(0.4)
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

			moveInsidePromptRange(target)
			task.wait(MOVE_SETTLE)
			if os.clock() - lastActionAt >= ACTION_COOLDOWN then
				lastActionAt = os.clock()
				attemptedAt[target.Key] = os.clock()
				local fired = firePrompt(target.Prompt)
				local name = tostring(target.ChoiceName or target.Root.Name)
				setStatus(controller, fired and "Chosen" or "PromptFailed", target.Category .. " | " .. name)
			end
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
