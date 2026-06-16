--!nocheck
-- [[
--  NULLSCAPE - Grapple Aim Assist
--  Temporarily replaces Grapple.Cast while enabled, then restores it fully when disabled.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Logic = {
    Connections = {},
    InputConnections = {},
    Candidates = {},
    CandidateCursor = 1,
    Random = Random.new(),
    BellBypass = nil,
    BellBypassToken = 0,
    CurrentGrappleStep = nil,
    LastGrappleMovement = nil,
    SuppressBonkUntil = 0,
    FallbackHitbox = nil,
    NoCollisionMoveCastParams = nil,
    JumpPadStates = {},
    LastJumpPadUsesBypassEnabled = false,
    AdaptInputHeld = false,
    AdaptInputBeganAt = 0,
    LastAdaptInputPressed = 0,
    AdaptDriveActive = false,
    AdaptRecastToken = 0,
    LastKnownGrapple = nil,
    AdaptRecastPending = false,
    AdaptRecastReleaseIssued = false,
    AdaptRecastRequestedAt = 0,
    AdaptRecastReleaseAt = 0,
    LastAdaptPulseAt = 0,
    AdaptAwaitingAttachUntil = 0,
    AdaptRetryAt = 0,
    AutoRescueUntil = 0,
    LastAutoRescuePulseAt = 0,
}

local VALID_TARGETS = {
    GrapplePoint = true,
    JumpPad = true,
    Bell = true,
    TriaOrb = true,
}

local TARGET_OPTIONS = {
    "GrapplePoint",
    "JumpPad",
    "Bell",
    "TriaOrb",
}

local RANGE_OPTIONS = {
    "Nearest",
    "Farthest",
    "Closest To Cursor",
    "Random",
}

local ADAPT_INPUT_PULSE_DURATION = 0.05
local ADAPT_TAP_THRESHOLD = 0.16
local ADAPT_RECAST_RELEASE_DELAY = 0.045
local ADAPT_RECAST_COOLDOWN = 0.12
local ADAPT_RECAST_MAX_WAIT = 0.35
local ADAPT_ATTACH_GRACE = 0.18
local ADAPT_RETRY_DELAY = 0.26
local ADAPT_RECAST_SAFE_SPEED = 92
local ADAPT_RECAST_CLAMP_SPEED = 78
local ADAPT_RECAST_ARRIVAL_DISTANCE = 7
local ADAPT_RECAST_TRIA_ARRIVAL_DISTANCE = 11
local AUTO_RESCUE_SPEED = 135
local AUTO_RESCUE_COOLDOWN = 0.45
local AUTO_RESCUE_WINDOW = 0.3

local DEFAULT_MAX_RANGE = 90
local MAX_CANDIDATES_PER_CAST = 48
local FALLBACK_HITBOX_SIZE = Vector3.new(3, 2, 2)
local MOMENTUM_GUARD_SPEED = 115
local MOMENTUM_GUARD_CLAMP = 88
local MOMENTUM_GUARD_WINDOW = 0.8

local SCREEN_RAY_OFFSETS = {
    Vector2.new(0, 0),
    Vector2.new(0.06, 0),
    Vector2.new(-0.06, 0),
    Vector2.new(0, 0.06),
    Vector2.new(0, -0.06),
    Vector2.new(0.1, 0.06),
    Vector2.new(-0.1, 0.06),
    Vector2.new(0.1, -0.06),
    Vector2.new(-0.1, -0.06),
}

local markGrappleBonkGrace
local getHorizontalVelocity
local isInAir
local hasAdaptDriveTarget

local function getGlobals()
    local env = getgenv()
    env._NULLSCAPE_Globals = env._NULLSCAPE_Globals or {}
    return env._NULLSCAPE_Globals
end

local function getController()
    return getGlobals().activeAccessibilityController
end

local function isEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleAimAssistEnabled == true
end

local function isSuiteEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true
end

local function isRescueEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleRescueAssistEnabled == true
end

local function isAntiBonkEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleAntiBonkEnabled == true
end

local function isSmartReelEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleSmartReelEnabled == true
end

local function isSharkTailHelperEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleSharkTailHelperEnabled == true
end

local function isMomentumGuardEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleMomentumGuardEnabled == true
end

local function isJumpPadUsesBypassEnabled()
    local controller = getController()
    return controller and controller.GrappleAssistSuiteEnabled == true and controller.GrappleJumpPadUsesBypassEnabled == true
end

local function getAdaptInputKeyCode()
    local controller = getController()
    local keyName = tostring(controller and controller.GrappleAdaptInputKey or "T")
    return Enum.KeyCode[keyName] or Enum.KeyCode.T
end

local function isTextBoxFocused()
    local success, focused = pcall(function()
        return UserInputService:GetFocusedTextBox()
    end)
    return success and focused ~= nil
end

local function getAirControlMultiplier()
    local controller = getController()
    if not (controller and controller.GrappleAssistSuiteEnabled == true) then
        return 1
    end

    return math.clamp(tonumber(controller.GrappleAirControlMultiplier) or 1, 1, 5)
end

local function getReelPullMultiplier()
    local controller = getController()
    if not (controller and controller.GrappleAssistSuiteEnabled == true) then
        return 1
    end

    return math.clamp(tonumber(controller.GrappleReelPullMultiplier) or 1, 1, 5)
end

local function getSharkTailPullMultiplier()
    local controller = getController()
    if not (controller and controller.GrappleAssistSuiteEnabled == true) then
        return 1
    end

    return math.clamp(tonumber(controller.GrappleSharkTailPullMultiplier) or 1, 1, 5)
end

local function isInfiniteStamina()
    local controller = getController()
    return controller and controller.GrapplerStaminaMode == "Infinite Stamina"
end

local function normalizeTargetPriority(value)
    value = tostring(value or "GrapplePoint")
    if VALID_TARGETS[value] then
        return value
    end
    return "GrapplePoint"
end

local function normalizeRangePriority(value)
    value = tostring(value or "Nearest")
    for _, option in ipairs(RANGE_OPTIONS) do
        if value == option then
            return value
        end
    end
    return "Nearest"
end

local function normalizeMode(value)
    value = tostring(value or "Manual")
    if value == "Automatic" then
        return "Automatic"
    end
    return "Manual"
end

local function getTargetPart(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") and instance.PrimaryPart then
        return instance.PrimaryPart
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getCandidateName(instance, part)
    if instance and VALID_TARGETS[instance.Name] then
        return instance.Name
    end
    if part and VALID_TARGETS[part.Name] then
        return part.Name
    end
    return nil
end

local function registerCandidate(instance)
    local part = getTargetPart(instance)
    local targetName = getCandidateName(instance, part)
    if not part or not targetName then
        return
    end

    Logic.Candidates[instance] = {
        Instance = instance,
        Part = part,
        Name = targetName,
    }
end

local function unregisterCandidate(instance)
    if not instance then
        return
    end

    Logic.Candidates[instance] = nil
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

local function clearInputConnections()
    for _, connection in ipairs(Logic.InputConnections) do
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    table.clear(Logic.InputConnections)
    Logic.AdaptInputHeld = false
    Logic.AdaptInputBeganAt = 0
    Logic.AdaptDriveActive = false
    Logic.AdaptRecastToken = Logic.AdaptRecastToken + 1
    Logic.AdaptRecastPending = false
    Logic.AdaptRecastReleaseIssued = false
    Logic.AdaptAwaitingAttachUntil = 0
    Logic.AdaptRetryAt = 0
end

local function getTrackedGrapple()
    local grapple = Logic.CurrentGrappleStep or Logic.LastKnownGrapple
    if typeof(grapple) ~= "table" then
        return nil
    end

    local movement = grapple.Movement
    if not movement then
        return nil
    end

    if movement.ActiveSpecial ~= grapple then
        return nil
    end

    return grapple
end

local function fireSpecialAction(grapple, state)
    local movement = grapple and grapple.Movement
    if not (movement and typeof(movement.SpecialAction) == "function") then
        return false
    end

    local success = pcall(function()
        movement:SpecialAction(state)
    end)

    return success
end

local function pulseSpecialAction(grapple)
    if time() - Logic.LastAdaptPulseAt < ADAPT_RECAST_COOLDOWN then
        return false
    end
    if not fireSpecialAction(grapple, Enum.UserInputState.Begin) then
        return false
    end

    Logic.LastAdaptPulseAt = time()
    Logic.AdaptAwaitingAttachUntil = Logic.LastAdaptPulseAt + ADAPT_ATTACH_GRACE
    Logic.AdaptRetryAt = Logic.AdaptAwaitingAttachUntil + ADAPT_RETRY_DELAY

    local token = Logic.AdaptRecastToken + 1
    Logic.AdaptRecastToken = token

    task.delay(ADAPT_INPUT_PULSE_DURATION, function()
        if Logic.AdaptRecastToken ~= token then
            return
        end

        local activeGrapple = grapple
        if not (activeGrapple and activeGrapple.Movement and activeGrapple.Movement.ActiveSpecial == activeGrapple) then
            activeGrapple = getTrackedGrapple()
        end
        if not activeGrapple then
            return
        end

        fireSpecialAction(activeGrapple, Enum.UserInputState.End)
    end)

    return true
end

local function armAutoRescueWindow()
    Logic.AutoRescueUntil = time() + AUTO_RESCUE_WINDOW
end

local function isAutoRescueWindowActive()
    return time() <= (Logic.AutoRescueUntil or 0)
end

local function isAwaitingAdaptAttach(grapple)
    local movement = grapple and grapple.Movement
    if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
        Logic.AdaptAwaitingAttachUntil = 0
        Logic.AdaptRetryAt = 0
        return false
    end

    return time() <= (Logic.AdaptAwaitingAttachUntil or 0)
end

local function getAdaptHorizontalSpeed(grapple)
    local rootPart = grapple and grapple.RootPart
    local horizontal = getHorizontalVelocity(rootPart)
    return horizontal.Magnitude, horizontal
end

local function getActiveGrappleTargetPosition(grapple)
    local movement = grapple and grapple.Movement
    if movement and typeof(movement.grapplePoint) == "Vector3" then
        return movement.grapplePoint
    end

    local part = (movement and movement.grapplePart) or grapple and grapple.grapplePart
    if part and part.Parent and part:IsA("BasePart") then
        return part.Position
    end

    return nil
end

local function getAdaptArrivalDistance(grapple)
    local movement = grapple and grapple.Movement
    local part = (movement and movement.grapplePart) or grapple and grapple.grapplePart
    if part and part.Parent and part.Name == "TriaOrb" then
        return ADAPT_RECAST_TRIA_ARRIVAL_DISTANCE
    end

    local size = part and part.Parent and part:IsA("BasePart") and part.Size.Magnitude * 0.45 or 0
    return math.max(ADAPT_RECAST_ARRIVAL_DISTANCE, size)
end

local function hasReachedGrappleDestination(grapple)
    local rootPart = grapple and grapple.RootPart
    local targetPosition = getActiveGrappleTargetPosition(grapple)
    if not (rootPart and targetPosition) then
        return true
    end

    local remainingDistance = (targetPosition - rootPart.Position).Magnitude
    if remainingDistance <= getAdaptArrivalDistance(grapple) then
        return true
    end

    local rootVelocity = rootPart.Velocity
    if not rootVelocity then
        return false
    end

    local toTarget = targetPosition - rootPart.Position
    if toTarget.Magnitude <= 0.001 then
        return true
    end

    return rootVelocity:Dot(toTarget.Unit) <= 0
end

local function clampAdaptRecastVelocity(grapple)
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return
    end

    local speed, horizontal = getAdaptHorizontalSpeed(grapple)
    if speed <= ADAPT_RECAST_SAFE_SPEED or speed <= 0 then
        return
    end

    local clampedHorizontal = horizontal.Unit * ADAPT_RECAST_CLAMP_SPEED
    rootPart.Velocity = Vector3.new(clampedHorizontal.X, rootPart.Velocity.Y, clampedHorizontal.Z)
end

local function requestAdaptRecast(grapple)
    local now = time()
    if now - Logic.LastAdaptPulseAt < ADAPT_RECAST_COOLDOWN then
        return false
    end

    local movement = grapple and grapple.Movement
    if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
        if not hasReachedGrappleDestination(grapple) then
            return false
        end
        Logic.AdaptRecastPending = true
        Logic.AdaptRecastReleaseIssued = fireSpecialAction(grapple, Enum.UserInputState.End) == true
        Logic.AdaptRecastRequestedAt = now
        Logic.AdaptRecastReleaseAt = now
        markGrappleBonkGrace(grapple, 0.5)
        return Logic.AdaptRecastReleaseIssued
    end

    return pulseSpecialAction(grapple)
end

local function beginAdaptDrive(grapple)
    if Logic.AdaptDriveActive then
        return false
    end

    Logic.AdaptDriveActive = true
    Logic.LastAdaptInputPressed = time()

    if grapple then
        return requestAdaptRecast(grapple)
    end

    return false
end

local function updateAdaptRecast(grapple)
    if not Logic.AdaptRecastPending then
        return
    end
    if not (Logic.AdaptInputHeld and isSuiteEnabled()) then
        Logic.AdaptRecastPending = false
        Logic.AdaptRecastReleaseIssued = false
        return
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement) then
        return
    end

    local now = time()
    local releaseElapsed = now - Logic.AdaptRecastReleaseAt
    local requestElapsed = now - Logic.AdaptRecastRequestedAt
    local detached = movement.grappling ~= true and grapple.jumpPadReel ~= true
    local speed = getAdaptHorizontalSpeed(grapple)

    if speed > ADAPT_RECAST_SAFE_SPEED then
        clampAdaptRecastVelocity(grapple)
        markGrappleBonkGrace(grapple, 0.3)
        speed = getAdaptHorizontalSpeed(grapple)
    end

    if not Logic.AdaptRecastReleaseIssued then
        Logic.AdaptRecastReleaseIssued = fireSpecialAction(grapple, Enum.UserInputState.End) == true
        Logic.AdaptRecastReleaseAt = now
        return
    end

    if not detached then
        return
    end
    if releaseElapsed < ADAPT_RECAST_RELEASE_DELAY then
        return
    end
    if speed > ADAPT_RECAST_SAFE_SPEED and requestElapsed < ADAPT_RECAST_MAX_WAIT then
        return
    end

    Logic.AdaptRecastPending = false
    Logic.AdaptRecastReleaseIssued = false
    pulseSpecialAction(grapple)
end

local function maintainAdaptInputHold(grapple)
    if not (Logic.AdaptDriveActive and Logic.AdaptInputHeld and isSuiteEnabled() and isInAir(grapple)) then
        return
    end
    if Logic.AdaptRecastPending then
        return
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement) then
        return
    end
    if isAwaitingAdaptAttach(grapple) then
        return
    end
    if time() < (Logic.AdaptRetryAt or 0) then
        return
    end
    if time() - Logic.LastAdaptPulseAt < ADAPT_RECAST_COOLDOWN then
        return
    end

    if movement.grappling == true or grapple.jumpPadReel == true then
        if not hasReachedGrappleDestination(grapple) then
            return
        end
        requestAdaptRecast(grapple)
        return
    end

    if not hasAdaptDriveTarget(grapple) then
        Logic.AdaptRetryAt = time() + ADAPT_RETRY_DELAY
        return
    end

    pulseSpecialAction(grapple)
end

local function updateAdaptInputMode(grapple)
    if not (Logic.AdaptInputHeld and isSuiteEnabled()) then
        return
    end
    if Logic.AdaptDriveActive then
        return
    end
    if time() - (Logic.AdaptInputBeganAt or 0) < ADAPT_TAP_THRESHOLD then
        return
    end

    beginAdaptDrive(grapple)
end

local function watchAdaptInput()
    if #Logic.InputConnections > 0 then
        return
    end

    table.insert(Logic.InputConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or isTextBoxFocused() or input.KeyCode ~= getAdaptInputKeyCode() then
            return
        end

        Logic.AdaptInputHeld = true
        Logic.AdaptInputBeganAt = time()
    end))

    table.insert(Logic.InputConnections, UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode ~= getAdaptInputKeyCode() then
            return
        end

        local heldDuration = time() - (Logic.AdaptInputBeganAt or 0)
        local shouldTap = heldDuration <= ADAPT_TAP_THRESHOLD and Logic.AdaptDriveActive ~= true

        Logic.AdaptInputHeld = false
        Logic.AdaptInputBeganAt = 0
        Logic.AdaptDriveActive = false
        Logic.AdaptRecastPending = false
        Logic.AdaptRecastReleaseIssued = false
        Logic.AdaptAwaitingAttachUntil = 0
        Logic.AdaptRetryAt = 0

        if shouldTap and isSuiteEnabled() then
            local grapple = getTrackedGrapple()
            if grapple then
                Logic.LastAdaptInputPressed = time()
                requestAdaptRecast(grapple)
            end
        end
    end))
