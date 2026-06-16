--!nocheck
-- [[
--  NULLSCAPE - Advanced Gravity Coil Simulation
--  Ref logic:
--    - Base JumpPower = 35
--    - AdvancedGravityCoil reduces it to 35 * 0.8 = 28
--    - MovementCore adds an upward assist task on Jumping while the upgrade is enabled
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local MIN_JUMP_POWER = 28
local MAX_JUMP_POWER = 100

local Logic = {
    JumpPower = MIN_JUMP_POWER,
    Connection = nil,
    Hooked = false
}

local function getHumanoid()
    local character = LocalPlayer and LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function applyJumpPower(controller)
    local humanoid = getHumanoid()
    if not humanoid then return end

    local jumpPower = math.clamp(tonumber(controller.AdvancedGravityCoilJumpPower) or Logic.JumpPower, MIN_JUMP_POWER, MAX_JUMP_POWER)
    humanoid.JumpPower = jumpPower
end

function Logic.start(controller, gc)
    Logic.JumpPower = math.clamp(tonumber(controller.AdvancedGravityCoilJumpPower) or Logic.JumpPower, MIN_JUMP_POWER, MAX_JUMP_POWER)
    applyJumpPower(controller)

    if Logic.Connection then
        Logic.Hooked = true
        return
    end

    Logic.Connection = RunService.Heartbeat:Connect(function()
        if not controller.AdvancedGravityCoilEnabled then
            return
        end

        applyJumpPower(controller)
    end)
    Logic.Hooked = true
end

function Logic.stop()
    if Logic.Connection then
        Logic.Connection:Disconnect()
        Logic.Connection = nil
    end

    Logic.Hooked = false
end

function Logic.setJumpPower(value)
    Logic.JumpPower = math.clamp(tonumber(value) or MIN_JUMP_POWER, MIN_JUMP_POWER, MAX_JUMP_POWER)
end

function Logic.getMinJumpPower()
    return MIN_JUMP_POWER
end

function Logic.getMaxJumpPower()
    return MAX_JUMP_POWER
end

return Logic
