--!nocheck
-- [[
--  NULLSCAPE - Automation Pylon Activator
--  Holds the player inside Celestial pylon activation hitboxes at level 35+.
-- ]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local MovementLease = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/MovementLease.luau")

local PylonActivator = {}

local TARGET_LEVEL = 35
local HOLD_INTERVAL = 0.12
local ROOT_OFFSET = Vector3.new(0, 2, 0)
local STREAM_REQUEST_TIMEOUT = 1.25
local STREAM_RETRY_INTERVAL = 0.75
local PYLON_MATCH_RADIUS = 8
local COMPLETION_SETTLE_TIMEOUT = 0.75

local enabled = false
local running = false
local savedCFrame = nil
local knownPylons = {}
local pylonAddedConnection = nil
local pylonRemovedConnection = nil
local pylonRegistryDirty = true
local lastPylonRefreshAt = -math.huge
local PYLON_SAFETY_REFRESH_INTERVAL = 1

local function setStatus(controller, status, detail)
	if controller then
		controller.PylonActivatorStatus = status or "Idle"
		controller.PylonActivatorDetail = detail or ""
	end
end

local function getRootPart()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isInRound()
	local inRound = ReplicatedStorage:FindFirstChild("InRound")
	return not (inRound and inRound:IsA("BoolValue")) or inRound.Value == true
end

local function getLevel()
	local level = ReplicatedStorage:FindFirstChild("Level")
	if level and (level:IsA("IntValue") or level:IsA("NumberValue")) then
		return tonumber(level.Value) or 0
	end
	return 0
end

local function getPylonRoot(model)
	if typeof(model) ~= "Instance" then
		return nil
	end

	local stayNear = model:FindFirstChild("StayNear")
	if stayNear and stayNear:IsA("BasePart") then
		return stayNear
	end

	local hitBox = model:FindFirstChild("HitBox")
	if hitBox and hitBox:IsA("BasePart") then
		return hitBox
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function isCompleted(model)
	return model ~= nil and model:GetAttribute("Completed") == true
end

local function getPylonProgress()
	local completed = tonumber(ReplicatedStorage:GetAttribute("PylonsDone")) or 0
	local maximum = tonumber(ReplicatedStorage:GetAttribute("MaxPylons")) or 0
	return completed, maximum
end

local function areAllPylonsComplete()
	local completed, maximum = getPylonProgress()
	return maximum > 0 and completed >= maximum
end

local function hasPendingPylons()
	local completed, maximum = getPylonProgress()
	if maximum > completed then
		return true
	end
	for _, record in ipairs(knownPylons) do
		if not record.Completed then
			return true
		end
	end
	return false
end

local function getPylonProgressDetail(prefix)
	local completed, maximum = getPylonProgress()
	if maximum > 0 then
		return string.format("%s | %d/%d", prefix, completed, maximum)
	end
	return prefix
end

local function getPylonPosition(model)
	local root = getPylonRoot(model)
	if root then
		return root.Position
	end

	if model and model:IsA("Model") then
		local ok, pivot = pcall(model.GetPivot, model)
		if ok then
			return pivot.Position
		end
	end

	return nil
end

local function findKnownPylon(model, position)
	for _, record in ipairs(knownPylons) do
		if record.Model == model then
			return record
		end
	end

	if position then
		for _, record in ipairs(knownPylons) do
			local liveModel = record.Model
			if
				not (liveModel and liveModel:IsDescendantOf(workspace))
				and record.Position
				and (record.Position - position).Magnitude <= PYLON_MATCH_RADIUS
			then
				return record
			end
		end
	end

	return nil
end

local function rememberPylon(model)
	if not (model and model:IsDescendantOf(workspace)) then
		return nil
	end

	local position = getPylonPosition(model)
	if not position then
		return nil
	end

	local record = findKnownPylon(model, position)
	if not record then
		record = {
			Model = model,
			Position = position,
			Completed = false,
			NextStreamAt = 0,
		}
		table.insert(knownPylons, record)
	else
		record.Model = model
		record.Position = position
	end
	record.Completed = record.Completed or isCompleted(model)
	pylonRegistryDirty = true
	return record
end

local function refreshKnownPylons(force)
	local now = os.clock()
	if not force and not pylonRegistryDirty and now - lastPylonRefreshAt < PYLON_SAFETY_REFRESH_INTERVAL then
		return
	end
	for _, model in ipairs(CollectionService:GetTagged("Pylon")) do
		rememberPylon(model)
	end

	for _, record in ipairs(knownPylons) do
		local model = record.Model
		if model and model:IsDescendantOf(workspace) then
			record.Position = getPylonPosition(model) or record.Position
			record.Completed = record.Completed or isCompleted(model)
		elseif model then
			record.Completed = record.Completed or isCompleted(model)
			record.Model = nil
		end
	end
	pylonRegistryDirty = false
	lastPylonRefreshAt = now
end

local function resetKnownPylons()
	table.clear(knownPylons)
	pylonRegistryDirty = true
	lastPylonRefreshAt = -math.huge
end

local function startPylonObserver()
	if pylonAddedConnection then
		return
	end

	pylonAddedConnection = CollectionService:GetInstanceAddedSignal("Pylon"):Connect(function(model)
		pylonRegistryDirty = true
		task.spawn(function()
			for _ = 1, 20 do
				if not enabled then
					return
				end
				if isInRound() and rememberPylon(model) then
					return
				end
				task.wait(0.1)
			end
		end)
	end)
	pylonRemovedConnection = CollectionService:GetInstanceRemovedSignal("Pylon"):Connect(function(model)
		local record = findKnownPylon(model)
		if record then
			record.Completed = record.Completed or isCompleted(model)
			record.Model = nil
		end
		pylonRegistryDirty = true
	end)
end

local function stopPylonObserver()
	if pylonAddedConnection then
		pylonAddedConnection:Disconnect()
		pylonAddedConnection = nil
	end
	if pylonRemovedConnection then
		pylonRemovedConnection:Disconnect()
		pylonRemovedConnection = nil
	end
end

local function getProgressDetail(model)
	local elapsed = tonumber(model:GetAttribute("TimeElapsed")) or 0
	local required = tonumber(model:GetAttribute("TimeRequired")) or 0
	local currentPlayers = tonumber(model:GetAttribute("CurrentPlayers")) or 0
	local progressing = model:GetAttribute("Progressing") == true

	if required > 0 then
		local percent = math.clamp(elapsed / required, 0, 1) * 100
		return string.format(
			"%.0f%% | players %d | %s",
			percent,
			currentPlayers,
			progressing and "charging" or "waiting"
		)
	end

	return currentPlayers > 0 and ("players " .. tostring(currentPlayers)) or ""
end

local function getCandidates(hrp)
	local candidates = {}
	refreshKnownPylons()
	for _, record in ipairs(knownPylons) do
		if not record.Completed and record.Position then
			local model = record.Model
			local root = model and model:IsDescendantOf(workspace) and getPylonRoot(model) or nil
			table.insert(candidates, {
				Record = record,
				Model = model,
				Root = root,
				Position = root and root.Position or record.Position,
				Distance = (record.Position - hrp.Position).Magnitude,
				Loaded = root ~= nil,
			})
		end
	end

	table.sort(candidates, function(a, b)
		if a.Loaded ~= b.Loaded then
			return a.Loaded
		end
		return a.Distance < b.Distance
	end)
	return candidates
end

local function resolveCandidate(controller, candidate)
	local record = candidate.Record
	local model = record and record.Model or candidate.Model
	local root = model and model:IsDescendantOf(workspace) and getPylonRoot(model) or nil
	if root then
		return model, root
	end

	local now = os.clock()
	if not (record and record.Position) or now < (record.NextStreamAt or 0) then
		return nil, nil
	end

	record.NextStreamAt = now + STREAM_RETRY_INTERVAL
	setStatus(controller, "StreamingPylon", getPylonProgressDetail("Loading remaining pylon"))
	if Context and typeof(Context.requestStreamAround) == "function" then
		Context.requestStreamAround(record.Position, STREAM_REQUEST_TIMEOUT)
	end
	refreshKnownPylons(true)

	model = record.Model
	root = model and model:IsDescendantOf(workspace) and getPylonRoot(model) or nil
	return model, root
end

local function confirmTargetCompletion(candidate, completedBefore)
	local deadline = os.clock() + COMPLETION_SETTLE_TIMEOUT
	repeat
		local record = candidate.Record
		local model = record and record.Model or candidate.Model
		if isCompleted(model) then
			if record then
				record.Completed = true
			end
			return true
		end

		local completed = getPylonProgress()
		if completed > completedBefore then
			if record then
				record.Completed = true
			end
			return true
		end

		if os.clock() >= deadline then
			return false
		end
		task.wait(HOLD_INTERVAL)
	until false
end

local function holdAtRoot(hrp, root, lease)
	if not (hrp and hrp.Parent and root and root.Parent and lease and lease:isValid()) then
		return false
	end

	if not lease:moveTo(root.CFrame + ROOT_OFFSET) then
		return false
	end
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
	return true
end

local function restorePosition(controller)
	local returnCFrame = savedCFrame
	savedCFrame = nil
	if
		not (controller and not controller.Destroyed and controller.PylonActivatorReturnAfter ~= false and returnCFrame)
	then
		return false
	end
	if not isInRound() or controller.GiftFarmPolicyHolding == true then
		return false
	end

	local lease = MovementLease.tryAcquire("PylonReturn")
	if not lease then
		return false
	end
	local restored = lease:moveTo(returnCFrame)
	lease:release()
	return restored
end

local function run(controller)
	if running then
		return
	end

	running = true
	task.spawn(function()
		while enabled and controller and not controller.Destroyed do
			if controller.GiftFarmXpTripcoinMode == true then
				controller.PylonActivatorHolding = false
				controller.PylonActivatorComplete = false
				setStatus(controller, "DisabledForXpTripcoin", "All upgrades owned; normal Gift farming only")
				task.wait(0.5)
				continue
			end

			if not isInRound() then
				controller.PylonActivatorHolding = false
				controller.PylonActivatorComplete = false
				resetKnownPylons()
				savedCFrame = nil
				setStatus(controller, "WaitingForRound")
				task.wait(0.5)
				continue
			end

			if controller.GiftFarmPolicyHolding == true or controller.GiftFarmRestPending == true then
				controller.PylonActivatorHolding = false
				setStatus(controller, "WaitingForGiftFarmPolicy", controller.GiftFarmDetail)
				task.wait(0.25)
				continue
			end

			if getLevel() < TARGET_LEVEL then
				controller.PylonActivatorHolding = false
				controller.PylonActivatorComplete = false
				setStatus(
					controller,
					"WaitingForLevel",
					"Level " .. tostring(getLevel()) .. "/" .. tostring(TARGET_LEVEL)
				)
				task.wait(0.75)
				continue
			end

			refreshKnownPylons()

			if controller.GiftFarmGoldenComplete ~= true then
				controller.PylonActivatorHolding = false
				setStatus(controller, "WaitingForGolden", "Gift Farm must clear golden gifts first")
				task.wait(0.5)
				continue
			end

			if areAllPylonsComplete() then
				controller.PylonActivatorComplete = true
				restorePosition(controller)
				controller.PylonActivatorHolding = false
				setStatus(controller, "Completed", getPylonProgressDetail("All pylons activated"))
				task.wait(0.5)
				continue
			end
			if not hasPendingPylons() then
				controller.PylonActivatorHolding = false
				setStatus(controller, "WaitingForPylons", "Waiting for native pylon progress")
				task.wait(0.25)
				continue
			end

			controller.PylonActivatorComplete = false
			controller.PylonActivatorHolding = true
			local hrp = getRootPart()
			if not hrp then
				setStatus(controller, "WaitingForCharacter")
				task.wait(0.5)
				continue
			end

			local candidates = getCandidates(hrp)
			if #candidates == 0 then
				controller.PylonActivatorComplete = areAllPylonsComplete()
				if controller.PylonActivatorComplete then
					restorePosition(controller)
					controller.PylonActivatorHolding = false
					setStatus(controller, "Completed", getPylonProgressDetail("All pylons activated"))
				else
					setStatus(controller, "WaitingForPylons", getPylonProgressDetail("Waiting for remaining pylons"))
				end
				task.wait(0.5)
				continue
			end

			local target = candidates[1]
			local targetModel, targetRoot = resolveCandidate(controller, target)
			if not (targetModel and targetRoot) then
				task.wait(0.2)
				continue
			end
			local lease = MovementLease.tryAcquire("PylonActivator")
			if not lease then
				setStatus(controller, "WaitingForMovement", MovementLease.getActiveOwner() or "Movement busy")
				task.wait(0.12)
				continue
			end
			target.Model = targetModel
			target.Root = targetRoot
			savedCFrame = savedCFrame or hrp.CFrame
			local completedBefore = getPylonProgress()

			while
				enabled
				and controller
				and not controller.Destroyed
				and isInRound()
				and getLevel() >= TARGET_LEVEL
				and controller.GiftFarmXpTripcoinMode ~= true
				and controller.GiftFarmGoldenComplete == true
				and controller.GiftFarmPolicyHolding ~= true
				and controller.GiftFarmRestPending ~= true
				and lease:isValid()
			do
				if isCompleted(target.Model) then
					break
				end

				local root = getPylonRoot(target.Model)
				hrp = getRootPart()
				if not root and target.Record then
					target.Record.Model = nil
					target.Model, root = resolveCandidate(controller, target)
				end
				if not (target.Model and root and hrp) then
					break
				end

				if not holdAtRoot(hrp, root, lease) then
					break
				end
				setStatus(controller, "Activating", getProgressDetail(target.Model))
				task.wait(HOLD_INTERVAL)
			end

			lease:release()
			if confirmTargetCompletion(target, completedBefore) then
				controller.PylonActivatorComplete = areAllPylonsComplete()
				if controller.PylonActivatorComplete then
					restorePosition(controller)
					controller.PylonActivatorHolding = false
				end
				setStatus(controller, "Completed", getPylonProgressDetail("Pylon activated"))
			else
				setStatus(controller, "WaitingForPylons", getPylonProgressDetail("Pylon not confirmed; retrying"))
			end
			task.wait(0.2)
		end

		if controller then
			controller.PylonActivatorHolding = false
		end
		restorePosition(controller)
		running = false
	end)
end

function PylonActivator.update(controller)
	enabled = controller and controller.PylonActivatorEnabled == true
	if enabled then
		controller.PylonActivatorComplete = false
		startPylonObserver()
		refreshKnownPylons()
		run(controller)
	else
		if controller then
			controller.PylonActivatorHolding = false
			controller.PylonActivatorComplete = false
		end
		restorePosition(controller)
		setStatus(controller, "Idle")
	end
	return true
end

function PylonActivator.disable(controller)
	enabled = false
	stopPylonObserver()
	resetKnownPylons()
	if controller then
		controller.PylonActivatorHolding = false
		controller.PylonActivatorComplete = false
	end
	restorePosition(controller)
	setStatus(controller, "Idle")
	return true
end

function PylonActivator.getStatus(controller)
	return {
		Status = controller and controller.PylonActivatorStatus or "Idle",
		Detail = controller and controller.PylonActivatorDetail or "",
	}
end

return PylonActivator
