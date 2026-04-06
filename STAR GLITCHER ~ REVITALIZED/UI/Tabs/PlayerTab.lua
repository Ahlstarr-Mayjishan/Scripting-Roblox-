--[[
    PlayerTab.lua - Compatibility wrapper
    Job: Delegate Player tab construction to an injected controller.
]]

return function(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, zenith, controller)
    if controller and controller.Build then
        return controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, zenith)
    end

    error("PlayerTab controller was not provided", 2)
end
