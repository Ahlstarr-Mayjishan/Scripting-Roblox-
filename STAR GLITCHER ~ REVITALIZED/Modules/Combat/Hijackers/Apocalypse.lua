--[[
    Apocalypse.lua - The Ultimate Neural Hijacker
    Job: Parasitic locking of game projectiles and beams to boss entities.
    Notes: Uses a singleton hook state to avoid stacking hooks across reloads.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Apocalypse = {}
Apocalypse.__index = Apocalypse

local GLOBAL_HOOK_KEY = "__STAR_GLITCHER_APOCALYPSE_HOOK"

local function ensureHookState()
    local hookState = getgenv()[GLOBAL_HOOK_KEY]
    if hookState then
        return hookState
    end

    local mouse = LocalPlayer:GetMouse()
    hookState = {
        Instance = nil,
        Mouse = mouse,
    }

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local selfRef = hookState.Instance
        local method = getnamecallmethod()
        local args = table.pack(...)

        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef.Active
            and selfRef._bossExists then
            if method == "FireServer" or method == "InvokeServer" then
                for i = 1, args.n do
                    local value = args[i]
                    if typeof(value) == "Vector3" then
                        args[i] = selfRef._bossPos
                    elseif typeof(value) == "CFrame" then
                        args[i] = CFrame.new(selfRef._bossPos)
                    end
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
        local selfRef = hookState.Instance
        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef.Active
            and selfRef._bossExists
            and inst == hookState.Mouse then
            if index == "Hit" then
                return CFrame.new(selfRef._bossPos)
            end
            if index == "Target" then
                return selfRef._bossModel
            end
        end

        return oldIndex(inst, index)
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function Apocalypse.new(config)
    local self = setmetatable({}, Apocalypse)
    self.Options = config.Options
    self.Active = config.Options.ApocalypseEnabled == true

    self._bossPos = Vector3.zero
    self._bossModel = nil
    self._bossExists = false
    self._connections = {}
    self._destroyed = false
    self._hookState = nil

    return self
end

function Apocalypse:Init()
    if not (hookmetamethod or hookfunction) then
        return
    end

    self._destroyed = false
    self._hookState = ensureHookState()
    self._hookState.Instance = self

    local selfRef = self
    local lastTrackerUpdate = 0
    local lastFullScan = 0

    table.insert(self._connections, RunService.Heartbeat:Connect(function()
        if selfRef._destroyed or not selfRef.Active then
            selfRef._bossExists = false
            return
        end

        local now = os.clock()
        if now - lastTrackerUpdate < 0.03 then
            return
        end
        lastTrackerUpdate = now

        local found = nil
        local entities = Workspace:FindFirstChild("Entities")

        if entities then
            for _, model in ipairs(entities:GetChildren()) do
                if model:IsA("Model") then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and model ~= LocalPlayer.Character then
                        found = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                        if found then
                            break
                        end
                    end
                end
            end
        end

        if not found and (now - lastFullScan > 1.5) then
            lastFullScan = now
            if entities then
                for _, descendant in ipairs(entities:GetDescendants()) do
                    if descendant:IsA("Humanoid") and descendant.Parent ~= LocalPlayer.Character and descendant.Health > 0 then
                        found = descendant.Parent:FindFirstChild("HumanoidRootPart") or descendant.Parent.PrimaryPart
                        if found then
                            break
                        end
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
            selfRef._bossModel = nil
        end
    end))

    local activeProjectiles = {}
    local effectCache = {}

    table.insert(self._connections, Workspace.ChildAdded:Connect(function(child)
        if child.Name == "BallOfLight" then
            activeProjectiles[#activeProjectiles + 1] = child
        end
    end))

    local function updateEffectCache()
        table.clear(effectCache)
        local char = LocalPlayer.Character
        if char then
            for _, descendant in ipairs(char:GetDescendants()) do
                if descendant:IsA("Beam") or descendant:IsA("Trail") then
                    effectCache[#effectCache + 1] = descendant
                end
            end
        end
    end

    table.insert(self._connections, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if not selfRef._destroyed then
            updateEffectCache()
        end
    end))
    updateEffectCache()

    table.insert(self._connections, RunService.RenderStepped:Connect(function()
        if selfRef._destroyed or not selfRef.Active or not selfRef._bossExists then
            return
        end

        local bossPos = selfRef._bossPos
        for i = #activeProjectiles, 1, -1 do
            local projectile = activeProjectiles[i]
            if projectile and projectile.Parent then
                pcall(function()
                    local attachment = projectile:FindFirstChild("Attachment1")
                    if attachment then
                        attachment.WorldPosition = bossPos
                    end
                    local targetCFrame = projectile:FindFirstChild("TargCF")
                    if targetCFrame then
                        targetCFrame.Value = CFrame.new(bossPos)
                    end
                end)
            else
                table.remove(activeProjectiles, i)
            end
        end

        for _, effect in ipairs(effectCache) do
            pcall(function()
                if effect.Attachment1 then
                    effect.Attachment1.WorldPosition = bossPos
                end
            end)
        end
    end))
end

function Apocalypse:SetState(active)
    self.Active = active
    if not active then
        self._bossExists = false
        self._bossModel = nil
    end
end

function Apocalypse:Destroy()
    self._destroyed = true
    self.Active = false
    self._bossExists = false
    self._bossModel = nil

    if self._hookState and self._hookState.Instance == self then
        self._hookState.Instance = nil
    end

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return Apocalypse
