--[[
    PlayerTab.lua — Tab Player
    No Slowdown, No Delay, No Stun, Custom Move Speed.
]]

return function(Window, Options, noSlowdown)
    local Tab = Window:CreateTab("Player", 4483362458)

    Tab:CreateSection("Movement")

    Tab:CreateToggle({
        Name = "Custom Move Speed",
        CurrentValue = Options.CustomMoveSpeedEnabled,
        Flag = "CustomMoveSpeedEnabledFlag",
        Callback = function(Value)
            Options.CustomMoveSpeedEnabled = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Walk Speed",
        Range = {1, 200},
        Increment = 1,
        CurrentValue = Options.CustomMoveSpeed,
        Flag = "CustomMoveSpeedFlag",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.CustomMoveSpeed = Value
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
