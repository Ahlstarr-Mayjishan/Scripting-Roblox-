--!nocheck
-- [[
--  NULLSCAPE - Grace Wings Simulation
--  Multiplies airborne control by scaling HumanoidMovement friction while Freefall.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
    AirControlMultiplier = 1.1,
    OriginalApplyFriction = nil,
    Hooked = false
}

local function getHumanoidMovement()
    local movement = ReplicatedStorage:FindFirstChild("Movement")
    if not movement then return nil end
    return movement:FindFirstChild("HumanoidMovement")
end

function Logic.start(controller, gc)
    local HumanoidMovementModule = getHumanoidMovement()
    if not HumanoidMovementModule then return end

    local success, HumanoidMovement = pcall(require, HumanoidMovementModule)
    if not success or not HumanoidMovement or type(HumanoidMovement) ~= "table" then return end

    if not HumanoidMovement.__NULLSCAPE_original_ApplyFriction then
        HumanoidMovement.__NULLSCAPE_original_ApplyFriction = HumanoidMovement.ApplyFriction
    end
    Logic.OriginalApplyFriction = HumanoidMovement.__NULLSCAPE_original_ApplyFriction

    if Logic.Hooked or HumanoidMovement.__NULLSCAPE_grace_wings_hooked then return end

    HumanoidMovement.ApplyFriction = function(self, dt)
        local result = Logic.OriginalApplyFriction(self, dt)
        local movement = self and self.Movement
        local humanoid = self and self.Humanoid

        if controller.GraceWingsEnabled and movement and humanoid then
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
                local multiplier = math.clamp(tonumber(controller.GraceWingsAirControlMultiplier) or Logic.AirControlMultiplier, 1.1, 5)
                movement.friction = movement.friction * multiplier
            end
        end

        return result
    end

    HumanoidMovement.__NULLSCAPE_grace_wings_hooked = true
    Logic.Hooked = true
end

function Logic.stop()
    if not Logic.Hooked then return end

    local HumanoidMovementModule = getHumanoidMovement()
    if HumanoidMovementModule then
        local success, HumanoidMovement = pcall(require, HumanoidMovementModule)
        if success and HumanoidMovement and type(HumanoidMovement) == "table" and HumanoidMovement.__NULLSCAPE_original_ApplyFriction then
            HumanoidMovement.ApplyFriction = HumanoidMovement.__NULLSCAPE_original_ApplyFriction
            HumanoidMovement.__NULLSCAPE_grace_wings_hooked = false
        end
    end

    Logic.OriginalApplyFriction = nil
    Logic.Hooked = false
end

function Logic.setMultiplier(value)
    Logic.AirControlMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

return Logic
