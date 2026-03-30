--[[
    NoSlowdown.lua — Anti-Debuff & Player Enhancement Module
    ═══════════════════════════════════════════════════
    • No Slowdown: Giữ WalkSpeed >= tốc độ gốc
    • No Delay: Xóa debuff Value/Attribute
    • No Stun: Chống stun/ragdoll/freeze
    • Custom Move Speed: Đặt WalkSpeed tùy chỉnh
    • Speed Multiplier (Legit): Nhân tốc độ nhân vật
    • Speed Spoof (Bypass): Giả mạo WalkSpeed về 16 khi game kiểm tra
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NoSlowdown = {}
NoSlowdown.__index = NoSlowdown

function NoSlowdown.new(config)
    local self = setmetatable({}, NoSlowdown)
    self.Config = config
    self.Options = config.Options
    self._connections = {}
    self._baseWalkSpeed = nil
    self._baseJumpPower = nil
    self._isHookActive = false
    return self
end

function NoSlowdown:GetHumanoid()
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

function NoSlowdown:CaptureBaseStats()
    local humanoid = self:GetHumanoid()
    if not humanoid then return end
    if not self._baseWalkSpeed then
        self._baseWalkSpeed = humanoid.WalkSpeed
    end
    if not self._baseJumpPower then
        self._baseJumpPower = humanoid.JumpPower
    end
end

function NoSlowdown:Init()
    local localPlayer = Players.LocalPlayer
    local selfRef = self

    local function onCharacterAdded(char)
        local humanoid = char:WaitForChild("Humanoid", 10)
        if humanoid then
            selfRef._baseWalkSpeed = nil
            selfRef._baseJumpPower = nil
            task.wait(0.5)
            selfRef:CaptureBaseStats()

            -- Disable stun-related HumanoidStates
            if selfRef.Options.NoStun then
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
                end)
            end
        end
    end

    if localPlayer.Character then
        task.spawn(function() onCharacterAdded(localPlayer.Character) end)
    end
    table.insert(self._connections, localPlayer.CharacterAdded:Connect(onCharacterAdded))

    -- ═══ MAIN LOOP ═══
    local heartConn = RunService.Heartbeat:Connect(function()
        local humanoid = selfRef:GetHumanoid()
        if not humanoid then return end

        if not selfRef._baseWalkSpeed then
            selfRef:CaptureBaseStats()
            return
        end

        -- 1. No Slowdown / Speed Multiplier / Custom Speed (Always active)
        if selfRef.Options.SpeedMultiplierEnabled then
            local base = selfRef._baseWalkSpeed or 16
            local target = base * selfRef.Options.SpeedMultiplier
            if math.abs(humanoid.WalkSpeed - target) > 0.1 then
                humanoid.WalkSpeed = target
            end
        elseif selfRef.Options.CustomMoveSpeedEnabled then
            if math.abs(humanoid.WalkSpeed - selfRef.Options.CustomMoveSpeed) > 0.1 then
                humanoid.WalkSpeed = selfRef.Options.CustomMoveSpeed
            end
        elseif selfRef.Options.NoSlowdown then
            if humanoid.WalkSpeed < selfRef._baseWalkSpeed then
                humanoid.WalkSpeed = selfRef._baseWalkSpeed
            end
        end

        -- 2. JumpPower Protection
        if selfRef.Options.NoSlowdown and selfRef._baseJumpPower then
            if humanoid.JumpPower < selfRef._baseJumpPower then
                humanoid.JumpPower = selfRef._baseJumpPower
            end
        end

        -- 3. No Stun / Ragdoll
        if selfRef.Options.NoStun then
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.PlatformStanding then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end

            local character = humanoid.Parent
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart and rootPart.Anchored then rootPart.Anchored = false end
            end
        end

        -- 4. No Delay / Attributes
        if selfRef.Options.NoDelay then
            local character = humanoid.Parent
            if character then
                -- Values
                for _, child in ipairs(character:GetChildren()) do
                    if child:IsA("ValueBase") then
                        local name = child.Name:lower()
                        if name:find("slow") or name:find("stun") or name:find("freeze")
                           or name:find("root") or name:find("debuff") or name:find("delay")
                           or name:find("cooldown") then
                            child:Destroy()
                        end
                    end
                end
                -- Attributes
                for attrName, _ in pairs(character:GetAttributes()) do
                    local lower = attrName:lower()
                    if lower:find("slow") or lower:find("stun") or lower:find("freeze")
                       or lower:find("delay") or lower:find("debuff") then
                        character:SetAttribute(attrName, nil)
                    end
                end
            end
        end
    end)
    table.insert(self._connections, heartConn)

    -- ═══ METAMETHOD HOOKS (Bypass & Control) ═══
    if hookmetamethod and not self._isHookActive then
        local Options = self.Options
        
        -- Hook __index: Giả mạo chỉ số cho các script của Game (Bypass)
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(obj, index)
            if not checkcaller() and typeof(obj) == "Instance" and obj:IsA("Humanoid") then
                if Options.SpeedSpoofEnabled then
                    if index == "WalkSpeed" then return 16 end
                    if index == "JumpPower" then return 50 end
                end
            end
            return oldIndex(obj, index)
        end))

        -- Hook __newindex: Can thiệp khi game nhân vật thay đổi WalkSpeed
        local oldNewIndex
        oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(obj, index, value)
            if not checkcaller() and typeof(obj) == "Instance" and obj:IsA("Humanoid") then
                -- Multiplier cho Legit speed
                if index == "WalkSpeed" and Options.SpeedMultiplierEnabled then
                    return oldNewIndex(obj, index, value * Options.SpeedMultiplier)
                end
                
                -- No Slowdown
                if Options.NoSlowdown then
                    if index == "WalkSpeed" and value < 16 then return end
                    if index == "JumpPower" and value < 50 then return end
                end
            end
            return oldNewIndex(obj, index, value)
        end))
        
        self._isHookActive = true
    end
end

function NoSlowdown:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    table.clear(self._connections)
end

return NoSlowdown
