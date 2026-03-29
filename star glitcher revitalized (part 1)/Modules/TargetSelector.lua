--[[
    TargetSelector.lua — Target Selection Class
    Quản lý logic chọn mục tiêu gần nhất, scoring, grace period.
]]

local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local TargetSelector = {}
TargetSelector.__index = TargetSelector

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
    local closestScore = math.huge
    local closestEntry = nil
    local now = os.clock()
    local entries = self.NPCTracker.Entries
    local currentTarget = self.NPCTracker.CurrentTargetEntry
    local Camera = Workspace.CurrentCamera

    for i = #entries, 1, -1 do
        local entry = entries[i]
        local model = entry.Model
        local humanoid = entry.Humanoid
        local rootPart = entry.RootPart

        if not model or not model.Parent then
            self.NPCTracker:Remove(model)
        elseif humanoid and rootPart and rootPart.Parent then
            if humanoid.Health > 0 then
                local targetPart = self.NPCTracker:GetTargetPart(entry)
                if targetPart and targetPart.Parent then
                    local isCurrentTarget = currentTarget and entry.Model == currentTarget.Model
                    local targetPosition = self.Prediction:GetSelectionTargetPosition(cameraPosition, targetPart, entry, isCurrentTarget)
                    local worldDistance = (targetPosition - cameraPosition).Magnitude
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPosition)

                    if onScreen and worldDistance <= self.Options.MaxDistance then
                        local dx = screenPos.X - mousePos.X
                        local dy = screenPos.Y - mousePos.Y
                        local screenDistance = math.sqrt(dx * dx + dy * dy)

                        if screenDistance <= self.Options.FOV then
                            local maxHP = humanoid.MaxHealth
                            local hpWeight = 1 + (math.log10(maxHP + 1) * 2)
                            local score = screenDistance / hpWeight

                            if isCurrentTarget then
                                score = score * 0.2
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

    -- Grace Period
    if closestEntry then
        self.LastValidTargetTime = now
        self.LastValidTargetEntry = closestEntry
        return closestEntry
    end

    if self.LastValidTargetEntry
        and self.LastValidTargetEntry.Model
        and self.LastValidTargetEntry.Model.Parent
        and self.LastValidTargetEntry.Humanoid
        and self.LastValidTargetEntry.Humanoid.Health > 0
        and (now - self.LastValidTargetTime) < self.C.GRACE_PERIOD then
        return self.LastValidTargetEntry
    end

    self.LastValidTargetEntry = nil
    return nil
end

return TargetSelector
