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
local REDIRECT_WINDOW = 0.35
local clock = os.clock

local REMOTE_BLACKLIST = {
    "sprint", "speed", "walk", "jump", "action", "interact", "dialogue", "inventory", "tab"
}

local function isCombatRemote(remote)
    local mName = tostring(remote):lower()
    for _, word in ipairs(REMOTE_BLACKLIST) do
        if mName:find(word) then return false end
    end
    return mName:find("shoot")
        or mName:find("fire")
        or mName:find("attack")
        or mName:find("hit")
        or mName:find("damage")
        or mName:find("impact")
end

local function buildTargetCFrame(targetPos)
    local camPos = Workspace.CurrentCamera.CFrame.Position
    return CFrame.lookAt(camPos, targetPos)
end

local function buildTargetRay(origin, targetPos, length)
    local direction = targetPos - origin
    if direction.Magnitude <= 0.001 then
        direction = Workspace.CurrentCamera.CFrame.LookVector
    else
        direction = direction.Unit * (length or (targetPos - origin).Magnitude)
    end
    return Ray.new(origin, direction)
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
            and selfRef:_hasTargetLock()
            and selfRef:_isRedirectActive() then -- FIX: Only redirect mouse during firing window
            if inst == Mouse or (typeof(inst) == "Instance" and inst:IsA("Mouse")) then
                if index == "Hit" then
                    return buildTargetCFrame(selfRef.TargetPosCache)
                elseif index == "Target" then
                    return selfRef.TargetPartCache
                elseif index == "UnitRay" then
                    local camPos = Workspace.CurrentCamera.CFrame.Position
                    return buildTargetRay(camPos, selfRef.TargetPosCache, 1)
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
            and selfRef:_hasTargetLock() then
            if (method == "ViewportPointToRay" or method == "ScreenPointToRay") and inst == Workspace.CurrentCamera then
                local camPos = Workspace.CurrentCamera.CFrame.Position
                return buildTargetRay(camPos, selfRef.TargetPosCache, 1)
            end

            if selfRef:_isRedirectActive() then
                if (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and inst == Workspace then
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        args[1] = buildTargetRay(ray.Origin, selfRef.TargetPosCache, ray.Direction.Magnitude)
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end

                if (method == "FireServer" or method == "InvokeServer") and isCombatRemote(inst) then
                    local modified = false

                    for i = 1, args.n do
                        local arg = args[i]
                        if typeof(arg) == "Vector3" then
                            args[i] = selfRef.TargetPosCache
                            modified = true
                            break -- FIX: Only modify the first Vector3 (Primary Target) to avoid breaking skills
                        elseif typeof(arg) == "Instance" and (arg:IsA("BasePart") or arg:IsA("Model")) then
                            local localCharacter = LocalPlayer.Character
                            if not (localCharacter and arg:IsDescendantOf(localCharacter)) then
                                args[i] = selfRef.TargetPartCache
                                modified = true
                                break -- FIX: Same for Instances
                            end
                        elseif typeof(arg) == "CFrame" then
                            args[i] = buildTargetCFrame(selfRef.TargetPosCache)
                            modified = true
                            break -- FIX: Same for CFrames
                        elseif typeof(arg) == "Ray" then
                            args[i] = buildTargetRay(arg.Origin, selfRef.TargetPosCache, arg.Direction.Magnitude)
                            modified = true
                            break
                        end
                    end

                    if modified then
                        selfRef._lastRedirectTime = clock()
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function SilentAim.new(config, synapse, resolver)
    local self = setmetatable({}, SilentAim)
    self.Options = config.Options
    self.Synapse = synapse
    self.Resolver = resolver

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

function SilentAim:_hasTargetLock()
    return self.Active and self.TargetPosCache ~= nil and self.TargetPartCache ~= nil
end

function SilentAim:_isRedirectActive()
    if not self:_hasTargetLock() then
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
    self.TargetPosCache = active and self.Resolver and self.Resolver.Resolve and self.Resolver:Resolve(targetPart, targetPos, currentEntry) or targetPos
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
