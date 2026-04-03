--[[
    InputHandler.lua - Input Management Class
    Quan ly trang thai chuot/ban phim va logic shouldAssist().
]]

local UserInputService = game:GetService("UserInputService")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler.new(config)
    local self = setmetatable({}, InputHandler)
    self.Config = config
    self.Options = config.Options
    self.RightMouseHeld = false
    self.LastShotTick = 0
    self._connections = {}
    return self
end

function InputHandler:Init()
    local conn1 = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed then
            local inputType = input.UserInputType
            if inputType == Enum.UserInputType.MouseButton1
                or inputType == Enum.UserInputType.MouseButton2
                or inputType == Enum.UserInputType.Keyboard then
                self.LastShotTick = os.clock()
            end
        end

        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.RightMouseHeld = true
        end
    end)

    local conn2 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.RightMouseHeld = false
        end
    end)

    table.insert(self._connections, conn1)
    table.insert(self._connections, conn2)
end

function InputHandler:ShouldAssist()
    if self.Options.AssistMode == "Off" then
        return false
    end
    if self.Options.HoldMouse2ToAssist and not self.RightMouseHeld then
        return false
    end
    return true
end

function InputHandler:WasShotRecently(windowSeconds)
    return (os.clock() - self.LastShotTick) <= (windowSeconds or 1.5)
end

function InputHandler:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    table.clear(self._connections)
end

return InputHandler

