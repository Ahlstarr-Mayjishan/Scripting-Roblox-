--[[
    SilentAim.lua - Universal silent aim hook class.
    Keeps redirection scoped to brief left-click combat windows and avoids
    global Raycast hijacking so non-combat keybinds keep working.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SilentAim = {}
SilentAim.__index = SilentAim

local CLICK_REDIRECT_WINDOW = 0.08
local DAMAGE_NAME_TOKENS = {"hit", "damage"}

local function containsToken(value, tokens)
    if not value or value == "" then
        return false
    end

    for _, token in ipairs(tokens) do
        if value:find(token, 1, true) then
            return true
        end
    end

    return false
end

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
        if (index == "Hit" or index == "UnitRay")
            and not checkcaller()
            and selfRef:CanRedirect()
            and typeof(inst) == "Instance"
            and inst:IsA("Mouse") then
            if index == "Hit" then
                local camPos = Workspace.CurrentCamera.CFrame.Position
                local lookDir = (selfRef.TargetPosCache - camPos).Unit
                return CFrame.lookAt(selfRef.TargetPosCache, selfRef.TargetPosCache + lookDir)
            elseif index == "UnitRay" then
                local camPos = Workspace.CurrentCamera.CFrame.Position
                return Ray.new(camPos, (selfRef.TargetPosCache - camPos).Unit)
            end
        end

        return oldIndex(inst, index)
    end))

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)

        if not checkcaller() and (method == "FireServer" or method == "InvokeServer") and selfRef.CurrentTargetEntry then
            local remoteName = typeof(inst) == "Instance" and string.lower(inst.Name) or string.lower(tostring(inst))
            if containsToken(remoteName, DAMAGE_NAME_TOKENS) then
                local targetModel = selfRef.CurrentTargetEntry.Model
                for i = 1, args.n do
                    local arg = args[i]
                    if typeof(arg) == "Instance" and (arg == targetModel or arg:IsDescendantOf(targetModel)) then
                        selfRef.Synapse.fire("DamageApplied", targetModel, os.clock())
                        break
                    end
                end
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
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
