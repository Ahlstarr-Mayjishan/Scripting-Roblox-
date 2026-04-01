--[[
    NPCTracker.lua — Neural Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
    Fixes: Non-humanoid boss support and performance bottlenecks.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local NPCTracker = {}
NPCTracker.__index = NPCTracker

function NPCTracker.new(config, detector)
    local self = setmetatable({}, NPCTracker)
    self.Options = config.Options
    self.Blacklist = config.Blacklist or {"statue", "tuong", "monument", "altar", "dummy", "board", "spawn", "shop", "gui", "display", "map", "portal"}
    self._blacklistLower = {}
    self.Detector = detector
    
    self.CurrentTargetEntry = nil
    self._entries = {}
    self._folders = {"Entities", "Enemies", "Monsters", "NPCs", "Bosses"} -- Expanded folder list
    
    -- Performance: Polling Strategy
    self._lastScan = 0
    self._scanInterval = 0.1 -- Scan every 100ms instead of every frame
    self._cachedTargets = {}
    self._folderRefs = {}
    self._lastFolderRefresh = 0
    self._folderRefreshInterval = 2

    for i, keyword in ipairs(self.Blacklist) do
        self._blacklistLower[i] = string.lower(keyword)
    end
    
    return self
end

function NPCTracker:Init()
end

function NPCTracker:IsLocalCharacterModel(model)
    return model ~= nil and model == Players.LocalPlayer.Character
end

function NPCTracker:_HasBlacklistedName(model)
    if not model then return false end
    local modelName = string.lower(model.Name)
    for _, keyword in ipairs(self._blacklistLower) do
        if modelName:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

function NPCTracker:_GetPrimaryPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or model:FindFirstChildWhichIsA("BasePart")
end

function NPCTracker:_IsTargetCandidate(model)
    -- GUARD: Ensure model validity
    if not model or not model:IsA("Model") or self:IsLocalCharacterModel(model) or not model.Parent then
        return false
    end

    -- PVP Check
    local isPlayerCharacter = Players:GetPlayerFromCharacter(model) ~= nil
    if isPlayerCharacter then
        return self.Options.TargetPlayersToggle == true
    end

    -- Blacklist/Sanity
    if self:_HasBlacklistedName(model) then
        return false
    end

    -- UNIVERSAL TARGETING: Support both Humanoid và Non-Humanoid (Bosses)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    
    if not primary then return false end

    -- STATIC OBJECT FILTER: Boss boards, shops, etc.
    -- Mobs/Bosses (even custom ones) usually have unanchored root parts.
    if not humanoid and primary.Anchored and not model:FindFirstChild("Health") then
        -- Only ignore if it has no health indicators và is anchored
        return false
    end

    return true
end

function NPCTracker:GetTargets()
    local now = os.clock()
    
    if (now - self._lastScan) < self._scanInterval then
        return self._cachedTargets
    end
    
    self._lastScan = now
    local result = self._cachedTargets
    table.clear(result)
    local seenModels = {}

    if (now - self._lastFolderRefresh) >= self._folderRefreshInterval then
        self._lastFolderRefresh = now
        for i = 1, #self._folders do
            self._folderRefs[i] = Workspace:FindFirstChild(self._folders[i])
        end
    end

    local function trackModel(model)
        if not model or seenModels[model] then return end
        seenModels[model] = true
        
        local entry = self:_GetOrCreateEntry(model)
        if entry then
            -- Only include alive targets
            if not entry.Humanoid or entry.Humanoid.Health > 0 then
                result[#result + 1] = entry
                return true
            end
        end
        return false
    end
    
    -- 1. Scan Folders (Entities)
    local foundFolderTarget = false
    for i = 1, #self._folderRefs do
        local f = self._folderRefs[i]
        if f then
            for _, model in ipairs(f:GetChildren()) do
                if model:IsA("Model") and trackModel(model) then
                    foundFolderTarget = true
                end
            end
        end
    end

    -- 2. Fallback Scan (Entities directly in Workspace)
    -- Skip this broad scan if dedicated entity folders already yielded targets.
    if not foundFolderTarget then
        -- Avoid GetDescendants() which is catastrophic for performance.
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") then
                trackModel(obj)
            end
        end
    end
    
    -- 3. Scan Players (PvP Mode)
    if self.Options.TargetPlayersToggle then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer and p.Character then
                trackModel(p.Character)
            end
        end
    end
    
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    if not self:_IsTargetCandidate(model) then
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

    return targetPart or entry.PrimaryPart or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    table.clear(self._cachedTargets)
    self.CurrentTargetEntry = nil
end

return NPCTracker
