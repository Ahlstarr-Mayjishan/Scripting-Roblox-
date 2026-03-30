--[[
    NPCTracker.lua — OOP World Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
    Optimized for high-performance and zero redundancy.
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
    return self
end

function NPCTracker:Init()
    -- Simplify: We rely on periodical systematic polling in GetTargets
    -- This avoids the "signal overlapping" and "Workspace fallback" debt.
end

function NPCTracker:GetTargets()
    local result = {}
    local foldersFound = false
    
    -- 1. Scan Folders (Entities)
    for _, name in ipairs(self._folders) do
        local f = Workspace:FindFirstChild(name)
        if f then
            foldersFound = true
            for _, model in ipairs(f:GetChildren()) do
                if model:IsA("Model") then
                    local entry = self:_GetOrCreateEntry(model)
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
    
    -- Safety: If NO folders found, we do NOT fallback to Workspace to avoid false targets.
    -- Instead, we return empty list and warn once.
    if not foldersFound and not self._warnedFolders then
        self._warnedFolders = true
        warn("⚠️ [NPCTracker] Targeting folders not found. Ensure models are in: "..table.concat(self._folders, ", "))
    end
    
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    -- Cleanup entry if model is destroyed
    if self._entries[model] and not model.Parent then
        self._entries[model] = nil
        return nil
    end

    if self._entries[model] then return self._entries[model] end
    
    -- Support for Non-Humanoid bosses/models if they have a PrimaryPart
    local hum = model:FindFirstChildOfClass("Humanoid")
    local primary = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    
    if not primary then return nil end
    
    local isBoss = self.Detector:IsBoss(model, hum)
    
    local entry = {
        Model = model,
        Humanoid = hum,
        PrimaryPart = primary,
        IsBoss = isBoss,
        Name = model.Name,
        Velocity = Vector3.zero,
        Acceleration = Vector3.zero,
        LastPos = primary.Position,
        LastTime = os.clock(),
        Confidence = 1
    }
    
    self._entries[model] = entry
    return entry
end

function NPCTracker:GetTargetPart(entry)
    local model = entry.Model
    if not model or not model.Parent then return nil end
    
    -- Advanced selection: custom part -> Primary -> Head
    local targetPart = model:FindFirstChild(self.Options.TargetPart)
    if not targetPart then
        targetPart = entry.PrimaryPart or model:PrimaryPart or model:FindFirstChild("Head")
    end
    
    return targetPart
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    self.CurrentTargetEntry = nil
end

return NPCTracker