end

local function rebuildCandidateCache()
    table.clear(Logic.Candidates)

    local jumpPads = Workspace:FindFirstChild("JumpPads")
    if not jumpPads then
        return
    end

    for _, child in ipairs(jumpPads:GetChildren()) do
        registerCandidate(child)
    end
end

local function watchCandidateFolder()
    clearConnections()
    rebuildCandidateCache()

    local jumpPads = Workspace:FindFirstChild("JumpPads")
    if not jumpPads then
        local connection = Workspace.ChildAdded:Connect(function(child)
            if child.Name == "JumpPads" then
                watchCandidateFolder()
            end
        end)
        table.insert(Logic.Connections, connection)
        return
    end

    table.insert(Logic.Connections, jumpPads.ChildAdded:Connect(registerCandidate))
    table.insert(Logic.Connections, jumpPads.ChildRemoved:Connect(unregisterCandidate))
end

local function getGrappleModule()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    local specials = movement and movement:FindFirstChild("Specials")
    local grappleScript = specials and specials:FindFirstChild("Grapple")
    if not grappleScript or not grappleScript:IsA("ModuleScript") then
        return nil
    end

    local success, grappleModule = pcall(require, grappleScript)
    if not success or typeof(grappleModule) ~= "table" then
        return nil
    end

    return grappleModule
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

