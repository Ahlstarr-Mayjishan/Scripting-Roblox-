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

        -- 🔥 HYPER SPOOF: Can thiệp RemoteEvent để ép Beam phải trúng
        if (method == "FireServer" or method == "InvokeServer") and not checkcaller() then
            if selfRef.Active and selfRef.TargetPosCache then
                local modified = false
                for i, arg in ipairs(args) do
                    -- Nếu argument là Vector3 và ở xa Player (khả năng cao là vị trí target)
                    if typeof(arg) == "Vector3" then
                        local localCharacter = game:GetService("Players").LocalPlayer.Character
                        local myPos = localCharacter and localCharacter:GetPivot().Position or Vector3.zero
                        
                        -- Nếu điểm hit cách mình > 5 units (tránh spoofing chính mình hoặc effect gần)
                        if (arg - myPos).Magnitude > 5 then
                            args[i] = selfRef.TargetPosCache
                            modified = true
                        end
                    end
                end
                
                if modified then
                    return oldNamecall(inst, unpack(args))
                end
            end

            -- Hitmarker detection (Xác nhận trúng trên server)
            if selfRef.CurrentTargetEntry then
                for _, arg in ipairs(args) do
                    if typeof(arg) == "Instance" and (arg == selfRef.CurrentTargetEntry.Model or arg:IsDescendantOf(selfRef.CurrentTargetEntry.Model)) then
                        task.spawn(function() selfRef.Visuals:ShowHitmarker() end)
                        break
                    end
                end
            end
        end

        return oldNamecall(inst, unpack(args))
    end))
end

function SilentAim:SetState(active, targetPart, targetPos, currentEntry, dt)
    self.Active = active
    self.TargetPartCache = targetPart
    self.CurrentTargetEntry = currentEntry

    if active and targetPos then
        -- Ổn định DeltaTime (mặc định 60fps nếu dt bị hỏng)
        local deltaTime = dt or (1/60)
        
        -- Nếu có Smoothness < 1 thì Lerp theo DeltaTime
        if self.Options.SilentAimSmoothness < 1 then
            -- Khởi tạo cache nếu chưa có (lấy từ tâm camera)
            if not self.TargetPosCache then
                local cam = Workspace.CurrentCamera
                self.TargetPosCache = cam.CFrame.Position + (cam.CFrame.LookVector * 10)
            end
            
            -- Alpha dựa trên DeltaTime để mượt trên mọi máy (FPS-independent)
            -- Alpha = 1 - (1 - smoothness)^(dt * scale)
            local speedScale = 15 -- Hệ số tốc độ
            local alpha = 1 - math.pow(1 - self.Options.SilentAimSmoothness, deltaTime * speedScale)
            alpha = math.clamp(alpha, 0, 1)
            
            -- Lerp
            local newPos = self.TargetPosCache:Lerp(targetPos, alpha)
            
            -- Safety: Tránh NaN
            if newPos.X == newPos.X then
                self.TargetPosCache = newPos
            end
        else
            -- Không mượt (Lập tức)
            self.TargetPosCache = targetPos
        end
    else
        -- Không active thì xóa cache từ từ hoặc reset ngay? 
        -- Reset ngay giúp lần sau khóa mục tiêu mới sẽ bắt đầu mượt từ tâm.
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
