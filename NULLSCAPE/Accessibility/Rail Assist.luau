--!nocheck
-- [[
--  NULLSCAPE - Rail Assist
--  Adds auto-rail capture and entry-speed scaling while restoring MovementCore cleanly when disabled.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local MomentumMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Movement Context/Momentum Memory.luau")
local RailMemory = getgenv().loadModule("NULLSCAPE/Accessibility/Grappler assistments/Map Context/Rail Memory.luau")

local Logic = {
	Connections = {},
	Telefraggers = {},
	LastAutoRailAt = 0,
	LastScanAt = 0,
	LastTelefraggerScanAt = 0,
}

local function packValues(...)
	local values = { ... }
	values.n = select("#", ...)
	return values
end

local RAIL_SCAN_INTERVAL = 0.08
local RAIL_NEAR_CAPTURE_DISTANCE = 2.75
local TELEFRAGGER_SCAN_INTERVAL = 0.18
local TELEFRAGGER_BLOCK_DISTANCE = 58
local TELEFRAGGER_BLOCK_LATERAL_DISTANCE = 13
local TELEFRAGGER_INDICATOR_DISTANCE = 75

local function getGlobals()
	local env = getgenv()
	env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
	return env._NULLSCAPE_Globals
end

local function getController()
	return getGlobals().activeAccessibilityController
end

local function isSuiteEnabled()
	local controller = getController()
	return controller and controller.RailAssistSuiteEnabled == true
end

local function isAutoRailEnabled()
	local controller = getController()
	return controller and controller.RailAssistSuiteEnabled == true and controller.RailAutoEnabled == true
end

local function getSpeedMultiplier()
	local controller = getController()
	if not (controller and controller.RailAssistSuiteEnabled == true) then
		return 1
	end

	return math.clamp(tonumber(controller.RailSpeedMultiplier) or 1.1, 1.1, 5)
end

local function getAutoRailDelay()
	local controller = getController()
	return math.clamp(tonumber(controller and controller.RailAutoDelay) or 1.5, 0.15, 3)
end

local function getAutoRailCaptureRange()
	local controller = getController()
	return math.clamp(tonumber(controller and controller.RailAutoCaptureRange) or 4, 1, 64)
end

local function getMovementCore()
	local movement = ReplicatedStorage:FindFirstChild("Movement")
	local movementCoreScript = movement and movement:FindFirstChild("MovementCore")
	if not movementCoreScript or not movementCoreScript:IsA("ModuleScript") then
		return nil
	end

	local success, movementCore = pcall(require, movementCoreScript)
	if not success or typeof(movementCore) ~= "table" then
		return nil
	end

	return movementCore
end

local function clearConnections()
	for _, connection in ipairs(Logic.Connections) do
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	table.clear(Logic.Connections)
end

local function getLocalMovement()
	return getGlobals().NullscapeRailLocalMovement
end

local function rememberRailExit(movement, railPart)
	local rootPart = movement and movement.RootPart
	if not rootPart then
		return
	end

	getGlobals().NullscapeRailLastExit = {
		At = time(),
		Movement = movement,
		RailPart = railPart,
		Position = rootPart.Position,
		Velocity = rootPart.Velocity,
		WasJump = movement.railJumped == true,
	}
end

local function clampPointToPart(part, worldPosition)
	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = part.Size * 0.5

	local clampedLocal = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)

	return part.CFrame:PointToWorldSpace(clampedLocal)
end

local function flatten(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getApproachSpeed(rootPart, worldPosition)
	local toPoint = worldPosition - rootPart.Position
	if toPoint.Magnitude <= 0.05 then
		return 0
	end

	local velocity = rootPart.AssemblyLinearVelocity or rootPart.Velocity
	return velocity:Dot(toPoint.Unit)
end

local function getSafeUnit(vector, fallback)
	if vector.Magnitude > 0.05 then
		return vector.Unit
	end

	return fallback
end

local function getRailTravelDirection(rootPart, railPart)
	local railDirection = getSafeUnit(flatten(railPart.CFrame.LookVector), nil)
	if not railDirection then
		railDirection = getSafeUnit(flatten(rootPart.CFrame.LookVector), Vector3.new(0, 0, -1))
	end

	local velocity = flatten(rootPart.AssemblyLinearVelocity or rootPart.Velocity)
	local lookDirection = getSafeUnit(flatten(rootPart.CFrame.LookVector), railDirection)
	local referenceDirection = velocity.Magnitude > 2 and velocity.Unit or lookDirection
	if railDirection:Dot(referenceDirection) < 0 then
		railDirection = -railDirection
	end

	return railDirection
end

local function getTelefraggerPart(enemy)
	if not (enemy and enemy.Parent) then
		return nil
	end

	local preferredNames =
		{ "Mirror", "Surface", "HighlightGlass", "IndicatorPart", "HumanoidRootPart", "RootPart", "head", "Head" }
	for _, name in ipairs(preferredNames) do
		local part = enemy:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	if enemy:IsA("BasePart") then
		return enemy
	end

	if enemy:IsA("Model") and enemy.PrimaryPart then
		return enemy.PrimaryPart
	end

	return enemy:FindFirstChildWhichIsA("BasePart", true)
end

local function hasActiveTelefraggerIndicator(enemy)
	if not (enemy and enemy.Parent) then
		return false
	end

	for _, name in ipairs({ "Mirror", "Surface", "HighlightGlass" }) do
		local part = enemy:FindFirstChild(name, true)
		if part and part:IsA("BasePart") and part.Transparency < 0.95 then
			return true
		end
	end

	local indicatorPart = enemy:FindFirstChild("IndicatorPart", true)
	if indicatorPart then
		for _, descendant in ipairs(indicatorPart:GetDescendants()) do
			if descendant:IsA("Beam") and descendant.Enabled ~= false then
				return true
			end

			if descendant:IsA("ParticleEmitter") and descendant.Enabled ~= false then
				return true
			end
		end
	end

	return false
end

local function refreshTelefraggerCache()
	local now = time()
	if now - Logic.LastTelefraggerScanAt < TELEFRAGGER_SCAN_INTERVAL then
		return
	end

	Logic.LastTelefraggerScanAt = now
	table.clear(Logic.Telefraggers)

	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder then
		return
	end

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if string.find(string.lower(enemy.Name), "telefragger", 1, true) then
			table.insert(Logic.Telefraggers, enemy)
		end
	end
end

local function isTelefraggerThreatOnRail(rootPart, railPart)
	refreshTelefraggerCache()

	if #Logic.Telefraggers <= 0 then
		return false
	end

	local travelDirection = getRailTravelDirection(rootPart, railPart)
	local rootPosition = rootPart.Position

	for i = #Logic.Telefraggers, 1, -1 do
		local enemy = Logic.Telefraggers[i]
		local enemyPart = getTelefraggerPart(enemy)
		if not enemyPart then
			table.remove(Logic.Telefraggers, i)
			continue
		end

		local offset = flatten(enemyPart.Position - rootPosition)
		local distance = offset.Magnitude
		local aheadDistance = offset:Dot(travelDirection)
		local lateralDistance = (offset - travelDirection * aheadDistance).Magnitude
		local hasIndicator = hasActiveTelefraggerIndicator(enemy)

		if
			aheadDistance > -4
			and aheadDistance <= TELEFRAGGER_BLOCK_DISTANCE
			and lateralDistance <= TELEFRAGGER_BLOCK_LATERAL_DISTANCE
		then
			return true
		end

		if hasIndicator and distance <= TELEFRAGGER_INDICATOR_DISTANCE then
			return true
		end
	end

	return false
end

local function getRailCaptureCooldown()
	return getAutoRailDelay()
end

local function isPointInFrontHemisphere(rootPart, worldPosition)
	local toPoint = flatten(worldPosition - rootPart.Position)
	if toPoint.Magnitude <= 0.05 then
		return true
	end

	local horizontalVelocity = flatten(rootPart.AssemblyLinearVelocity or rootPart.Velocity)
	local referenceDirection = horizontalVelocity.Magnitude > 2 and horizontalVelocity
		or flatten(rootPart.CFrame.LookVector)
	if referenceDirection.Magnitude <= 0.05 then
		return true
	end

	return referenceDirection.Unit:Dot(toPoint.Unit) >= 0
end

local function findBestRailPart(rootPart)
	local bestPart = nil
	local bestDistance = math.huge
	local bestApproachSpeed = 0
	local bestScore = math.huge
	local captureRange = getAutoRailCaptureRange()

	local railEntries = RailMemory.getNearbyRails(rootPart.Position, captureRange)
	for _, entry in ipairs(railEntries) do
		local part = entry.Part
		if part and part.Parent then
			local nearestPoint = clampPointToPart(part, rootPart.Position)
			local distance = (nearestPoint - rootPart.Position).Magnitude
			local approachSpeed = getApproachSpeed(rootPart, nearestPoint)
			local isCaptureReady = distance <= RAIL_NEAR_CAPTURE_DISTANCE or approachSpeed > 4
			local score = distance - math.max(approachSpeed, 0) * 0.035

			if
				distance <= captureRange
				and isCaptureReady
				and score < bestScore
				and isPointInFrontHemisphere(rootPart, nearestPoint)
			then
				bestDistance = distance
				bestApproachSpeed = approachSpeed
				bestScore = score
				bestPart = part
			end
		end
	end

	return bestPart, bestDistance, bestApproachSpeed
end

local function canAutoRail(movement)
	if not isAutoRailEnabled() then
		return false
	end

	if not movement or movement.IsLocalPlayer ~= true then
		return false
	end

	local rootPart = movement.RootPart
	local humanoid = movement.Humanoid
	if not (rootPart and humanoid and rootPart.Parent and humanoid.Parent) then
		return false
	end

	if movement.rail or movement.railDebounce or movement.Anchored or movement.triaHold then
		return false
	end

	if
		movement.diving
		or movement.grappling
		or movement.charging
		or movement.chargeSlowing
		or movement.gliding
		or movement.spirit
	then
		return false
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return false
	end

	return true
end

local function autoRailStep()
	local movement = getLocalMovement()
	if not canAutoRail(movement) or time() - Logic.LastScanAt < RAIL_SCAN_INTERVAL then
		return
	end

	Logic.LastScanAt = time()

	local railPart = findBestRailPart(movement.RootPart)
	if railPart and typeof(movement.FollowRail) == "function" then
		local cooldown = getRailCaptureCooldown()
		if time() - Logic.LastAutoRailAt < cooldown then
			return
		end

		if isTelefraggerThreatOnRail(movement.RootPart, railPart) then
			Logic.LastAutoRailAt = time() - math.max(cooldown - 0.2, 0)
			return
		end

		Logic.LastAutoRailAt = time()
		movement:FollowRail(railPart)
	end
end

local function applyEntrySpeedBoost(movement, railPart)
	local multiplier = getSpeedMultiplier()
	if multiplier <= 1 or not (movement and movement.RootPart) then
		return
	end

	local rootPart = movement.RootPart
	local horizontalVelocity = rootPart.Velocity * Vector3.new(1, 0, 1)
	local direction = railPart and railPart.CFrame.LookVector or rootPart.CFrame.LookVector
	local boostedHorizontal

	if horizontalVelocity.Magnitude > 0.05 then
		boostedHorizontal = horizontalVelocity * multiplier
	else
		boostedHorizontal = direction * (16 * multiplier)
	end

	local beforeVelocity = rootPart.Velocity
	local nextVelocity = Vector3.new(boostedHorizontal.X, beforeVelocity.Y, boostedHorizontal.Z)
	rootPart.Velocity = nextVelocity
	MomentumMemory.noteImpulse(
		rootPart,
		"RailEntrySpeedBoost",
		beforeVelocity,
		nextVelocity,
		nextVelocity - beforeVelocity,
		{
			Multiplier = multiplier,
		}
	)
end

function Logic.enable()
	local globals = getGlobals()
	if globals.RailAssistHooked then
		return true
	end

	local movementCore = getMovementCore()
	if not movementCore then
		return false
	end

	if typeof(movementCore.FollowRail) == "function" then
		local originalFollowRail = movementCore.FollowRail
		globals.RailAssistOriginalFollowRail = originalFollowRail

		movementCore.FollowRail = function(self, railPart, ...)
			if self and self.IsLocalPlayer then
				globals.NullscapeRailLocalMovement = self
				globals.NullscapeRailCurrentPart = railPart
				if isSuiteEnabled() then
					applyEntrySpeedBoost(self, railPart)
				end
			end

			return originalFollowRail(self, railPart, ...)
		end
	end

	if typeof(movementCore.Step) == "function" then
		local originalStep = movementCore.Step
		globals.RailAssistOriginalStep = originalStep

		movementCore.Step = function(self, dt, ...)
			if self and self.IsLocalPlayer then
				globals.NullscapeRailLocalMovement = self
				local wasRail = self.rail == true
				local railPart = globals.NullscapeRailCurrentPart
				local results = packValues(originalStep(self, dt, ...))
				if wasRail and self.rail ~= true then
					rememberRailExit(self, railPart)
					globals.NullscapeRailCurrentPart = nil
				end
				return table.unpack(results, 1, results.n)
			end
			return originalStep(self, dt, ...)
		end
	end

	table.insert(Logic.Connections, RunService.Heartbeat:Connect(autoRailStep))

	globals.RailAssistHooked = true
	return true
end

function Logic.disable()
	local globals = getGlobals()
	local movementCore = getMovementCore()

	if movementCore and globals.RailAssistOriginalFollowRail then
		movementCore.FollowRail = globals.RailAssistOriginalFollowRail
	end

	if movementCore and globals.RailAssistOriginalStep then
		movementCore.Step = globals.RailAssistOriginalStep
	end

	globals.RailAssistOriginalFollowRail = nil
	globals.RailAssistOriginalStep = nil
	globals.RailAssistHooked = false
	globals.NullscapeRailLocalMovement = nil
	globals.NullscapeRailCurrentPart = nil
	globals.NullscapeRailLastExit = nil

	Logic.LastAutoRailAt = 0
	Logic.LastScanAt = 0
	Logic.LastTelefraggerScanAt = 0
	clearConnections()
	table.clear(Logic.Telefraggers)
end

return Logic