local function clearLegacyInfiniteStaminaHook(globals, grappleModule)
    if globals.GrappleAimAssistHooked or not globals.GrapplerInfiniteStaminaHooked then
        return
    end

    if grappleModule then
        if globals.OriginalGrappleStep then
            grappleModule.Step = globals.OriginalGrappleStep
        end
        if globals.OriginalGrappleStart then
            grappleModule.Start = globals.OriginalGrappleStart
        end
    end

    globals.OriginalGrappleStep = nil
    globals.OriginalGrappleStart = nil
    globals.GrapplerInfiniteStaminaHooked = nil
end

local function getEntitiesGC()
    local success, gc = pcall(function()
        return getgenv().loadModule("NULLSCAPE/Entities/GC.luau")
    end)
    if success and typeof(gc) == "table" then
        return gc
    end
    return nil
end

function isInAir(grapple)
    local humanoid = grapple and grapple.Humanoid
    if not humanoid then
        return false
    end

    return humanoid.FloorMaterial == Enum.Material.Air
end

local function isFallingFast(grapple)
    local rootPart = grapple and grapple.RootPart
    local velocity = rootPart and rootPart.Velocity
    return velocity and velocity.Y < -35
end

local function isHighMomentumDanger(grapple)
    if not (grapple and isInAir(grapple)) then
        return false
    end

    return getHorizontalVelocity(grapple.RootPart).Magnitude >= AUTO_RESCUE_SPEED
end

local function getModeValue(key)
    local controller = getController()
    return normalizeMode(controller and controller[key])
end

local function hasUpgrade(movement, upgradeName)
    if not (movement and typeof(movement.HasUpgrade) == "function") then
        return false
    end

    local success, result = pcall(function()
        return movement:HasUpgrade(upgradeName)
    end)
    return success and result == true
