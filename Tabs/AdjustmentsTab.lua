--[[
    AdjustmentsTab.lua — Tab Adjustments
    Smoothness, Distance, Target Part, Prediction settings.
]]

return function(Window, Options)
    local Tab = Window:CreateTab("Adjustments", 4483362458)

    Tab:CreateSection("Aim Behaviours")

    Tab:CreateSlider({
        Name = "Lock-On Smoothness",
        Range = {1, 100},
        Increment = 1,
        Suffix = "%",
        CurrentValue = math.floor(Options.Smoothness * 100),
        Flag = "SmoothnessSlider",
        Callback = function(Value)
            Options.Smoothness = math.clamp(Value / 100, 0.01, 1)
        end,
    })

    Tab:CreateSlider({
        Name = "Maximum Distance",
        Range = {100, 5000},
        Increment = 50,
        Suffix = " Studs",
        CurrentValue = Options.MaxDistance,
        Flag = "DistanceSlider",
        Callback = function(Value)
            Options.MaxDistance = Value
        end,
    })

    Tab:CreateSection("Target Offsets")

    Tab:CreateDropdown({
        Name = "Lock Onto Body Part",
        Options = {"HumanoidRootPart", "Torso", "Head"},
        CurrentOption = {"HumanoidRootPart"},
        Flag = "TargetPartDropdown",
        Callback = function(Value)
            Options.TargetPart = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateSlider({
        Name = "Raise/Lower Aim Point (Y Offset)",
        Range = {-50, 50},
        Increment = 5,
        Suffix = " (x0.1 Studs)",
        CurrentValue = 0,
        Flag = "YOffsetSlider",
        Callback = function(Value)
            Options.AimOffset = Value / 10
        end,
    })

    Tab:CreateSection("Aim Prediction")

    Tab:CreateToggle({
        Name = "Enable Aim Prediction",
        CurrentValue = Options.PredictionEnabled,
        Flag = "PredictToggle",
        Callback = function(Value)
            Options.PredictionEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Smart Prediction (Auto)",
        CurrentValue = Options.SmartPrediction,
        Flag = "SmartPredictToggle",
        Callback = function(Value)
            Options.SmartPrediction = Value
        end,
    })

    return Tab
end
