--!nocheck
-- [[
--  NULLSCAPE - Grace Wings Simulation
--  Multiplies airborne control while Freefall/Jumping.
-- ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logic = {
    AirControlMultiplier = 1.1,
    OriginalApplyFriction = nil,
    OriginalStep = nil,
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
    if not HumanoidMovement.__NULLSCAPE_original_GraceStep then
        HumanoidMovement.__NULLSCAPE_original_GraceStep = HumanoidMovement.Step
    end
    Logic.OriginalApplyFriction = HumanoidMovement.__NULLSCAPE_original_ApplyFriction
    Logic.OriginalStep = HumanoidMovement.__NULLSCAPE_original_GraceStep

    if Logic.Hooked or HumanoidMovement.__NULLSCAPE_grace_wings_hooked then return end

    local function isAirborne(humanoid)
        local state = humanoid:GetState()
        return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
    end

    local function getMultiplier()
        return math.clamp(tonumber(controller.GraceWingsAirControlMultiplier) or Logic.AirControlMultiplier, 1.1, 5)
    end

    local function applyVelocitySteering(movement, dt)
        local rootPart = movement.RootPart
        local wantDirection = movement.WantDirection
        if not rootPart or typeof(wantDirection) ~= "Vector3" or wantDirection.Magnitude <= 0.001 then
            return
        end

        local velocity = rootPart.AssemblyLinearVelocity or rootPart.Velocity
        local horizontalVelocity = velocity * Vector3.new(1, 0, 1)
        local horizontalSpeed = horizontalVelocity.Magnitude
        local targetSpeed = math.max(horizontalSpeed, (movement.Humanoid and movement.Humanoid.WalkSpeed or 16) * 0.85)
        local targetHorizontal = wantDirection.Unit * targetSpeed
        local multiplier = getMultiplier()
        local alpha = math.clamp((dt or 0.016) * (multiplier - 1) * 5, 0, 0.9)
        local newHorizontal = horizontalVelocity:Lerp(targetHorizontal, alpha)
        local newVelocity = newHorizontal + Vector3.new(0, velocity.Y, 0)

        pcall(function()
            rootPart.AssemblyLinearVelocity = newVelocity
        end)
        rootPart.Velocity = newVelocity
    end

    HumanoidMovement.ApplyFriction = function(self, dt)
        local result = Logic.OriginalApplyFriction(self, dt)
        local movement = self and self.Movement
        local humanoid = self and self.Humanoid

        if controller.GraceWingsEnabled and movement and humanoid and isAirborne(humanoid) then
            movement.friction = movement.friction * getMultiplier()
        end

        return result
    end

    HumanoidMovement.Step = function(self, dt)
        local result = Logic.OriginalStep(self, dt)
        local movement = self and self.Movement
        local humanoid = self and self.Humanoid

        if controller.GraceWingsEnabled and movement and humanoid and isAirborne(humanoid) then
            local wantDirection = movement.WantDirection
            local trueDirection = movement.TrueMoveDirection
            if typeof(wantDirection) == "Vector3" and typeof(trueDirection) == "Vector3" and wantDirection.Magnitude > 0.001 then
                local multiplier = getMultiplier()
                local alpha = math.clamp((dt or 0.016) * (multiplier - 1) * 3, 0, 0.85)
                movement.TrueMoveDirection = trueDirection:Lerp(wantDirection, alpha)
                applyVelocitySteering(movement, dt)
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
            if HumanoidMovement.__NULLSCAPE_original_GraceStep then
                HumanoidMovement.Step = HumanoidMovement.__NULLSCAPE_original_GraceStep
            end
            HumanoidMovement.__NULLSCAPE_grace_wings_hooked = false
        end
    end

    Logic.OriginalApplyFriction = nil
    Logic.OriginalStep = nil
    Logic.Hooked = false
end

function Logic.setMultiplier(value)
    Logic.AirControlMultiplier = math.clamp(tonumber(value) or 1.1, 1.1, 5)
end

return Logic
