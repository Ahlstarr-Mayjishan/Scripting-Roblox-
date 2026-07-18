--!nocheck
--[[
	NULLSCAPE - Character Actions
	Provides a bounded void respawn and a reversible CoreGui reset callback.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Logic = {
	ResetUnlocked = false,
	ResetEvent = nil,
	ResetConnection = nil,
	CharacterAddedConnection = nil,
	ApplyToken = 0,
}

local RESET_APPLY_ATTEMPTS = 20
local RESET_APPLY_INTERVAL = 0.1
local RESET_GUARD_INTERVAL = 0.75
local VOID_OFFSET = 64

local function destroyResetBinding()
	if Logic.ResetConnection then
		Logic.ResetConnection:Disconnect()
		Logic.ResetConnection = nil
	end
	if Logic.ResetEvent then
		Logic.ResetEvent:Destroy()
		Logic.ResetEvent = nil
	end
	if Logic.CharacterAddedConnection then
		Logic.CharacterAddedConnection:Disconnect()
		Logic.CharacterAddedConnection = nil
	end
end

local function applyResetCallback(callback, token)
	for _ = 1, RESET_APPLY_ATTEMPTS do
		if token ~= Logic.ApplyToken then
			return false
		end
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", callback) then
			return true
		end
		task.wait(RESET_APPLY_INTERVAL)
	end
	return false
end

local function startResetGuard(resetEvent, token)
	if token ~= Logic.ApplyToken or not Logic.ResetUnlocked or Logic.ResetEvent ~= resetEvent then
		return
	end
	local player = Players.LocalPlayer
	if player then
		Logic.CharacterAddedConnection = player.CharacterAdded:Connect(function()
			task.defer(function()
				if token == Logic.ApplyToken and Logic.ResetUnlocked and Logic.ResetEvent == resetEvent then
					applyResetCallback(resetEvent, token)
				end
			end)
		end)
	end

	task.spawn(function()
		while token == Logic.ApplyToken and Logic.ResetUnlocked and Logic.ResetEvent == resetEvent do
			applyResetCallback(resetEvent, token)
			task.wait(RESET_GUARD_INTERVAL)
		end
	end)
end

function Logic.respawn()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return false, "Character is not ready."
	end

	local voidY = math.clamp(workspace.FallenPartsDestroyHeight - VOID_OFFSET, -49900, 49900)
	local ok, err = pcall(function()
		humanoid.Sit = false
		humanoid.PlatformStand = false
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.new(0, -256, 0)
		root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		character:PivotTo(CFrame.new(root.Position.X, voidY, root.Position.Z))
	end)
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Logic.setResetUnlocked(enabled)
	enabled = enabled == true
	Logic.ApplyToken += 1
	local token = Logic.ApplyToken
	destroyResetBinding()
	Logic.ResetUnlocked = enabled

	if not enabled then
		task.spawn(applyResetCallback, false, token)
		return true
	end

	local resetEvent = Instance.new("BindableEvent")
	Logic.ResetEvent = resetEvent
	Logic.ResetConnection = resetEvent.Event:Connect(function()
		Logic.respawn()
	end)

	task.spawn(function()
		if not applyResetCallback(resetEvent, token) and token == Logic.ApplyToken then
			Logic.ResetUnlocked = false
			destroyResetBinding()
			return
		end
		startResetGuard(resetEvent, token)
	end)
	return true
end

function Logic.CleanUp()
	Logic.ApplyToken += 1
	Logic.ResetUnlocked = false
	destroyResetBinding()
	pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false)
end

return Logic
