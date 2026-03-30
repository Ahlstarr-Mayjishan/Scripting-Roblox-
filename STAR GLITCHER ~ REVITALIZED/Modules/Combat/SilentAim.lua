--[[
    SilentAim.lua — Universal Silent Aim Hook Class
    Analogy: The Neural Network's Motor Path.
    Logic:
    • Hook metamethods for Mouse.Hit, Mouse.Target.
    • Synapse Integration: Fires 'ShotFired' when shooting, 'DamageApplied' when remote hits target.
    • Enhanced Hitmarker logic with confirmation queue Support.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new(config, synapse)
    local self = setmetatable({}, SilentAim)
    self.Config = config
    self.Options = config.Options
    self.Synapse = synapse
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    return self
end

function SilentAim:Init()
    if not hookmetamethod then return end

    local selfRef = self
    local Synapse = self.Synapse
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
    -- 2. NAMECALL HOOK (WeaponController Simulation)
    -- ═══════════════════════════════════════════════════
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)

        if not checkcaller() then
            -- A. RAYCAST REDIRECTION
            if selfRef.Active and selfRef.TargetPosCache then
                if method == "Raycast" and inst == Workspace then
                    local origin = args[1]
                    local direction = args[2]
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        args[2] = (selfRef.TargetPosCache - origin).Unit * direction.Magnitude
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end
            end

            -- B. COMMUNICATION REFINEMENT (WeaponController & CombatService simulation)
            if (method == "FireServer" or method == "InvokeServer") then
                local mName = tostring(inst):lower()
                local meth = method:lower()
                
                -- WEAPON CONTROLLER: Register a SHOT (Spell / Ability / Projectile)
                -- We detect fire remotes (Shoot, Fire, Attack, Spell, Ability, Magic)
                local isAttack = meth:find("fire") or meth:find("shoot") or meth:find("attack") 
                local isMagic  = meth:find("spell") or meth:find("ability") or meth:find("magic") or meth:find("effect")

                if (isAttack or isMagic) then
                    if selfRef.Active and selfRef.CurrentTargetEntry then
                        -- Register the cast/shot with Synapse
                        local muzzlePos = LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position or Vector3.zero
                        Synapse.fire("ShotFired", selfRef.CurrentTargetEntry.Model, os.clock(), muzzlePos)
                    end
                end

                -- COMBAT SERVICE: Register a HIT (DamageApplied)
                if meth:find("hit") or meth:find("damage") or mName:find("hit") then
                    if selfRef.CurrentTargetEntry then
                        for i = 1, args.n do
                            local arg = args[i]
                            local targetModel = selfRef.CurrentTargetEntry.Model
                            if typeof(arg) == "Instance" and (arg == targetModel or arg:IsDescendantOf(targetModel)) then
                                -- Fire event for HitConfirmController
                                Synapse.fire("DamageApplied", targetModel, os.clock())
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
    self.TargetPosCache = targetPos 
end

function SilentAim:Clear()
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
end

return SilentAim
