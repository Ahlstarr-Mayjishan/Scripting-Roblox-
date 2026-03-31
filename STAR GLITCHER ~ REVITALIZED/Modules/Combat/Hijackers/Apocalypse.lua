--[[
    Apocalypse.lua — The Ultimate Neural Hijacker v1.1.64
    Job: Parasitic locking of game projectiles and beams to boss entities.
    Fixes: Visual lag, Damage misalignment, C-Stack overflow, and Out-of-FOV targeting.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Apocalypse = {}
Apocalypse.__index = Apocalypse

function Apocalypse.new(config)
    local self = setmetatable({}, Apocalypse)
    self.Options = config.Options
    self.Active = true
    
    -- Optimized State (Anti-Recursion)
    self._bossPos = Vector3.new()
    self._bossModel = nil
    self._bossExists = false
    self._mouse = LocalPlayer:GetMouse()
    
    return self
end

function Apocalypse:Init()
    if not (hookmetamethod or hookfunction) then return end
    local selfRef = self

    -- ═══════════════════════════════════════════════════
    -- 1. OPTIMIZED TRACKER (Frequency: Heartbeat)
    -- ═══════════════════════════════════════════════════
    local lastFullScan = 0
    RunService.Heartbeat:Connect(function()
        if not selfRef.Active then selfRef._bossExists = false return end
        
        local now = os.clock()
        local found = nil
        
        -- 1. FAST SCAN (GetChildren) - Low CPU
        local entities = Workspace:FindFirstChild("Entities")
        if entities then
            for _, model in ipairs(entities:GetChildren()) do
                if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum.Health > 0 and model ~= LocalPlayer.Character then
                        found = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                        if found then break end
                    end
                end
            end
        end
        
        -- 2. DEEP SCAN (GetDescendants) - Only every 1 second
        if not found and (now - lastFullScan > 1) then
            lastFullScan = now
            if entities then
                for _, v in ipairs(entities:GetDescendants()) do
                    if v:IsA("Humanoid") and v.Parent ~= LocalPlayer.Character and v.Health > 0 then
                        found = v.Parent:FindFirstChild("HumanoidRootPart") or v.Parent.PrimaryPart
                        if found then break end
                    end
                end
            end
        end
        
        -- 3. FALLBACK (Workspace Root)
        if not found then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if (obj.Name == "Cube" or obj.Name == "Boss") and not obj:IsA("Folder") then
                    found = (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart"))) or (obj:IsA("BasePart") and obj)
                    if found then break end
                end
            end
        end

        if found then
            selfRef._bossPos = found.Position
            selfRef._bossModel = found.Parent
            selfRef._bossExists = true
        else
            selfRef._bossExists = false
        end
    end)

    -- ═══════════════════════════════════════════════════
    -- 2. ENGINE HOOKS (Silent Hijacking)
    -- ═══════════════════════════════════════════════════
    
    -- A. NAMECALL (Network & Viewport)
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)
        
        if not checkcaller() and selfRef._bossExists then
            -- Combat Packet Redirection
            if (method == "FireServer" or method == "InvokeServer") then
                for i = 1, args.n do
                    local v = args[i]
                    if typeof(v) == "Vector3" then args[i] = selfRef._bossPos
                    elseif typeof(v) == "CFrame" then args[i] = CFrame.new(selfRef._bossPos) end
                end
                return oldNamecall(inst, unpack(args, 1, args.n))
            end
            
            -- Visual Ray Redirection (Fixes beam pointing)
            if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and inst == Camera then
                return Ray.new(Camera.CFrame.Position, (selfRef._bossPos - Camera.CFrame.Position).Unit)
            end
        end
        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    -- B. INDEX (Mouse Hijacking)
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        if not checkcaller() and selfRef._bossExists and inst == selfRef._mouse then
            if index == "Hit" then return CFrame.new(selfRef._bossPos) end
            if index == "Target" then return selfRef._bossModel end
        end
        return oldIndex(inst, index)
    end))

    -- ═══════════════════════════════════════════════════
    -- 3. OPTIMIZED VISUAL LOCK (FPS Fix)
    -- ═══════════════════════════════════════════════════
    local activeProjectiles = {}
    
    -- Cache newly added projectiles instantly
    Workspace.ChildAdded:Connect(function(child)
        if child.Name == "BallOfLight" then
            table.insert(activeProjectiles, child)
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not selfRef._bossExists then return end
        
        local p = selfRef._bossPos
        -- Fast Sync for Cached Projectiles
        for i = #activeProjectiles, 1, -1 do
            local v = activeProjectiles[i]
            if v and v.Parent then
                pcall(function()
                    local a1 = v:FindFirstChild("Attachment1")
                    if a1 then a1.WorldPosition = p end
                    local tcf = v:FindFirstChild("TargCF")
                    if tcf then tcf.Value = CFrame.new(p) end
                end)
            else
                table.remove(activeProjectiles, i)
            end
        end
        
        -- Optimized Beam/Effect Sync (Skip full scan, target local character only)
        local char = LocalPlayer.Character
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("Beam") or v:IsA("Trail") then
                    pcall(function()
                         if v.Attachment1 then v.Attachment1.WorldPosition = p end
                    end)
                end
            end
        end
    end)
end

function Apocalypse:SetState(active)
    self.Active = active
end

return Apocalypse
