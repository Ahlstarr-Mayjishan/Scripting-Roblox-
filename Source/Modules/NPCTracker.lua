--[[
    NPCTracker.lua — Universal Entity Tracking
    Quản lý việc tìm kiếm và theo dõi BOSS/NPC trong toàn bộ Workspace.
    Đã tối ưu hóa để không bỏ lỡ mục tiêu dù chúng nằm trong folder lạ.
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

function NPCTracker:_isValidNPC(model)
    if not model or not model:IsA("Model") or self:_isLocalCharacter(model) then
        return false
    end

    -- Nếu là Player, chỉ track nếu bật PvP mode
    local player = Players:GetPlayerFromCharacter(model)
    if player then
        return self.Options.TargetPlayersToggle == true
    end

    -- Kiểm tra Blacklist (Tên rác: Bomb, Trap, Bullet...)
    local name = string_lower(model.Name)
    for _, word in ipairs(self.Blacklist) do
        if name:find(word, 1, true) then return false end
    end

    -- Phải có Humanoid hoặc RootPart
    return model:FindFirstChildOfClass("Humanoid") ~= nil or model:FindFirstChild("HumanoidRootPart") ~= nil
end

-- ═══ PUBLIC API ═══

function NPCTracker:Add(model)
    if not model or self.Lookup[model] then return end
    if not self:_isValidNPC(model) then return end

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
        local bType, height = self.BossClassifier.Classify(model)
        entry.BossType = bType
        entry.BossProfile = self.BossClassifier.GetProfile(bType)
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
        local last = #self.Entries
        self.Entries[index] = self.Entries[last]
        self.Entries[last] = nil
    end
    self.Lookup[model] = nil
end

function NPCTracker:IsTargetPlayer(entry)
    return entry and entry.Model and Players:GetPlayerFromCharacter(entry.Model) ~= nil
end

function NPCTracker:GetTargetPart(entry)
    if not entry or not entry.Model or not entry.Model.Parent then return nil end
    
    local profile = entry.BossProfile
    if profile and profile.PreferredPart then
        local p = entry.Model:FindFirstChild(profile.PreferredPart)
        if p then return p end
    end

    local target = entry.Model:FindFirstChild(self.Options.TargetPart)
    return target or entry.RootPart
end

-- Quét toàn bộ Workspace (Recursive) để tìm NPC
function NPCTracker:FullScan()
    table.clear(self.Entries)
    table.clear(self.Lookup)
    
    -- Chỉ quét các con của Workspace để tránh lag nặng
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            -- Giới hạn độ sâu để tránh quét vô tận
            self:Add(obj)
        end
    end
end

function NPCTracker:Init()
    -- Cú hích đầu tiên
    self:FullScan()

    -- Lắng nghe mọi Model mới xuất hiện trong Workspace (Bao gồm cả folder sâu)
    table.insert(self._connections, Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") then
            task.wait(0.3) -- Đợi load con của Model
            self:Add(desc)
        end
    end))

    table.insert(self._connections, Workspace.DescendantRemoving:Connect(function(desc)
        if desc:IsA("Model") then
            self:Remove(desc)
        end
    end))

    -- Heartbeat check cho các target đã chết hoặc nil
    task.spawn(function()
        while task.wait(5) do
            for i = #self.Entries, 1, -1 do
                local e = self.Entries[i]
                if not e.Model or not e.Model.Parent or (e.Humanoid and e.Humanoid.Health <= 0) then
                    self:Remove(e.Model)
                end
            end
        end
    end)
end

function NPCTracker:Destroy()
    for _, c in ipairs(self._connections) do c:Disconnect() end
    table.clear(self._connections)
    table.clear(self.Entries)
    table.clear(self.Lookup)
end

return NPCTracker
