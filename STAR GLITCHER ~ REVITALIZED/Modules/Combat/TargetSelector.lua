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
    self._destroyed = false
    return self
end

function TargetSelector:Init()
    self._destroyed = false
end

function TargetSelector:_getMethod()
    local method = tostring(self.Options.TargetingMethod or "FOV")
    if method == "Distance" or method == "Deadlock" then
        return method
    end
    return "FOV"
end

function TargetSelector:_isEntryValid(entry, localCharacter, originPos, maxDistance)
    if not entry or not entry.Model or entry.Model == localCharacter then
        return nil, nil, nil
    end

    local part = self.Tracker:GetTargetPart(entry)
    if not part or (localCharacter and part:IsDescendantOf(localCharacter)) then
        return nil, nil, nil
    end

    local toTarget = part.Position - originPos
    local distance = toTarget.Magnitude
    if distance > maxDistance then
        return nil, nil, nil
    end

    return part, distance, toTarget
end

function TargetSelector:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
    local part, distance = self:_isEntryValid(entry, localCharacter, originPos, maxDistance)
    if not part then
        return nil, nil
    end

    if method == "Distance" then
        return distance, part
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
    if self._destroyed then
        return nil
    end

    local bestTarget = nil
    local localCharacter = Players.LocalPlayer.Character
    local mouseX = mousePos.X
    local mouseY = mousePos.Y
    local maxDistance = self.Options.MaxDistance or 2500
    local method = self:_getMethod()
    local fov = self.Options.FOV or 150
    local bestScore = method == "Distance" and maxDistance or (fov * fov)

    if method == "Deadlock" and preferredEntry then
        local lockedPart = self:_isEntryValid(preferredEntry, localCharacter, originPos, maxDistance)
        if lockedPart then
            return preferredEntry
        end
    end

    -- Keep the current target when it is still meaningfully valid to avoid
    -- rescoring churn and target thrash in crowded scenes.
    if preferredEntry then
        local preferredScore = self:_scoreEntry(preferredEntry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
        if preferredScore and preferredScore <= (bestScore * self._stickyBias) then
            bestTarget = preferredEntry
            bestScore = preferredScore
        end
    end

    local entries = self.Tracker:GetTargets()
    for i = 1, #entries do
        local entry = entries[i]
        if entry ~= preferredEntry then
            local score = self:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
            if score and score < bestScore then
                bestScore = score
                bestTarget = entry
            end
        end
    end

    return bestTarget
end

function TargetSelector:Destroy()
    self._destroyed = true
end

return TargetSelector
