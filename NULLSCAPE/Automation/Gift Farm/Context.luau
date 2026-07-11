--!nocheck

local Context = {}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local beaconPartStates = nil
local STREAM_REQUEST_TIMEOUT = 2.5
local GROUND_WAIT_TIMEOUT = 1.25
local GROUND_RAY_HEIGHT = 14
local GROUND_RAY_DISTANCE = 96

local function collectBeaconParts()
	local beacon = workspace:FindFirstChild("Beacon")
	if not beacon then
		return {}
	end

	if beacon:IsA("BasePart") then
		return { beacon }
	end

	local parts = {}
	for _, descendant in ipairs(beacon:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

function Context.getGiftClientHandler()
	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		or ReplicatedStorage:FindFirstChild("ClientModules")
	local giftClient = clientModules and clientModules:FindFirstChild("GiftClient")
	local handlerModule = giftClient and giftClient:FindFirstChild("GiftClientHandler")
	if not handlerModule then
		return nil
	end

	local ok, result = pcall(require, handlerModule)
	if ok and typeof(result) == "table" then
		return result
	end

	return nil
end

function Context.resetGiftClientHandler()
	-- No-op
end

function Context.getCollectedGiftEvent()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local events = movement and movement:FindFirstChild("Events")
	return events and events:FindFirstChild("CollectedGift")
end

function Context.getRootPart()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function raycastCurrentRoomsFloor(position)
	local currentRooms = Workspace:FindFirstChild("CurrentRooms")
	if not currentRooms then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { currentRooms }
	params.RespectCanCollide = true

	return Workspace:Raycast(
		position + Vector3.new(0, GROUND_RAY_HEIGHT, 0),
		Vector3.new(0, -GROUND_RAY_DISTANCE, 0),
		params
	)
end

function Context.requestStreamAround(position, timeout)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local ok = pcall(function()
		Workspace:RequestStreamAroundAsync(position, timeout or STREAM_REQUEST_TIMEOUT)
	end)
	return ok == true
end

function Context.waitForStreamedGround(position, timeout)
	if typeof(position) ~= "Vector3" then
		return false
	end

	Context.requestStreamAround(position, STREAM_REQUEST_TIMEOUT)

	local deadline = os.clock() + (timeout or GROUND_WAIT_TIMEOUT)
	repeat
		local result = raycastCurrentRoomsFloor(position)
		if result and result.Instance then
			return true
		end
		RunService.Heartbeat:Wait()
	until os.clock() >= deadline

	return false
end

function Context.releaseCharacterControl(options)
	options = options or {}

	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp.Parent) then
		return false
	end

	pcall(function()
		if Context.isInRound() then
			hrp.Anchored = false
		end
		if options.SkipVelocityClear ~= true then
			hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end)

	if options.SkipTouchRestore ~= true then
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				pcall(function()
					descendant.CanTouch = true
				end)
			end
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			if options.ForceAbilityClear == true then
				humanoid:SetAttribute("UsingAbility", false)
			end
			humanoid.PlatformStand = false
			humanoid.Sit = false
			humanoid.AutoRotate = true
		end)
		if options.SkipStateChange ~= true and options.State ~= nil and humanoid.Health > 0 then
			pcall(function()
				humanoid:ChangeState(options.State)
			end)
		end
	end

	if options.ForceAbilityClear == true then
		pcall(function()
			character:SetAttribute("ChargingCheck", false)
		end)
	end

	return true
end

local function setRootCFrame(character, hrp, cframe)
	if not (character and hrp and hrp.Parent) then
		return false
	end

	local ok = pcall(function()
		if Context.isInRound() then
			hrp.Anchored = false
		end
		hrp.CFrame = cframe
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
	return ok == true
end

function Context.moveCharacterTo(cframe)
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp.Parent) then
		return false
	end

	local targetPos = cframe.Position
	if Context.isInRound() and not Context.waitForStreamedGround(targetPos) then
		return false
	end

	Context.releaseCharacterControl({
		SkipVelocityClear = true,
		SkipTouchRestore = true,
		SkipStateChange = true,
	})

	local startPos = hrp.Position
	local direction = (targetPos - startPos)
	local distance = direction.Magnitude
	local stepSize = 75

	if distance > stepSize then
		local steps = math.ceil(distance / stepSize)
		local unitDir = direction.Unit
		for i = 1, steps - 1 do
			if not (hrp and hrp.Parent) or Players.LocalPlayer.Character ~= character then
				break
			end
			local intermediatePos = startPos + unitDir * (i * stepSize)
			local intermediateCFrame = CFrame.new(intermediatePos, intermediatePos + hrp.CFrame.LookVector)

			local ok = setRootCFrame(character, hrp, intermediateCFrame)
			if not ok then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end

	if not (hrp and hrp.Parent) or Players.LocalPlayer.Character ~= character then
		return false
	end

	setRootCFrame(character, hrp, cframe)
	RunService.Heartbeat:Wait()
	setRootCFrame(character, hrp, cframe)

	return true
end

function Context.getBeaconPart()
	local beacon = workspace:FindFirstChild("Beacon")
	if not beacon then
		return nil
	end

	if beacon:IsA("BasePart") then
		return beacon
	end

	if beacon:IsA("Model") then
		return beacon.PrimaryPart or beacon:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function Context.isBeaconActive()
	local beacon = workspace:FindFirstChild("Beacon")
	return not (beacon and beacon:GetAttribute("Beacon") == false)
end

function Context.suppressBeaconInteraction()
	local parts = collectBeaconParts()
	if #parts == 0 then
		return false
	end

	beaconPartStates = beaconPartStates or {}
	for _, part in ipairs(parts) do
		if beaconPartStates[part] == nil then
			beaconPartStates[part] = {
				CanTouch = part.CanTouch,
				CanCollide = part.CanCollide,
				CanQuery = part.CanQuery,
			}
		end
		pcall(function()
			part.CanTouch = false
			part.CanCollide = false
			part.CanQuery = false
		end)
	end

	return true
end

function Context.isBeaconInteractionSuppressed()
	return beaconPartStates ~= nil
end

function Context.restoreBeaconInteraction()
	if not beaconPartStates then
		return false
	end

	for part, state in pairs(beaconPartStates) do
		if part and part.Parent then
			pcall(function()
				part.CanTouch = state.CanTouch
				part.CanCollide = state.CanCollide
				part.CanQuery = state.CanQuery
			end)
		end
	end

	beaconPartStates = nil
	return true
end

function Context.forceBeaconInteraction()
	if beaconPartStates then
		Context.restoreBeaconInteraction()
	end

	local parts = collectBeaconParts()
	if #parts == 0 then
		beaconPartStates = nil
		return false
	end

	for _, part in ipairs(parts) do
		if part and part.Parent then
			pcall(function()
				part.CanTouch = true
				part.CanQuery = true
			end)
		end
	end

	beaconPartStates = nil
	return true
end

function Context.isInRound()
	local inRound = ReplicatedStorage:FindFirstChild("InRound")
	return not (inRound and inRound:IsA("BoolValue")) or inRound.Value == true
end

function Context.getInRoundValue()
	local inRound = ReplicatedStorage:FindFirstChild("InRound")
	if inRound and inRound:IsA("BoolValue") then
		return inRound
	end
	return nil
end

function Context.getGiftPosition(gift)
	local pos = gift and gift.Position
	if typeof(pos) == "Vector3" then
		return pos
	end

	local model = gift and gift.Model
	if typeof(model) == "Instance" then
		if model:IsA("BasePart") then
			return model.Position
		end

		local part = model:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	return nil
end

return Context
