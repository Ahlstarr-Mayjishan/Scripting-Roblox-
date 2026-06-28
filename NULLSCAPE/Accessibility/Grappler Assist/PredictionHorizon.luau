--!nocheck
--[[
 NULLSCAPE - Grappler Assist Prediction Horizon
 Converts current movement state into short/tactical/route/coarse planning windows.
]]

local PredictionHorizon = {}

local function horizontalSpeed(rootPart)
    local velocity = rootPart and rootPart.Velocity
    if typeof(velocity) ~= "Vector3" then
        return 0
    end

    return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

function PredictionHorizon.get(_deps, grapple, profile)
    local rootPart = grapple and grapple.RootPart
    local movement = grapple and grapple.Movement
    local speed = horizontalSpeed(rootPart)
    local route = math.clamp(speed / 55, 1.2, 4.2)
    if profile and profile.LowGravity then
        route *= 1.25
    end
    if movement and (movement.grappling == true or grapple.jumpPadReel == true) then
        route *= 1.15
    end

    route = math.clamp(route, 1.2, 4.8)
    local tactical = math.clamp(route * 0.58, 1.0, 2.2)
    local short = math.clamp(route * 0.24, 0.25, 0.85)
    local coarse = math.clamp(route * 1.35, 2.0, 6.0)

    return {
        Speed = speed,
        Short = short,
        Tactical = tactical,
        Route = route,
        Coarse = coarse,
        Summary = string.format("H%.1f/%.1f/%.1f", short, tactical, route),
    }
end

function PredictionHorizon.getPanicLookaheads(horizon)
    horizon = horizon or {}
    local short = tonumber(horizon.Short) or 0.45
    local tactical = tonumber(horizon.Tactical) or 1.3
    local route = tonumber(horizon.Route) or 2.2
    return {
        math.clamp(short * 0.75, 0.16, 0.65),
        math.clamp(tactical * 0.55, 0.32, 1.2),
        math.clamp(route * 0.68, 0.52, 2.8),
        math.clamp(route, 1.0, 4.2),
    }
end

function PredictionHorizon.snapshot(horizon)
    if not horizon then
        return "Horizon:pending"
    end

    return tostring(horizon.Summary or "Horizon")
end

return PredictionHorizon
