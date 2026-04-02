--[[
    PlayerTab.lua - Tab Player
    No Slowdown, No Delay, No Stun, Custom Move Speed.
    Updated: Active status monitoring for anti-debuffs.
]]

return function(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost)
    local Tab = Window:CreateTab("Player", 4483362458)

    local function setLabelText(label, text)
        if not label then
            return
        end

        if type(label) == "table" and type(label.Set) == "function" then
            local ok = pcall(function()
                label:Set(text)
            end)
            if ok then
                return
            end
        end

        if typeof(label) == "Instance" then
            local textLabel = label:IsA("TextLabel") and label or label:FindFirstChildWhichIsA("TextLabel", true)
            if textLabel then
                textLabel.Text = text
            end
        end
    end

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

    Tab:CreateSection("Mobility")

    Tab:CreateToggle({
        Name = "Jump Boost",
        CurrentValue = Options.JumpBoostEnabled,
        Flag = "JumpBoostEnabledFlag",
        Callback = function(Value)
            Options.JumpBoostEnabled = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Jump Power",
        Range = { 1, 300 },
        Increment = 1,
        CurrentValue = Options.JumpBoostPower or 70,
        Flag = "JumpBoostPowerFlag",
        Callback = function(Value)
            Options.JumpBoostPower = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Float",
        CurrentValue = Options.FloatEnabled,
        Flag = "FloatEnabledFlag",
        Callback = function(Value)
            Options.FloatEnabled = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Float Fall Speed",
        Range = { 0, 40 },
        Increment = 1,
        CurrentValue = Options.FloatFallSpeed or 8,
        Flag = "FloatFallSpeedFlag",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.FloatFallSpeed = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Custom Gravity",
        CurrentValue = Options.GravityEnabled,
        Flag = "GravityEnabledFlag",
        Callback = function(Value)
            Options.GravityEnabled = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Gravity Value",
        Range = { 0, 500 },
        Increment = 1,
        CurrentValue = Options.GravityValue or 196.2,
        Flag = "GravityValueFlag",
        Callback = function(Value)
            Options.GravityValue = Value
        end,
    })

    local jumpBoostLabel = Tab:CreateLabel("Jump Boost Status: Idle")
    local floatLabel = Tab:CreateLabel("Float Status: Idle")
    local gravityLabel = Tab:CreateLabel("Gravity Status: Idle")

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
        local lastJumpText
        local lastFloatText
        local lastGravityText

        while true do
            if noSlowdown then
                local nextText = "Slowdown Status: " .. tostring(noSlowdown.Status)
                if nextText ~= lastSlowdownText then
                    setLabelText(slowdownLabel, nextText)
                    lastSlowdownText = nextText
                end
            end

            if noStun then
                local nextText = "Stun Status: " .. tostring(noStun.Status)
                if nextText ~= lastStunText then
                    setLabelText(stunLabel, nextText)
                    lastStunText = nextText
                end
            end

            if speedMultiplier then
                local nextText = "Multi Speed Status: " .. tostring(speedMultiplier.Status)
                if nextText ~= lastSpeedText then
                    setLabelText(speedMultiplierLabel, nextText)
                    lastSpeedText = nextText
                end
            end

            if jumpBoost then
                local nextText = "Jump Boost Status: " .. tostring(jumpBoost.Status)
                if nextText ~= lastJumpText then
                    setLabelText(jumpBoostLabel, nextText)
                    lastJumpText = nextText
                end
            end

            if floatController then
                local nextText = "Float Status: " .. tostring(floatController.Status)
                if nextText ~= lastFloatText then
                    setLabelText(floatLabel, nextText)
                    lastFloatText = nextText
                end
            end

            if gravityController then
                local nextText = "Gravity Status: " .. tostring(gravityController.Status)
                if nextText ~= lastGravityText then
                    setLabelText(gravityLabel, nextText)
                    lastGravityText = nextText
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
