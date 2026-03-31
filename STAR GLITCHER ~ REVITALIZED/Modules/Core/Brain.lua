--[[
    Brain.lua — Central Nervous System (Orchestrator)
    Analogy: The Spinal Cord/CNS connecting all Brain Lobes.
    Job: Coordinates input, thought, and motor execution.
    Neural Pattern: v6.1 Orthogonal Scientific Overhaul.
]]

local BrainFolder = "Modules/Core/Brain/"

local Brain = {}
Brain.__index = Brain

function Brain.new(config, modules, loader)
    local self = setmetatable({}, Brain)
    self.Options = config.Options
    self.Config = config
    
    -- Load Human-like Lobes
    local Parietal   = loader(BrainFolder.."Parietal.lua")
    local Temporal   = loader(BrainFolder.."Temporal.lua")
    local Occipital  = loader(BrainFolder.."Occipital.lua")
    local Frontal    = loader(BrainFolder.."Frontal.lua")
    
    -- Instantiate Lobes
    self.Parietal   = Parietal.new(modules.Input, modules.Tracker)
    self.Temporal   = Temporal.new(modules.Selector, modules.Predictor)
    self.Occipital  = Occipital.new(modules.Visuals)
    self.Frontal    = Frontal.new(modules.Aimbot, modules.SilentAim, self.Options)
    
    return self
end

function Brain:Scan(mousePos, originPos)
    local shouldAssist, _ = self.Parietal:Process()
    if shouldAssist then
        -- Sensory acquisition
        local target = self.Temporal:Scan(mousePos, originPos)
        self.Parietal.Tracker.CurrentTargetEntry = target
    else
        self.Parietal.Tracker.CurrentTargetEntry = nil
    end
end

function Brain:Update(dt, mousePos, camCFrame)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local entry = self.Parietal.Tracker.CurrentTargetEntry

    if not shouldAssist or not entry then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    -- 1. COGNITIVE PROCESSING (Temporal Lobe - Logic Layer)
    -- This resolves the "Thin Wrapper" finding by centralizing thought logic
    local targetPart, targetPos = self.Temporal:Process(camCFrame.Position, dt)
    
    if not targetPart or not targetPos then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    -- 2. VISUAL PERCEPTION (Occipital Lobe - Presentation Layer)
    local sPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    self.Occipital:Process(mousePos, sPos, targetPart, onScreen)

    -- 3. MOTOR EXECUTION (Frontal Lobe - Action Layer)
    self.Frontal:Execute(targetPos, targetPart, entry, dt)
end

function Brain:Destroy()
    -- Logic to clean up everything
end

return Brain
