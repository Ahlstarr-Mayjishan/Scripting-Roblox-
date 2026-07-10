--!nocheck

local Context = {}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local cachedGCH = nil
local beaconPartStates = nil

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
	if cachedGCH and typeof(cachedGCH.Gifts) == "table" then
		return cachedGCH
	end
	cachedGCH = nil

	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		or ReplicatedStorage:FindFirstChild("ClientModules")
	local giftClient = clientModules and clientModules:FindFirstChild("GiftClient")
	local handlerModule = giftClient and giftClient:FindFirstChild("GiftClientHandler")
	if not handlerModule then
		return nil
	end

	local ok, result = pcall(require, handlerModule)
	if ok and typeof(result) == "table" then
		cachedGCH = result
		return result
	end

	return nil
end

function Context.resetGiftClientHandler()
	cachedGCH = nil
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

function Context.releaseCharacterControl(options)
	options = options or {}

	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp.Parent) then
		return false
	end

	pcall(function()
		hrp.Anchored = false
		if options.SkipVelocityClear ~= true then
			hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.PlatformStand = false
			humanoid.Sit = false
			humanoid.AutoRotate = true
		end)
		if options.SkipStateChange ~= true and humanoid.Health > 0 then
			pcall(function()
				humanoid:ChangeState(options.State or Enum.HumanoidStateType.Running)
			end)
		end
	end

	return true
end

function Context.moveCharacterTo(cframe)
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp.Parent) then
		return false
	end
	Context.releaseCharacterControl({
		SkipVelocityClear = true,
		SkipStateChange = true,
	})

	local startPos = hrp.Position
	local targetPos = cframe.Position
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

			local ok = pcall(function()
				if character and typeof(character.PivotTo) == "function" then
					character:PivotTo(intermediateCFrame)
				else
					hrp.CFrame = intermediateCFrame
				end
				hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end)
			if not ok then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end

	if not (hrp and hrp.Parent) or Players.LocalPlayer.Character ~= character then
		return false
	end

	local moved = false
	if character and typeof(character.PivotTo) == "function" then
		moved = pcall(function()
			character:PivotTo(cframe)
		end)
	end

	if not moved then
		hrp.CFrame = cframe
	end

	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)

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
