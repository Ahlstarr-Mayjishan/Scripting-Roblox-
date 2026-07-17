--!nocheck
-- [[
--  NULLSCAPE - Gift Farm No-Tracking Rule
--  Forces a void reset before farming can continue at level 9 or above.
-- ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Context = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/Context.luau")
local MovementLease = getgenv().loadModule("NULLSCAPE/Automation/Gift Farm/MovementLease.luau")

local NoTracking = {}
local localPlayer = Players.LocalPlayer
local LEVEL_LIMIT = 9
local DROP_INTERVAL = 0.5

local state = {
	Triggered = false,
	DeathConfirmed = false,
	Respawned = false,
	LastDropAt = 0,
}

local function getLevel()
	local levelValue = ReplicatedStorage:FindFirstChild("Level")
	return math.max(0, math.floor(tonumber(levelValue and levelValue.Value) or 0))
end

local function getCharacterParts()
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function isDead()
	local deadValue = localPlayer and localPlayer:FindFirstChild("Dead")
	if deadValue and deadValue.Value == true then
		return true
	end
	local _, humanoid = getCharacterParts()
	return humanoid ~= nil and humanoid.Health <= 0
end

local function isRespawnReady()
	local _, humanoid, root = getCharacterParts()
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

local function performRuntimeGC()
	Context.releaseCharacterControl({
		SkipVelocityClear = true,
		SkipStateChange = true,
		ForceAbilityClear = true,
	})
	if typeof(collectgarbage) == "function" then
		pcall(collectgarbage, "collect")
	end
end

local function dropCharacterIntoVoid()
	if Context.isInRound() ~= true then
		return false
	end
	if MovementLease and typeof(MovementLease.invalidateActive) == "function" then
		MovementLease.invalidateActive()
	end
	if MovementLease and typeof(MovementLease.resetTransport) == "function" then
		MovementLease.resetTransport()
	end
	Context.releaseCharacterControl({
		SkipVelocityClear = true,
		SkipStateChange = true,
		ForceAbilityClear = true,
	})

	local _, _, root = getCharacterParts()
	if not root then
		return false
	end
	local voidY = (tonumber(Workspace.FallenPartsDestroyHeight) or -500) - 100
	return pcall(function()
		root.Anchored = false
		root.CFrame = CFrame.new(root.Position.X, voidY, root.Position.Z)
		root.AssemblyLinearVelocity = Vector3.new(0, -200, 0)
		root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)
end

function NoTracking.reset()
	state.Triggered = false
	state.DeathConfirmed = false
	state.Respawned = false
	state.LastDropAt = 0
end

function NoTracking.step(controller)
	if not controller or controller.GiftFarmNoTrackingEnabled ~= true then
		NoTracking.reset()
		return nil
	end

	local level = getLevel()
	if not state.Triggered then
		if level < LEVEL_LIMIT or Context.isInRound() ~= true then
			return nil
		end
		state.Triggered = true
	end

	if state.DeathConfirmed and not state.Respawned and isRespawnReady() then
		state.Respawned = true
		performRuntimeGC()
	elseif isDead() then
		state.DeathConfirmed = true
	end

	if state.Respawned then
		if level < LEVEL_LIMIT then
			NoTracking.reset()
			return { ResetComplete = true }
		end
		return {
			Hold = true,
			Status = "NoTrackingReset",
			Detail = "Respawned; waiting for level to reset below 9",
			OverlayText = "No-Tracking reset complete\nWaiting for level below 9",
		}
	end

	local now = os.clock()
	if Context.isInRound() == true and not state.DeathConfirmed and now - state.LastDropAt >= DROP_INTERVAL then
		state.LastDropAt = now
		dropCharacterIntoVoid()
	end

	return {
		Hold = true,
		Status = "NoTrackingReset",
		Detail = if state.DeathConfirmed
			then "Void death confirmed; waiting for respawn"
			else "Level 9 reached; forcing a void reset",
		OverlayText = "No-Tracking me\nResetting before level 9 farm",
	}
end

function NoTracking.getState()
	return state
end

return NoTracking
