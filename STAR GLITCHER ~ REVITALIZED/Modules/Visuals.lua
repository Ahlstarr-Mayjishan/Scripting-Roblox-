--[[
    Visuals.lua - Visual Feedback Class
    Quan ly FOV Circle, Target Dot, Highlight, va Hitmarker system.
]]

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local Visuals = {}
Visuals.__index = Visuals
Visuals.__Legacy = true

function Visuals.new(config)
    local self = setmetatable({}, Visuals)
    self.Config = config
    self.Options = config.Options

    -- FOV Circle
    self.FOVCircle = Drawing.new("Circle")
    self.FOVCircle.Position = UserInputService:GetMouseLocation()
    self.FOVCircle.Radius = self.Options.FOV
    self.FOVCircle.Filled = false
    self.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    self.FOVCircle.Visible = self.Options.ShowFOV
    self.FOVCircle.Thickness = 1.5

    -- Target Dot
    self.TargetDot = Drawing.new("Circle")
    self.TargetDot.Visible = false
    self.TargetDot.Filled = true
    self.TargetDot.Radius = 4
    self.TargetDot.Color = Color3.fromRGB(255, 80, 80)
    self.TargetDot.Thickness = 1

    -- Hitmarker Lines
    local HitmarkerColor = Color3.fromRGB(255, 40, 40)
    self.HitmarkerLine1 = Drawing.new("Line")
    self.HitmarkerLine1.Visible = false
    self.HitmarkerLine1.Thickness = 1.5
    self.HitmarkerLine1.Color = HitmarkerColor

    self.HitmarkerLine2 = Drawing.new("Line")
    self.HitmarkerLine2.Visible = false
    self.HitmarkerLine2.Thickness = 1.5
    self.HitmarkerLine2.Color = HitmarkerColor

    -- Hitmarker Sound
    self.HitSound = Instance.new("Sound")
    pcall(function() self.HitSound.Parent = CoreGui end)
    self.HitSound.SoundId = "rbxassetid://160432334"
    self.HitSound.Volume = 1.6

    -- Target Highlight
    self.TargetHighlight = Instance.new("Highlight")
    self.TargetHighlight.FillColor = Color3.fromRGB(255, 50, 50)
    self.TargetHighlight.FillTransparency = 0.5
    self.TargetHighlight.OutlineColor = Color3.new(1, 1, 1)
    self.TargetHighlight.OutlineTransparency = 0
    self.TargetHighlight.Enabled = false
    pcall(function() self.TargetHighlight.Parent = CoreGui end)
    if not self.TargetHighlight.Parent then
        self.TargetHighlight.Parent = Workspace.CurrentCamera
    end

    self._lastHitTick = 0
    return self
end

function Visuals:ShowHitmarker()
    pcall(function()
        local mousePos = UserInputService:GetMouseLocation()
        local size = 7

        self.HitmarkerLine1.From = Vector2.new(mousePos.X - size, mousePos.Y - size)
        self.HitmarkerLine1.To = Vector2.new(mousePos.X + size, mousePos.Y + size)
        self.HitmarkerLine1.Visible = true

        self.HitmarkerLine2.From = Vector2.new(mousePos.X + size, mousePos.Y - size)
        self.HitmarkerLine2.To = Vector2.new(mousePos.X - size, mousePos.Y + size)
        self.HitmarkerLine2.Visible = true

        self.HitSound:Play()

        local currentTick = os.clock()
        self._lastHitTick = currentTick
        task.delay(0.25, function()
            if self._lastHitTick == currentTick then
                self.HitmarkerLine1.Visible = false
                self.HitmarkerLine2.Visible = false
            end
        end)
    end)
end

function Visuals:UpdateFOV(mousePos)
    if self.Options.ShowFOV then
        self.FOVCircle.Position = mousePos
        self.FOVCircle.Visible = true
    else
        self.FOVCircle.Visible = false
    end
end

function Visuals:SetTargetDot(screenPos, visible)
    if visible then
        self.TargetDot.Position = Vector2.new(screenPos.X, screenPos.Y)
        self.TargetDot.Visible = true
    else
        self.TargetDot.Visible = false
    end
end

function Visuals:SetHighlight(part, enabled)
    self.TargetHighlight.Adornee = part
    self.TargetHighlight.Enabled = enabled
end

function Visuals:ClearHighlight()
    self.TargetHighlight.Adornee = nil
    self.TargetHighlight.Enabled = false
end

function Visuals:Destroy()
    pcall(function() self.FOVCircle:Remove() end)
    pcall(function() self.TargetDot:Remove() end)
    pcall(function() self.HitmarkerLine1:Remove() end)
    pcall(function() self.HitmarkerLine2:Remove() end)
    pcall(function() self.HitSound:Destroy() end)
    pcall(function() self.TargetHighlight:Destroy() end)
end

return Visuals

