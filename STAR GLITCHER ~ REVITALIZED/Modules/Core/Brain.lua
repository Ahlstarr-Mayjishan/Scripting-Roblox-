--[[
    Brain.lua - Central Nervous System (Orchestrator)
    Analogy: The Spinal Cord/CNS connecting all Brain Lobes.
    Job: Coordinates input, thought, and motor execution.
]]

local BrainFolder = "Modules/Core/Brain/"
local clock = os.clock

local Brain = {}
Brain.__index = Brain

function Brain.new(config, modules, loader)
    local self = setmetatable({}, Brain)
    self.Options = config.Options
    self.Config = config

    local Parietal = loader(BrainFolder .. "Parietal.lua")
    local Temporal = loader(BrainFolder .. "Temporal.lua")
    local Occipital = loader(BrainFolder .. "Occipital.lua")
    local Frontal = loader(BrainFolder .. "Frontal.lua")

    self.Parietal = Parietal.new(modules.Input, modules.Tracker)
    self.Temporal = Temporal.new(modules.Selector, modules.Predictor)
    self.Occipital = Occipital.new(modules.Visuals)
    self.Frontal = Frontal.new(modules.Aimbot, modules.SilentAim, self.Options)

    self._lastScan = 0
    self._scanInterval = 1 / 30
    return self
end

function Brain:_isDeadlockMode()
    return tostring(self.Options.TargetingMethod or "FOV") == "Deadlock"
end

function Brain:Scan(mousePos, originPos)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local deadlockMode = self:_isDeadlockMode()
    if not shouldAssist then
        if deadlockMode and self.Options.AssistMode ~= "Off" then
            return
        end
        self.Parietal.Tracker.CurrentTargetEntry = nil
        return
    end

    local now = clock()
    if (now - self._lastScan) < self._scanInterval then
        return
    end
    self._lastScan = now

    local target = self.Temporal:Scan(mousePos, originPos)
    self.Parietal.Tracker.CurrentTargetEntry = target
end

function Brain:Update(dt, mousePos, camCFrame)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local entry = self.Parietal.Tracker.CurrentTargetEntry
    local maintainDeadlock = self:_isDeadlockMode() and self.Options.AssistMode ~= "Off" and entry ~= nil
    local shouldTrack = shouldAssist or maintainDeadlock

    if not shouldTrack or not entry then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local targetPart, targetPos = self.Temporal:Process(camCFrame.Position, dt)

    if not targetPart or not targetPos then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local sPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    self.Occipital:Process(mousePos, sPos, targetPart, onScreen)
    self.Frontal:Execute(targetPos, targetPart, entry, dt)
end

function Brain:Destroy()
    local lobes = {
        self.Parietal,
        self.Temporal,
        self.Occipital,
        self.Frontal,
    }

    for _, lobe in ipairs(lobes) do
        if lobe and lobe.Destroy then
            pcall(function()
                lobe:Destroy()
            end)
        end
    end

    self.Parietal = nil
    self.Temporal = nil
    self.Occipital = nil
    self.Frontal = nil
end

return Brain
