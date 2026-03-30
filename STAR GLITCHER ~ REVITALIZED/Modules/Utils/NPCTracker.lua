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

function NPCTracker:GetTargets()
    local now = os.clock()
    
    -- Adaptive Polling Strategy: Resolving frame-rate dependency
    if (now - self._lastScan) < self._scanInterval then
        return self._cachedTargets
    end
    
    self._lastScan = now
    local result = {}
    local foldersFound = false
    
    -- 1. Scan Folders (Entities)
    for _, name in ipairs(self._folders) do
        local f = Workspace:FindFirstChild(name)
        if f then
            foldersFound = true
            for _, model in ipairs(f:GetChildren()) do
                if model:IsA("Model") and not self:IsLocalCharacterModel(model) then
                    local entry = self:_GetOrCreateEntry(model)
                    -- Clean up dead/invalid entries in the final list
                    if entry and (not entry.Humanoid or entry.Humanoid.Health > 0) then 
                        table.insert(result, entry) 
                    end
                end
            end
        end
    end
    
    -- 2. Scan Players (PvP Mode)
    if self.Options.TargetPlayersToggle then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer and p.Character then
                local entry = self:_GetOrCreateEntry(p.Character)
                if entry and (not entry.Humanoid or entry.Humanoid.Health > 0) then
                    table.insert(result, entry)
                end
            end
        end
    end
    
    self._cachedTargets = result
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    -- ORTHOGONAL DECOUPLING: Tracker entries NO LONGER store prediction results (Velocity/Accel).
    -- They only store raw kinematic memory (LastPos/LastTime).

    if self:IsLocalCharacterModel(model) then
        self._entries[model] = nil
        return nil
    end

    if self._entries[model] and not model.Parent then
        self._entries[model] = nil
        return nil
    end

    if self._entries[model] then return self._entries[model] end
    
    local hum = model:FindFirstChildOfClass("Humanoid")
    local primary = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    
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
    return targetPart or entry.PrimaryPart or model.PrimaryPart or model:FindFirstChild("Head")
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    table.clear(self._cachedTargets)
    self.CurrentTargetEntry = nil
end

return NPCTracker
