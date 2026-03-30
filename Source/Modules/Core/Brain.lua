--[[
    Brain.lua — Central Nervous System (Orchestrator)
    Analogy: The Spinal Cord/CNS connecting all Brain Lobes.
    Script Job: Coordinates input, thought, and motor execution.
]]

local BrainFolder = "Modules/Core/Brain/"

local Brain = {}
Brain.__index = Brain

function Brain.new(config, modules, loader)
    local self = setmetatable({}, Brain)
    self.Options = config.Options
    self.Config = config
    
    -- Instantiate Human-like Lobes
    local Parietal  = loader(BrainFolder.."Parietal.lua")
    local Temporal   = loader(BrainFolder.."Temporal.lua")
    local Occipital  = loader(BrainFolder.."Occipital.lua")
    local Frontal    = loader(BrainFolder.."Frontal.lua")
    
    self.Parietal  = Parietal.new(modules.Input, modules.Tracker)
    self.Temporal   = Temporal.new(modules.Selector, modules.Predictor)
    self.Occipital  = Occipital.new(modules.Visuals)
    self.Frontal    = Frontal.new(modules.Aimbot, modules.SilentAim, self.Options)
    
    return self
end

function Brain:Scan(mousePos, originPos)
    local shouldAssist, _ = self.Parietal:Process()
    if shouldAssist then
        self.Parietal.Tracker.CurrentTargetEntry = self.Temporal:Scan(mousePos, originPos)
    end
end

function Brain:Update(dt, mousePos, camCFrame)
    local entry = self.Parietal.Tracker.CurrentTargetEntry
    local shouldAssist, _ = self.Parietal:Process()

    if not shouldAssist or not entry then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    -- 1. Sensory Info: Get Part
    local part = self.Parietal.Tracker:GetTargetPart(entry)
    if not part then return end

    -- 2. Temporal Processing: Calculate Prediction
    local targetPos = self.Temporal:Calculate(camCFrame.Position, part, entry, dt)
    
    -- 3. Visual Rendering
    local sPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    self.Occipital:Process(mousePos, sPos, part, onScreen)

    -- 4. Motor Execution
    self.Frontal:Execute(targetPos, part, entry, dt)
end

function Brain:Destroy()
    -- Logic to clean up everything
end

return Brain
