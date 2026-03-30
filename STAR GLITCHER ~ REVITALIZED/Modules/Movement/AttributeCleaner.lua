local RunService = game:GetService("RunService")

local AttributeCleaner = {}
AttributeCleaner.__index = AttributeCleaner

function AttributeCleaner.new(options, localCharacter)
    local self = setmetatable({}, AttributeCleaner)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    return self
end

function AttributeCleaner:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoDelay then
            return
        end

        local char = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        if not char then
            return
        end

        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("ValueBase") then
                local n = child.Name:lower()
                if n:find("slow") or n:find("stun") or n:find("freeze")
                    or n:find("root") or n:find("debuff") or n:find("delay")
                    or n:find("cooldown") then
                    child:Destroy()
                end
            end
        end

        for attr, _ in pairs(char:GetAttributes()) do
            local lower = attr:lower()
            if lower:find("slow") or lower:find("stun") or lower:find("freeze")
                or lower:find("delay") or lower:find("debuff") then
                char:SetAttribute(attr, nil)
            end
        end
    end)
end

function AttributeCleaner:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AttributeCleaner