end

function getHorizontalVelocity(rootPart)
    local velocity = rootPart and rootPart.Velocity
    if not velocity then
        return Vector3.new(0, 0, 0)
    end

    return velocity * Vector3.new(1, 0, 1)
end

local function getFallbackHitbox(rootPart)
    if Logic.FallbackHitbox and Logic.FallbackHitbox.Parent then
        Logic.FallbackHitbox.CFrame = rootPart.CFrame
        return Logic.FallbackHitbox
    end

    local part = Instance.new("Part")
    part.Name = "NULLSCAPE_GrappleFallbackHitbox"
    part.Size = FALLBACK_HITBOX_SIZE
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CFrame = rootPart.CFrame
    part.Parent = Workspace
    Logic.FallbackHitbox = part

    return part
end

local function getStaminaRatio(grapple)
    if isInfiniteStamina() then
        return 1
    end

    local maxTime = tonumber(grapple and grapple.usedGrappleTime) or tonumber(grapple and grapple.TimeClamp) or 0
    local currentTime = tonumber(grapple and grapple.Time) or 0
    if maxTime <= 0 then
        return 1
    end

    return math.clamp(currentTime / maxTime, 0, 1)
end

local function refillStamina(grapple)
    if not isInfiniteStamina() or typeof(grapple) ~= "table" then
        return
    end

    local maxTime = tonumber(grapple.usedGrappleTime) or tonumber(grapple.TimeClamp) or tonumber(grapple.Time)
    if not maxTime or maxTime <= 0 then
        return
    end

    grapple.Time = maxTime
    grapple.TimeClamp = maxTime
    grapple.TimeDrained = false

    local ui = grapple.UI
    local frame = ui and ui:FindFirstChild("Frame")
    local bar = frame and frame:FindFirstChild("Bar")
    if bar then
        pcall(function()
            bar.Size = UDim2.fromScale(1, 1)
        end)
    end
end

local function getAssistRange(grapple, ignoreStamina)
    if ignoreStamina then
        return DEFAULT_MAX_RANGE
    end

    local staminaRatio = getStaminaRatio(grapple)
    if staminaRatio < 0.3 then
        return 45
    elseif staminaRatio < 0.6 then
        return 70
    end

    return DEFAULT_MAX_RANGE
end

local function shouldForceNearest(grapple)
    return not isInfiniteStamina() and getStaminaRatio(grapple) < 0.3
end

local function getScreenAnchor(camera, rangeMode)
    if rangeMode == "Closest To Cursor" then
        local mouseLocation = UserInputService:GetMouseLocation()
        local viewportSize = camera.ViewportSize
        if mouseLocation.X >= 0 and mouseLocation.Y >= 0 and mouseLocation.X <= viewportSize.X and mouseLocation.Y <= viewportSize.Y then
            return mouseLocation
        end
    end

    return camera.ViewportSize * 0.5
end

local function getCameraScreenScore(camera, worldPosition, anchor)
    local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
    if not onScreen or viewportPoint.Z <= 0 then
        return nil
    end

    local viewportSize = camera.ViewportSize
    if viewportPoint.X < 0 or viewportPoint.Y < 0 or viewportPoint.X > viewportSize.X or viewportPoint.Y > viewportSize.Y then
        return nil
    end

    local delta = Vector2.new(viewportPoint.X, viewportPoint.Y) - anchor
    return delta.Magnitude / math.max(viewportSize.X, viewportSize.Y)
end

local function isLineClear(grapple, targetInstance, targetPart, targetPosition, maxRange)
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return nil
    end

    local offset = targetPosition - rootPart.Position
    local distance = offset.Magnitude
    if distance <= 0 or distance > maxRange then
        return nil
    end

    local result = Workspace:Raycast(rootPart.Position, offset, grapple.grappleParams)
    if not result then
        return nil
    end

    if result.Instance == targetPart or result.Instance:IsDescendantOf(targetInstance) then
        return result, distance
    end

    return nil
end

local function isTargetHit(result, targetInstance, targetPart)
    if not result or not result.Instance then
        return false
    end

    return result.Instance == targetPart or result.Instance:IsDescendantOf(targetInstance)
end

local function isPathSafeForHitbox(grapple, targetInstance, targetPart, targetPosition, maxRange)
    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not rootPart then
        return nil
    end

    local offset = targetPosition - rootPart.Position
    local distance = offset.Magnitude
    if distance <= 0 or distance > maxRange then
        return nil
    end

    local hitbox = movement and movement.Hitbox
    if not (hitbox and hitbox.Parent and hitbox:IsA("BasePart")) then
        hitbox = getFallbackHitbox(rootPart)
    end

    local size = hitbox.Size or FALLBACK_HITBOX_SIZE
    local buffer = math.max(size.X, size.Y, size.Z) * 0.5
    local castDistance = math.max(distance - buffer, 0)
    if castDistance <= 0 then
        return true
    end

    local direction = offset.Unit * castDistance
    local success, result = pcall(function()
        return Workspace:Shapecast(hitbox, direction, movement and movement.moveCastParams or grapple.grappleParams)
    end)
    if not success then
        return true
    end

    if not result then
        return true
    end

    if isTargetHit(result, targetInstance, targetPart) then
        return true
    end

    if result.Normal and result.Normal.Y < 0.7 then
        return false
    end

    return false
end

local function isBellInstance(instance)
    return instance and instance.Name == "Bell"
end

local function isJumpPadInstance(instance)
    return instance and instance.Name == "JumpPad" and instance:IsA("BasePart")
end

local function cacheJumpPadState(part)
    if not isJumpPadInstance(part) or Logic.JumpPadStates[part] then
        return
    end

    local textures = {}
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Texture") then
            textures[child] = {
                Color3 = child.Color3,
                Speed = child:GetAttribute("Speed"),
            }
        end
    end

    Logic.JumpPadStates[part] = {
        Uses = part:GetAttribute("Uses"),
        CanQuery = part.CanQuery,
        Color = part.Color,
        Textures = textures,
    }
end

local function normalizeJumpPadForReuse(part)
    if not isJumpPadInstance(part) then
        return
    end

    cacheJumpPadState(part)

    pcall(function()
        part:SetAttribute("Uses", nil)
    end)
    pcall(function()
        part.CanQuery = true
    end)

    local state = Logic.JumpPadStates[part]
    if state then
        pcall(function()
            part.Color = state.Color
        end)

        for texture, textureState in pairs(state.Textures or {}) do
            if texture and texture.Parent then
                pcall(function()
                    texture.Color3 = textureState.Color3
                    texture:SetAttribute("Speed", textureState.Speed)
                end)
            end
        end
    end
end

