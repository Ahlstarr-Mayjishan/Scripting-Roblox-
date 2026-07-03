--!nocheck

local Context = {}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local cachedGCH = nil

function Context.getGiftClientHandler()
	if cachedGCH then
		return cachedGCH
	end

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

function Context.getCollectedGiftEvent()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local events = movement and movement:FindFirstChild("Events")
	return events and events:FindFirstChild("CollectedGift")
end

function Context.getRootPart()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
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
