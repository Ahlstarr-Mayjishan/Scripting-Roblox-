--[[
    AdjustmentsTab.lua — Tab Adjustments
    Smoothness, Distance, Target Part, Prediction settings.
]]

return function(Window, Options, Visuals, NPCTracker)
    local Tab = Window:CreateTab("Targeting", 4483362458)

    Tab:CreateSection("FOV")

    Tab:CreateToggle({
        Name = "Show FOV Circle",
        CurrentValue = Options.ShowFOV,
        Flag = "FOVToggle",
        Callback = function(Value)
            Options.ShowFOV = Value
            Visuals.FOVCircle.Visible = Value
        end,
    })

    Tab:CreateSlider({
        Name = "FOV Circle Size (Radius)",
        Range = {0, 1000},
        Increment = 10,
        Suffix = " Pixels",
        CurrentValue = Options.FOV,
        Flag = "FOVSlider",
        Callback = function(Value)
            Options.FOV = Value
            Visuals.FOVCircle.Radius = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Ignore Players Inside FOV",
        CurrentValue = Options.IgnorePlayersInFOV,
        Flag = "IgnorePlayersToggle",
        Callback = function(Value)
            Options.IgnorePlayersInFOV = Value
        end,
    })

    Tab:CreateSection("Target Part")

    Tab:CreateDropdown({
        Name = "Lock Onto Body Part",
        Options = {"HumanoidRootPart", "Torso", "Head"},
        CurrentOption = {"HumanoidRootPart"},
        Flag = "TargetPartDropdown",
        Callback = function(Value)
            Options.TargetPart = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateSection("Target Offset")

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

    Tab:CreateSection("Target Source")

    Tab:CreateToggle({
        Name = "Target Other Players (PvP Mode)",
        CurrentValue = Options.TargetPlayersToggle,
        Flag = "TargetPlayersFlag",
        Callback = function(Value)
            Options.TargetPlayersToggle = Value
            if NPCTracker and NPCTracker.ClearCache then
                NPCTracker:ClearCache()
            end
        end,
    })

    return Tab
end
