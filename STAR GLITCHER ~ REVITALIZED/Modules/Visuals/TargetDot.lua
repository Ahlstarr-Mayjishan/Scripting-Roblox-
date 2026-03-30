--[[
    TargetDot.lua — OOP Target Locking Dot Visualization Class
]]

local TargetDot = {}
TargetDot.__index = TargetDot

function TargetDot.new()
    local self = setmetatable({}, TargetDot)
    
    self.Drawing = Drawing.new("Circle")
    self.Drawing.Visible = false
    self.Drawing.Filled = true
    self.Drawing.Radius = 4
    self.Drawing.Color = Color3.fromRGB(240, 60, 60)
    self.Drawing.Thickness = 1
    
    return self
end

function TargetDot:Set(screenPos, visible)
    if visible and screenPos then
        self.Drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
        self.Drawing.Visible = true
    else
        self.Drawing.Visible = false
    end
end

function TargetDot:Destroy()
    pcall(function() self.Drawing:Remove() end)
end

return TargetDot
