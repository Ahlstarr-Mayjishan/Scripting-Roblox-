--[[
    SilentAim.lua — Universal Silent Aim Hook Class
    Hook metamethods cho Mouse.Hit, Mouse.Target, Camera ray functions.
    Siêu nhẹ, 0% Lag, dành riêng cho Magic/Beams.
]]

local Workspace = game:GetService("Workspace")

local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new(config, visuals)
    local self = setmetatable({}, SilentAim)
    self.Config = config
    self.Options = config.Options
    self.Visuals = visuals

    -- State shared with main loop
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil

    return self
end

function SilentAim:Init()
    if not hookmetamethod then
        warn("[SilentAim] hookmetamethod not available — Silent Aim disabled")
        return
    end

    local selfRef = self

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        if index == "Hit" or index == "Target" or index == "UnitRay" then
            if selfRef.Active and selfRef.TargetPosCache and selfRef.TargetPartCache and not checkcaller() and typeof(inst) == "Instance" and inst:IsA("Mouse") then
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
        end
        return oldIndex(inst, index)
    end))

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local method = getnamecallmethod()

        if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
            if selfRef.Active and selfRef.TargetPosCache and not checkcaller() and typeof(inst) == "Instance" and inst:IsA("Camera") then
                local camPos = inst.CFrame.Position
                return Ray.new(camPos, (selfRef.TargetPosCache - camPos).Unit)
            end
        elseif (method == "FireServer" or method == "InvokeServer") and selfRef.CurrentTargetEntry then
            if not checkcaller() and typeof(inst) == "Instance" then
                local args = {...}
                for _, arg in ipairs(args) do
                    if typeof(arg) == "Instance" and (arg == selfRef.CurrentTargetEntry.Model or arg:IsDescendantOf(selfRef.CurrentTargetEntry.Model)) then
                        task.spawn(function()
                            selfRef.Visuals:ShowHitmarker()
                        end)
                        break
                    end
                end
            end
        end

        return oldNamecall(inst, ...)
    end))
end

function SilentAim:SetState(active, targetPart, targetPos, currentEntry)
    self.Active = active
    self.TargetPartCache = targetPart
    self.TargetPosCache = targetPos
    self.CurrentTargetEntry = currentEntry
end

function SilentAim:Clear()
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
end

return SilentAim
