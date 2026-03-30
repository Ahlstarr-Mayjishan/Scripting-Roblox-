--[[
    NPCTracker.lua — OOP World Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
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
    return self
end

function NPCTracker:Init()
    -- No complex signals needed, just a cache manager
end

function NPCTracker:GetTargets()
    local result = {}
    local folders = {"Entities", "Enemies", "Monsters"}
    
    for _, folderName in ipairs(folders) do
        local f = Workspace:FindFirstChild(folderName)
        if f then
            for _, model in ipairs(f:GetChildren()) do
                if model:IsA("Model") then
                    local entry = self:_GetOrCreateEntry(model)
                    if entry then table.insert(result, entry) end
                end
            end
        end
    end
    
    -- Filter Bosses specifically if requested (logic to come)
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    if self._entries[model] then return self._entries[model] end
    
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    
    local isBoss = self.Detector:IsBoss(model, hum)
    
    local entry = {
        Model = model,
        Humanoid = hum,
        IsBoss = isBoss,
        Name = model.Name,
        Velocity = Vector3.zero,
        Acceleration = Vector3.zero,
        LastPos = nil,
        LastTime = 0,
        Confidence = 1
    }
    
    self._entries[model] = entry
    return entry
end

function NPCTracker:GetTargetPart(entry)
    local model = entry.Model
    if not model or not model.Parent then return nil end
    
    local partName = self.Options.TargetPart or "HumanoidRootPart"
    return model:FindFirstChild(partName) or model:FindFirstChild("Head") or model:PrimaryPart
end

return NPCTracker
