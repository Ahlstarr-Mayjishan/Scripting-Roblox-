--[[
    Apocalypse.lua — The Ultimate Neural Hijacker v1.1.66
    Job: Parasitic locking of game projectiles and beams to boss entities.
    Fixes: Visual lag, Damage misalignment, C-Stack overflow, Performance, and Teleport Flick.
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
    -- 1. EXTREME OPTIMIZED TRACKER (Throttled)
    -- ═══════════════════════════════════════════════════
    local lastTrackerUpdate = 0
    local lastFullScan = 0
    
    RunService.Heartbeat:Connect(function()
        if not selfRef.Active then selfRef._bossExists = false return end
        
        local now = os.clock()
        -- THROTTLE: Only run tracker every 2 frames
        if now - lastTrackerUpdate < 0.03 then return end
        lastTrackerUpdate = now
        
        local found = nil
        local entities = Workspace:FindFirstChild("Entities")
        
        -- FAST SCAN (Children only)
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
        
        -- DEEP SCAN (Descendants) - Only Every 1.5 Seconds
        if not found and (now - lastFullScan > 1.5) then
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
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)
        
        if not checkcaller() and selfRef._bossExists then
            if (method == "FireServer" or method == "InvokeServer") then
                for i = 1, args.n do
                    local v = args[i]
                    if typeof(v) == "Vector3" then args[i] = selfRef._bossPos
                    elseif typeof(v) == "CFrame" then args[i] = CFrame.new(selfRef._bossPos) end
                end
                return oldNamecall(inst, unpack(args, 1, args.n))
            end
            
            if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and inst == Camera then
                return Ray.new(Camera.CFrame.Position, (selfRef._bossPos - Camera.CFrame.Position).Unit)
            end
        end
        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        if not checkcaller() and selfRef._bossExists and inst == selfRef._mouse then
            if index == "Hit" then return CFrame.new(selfRef._bossPos) end
            if index == "Target" then return selfRef._bossModel end
        end
        return oldIndex(inst, index)
    end))

    -- ═══════════════════════════════════════════════════
    -- 3. NEURAL VISUAL SYNC (Zero-Search Cache)
    -- ═══════════════════════════════════════════════════
    local activeProjectiles = {}
    local effectCache = {}
    local lastBossPos = Vector3.new()
    
    Workspace.ChildAdded:Connect(function(child)
        if child.Name == "BallOfLight" then table.insert(activeProjectiles, child) end
    end)

    local function updateEffectCache()
        table.clear(effectCache)
        local char = LocalPlayer.Character
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("Beam") or v:IsA("Trail") then table.insert(effectCache, v) end
            end
        end
    end
    
    LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5) updateEffectCache() end)
    updateEffectCache()

    RunService.RenderStepped:Connect(function()
        if not selfRef._bossExists then return end
        local p = selfRef._bossPos
        
        -- SYNC PROJECTILES
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
        
        -- SYNC BEAMS
        for _, v in ipairs(effectCache) do
            pcall(function()
                if v.Attachment1 then v.Attachment1.WorldPosition = p end
            end)
        end
    end)
end

function Apocalypse:SetState(active)
    self.Active = active
end

return Apocalypse
