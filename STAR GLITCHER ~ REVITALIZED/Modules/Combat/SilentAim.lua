--[[
    SilentAim.lua - Universal silent aim hook class.
    Keeps redirection scoped to brief left-click combat windows and avoids
    broad input interception so non-combat keybinds keep working.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SilentAim = {}
SilentAim.__index = SilentAim

local CLICK_REDIRECT_WINDOW = 0.08

function SilentAim.new(config, synapse)
    local self = setmetatable({}, SilentAim)
    self.Config = config
    self.Options = config.Options
    self.Synapse = synapse
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self.LastClickTime = 0
    return self
end

function SilentAim:MarkClick()
    self.LastClickTime = os.clock()

    if self.Active and self.CurrentTargetEntry then
        local muzzlePos = Players.LocalPlayer.Character and Players.LocalPlayer.Character:GetPivot().Position or Vector3.zero
        self.Synapse.fire("ShotFired", self.CurrentTargetEntry.Model, self.LastClickTime, muzzlePos)
    end
end

function SilentAim:CanRedirect()
    if not self.Active or not self.TargetPosCache or not self.TargetPartCache then
        return false
    end

    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        return true
    end

    return (os.clock() - self.LastClickTime) <= CLICK_REDIRECT_WINDOW
end

function SilentAim:Init()
    if not hookmetamethod then
        return
    end

    local selfRef = self

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            selfRef:MarkClick()
        end
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        if index == "Hit"
            and not checkcaller()
            and selfRef:CanRedirect()
            and typeof(inst) == "Instance"
            and inst:IsA("Mouse") then
            local camPos = Workspace.CurrentCamera.CFrame.Position
            local lookDir = (selfRef.TargetPosCache - camPos).Unit
            return CFrame.lookAt(selfRef.TargetPosCache, selfRef.TargetPosCache + lookDir)
        end

        return oldIndex(inst, index)
    end))
end

function SilentAim:SetState(active, targetPart, targetPos, currentEntry, dt)
    local localCharacter = Players.LocalPlayer.Character
    if localCharacter then
        local targetModel = currentEntry and currentEntry.Model
        if targetModel == localCharacter or (targetPart and targetPart:IsDescendantOf(localCharacter)) then
            self:Clear()
            return
        end
    end

    self.Active = active
    self.TargetPartCache = targetPart
    self.CurrentTargetEntry = currentEntry
    self.TargetPosCache = targetPos
end

function SilentAim:Clear()
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
end

return SilentAim
