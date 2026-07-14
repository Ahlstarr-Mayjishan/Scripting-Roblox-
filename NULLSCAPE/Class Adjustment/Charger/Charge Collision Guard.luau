--!strict
-- [[
--  NULLSCAPE - Charger Charge Collision Guard
--  Temporarily suppresses collision probes against other characters and small movable parts.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ChargeCollisionGuard = {}

local LocalPlayer = Players.LocalPlayer
local ClassContext = getgenv().loadModule("NULLSCAPE/Core/Class Context.luau")

local SCAN_SIZE = Vector3.new(12, 10, 18)
local SCAN_FORWARD_OFFSET = 5
local MAX_SMALL_PART_DIMENSION = 8
local CHARGE_END_GRACE = 0.15
local MIN_ABILITY_CHARGE_SPEED = 20

type CollisionState = {
	CanCollide: boolean,
	CanTouch: boolean,
	CanQuery: boolean,
}

type Controller = {
	ChargerCollisionGuardEnabled: boolean,
}

local activeController: Controller? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local lastChargingAt = 0
local originalStates: { [BasePart]: CollisionState } = {}

local function isCharging(character: Model, humanoid: Humanoid, root: BasePart): boolean
	if character:GetAttribute("ChargingCheck") == true then
		return true
	end
	if humanoid:GetAttribute("UsingAbility") ~= true then
		return false
	end

	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= MIN_ABILITY_CHARGE_SPEED
end

local function isOtherCharacterPart(part: BasePart): boolean
	local character = part:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	return player ~= nil and player ~= LocalPlayer
end

local function isSmallMovablePart(part: BasePart): boolean
	if part.Anchored then
		return false
	end

	local size = part.Size
	return math.max(size.X, size.Y, size.Z) <= MAX_SMALL_PART_DIMENSION
end

local function shouldSuppress(part: BasePart, localCharacter: Model): boolean
	if part:IsDescendantOf(localCharacter) then
		return false
	end
	return isOtherCharacterPart(part) or isSmallMovablePart(part)
end

local function suppressPart(part: BasePart)
	if originalStates[part] == nil then
		originalStates[part] = {
			CanCollide = part.CanCollide,
			CanTouch = part.CanTouch,
			CanQuery = part.CanQuery,
		}
	end

	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

local function restoreParts()
	for part, state in pairs(originalStates) do
		if part.Parent then
			pcall(function()
				part.CanCollide = state.CanCollide
				part.CanTouch = state.CanTouch
				part.CanQuery = state.CanQuery
			end)
		end
		originalStates[part] = nil
	end
end

local function scanChargeCorridor(character: Model, root: BasePart)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = 100

	local scanCFrame = root.CFrame + root.CFrame.LookVector * SCAN_FORWARD_OFFSET
	for _, part in ipairs(workspace:GetPartBoundsInBox(scanCFrame, SCAN_SIZE, overlapParams)) do
		if part:IsA("BasePart") and shouldSuppress(part, character) then
			pcall(suppressPart, part)
		end
	end
end

local function updateGuard()
	local controller = activeController
	if not (controller and controller.ChargerCollisionGuardEnabled and ClassContext.is("Charger")) then
		restoreParts()
		return
	end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and root and root:IsA("BasePart") and isCharging(character, humanoid, root) then
		lastChargingAt = os.clock()
		scanChargeCorridor(character, root)
		return
	end

	if os.clock() - lastChargingAt >= CHARGE_END_GRACE then
		restoreParts()
	end
end

local function disconnect()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	restoreParts()
end

function ChargeCollisionGuard.update(controller: Controller?): boolean
	activeController = controller
	local enabled = controller and controller.ChargerCollisionGuardEnabled == true and ClassContext.is("Charger")
	if not enabled then
		disconnect()
		return false
	end

	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(updateGuard)
	end
	return true
end

function ChargeCollisionGuard.stop()
	activeController = nil
	disconnect()
end

return ChargeCollisionGuard
