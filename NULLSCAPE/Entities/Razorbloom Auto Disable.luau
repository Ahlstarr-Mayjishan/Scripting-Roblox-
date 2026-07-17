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
local START_PHASE_GRACE = 1
local MAX_DISABLE_ATTEMPTS = 4

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

local function canDisable(razorbloom, clientBindable, generation)
	return isRequested()
		and generation == Logic.Generation
		and razorbloom.Parent ~= nil
		and clientBindable.Parent ~= nil
end

local function disableDangerPhase(target, razorbloom, clientBindable, generation)
	if target.DisableActive or target.DisableComplete then
		return
	end
	target.DisableActive = true

	task.spawn(function()
		-- Native starts the danger animation/sound immediately before setting its
		-- active flag. Crossing one frame prevents Disable from being overwritten.
		RunService.Heartbeat:Wait()
		for _ = 1, MAX_DISABLE_ATTEMPTS do
			if not canDisable(razorbloom, clientBindable, generation) then
				break
			end

			pcall(clientBindable.Fire, clientBindable, "Disable")
			RunService.Heartbeat:Wait()
			if not isDangerPhaseActive(razorbloom) then
				target.DisableComplete = true
				break
			end
		end
		target.DisableActive = nil
	end)
end

local function scheduleStartFallback(target, razorbloom, clientBindable, generation, startDelay)
	target.StartToken = (target.StartToken or 0) + 1
	local startToken = target.StartToken
	target.DisableComplete = nil

	task.spawn(function()
		task.wait(math.max(0, tonumber(startDelay) or 5))
		local deadline = time() + START_PHASE_GRACE
		while target.StartToken == startToken and not target.DisableComplete do
			if not canDisable(razorbloom, clientBindable, generation) then
				return
			end
			if isDangerPhaseActive(razorbloom) then
				disableDangerPhase(target, razorbloom, clientBindable, generation)
				return
			end
			if time() >= deadline then
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
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
				scheduleStartFallback(target, razorbloom, clientBindable, generation, startDelay)
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
				disableDangerPhase(target, razorbloom, clientBindable, generation)
			end)
		end
		if screamHard and screamHard:IsA("Sound") then
			target.ScreamHardPlayed = screamHard.Played:Connect(function()
				disableDangerPhase(target, razorbloom, clientBindable, generation)
			end)
		end

		local animationController = razorbloom:FindFirstChild("AnimationController")
		local animator = animationController and animationController:FindFirstChildOfClass("Animator")
		if animator then
			target.AnimationPlayed = animator.AnimationPlayed:Connect(function(track)
				if isDangerTrack(track) then
					disableDangerPhase(target, razorbloom, clientBindable, generation)
				end
			end)
		end

		-- Covers enabling the option after the native Start event already fired.
		if isDangerPhaseActive(razorbloom) then
			disableDangerPhase(target, razorbloom, clientBindable, generation)
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
