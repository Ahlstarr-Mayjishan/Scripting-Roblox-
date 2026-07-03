--!nocheck

local CollectionService = game:GetService("CollectionService")

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

local function getPrompt(root, tagged)
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

local function isUsed(root, tagged)
	return (root and root:GetAttribute("AltarUsed") == true) or (tagged and tagged:GetAttribute("AltarUsed") == true)
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
	return not isUsed(target.Root, target.Tagged)
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
		if name
			and selected[name]
			and not isUsed(root, tagged)
			and not (skippedUntil[root] and os.clock() < skippedUntil[root])
		then
			local hitbox = getHitbox(root) or getHitbox(tagged)
			if hitbox then
				local distance = (hitbox.Position - hrp.Position).Magnitude
				local candidate = {
					Root = root,
					Tagged = tagged,
					Hitbox = hitbox,
					Prompt = getPrompt(root, tagged),
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

	local offset = Vector3.new(0, math.clamp(target.Hitbox.Size.Y * 0.25, 1, 4), 0)
	Context.moveCharacterTo(CFrame.new(target.Hitbox.Position + offset))

	if os.clock() - lastActionAt >= ACTION_COOLDOWN then
		lastActionAt = os.clock()
		task.wait(TOUCH_SETTLE)
		if not triggerPrompt(target.Prompt) then
			touch(target.Hitbox, hrp)
		end
	end

	return true, "ActivatingAltar", target.Name
end

function Altar.reset()
	currentTarget = nil
	currentTargetStartedAt = 0
	lastActionAt = 0
	skippedUntil = setmetatable({}, { __mode = "k" })
end

return Altar
