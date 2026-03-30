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
        local args = {...}

        if selfRef.Active and selfRef.TargetPosCache and not checkcaller() then
            if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                if typeof(inst) == "Instance" and inst:IsA("Camera") then
                    local camPos = inst.CFrame.Position
                    return Ray.new(camPos, (selfRef.TargetPosCache - camPos).Unit)
                end
            elseif method == "Raycast" then
                if inst == Workspace then
                    local origin = args[1]
                    local direction = args[2]
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        -- Redirect direction to target
                        args[2] = (selfRef.TargetPosCache - origin).Unit * direction.Magnitude
                        return oldNamecall(inst, unpack(args))
                    end
                end
            elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                if inst == Workspace then
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        -- Redirect ray
                        args[1] = Ray.new(ray.Origin, (selfRef.TargetPosCache - ray.Origin).Unit * ray.Direction.Magnitude)
                        return oldNamecall(inst, unpack(args))
                    end
                end
            end
        end

        if (method == "FireServer" or method == "InvokeServer") and selfRef.CurrentTargetEntry then
            if not checkcaller() and typeof(inst) == "Instance" then
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

        return oldNamecall(inst, unpack(args))
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
