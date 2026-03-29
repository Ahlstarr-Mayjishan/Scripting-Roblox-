--[[
    NPCTracker.lua — NPC/Entity Tracking Class
    Quản lý quét, thêm, xóa NPC/Boss trong folder Entities.
    Hỗ trợ cả Player tracking khi bật PvP mode.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local NPCTracker = {}
NPCTracker.__index = NPCTracker

function NPCTracker.new(config)
    local self = setmetatable({}, NPCTracker)
    self.Config = config
    self.Options = config.Options
    self.Blacklist = config.Blacklist

    self.TargetFolder = Workspace:WaitForChild("Entities", 10) or Workspace
    self.Entries = {}     -- Array: {Model, Humanoid, RootPart}
    self.Lookup = {}      -- Map: Model → Entry
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

    if not model:IsDescendantOf(self.TargetFolder) then
        return false
    end

    local modelName = string.lower(model.Name)
    for _, keyword in ipairs(self.Blacklist) do
        if modelName:find(keyword, 1, true) then
            return false
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return true
    end

    local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if rootPart then
        return true
    end

    return false
end

-- ═══ PUBLIC API ═══

function NPCTracker:Add(model)
    if not model or not model.Parent or self.Lookup[model] then
        return
    end

    if not self:_isNPCModel(model) then
        return
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Head")
        or model:FindFirstChildWhichIsA("BasePart")

    if not rootPart then
        return
    end

    local entry = {
        Model = model,
        Humanoid = humanoid,
        RootPart = rootPart,
    }

    table.insert(self.Entries, entry)
    self.Lookup[model] = entry

    local connection
    connection = model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            connection:Disconnect()
            self:Remove(model)
        end
    end)
    table.insert(self._connections, connection)
end

function NPCTracker:Remove(model)
    local entry = self.Lookup[model]
    if not entry then
        return
    end

    local index = table.find(self.Entries, entry)
    local lastIndex = #self.Entries
    local lastEntry = self.Entries[lastIndex]

    self.Entries[index] = lastEntry
    self.Entries[lastIndex] = nil
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
        if obj:IsA("Model") then
            self:Add(obj)
        end
    end
end

function NPCTracker:Init()
    -- 1. Quét những con đang đứng sẵn
    for _, obj in ipairs(self.TargetFolder:GetChildren()) do
        if obj:IsA("Model") then self:Add(obj) end
    end

    -- 2. Nghe ngóng những con mới spawn
    local conn = self.TargetFolder.ChildAdded:Connect(function(child)
        task.wait(0.1)
        if child:IsA("Model") then self:Add(child) end
    end)
    table.insert(self._connections, conn)

    -- 3. Quét lại định kỳ phòng sót
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
