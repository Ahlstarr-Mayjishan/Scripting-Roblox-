--!nocheck

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local Beacon = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Beacon.luau")
local MedalRegistry = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Medal Registry.luau")

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Medal = {}

local ACTION_COOLDOWN = 0.8
local TOUCH_SETTLE = 0.08
local lastActionAt = 0
local manualActionBusy = false
local statusHandler = nil
local espEnabled = false
local espConnections = {}
local espHighlights = setmetatable({}, { __mode = "k" })

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

	for _, medalInstance in ipairs(MedalRegistry.getInstances()) do
		part = getPartFromMedal(medalInstance)
		if part and not medalHeldByLocalPlayer(medalInstance) then
			return part
		end
	end

	return nil
end

local function touch(part, hrp)
	if typeof(firetouchinterest) ~= "function" then
		return false
	end
	local ok = pcall(function()
		firetouchinterest(hrp, part, 0)
		task.wait()
		firetouchinterest(hrp, part, 1)
	end)
	return ok
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
	for _, medalInstance in ipairs(MedalRegistry.getInstances()) do
		if medalHeldByLocalPlayer(medalInstance) then
			return true
		end
	end

	return false
end

local function removeESP(medal)
	local highlight = medal and espHighlights[medal]
	if highlight then
		espHighlights[medal] = nil
		highlight:Destroy()
	end
end

local function applyESP(medal)
	if not (espEnabled and medal and medal:IsDescendantOf(workspace)) or medalHeldByLocalPlayer(medal) then
		removeESP(medal)
		return
	end

	local adornee = if medal:IsA("BasePart") or medal:IsA("Model") then medal else getPartFromMedal(medal)
	if not adornee then
		return
	end

	local highlight = espHighlights[medal]
	if not (highlight and highlight.Parent) then
		highlight = Instance.new("Highlight")
		highlight.Name = "NULLSCAPE_MedalESP"
		highlight.FillColor = Color3.fromRGB(255, 205, 55)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.35
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = adornee
		espHighlights[medal] = highlight
	end
	highlight.Adornee = adornee
	highlight.Enabled = true
end

local function clearESP()
	for medal, highlight in pairs(espHighlights) do
		espHighlights[medal] = nil
		if highlight then
			highlight:Destroy()
		end
	end
	for _, connection in ipairs(espConnections) do
		connection:Disconnect()
	end
	table.clear(espConnections)
end

local function scanMedalsForESP()
	for _, medalInstance in ipairs(MedalRegistry.getInstances()) do
		applyESP(medalInstance)
	end
end

function Medal.tryStep(controller, hrp, lease, _currentSessionToken)
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
		if lease then
			lease:moveTo(CFrame.new(beacon.Position + Vector3.new(0, 4, 0)))
		else
			Context.moveCharacterTo(CFrame.new(beacon.Position + Vector3.new(0, 4, 0)))
		end
		if lease and not lease:isValid() then
			return false
		end
		task.wait(TOUCH_SETTLE)
		if lease and not lease:isValid() then
			return false
		end
		touch(beacon, hrp)
		return true, "SubmittingMedal"
	end

	local medalPart = getMedalPart()
	if not medalPart then
		return false
	end

	lastActionAt = os.clock()
	if lease then
		lease:moveTo(medalPart.CFrame + Vector3.new(0, 2, 0))
	else
		Context.moveCharacterTo(medalPart.CFrame + Vector3.new(0, 2, 0))
	end
	if lease and not lease:isValid() then
		return false
	end
	task.wait(TOUCH_SETTLE)
	if lease and not lease:isValid() then
		return false
	end
	touch(medalPart, hrp)
	return true, "CollectingMedal"
end

function Medal.isCarrying()
	return carriesMedal()
end

function Medal.setESPEnabled(enabled)
	enabled = enabled == true
	if espEnabled == enabled then
		return
	end

	espEnabled = enabled
	clearESP()
	if not enabled then
		return
	end

	scanMedalsForESP()
	table.insert(
		espConnections,
		workspace.DescendantAdded:Connect(function(instance)
			if instance.Name == "Medal" then
				applyESP(instance)
			end
		end)
	)
	table.insert(
		espConnections,
		workspace.DescendantRemoving:Connect(function(instance)
			if instance.Name == "Medal" or CollectionService:HasTag(instance, "Medal") then
				removeESP(instance)
			end
		end)
	)
	table.insert(espConnections, CollectionService:GetInstanceAddedSignal("Medal"):Connect(applyESP))
	table.insert(espConnections, CollectionService:GetInstanceRemovedSignal("Medal"):Connect(removeESP))
end

function Medal.triggerManual()
	if manualActionBusy then
		return false, "Medal action is already running."
	end
	if os.clock() - lastActionAt < ACTION_COOLDOWN then
		return false, "Medal action is cooling down."
	end

	local character = getCharacter()
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return false, "Character is not ready."
	end

	if carriesMedal() then
		local beacon = Context.getBeaconPart()
		if not beacon then
			return false, "Beacon was not found."
		end

		local distance = (beacon.Position - hrp.Position).Magnitude
		if distance > 30 then
			return false, string.format("Move closer to the Beacon (%.1f/30 studs).", distance)
		end

		lastActionAt = os.clock()
		if Beacon and typeof(Beacon.restore) == "function" then
			Beacon.restore()
		end
		touch(beacon, hrp)
		return true, "Medal submitted."
	end

	local medalPart = getMedalPart()
	if not medalPart then
		return false, "Medal was not found."
	end

	manualActionBusy = true
	lastActionAt = os.clock()
	local oldCFrame = hrp.CFrame
	local oldAnchored = hrp.Anchored
	local oldLinearVelocity = hrp.AssemblyLinearVelocity
	local oldAngularVelocity = hrp.AssemblyAngularVelocity

	local ok, err = xpcall(function()
		hrp.Anchored = true
		hrp.CFrame = medalPart.CFrame + Vector3.new(0, 1.5, 0)
		touch(medalPart, hrp)
		task.wait(TOUCH_SETTLE)
	end, debug.traceback)

	if hrp.Parent then
		pcall(function()
			hrp.CFrame = oldCFrame
			hrp.AssemblyLinearVelocity = oldLinearVelocity
			hrp.AssemblyAngularVelocity = oldAngularVelocity
			hrp.Anchored = oldAnchored
		end)
	end
	manualActionBusy = false

	if not ok then
		return false, tostring(err)
	end
	return true, "Medal pickup triggered."
end

function Medal.reset()
	lastActionAt = 0
	manualActionBusy = false
end

function Medal.cleanup()
	espEnabled = false
	clearESP()
	MedalRegistry.stop()
	Medal.reset()
end

return Medal
