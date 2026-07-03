--!nocheck
-- [[
--  NULLSCAPE - Automation Pylon Activator
--  Holds the player inside Celestial pylon activation hitboxes at level 35+.
-- ]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")

local PylonActivator = {}

local TARGET_LEVEL = 35
local HOLD_INTERVAL = 0.12
local ROOT_OFFSET = Vector3.new(0, 2, 0)

local enabled = false
local running = false
local savedCFrame = nil
local completedThisRound = 0

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
	return not (model and model:IsDescendantOf(workspace)) or model:GetAttribute("Completed") == true
end

local function getProgressDetail(model)
	local elapsed = tonumber(model:GetAttribute("TimeElapsed")) or 0
	local required = tonumber(model:GetAttribute("TimeRequired")) or 0
	local currentPlayers = tonumber(model:GetAttribute("CurrentPlayers")) or 0
	local progressing = model:GetAttribute("Progressing") == true

	if required > 0 then
		local percent = math.clamp(elapsed / required, 0, 1) * 100
		return string.format("%.0f%% | players %d | %s", percent, currentPlayers, progressing and "charging" or "waiting")
	end

	return currentPlayers > 0 and ("players " .. tostring(currentPlayers)) or ""
end

local function getCandidates(hrp)
	local candidates = {}
	for _, model in ipairs(CollectionService:GetTagged("Pylon")) do
		if model and model:IsDescendantOf(workspace) and not isCompleted(model) then
			local root = getPylonRoot(model)
			if root then
				table.insert(candidates, {
					Model = model,
					Root = root,
					Distance = (root.Position - hrp.Position).Magnitude,
				})
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	return candidates
end

local function holdAtRoot(hrp, root)
	if not (hrp and hrp.Parent and root and root.Parent) then
		return
	end

	Context.moveCharacterTo(root.CFrame + ROOT_OFFSET)
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
end

local function restorePosition(controller)
	if controller and controller.PylonActivatorReturnAfter ~= false and savedCFrame then
		local hrp = getRootPart()
		if hrp and hrp.Parent then
			Context.moveCharacterTo(savedCFrame)
		end
	end
	savedCFrame = nil
end

local function run(controller)
	if running then
		return
	end

	running = true
	task.spawn(function()
		while enabled and controller and not controller.Destroyed do
			if not isInRound() then
				controller.PylonActivatorHolding = false
				controller.PylonActivatorComplete = false
				completedThisRound = 0
				restorePosition(controller)
				setStatus(controller, "WaitingForRound")
				task.wait(0.5)
				continue
			end

			if getLevel() < TARGET_LEVEL then
				controller.PylonActivatorHolding = false
				setStatus(controller, "WaitingForLevel", "Level " .. tostring(getLevel()) .. "/" .. tostring(TARGET_LEVEL))
				task.wait(0.75)
				continue
			end

			if controller.GiftFarmGoldenComplete ~= true then
				controller.PylonActivatorHolding = false
				restorePosition(controller)
				setStatus(controller, "WaitingForGolden", "Gift Farm must clear golden gifts first")
				task.wait(0.5)
				continue
			end

			local hrp = getRootPart()
			if not hrp then
				controller.PylonActivatorHolding = false
				setStatus(controller, "WaitingForCharacter")
				task.wait(0.5)
				continue
			end

			local candidates = getCandidates(hrp)
			if #candidates == 0 then
				controller.PylonActivatorHolding = false
				restorePosition(controller)
				controller.PylonActivatorComplete = completedThisRound > 0
				setStatus(controller, "WaitingForPylons")
				task.wait(0.5)
				continue
			end

			local target = candidates[1]
			savedCFrame = savedCFrame or hrp.CFrame
			controller.PylonActivatorHolding = true

			while enabled and controller and not controller.Destroyed and isInRound() and getLevel() >= TARGET_LEVEL do
				if isCompleted(target.Model) then
					break
				end

				local root = getPylonRoot(target.Model)
				hrp = getRootPart()
				if not (root and hrp) then
					break
				end

				holdAtRoot(hrp, root)
				setStatus(controller, "Activating", getProgressDetail(target.Model))
				task.wait(HOLD_INTERVAL)
			end

			controller.PylonActivatorHolding = false
			if isCompleted(target.Model) then
				completedThisRound += 1
				setStatus(controller, "Completed", "Pylon activated")
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
