local SpeedSpoof = {}
SpeedSpoof.__index = SpeedSpoof

function SpeedSpoof.new(options, localCharacter)
    local self = setmetatable({}, SpeedSpoof)
    self.Options = options
    self.LocalCharacter = localCharacter
    self._isHooked = false
    return self
end

function SpeedSpoof:Init()
    if not hookmetamethod then
        return
    end

    local hookState = getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK
    if hookState then
        hookState.Options = self.Options
        hookState.LocalCharacter = self.LocalCharacter
        self._isHooked = true
        return
    end

    hookState = {
        Options = self.Options,
        LocalCharacter = self.LocalCharacter,
    }
    getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK = hookState

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(obj, index)
        local options = hookState.Options
        local localCharacter = hookState.LocalCharacter
        if not checkcaller()
            and typeof(obj) == "Instance"
            and obj:IsA("Humanoid")
            and localCharacter
            and localCharacter:IsLocalHumanoid(obj) then
            if options and options.SpeedSpoofEnabled then
                if index == "WalkSpeed" then return 16 end
                if index == "JumpPower" then return 50 end
            end
        end
        return oldIndex(obj, index)
    end))

    self._isHooked = true
end

return SpeedSpoof
