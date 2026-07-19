--!nocheck

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local Altar = {}

local POLICY_ORDER = { "Passage", "Purgatory", "Chance", "Protection", "Purification", "Chaos" }
local POLICY_PRIORITY = {}
local PRIMARY_ECHO_SOURCES = {
	Purgatory = true,
	Chance = true,
	Protection = true,
}
local ECHO_IGNORED_ALTARS = {
	Purification = true,
	Chaos = true,
}
local DISCOVERY_MIN_SECONDS = 1
local DISCOVERY_QUIET_SECONDS = 0.35
local DISCOVERY_MAX_SECONDS = 3
local ACTION_COOLDOWN = 0.7
local TOUCH_SETTLE = 0.08
local MAX_ACTIVATION_SECONDS = 5
local SKIP_SECONDS = 12

local currentTarget = nil
local currentTargetStartedAt = 0
local lastActionAt = 0
local skippedUntil = setmetatable({}, { __mode = "k" })
local activatedThisRound = setmetatable({}, { __mode = "k" })
local rememberedEchoSource = nil
local lastObservedLevel = nil
local discoveryStartedAt = nil
local discoveryChangedAt = nil
local discoverySignature = nil
local discoveryComplete = false
local getPrompt

for index, altarName in ipairs(POLICY_ORDER) do
	POLICY_PRIORITY[altarName] = index
end

local function isSoloRun()
	local solo = ReplicatedStorage:FindFirstChild("Solo")
	return solo and solo:IsA("BoolValue") and solo.Value == true
end

local function isLocalHost()
	local player = Players.LocalPlayer
	return player and player:HasTag("Host") == true
end

local function getAltarState(root, tagged)
	if not root then
		return {
			Exists = false,
			Used = true,
			Voting = false,
			Solo = false,
			Host = false,
			PromptEnabled = false,
			Ready = false,
		}
	end

	local prompt = getPrompt(root, tagged)
	local used = root:GetAttribute("AltarUsed") == true
	local voting = root:HasTag("Voting") or (tagged and tagged:HasTag("Voting"))
	local solo = isSoloRun()
	local host = isLocalHost()
	local hostOrSolo = solo or host
	local promptEnabled = prompt and prompt.Enabled == true

	return {
		Exists = root:IsDescendantOf(workspace),
		Used = used,
		Voting = voting,
		Solo = solo,
		Host = host,
		Prompt = prompt,
		PromptEnabled = promptEnabled,
		Ready = root:IsDescendantOf(workspace) and not used and (voting or promptEnabled or hostOrSolo),
	}
end

local function touch(part, hrp)
	if typeof(firetouchinterest) ~= "function" then
		return
	end
	pcall(function()
		firetouchinterest(part, hrp, 0)
		task.wait()
		firetouchinterest(part, hrp, 1)
	end)
end

getPrompt = function(root, tagged)
	local prompt = root and root:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		return prompt
	end
	return tagged and tagged:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function triggerPrompt(prompt)
	if not (prompt and prompt:IsDescendantOf(workspace)) then
		return false
	end

	local oldHoldDuration = prompt.HoldDuration
	local triggered = false

	pcall(function()
		prompt.HoldDuration = 0
	end)

	if typeof(fireproximityprompt) == "function" then
		triggered = pcall(function()
			fireproximityprompt(prompt)
		end) == true
	elseif typeof(prompt.InputHoldBegin) == "function" and typeof(prompt.InputHoldEnd) == "function" then
		triggered = pcall(function()
			prompt:InputHoldBegin()
			task.wait()
			prompt:InputHoldEnd()
		end) == true
	end

	pcall(function()
		prompt.HoldDuration = oldHoldDuration
	end)

	return triggered
end

local function readStringValue(instance)
	if not instance then
		return nil
	end
	if instance:IsA("StringValue") then
		return instance.Value
	end
	return nil
end

local function getHitbox(root)
	if not root then
		return nil
	end

	local direct = root:FindFirstChild("HitBox") or root:FindFirstChild("Hitbox")
	if direct and direct:IsA("BasePart") then
		return direct
	end

	local nested = root:FindFirstChild("HitBox", true) or root:FindFirstChild("Hitbox", true)
	if nested and nested:IsA("BasePart") then
		return nested
	end

	return nil
end

local function getAltarName(root, tagged)
	local marker = root and root:FindFirstChild("Altar")
	return (root and root:GetAttribute("Name"))
		or (tagged and tagged:GetAttribute("Name"))
		or readStringValue(root and root:FindFirstChild("RealName"))
		or readStringValue(tagged and tagged:FindFirstChild("RealName"))
		or readStringValue(marker and marker:FindFirstChild("RealName"))
end

