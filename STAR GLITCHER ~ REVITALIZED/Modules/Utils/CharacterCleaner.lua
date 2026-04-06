local Players = game:GetService("Players")

local CharacterCleaner = {}
CharacterCleaner.__index = CharacterCleaner

function CharacterCleaner.new(options, localCharacter, hitboxDesync)
    local self = setmetatable({}, CharacterCleaner)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.HitboxDesync = hitboxDesync
    return self
end

function CharacterCleaner:Clean()
    local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    local root = self.LocalCharacter and self.LocalCharacter:GetRootPart()

    -- 1. Disable Toggles in Options
    self.Options.KillPartBypassEnabled = false
    self.Options.ZenithDesyncEnabled = false
    self.Options.NoclipEnabled = false
    self.Options.CustomMoveSpeedEnabled = false
    self.Options.InfiniteJumpEnabled = false
    self.Options.HighGravityEnabled = false
    self.Options.FlightEnabled = false

    -- 2. Force Stop Zenith Desync
    if self.HitboxDesync then
        pcall(function()
            self.HitboxDesync:Stop()
        end)
    end

    -- 3. Reset Humanoid Properties
    if humanoid then
        pcall(function()
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
            humanoid.AutoRotate = true
            humanoid.PlatformStand = false
        end)
    end

    -- 4. Restore Interaction (CanTouch/CanQuery)
    if character then
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                pcall(function()
                    obj.CanTouch = true
                    obj.CanQuery = true
                    -- obj.CanCollide = true -- Caution: Noclip might still be desirable if inside a wall
                end)
            end
        end
    end

    return true
end

return CharacterCleaner
