--[[
    SilentAim.lua - Universal silent aim hook class.
    Hooks mouse/raycast reads, but only during a short shot window so
    non-combat systems like form switching are left alone.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SilentAim = {}
SilentAim.__index = SilentAim

local SHOT_HOOK_WINDOW = 0.18
local ATTACK_NAME_TOKENS = {"shoot", "fire", "attack", "spell", "ability", "magic", "cast"}
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
    self.LastShotRequest = 0
    return self
end

function SilentAim:MarkShotRequest()
    self.LastShotRequest = os.clock()
end

function SilentAim:CanRedirect()
    return self.Active
        and self.TargetPosCache ~= nil
        and self.TargetPartCache ~= nil
        and (os.clock() - self.LastShotRequest) <= SHOT_HOOK_WINDOW
end

function SilentAim:Init()
    if not hookmetamethod then
        return
    end

    local selfRef = self
    local synapse = self.Synapse
    local localPlayer = Players.LocalPlayer

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            selfRef:MarkShotRequest()
        end
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        if (index == "Hit" or index == "Target" or index == "UnitRay")
            and not checkcaller()
            and selfRef:CanRedirect()
            and typeof(inst) == "Instance"
            and inst:IsA("Mouse") then
            if index == "Hit" then
                local camPos = Workspace.CurrentCamera.CFrame.Position
                local lookDir = (selfRef.TargetPosCache - camPos).Unit
                return CFrame.lookAt(selfRef.TargetPosCache, selfRef.TargetPosCache + lookDir)
            elseif index == "Target" then
                return selfRef.TargetPartCache
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

        if not checkcaller() then
            if selfRef:CanRedirect() and method == "Raycast" and inst == Workspace then
                local origin = args[1]
                local direction = args[2]
                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                    args[2] = (selfRef.TargetPosCache - origin).Unit * direction.Magnitude
                    return oldNamecall(inst, unpack(args, 1, args.n))
                end
            end

            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = typeof(inst) == "Instance" and string.lower(inst.Name) or string.lower(tostring(inst))

                if containsToken(remoteName, ATTACK_NAME_TOKENS) then
                    selfRef:MarkShotRequest()

                    if selfRef.Active and selfRef.CurrentTargetEntry then
                        local muzzlePos = localPlayer.Character and localPlayer.Character:GetPivot().Position or Vector3.zero
                        synapse.fire("ShotFired", selfRef.CurrentTargetEntry.Model, os.clock(), muzzlePos)
                    end
                end

                if containsToken(remoteName, DAMAGE_NAME_TOKENS) and selfRef.CurrentTargetEntry then
                    local targetModel = selfRef.CurrentTargetEntry.Model
                    for i = 1, args.n do
                        local arg = args[i]
                        if typeof(arg) == "Instance" and (arg == targetModel or arg:IsDescendantOf(targetModel)) then
                            synapse.fire("DamageApplied", targetModel, os.clock())
                            break
                        end
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
