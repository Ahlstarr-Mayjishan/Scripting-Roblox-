--[[
    TargetSelector.lua — Target Selection Class
    Quản lý logic chọn mục tiêu gần nhất, scoring, grace period.
]]

local Workspace = game:GetService("Workspace")

local TargetSelector = {}
TargetSelector.__index = TargetSelector

-- Localize functions for PERF
local math_sqrt = math.sqrt
local math_log10 = math.log10
local math_huge = math.huge
local os_clock = os.clock
local Vector2_new = Vector2.new

function TargetSelector.new(config, npcTracker, predictionEngine)
    local self = setmetatable({}, TargetSelector)
    self.Config = config
    self.Options = config.Options
    self.C = config.Prediction
    self.NPCTracker = npcTracker
    self.Prediction = predictionEngine

    self.LastValidTargetTime = 0
    self.LastValidTargetEntry = nil

    return self
end

function TargetSelector:GetClosestTarget(mousePos, cameraPosition)
    local closestScore = math_huge
    local closestEntry = nil
    
    local now = os_clock()
    local entries = self.NPCTracker.Entries
    local currentTarget = self.NPCTracker.CurrentTargetEntry
    local Camera = Workspace.CurrentCamera
    
    local maxDistSq = self.Options.MaxDistance * self.Options.MaxDistance
    local fovLimit = self.Options.FOV
    local fovLimitSq = fovLimit * fovLimit

    for i = #entries, 1, -1 do
        local entry = entries[i]
        local model = entry.Model
        local humanoid = entry.Humanoid
        local rootPart = entry.RootPart

        if not model or not model.Parent then
            self.NPCTracker:Remove(model)
        else
            if humanoid and rootPart and humanoid.Health > 0 then
                local targetPart = self.NPCTracker:GetTargetPart(entry)
                if targetPart and targetPart.Parent then
                    local isCurrentTarget = (currentTarget and entry.Model == currentTarget.Model)
                    local targetPosition = self.Prediction:GetSelectionTargetPosition(cameraPosition, targetPart, entry, isCurrentTarget)
                    
                    -- PERF: Use MagnitudeSquared instead of Magnitude
                    local offset = targetPosition - cameraPosition
                    local worldDistSq = offset.X*offset.X + offset.Y*offset.Y + offset.Z*offset.Z
                    
                    if worldDistSq <= maxDistSq then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPosition)
                        
                        if onScreen then
                            local dx = screenPos.X - mousePos.X
                            local dy = screenPos.Y - mousePos.Y
                            local screenDistSq = dx*dx + dy*dy

                            if screenDistSq <= fovLimitSq then
                                -- Optimization: Simpler score weights
                                local hpFactor = 1 + (math_log10(humanoid.MaxHealth + 1) * 2)
                                local score = math_sqrt(screenDistSq) / hpFactor

                                if isCurrentTarget then
                                    score = score * 0.25 -- Sticky target bonus
                                end

                                if score < closestScore then
                                    closestScore = score
                                    closestEntry = entry
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if closestEntry then
        self.LastValidTargetTime = now
        self.LastValidTargetEntry = closestEntry
        return closestEntry
    end

    -- Grace Period logic
    local last = self.LastValidTargetEntry
    if last and last.Model and last.Model.Parent and last.Humanoid and last.Humanoid.Health > 0 then
        if (now - self.LastValidTargetTime) < self.C.GRACE_PERIOD then
            return last
        end
    end

    self.LastValidTargetEntry = nil
    return nil
end

return TargetSelector