local function restoreJumpPad(part, state)
    if not (part and part.Parent and state) then
        return
    end

    pcall(function()
        part:SetAttribute("Uses", state.Uses)
    end)
    pcall(function()
        part.CanQuery = state.CanQuery
        part.Color = state.Color
    end)

    for texture, textureState in pairs(state.Textures or {}) do
        if texture and texture.Parent then
            pcall(function()
                texture.Color3 = textureState.Color3
                texture:SetAttribute("Speed", textureState.Speed)
            end)
        end
    end
end

local function restoreJumpPadBypassParts()
    for part, state in pairs(Logic.JumpPadStates) do
        restoreJumpPad(part, state)
    end
    table.clear(Logic.JumpPadStates)
end

local function maintainJumpPadUsesBypass()
    local enabled = isJumpPadUsesBypassEnabled()
    if not enabled then
        if Logic.LastJumpPadUsesBypassEnabled then
            restoreJumpPadBypassParts()
        end
        Logic.LastJumpPadUsesBypassEnabled = false
        return
    end

    Logic.LastJumpPadUsesBypassEnabled = true

    local jumpPads = Workspace:FindFirstChild("JumpPads")
    if not jumpPads then
        return
    end

    for _, child in ipairs(jumpPads:GetChildren()) do
        if isJumpPadInstance(child) then
            normalizeJumpPadForReuse(child)
        end
    end
end

local function getSavedBellData(part)
    local gc = getEntitiesGC()
    local data = gc and gc.SavedPartsData and gc.SavedPartsData[part]
    if data and data.enemyName and string.find(string.lower(data.enemyName), "bell") then
        return gc, data
    end
    return gc, nil
end

local function hasSavedBellImmunity(part)
    local _, data = getSavedBellData(part)
    return data ~= nil
end

local function releaseBellBypass()
    local bypass = Logic.BellBypass
    if not bypass then
        return
    end

    local part = bypass.Part
    local data = bypass.Data
    local _, currentData = getSavedBellData(part)
    if part and part.Parent and data and currentData == data then
        data.connections = data.connections or {}

        pcall(function()
            part.CanTouch = false
        end)

        local conn = part:GetPropertyChangedSignal("CanTouch"):Connect(function()
            if part.CanTouch then
                part.CanTouch = false
            end
        end)
        table.insert(data.connections, conn)
    elseif part and part.Parent and bypass.RestoreCanTouch ~= nil then
        pcall(function()
            part.CanTouch = bypass.RestoreCanTouch
        end)
    end

    Logic.BellBypass = nil
end

local function scheduleBellBypassRelease(delaySeconds)
    if not Logic.BellBypass then
        return
    end

    Logic.BellBypassToken = Logic.BellBypassToken + 1
    local token = Logic.BellBypassToken

    task.delay(delaySeconds or 0.5, function()
        if token ~= Logic.BellBypassToken then
            return
        end

        releaseBellBypass()
    end)
end

local function holdBellBypass(part)
    if not part or not part.Parent or part.Name ~= "Bell" then
        return
    end

    if Logic.BellBypass and Logic.BellBypass.Part == part then
        if not part.CanTouch then
            pcall(function()
                part.CanTouch = true
            end)
        end
        return
    end

    Logic.BellBypassToken = Logic.BellBypassToken + 1
    releaseBellBypass()

    local _, data = getSavedBellData(part)
    if data then
        for _, conn in ipairs(data.connections or {}) do
            if conn then
                pcall(function()
                    conn:Disconnect()
                end)
            end
        end
        data.connections = {}

        Logic.BellBypass = {
            Part = part,
            Data = data,
        }
    elseif not part.CanTouch then
        Logic.BellBypass = {
            Part = part,
            RestoreCanTouch = false,
        }
    end

    if Logic.BellBypass then
        pcall(function()
            part.CanTouch = true
        end)
    end
end

local function maintainBellBypass(grapple)
    local movement = grapple and grapple.Movement
    local part = grapple and grapple.grapplePart
    if movement and movement.grappling and isBellInstance(part) then
        holdBellBypass(part)
    else
        scheduleBellBypassRelease(0.5)
    end
end

local function getCandidateList()
    local list = {}
    for _, candidate in pairs(Logic.Candidates) do
        table.insert(list, candidate)
    end
    return list
end

local isUsableResult

