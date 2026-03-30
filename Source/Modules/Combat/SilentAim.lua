--[[
    SilentAim.lua — Universal Silent Aim Hook Class
    Hook metamethods for Mouse.Hit, Mouse.Target, Camera ray functions.
    Super-lite, 0% Lag, dedicated to Magic/Beams.
    Enhanced Hitmarker Logic to reduce false positives.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new(config, visuals)
    local self = setmetatable({}, SilentAim)
    self.Config = config
    self.Options = config.Options
    self.Visuals = visuals
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    return self
end

function SilentAim:Init()
    if not hookmetamethod then return end

    local selfRef = self
    local LocalPlayer = Players.LocalPlayer

    -- ═══════════════════════════════════════════════════
    -- 1. INDEX HOOK (Mouse & UnitRay)
    -- ═══════════════════════════════════════════════════
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        if (index == "Hit" or index == "Target" or index == "UnitRay") and not checkcaller() then
            if selfRef.Active and selfRef.TargetPosCache and selfRef.TargetPartCache and typeof(inst) == "Instance" and inst:IsA("Mouse") then
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

    -- ═══════════════════════════════════════════════════
    -- 2. NAMECALL HOOK (Raycast & RemoteEvents)
    -- ═══════════════════════════════════════════════════
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)

        if not checkcaller() then
            -- A. RAYCAST REDIRECTION
            if selfRef.Active and selfRef.TargetPosCache then
                if method == "ViewportPointToRay" or method == "ScreenPointToRay" then
                    if typeof(inst) == "Instance" and inst:IsA("Camera") then
                        local camPos = inst.CFrame.Position
                        return Ray.new(camPos, (selfRef.TargetPosCache - camPos).Unit)
                    end
                elseif method == "Raycast" and inst == Workspace then
                    local origin = args[1]
                    local direction = args[2]
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        args[2] = (selfRef.TargetPosCache - origin).Unit * direction.Magnitude
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end
            end

            -- B. HYPER SPOOF & HITMARKER (RemoteEvents)
            if (method == "FireServer" or method == "InvokeServer") then
                -- Target redirection for Vector3 args (Guaranteed Hitrate)
                if selfRef.Active and selfRef.TargetPosCache then
                    for i = 1, args.n do
                        local arg = args[i]
                        if typeof(arg) == "Vector3" then
                            local char = LocalPlayer.Character
                            local myPos = char and char:GetPivot().Position or Vector3.new(0, 0, 0)
                            if (arg - myPos).Magnitude > 4 then
                                args[i] = selfRef.TargetPosCache
                            end
                        end
                    end
                end

                -- HITMARKER REFINEMENT Logic
                -- Only show hitmarkers for methods likely carrying damage (Hit, Attack, Damage, Deal)
                -- This resolves the "False Positive" identified in the findings.
                local mName = tostring(inst):lower()
                local meth = method:lower()
                if meth:find("hit") or meth:find("attack") or meth:find("damage") or mName:find("hit") then
                    if selfRef.Active and selfRef.CurrentTargetEntry then
                        for i = 1, args.n do
                            local arg = args[i]
                            if typeof(arg) == "Instance" and (arg == selfRef.CurrentTargetEntry.Model or arg:IsDescendantOf(selfRef.CurrentTargetEntry.Model)) then
                                task.spawn(function() selfRef.Visuals:ShowHitmarker() end)
                                break
                            end
                        end
                    end
                end
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))
end

function SilentAim:SetState(active, targetPart, targetPos, currentEntry, dt)
    self.Active = active
    self.TargetPartCache = targetPart
    self.CurrentTargetEntry = currentEntry
    self.TargetPosCache = targetPos -- We take the prediction directly from Brain
end

function SilentAim:Clear()
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
end

return SilentAim
