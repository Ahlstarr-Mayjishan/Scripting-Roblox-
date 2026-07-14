--!nocheck
-- [[
--  NULLSCAPE - Charger Steering Assist
--  Blends an active Charger dash toward WASD input, or camera forward when idle.
-- ]]

local ChargerSteeringAssist = {}

local getgenv = getgenv
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")

local activeController = nil
local steeringConnection = nil

local function isCharging(character, humanoid)
	return character
		and humanoid
		and (character:GetAttribute("ChargingCheck") == true or humanoid:GetAttribute("UsingAbility") == true)
end

local function flatDirection(vector)
	local direction = Vector3.new(vector.X, 0, vector.Z)
	return direction.Magnitude > 0.001 and direction.Unit or nil
end

local function getDesiredDirection(humanoid)
	local movementDirection = flatDirection(humanoid.MoveDirection)
	if movementDirection then
		return movementDirection
	end

	local camera = workspace.CurrentCamera
	return camera and flatDirection(camera.CFrame.LookVector) or nil
end

local function applySteering()
	if not (activeController and activeController.ChargerSteeringAssistEnabled and ClassContext.is("Charger")) then
		return
	end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and isCharging(character, humanoid)) then
		return
	end

	local desiredDirection = getDesiredDirection(humanoid)
	local strength = math.clamp(tonumber(activeController.ChargerSteeringAssistStrength) or 50, 0, 100) / 100
	if not desiredDirection or strength <= 0 then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontalVelocity = flatDirection(velocity)
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local currentDirection = horizontalVelocity or flatDirection(root.CFrame.LookVector) or desiredDirection
	local blendedDirection = currentDirection:Lerp(desiredDirection, strength)
	if blendedDirection.Magnitude <= 0.001 then
		return
	end
	blendedDirection = blendedDirection.Unit

	if speed > 0.1 then
		root.AssemblyLinearVelocity = Vector3.new(blendedDirection.X * speed, velocity.Y, blendedDirection.Z * speed)
	end

	local targetCFrame = CFrame.lookAt(root.Position, root.Position + blendedDirection)
	root.CFrame = root.CFrame:Lerp(targetCFrame, strength)
end

local function stopSteering()
	if steeringConnection then
		steeringConnection:Disconnect()
		steeringConnection = nil
	end
end

function ChargerSteeringAssist.update(controller)
	activeController = controller
	local enabled = controller and controller.ChargerSteeringAssistEnabled == true and ClassContext.is("Charger")
	if not enabled then
		stopSteering()
		return false
	end

	if not steeringConnection then
		steeringConnection = RunService.RenderStepped:Connect(applySteering)
	end
	return true
end

function ChargerSteeringAssist.stop()
	activeController = nil
	stopSteering()
end

return ChargerSteeringAssist
