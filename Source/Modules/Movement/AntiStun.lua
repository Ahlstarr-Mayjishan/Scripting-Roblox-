--[[
    AntiStun.lua — OOP Movement Stability Class
    Prevents Ragdoll, FallingDown, and PlatformStanding states.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AntiStun = {}
AntiStun.__index = AntiStun

function AntiStun.new(options)
    local self = setmetatable({}, AntiStun)
    self.Options = options
    self.Connection = nil
    return self
end

function AntiStun:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoStun then return end
        
        local char = Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.FallingDown 
           or state == Enum.HumanoidStateType.Ragdoll 
           or state == Enum.HumanoidStateType.PlatformStanding then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and root.Anchored then 
            root.Anchored = false 
        end
    end)
end

function AntiStun:Destroy()
    if self.Connection then self.Connection:Disconnect() end
end

return AntiStun
