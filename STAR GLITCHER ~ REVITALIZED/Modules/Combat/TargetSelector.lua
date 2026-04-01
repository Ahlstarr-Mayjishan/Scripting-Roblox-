--[[
    TargetSelector.lua - OOP Target Selection Class
    Logic for finding the most optimal target based on distance and FOV.
    Optimized for crosshair proximity with lightweight sticky targeting.
]]

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")

local TargetSelector = {}
TargetSelector.__index = TargetSelector

function TargetSelector.new(config, tracker, predictor)
    local self = setmetatable({}, TargetSelector)
    self.Options = config.Options
    self.Tracker = tracker
    self.Predictor = predictor
    self._stickyBias = 1.12
    return self
end

function TargetSelector:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance)
    if not entry or not entry.Model or entry.Model == localCharacter then
        return nil, nil
    end

    local part = self.Tracker:GetTargetPart(entry)
    if not part or (localCharacter and part:IsDescendantOf(localCharacter)) then
        return nil, nil
    end

    local toTarget = part.Position - originPos
    if toTarget.Magnitude > maxDistance then
        return nil, nil
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return nil, nil
    end

    local dx = screenPos.X - mouseX
    local dy = screenPos.Y - mouseY
    return (dx * dx) + (dy * dy), part
end

function TargetSelector:GetClosestTarget(mousePos, originPos, preferredEntry)
    local bestTarget = nil
    local localCharacter = Players.LocalPlayer.Character
    local mouseX = mousePos.X
    local mouseY = mousePos.Y
    local maxDistance = self.Options.MaxDistance or 2500
    local fov = self.Options.FOV or 150
    local bestScore = fov * fov

    -- Keep the current target when it is still meaningfully valid to avoid
    -- rescoring churn and target thrash in crowded scenes.
    if preferredEntry then
        local preferredScore = self:_scoreEntry(preferredEntry, localCharacter, mouseX, mouseY, originPos, maxDistance)
        if preferredScore and preferredScore <= (bestScore * self._stickyBias) then
            bestTarget = preferredEntry
            bestScore = preferredScore
        end
    end

    local entries = self.Tracker:GetTargets()
    for i = 1, #entries do
        local entry = entries[i]
        if entry ~= preferredEntry then
            local score = self:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance)
            if score and score < bestScore then
                bestScore = score
                bestTarget = entry
            end
        end
    end

    return bestTarget
end

return TargetSelector
