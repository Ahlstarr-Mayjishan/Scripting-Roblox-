local RunService = game:GetService("RunService")

local ResourceManager = {}
ResourceManager.__index = ResourceManager

local DEFAULT_FRAME_BUDGET = 0.0008
local DEFAULT_GC_STEP = 16

function ResourceManager.new(options)
    local self = setmetatable({}, ResourceManager)
    self.Options = options
    self.Status = "Idle"
    self.Connection = nil
    self._trackedConnections = {}
    self._trackedObjects = {}
    self._cleanupQueue = {}
    self._queueHead = 1
    self._queueTail = 0
    self._frameBudget = DEFAULT_FRAME_BUDGET
    self._gcStep = DEFAULT_GC_STEP
    self._manualBoostUntil = 0
    self._lastHitch = 0
    return self
end

function ResourceManager:_pushJob(kind, payload)
    self._queueTail = self._queueTail + 1
    self._cleanupQueue[self._queueTail] = {
        Kind = kind,
        Payload = payload,
    }
end

function ResourceManager:_popJob()
    if self._queueHead > self._queueTail then
        return nil
    end

    local job = self._cleanupQueue[self._queueHead]
    self._cleanupQueue[self._queueHead] = nil
    self._queueHead = self._queueHead + 1

    if self._queueHead > self._queueTail then
        self._queueHead = 1
        self._queueTail = 0
    end

    return job
end

function ResourceManager:GetPendingCount()
    return math.max(0, self._queueTail - self._queueHead + 1)
end

function ResourceManager:TrackConnection(connection)
    if connection then
        self._trackedConnections[#self._trackedConnections + 1] = connection
    end
    return connection
end

function ResourceManager:TrackObject(object)
    if object then
        self._trackedObjects[#self._trackedObjects + 1] = object
    end
    return object
end

function ResourceManager:DeferDestroy(object)
    if object then
        self:_pushJob("destroy", object)
    end
end

function ResourceManager:DeferDisconnect(connection)
    if connection then
        self:_pushJob("disconnect", connection)
    end
end

function ResourceManager:DeferCleanup(callback)
    if callback then
        self:_pushJob("callback", callback)
    end
end

function ResourceManager:_getBudget(dt)
    local budget = self._frameBudget
    local now = os.clock()
    local boosted = now < self._manualBoostUntil
    local pending = self:GetPendingCount()

    if boosted then
        budget = budget * 1.6
    end

    if pending >= 400 then
        budget = budget * 4
    elseif pending >= 150 then
        budget = budget * 2.5
    elseif pending >= 50 then
        budget = budget * 1.6
    end

    if dt and dt > (1 / 35) then
        self._lastHitch = now
        budget = budget * 0.45
    elseif (now - self._lastHitch) < 0.75 then
        budget = budget * 0.7
    end

    return budget
end

function ResourceManager:_runJob(job)
    if not job then
        return false
    end

    if job.Kind == "destroy" then
        local object = job.Payload
        if object and object.Destroy then
            pcall(function()
                object:Destroy()
            end)
        elseif object and object.Parent then
            pcall(function()
                object:Destroy()
            end)
        end
        return true
    end

    if job.Kind == "disconnect" then
        local connection = job.Payload
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
        return true
    end

    if job.Kind == "callback" then
        pcall(job.Payload)
        return true
    end

    return false
end

function ResourceManager:_step(dt)
    local budget = self:_getBudget(dt)
    local startTime = os.clock()
    local processed = 0

    while self:GetPendingCount() > 0 and (os.clock() - startTime) < budget do
        local job = self:_popJob()
        if not job then
            break
        end
        if self:_runJob(job) then
            processed = processed + 1
        end
    end

    if processed > 0 then
        -- collectgarbage("step", self._gcStep) -- Restricted in some environments
    end

    local pending = self:GetPendingCount()
    if pending > 0 then
        self.Status = string.format("Draining (%d pending)", pending)
    elseif processed > 0 then
        self.Status = "Settled"
    else
        self.Status = "Idle"
    end
end

function ResourceManager:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function(dt)
        if self.Options and self.Options.SmartCleanupEnabled == false then
            return
        end
        self:_step(dt)
    end)
end

function ResourceManager:ScheduleTrackedCleanup()
    for i = #self._trackedConnections, 1, -1 do
        local connection = self._trackedConnections[i]
        self._trackedConnections[i] = nil
        self:DeferDisconnect(connection)
    end

    for i = #self._trackedObjects, 1, -1 do
        local object = self._trackedObjects[i]
        self._trackedObjects[i] = nil
        self:DeferDestroy(object)
    end
end

function ResourceManager:Boost(duration)
    self._manualBoostUntil = math.max(self._manualBoostUntil, os.clock() + (duration or 1.5))
end

function ResourceManager:Flush(maxSeconds)
    local deadline = os.clock() + (maxSeconds or 1.25)
    self:Boost(maxSeconds or 1.25)

    while self:GetPendingCount() > 0 and os.clock() < deadline do
        self:_step(1 / 60)
        task.wait()
    end

    return self:GetPendingCount()
end

function ResourceManager:Destroy()
    self:ScheduleTrackedCleanup()
    self:Flush(0.2)

    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return ResourceManager
