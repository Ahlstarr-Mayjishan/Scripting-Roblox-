--[[
    GarbageCollector.lua — Memory & Workspace Optimization v1.0
    Job: Proactive cleanup of visual debris, effects, and orphaned instances.
    Analogy: The Lymphatic System (Cleaning up cellular debris).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local GarbageCollector = {}
GarbageCollector.__index = GarbageCollector

function GarbageCollector.new(options, resourceManager)
    local self = setmetatable({}, GarbageCollector)
    self.Options = options
    self.ResourceManager = resourceManager
    self.Connection = nil
    self._lastClean = 0
    self._cleanInterval = 60 -- Default to every 60 seconds
    self._queued = {}
    self._queueSize = 0
    self._scanIndex = 1
    self._scanList = nil
    self._scanBatchSize = 80
    self._destroyBudget = 10
    self._collectStepSize = 24
    self._manualBoostUntil = 0
    self._frameBudget = 0.0012
    self.Status = "Idle"
    return self
end

local DEBRIS_TAGS = {
    "Debris", "Effect", "Projectile", "Shell", "Bullet", 
    "Particle", "Emitter", "Orb", "Trail", "Beam", "Visual"
}

function GarbageCollector:_getPlayerPosition()
    local char = LocalPlayer and LocalPlayer.Character
    local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    return root and root.Position or nil
end

function GarbageCollector:_isDebrisCandidate(instance, playerPos)
    if not instance or not instance.Parent then
        return false
    end

    if not (instance:IsA("BasePart") or instance:IsA("Model") or instance:IsA("Folder")) then
        return false
    end

    local name = instance.Name:lower()
    local matched = false
    for _, tag in ipairs(DEBRIS_TAGS) do
        if name:find(tag:lower(), 1, true) then
            matched = true
            break
        end
    end
    if not matched or instance:FindFirstChildOfClass("Humanoid") then
        return false
    end

    if not playerPos then
        return true
    end

    local ok, position = pcall(function()
        return instance:GetPivot().Position
    end)
    if not ok then
        return false
    end

    return (position - playerPos).Magnitude > 300
end

function GarbageCollector:_queueInstance(instance)
    if instance:GetAttribute("__SG_QueuedForCleanup") then
        return false
    end

    instance:SetAttribute("__SG_QueuedForCleanup", true)
    self._queueSize = self._queueSize + 1
    self._queued[self._queueSize] = instance
    return true
end

function GarbageCollector:_beginScan()
    self._scanList = Workspace:GetChildren()
    self._scanIndex = 1
    self.Status = "Scanning Debris"
end

function GarbageCollector:_processScan(batchSize)
    local scanList = self._scanList
    if not scanList then
        return 0, true
    end

    local playerPos = self:_getPlayerPosition()
    local queuedCount = 0
    local endIndex = math.min(self._scanIndex + batchSize - 1, #scanList)

    for i = self._scanIndex, endIndex do
        local instance = scanList[i]
        if self:_isDebrisCandidate(instance, playerPos) and self:_queueInstance(instance) then
            queuedCount = queuedCount + 1
        end
    end

    self._scanIndex = endIndex + 1
    local done = self._scanIndex > #scanList
    if done then
        self._scanList = nil
        self._scanIndex = 1
    end

    return queuedCount, done
end

function GarbageCollector:_drainQueue(destroyBudget, gcStepSize)
    local destroyed = 0
    local processed = 0
    local startTime = os.clock()

    while self._queueSize > 0 and processed < destroyBudget do
        if (os.clock() - startTime) >= self._frameBudget then
            break
        end

        local instance = self._queued[self._queueSize]
        self._queued[self._queueSize] = nil
        self._queueSize = self._queueSize - 1
        processed = processed + 1

        if instance and instance.Parent then
            if self.ResourceManager then
                self.ResourceManager:DeferCleanup(function()
                    if instance and instance.Parent then
                        instance:SetAttribute("__SG_QueuedForCleanup", nil)
                        instance:Destroy()
                    end
                end)
            else
                pcall(function()
                    instance:SetAttribute("__SG_QueuedForCleanup", nil)
                    instance:Destroy()
                end)
                destroyed = destroyed + 1
            end
        end
    end

    if destroyed > 0 and not self.ResourceManager then
        -- collectgarbage("step", gcStepSize) -- Restricted in some environments
    end

    return destroyed
end

function GarbageCollector:_stepCleanup()
    local now = os.clock()
    local manualBoost = now < self._manualBoostUntil
    local scanBatchSize = manualBoost and (self._scanBatchSize * 2) or self._scanBatchSize
    local destroyBudget = manualBoost and (self._destroyBudget * 2) or self._destroyBudget
    local gcStepSize = manualBoost and (self._collectStepSize * 2) or self._collectStepSize

    if not self._scanList and self._queueSize == 0 then
        if now - self._lastClean < self._cleanInterval then
            self.Status = "Idle"
            return
        end
        self._lastClean = now
        self:_beginScan()
    end

    local queuedCount = 0
    local scanDone = true
    if self._scanList then
        queuedCount, scanDone = self:_processScan(scanBatchSize)
    end

    local destroyed = self:_drainQueue(destroyBudget, gcStepSize)

    if self._scanList then
        self.Status = string.format("Scanning (%d queued)", self._queueSize)
    elseif self._queueSize > 0 then
        self.Status = string.format("Cleaning (%d left)", self._queueSize)
    elseif destroyed > 0 or queuedCount > 0 or not scanDone then
        self.Status = "Cleanup Settled"
    else
        self.Status = "Idle"
    end
end

function GarbageCollector:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.AutoCleanEnabled then return end

        self:_stepCleanup()
    end)
end

function GarbageCollector:Clean()
    self._manualBoostUntil = os.clock() + 3
    if self.ResourceManager then
        self.ResourceManager:Boost(2.5)
    end
    if not self._scanList then
        self._lastClean = 0
        self:_beginScan()
    end

    local queued = 0
    local destroyed = 0
    for _ = 1, 4 do
        local q = 0
        if self._scanList then
            q = select(1, self:_processScan(self._scanBatchSize * 2))
        end
        queued = queued + q
        destroyed = destroyed + self:_drainQueue(self._destroyBudget, self._collectStepSize)

        if not self._scanList and self._queueSize == 0 then
            break
        end
    end

    if self.ResourceManager and self.ResourceManager:GetPendingCount() > 0 then
        self.Status = string.format(
            "Smart Cleanup (%d local / %d deferred)",
            self._queueSize,
            self.ResourceManager:GetPendingCount()
        )
    else
        self.Status = self._queueSize > 0 and string.format("Cleaning (%d left)", self._queueSize) or "Cleanup Settled"
    end
    return destroyed, queued, self._queueSize
end

function GarbageCollector:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    for i = 1, self._queueSize do
        local instance = self._queued[i]
        if instance and instance.Parent then
            pcall(function()
                instance:SetAttribute("__SG_QueuedForCleanup", nil)
            end)
        end
    end
end

return GarbageCollector
