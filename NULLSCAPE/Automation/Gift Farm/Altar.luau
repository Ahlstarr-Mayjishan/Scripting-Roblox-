--!nocheck

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local Altar = {}

local ALTAR_ORDER = { "Passage", "Purgatory", "Chance", "Protection", "Chaos", "Echo", "Purification" }
local ACTION_COOLDOWN = 0.7
local TOUCH_SETTLE = 0.08
local MAX_ACTIVATION_SECONDS = 5
local SKIP_SECONDS = 12

local currentTarget = nil
local currentTargetStartedAt = 0
local lastActionAt = 0
local skippedUntil = setmetatable({}, { __mode = "k" })
local activatedThisRound = setmetatable({}, { __mode = "k" })
local stateCache = setmetatable({}, { __mode = "k" })
local stateConnections = {}
local getPrompt

local function isSoloRun()
	local solo = ReplicatedStorage:FindFirstChild("Solo")
	return solo and solo:IsA("BoolValue") and solo.Value == true
end

local function isLocalHost()
	local player = Players.LocalPlayer
	return player and player:HasTag("Host") == true
end

local function disconnectState(root)
	local connections = stateConnections[root]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	stateConnections[root] = nil
	stateCache[root] = nil
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
	local used = (root:GetAttribute("AltarUsed") == true) or (tagged and tagged:GetAttribute("AltarUsed") == true)
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

local function refreshState(root, tagged)
	stateCache[root] = getAltarState(root, tagged)
	return stateCache[root]
end

local function hookState(root, tagged)
	if not root or stateConnections[root] then
		return refreshState(root, tagged)
	end

	stateConnections[root] = {}
	local function bind(signal)
		local ok, connection = pcall(function()
			return signal:Connect(function()
				if not root:IsDescendantOf(workspace) then
					disconnectState(root)
					return
				end
				refreshState(root, tagged)
			end)
		end)
		if ok and connection then
			table.insert(stateConnections[root], connection)
		end
	end

	bind(root:GetAttributeChangedSignal("AltarUsed"))
	if tagged and tagged ~= root then
		bind(tagged:GetAttributeChangedSignal("AltarUsed"))
	end
	bind(root.AncestryChanged)
	bind(CollectionService:GetInstanceAddedSignal("Voting"))
	bind(CollectionService:GetInstanceRemovedSignal("Voting"))
	bind(CollectionService:GetInstanceAddedSignal("Host"))
	bind(CollectionService:GetInstanceRemovedSignal("Host"))
	local solo = ReplicatedStorage:FindFirstChild("Solo")
	if solo and solo:IsA("BoolValue") then
		bind(solo.Changed)
	end

	local prompt = getPrompt(root, tagged)
	if prompt then
		bind(prompt:GetPropertyChangedSignal("Enabled"))
		bind(prompt:GetPropertyChangedSignal("HoldDuration"))
	end

	return refreshState(root, tagged)
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

local function buildSelectionPriority(controller)
	local selected = {}
	local priority = {}
	local selections = controller and controller.AltarSelections

	if typeof(selections) ~= "table" then
		return selected, priority
	end

	for index, altarName in ipairs(selections) do
		if typeof(altarName) == "string" and altarName ~= "" then
			selected[altarName] = true
			priority[altarName] = priority[altarName] or index
		end
	end

	for altarName, enabled in pairs(selections) do
		if typeof(altarName) == "string" and enabled == true then
			selected[altarName] = true
		end
	end

	for index, altarName in ipairs(ALTAR_ORDER) do
		if selected[altarName] and not priority[altarName] then
			priority[altarName] = index
		end
	end

	return selected, priority
end

local function isSelected(controller)
	local selected = buildSelectionPriority(controller)
	for _ in pairs(selected) do
		return true
	end
	return false
end

local function collectCandidates()
	local roots = {}
	local seen = {}

	for _, tagged in ipairs(CollectionService:GetTagged("Altar")) do
		if tagged and tagged:IsDescendantOf(workspace) then
			local root = tagged
			if tagged.Parent and tagged.Parent:IsDescendantOf(workspace) then
				root = tagged.Parent
			end

			if root and not seen[root] then
				seen[root] = tagged
				table.insert(roots, root)
			end

			if tagged and not seen[tagged] then
				seen[tagged] = tagged
				table.insert(roots, tagged)
			end
		end
	end

	return roots, seen
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
	local state = hookState(target.Root, target.Tagged)
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

local function findBestTarget(controller, hrp)
	local selected, priority = buildSelectionPriority(controller)
	if not next(selected) then
		return nil
	end

	if isValidTarget(currentTarget, selected) then
		return currentTarget
	end

	currentTarget = nil
	local roots, taggedByRoot = collectCandidates()
	local best = nil

	for _, root in ipairs(roots) do
		local tagged = taggedByRoot[root]
		local name = getAltarName(root, tagged)
		local state = hookState(root, tagged)
		if name
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
					Priority = priority[name] or 999,
					Distance = distance,
				}
				if not best
					or candidate.Priority < best.Priority
					or (candidate.Priority == best.Priority and candidate.Distance < best.Distance)
				then
					best = candidate
				end
			end
		end
	end

	currentTarget = best
	currentTargetStartedAt = best and os.clock() or 0
	return best
end

function Altar.tryStep(controller, hrp)
	if not (controller and hrp and hrp.Parent) then
		return false
	end
	if not isSelected(controller) then
		currentTarget = nil
		return false
	end

	local target = findBestTarget(controller, hrp)
	if not target then
		return false
	end
	if currentTargetStartedAt > 0 and os.clock() - currentTargetStartedAt > MAX_ACTIVATION_SECONDS then
		skippedUntil[target.Root] = os.clock() + SKIP_SECONDS
		currentTarget = nil
		currentTargetStartedAt = 0
		return false
	end

	local state = refreshState(target.Root, target.Tagged)
	if not (state and state.Ready == true) then
		currentTarget = nil
		currentTargetStartedAt = 0
		return false
	end

	local offset = Vector3.new(0, math.clamp(target.Hitbox.Size.Y * 0.25, 1, 4), 0)
	Context.moveCharacterTo(CFrame.new(target.Hitbox.Position + offset))

	if os.clock() - lastActionAt >= ACTION_COOLDOWN then
		lastActionAt = os.clock()
		task.wait(TOUCH_SETTLE)
		if not triggerPrompt(target.Prompt) then
			touch(target.Hitbox, hrp)
		end
		activatedThisRound[target.Root] = true
		currentTarget = nil
		currentTargetStartedAt = 0
	end

	return true, "ActivatingAltar", getStateDetail(target, state)
end

function Altar.reset()
	currentTarget = nil
	currentTargetStartedAt = 0
	lastActionAt = 0
	skippedUntil = setmetatable({}, { __mode = "k" })
	activatedThisRound = setmetatable({}, { __mode = "k" })
	for root in pairs(stateConnections) do
		disconnectState(root)
	end
	stateCache = setmetatable({}, { __mode = "k" })
end

return Altar