local function chooseRandomCandidate(validResults, preferredName)
    local preferred = {}
    for _, item in ipairs(validResults) do
        if item.Name == preferredName then
            table.insert(preferred, item)
        end
    end

    local source = #preferred > 0 and preferred or validResults
    if #source == 0 then
        return nil
    end

    return source[Logic.Random:NextInteger(1, #source)].Result
end

local function getEffectivePreferredTarget(grapple, preferredName)
    if isAutoRescueWindowActive() and isHighMomentumDanger(grapple) then
        return "TriaOrb"
    end

    return preferredName
end

local function scanNamedTargets(grapple, options)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local driveMode = typeof(options) == "table" and options.driveMode == true

    local controller = getController()
    local preferredName = normalizeTargetPriority(controller and controller.GrappleAimAssistTargetPriority)
    local rescueMode = isRescueEnabled() and isFallingFast(grapple)
    local emergencyBrakeMode = isRescueEnabled() and isHighMomentumDanger(grapple) and isAutoRescueWindowActive()
    preferredName = getEffectivePreferredTarget(grapple, preferredName)
    local rangeMode = normalizeRangePriority(controller and controller.GrappleAimAssistRangePriority)
    if not driveMode and shouldForceNearest(grapple) then
        rangeMode = "Nearest"
    elseif emergencyBrakeMode then
        rangeMode = "Nearest"
    end

    local maxRange = getAssistRange(grapple, driveMode)
    local staminaRatio = getStaminaRatio(grapple)
    local screenAnchor = getScreenAnchor(camera, rangeMode)
    local candidateList = getCandidateList()
    local candidateCount = #candidateList
    if candidateCount == 0 then
        return nil
    end

    local validResults = {}
    local rescuePriority = {
        Bell = 0,
        GrapplePoint = 1,
        JumpPad = 2,
        TriaOrb = 3,
    }
    local bestScore = math.huge
    local bestResult = nil
    local checks = driveMode and candidateCount or math.min(candidateCount, MAX_CANDIDATES_PER_CAST)

    for _ = 1, checks do
        if Logic.CandidateCursor > candidateCount then
            Logic.CandidateCursor = 1
        end

        local candidate = candidateList[Logic.CandidateCursor]
        Logic.CandidateCursor = Logic.CandidateCursor + 1

        local part = candidate and candidate.Part
        if part and part.Parent then
            if candidate.Name ~= "Bell" or part.CanTouch or hasSavedBellImmunity(part) then
                local position = part.Position
                local screenScore = getCameraScreenScore(camera, position, screenAnchor)
                if screenScore then
                    local result, distance = isLineClear(grapple, candidate.Instance, part, position, maxRange)
                    if
                        result
                        and isUsableResult(grapple, result)
                        and isPathSafeForHitbox(grapple, candidate.Instance, part, position, maxRange)
                    then
                        local item = {
                            Name = candidate.Name,
                            Result = result,
                            Distance = distance,
                            ScreenScore = screenScore,
                        }

                        if rangeMode == "Random" then
                            table.insert(validResults, item)
                        else
                            local priorityScore = candidate.Name == preferredName and 0 or 1000
                            if rescueMode then
                                priorityScore = rescuePriority[candidate.Name] or 1000
                            elseif emergencyBrakeMode then
                                priorityScore = candidate.Name == "TriaOrb" and 0 or 5000
                            end
                            local distanceScore = rangeMode == "Farthest" and -distance or distance
                            if rangeMode == "Closest To Cursor" then
                                distanceScore = distance * 0.25
                            end
                            local staminaPenalty = driveMode and 0 or (isInfiniteStamina() and 0 or distance * (1 - staminaRatio) * 0.12)
                            local score = priorityScore + screenScore * 100 + distanceScore * 0.01 + staminaPenalty

                            if score < bestScore then
                                bestScore = score
                                bestResult = result
                            end
                        end
                    end
                end
            end
        else
            unregisterCandidate(candidate and candidate.Instance)
        end
    end

    if rangeMode == "Random" then
        return chooseRandomCandidate(validResults, preferredName)
    end

    return bestResult
end

local function scanScreenSurface(grapple, options)
    local camera = Workspace.CurrentCamera
    local rootPart = grapple and grapple.RootPart
    if not camera or not rootPart then
        return nil
    end

    local driveMode = typeof(options) == "table" and options.driveMode == true

    local viewportSize = camera.ViewportSize
    local maxRange = getAssistRange(grapple, driveMode)

    for _, offset in ipairs(SCREEN_RAY_OFFSETS) do
        local screenPoint = Vector2.new(
            viewportSize.X * (0.5 + offset.X),
            viewportSize.Y * (0.5 + offset.Y)
        )
        local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
        local cameraHit = Workspace:Raycast(ray.Origin, ray.Direction.Unit * 2048, grapple.grappleParams)
        if cameraHit then
            local directOffset = cameraHit.Position - rootPart.Position
            if directOffset.Magnitude > 0 and directOffset.Magnitude <= maxRange then
                local directHit = Workspace:Raycast(rootPart.Position, directOffset, grapple.grappleParams)
                if
                    directHit
                    and isUsableResult(grapple, directHit)
                    and isPathSafeForHitbox(grapple, directHit.Instance, directHit.Instance, directHit.Position, maxRange)
                then
                    return directHit
                end
            end
        end
    end

    return nil
end

function hasAdaptDriveTarget(grapple)
    local driveOptions = { driveMode = true }
    return scanNamedTargets(grapple, driveOptions) ~= nil or scanScreenSurface(grapple, driveOptions) ~= nil
end

local function tryAutoMomentumRescue(grapple)
    if not (isRescueEnabled() and isHighMomentumDanger(grapple)) then
        return false
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement and grapple.specialHeld and isInAir(grapple)) then
        return false
    end
    if movement.grappling or grapple.jumpPadReel then
        return false
    end
    if time() - Logic.LastAutoRescuePulseAt < AUTO_RESCUE_COOLDOWN then
        return false
    end

    armAutoRescueWindow()
    local previewResult = scanNamedTargets(grapple)
    if not (previewResult and previewResult.Instance and previewResult.Instance.Name == "TriaOrb") then
        return false
    end

    Logic.LastAutoRescuePulseAt = time()
    return pulseSpecialAction(grapple)
end

function isUsableResult(grapple, result)
    if not result then
        return false
    end

    local instance = result.Instance
    if not instance then
        return false
    end

    if instance.Name == "Bell" and instance.CanTouch == false and not hasSavedBellImmunity(instance) then
        return false
    end

    local humanoid = grapple and grapple.Humanoid
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Running and instance.Name ~= "JumpPad" then
        return false
    end

    return true
end

local function assistedCast(grapple, forceRefresh, originalCast, ...)
    local result, direction = originalCast(grapple, forceRefresh, ...)
    local canAssist = isEnabled() or (isRescueEnabled() and isFallingFast(grapple))
    if isUsableResult(grapple, result) or not canAssist then
        return result, direction
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement and grapple.specialHeld and not movement.grappling and isInAir(grapple)) then
        return result, direction
    end

    local assistedResult = scanNamedTargets(grapple) or scanScreenSurface(grapple)
    if assistedResult then
        if assistedResult.Instance and assistedResult.Instance.Name == "Bell" then
            holdBellBypass(assistedResult.Instance)
        end
        return assistedResult
    end

    return result, direction
end

local function canUseSharkTail(grapple)
    local movement = grapple and grapple.Movement
    if not (grapple and movement and isSharkTailHelperEnabled()) then
        return false
    end
    if getModeValue("GrappleSharkTailMode") ~= "Automatic" and getModeValue("GrappleSharkTailMode") ~= "Manual" then
        return false
    end

    return grapple.allowSharkTail == true
        and grapple.sharkTailDisable ~= true
        and isInAir(grapple)
        and hasUpgrade(movement, "SharkTail")
end

local function tryUseSharkTail(grapple)
    if not canUseSharkTail(grapple) then
        return false
    end

    local horizontal = getHorizontalVelocity(grapple.RootPart)
    if horizontal.Magnitude < 35 then
        return false
    end

    if typeof(grapple.SpecialAction) == "function" then
        grapple:SpecialAction(Enum.UserInputState.Begin)
        return true
    end

    return false
end

local function canStartSmartReel(grapple)
    local movement = grapple and grapple.Movement
    if not (grapple and movement and isSmartReelEnabled()) then
        return false
    end
    if not isInAir(grapple) then
        return false
    end
    if not hasUpgrade(movement, "NinjaBelt") then
        return false
    end
    if not movement.grappling or grapple.jumpPadReel or grapple.reelCooldown or grapple.sharkTailDisable then
        return false
    end
    if tonumber(grapple.Time) == 0 then
        return false
    end
    if not (movement.grapplePoint and movement.grapplePart and movement.grapplePart.Parent) then
        return false
    end

    return isPathSafeForHitbox(grapple, movement.grapplePart, movement.grapplePart, movement.grapplePoint, DEFAULT_MAX_RANGE) == true
end

local function startSmartReel(grapple)
    if not canStartSmartReel(grapple) then
        return false
    end

    grapple.jumpPadReel = true
    grapple.reelStart = time()
    grapple.grappleReel = true
    markGrappleBonkGrace(grapple, MOMENTUM_GUARD_WINDOW)

    if grapple.SFX and grapple.SFX.PlaySound then
        pcall(function()
            grapple.SFX:PlaySound("GrapplerReel")
        end)
    end

    return true
