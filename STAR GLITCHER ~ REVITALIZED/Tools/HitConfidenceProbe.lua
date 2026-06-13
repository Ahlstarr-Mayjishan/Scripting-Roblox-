--[[
    HitConfidenceProbe.lua
    Standalone internal test helper for validating "did my shot likely deal damage?"

    Usage:
    1. Run your main runtime first if you want the probe to reuse its highlight target.
    2. Copy this file and execute it standalone.
    3. Left click to register a shot. The probe tracks the target at shot time.
    4. It watches health-like values on that exact target and reports damage deltas.

    Classification:
    - CONFIRMED: reserved for future remote/projectile ACK signals.
    - PROBABLE: the tracked target lost health inside the shot confirmation window.
    - MISS: no health drop observed in time.

    Notes:
    - This intentionally does not claim perfect attribution in multiplayer.
    - It is strongest when you test alone on a boss or on a target few others are hitting.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local clock = os.clock

local SETTINGS = {
    WindowSeconds = 1.1,
    GraceSeconds = 0.06,
    MaxRows = 10,
    PollInterval = 0.03,
    HighlightFillColor = Color3.fromRGB(240, 60, 60),
    HighlightTolerance = 8,
}

local HEALTH_HINTS = {
    "Health", "HP", "HitPoints", "BossHealth", "EnemyHealth", "HealthValue",
}

local Probe = {
    Shots = {},
    Alive = true,
    LastPoll = 0,
    NextId = 0,
}

local function round(n)
    if typeof(n) ~= "number" then
        return n
    end
    return math.floor(n * 100 + 0.5) / 100
end

local function findCharacterAncestor(instance)
    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Model") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function getLargestPart(model)
    local bestPart = nil
    local bestVolume = -1
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local size = descendant.Size
            local volume = size.X * size.Y * size.Z
            if volume > bestVolume then
                bestPart = descendant
                bestVolume = volume
            end
        end
    end
    return bestPart
end

local function getPrimaryPart(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or getLargestPart(model)
end

local function getHealthObject(model)
    if not model then
        return nil, nil
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid, "Humanoid"
    end

    for _, hint in ipairs(HEALTH_HINTS) do
        local child = model:FindFirstChild(hint, true)
        if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
            return child, child.ClassName
        end
    end

    if model:GetAttribute("Health") ~= nil or model:GetAttribute("HP") ~= nil then
        return model, "Attribute"
    end

    return nil, nil
end

local function readHealth(model)
    local source, sourceType = getHealthObject(model)
    if not source then
        return nil, nil, "Missing"
    end

    if sourceType == "Humanoid" then
        return tonumber(source.Health), tonumber(source.MaxHealth), "Humanoid"
    end

    if sourceType == "Attribute" then
        local current = tonumber(model:GetAttribute("Health")) or tonumber(model:GetAttribute("HP"))
        local max = tonumber(model:GetAttribute("MaxHealth")) or tonumber(model:GetAttribute("MaxHP")) or current
        return current, max, "Attribute"
    end

    local value = tonumber(source.Value)
    return value, value, source.Name
end

local function findProbeHighlight()
    local best = nil

    local function scan(container)
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("Highlight") and descendant.Enabled and descendant.Adornee then
                local fill = descendant.FillColor
                local diff = math.abs(fill.R * 255 - SETTINGS.HighlightFillColor.R * 255)
                    + math.abs(fill.G * 255 - SETTINGS.HighlightFillColor.G * 255)
                    + math.abs(fill.B * 255 - SETTINGS.HighlightFillColor.B * 255)
                if diff <= SETTINGS.HighlightTolerance * 3 then
                    best = descendant
                    return true
                end
            end
        end
        return false
    end

    pcall(function()
        if scan(CoreGui) then
            return
        end
    end)

    if not best then
        pcall(function()
            local camera = Workspace.CurrentCamera
            if camera then
                scan(camera)
            end
        end)
    end

    return best
end

local function resolveCurrentTarget()
    local highlight = findProbeHighlight()
    if highlight and highlight.Adornee then
        local model = findCharacterAncestor(highlight.Adornee)
        if model then
            return model, highlight.Adornee, "highlight"
        end
    end

    local mouseTarget = Mouse.Target
    local model = findCharacterAncestor(mouseTarget)
    if model then
        return model, mouseTarget, "mouse"
    end

    return nil, nil, "none"
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StarGlitcherHitProbe"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    screenGui.Parent = CoreGui
end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.Size = UDim2.fromOffset(430, 250)
frame.Position = UDim2.new(1, -450, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = screenGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 90, 90)
stroke.Transparency = 0.2
stroke.Parent = frame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 24)
title.Font = Enum.Font.Code
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 240, 240)
title.Text = "Hit Confidence Probe"
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(12, 30)
subtitle.Size = UDim2.new(1, -24, 0, 18)
subtitle.Font = Enum.Font.Code
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(180, 190, 205)
subtitle.Text = "Left click = register shot | highlight target first for best results"
subtitle.Parent = frame

local logLabel = Instance.new("TextLabel")
logLabel.BackgroundTransparency = 1
logLabel.Position = UDim2.fromOffset(12, 56)
logLabel.Size = UDim2.new(1, -24, 1, -68)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 14
logLabel.TextWrapped = false
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.RichText = false
logLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
logLabel.Text = "Waiting for shots..."
logLabel.Parent = frame

local function formatShot(shot)
    local age = round(clock() - shot.Time)
    local prefix = string.format("#%d [%s]", shot.Id, shot.State)
    local modelName = shot.ModelName or "Unknown"
    local source = shot.TargetSource or "?"

    if shot.State == "PROBABLE" then
        return string.format(
            "%s dmg=%s dt=%ss target=%s via=%s health=%s->%s",
            prefix,
            tostring(round(shot.Damage or 0)),
            tostring(round((shot.HitTime or shot.Time) - shot.Time)),
            modelName,
            source,
            tostring(round(shot.HealthBefore)),
            tostring(round(shot.HealthAfter))
        )
    end

    if shot.State == "MISS" then
        return string.format(
            "%s no drop age=%ss target=%s via=%s start=%s",
            prefix,
            tostring(age),
            modelName,
            source,
            tostring(round(shot.HealthBefore))
        )
    end

    return string.format(
        "%s pending age=%ss target=%s via=%s health=%s source=%s",
        prefix,
        tostring(age),
        modelName,
        source,
        tostring(round(shot.HealthBefore)),
        tostring(shot.HealthKind or "?")
    )
end

local function refreshLog()
    local lines = {
        string.format("Active shots: %d", #Probe.Shots),
    }

    local count = 0
    for i = #Probe.Shots, 1, -1 do
        count = count + 1
        if count > SETTINGS.MaxRows then
            break
        end
        lines[#lines + 1] = formatShot(Probe.Shots[i])
    end

    logLabel.Text = table.concat(lines, "\n")
end

local function pushShot(shot)
    Probe.Shots[#Probe.Shots + 1] = shot
    while #Probe.Shots > SETTINGS.MaxRows do
        table.remove(Probe.Shots, 1)
    end
    refreshLog()
end

local function registerShot()
    local model, part, source = resolveCurrentTarget()
    Probe.NextId = Probe.NextId + 1

    if not model then
        pushShot({
            Id = Probe.NextId,
            Time = clock(),
            State = "MISS",
            Model = nil,
            ModelName = "No target",
            TargetSource = source,
            HealthBefore = nil,
            HealthAfter = nil,
            Damage = 0,
        })
        return
    end

    local health, maxHealth, kind = readHealth(model)
    pushShot({
        Id = Probe.NextId,
        Time = clock(),
        ExpiresAt = clock() + SETTINGS.WindowSeconds,
        State = "PENDING",
        Model = model,
        ModelName = model.Name,
        Part = part or getPrimaryPart(model),
        TargetSource = source,
        HealthBefore = health,
        HealthAfter = health,
        MaxHealth = maxHealth,
        HealthKind = kind,
        Damage = 0,
    })
end

local function updateShots()
    local now = clock()
    if (now - Probe.LastPoll) < SETTINGS.PollInterval then
        return
    end
    Probe.LastPoll = now

    local dirty = false

    for _, shot in ipairs(Probe.Shots) do
        if shot.State == "PENDING" and shot.Model and shot.Model.Parent then
            local health = readHealth(shot.Model)
            if typeof(health) == "number" and typeof(shot.HealthBefore) == "number" then
                if health < shot.HealthBefore and (now - shot.Time) >= SETTINGS.GraceSeconds then
                    shot.HealthAfter = health
                    shot.Damage = shot.HealthBefore - health
                    shot.HitTime = now
                    shot.State = "PROBABLE"
                    dirty = true
                elseif now >= shot.ExpiresAt then
                    shot.HealthAfter = health
                    shot.State = "MISS"
                    dirty = true
                end
            elseif now >= shot.ExpiresAt then
                shot.State = "MISS"
                dirty = true
            end
        end
    end

    if dirty then
        refreshLog()
    end
end

local inputConnection
local renderConnection

inputConnection = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not Probe.Alive then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        registerShot()
    elseif input.KeyCode == Enum.KeyCode.Delete then
        Probe.Alive = false
        if inputConnection then
            inputConnection:Disconnect()
        end
        if renderConnection then
            renderConnection:Disconnect()
        end
        screenGui:Destroy()
    end
end)

renderConnection = RunService.RenderStepped:Connect(function()
    if Probe.Alive then
        updateShots()
    end
end)

refreshLog()

return Probe
