--!nocheck
-- Executor-facing native interop: MovementCore and native movement tables have no stable Luau types.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")

local LocalPlayer = Players.LocalPlayer
local AnchorCastAssist = {
	Controller = nil,
	MovementCore = nil,
	OriginalOnHitboxTouch = nil,
	WrappedOnHitboxTouch = nil,
	Pending = {},
	Connection = nil,
}

local MAX_WAIT = 0.22
local MIN_LAUNCH_SPEED = 5

local function isEnabled()
	return AnchorCastAssist.Controller
		and AnchorCastAssist.Controller.ChargerAnchorCastAssistEnabled == true
		and ClassContext
		and ClassContext.is("Charger")
end

local function getDelay()
	local value = AnchorCastAssist.Controller and AnchorCastAssist.Controller.ChargerAnchorCastDelay or 0.04
	return math.clamp(tonumber(value) or 0.04, 0, 0.2)
end

local function isLocalMovement(movement)
	return typeof(movement) == "table"
		and movement.IsLocalPlayer == true
		and movement.Player == LocalPlayer
		and movement.Character == LocalPlayer.Character
		and typeof(movement.SpecialAction) == "function"
end

local function getMovementCore()
	local movementFolder = ReplicatedStorage:FindFirstChild("Movement")
	local moduleScript = movementFolder and movementFolder:FindFirstChild("MovementCore")
	if not moduleScript then
		return nil
	end
	local success, core = pcall(require, moduleScript)
	return success and typeof(core) == "table" and core or nil
end

local function isReadyForAnchorCast(pending)
	local movement = pending.Movement
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (isLocalMovement(movement) and root and humanoid) then
		return false
	end
	if character:GetAttribute("ChargingCheck") == true or humanoid:GetAttribute("UsingAbility") == true then
		return false
	end
	if pending.AnchorName == "JumpPad" then
		return movement.jumpPadDebounce == true and root.AssemblyLinearVelocity.Y >= MIN_LAUNCH_SPEED
	end
	return movement.grapplePoint ~= nil
end

local function pulseNativeCast(movement)
	local began = pcall(function()
		movement:SpecialAction(Enum.UserInputState.Begin)
	end)
	if began then
		task.defer(function()
			pcall(function()
				movement:SpecialAction(Enum.UserInputState.End)
			end)
		end)
	end
end

local function processPending()
	if not isEnabled() then
		table.clear(AnchorCastAssist.Pending)
		return
	end
	local now = time()
	for movement, pending in pairs(AnchorCastAssist.Pending) do
		if now - pending.TouchedAt > MAX_WAIT then
			AnchorCastAssist.Pending[movement] = nil
		elseif now - pending.TouchedAt >= getDelay() and isReadyForAnchorCast(pending) then
			AnchorCastAssist.Pending[movement] = nil
			pulseNativeCast(movement)
		end
	end
end

local function queueAnchorCast(movement, anchorName)
	if isEnabled() then
		AnchorCastAssist.Pending[movement] = {
			Movement = movement,
			AnchorName = anchorName,
			TouchedAt = time(),
		}
	end
end

local function restoreHook()
	local movementCore = AnchorCastAssist.MovementCore
	if movementCore and movementCore.OnHitboxTouch == AnchorCastAssist.WrappedOnHitboxTouch then
		movementCore.OnHitboxTouch = AnchorCastAssist.OriginalOnHitboxTouch
	end
	AnchorCastAssist.MovementCore = nil
	AnchorCastAssist.OriginalOnHitboxTouch = nil
	AnchorCastAssist.WrappedOnHitboxTouch = nil
end

local function installHook()
	local movementCore = getMovementCore()
	if not (movementCore and typeof(movementCore.OnHitboxTouch) == "function") then
		return false
	end
	if
		movementCore == AnchorCastAssist.MovementCore
		and movementCore.OnHitboxTouch == AnchorCastAssist.WrappedOnHitboxTouch
	then
		return true
	end

	restoreHook()
	local originalOnHitboxTouch = movementCore.OnHitboxTouch
	local wrappedOnHitboxTouch
	wrappedOnHitboxTouch = function(self, hitPart, ...)
		local results = table.pack(originalOnHitboxTouch(self, hitPart, ...))
		if
			isEnabled()
			and isLocalMovement(self)
			and hitPart
			and (hitPart.Name == "JumpPad" or hitPart.Name == "GrapplePoint")
		then
			queueAnchorCast(self, hitPart.Name)
		end
		return table.unpack(results, 1, results.n)
	end

	movementCore.OnHitboxTouch = wrappedOnHitboxTouch
	AnchorCastAssist.MovementCore = movementCore
	AnchorCastAssist.OriginalOnHitboxTouch = originalOnHitboxTouch
	AnchorCastAssist.WrappedOnHitboxTouch = wrappedOnHitboxTouch
	return true
end

local function ensureLoop()
	if not AnchorCastAssist.Connection then
		AnchorCastAssist.Connection = RunService.Heartbeat:Connect(processPending)
	end
end

function AnchorCastAssist.update(controller)
	AnchorCastAssist.Controller = controller
	if not isEnabled() then
		AnchorCastAssist.stop()
		return false
	end
	ensureLoop()
	return installHook()
end

function AnchorCastAssist.stop()
	if AnchorCastAssist.Connection then
		AnchorCastAssist.Connection:Disconnect()
		AnchorCastAssist.Connection = nil
	end
	restoreHook()
	table.clear(AnchorCastAssist.Pending)
	AnchorCastAssist.Controller = nil
end

return AnchorCastAssist
