--[[
    Apocalypse.lua - The Ultimate Neural Hijacker
    Job: Parasitic locking of game projectiles and beams to boss entities.
    Notes: Uses a singleton hook state to avoid stacking hooks across reloads.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Apocalypse = {}
Apocalypse.__index = Apocalypse

local GLOBAL_HOOK_KEY = "__STAR_GLITCHER_APOCALYPSE_HOOK"
local BOSS_HINTS = { "boss", "king", "queen", "lord", "orb", "sphere", "core" }
local HEALTH_HINTS = { "Health", "HP", "HitPoints", "BossHealth", "EnemyHealth", "HealthValue" }

local function containsBossHint(text)
    local lowered = string.lower(tostring(text or ""))
    for _, hint in ipairs(BOSS_HINTS) do
        if lowered:find(hint, 1, true) then
            return true
        end
    end
    return false
end

local function getLargestPart(model)
    local bestPart = nil
    local bestVolume = -1
    if not model then
        return nil
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
            if volume > bestVolume then
                bestPart = descendant
                bestVolume = volume
            end
        end
    end

    return bestPart
end

local function getPrimaryPart(model)
    if not model then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or getLargestPart(model)
end

local function getHealthLikeValue(model)
    if not model then
        return nil, nil
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth, humanoid
    end

    for _, hint in ipairs(HEALTH_HINTS) do
        local child = model:FindFirstChild(hint, true)
        if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
            local value = tonumber(child.Value)
            if value then
                return value, value, nil
            end
        end
    end

    local attrHealth = tonumber(model:GetAttribute("Health")) or tonumber(model:GetAttribute("HP"))
    local attrMaxHealth = tonumber(model:GetAttribute("MaxHealth")) or tonumber(model:GetAttribute("MaxHP"))
    if attrHealth or attrMaxHealth then
        return attrHealth or attrMaxHealth, attrMaxHealth or attrHealth, nil
    end

    return nil, nil, nil
end

local function getBoundsInfo(model)
    if not model then
        return Vector3.zero, 0
    end

    local ok, _, size = pcall(model.GetBoundingBox, model)
    if ok and typeof(size) == "Vector3" then
        return size, size.X * size.Y * size.Z
    end

    return Vector3.zero, 0
end

local function scoreBossModel(model)
    if not model or not model:IsA("Model") or model == LocalPlayer.Character then
        return nil, nil
    end

    local primary = getPrimaryPart(model)
    if not primary then
        return nil, nil
    end

    local health, maxHealth, humanoid = getHealthLikeValue(model)
    if humanoid and humanoid.Health <= 0 then
        return nil, nil
    end
    if not humanoid and health and health <= 0 then
        return nil, nil
    end

    local size, volume = getBoundsInfo(model)
    local score = 0
    local primaryIsBall = primary.Shape == Enum.PartType.Ball

    if containsBossHint(model.Name) then
        score = score + 6
    end

    if humanoid and containsBossHint(humanoid.DisplayName) then
        score = score + 5
    end

    if maxHealth and maxHealth > 500 then
        score = score + 5
    elseif maxHealth and maxHealth > 150 then
        score = score + 2
    end

    if volume > 70 then
        score = score + 4
    elseif volume > 30 then
        score = score + 2
    end

    if primaryIsBall then
        score = score + 3
        local axis = math.max(size.X, size.Y, size.Z, primary.Size.X, primary.Size.Y, primary.Size.Z)
        if axis >= 5 then
            score = score + 2
        end
    end

    if humanoid then
        score = score + 1
    end

    if score < 4 then
        return nil, nil
    end

    return score, primary
end

local function ensureHookState()
    local hookState = getgenv()[GLOBAL_HOOK_KEY]
    if hookState then
        return hookState
    end

    local mouse = LocalPlayer:GetMouse()
    hookState = {
        Instance = nil,
        Mouse = mouse,
    }

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local selfRef = hookState.Instance
        local method = getnamecallmethod()
        local args = table.pack(...)

        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef.Active
            and selfRef._bossExists then
            if method == "FireServer" or method == "InvokeServer" then
                for i = 1, args.n do
                    local value = args[i]
                    if typeof(value) == "Vector3" then
                        args[i] = selfRef._bossPos
                    elseif typeof(value) == "CFrame" then
                        args[i] = CFrame.new(selfRef._bossPos)
                    end
                end
                return oldNamecall(inst, unpack(args, 1, args.n))
            end

            if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and inst == Camera then
                return Ray.new(Camera.CFrame.Position, (selfRef._bossPos - Camera.CFrame.Position).Unit)
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        local selfRef = hookState.Instance
        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef.Active
            and selfRef._bossExists
            and inst == hookState.Mouse then
            if index == "Hit" then
                return CFrame.new(selfRef._bossPos)
            end
            if index == "Target" then
                return selfRef._bossModel
            end
        end

        return oldIndex(inst, index)
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function Apocalypse.new(config)
    local self = setmetatable({}, Apocalypse)
    self.Options = config.Options
    self.Active = config.Options.ApocalypseEnabled == true

    self._bossPos = Vector3.zero
    self._bossModel = nil
    self._bossExists = false
    self._connections = {}
    self._destroyed = false
    self._hookState = nil

    return self
end

function Apocalypse:Init()
    if not (hookmetamethod or hookfunction) then
        return
    end

    self._destroyed = false
    self._hookState = ensureHookState()
    self._hookState.Instance = self

    local selfRef = self
    local lastTrackerUpdate = 0
    local lastFullScan = 0

    table.insert(self._connections, RunService.Heartbeat:Connect(function()
        if selfRef._destroyed or not selfRef.Active then
            selfRef._bossExists = false
            return
        end

        local now = os.clock()
        if now - lastTrackerUpdate < 0.03 then
            return
        end
        lastTrackerUpdate = now

        local found = nil
        local foundScore = -math.huge
        local entities = Workspace:FindFirstChild("Entities")

        if entities then
            for _, model in ipairs(entities:GetChildren()) do
                if model:IsA("Model") then
                    local score, primary = scoreBossModel(model)
                    if score and primary and score > foundScore then
                        found = primary
                        foundScore = score
                    end
                end
            end
        end

        if (not found or foundScore < 6) and (now - lastFullScan > 1.5) then
            lastFullScan = now
            if entities then
                for _, descendant in ipairs(entities:GetDescendants()) do
                    local model = descendant:IsA("Model") and descendant or descendant:FindFirstAncestorOfClass("Model")
                    local score, primary = scoreBossModel(model)
                    if score and primary and score > foundScore then
                        found = primary
                        foundScore = score
                    end
                end
            end
        end

        if found then
            selfRef._bossPos = found.Position
            selfRef._bossModel = found.Parent
            selfRef._bossExists = true
        else
            selfRef._bossExists = false
            selfRef._bossModel = nil
        end
    end))

    local activeProjectiles = {}
    local effectCache = {}

    table.insert(self._connections, Workspace.ChildAdded:Connect(function(child)
        if child.Name == "BallOfLight" then
            activeProjectiles[#activeProjectiles + 1] = child
        end
    end))

    local function updateEffectCache()
        table.clear(effectCache)
        local char = LocalPlayer.Character
        if char then
            for _, descendant in ipairs(char:GetDescendants()) do
                if descendant:IsA("Beam") or descendant:IsA("Trail") then
                    effectCache[#effectCache + 1] = descendant
                end
            end
        end
    end

    table.insert(self._connections, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if not selfRef._destroyed then
            updateEffectCache()
        end
    end))
    updateEffectCache()

    table.insert(self._connections, RunService.RenderStepped:Connect(function()
        if selfRef._destroyed or not selfRef.Active or not selfRef._bossExists then
            return
        end

        local bossPos = selfRef._bossPos
        for i = #activeProjectiles, 1, -1 do
            local projectile = activeProjectiles[i]
            if projectile and projectile.Parent then
                pcall(function()
                    local attachment = projectile:FindFirstChild("Attachment1")
                    if attachment then
                        attachment.WorldPosition = bossPos
                    end
                    local targetCFrame = projectile:FindFirstChild("TargCF")
                    if targetCFrame then
                        targetCFrame.Value = CFrame.new(bossPos)
                    end
                end)
            else
                table.remove(activeProjectiles, i)
            end
        end

        for _, effect in ipairs(effectCache) do
            pcall(function()
                if effect.Attachment1 then
                    effect.Attachment1.WorldPosition = bossPos
                end
            end)
        end
    end))
end

function Apocalypse:SetState(active)
    self.Active = active
    if not active then
        self._bossExists = false
        self._bossModel = nil
    end
end

function Apocalypse:Destroy()
    self._destroyed = true
    self.Active = false
    self._bossExists = false
    self._bossModel = nil

    if self._hookState and self._hookState.Instance == self then
        self._hookState.Instance = nil
    end

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return Apocalypse
