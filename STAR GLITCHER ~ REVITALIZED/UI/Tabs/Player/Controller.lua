--[[
    Controller.lua - Player tab controller
    Job: Compose layout and status refresh helpers for the Player tab.
]]

local Controller = {}
Controller.__index = Controller

function Controller.new(layout, statusLoop, labelUtils)
    local self = setmetatable({}, Controller)
    self.Layout = layout
    self.StatusLoop = statusLoop
    self.LabelUtils = labelUtils
    return self
end

function Controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost)
    local Tab = Window:CreateTab("Player", 4483362458)
    local refs = self.Layout.Build(Tab, Options)

    self.StatusLoop.Start(refs, {
        noSlowdown = noSlowdown,
        noStun = noStun,
        speedMultiplier = speedMultiplier,
        gravityController = gravityController,
        floatController = floatController,
        jumpBoost = jumpBoost,
    }, self.LabelUtils)

    return Tab
end

return Controller
