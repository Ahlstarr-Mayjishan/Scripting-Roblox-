--!nocheck
-- [[
--  NULLSCAPE - Rail Assist
--  Adds auto-rail capture and entry-speed scaling while restoring MovementCore cleanly when disabled.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Logic = {
    Connections = {},
    RailParts = {},
    LastAutoRailAt = 0,
    LastScanAt = 0,
}

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
    return math.clamp(tonumber(controller and controller.RailAutoDelay) or 1.5, 1.5, 3)
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

local function isRailPart(part)
    return part and part:IsA("BasePart") and part.Name == "_RailPart"
end

local function registerRailPart(part)
    if not isRailPart(part) then
        return
    end

    Logic.RailParts[part] = true
end

local function unregisterRailPart(part)
    Logic.RailParts[part] = nil
end

local function rebuildRailCache()
    table.clear(Logic.RailParts)

    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if isRailPart(descendant) then
            Logic.RailParts[descendant] = true
        end
    end
end

local function watchRailParts()
    rebuildRailCache()

    table.insert(Logic.Connections, Workspace.DescendantAdded:Connect(registerRailPart))
    table.insert(Logic.Connections, Workspace.DescendantRemoving:Connect(unregisterRailPart))
end

local function getLocalMovement()
    return getGlobals().NullscapeRailLocalMovement
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

local function isPointInFrontHemisphere(rootPart, worldPosition)
    local toPoint = flatten(worldPosition - rootPart.Position)
    if toPoint.Magnitude <= 0.05 then
        return true
    end

    local horizontalVelocity = flatten(rootPart.AssemblyLinearVelocity or rootPart.Velocity)
    local referenceDirection = horizontalVelocity.Magnitude > 2 and horizontalVelocity or flatten(rootPart.CFrame.LookVector)
    if referenceDirection.Magnitude <= 0.05 then
        return true
    end

    return referenceDirection.Unit:Dot(toPoint.Unit) >= 0
end

local function findBestRailPart(rootPart)
    local bestPart = nil
    local bestDistance = math.huge
    local captureRange = getAutoRailCaptureRange()

    for part in pairs(Logic.RailParts) do
        if part and part.Parent then
            local nearestPoint = clampPointToPart(part, rootPart.Position)
            local distance = (nearestPoint - rootPart.Position).Magnitude
            if distance <= captureRange and distance < bestDistance and isPointInFrontHemisphere(rootPart, nearestPoint) then
                bestDistance = distance
                bestPart = part
            end
        else
            Logic.RailParts[part] = nil
        end
    end

    return bestPart
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

    if movement.diving or movement.grappling or movement.charging or movement.chargeSlowing or movement.gliding or movement.spirit then
        return false
    end

    if humanoid:GetState() == Enum.HumanoidStateType.Dead then
        return false
    end

    if time() - Logic.LastAutoRailAt < getAutoRailDelay() then
        return false
    end

    return true
end

local function autoRailStep()
    local movement = getLocalMovement()
    if not canAutoRail(movement) or time() - Logic.LastScanAt < 0.08 then
        return
    end

    Logic.LastScanAt = time()

    local railPart = findBestRailPart(movement.RootPart)
    if railPart and typeof(movement.FollowRail) == "function" then
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

    rootPart.Velocity = Vector3.new(boostedHorizontal.X, rootPart.Velocity.Y, boostedHorizontal.Z)
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
            end
            return originalStep(self, dt, ...)
        end
    end

    watchRailParts()
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

    Logic.LastAutoRailAt = 0
    Logic.LastScanAt = 0
    clearConnections()
    table.clear(Logic.RailParts)
end

return Logic
