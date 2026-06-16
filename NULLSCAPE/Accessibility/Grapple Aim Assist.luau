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
    Candidates = {},
    CandidateCursor = 1,
    Random = Random.new(),
    BellBypass = nil,
    CurrentGrappleStep = nil,
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

local DEFAULT_MAX_RANGE = 90
local MAX_CANDIDATES_PER_CAST = 48

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
    return controller and controller.GrappleAimAssistEnabled == true
end

local function isAntiBonkEnabled()
    local controller = getController()
    return controller and controller.GrappleAntiBonkEnabled == true
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

local function getEntitiesGC()
    local success, gc = pcall(function()
        return getgenv().loadModule("NULLSCAPE/Entities/GC.luau")
    end)
    if success and typeof(gc) == "table" then
        return gc
    end
    return nil
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

local function getAssistRange(grapple)
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

local function isBellInstance(instance)
    return instance and instance.Name == "Bell"
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
        releaseBellBypass()
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

local function scanNamedTargets(grapple)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local controller = getController()
    local preferredName = normalizeTargetPriority(controller and controller.GrappleAimAssistTargetPriority)
    local rangeMode = normalizeRangePriority(controller and controller.GrappleAimAssistRangePriority)
    if shouldForceNearest(grapple) then
        rangeMode = "Nearest"
    end

    local maxRange = getAssistRange(grapple)
    local staminaRatio = getStaminaRatio(grapple)
    local screenAnchor = getScreenAnchor(camera, rangeMode)
    local candidateList = getCandidateList()
    local candidateCount = #candidateList
    if candidateCount == 0 then
        return nil
    end

    local validResults = {}
    local bestScore = math.huge
    local bestResult = nil
    local checks = math.min(candidateCount, MAX_CANDIDATES_PER_CAST)

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
                    if result and isUsableResult(grapple, result) then
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
                            local distanceScore = rangeMode == "Farthest" and -distance or distance
                            if rangeMode == "Closest To Cursor" then
                                distanceScore = distance * 0.25
                            end
                            local staminaPenalty = isInfiniteStamina() and 0 or distance * (1 - staminaRatio) * 0.12
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

local function scanScreenSurface(grapple)
    local camera = Workspace.CurrentCamera
    local rootPart = grapple and grapple.RootPart
    if not camera or not rootPart then
        return nil
    end

    local viewportSize = camera.ViewportSize
    local maxRange = getAssistRange(grapple)

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
                if directHit and isUsableResult(grapple, directHit) then
                    return directHit
                end
            end
        end
    end

    return nil
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
    if isUsableResult(grapple, result) or not isEnabled() then
        return result, direction
    end

    local movement = grapple and grapple.Movement
    if not (grapple and movement and grapple.specialHeld and not movement.grappling) then
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

local function shouldSuppressGrappleBonk(movement)
    if not isAntiBonkEnabled() then
        return false
    end

    local grapple = Logic.CurrentGrappleStep
    if not grapple or grapple.Movement ~= movement then
        return false
    end

    return movement.grappling == true or grapple.jumpPadReel == true
end

function Logic.enable()
    local globals = getGlobals()
    if globals.GrappleAimAssistHooked then
        watchCandidateFolder()
        return true
    end

    local grappleModule = getGrappleModule()
    if not grappleModule or typeof(grappleModule.Cast) ~= "function" then
        return false
    end

    local originalCast = grappleModule.Cast
    globals.GrappleAimAssistOriginalCast = originalCast

    grappleModule.Cast = function(self, forceRefresh, ...)
        return assistedCast(self, forceRefresh, originalCast, ...)
    end

    if typeof(grappleModule.Start) == "function" then
        local originalStart = grappleModule.Start
        globals.GrappleAimAssistOriginalStart = originalStart

        grappleModule.Start = function(self, result, ...)
            if result and result.Instance and result.Instance.Name == "Bell" then
                holdBellBypass(result.Instance)
            end

            local startResult = originalStart(self, result, ...)
            maintainBellBypass(self)
            return startResult
        end
    end

    if typeof(grappleModule.Step) == "function" then
        local originalStep = grappleModule.Step
        globals.GrappleAimAssistOriginalStep = originalStep

        grappleModule.Step = function(self, dt, ...)
            maintainBellBypass(self)
            Logic.CurrentGrappleStep = self
            local success, stepResult = pcall(originalStep, self, dt, ...)
            Logic.CurrentGrappleStep = nil
            if not success then
                error(stepResult, 0)
            end
            maintainBellBypass(self)
            return stepResult
        end
    end

    local movementCore = getMovementCore()
    if movementCore and typeof(movementCore.DiveBonk) == "function" then
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

    if typeof(grappleModule.End) == "function" then
        local originalEnd = grappleModule.End
        globals.GrappleAimAssistOriginalEnd = originalEnd

        grappleModule.End = function(self, ...)
            local endResult = originalEnd(self, ...)
            releaseBellBypass()
            return endResult
        end
    end

    globals.GrappleAimAssistHooked = true
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
    local movementCore = getMovementCore()
    if movementCore and globals.GrappleAimAssistOriginalDiveBonk then
        movementCore.DiveBonk = globals.GrappleAimAssistOriginalDiveBonk
    end

    globals.GrappleAimAssistOriginalCast = nil
    globals.GrappleAimAssistOriginalStart = nil
    globals.GrappleAimAssistOriginalStep = nil
    globals.GrappleAimAssistOriginalEnd = nil
    globals.GrappleAimAssistOriginalDiveBonk = nil
    globals.GrappleAimAssistHooked = false
    Logic.CurrentGrappleStep = nil
    releaseBellBypass()
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

return Logic
