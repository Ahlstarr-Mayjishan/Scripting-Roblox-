--[[
    PlayerTab.lua — Tab Player
    No Slowdown, No Delay, No Stun, Custom Move Speed.
]]

return function(Window, Options, noSlowdown)
    local Tab = Window:CreateTab("Player", 4483362458)

    Tab:CreateSection("Movement")

    Tab:CreateToggle({
        Name = "Fixed Move Speed",
        CurrentValue = Options.CustomMoveSpeedEnabled,
        Flag = "CustomMoveSpeedEnabledFlag",
        Callback = function(Value)
            Options.CustomMoveSpeedEnabled = Value
            if Value then Options.SpeedMultiplierEnabled = false end
        end,
    })

    Tab:CreateSlider({
        Name = "Walk Speed (Fixed)",
        Range = {1, 250},
        Increment = 1,
        CurrentValue = Options.CustomMoveSpeed,
        Flag = "CustomMoveSpeedFlag",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.CustomMoveSpeed = Value
        end,
    })

    Tab:CreateSection("Legit Multiplier")

    Tab:CreateToggle({
        Name = "Speed Multiplier",
        CurrentValue = Options.SpeedMultiplierEnabled,
        Flag = "SpeedMultiplierEnabledFlag",
        Callback = function(Value)
            Options.SpeedMultiplierEnabled = Value
            if Value then Options.CustomMoveSpeedEnabled = false end
        end,
    })

    Tab:CreateSlider({
        Name = "Multiplier Factor",
        Range = {1, 5},
        Increment = 0.1,
        CurrentValue = Options.SpeedMultiplier,
        Flag = "SpeedMultiplierFlag",
        Suffix = "x",
        Callback = function(Value)
            Options.SpeedMultiplier = Value
        end,
    })

    Tab:CreateSection("Anti-Debuff")

    Tab:CreateToggle({
        Name = "No Slowdown",
        CurrentValue = Options.NoSlowdown,
        Flag = "NoSlowdownFlag",
        Callback = function(Value)
            Options.NoSlowdown = Value
        end,
    })

    Tab:CreateToggle({
        Name = "No Stun",
        CurrentValue = Options.NoStun,
        Flag = "NoStunFlag",
        Callback = function(Value)
            Options.NoStun = Value
        end,
    })

    Tab:CreateToggle({
        Name = "No Delay (Remove Debuffs)",
        CurrentValue = Options.NoDelay,
        Flag = "NoDelayFlag",
        Callback = function(Value)
            Options.NoDelay = Value
        end,
    })

    Tab:CreateSection("Utilities")

    if noSlowdown then
        Tab:CreateButton({
            Name = "Re-capture Base WalkSpeed",
            Callback = function()
                noSlowdown:CaptureBaseStats()
            end,
        })
    end

    return Tab
end
