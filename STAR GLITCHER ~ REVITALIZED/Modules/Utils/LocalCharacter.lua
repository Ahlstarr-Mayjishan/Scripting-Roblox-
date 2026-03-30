local Players = game:GetService("Players")

local LocalCharacter = {}
LocalCharacter.__index = LocalCharacter

function LocalCharacter.new()
    local self = setmetatable({}, LocalCharacter)
    self.Player = Players.LocalPlayer
    self.Character = nil
    self.Humanoid = nil
    self.RootPart = nil
    self.PlayerGui = nil
    self._connections = {}
    return self
end

function LocalCharacter:_refresh(character)
    self.Character = character
    self.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    self.RootPart = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChildWhichIsA("BasePart")
    ) or nil
    self.PlayerGui = self.Player and self.Player:FindFirstChildOfClass("PlayerGui") or nil
end

function LocalCharacter:Init()
    self:_refresh(self.Player and self.Player.Character or nil)

    if not self.Player then
        return
    end

    table.insert(self._connections, self.Player.CharacterAdded:Connect(function(character)
        self:_refresh(character)
    end))

    table.insert(self._connections, self.Player.CharacterRemoving:Connect(function(character)
        if self.Character == character then
            self:_refresh(nil)
        end
    end))
end

function LocalCharacter:GetCharacter()
    local character = self.Player and self.Player.Character or nil
    if character ~= self.Character then
        self:_refresh(character)
    end
    return self.Character
end

function LocalCharacter:GetHumanoid()
    local character = self:GetCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    if humanoid ~= self.Humanoid then
        self.Humanoid = humanoid
    end
    return self.Humanoid
end

function LocalCharacter:GetRootPart()
    local character = self:GetCharacter()
    local rootPart = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChildWhichIsA("BasePart")
    ) or nil
    if rootPart ~= self.RootPart then
        self.RootPart = rootPart
    end
    return self.RootPart
end

function LocalCharacter:GetState()
    return self:GetCharacter(), self:GetHumanoid(), self:GetRootPart()
end

function LocalCharacter:IsLocalHumanoid(instance)
    local humanoid = self:GetHumanoid()
    return humanoid ~= nil and instance == humanoid
end

function LocalCharacter:Destroy()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return LocalCharacter