end

local function applyMomentumGuard(grapple)
    if not isMomentumGuardEnabled() then
        return
    end

    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart) then
        return
    end
    if movement ~= Logic.LastGrappleMovement or time() > Logic.SuppressBonkUntil then
        return
    end

    local horizontal = getHorizontalVelocity(rootPart)
    local speed = horizontal.Magnitude
    if speed <= MOMENTUM_GUARD_SPEED then
        return
    end

    local targetSpeed = math.max(MOMENTUM_GUARD_CLAMP, speed - (speed - MOMENTUM_GUARD_CLAMP) * 0.35)
    local clampedHorizontal = horizontal.Unit * targetSpeed
    rootPart.Velocity = Vector3.new(clampedHorizontal.X, rootPart.Velocity.Y, clampedHorizontal.Z)
end

local function applyAirControlMultiplier(grapple, dt)
    local multiplier = getAirControlMultiplier()
    if multiplier <= 1 then
        return
    end

    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart and movement.grappling and not grapple.jumpPadReel) then
        return
    end

    local playerMoveDirection = movement.PlayerMoveDirection
    if typeof(playerMoveDirection) ~= "Vector3" or playerMoveDirection.Magnitude <= 0.01 then
        return
    end

    local graceWingsMultiplier = hasUpgrade(movement, "GraceWings") and 1.5 or 1
    local movementSpeedMultiplier = tonumber(movement.movementSpeedMulti) or 1
    local extraForce = playerMoveDirection * 12 * graceWingsMultiplier * (multiplier - 1) * dt * movementSpeedMultiplier

    rootPart.Velocity = rootPart.Velocity + extraForce
end

local function applyReelPullMultiplier(grapple)
    local multiplier = getReelPullMultiplier()
    if multiplier <= 1 then
        return
    end

    local rootPart = grapple and grapple.RootPart
    if not (grapple and rootPart and grapple.jumpPadReel) then
        return
    end

    rootPart.Velocity = rootPart.Velocity * multiplier
end

local function applySharkTailPullMultiplier(grapple, previousVelocity)
    local multiplier = getSharkTailPullMultiplier()
    if multiplier <= 1 then
        return
    end

    local rootPart = grapple and grapple.RootPart
    if not (grapple and rootPart) then
        return
    end

    local beforeVelocity = previousVelocity
    if typeof(beforeVelocity) ~= "Vector3" then
        beforeVelocity = Vector3.new(0, 0, 0)
    end

    local deltaVelocity = rootPart.Velocity - beforeVelocity
    if deltaVelocity.Magnitude <= 0.01 then
        return
    end

    rootPart.Velocity = beforeVelocity + deltaVelocity * multiplier
end

local function shouldSuppressGrappleBonk(movement)
    if not isAntiBonkEnabled() then
        return false
    end

    local grapple = Logic.CurrentGrappleStep
    if grapple and grapple.Movement == movement then
        return movement.grappling == true or grapple.jumpPadReel == true
    end

    if movement == Logic.LastGrappleMovement and time() < Logic.SuppressBonkUntil then
        local rootPart = movement.RootPart
        local speed = rootPart and rootPart.Velocity and rootPart.Velocity.Magnitude or 0
        return speed > 70
    end

    return false
end

local function getNoCollisionMoveCastParams()
    if Logic.NoCollisionMoveCastParams then
        return Logic.NoCollisionMoveCastParams
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Workspace }
    params.RespectCanCollide = true
    Logic.NoCollisionMoveCastParams = params

    return params
end

local function shouldSuppressGrappleCollisionCheck(grapple)
    if not isAntiBonkEnabled() then
        return false
    end

    local movement = grapple and grapple.Movement
    local rootPart = grapple and grapple.RootPart
    if not (movement and rootPart) then
        return false
    end

    if movement.grappling == true or grapple.jumpPadReel == true then
        return true
    end

    local lastRelease = tonumber(grapple.lastGrappleRelease)
    return lastRelease ~= nil and time() - lastRelease < 1.5 and rootPart.Velocity.Magnitude > 70
end

local function beginGrappleCollisionBypass(grapple)
    if not shouldSuppressGrappleCollisionCheck(grapple) then
        return nil
    end

    local movement = grapple.Movement
    local previousMoveCastParams = movement.moveCastParams
    movement.moveCastParams = getNoCollisionMoveCastParams()

    return function()
        if movement then
            movement.moveCastParams = previousMoveCastParams
        end
    end
end

function markGrappleBonkGrace(grapple, duration)
    local movement = grapple and grapple.Movement
    if not movement then
        return
    end

    Logic.LastGrappleMovement = movement
    Logic.SuppressBonkUntil = math.max(Logic.SuppressBonkUntil, time() + duration)
end

local function ensureDiveBonkHook(globals)
    if globals.GrappleAimAssistOriginalDiveBonk then
        return
    end

    local movementCore = getMovementCore()
    if not (movementCore and typeof(movementCore.DiveBonk) == "function") then
        return
    end

    local originalDiveBonk = movementCore.DiveBonk
    globals.GrappleAimAssistOriginalDiveBonk = originalDiveBonk

    movementCore.DiveBonk = function(self, ...)
        if shouldSuppressGrappleBonk(self) then
            self.diveBonked = false
            self.bonkedOffPlayer = false
            return nil
        end

        return originalDiveBonk(self, ...)
    end
end

