--[[
    Input.lua — OOP User Interaction Class
    Handles mouseholding and assist availability checks.
]]

local UserInputService = game:GetService("UserInputService")

local Input = {}
Input.__index = Input

function Input.new(config)
    local self = setmetatable({}, Input)
    self.Options = config.Options
    self.Holding = false
    self._lastShot = 0
    return self
end

function Input:Init()
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Holding = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Holding = false
        end
    end)
    
    -- Hitmarker tracking (Register a shot)
    UserInputService.InputBegan:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._lastShot = os.clock()
        end
    end)
end

function Input:ShouldAssist()
    if self.Options.HoldMouse2ToAssist then
        return self.Holding
    end
    return true -- Mode is always active otherwise
end

function Input:WasShotRecently(seconds)
    return (os.clock() - self._lastShot) < (seconds or 1.5)
end

return Input