local function buildSelection(controller, forcedName)
	local selected = {}
	if typeof(forcedName) == "string" and forcedName ~= "" then
		selected[forcedName] = true
		return selected
	end
	local selections = controller and controller.AltarSelections

	if typeof(selections) ~= "table" then
		return selected
	end

	for _, altarName in ipairs(selections) do
		if typeof(altarName) == "string" and altarName ~= "" then
			selected[altarName] = true
		end
	end

	for altarName, enabled in pairs(selections) do
		if typeof(altarName) == "string" and enabled == true then
			selected[altarName] = true
		end
	end

	return selected
end

local function isSelected(controller, forcedName)
	local selected = buildSelection(controller, forcedName)
	for _ in pairs(selected) do
		return true
	end
	return false
end

local function isBetterCandidate(candidate, current)
	return not current
		or candidate.Priority < current.Priority
		or (candidate.Priority == current.Priority and candidate.Distance < current.Distance)
end

local function collectCandidates()
	local roots = {}
	local seen = {}

	for _, tagged in ipairs(CollectionService:GetTagged("Altar")) do
		if tagged and tagged:IsDescendantOf(workspace) then
			local root = tagged.Parent
			if root and root:IsDescendantOf(workspace) and root:FindFirstChild("Altar") and not seen[root] then
				seen[root] = tagged
				table.insert(roots, root)
			end
		end
	end

	return roots, seen
end

