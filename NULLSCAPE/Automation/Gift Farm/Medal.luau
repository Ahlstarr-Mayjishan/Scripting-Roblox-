--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Beacon = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Beacon.luau")

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Medal = {}

local ACTION_COOLDOWN = 0.8
local TOUCH_SETTLE = 0.08
local lastActionAt = 0
local statusHandler = nil

local function getCharacter()
	return Players.LocalPlayer and Players.LocalPlayer.Character
end

local function getStatusHandler()
	if statusHandler ~= nil then
		return statusHandler
	end

	local clientModules = ReplicatedFirst:FindFirstChild("ClientModules")
		or ReplicatedStorage:FindFirstChild("ClientModules")
	local module = clientModules and clientModules:FindFirstChild("StatusEffectHandler")
	if not module then
		statusHandler = false
		return nil
	end

	local ok, result = pcall(require, module)
	statusHandler = ok and result or false
	return statusHandler ~= false and statusHandler or nil
end

local function getPartFromMedal(medal)
	if not medal then
		return nil
	end
	if medal:IsA("BasePart") then
		return medal
	end
	if medal:IsA("Model") then
		return medal:FindFirstChild("Handle") or medal:FindFirstChildWhichIsA("BasePart", true)
	end
	return medal:FindFirstChild("Handle") or medal:FindFirstChildWhichIsA("BasePart", true)
end

local function medalHeldByLocalPlayer(medal)
	local character = getCharacter()
	if not (medal and character) then
		return false
	end

	if medal:IsDescendantOf(character) then
		return true
	end

	local holder = medal:FindFirstChild("Holder")
	if holder and holder:IsA("ObjectValue") then
		local value = holder.Value
		return value == character
			or value == character:FindFirstChild("HumanoidRootPart")
			or (value and value:IsDescendantOf(character))
	end

	return false
end

local function getMedalPart()
	local medal = workspace:FindFirstChild("Medal")
	local part = getPartFromMedal(medal)
	if part and not medalHeldByLocalPlayer(medal) then
		return part
	end

	for _, tagged in ipairs(CollectionService:GetTagged("Medal")) do
		part = getPartFromMedal(tagged)
		if part and not medalHeldByLocalPlayer(tagged) then
			return part
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "Medal" then
			part = getPartFromMedal(descendant)
			if part and not medalHeldByLocalPlayer(descendant) then
				return part
			end
		end
	end

	return nil
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

local function carriesMedal()
	local character = getCharacter()
	if character and character:FindFirstChild("Medal") ~= nil then
		return true
	end

	local handler = getStatusHandler()
	if handler and typeof(handler.HasStatus) == "function" then
		local ok, result = pcall(function()
			return handler.HasStatus("Medal")
		end)
		if ok and result == true then
			return true
		end
	end

	local medal = workspace:FindFirstChild("Medal")
	if medalHeldByLocalPlayer(medal) then
		return true
	end
	for _, tagged in ipairs(CollectionService:GetTagged("Medal")) do
		if medalHeldByLocalPlayer(tagged) then
			return true
		end
	end

	return false
end

function Medal.tryStep(controller, hrp)
	if not (controller and controller.CollectMedalEnabled == true and hrp and hrp.Parent) then
		return false
	end
	if os.clock() - lastActionAt < ACTION_COOLDOWN then
		return false
	end

	if carriesMedal() then
		if controller.GiftFarmGoldenComplete ~= true then
			return false
		end

		local beacon = Context.getBeaconPart()
		if not beacon then
			return false
		end

		lastActionAt = os.clock()
		if Beacon and typeof(Beacon.restore) == "function" then
			Beacon.restore()
		end
		Context.moveCharacterTo(CFrame.new(beacon.Position + Vector3.new(0, 4, 0)))
		task.wait(TOUCH_SETTLE)
		touch(beacon, hrp)
		return true, "SubmittingMedal"
	end

	local medalPart = getMedalPart()
	if not medalPart then
		return false
	end

	lastActionAt = os.clock()
	Context.moveCharacterTo(medalPart.CFrame + Vector3.new(0, 2, 0))
	task.wait(TOUCH_SETTLE)
	touch(medalPart, hrp)
	return true, "CollectingMedal"
end

function Medal.isCarrying()
	return carriesMedal()
end

function Medal.reset()
	lastActionAt = 0
end

return Medal
