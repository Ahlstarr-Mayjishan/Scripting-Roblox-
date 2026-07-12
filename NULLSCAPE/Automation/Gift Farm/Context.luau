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

	-- Check center and 4 horizontal offsets (cross pattern) to handle edges/gaps robustly
	local offsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(4.5, 0, 0),
		Vector3.new(-4.5, 0, 0),
		Vector3.new(0, 0, 4.5),
		Vector3.new(0, 0, -4.5)
	}

	for _, offset in ipairs(offsets) do
		local result = Workspace:Raycast(
			position + offset + Vector3.new(0, GROUND_RAY_HEIGHT, 0),
			Vector3.new(0, -GROUND_RAY_DISTANCE, 0),
			params
		)
		if result and result.Instance then
			return result
		end
	end

	return nil
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

	local waitTimeout = math.max(0, tonumber(timeout) or GROUND_WAIT_TIMEOUT)
	Context.requestStreamAround(position, waitTimeout)

	local deadline = os.clock() + waitTimeout
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

	Context.releaseCharacterControl({
		SkipVelocityClear = true,
		SkipTouchRestore = true,
		SkipStateChange = true,
	})

	if not (hrp and hrp.Parent) or Players.LocalPlayer.Character ~= character then
		return false
	end

	if not setRootCFrame(character, hrp, cframe) then
		return false
	end
	RunService.Heartbeat:Wait()
	if not setRootCFrame(character, hrp, cframe) then
		return false
	end

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

function Context.getCandidatePosition(item)
	if typeof(item) ~= "table" then
		return nil
	end

	local position = Context.getGiftPosition(item.rawObj) or item.pos
	if typeof(position) == "Vector3" then
		item.pos = position
		return position
	end
	return nil
end

local railConnection = nil
local modifiedRails = {}

function Context.suppressRails()
	if railConnection then
		return
	end

	modifiedRails = {}

	local function process(descendant)
		if descendant:IsA("BasePart") and descendant.Name == "_RailPart" then
			if modifiedRails[descendant] == nil then
				modifiedRails[descendant] = descendant.CanTouch
				pcall(function()
					descendant.CanTouch = false
				end)
			end
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		process(descendant)
	end

	railConnection = Workspace.DescendantAdded:Connect(process)
end

function Context.restoreRails()
	if railConnection then
		pcall(function()
			railConnection:Disconnect()
		end)
		railConnection = nil
	end

	for part, originalCanTouch in pairs(modifiedRails) do
		if part and part.Parent then
			pcall(function()
				part.CanTouch = originalCanTouch
			end)
		end
	end

	modifiedRails = {}
end

return Context
