--[[
    NPCTracker.lua - Neural Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
    Fixes: Non-humanoid boss support and performance bottlenecks.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local NPCTracker = {}
NPCTracker.__index = NPCTracker

function NPCTracker.new(config, detector, taskScheduler)
    local self = setmetatable({}, NPCTracker)
    self.Options = config.Options
    self.Blacklist = config.Blacklist or {"statue", "Minigames", "monument", "altar", "dummy", "board", "spawn", "shop", "gui", "display", "map", "portal", "tele", "rsbroad", "landscape", "terrain", "sign"}
    self._blacklistLower = {}
    self.Detector = detector
    self.TaskScheduler = taskScheduler
    
    self.CurrentTargetEntry = nil
    self._entries = {}
    self._folders = {"Entities", "Enemies", "Monsters", "NPCs", "Bosses"} -- Expanded folder list
    
    -- Performance: Polling Strategy
    self._lastScan = 0
    self._scanInterval = 0.1 -- Scan every 100ms instead of every frame
    self._cachedTargets = {}
    self._cacheDirty = true
    self._folderRefs = {}
    self._lastFolderRefresh = 0
    self._folderRefreshInterval = 2
    self._staleSweepInterval = 3
    self._entryExpiry = 18
    self._deadEntryExpiry = 6
    self._maxEntries = 180
    self._bossRefreshInterval = 8
    self._schedulerAlive = false
    self._staleSweepScheduled = false
    self._staleSweepGeneration = 0

    for i, keyword in ipairs(self.Blacklist) do
        self._blacklistLower[i] = string.lower(keyword)
    end
    
    return self
end

function NPCTracker:Init()
    self._schedulerAlive = true
    self._cacheDirty = true
    self:_refreshFolderRefs()
    self:_queueStaleSweep()
end

function NPCTracker:Prune(now)
    now = now or os.clock()
    local entryCount = 0

    for model, entry in pairs(self._entries) do
        entryCount = entryCount + 1
        local lastSeen = entry and entry.LastSeen or 0
        local isDead = entry and entry.Humanoid and entry.Humanoid.Health <= 0
        local expiry = isDead and self._deadEntryExpiry or self._entryExpiry

        if not model
            or not model.Parent
            or not entry
            or not entry.PrimaryPart
            or not entry.PrimaryPart.Parent
            or self:_HasBlacklistedName(model) then
            self._entries[model] = nil
        elseif lastSeen > 0 and (now - lastSeen) > expiry then
            self._entries[model] = nil
        end
    end

    if entryCount > self._maxEntries then
        for model, entry in pairs(self._entries) do
            if not entry or (entry.LastSeen or 0) < (now - 4) then
                self._entries[model] = nil
            end
        end
    end
end

function NPCTracker:_refreshFolderRefs()
    for i = 1, #self._folders do
        self._folderRefs[i] = Workspace:FindFirstChild(self._folders[i])
    end
    self._cacheDirty = true
end

function NPCTracker:_queueFolderRefresh()
    if not self.TaskScheduler or not self._schedulerAlive then
        self:_refreshFolderRefs()
        return
    end

    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if selfRef._schedulerAlive then
            selfRef:_refreshFolderRefs()
        end
    end, "__STAR_GLITCHER_TRACKER_FOLDER_REFRESH")
end

function NPCTracker:_queueStaleSweep()
    if not self.TaskScheduler or not self._schedulerAlive or self._staleSweepScheduled then
        return
    end

    self._staleSweepScheduled = true
    self._staleSweepGeneration = self._staleSweepGeneration + 1
    local generation = self._staleSweepGeneration
    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if not selfRef._schedulerAlive then
            selfRef._staleSweepScheduled = false
            return
        end

        if generation ~= selfRef._staleSweepGeneration then
            selfRef._staleSweepScheduled = false
            return
        end

        selfRef:Prune(os.clock())
        selfRef._staleSweepScheduled = false

        task.delay(selfRef._staleSweepInterval, function()
            if selfRef._schedulerAlive and generation == selfRef._staleSweepGeneration then
                selfRef:_queueStaleSweep()
            end
        end)
    end, "__STAR_GLITCHER_TRACKER_STALE_SWEEP")
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

function NPCTracker:_IsTargetCandidate(model, existingEntry)
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

    -- UNIVERSAL TARGETING: Support both Humanoid va Non-Humanoid (Bosses)
    local humanoid = existingEntry and existingEntry.Humanoid or model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    local isBoss = existingEntry and existingEntry.IsBoss
    if isBoss == nil then
        isBoss = self.Detector and self.Detector.IsBoss and self.Detector:IsBoss(model, humanoid)
    end
    
    if not primary then return false end

    -- STATIC OBJECT FILTER: Boss boards, shops, etc.
    -- Mobs/Bosses (even custom ones) usually have unanchored root parts.
    if not humanoid and primary.Anchored and not isBoss and not model:FindFirstChild("Health", true) then
        -- Only ignore if it has no health indicators va is anchored
        return false
    end

    return true
end

function NPCTracker:GetTargets()
    local now = os.clock()

    if not self._cacheDirty and (now - self._lastScan) < self._scanInterval then
        return self._cachedTargets
    end

    self._lastScan = now
    local result = self._cachedTargets
    table.clear(result)
    local seenModels = {}

    if (now - self._lastFolderRefresh) >= self._folderRefreshInterval then
        self._lastFolderRefresh = now
        self:_queueFolderRefresh()
    end

    local function trackModel(model)
        if not model or seenModels[model] then return end
        seenModels[model] = true
        
        local entry = self:_GetOrCreateEntry(model)
        if entry then
            entry.LastSeen = now
            entry.PrimaryPart = self:_GetPrimaryPart(model) or entry.PrimaryPart
            entry.Humanoid = model:FindFirstChildOfClass("Humanoid") or entry.Humanoid
            if (entry.LastBossCheck or 0) <= 0 or (now - entry.LastBossCheck) >= self._bossRefreshInterval then
                entry.IsBoss = self.Detector:IsBoss(model, entry.Humanoid)
                entry.LastBossCheck = now
            end
            if entry.PrimaryPart then
                entry.LastPos = entry.PrimaryPart.Position
            end

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

    self._cacheDirty = false
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    local existingEntry = self._entries[model]
    if existingEntry then
        if not self:_IsTargetCandidate(model, existingEntry) then
            self._entries[model] = nil
            return nil
        end
        return existingEntry
    end

    if not self:_IsTargetCandidate(model) then
        self._entries[model] = nil
        return nil
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    local now = os.clock()
    
    if not primary then return nil end
    
    local entry = {
        Model = model,
        Humanoid = hum,
        PrimaryPart = primary,
        IsBoss = self.Detector:IsBoss(model, hum),
        Name = model.Name,
        LastPos = primary.Position,
        LastTime = now,
        LastSeen = now,
        LastBossCheck = now,
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

    local resolvedPart = targetPart or entry.PrimaryPart or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if resolvedPart then
        entry.PrimaryPart = resolvedPart
    end
    return resolvedPart
end

function NPCTracker:GetEntryCount()
    local count = 0
    for _ in pairs(self._entries) do
        count = count + 1
    end
    return count
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    table.clear(self._cachedTargets)
    self.CurrentTargetEntry = nil
    self._cacheDirty = true
    self._lastScan = 0
end

function NPCTracker:Destroy()
    self._schedulerAlive = false
    self._staleSweepScheduled = false
    self._staleSweepGeneration = self._staleSweepGeneration + 1
    self:ClearCache()
end

return NPCTracker

