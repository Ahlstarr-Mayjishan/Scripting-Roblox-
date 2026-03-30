--[[
    NPCTracker.lua — OOP World Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
    Optimized for high-performance with adaptive polling.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local NPCTracker = {}
NPCTracker.__index = NPCTracker

function NPCTracker.new(config, detector)
    local self = setmetatable({}, NPCTracker)
    self.Options = config.Options
    self.Blacklist = config.Blacklist or {"statue", "tuong", "monument", "altar", "dummy"}
    self.Detector = detector
    
    self.CurrentTargetEntry = nil
    self._entries = {}
    self._folders = {"Entities", "Enemies", "Monsters"}
    
    -- Performance: Polling Strategy
    self._lastScan = 0
    self._scanInterval = 0.1 -- Scan every 100ms instead of every frame
    self._cachedTargets = {}
    
    return self
end

function NPCTracker:Init()
    -- Systematic startup if needed
end

function NPCTracker:IsLocalCharacterModel(model)
    return model ~= nil and model == Players.LocalPlayer.Character
end

function NPCTracker:_HasBlacklistedName(model)
    if not model then
        return false
    end

    local modelName = string.lower(model.Name)
    for _, keyword in ipairs(self.Blacklist) do
        if modelName:find(string.lower(keyword), 1, true) then
            return true
        end
    end

    return false
end

function NPCTracker:_GetPrimaryPart(model)
    if not model then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Head")
        or model:FindFirstChildWhichIsA("BasePart")
end

function NPCTracker:_IsTargetCandidate(model)
    if not model or not model:IsA("Model") or self:IsLocalCharacterModel(model) then
        return false
    end

    local isPlayerCharacter = Players:GetPlayerFromCharacter(model) ~= nil
    if isPlayerCharacter then
        return self.Options.TargetPlayersToggle == true
    end

    if self:_HasBlacklistedName(model) then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false
    end

    return self:_GetPrimaryPart(model) ~= nil
end

function NPCTracker:GetTargets()
    local now = os.clock()
    
    -- Adaptive Polling Strategy: Resolving frame-rate dependency
    if (now - self._lastScan) < self._scanInterval then
        return self._cachedTargets
    end
    
    self._lastScan = now
    local result = {}
    local foldersFound = false
    local seenModels = {}

    local function trackModel(model)
        if not model or seenModels[model] then
            return
        end

        seenModels[model] = true
        local entry = self:_GetOrCreateEntry(model)
        if entry and (not entry.Humanoid or entry.Humanoid.Health > 0) then
            table.insert(result, entry)
        end
    end
    
    -- 1. Scan Folders (Entities)
    for _, name in ipairs(self._folders) do
        local f = Workspace:FindFirstChild(name)
        if f then
            foldersFound = true
            for _, model in ipairs(f:GetDescendants()) do
                if model:IsA("Model") then
                    trackModel(model)
                end
            end
        end
    end

    if not foldersFound then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") then
                trackModel(model)
            end
        end
    end
    
    -- 2. Scan Players (PvP Mode)
    if self.Options.TargetPlayersToggle then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer and p.Character then
                trackModel(p.Character)
            end
        end
    end
    
    self._cachedTargets = result
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    -- ORTHOGONAL DECOUPLING: Tracker entries NO LONGER store prediction results (Velocity/Accel).
    -- They only store raw kinematic memory (LastPos/LastTime).

    if not self:_IsTargetCandidate(model) then
        self._entries[model] = nil
        return nil
    end

    if self._entries[model] and not model.Parent then
        self._entries[model] = nil
        return nil
    end

    if self._entries[model] then return self._entries[model] end
    
    local hum = model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    
    if not primary then return nil end
    
    local entry = {
        Model = model,
        Humanoid = hum,
        PrimaryPart = primary,
        IsBoss = self.Detector:IsBoss(model, hum),
        Name = model.Name,
        -- Pure kinematic state memory
        LastPos = primary.Position,
        LastTime = os.clock()
    }
    
    self._entries[model] = entry
    return entry
end

function NPCTracker:GetTargetPart(entry)
    local model = entry.Model
    if not model or not model.Parent or self:IsLocalCharacterModel(model) then return nil end
    
    local targetPart = model:FindFirstChild(self.Options.TargetPart)
    if not targetPart then
        if self.Options.TargetPart == "Torso" then
            targetPart = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
        elseif self.Options.TargetPart == "Head" then
            targetPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        end
    end

    return targetPart or entry.PrimaryPart or self:_GetPrimaryPart(model)
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    table.clear(self._cachedTargets)
    self.CurrentTargetEntry = nil
end

return NPCTracker
