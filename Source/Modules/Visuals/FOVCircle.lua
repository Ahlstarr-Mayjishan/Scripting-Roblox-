--[[
    FOVCircle.lua — OOP FOV Visualization Class
]]

local UserInputService = game:GetService("UserInputService")

local FOVCircle = {}
FOVCircle.__index = FOVCircle

function FOVCircle.new(options)
    local self = setmetatable({}, FOVCircle)
    self.Options = options
    
    self.Drawing = Drawing.new("Circle")
    self.Drawing.Position = UserInputService:GetMouseLocation()
    self.Drawing.Radius = options.FOV or 150
    self.Drawing.Filled = false
    self.Drawing.Color = Color3.fromRGB(255, 255, 255)
    self.Drawing.Visible = options.ShowFOV
    self.Drawing.Thickness = 1.5
    
    return self
end

function FOVCircle:Update(mousePos)
    if self.Options.ShowFOV then
        self.Drawing.Position = mousePos
        self.Drawing.Visible = true
        self.Drawing.Radius = self.Options.FOV
    else
        self.Drawing.Visible = false
    end
end

function FOVCircle:Destroy()
    pcall(function() self.Drawing:Remove() end)
end

return FOVCircle
