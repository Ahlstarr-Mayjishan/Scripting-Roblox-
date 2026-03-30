--[[
    SilentAim.lua — Universal Silent Aim Hook Class
    Hook metamethods cho Mouse.Hit, Mouse.Target, Camera ray functions.
    Siêu nhẹ, 0% Lag, dành riêng cho Magic/Beams.
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
                elseif (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") and inst == Workspace then
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        args[1] = Ray.new(ray.Origin, (selfRef.TargetPosCache - ray.Origin).Unit * ray.Direction.Magnitude)
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end
            end

            -- B. HYPER SPOOF (RemoteEvents)
            if (method == "FireServer" or method == "InvokeServer") then
                -- 1. Snap Vector3 args to target (Guaranteed Hitrate)
                if selfRef.Active and selfRef.TargetPosCache then
                    local modified = false
                    for i = 1, args.n do
                        local arg = args[i]
                        if typeof(arg) == "Vector3" then
                            local char = LocalPlayer.Character
                            local myPos = char and char:GetPivot().Position or Vector3.new(0, 0, 0)
                            -- Nếu arg ở xa người chơi (khả năng cao là vị trí target)
                            if (arg - myPos).Magnitude > 4 then
                                args[i] = selfRef.TargetPosCache
                                modified = true
                            end
                        end
                    end
                    if modified then
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end

                -- 2. Hitmarker (Confirmed damage)
                if selfRef.CurrentTargetEntry then
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

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    task.spawn(function()
        task.wait(1)
        local RayfieldGlobal = getgenv().Rayfield
        if RayfieldGlobal then
            RayfieldGlobal:Notify({
                Title = "System Ready",
                Content = "100% Hitrate Engine Initialized.",
                Duration = 3,
                Image = 4483362458,
            })
        end
    end)
end

function SilentAim:SetState(active, targetPart, targetPos, currentEntry, dt)
    self.Active = active
    self.TargetPartCache = targetPart
    self.CurrentTargetEntry = currentEntry

    if active and targetPos then
        local targetPosition = targetPos
        local deltaTime = dt or (1/60)
        
        if self.Options.SilentAimSmoothness < 1 then
            if not self.TargetPosCache then
                local cam = Workspace.CurrentCamera
                self.TargetPosCache = cam.CFrame.Position + (cam.CFrame.LookVector * 10)
            end
            local speedScale = 15
            local alpha = 1 - math.pow(1 - self.Options.SilentAimSmoothness, deltaTime * speedScale)
            alpha = math.clamp(alpha, 0, 1)
            local newPos = self.TargetPosCache:Lerp(targetPosition, alpha)
            if newPos.X == newPos.X then
                self.TargetPosCache = newPos
            end
        else
            self.TargetPosCache = targetPosition
        end
    else
        self.TargetPosCache = nil
    end
end

function SilentAim:Clear()
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
end

return SilentAim
