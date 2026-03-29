--[[
    NoSlowdown.lua — Anti-Debuff Module
    ═══════════════════════════════════════════════════
    Chống giảm tốc (WalkSpeed debuff) và giảm delay
    khi bị Boss đánh hoặc hiệu ứng áp lên nhân vật.

    Cơ chế:
      • NoSlowdown: Giữ WalkSpeed luôn >= tốc độ gốc
      • NoDelay: Xóa các debuff attribute/value phổ biến
    
    Tương thích: Hầu hết game Roblox RPG/Boss Fight
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
    self._active = false
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

    -- Chỉ lưu 1 lần (tốc độ gốc lúc chưa bị debuff)
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

    -- Capture stats khi character spawn
    local function onCharacterAdded(char)
        -- Đợi Humanoid load
        local humanoid = char:WaitForChild("Humanoid", 10)
        if humanoid then
            -- Reset base stats khi respawn
            self._baseWalkSpeed = nil
            self._baseJumpPower = nil
            task.wait(0.5) -- Đợi game set WalkSpeed gốc
            self:CaptureBaseStats()
        end
    end

    if localPlayer.Character then
        task.spawn(function() onCharacterAdded(localPlayer.Character) end)
    end
    table.insert(self._connections,
        localPlayer.CharacterAdded:Connect(onCharacterAdded)
    )

    -- Main loop: kiểm tra và khôi phục mỗi frame
    local conn = RunService.Heartbeat:Connect(function()
        local humanoid = self:GetHumanoid()
        if not humanoid then return end

        -- Capture lần đầu nếu chưa có
        if not self._baseWalkSpeed then
            self:CaptureBaseStats()
            return
        end

        -- ═══ NO SLOWDOWN ═══
        if self.Options.NoSlowdown then
            -- Nếu WalkSpeed bị giảm dưới mức gốc → khôi phục
            if humanoid.WalkSpeed < self._baseWalkSpeed then
                humanoid.WalkSpeed = self._baseWalkSpeed
            end
            -- Bảo vệ JumpPower
            if self._baseJumpPower and humanoid.JumpPower < self._baseJumpPower then
                humanoid.JumpPower = self._baseJumpPower
            end
        end

        -- ═══ NO DELAY ═══
        if self.Options.NoDelay then
            local character = humanoid.Parent
            if not character then return end

            -- Xóa các Value/Attribute debuff phổ biến
            for _, child in ipairs(character:GetChildren()) do
                local name = child.Name:lower()
                -- Tìm và xóa các debuff slowdown/stun/freeze
                if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("BoolValue") then
                    if name:find("slow") or name:find("stun") or name:find("freeze")
                        or name:find("root") or name:find("debuff") or name:find("delay") then
                        child:Destroy()
                    end
                end
            end

            -- Xóa các Attribute debuff
            for _, attrName in ipairs(character:GetAttributes() and {} or {}) do
                -- GetAttributes trả về dictionary, duyệt qua keys
            end
            -- Safe attribute removal
            pcall(function()
                local attrs = character:GetAttributes()
                for attrName, _ in pairs(attrs) do
                    local lower = attrName:lower()
                    if lower:find("slow") or lower:find("stun") or lower:find("freeze")
                        or lower:find("delay") or lower:find("debuff") then
                        character:SetAttribute(attrName, nil)
                    end
                end
            end)

            -- Đảm bảo nhân vật không bị Anchored
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart and rootPart.Anchored then
                rootPart.Anchored = false
            end

            -- Reset Humanoid state nếu bị stuck
            if humanoid:GetState() == Enum.HumanoidStateType.FallingDown
                or humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end)

    table.insert(self._connections, conn)
end

-- Cho phép user set WalkSpeed gốc thủ công
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