local function getDiscoverySignature(roots, taggedByRoot, selected)
	local counts = {}
	for _, root in ipairs(roots) do
		local altarName = getAltarName(root, taggedByRoot[root])
		if altarName and selected[altarName] then
			counts[altarName] = (counts[altarName] or 0) + 1
		end
	end

	local parts = {}
	for altarName, count in pairs(counts) do
		parts[#parts + 1] = altarName .. ":" .. tostring(count)
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

local function isDiscoveryReady(roots, taggedByRoot, selected)
	if discoveryComplete then
		return true
	end

	local now = os.clock()
	if not discoveryStartedAt then
		discoveryStartedAt = now
		discoveryChangedAt = now
	end

	local signature = getDiscoverySignature(roots, taggedByRoot, selected)
	if signature ~= discoverySignature then
		discoverySignature = signature
		discoveryChangedAt = now
	end

	local elapsed = now - discoveryStartedAt
	local quietFor = now - (discoveryChangedAt or now)
	discoveryComplete = elapsed >= DISCOVERY_MAX_SECONDS
		or (signature ~= "" and elapsed >= DISCOVERY_MIN_SECONDS and quietFor >= DISCOVERY_QUIET_SECONDS)
	return discoveryComplete
end

local function isValidTarget(target, selected)
	if not target or not target.Root or not target.Root:IsDescendantOf(workspace) then
		return false
	end
	if not target.Hitbox or not target.Hitbox:IsDescendantOf(workspace) then
		return false
	end
	if not selected[target.Name] then
		return false
	end
	if skippedUntil[target.Root] and os.clock() < skippedUntil[target.Root] then
		return false
	end
	if activatedThisRound[target.Root] == true then
		return false
	end
	local state = getAltarState(target.Root, target.Tagged)
	return state and state.Ready == true
end

local function getStateDetail(target, state)
	if not (target and state) then
		return ""
	end

	local stateText = "Touch"
	if state.PromptEnabled then
		stateText = "Prompt"
	elseif state.Voting then
		stateText = "Voting"
	elseif state.Solo then
		stateText = "Solo"
	elseif state.Host then
		stateText = "Host"
	end

	return target.Name .. " | " .. stateText
end

local function findBestTarget(controller, hrp, forcedName)
	local selected = buildSelection(controller, forcedName)
	if not next(selected) then
		return nil
	end

	local roots, taggedByRoot = collectCandidates()
	if not isDiscoveryReady(roots, taggedByRoot, selected) then
		return nil, true
	end

	local previousTarget = if isValidTarget(currentTarget, selected)
		and (currentTarget.Name ~= "Echo" or rememberedEchoSource ~= nil)
		then currentTarget
		else nil
	currentTarget = nil
	local primaryBest = nil
	local echoBest = nil
	local passageBest = nil
	local deferredBest = nil

	for _, root in ipairs(roots) do
		local tagged = taggedByRoot[root]
		local name = getAltarName(root, tagged)
		local state = getAltarState(root, tagged)
		if
			name
			and selected[name]
			and state
			and state.Ready == true
			and activatedThisRound[root] ~= true
			and not (skippedUntil[root] and os.clock() < skippedUntil[root])
		then
			local hitbox = getHitbox(root) or getHitbox(tagged)
			if hitbox then
				local distance = (hitbox.Position - hrp.Position).Magnitude
				local candidate = {
					Root = root,
					Tagged = tagged,
					Hitbox = hitbox,
					Prompt = state.Prompt,
					State = state,
					Name = name,
					Priority = POLICY_PRIORITY[name] or 999,
					Distance = distance,
				}
				if name == "Echo" then
					candidate.EchoSource = rememberedEchoSource
					if not echoBest or candidate.Distance < echoBest.Distance then
						echoBest = candidate
					end
				elseif name == "Passage" then
					if not passageBest or candidate.Distance < passageBest.Distance then
						passageBest = candidate
					end
				elseif PRIMARY_ECHO_SOURCES[name] then
					if isBetterCandidate(candidate, primaryBest) then
						primaryBest = candidate
					end
				elseif ECHO_IGNORED_ALTARS[name] and isBetterCandidate(candidate, deferredBest) then
					deferredBest = candidate
				end
			end
		end
	end

	local shouldRepeatRemembered = rememberedEchoSource ~= nil and echoBest ~= nil

	if passageBest then
		currentTarget = passageBest
	elseif previousTarget then
		currentTarget = previousTarget
	elseif shouldRepeatRemembered then
		currentTarget = echoBest
	else
		currentTarget = primaryBest or deferredBest
	end
	if not currentTarget then
		currentTargetStartedAt = 0
	elseif not previousTarget or previousTarget.Root ~= currentTarget.Root then
		currentTargetStartedAt = os.clock()
	end
	return currentTarget
end

function Altar.tryStep(controller, hrp, lease, _currentSessionToken, _normalGiftRatio, forcedName)
	if not (controller and hrp and hrp.Parent) then
		return false
	end
	if not isSelected(controller, forcedName) then
		currentTarget = nil
		return false
	end
	if forcedName and currentTarget and currentTarget.Name ~= forcedName then
		currentTarget = nil
		currentTargetStartedAt = 0
	end

	if currentTarget and currentTarget.Root then
		local confirmedState = getAltarState(currentTarget.Root, currentTarget.Tagged)
		if confirmedState and confirmedState.Used == true then
			local confirmedTarget = currentTarget
			activatedThisRound[confirmedTarget.Root] = true
			if PRIMARY_ECHO_SOURCES[confirmedTarget.Name] then
				rememberedEchoSource = confirmedTarget.Name
			else
				rememberedEchoSource = nil
			end
			currentTarget = nil
			currentTargetStartedAt = 0
			local detail = confirmedTarget.Name .. " | Confirmed"
			if confirmedTarget.Name == "Echo" and confirmedTarget.EchoSource then
				detail = detail .. " | Repeated " .. confirmedTarget.EchoSource
			end
			return true, "AltarActivated", detail, true, confirmedTarget.Name
		end
	end

	local target, discovering = findBestTarget(controller, hrp, forcedName)
	if discovering then
		return true, "DiscoveringAltars", "Waiting for altar replication", false
	end
	if not target then
		return false
	end
	if currentTargetStartedAt > 0 and os.clock() - currentTargetStartedAt > MAX_ACTIVATION_SECONDS then
		skippedUntil[target.Root] = os.clock() + SKIP_SECONDS
		currentTarget = nil
		currentTargetStartedAt = 0
		return false
	end

	local state = getAltarState(target.Root, target.Tagged)
	if not (state and state.Ready == true) then
		currentTarget = nil
		currentTargetStartedAt = 0
		return false
	end

	local offset = Vector3.new(0, math.clamp(target.Hitbox.Size.Y * 0.25, 1, 4), 0)
	if lease then
		lease:moveTo(CFrame.new(target.Hitbox.Position + offset))
	else
		Context.moveCharacterTo(CFrame.new(target.Hitbox.Position + offset))
	end

	if lease and not lease:isValid() then
		return false
	end

	if os.clock() - lastActionAt >= ACTION_COOLDOWN then
		lastActionAt = os.clock()
		task.wait(TOUCH_SETTLE)
		if lease and not lease:isValid() then
			return false
		end
		if not triggerPrompt(target.Prompt) then
			touch(target.Hitbox, hrp)
		end
	end

	return true, "ActivatingAltar", getStateDetail(target, state), false, target.Name
end

function Altar.reset()
	local levelValue = ReplicatedStorage:FindFirstChild("Level")
	local level = tonumber(levelValue and levelValue.Value)
	if level and lastObservedLevel and level < lastObservedLevel then
		rememberedEchoSource = nil
	end
	if level then
		lastObservedLevel = level
	end

	currentTarget = nil
	currentTargetStartedAt = 0
	lastActionAt = 0
	skippedUntil = setmetatable({}, { __mode = "k" })
	activatedThisRound = setmetatable({}, { __mode = "k" })
	discoveryStartedAt = nil
	discoveryChangedAt = nil
	discoverySignature = nil
	discoveryComplete = false
end

return Altar
