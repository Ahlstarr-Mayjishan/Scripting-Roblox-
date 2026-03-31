--[[
    SilentAim.lua — High-Performance Neural Combat Hook
    Analogy: The Spinal Reflex Arc.
    Job: Safely redirecting combat packets without interfering with user intent.
    Fixes: Clicking/Keybind blockage and Magic Auto-Aim for Skills/Spells.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SilentAim = {}
SilentAim.__index = SilentAim

function SilentAim.new(config, synapse)
    local self = setmetatable({}, SilentAim)
    self.Options = config.Options
    self.Synapse = synapse
    
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self._lastClickTime = 0
    self._connections = {}
    self._destroyed = false
    return self
end

function SilentAim:Init()
    if not hookmetamethod then return end
    
    local selfRef = self
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    
    -- COMBAT SENSOR: Update last click time
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            selfRef._lastClickTime = os.clock()
            if selfRef.Active and selfRef.CurrentTargetEntry then
                local char = LocalPlayer.Character
                local muzzlePos = (char and char:GetPivot().Position) or Vector3.zero
                selfRef.Synapse.fire("ShotFired", selfRef.CurrentTargetEntry.Model, os.clock(), muzzlePos)
            end
        end
    end))

    -- ═══════════════════════════════════════════════════
    -- 1. INDEX HOOK (Redirection)
    -- ═══════════════════════════════════════════════════
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        if not selfRef._destroyed and not checkcaller() and selfRef.Active and selfRef.TargetPosCache then
            -- BROAD MOUSE PROTECTION: Only act on the actual Mouse instance
            if inst == Mouse or (typeof(inst) == "Instance" and inst:IsA("Mouse")) then
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
    -- 2. NAMECALL HOOK (Skills / Spells / Projectiles)
    -- ═══════════════════════════════════════════════════
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)
        
        if not selfRef._destroyed and not checkcaller() and selfRef.Active and selfRef.TargetPosCache then
            -- A. RAYCAST REDIRECTION
            if method == "Raycast" and inst == Workspace then
                local origin = args[1]
                local direction = args[2]
                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                    args[2] = (selfRef.TargetPosCache - origin).Unit * direction.Magnitude
                    return oldNamecall(inst, unpack(args, 1, args.n))
                end
            end

            -- B. REMOTE REDIRECTION (Support for Skills/Spells)
            if (method == "FireServer" or method == "InvokeServer") then
                local mName = tostring(inst):lower()
                -- Broad magic/skill/attack detection
                local isCombat = mName:find("shoot") or mName:find("fire") or mName:find("attack") or 
                                 mName:find("magic") or mName:find("spell") or mName:find("skill") or 
                                 mName:find("ability") or mName:find("target") or mName:find("input")
                
                if isCombat then
                    local modified = false
                    for i = 1, args.n do
                        local arg = args[i]
                        if typeof(arg) == "Vector3" then
                            -- Redirect position to predicted target
                            args[i] = selfRef.TargetPosCache
                            modified = true
                        elseif typeof(arg) == "Instance" and (arg:IsA("BasePart") or arg:IsA("Model")) then
                            -- Redirect target instance if it's not the user themselves
                            if not arg:IsDescendantOf(LocalPlayer.Character) then
                                args[i] = selfRef.TargetPartCache
                                modified = true
                            end
                        end
                    end
                    
                    if modified then
                        return oldNamecall(inst, unpack(args, 1, args.n))
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
    self.TargetPosCache = targetPos
    self.CurrentTargetEntry = currentEntry
end

function SilentAim:Clear()
    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
end

function SilentAim:Destroy()
    self._destroyed = true
    self:Clear()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return SilentAim
