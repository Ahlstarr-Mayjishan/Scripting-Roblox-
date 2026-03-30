return function(Window, Options)
    local Tab = Window:CreateTab("Prediction", 4483362458)

    Tab:CreateSection("Prediction Engine")

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

    Tab:CreateSection("Target Response")

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

    return Tab
end
