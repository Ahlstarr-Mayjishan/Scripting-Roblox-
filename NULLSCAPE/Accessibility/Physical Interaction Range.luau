--!nocheck
--[[
	NULLSCAPE - Physical Interaction Range
	Extends local character contact with selected native movement anchors without
	resizing map parts or changing Grapple raycasts and attachment positions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
	Active = false,
	Controller = nil,
	Movement = nil,
	HookedCore = nil,
	OriginalStep = nil,
	WrappedStep = nil,
	Sensors = {},
	SensorConnections = {},
}

local RANGE_FIELDS = {
	GrapplePoint = "PhysicalInteractionRangeGrapplePoint",
	TriaOrb = "PhysicalInteractionRangeTriaOrb",
	JumpPad = "PhysicalInteractionRangeJumpPad",
}

local MAX_RANGE = 10

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getRange(anchorName)
	local field = RANGE_FIELDS[anchorName]
	local value = field and Logic.Controller and tonumber(Logic.Controller[field]) or 0
	return math.clamp(value or 0, 0, MAX_RANGE)
end

local function hasEnabledRange()
	for anchorName in pairs(RANGE_FIELDS) do
		if getRange(anchorName) > 0 then
			return true
		end
	end
	return false
end

local function isMovementValid(movement)
	return typeof(movement) == "table"
		and movement.IsLocalPlayer == true
		and movement.Character ~= nil
		and movement.RootPart ~= nil
		and typeof(movement.OnHitboxTouch) == "function"
end

local function getMovementCore()
	local movementFolder = ReplicatedStorage:FindFirstChild("Movement")
	local movementCoreScript = movementFolder and movementFolder:FindFirstChild("MovementCore")
	if not movementCoreScript then
		return nil
	end

	local success, movementCore = pcall(require, movementCoreScript)
	return success and typeof(movementCore) == "table" and movementCore or nil
end

local function destroySensor(anchorName)
	local connection = Logic.SensorConnections[anchorName]
	if connection then
		connection:Disconnect()
		Logic.SensorConnections[anchorName] = nil
	end

	local sensor = Logic.Sensors[anchorName]
	if sensor then
		sensor:Destroy()
		Logic.Sensors[anchorName] = nil
	end
end

local function destroySensors()
	for anchorName in pairs(RANGE_FIELDS) do
		destroySensor(anchorName)
	end
end

local function giftFarmOwnsMovement()
	local globals = getGlobals()
	local automation = globals.activeAutomationController
	return globals.GiftFarmMovementLeaseActive == true or (automation and automation.GiftFarmEnabled == true)
end

local function dispatchNativeTouch(anchorName, touchedPart)
	if not Logic.Active or getRange(anchorName) <= 0 or giftFarmOwnsMovement() then
		return
	end
	if not (touchedPart and touchedPart:IsA("BasePart") and touchedPart.Name == anchorName) then
		return
	end
	if touchedPart.CanTouch == false or not isMovementValid(Logic.Movement) then
		return
	end

	Logic.Movement:OnHitboxTouch(touchedPart)
end

local function createSensor(anchorName, movement)
	local range = getRange(anchorName)
	if range <= 0 then
		destroySensor(anchorName)
		return
	end

	local sensor = Logic.Sensors[anchorName]
	if not (sensor and sensor.Parent == movement.Character) then
		destroySensor(anchorName)

		sensor = Instance.new("Part")
		sensor.Name = "NULLSCAPE_" .. anchorName .. "InteractionSensor"
		local nativeHitbox = movement.Hitbox
		sensor.Shape = nativeHitbox and nativeHitbox.Shape or Enum.PartType.Cylinder
		sensor.Anchored = false
		sensor.CanCollide = false
		sensor.CanQuery = false
		sensor.CanTouch = true
		sensor.CastShadow = false
		sensor.Massless = true
		sensor.Transparency = 1
		sensor.CFrame = nativeHitbox and nativeHitbox.CFrame or movement.RootPart.CFrame
		if nativeHitbox then
			sensor.CollisionGroup = nativeHitbox.CollisionGroup
		end
		sensor.Parent = movement.Character

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = movement.RootPart
		weld.Part1 = sensor
		weld.Parent = sensor

		Logic.Sensors[anchorName] = sensor
		Logic.SensorConnections[anchorName] = sensor.Touched:Connect(function(touchedPart)
			dispatchNativeTouch(anchorName, touchedPart)
		end)
	end

	local nativeSize = movement.Hitbox and movement.Hitbox.Size or Vector3.new(3, 2, 2)
	sensor.Size = nativeSize + Vector3.new(range * 2, range * 2, range * 2)
end

local function refreshSensors()
	local movement = Logic.Movement
	if not (Logic.Active and isMovementValid(movement) and movement.Character.Parent) then
		destroySensors()
		return false
	end

	for anchorName in pairs(RANGE_FIELDS) do
		createSensor(anchorName, movement)
	end
	return true
end

local function registerRearmCallback()
	local globals = getGlobals()
	globals.NullscapePhysicalInteractionRearmOwner = Logic
	globals.NullscapeRearmPhysicalInteractions = Logic.rearm
end

local function unregisterRearmCallback()
	local globals = getGlobals()
	if globals.NullscapePhysicalInteractionRearmOwner == Logic then
		globals.NullscapePhysicalInteractionRearmOwner = nil
		globals.NullscapeRearmPhysicalInteractions = nil
	end
end

local function restoreCaptureHook()
	local movementCore = Logic.HookedCore
	if movementCore and Logic.WrappedStep and movementCore.Step == Logic.WrappedStep and Logic.OriginalStep then
		movementCore.Step = Logic.OriginalStep
	end
	if movementCore and movementCore.__NULLSCAPE_physical_interaction_owner == Logic then
		movementCore.__NULLSCAPE_physical_interaction_owner = nil
		movementCore.__NULLSCAPE_physical_interaction_original = nil
		movementCore.__NULLSCAPE_physical_interaction_wrapper = nil
	end

	Logic.HookedCore = nil
	Logic.OriginalStep = nil
	Logic.WrappedStep = nil
end

local function captureMovement(movement)
	if not (Logic.Active and isMovementValid(movement)) then
		return
	end

	Logic.Movement = movement
	getGlobals().NullscapePhysicalInteractionMovement = movement
	restoreCaptureHook()
	task.defer(refreshSensors)
end

local function installCaptureHook()
	local movementCore = getMovementCore()
	if not (movementCore and typeof(movementCore.Step) == "function") then
		return false
	end

	local existingWrapper = movementCore.__NULLSCAPE_physical_interaction_wrapper
	if existingWrapper and movementCore.Step == existingWrapper then
		movementCore.__NULLSCAPE_physical_interaction_owner = Logic
		Logic.HookedCore = movementCore
		Logic.OriginalStep = movementCore.__NULLSCAPE_physical_interaction_original
		Logic.WrappedStep = existingWrapper
		return true
	end

	local originalStep = movementCore.Step
	local wrappedStep
	wrappedStep = function(self, dt, ...)
		local owner = movementCore.__NULLSCAPE_physical_interaction_owner
		if owner and owner.Active and self and self.IsLocalPlayer then
			captureMovement(self)
		end
		return originalStep(self, dt, ...)
	end

	movementCore.__NULLSCAPE_physical_interaction_owner = Logic
	movementCore.__NULLSCAPE_physical_interaction_original = originalStep
	movementCore.__NULLSCAPE_physical_interaction_wrapper = wrappedStep
	movementCore.Step = wrappedStep

	Logic.HookedCore = movementCore
	Logic.OriginalStep = originalStep
	Logic.WrappedStep = wrappedStep
	return true
end

local function acquireMovement()
	local globals = getGlobals()
	local movement = globals.NullscapePhysicalInteractionMovement
		or globals.NullscapeStaminaMovement
		or globals.NullscapeRailLocalMovement
	if isMovementValid(movement) and movement.Character.Parent then
		captureMovement(movement)
		return true
	end

	return installCaptureHook()
end

function Logic.initialize(controller)
	Logic.Controller = controller or Logic.Controller
	Logic.Active = hasEnabledRange()
	if not Logic.Active then
		Logic.disable()
		return true
	end
	registerRearmCallback()

	if refreshSensors() then
		return true
	end
	return acquireMovement()
end

function Logic.rearm()
	if not Logic.Active or giftFarmOwnsMovement() then
		return false
	end

	destroySensors()
	return refreshSensors()
end

function Logic.resetRespawnState(controller)
	Logic.Controller = controller or Logic.Controller
	destroySensors()
	Logic.Movement = nil
	getGlobals().NullscapePhysicalInteractionMovement = nil
	Logic.Active = hasEnabledRange()
	return true
end

function Logic.disable()
	Logic.Active = false
	unregisterRearmCallback()
	restoreCaptureHook()
	destroySensors()
	Logic.Movement = nil
	Logic.Controller = nil
	getGlobals().NullscapePhysicalInteractionMovement = nil
end

return Logic
