--[[
    PlayerTab.lua — Tab Player
    No Slowdown, No Delay, No Stun, Custom Move Speed.
    Updated: Active status monitoring for anti-debuffs.
]]

return function(Window, Options, noSlowdown, noStun)
    local Tab = Window:CreateTab("Player", 4483362458)

    -- ═══════════════════════════════════════════════════
    -- SECTION: MOVEMENT
    -- ═══════════════════════════════════════════════════
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
            if Value then Options.CustomMoveSpeedEnabled = false end
        end,
    })

    Tab:CreateSlider({
        Name = "Multiplier Factor",
        Range = {1, 5},
        Increment = 0.1,
        CurrentValue = Options.SpeedMultiplier or 1.0,
        Flag = "SpeedMultiplierFlag",
        Suffix = "x",
        Callback = function(Value)
            Options.SpeedMultiplier = Value
        end,
    })

    -- ═══════════════════════════════════════════════════
    -- SECTION: ANTI-DEBUFF
    -- ═══════════════════════════════════════════════════
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

    -- STATUS REFRESHER
    task.spawn(function()
        while true do
            if noSlowdown then
                slowdownLabel:Set("Slowdown Status: " .. tostring(noSlowdown.Status))
            end
            if noStun then
                stunLabel:Set("Stun Status: " .. tostring(noStun.Status))
            end
            task.wait(0.5)
        end
    end)

    -- ═══════════════════════════════════════════════════
    -- SECTION: UTILITIES
    -- ═══════════════════════════════════════════════════
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
