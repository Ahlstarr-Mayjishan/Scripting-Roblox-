--[[
    Hitmarker.lua — OOP Hit Confirmation Visualization Class
]]

local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Hitmarker = {}
Hitmarker.__index = Hitmarker

function Hitmarker.new()
    local self = setmetatable({}, Hitmarker)
    
    local HitColor = Color3.fromRGB(240, 60, 60)
    
    self.Line1 = Drawing.new("Line")
    self.Line1.Visible = false
    self.Line1.Thickness = 1.5
    self.Line1.Color = HitColor

    self.Line2 = Drawing.new("Line")
    self.Line2.Visible = false
    self.Line2.Thickness = 1.5
    self.Line2.Color = HitColor

    self.Sound = Instance.new("Sound")
    pcall(function() self.Sound.Parent = CoreGui end)
    self.Sound.SoundId = "rbxassetid://160432334"
    self.Sound.Volume = 1.6

    self._lastTick = 0
    return self
end

function Hitmarker:Show()
    pcall(function()
        local mousePos = UserInputService:GetMouseLocation()
        local size = 7
        local currentTick = os.clock()
        self._lastTick = currentTick

        self.Line1.From = Vector2.new(mousePos.X - size, mousePos.Y - size)
        self.Line1.To = Vector2.new(mousePos.X + size, mousePos.Y + size)
        self.Line1.Visible = true

        self.Line2.From = Vector2.new(mousePos.X + size, mousePos.Y - size)
        self.Line2.To = Vector2.new(mousePos.X - size, mousePos.Y + size)
        self.Line2.Visible = true

        self.Sound:Play()

        task.delay(0.25, function()
            if self._lastTick == currentTick then
                self.Line1.Visible = false
                self.Line2.Visible = false
            end
        end)
    end)
end

function Hitmarker:Destroy()
    pcall(function() self.Line1:Remove() end)
    pcall(function() self.Line2:Remove() end)
    pcall(function() self.Sound:Destroy() end)
end

return Hitmarker
