--[[
    NPCTracker.lua — NPC/Entity Tracking Class
    Quản lý quét, thêm, xóa NPC/Boss trong folder Entities hoặc folder tự tìm được.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local NPCTracker = {}
NPCTracker.__index = NPCTracker

-- Localize for PERF
local string_lower = string.lower

function NPCTracker.new(config, bossClassifier)
    local self = setmetatable({}, NPCTracker)
    self.Config = config
    self.Options = config.Options
    self.Blacklist = config.Blacklist
    self.BossClassifier = bossClassifier

    -- Tìm folder chứa Boss/NPC (tự động phát hiện nhiều tên phổ biến)
    local commonFolders = {"Entities", "Enemies", "Monsters", "NPCs", "MobFolder", "Mobs", "NPC_Folder", "Living"}
    local targetFolder = Workspace
    for _, name in ipairs(commonFolders) do
        local folder = Workspace:FindFirstChild(name)
        if folder and (folder:IsA("Folder") or folder:IsA("Model")) then
            targetFolder = folder
            break
        end
    end
    self.TargetFolder = targetFolder
    
    self.Entries = {}
    self.Lookup = {}
    self.CurrentTargetEntry = nil
    self._connections = {}
    
    return self
end

-- ═══ PRIVATE HELPERS ═══

function NPCTracker:_isLocalCharacter(model)
    return LocalPlayer.Character and model == LocalPlayer.Character
end

function NPCTracker:_isNPCModel(model)
    if not model or not model:IsA("Model") or self:_isLocalCharacter(model) then
        return false
    end

    local isPlayer = Players:GetPlayerFromCharacter(model)
    if isPlayer then
        return self.Options.TargetPlayersToggle == true
    end

    if not model:IsDescendantOf(self.TargetFolder) and self.TargetFolder ~= Workspace then
        return false
    end

    -- Pre-screen keyword check (PERF)
    local modelName = string_lower(model.Name)
    for _, keyword in ipairs(self.Blacklist) do
        if modelName:find(keyword, 1, true) then
            return false
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then return true end

    local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if rootPart then return true end

    return false
end

-- ═══ PUBLIC API ═══

function NPCTracker:Add(model)
    if not model or self.Lookup[model] then return end
    if not self:_isNPCModel(model) then return end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")

    if not rootPart then return end

    local entry = {
        Model = model,
        Humanoid = humanoid,
        RootPart = rootPart,
        BossType = "humanoid",
        BossProfile = nil,
        LowerName = string_lower(model.Name)
    }

    if self.BossClassifier then
        local bossType, height = self.BossClassifier.Classify(model)
        entry.BossType = bossType
        entry.BossProfile = self.BossClassifier.GetProfile(bossType)
        entry.ModelHeight = height
    end

    table.insert(self.Entries, entry)
    self.Lookup[model] = entry
end

function NPCTracker:Remove(model)
    local entry = self.Lookup[model]
    if not entry then return end

    local index = table.find(self.Entries, entry)
    if index then
        local lastIndex = #self.Entries
        self.Entries[index] = self.Entries[lastIndex]
        self.Entries[lastIndex] = nil
    end
    
    self.Lookup[model] = nil

    if self.CurrentTargetEntry and self.CurrentTargetEntry.Model == model then
        self.CurrentTargetEntry = nil
    end
end

function NPCTracker:IsTargetPlayer(entry)
    if not entry or not entry.Model then return false end
    return Players:GetPlayerFromCharacter(entry.Model) ~= nil
end

function NPCTracker:GetTargetPart(entry)
    if not entry then return nil end
    local model = entry.Model
    if not model or not model.Parent then return nil end

    local profile = entry.BossProfile
    if profile and profile.PreferredPart then
        local preferred = model:FindFirstChild(profile.PreferredPart)
        if preferred then return preferred end
    end

    local partName = self.Options.TargetPart
    local target = model:FindFirstChild(partName)

    if not target then
        if partName == "Torso" then
            target = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
        elseif partName == "Head" then
            target = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        end
    end

    return target or entry.RootPart
end

function NPCTracker:RescanFolder()
    table.clear(self.Entries)
    table.clear(self.Lookup)
    self.CurrentTargetEntry = nil

    for _, obj in ipairs(self.TargetFolder:GetChildren()) do
        if obj:IsA("Model") then self:Add(obj) end
    end
end

function NPCTracker:Init()
    -- Scan folder and subfolders (if not workspace)
    for _, obj in ipairs(self.TargetFolder:GetChildren()) do
        if obj:IsA("Model") then self:Add(obj) end
    end

    table.insert(self._connections, self.TargetFolder.ChildAdded:Connect(function(child)
        task.wait(0.2)
        if child:IsA("Model") then self:Add(child) end
    end))

    table.insert(self._connections, self.TargetFolder.ChildRemoved:Connect(function(child)
        self:Remove(child)
    end))

    -- Fallback safety check (throttled)
    task.spawn(function()
        while task.wait(5) do
            for _, obj in ipairs(self.TargetFolder:GetChildren()) do
                if obj:IsA("Model") and not self.Lookup[obj] then
                    self:Add(obj)
                end
            end
        end
    end)
end

function NPCTracker:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    table.clear(self._connections)
    table.clear(self.Entries)
    table.clear(self.Lookup)
end

return NPCTracker