function Logic.enable()
    local globals = getGlobals()
    if globals.GrappleAimAssistHooked then
        ensureDiveBonkHook(globals)
        watchAdaptInput()
        watchCandidateFolder()
        return true
    end

    local grappleModule = getGrappleModule()
    if not grappleModule or typeof(grappleModule.Cast) ~= "function" then
        return false
    end
    clearLegacyInfiniteStaminaHook(globals, grappleModule)

    local originalCast = grappleModule.Cast
    globals.GrappleAimAssistOriginalCast = originalCast

    grappleModule.Cast = function(self, forceRefresh, ...)
        return assistedCast(self, forceRefresh, originalCast, ...)
    end

    if typeof(grappleModule.Start) == "function" then
        local originalStart = grappleModule.Start
        globals.GrappleAimAssistOriginalStart = originalStart

        grappleModule.Start = function(self, result, ...)
            Logic.LastKnownGrapple = self
            refillStamina(self)
            maintainJumpPadUsesBypass()
            local jumpPadTarget = result and result.Instance
            if isJumpPadUsesBypassEnabled() and isJumpPadInstance(jumpPadTarget) then
                normalizeJumpPadForReuse(jumpPadTarget)
            end

            if result and result.Instance and result.Instance.Name == "Bell" then
                holdBellBypass(result.Instance)
            end

            local startResult = originalStart(self, result, ...)
            refillStamina(self)
            if isJumpPadUsesBypassEnabled() and isJumpPadInstance(jumpPadTarget) then
                normalizeJumpPadForReuse(jumpPadTarget)
            end
            maintainBellBypass(self)
            return startResult
        end
    end

    if typeof(grappleModule.AltSpecialAction) == "function" then
        local originalAltSpecialAction = grappleModule.AltSpecialAction
        globals.GrappleAimAssistOriginalAltSpecialAction = originalAltSpecialAction

        grappleModule.AltSpecialAction = function(self, state, ...)
            if isSuiteEnabled() and state == Enum.UserInputState.Begin then
                if isSharkTailHelperEnabled() and getModeValue("GrappleSharkTailMode") == "Manual" and tryUseSharkTail(self) then
                    return nil
                end

                if isSmartReelEnabled() and getModeValue("GrappleSmartReelMode") == "Manual" then
                    return originalAltSpecialAction(self, state, ...)
                end
            end

            return originalAltSpecialAction(self, state, ...)
        end
    end

    if typeof(grappleModule.SharkTail) == "function" then
        local originalSharkTail = grappleModule.SharkTail
        globals.GrappleAimAssistOriginalSharkTail = originalSharkTail

        grappleModule.SharkTail = function(self, ...)
            local previousVelocity = self and self.RootPart and self.RootPart.Velocity
            local result = originalSharkTail(self, ...)
            applySharkTailPullMultiplier(self, previousVelocity)
            return result
        end
    end

    if typeof(grappleModule.Step) == "function" then
        local originalStep = grappleModule.Step
        globals.GrappleAimAssistOriginalStep = originalStep

        grappleModule.Step = function(self, dt, ...)
            Logic.LastKnownGrapple = self
            refillStamina(self)
            maintainJumpPadUsesBypass()
            maintainBellBypass(self)
            if self.Movement and (self.Movement.grappling or self.jumpPadReel) then
                markGrappleBonkGrace(self, 0.45)
            end

            if isSuiteEnabled() and isInAir(self) then
                updateAdaptInputMode(self)

                if isSharkTailHelperEnabled() and getModeValue("GrappleSharkTailMode") == "Automatic" then
                    tryUseSharkTail(self)
                end

                if isSmartReelEnabled() and getModeValue("GrappleSmartReelMode") == "Automatic" then
                    startSmartReel(self)
                end

                tryAutoMomentumRescue(self)
                maintainAdaptInputHold(self)
            end

            Logic.CurrentGrappleStep = self
            local restoreCollisionCheck = beginGrappleCollisionBypass(self)
            local success, stepResult = pcall(originalStep, self, dt, ...)
            Logic.CurrentGrappleStep = nil
            if restoreCollisionCheck then
                restoreCollisionCheck()
            end
            if not success then
                error(stepResult, 0)
            end
            maintainBellBypass(self)
            refillStamina(self)
            applyReelPullMultiplier(self)
            applyAirControlMultiplier(self, dt)
            applyMomentumGuard(self)
            updateAdaptRecast(self)
            return stepResult
        end
    end

    ensureDiveBonkHook(globals)

    if typeof(grappleModule.End) == "function" then
        local originalEnd = grappleModule.End
        globals.GrappleAimAssistOriginalEnd = originalEnd

        grappleModule.End = function(self, ...)
            Logic.LastKnownGrapple = self
            markGrappleBonkGrace(self, 0.45)
            local endResult = originalEnd(self, ...)
            scheduleBellBypassRelease(0.5)
            return endResult
        end
    end

    globals.GrappleAimAssistHooked = true
    watchAdaptInput()
    watchCandidateFolder()
    return true
end

function Logic.disable()
    local globals = getGlobals()
    local grappleModule = getGrappleModule()
    if grappleModule and globals.GrappleAimAssistOriginalCast then
        grappleModule.Cast = globals.GrappleAimAssistOriginalCast
    end
    if grappleModule and globals.GrappleAimAssistOriginalStart then
        grappleModule.Start = globals.GrappleAimAssistOriginalStart
    end
    if grappleModule and globals.GrappleAimAssistOriginalStep then
        grappleModule.Step = globals.GrappleAimAssistOriginalStep
    end
    if grappleModule and globals.GrappleAimAssistOriginalEnd then
        grappleModule.End = globals.GrappleAimAssistOriginalEnd
    end
    if grappleModule and globals.GrappleAimAssistOriginalAltSpecialAction then
        grappleModule.AltSpecialAction = globals.GrappleAimAssistOriginalAltSpecialAction
    end
    if grappleModule and globals.GrappleAimAssistOriginalSharkTail then
        grappleModule.SharkTail = globals.GrappleAimAssistOriginalSharkTail
    end
    local movementCore = getMovementCore()
    if movementCore and globals.GrappleAimAssistOriginalDiveBonk then
        movementCore.DiveBonk = globals.GrappleAimAssistOriginalDiveBonk
    end

    globals.GrappleAimAssistOriginalCast = nil
    globals.GrappleAimAssistOriginalStart = nil
    globals.GrappleAimAssistOriginalStep = nil
    globals.GrappleAimAssistOriginalEnd = nil
    globals.GrappleAimAssistOriginalAltSpecialAction = nil
    globals.GrappleAimAssistOriginalSharkTail = nil
    globals.GrappleAimAssistOriginalDiveBonk = nil
    globals.GrappleAimAssistHooked = false
    Logic.CurrentGrappleStep = nil
    Logic.LastKnownGrapple = nil
    Logic.LastGrappleMovement = nil
    Logic.SuppressBonkUntil = 0
    Logic.BellBypassToken = Logic.BellBypassToken + 1
    releaseBellBypass()
    restoreJumpPadBypassParts()
    Logic.LastJumpPadUsesBypassEnabled = false
    if Logic.FallbackHitbox then
        pcall(function()
            Logic.FallbackHitbox:Destroy()
        end)
        Logic.FallbackHitbox = nil
    end
    Logic.NoCollisionMoveCastParams = nil
    clearInputConnections()
    clearConnections()
    table.clear(Logic.Candidates)
end

function Logic.getTargetOptions()
    local options = {}
    for _, option in ipairs(TARGET_OPTIONS) do
        table.insert(options, option)
    end
    return options
end

function Logic.getRangeOptions()
    local options = {}
    for _, option in ipairs(RANGE_OPTIONS) do
        table.insert(options, option)
    end
    return options
end

function Logic.isAdaptInputHeld()
    return Logic.AdaptInputHeld == true
end

function Logic.getLastAdaptInputPressed()
    return Logic.LastAdaptInputPressed
end

return Logic
