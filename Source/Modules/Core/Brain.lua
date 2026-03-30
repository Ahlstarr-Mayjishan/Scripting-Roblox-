--[[
    Brain.lua — Central Decision Engine (Orchestrator)
    The "Scientific Mind" of the script. 
    Manages the relationship between Targeting, Prediction, and Execution.
]]

local Brain = {}
Brain.__index = Brain

function Brain.new(config, modules)
    local self = setmetatable({}, Brain)
    self.Options = config.Options
    self.Config = config
    
    -- Injected dependencies
    self.Input = modules.Input
    self.Tracker = modules.Tracker
    self.Predictor = modules.Predictor
    self.Selector = modules.Selector
    
    -- Execution modules
    self.Aimbot = modules.Aimbot
    self.SilentAim = modules.SilentAim
    self.Visuals = modules.Visuals -- (FOVCircle, TargetDot, Highlight, Hitmarker)
    
    self.CurrentTarget = nil
    return self
end

function Brain:Update(dt, mousePos, camCFrame)
    local visuals = self.Visuals
    visuals.fov:Update(mousePos)
    visuals.dot:Set(nil, false)
    
    -- 1. Decision: Should we assist?
    if not self.Input:ShouldAssist() then
        self:Reset()
        return
    end

    -- 2. Targeting Logic
    -- Scan for closest target periodically (handled by Heartbeat in Main)
    local entry = self.Tracker.CurrentTargetEntry
    if not entry then
        self:Reset()
        return 
    end

    -- 3. Part Selection
    local part = self.Tracker:GetTargetPart(entry)
    if not part then return end

    -- 4. Scientific Prediction
    local targetPos = self.Predictor:Predict(camCFrame.Position, part, entry, dt)
    
    -- 5. Visual Feedback
    local sPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    visuals.dot:Set(sPos, onScreen)
    visuals.highlight:Set(part, true)

    -- 6. Action Execution Dispatch
    local mode = self.Options.AssistMode
    if mode == "Camera Lock" then
        self.SilentAim:Clear()
        self.Aimbot:Update(targetPos, self.Options.Smoothness)
    elseif mode == "Silent Aim" then
        self.SilentAim:SetState(true, part, targetPos, entry, dt)
    elseif mode == "Highlight Only" then
        self.SilentAim:Clear()
    else
        self:Reset()
    end
end

function Brain:Scan(mousePos, originPos)
    if self.Input:ShouldAssist() then
        self.Tracker.CurrentTargetEntry = self.Selector:GetClosestTarget(mousePos, originPos)
    end
end

function Brain:Reset()
    self.Tracker.CurrentTargetEntry = nil
    self.SilentAim:Clear()
    self.Visuals.highlight:Clear()
end

return Brain
