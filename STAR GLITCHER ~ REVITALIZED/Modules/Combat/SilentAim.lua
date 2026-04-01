--[[
    SilentAim.lua - High-Performance Neural Combat Hook
    Job: Safely redirect combat packets without interfering with user intent.
    Notes: Uses a singleton hook state to avoid stacking metamethod hooks on reload.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SilentAim = {}
SilentAim.__index = SilentAim

local GLOBAL_HOOK_KEY = "__STAR_GLITCHER_SILENT_AIM_HOOK"
local REDIRECT_WINDOW = 0.18
local clock = os.clock

local function isCombatRemote(remote)
    local mName = tostring(remote):lower()
    return mName:find("shoot")
        or mName:find("fire")
        or mName:find("attack")
        or mName:find("magic")
        or mName:find("spell")
        or mName:find("skill")
        or mName:find("ability")
        or mName:find("target")
        or mName:find("input")
end

local function ensureHookState()
    local hookState = getgenv()[GLOBAL_HOOK_KEY]
    if hookState then
        return hookState
    end

    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    hookState = {
        Instance = nil,
    }

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        local selfRef = hookState.Instance
        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef:_isRedirectActive() then
            if inst == Mouse or (typeof(inst) == "Instance" and inst:IsA("Mouse")) then
                if index == "Hit" then
                    local camPos = Workspace.CurrentCamera.CFrame.Position
                    return CFrame.lookAt(camPos, selfRef.TargetPosCache)
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
        local selfRef = hookState.Instance
        local method = getnamecallmethod()
        local args = table.pack(...)

        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef:_isRedirectActive()
            and (method == "FireServer" or method == "InvokeServer")
            and isCombatRemote(inst) then
            local modified = false

            for i = 1, args.n do
                local arg = args[i]
                if typeof(arg) == "Vector3" then
                    args[i] = selfRef.TargetPosCache
                    modified = true
                elseif typeof(arg) == "Instance" and (arg:IsA("BasePart") or arg:IsA("Model")) then
                    local localCharacter = LocalPlayer.Character
                    if not (localCharacter and arg:IsDescendantOf(localCharacter)) then
                        args[i] = selfRef.TargetPartCache
                        modified = true
                    end
                elseif typeof(arg) == "CFrame" then
                    local origin = arg.Position
                    local direction = selfRef.TargetPosCache - origin
                    if direction.Magnitude > 0.001 then
                        args[i] = CFrame.lookAt(origin, selfRef.TargetPosCache)
                        modified = true
                    end
                elseif typeof(arg) == "Ray" then
                    args[i] = Ray.new(arg.Origin, (selfRef.TargetPosCache - arg.Origin).Unit * arg.Direction.Magnitude)
                    modified = true
                end
            end

            if modified then
                selfRef._lastRedirectTime = clock()
                return oldNamecall(inst, unpack(args, 1, args.n))
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function SilentAim.new(config, synapse)
    local self = setmetatable({}, SilentAim)
    self.Options = config.Options
    self.Synapse = synapse

    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self._lastClickTime = 0
    self._lastRedirectTime = 0
    self._connections = {}
    self._destroyed = false
    self._hookState = nil
    return self
end

function SilentAim:_isRedirectActive()
    if not (self.Active and self.TargetPosCache and self.TargetPartCache) then
        return false
    end

    local now = clock()
    return (now - self._lastClickTime) <= REDIRECT_WINDOW
        or (now - self._lastRedirectTime) <= REDIRECT_WINDOW
end

function SilentAim:Init()
    if not hookmetamethod then
        return
    end

    self._destroyed = false
    self._hookState = ensureHookState()
    self._hookState.Instance = self

    local selfRef = self
    local LocalPlayer = Players.LocalPlayer
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local now = clock()
            selfRef._lastClickTime = now
            if selfRef.Active and selfRef.CurrentTargetEntry then
                local char = LocalPlayer.Character
                local muzzlePos = (char and char:GetPivot().Position) or Vector3.zero
                selfRef.Synapse.fire("ShotFired", selfRef.CurrentTargetEntry.Model, now, muzzlePos)
            end
        end
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
    self._lastClickTime = 0
    self._lastRedirectTime = 0
end

function SilentAim:Destroy()
    self._destroyed = true
    self:Clear()

    if self._hookState and self._hookState.Instance == self then
        self._hookState.Instance = nil
    end

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return SilentAim
