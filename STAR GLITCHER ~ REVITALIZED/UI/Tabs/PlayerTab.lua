--[[
    PlayerTab.lua - Tab Player
    No Slowdown, No Delay, No Stun, Custom Move Speed.
    Updated: Active status monitoring for anti-debuffs.
]]

return function(Window, Options, noSlowdown, noStun, speedMultiplier)
    local Tab = Window:CreateTab("Player", 4483362458)

    Tab:CreateSection("Movement")

    Tab:CreateToggle({
        Name = "Fixed Move Speed",
        CurrentValue = Options.CustomMoveSpeedEnabled,
        Flag = "CustomMoveSpeedEnabledFlag",
        Callback = function(Value)
            Options.CustomMoveSpeedEnabled = Value
            if Value then
                Options.SpeedMultiplierEnabled = false
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Walk Speed (Fixed)",
        Range = { 1, 250 },
        Increment = 1,
        CurrentValue = Options.CustomMoveSpeed or 16,
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
            if Value then
                Options.CustomMoveSpeedEnabled = false
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Multiplier Factor",
        Range = { 1, 5 },
        Increment = 0.1,
        CurrentValue = Options.SpeedMultiplier or 1.0,
        Flag = "SpeedMultiplierFlag",
        Suffix = "x",
        Callback = function(Value)
            Options.SpeedMultiplier = Value
        end,
    })

    local speedMultiplierLabel = Tab:CreateLabel("Multi Speed Status: Idle")

    Tab:CreateSection("Anti-Debuff")

    local slowdownLabel = Tab:CreateLabel("No Slowdown: Idle")
    Tab:CreateToggle({
        Name = "No Slowdown",
        CurrentValue = Options.NoSlowdown,
        Flag = "NoSlowdownFlag",
        Callback = function(Value)
            Options.NoSlowdown = Value
        end,
    })

    local stunLabel = Tab:CreateLabel("No Stun: Idle")
    Tab:CreateToggle({
        Name = "No Stun",
        CurrentValue = Options.NoStun,
        Flag = "NoStunFlag",
        Callback = function(Value)
            Options.NoStun = Value
        end,
    })

    Tab:CreateToggle({
        Name = "No Delay (Attribute Cleaner)",
        CurrentValue = Options.NoDelay,
        Flag = "NoDelayFlag",
        Callback = function(Value)
            Options.NoDelay = Value
        end,
    })

    task.spawn(function()
        local lastSlowdownText
        local lastStunText
        local lastSpeedText

        while true do
            if noSlowdown then
                local nextText = "Slowdown Status: " .. tostring(noSlowdown.Status)
                if nextText ~= lastSlowdownText then
                    slowdownLabel:Set(nextText)
                    lastSlowdownText = nextText
                end
            end

            if noStun then
                local nextText = "Stun Status: " .. tostring(noStun.Status)
                if nextText ~= lastStunText then
                    stunLabel:Set(nextText)
                    lastStunText = nextText
                end
            end

            if speedMultiplier then
                local nextText = "Multi Speed Status: " .. tostring(speedMultiplier.Status)
                if nextText ~= lastSpeedText then
                    speedMultiplierLabel:Set(nextText)
                    lastSpeedText = nextText
                end
            end

            task.wait(0.5)
        end
    end)

    Tab:CreateSection("Maintenance")

    if noSlowdown then
        Tab:CreateButton({
            Name = "Re-capture Base Stats (Fixed Speed)",
            Callback = function()
                noSlowdown:CaptureBaseStats()
            end,
        })
    end

    return Tab
end
