--[[
    AimbotTab.lua - Tab Aim
    Core assist mode and response controls.
]]

return function(Window, Options, Visuals)
    local Tab = Window:CreateTab("Aim", 4483362458)

    Tab:CreateSection("Assist Mode")

    Tab:CreateDropdown({
        Name = "Assist Mode",
        Options = {"Off", "Camera Lock", "Silent Aim", "Highlight Only"},
        CurrentOption = {"Off"},
        Flag = "AssistModeDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.AssistMode = selected
        end,
    })

    Tab:CreateToggle({
        Name = "Only Assist While Holding Right Mouse",
        CurrentValue = Options.HoldMouse2ToAssist,
        Flag = "HoldMouse2Toggle",
        Callback = function(Value)
            Options.HoldMouse2ToAssist = Value
        end,
    })

    Tab:CreateSection("Camera Lock")

    Tab:CreateSlider({
        Name = "Camera Lock Smoothness",
        Range = {1, 100},
        Increment = 1,
        Suffix = "%",
        CurrentValue = math.floor(Options.Smoothness * 100),
        Flag = "SmoothnessSlider",
        Callback = function(Value)
            Options.Smoothness = math.clamp(Value / 100, 0.01, 1)
        end,
    })

    return Tab
end
