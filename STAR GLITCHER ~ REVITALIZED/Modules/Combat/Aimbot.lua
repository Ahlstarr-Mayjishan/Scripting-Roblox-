local Workspace = game:GetService("Workspace")

local Aimbot = {}
Aimbot.__index = Aimbot

function Aimbot.new(config)
    local self = setmetatable({}, Aimbot)
    self.Config = config
    self.Options = config.Options
    self.Active = false
    return self
end

function Aimbot:Update(targetPosition, smoothness)
    if not targetPosition then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local alpha = smoothness or self.Options.Smoothness or 0.15
    local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPosition)

    if targetPosition.X == targetPosition.X then
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
    end
end

function Aimbot:SetState(active)
    self.Active = active
end

return Aimbot
