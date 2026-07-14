--!nocheck
--[[
	NULLSCAPE - Razorbloom Auto Disable
	Waits for the native Start event before using the same Disable bindable as
	JumpPad/GrapplePoint interactions. Never mutates the replicated model.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ENDPOINT_WAIT_WINDOW = 2.5
local ENDPOINT_RETRY_STEP = 0.05

local Logic = {
	Enabled = false,
	Generation = 0,
	Connections = {},
	Targets = setmetatable({}, { __mode = "k" }),
}

local function getController()
	local globals = getgenv()._NULLSCAPE_Globals
	return globals and globals.activeEntitiesController
end

local function isRequested()
	local controller = getController()
	return Logic.Enabled
		and controller ~= nil
		and controller.inLobby ~= true
		and controller.RazorbloomAutoDisable == true
end

local function disconnect(connection)
	if connection then
		connection:Disconnect()
	end
end

local function disconnectNamed(name)
	disconnect(Logic.Connections[name])
	Logic.Connections[name] = nil
end

local function clearTarget(razorbloom)
	local target = Logic.Targets[razorbloom]
	if not target then
		return
	end

	disconnect(target.ClientEvent)
	disconnect(target.AncestryChanged)
	disconnect(target.ScreamPlayed)
	disconnect(target.ScreamHardPlayed)
	disconnect(target.AnimationPlayed)
	Logic.Targets[razorbloom] = nil
end

local function clearTargets()
	for razorbloom in pairs(Logic.Targets) do
		clearTarget(razorbloom)
	end
	Logic.Targets = setmetatable({}, { __mode = "k" })
end

local function findEndpoints(razorbloom)
	local clientEvent = razorbloom:FindFirstChild("ClientEvent", true)
	local clientBindable = razorbloom:FindFirstChild("ClientBindable", true)
	if not (clientEvent and clientEvent:IsA("RemoteEvent")) then
		clientEvent = nil
	end
	if not (clientBindable and clientBindable:IsA("BindableEvent")) then
		clientBindable = nil
	end
	return clientEvent, clientBindable
end

local function disableAfterStart(target, razorbloom, clientBindable, generation, startDelay)
	if target.DisableScheduled then
		return
	end
	target.DisableScheduled = true

	task.spawn(function()
		task.wait(math.max(0, tonumber(startDelay) or 5))
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		if isRequested() and generation == Logic.Generation and razorbloom.Parent and clientBindable.Parent then
			pcall(clientBindable.Fire, clientBindable, "Disable")
		end
	end)
end

local function isDangerTrack(track)
	local name = string.lower(track.Name)
	return name == "mad" or name == "spinloop"
end

local function isDangerPhaseActive(razorbloom)
	local rootPart = razorbloom:FindFirstChild("RootPart")
	if rootPart then
		local scream = rootPart:FindFirstChild("scream")
		local screamHard = rootPart:FindFirstChild("scream_hard")
		if
			(scream and scream:IsA("Sound") and scream.IsPlaying)
			or (screamHard and screamHard:IsA("Sound") and screamHard.IsPlaying)
		then
			return true
		end
	end

	local animationController = razorbloom:FindFirstChild("AnimationController")
	local animator = animationController and animationController:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end

	local success, tracks = pcall(animator.GetPlayingAnimationTracks, animator)
	if not success then
		return false
	end

	for _, track in ipairs(tracks) do
		if isDangerTrack(track) then
			return true
		end
	end
	return false
end

local function watchRazorbloom(razorbloom)
	if not isRequested() or not (razorbloom and razorbloom.Parent) or Logic.Targets[razorbloom] then
		return
	end

	local generation = Logic.Generation
	Logic.Targets[razorbloom] = { Pending = true }
	task.spawn(function()
		local deadline = time() + ENDPOINT_WAIT_WINDOW
		local clientEvent
		local clientBindable
		repeat
			if not isRequested() or generation ~= Logic.Generation or not razorbloom.Parent then
				clearTarget(razorbloom)
				return
			end

			clientEvent, clientBindable = findEndpoints(razorbloom)
			if not (clientEvent and clientBindable) then
				task.wait(ENDPOINT_RETRY_STEP)
			end
		until (clientEvent and clientBindable) or time() >= deadline

		if not (clientEvent and clientBindable) then
			clearTarget(razorbloom)
			return
		end

		local target = Logic.Targets[razorbloom]
		if not target or generation ~= Logic.Generation then
			return
		end

		target.Pending = nil
		target.ClientEvent = clientEvent.OnClientEvent:Connect(function(command, startDelay)
			if command == "Start" then
				disableAfterStart(target, razorbloom, clientBindable, generation, startDelay)
			end
		end)
		target.AncestryChanged = razorbloom.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				clearTarget(razorbloom)
			end
		end)

		local rootPart = razorbloom:FindFirstChild("RootPart")
		local scream = rootPart and rootPart:FindFirstChild("scream")
		local screamHard = rootPart and rootPart:FindFirstChild("scream_hard")
		if scream and scream:IsA("Sound") then
			target.ScreamPlayed = scream.Played:Connect(function()
				disableAfterStart(target, razorbloom, clientBindable, generation, 0)
			end)
		end
		if screamHard and screamHard:IsA("Sound") then
			target.ScreamHardPlayed = screamHard.Played:Connect(function()
				disableAfterStart(target, razorbloom, clientBindable, generation, 0)
			end)
		end

		local animationController = razorbloom:FindFirstChild("AnimationController")
		local animator = animationController and animationController:FindFirstChildOfClass("Animator")
		if animator then
			target.AnimationPlayed = animator.AnimationPlayed:Connect(function(track)
				if isDangerTrack(track) then
					disableAfterStart(target, razorbloom, clientBindable, generation, 0)
				end
			end)
		end

		-- Covers enabling the option after the native Start event already fired.
		if isDangerPhaseActive(razorbloom) then
			disableAfterStart(target, razorbloom, clientBindable, generation, 0)
		end
	end)
end

local function findRazorbloomAncestor(instance, character)
	local current = instance
	while current and current ~= character do
		if current.Name == "Razorbloom" then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function scanCharacter(character)
	if not character then
		return
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant.Name == "Razorbloom" then
			task.defer(watchRazorbloom, descendant)
		end
	end
end

local function watchCharacter(character)
	disconnectNamed("CharacterDescendantAdded")
	clearTargets()
	if not character then
		return
	end

	Logic.Connections.CharacterDescendantAdded = character.DescendantAdded:Connect(function(descendant)
		local razorbloom = descendant.Name == "Razorbloom" and descendant
			or findRazorbloomAncestor(descendant, character)
		if razorbloom then
			task.defer(watchRazorbloom, razorbloom)
		end
	end)
	task.defer(scanCharacter, character)
end

function Logic.setEnabled(enabled)
	enabled = enabled == true
	if enabled == Logic.Enabled then
		return true
	end

	Logic.Enabled = enabled
	Logic.Generation += 1
	if not enabled then
		disconnectNamed("CharacterAdded")
		disconnectNamed("CharacterDescendantAdded")
		clearTargets()
		return true
	end

	local player = Players.LocalPlayer
	if not player then
		Logic.Enabled = false
		return false
	end

	watchCharacter(player.Character)
	Logic.Connections.CharacterAdded = player.CharacterAdded:Connect(watchCharacter)
	return true
end

function Logic.disable()
	Logic.setEnabled(false)
	local globals = getgenv()._NULLSCAPE_Globals
	if globals and globals.RazorbloomAutoDisableOwner == Logic then
		globals.RazorbloomAutoDisableOwner = nil
		globals.RazorbloomAutoDisableRestore = nil
	end
end

do
	local environment = getgenv()
	environment._NULLSCAPE_Globals = environment._NULLSCAPE_Globals or {}
	local globals = environment._NULLSCAPE_Globals
	if typeof(globals.RazorbloomAutoDisableRestore) == "function" then
		pcall(globals.RazorbloomAutoDisableRestore)
	end
	globals.RazorbloomAutoDisableOwner = Logic
	globals.RazorbloomAutoDisableRestore = Logic.disable
end

return Logic
