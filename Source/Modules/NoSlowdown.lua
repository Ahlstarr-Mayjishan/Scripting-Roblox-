--[[
    NoSlowdown.lua — Anti-Debuff & Player Enhancement Module
    ═══════════════════════════════════════════════════
    • No Slowdown: Giữ WalkSpeed >= tốc độ gốc
    • No Delay: Xóa debuff Value/Attribute
    • No Stun: Chống stun/ragdoll/freeze
    • Custom Move Speed: Đặt WalkSpeed tùy chỉnh
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
        self.Options.OriginalWalkSpeed = self._baseWalkSpeed
    end
    if not self._baseJumpPower then
        self._baseJumpPower = humanoid.JumpPower
    end
end

function NoSlowdown:Init()
    local localPlayer = Players.LocalPlayer

    local function onCharacterAdded(char)
        local humanoid = char:WaitForChild("Humanoid", 10)
        if humanoid then
            self._baseWalkSpeed = nil
            self._baseJumpPower = nil
            task.wait(0.5)
            self:CaptureBaseStats()

            -- Disable stun-related HumanoidStates
            if self.Options.NoStun then
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
    table.insert(self._connections,
        localPlayer.CharacterAdded:Connect(onCharacterAdded)
    )

    -- Main loop
    local conn = RunService.Heartbeat:Connect(function()
        local humanoid = self:GetHumanoid()
        if not humanoid then return end

        if not self._baseWalkSpeed then
            self:CaptureBaseStats()
            return
        end

        -- ═══ SPEED MULTIPLIER (Legit Mode) ═══
        if self.Options.SpeedMultiplierEnabled then
            -- Note: Logic handled by hook in Init() or can be checked here
            -- But we want to ensure it stays scaled if game doesn't update it
        else
            -- ═══ CUSTOM MOVE SPEED ═══
            if self.Options.CustomMoveSpeedEnabled then
                humanoid.WalkSpeed = self.Options.CustomMoveSpeed
            -- ═══ NO SLOWDOWN ═══
            elseif self.Options.NoSlowdown then
                if humanoid.WalkSpeed < self._baseWalkSpeed then
                    humanoid.WalkSpeed = self._baseWalkSpeed
                end
            end
        end

        -- Bảo vệ JumpPower
        if self.Options.NoSlowdown and self._baseJumpPower then
            if humanoid.JumpPower < self._baseJumpPower then
                humanoid.JumpPower = self._baseJumpPower
            end
        end

        -- ═══ NO STUN ═══
        if self.Options.NoStun then
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.PlatformStanding then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end

            -- Unanchor nếu bị freeze
            local character = humanoid.Parent
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart and rootPart.Anchored then
                    rootPart.Anchored = false
                end
            end
        end

        -- ═══ NO DELAY ═══
        if self.Options.NoDelay then
            local character = humanoid.Parent
            if not character then return end

            -- Xóa debuff Values
            for _, child in ipairs(character:GetChildren()) do
                if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("BoolValue") then
                    local name = child.Name:lower()
                    if name:find("slow") or name:find("stun") or name:find("freeze")
                        or name:find("root") or name:find("debuff") or name:find("delay")
                        or name:find("cooldown") then
                        child:Destroy()
                    end
                end
            end

            -- Xóa debuff Attributes
            pcall(function()
                local attrs = character:GetAttributes()
                for attrName, _ in pairs(attrs) do
                    local lower = attrName:lower()
                    if lower:find("slow") or lower:find("stun") or lower:find("freeze")
                        or lower:find("delay") or lower:find("debuff") or lower:find("cooldown") then
                        character:SetAttribute(attrName, nil)
                    end
                end
            end)
        end

        -- Maintain Multiplier if active
        if self.Options.SpeedMultiplierEnabled and not self._isHookActive then
            -- Fallback if hook not supported, but hook is preferred
            local base = self._wantedSpeed or self._baseWalkSpeed or 16
            humanoid.WalkSpeed = base * self.Options.SpeedMultiplier
        end
    end)

    -- ═══ PROPERTY HOOK ═══
    -- This handles "Legit" multiplier by intercepting game's speed changes
    if hookmetamethod and not self._isHookActive then
        local selfRef = self
        local oldNewIndex
        oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(inst, index, value)
            if not checkcaller() and typeof(inst) == "Instance" and inst:IsA("Humanoid") then
                if index == "WalkSpeed" and selfRef.Options.SpeedMultiplierEnabled then
                    selfRef._wantedSpeed = value -- Save what the game wanted
                    return oldNewIndex(inst, index, value * selfRef.Options.SpeedMultiplier)
                end
            end
            return oldNewIndex(inst, index, value)
        end))
        self._isHookActive = true
    end

    table.insert(self._connections, conn)
end

function NoSlowdown:SetBaseWalkSpeed(speed)
    self._baseWalkSpeed = speed
    self.Options.OriginalWalkSpeed = speed
end

function NoSlowdown:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    table.clear(self._connections)
end

return NoSlowdown
