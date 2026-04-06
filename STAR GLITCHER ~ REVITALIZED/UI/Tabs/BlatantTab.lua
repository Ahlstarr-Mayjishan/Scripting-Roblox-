--[[
    BlatantTab.lua - Tab Blatant & Bypass
    Contains only explicit bypass-style options.
]]

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

return function(Window, Options, killPartBypass, proactiveEvade, ultraHell)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)
    local statusLabel = Tab:CreateLabel("Zenith Status: Idle")
    local killPartLabel = Tab:CreateLabel("Kill Part Bypass: Idle")
    local proactiveEvadeLabel = Tab:CreateLabel("Proactive Evade: Idle")
    local ultraHellLabel = Tab:CreateLabel("UltraHell: Hit an enemy once to arm capture")

    Tab:CreateSection("Zenith Desync Architecture")

    Tab:CreateToggle({
        Name = "Zenith Desync (Soul Mode)",
        CurrentValue = Options.ZenithDesyncEnabled,
        Flag = "ZenithDesyncFlag",
        Callback = function(Value)
            Options.ZenithDesyncEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Soul Separated",
                    Content = "Your physical hitbox is now hidden. You are visually desynced.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Silent Damage Sync",
        CurrentValue = Options.SilentDamageEnabled,
        Flag = "SilentDamageFlag",
        Callback = function(Value)
            Options.SilentDamageEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Combat Sync Active",
                    Content = "Hitbox will flicker to targets for damage registration.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("Client Masking")

    Tab:CreateToggle({
        Name = "Speed Spoof (Bypass)",
        CurrentValue = Options.SpeedSpoofEnabled,
        Flag = "SpeedSpoofFlag",
        Callback = function(Value)
            Options.SpeedSpoofEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Kill Part Bypass",
        CurrentValue = Options.KillPartBypassEnabled,
        Flag = "KillPartBypassFlag",
        Callback = function(Value)
            Options.KillPartBypassEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Kill Part Bypass Active",
                    Content = "Touch/query kill parts are now being masked separately from noclip.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("Auto Evasion")

    Tab:CreateToggle({
        Name = "Proactive Evade",
        CurrentValue = Options.ProactiveEvadeEnabled,
        Flag = "ProactiveEvadeFlag",
        Callback = function(Value)
            Options.ProactiveEvadeEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Proactive Evade Active",
                    Content = "Your character will sidestep automatically without needing target detection.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Evade Stride",
        Range = {2, 8},
        Increment = 0.25,
        Suffix = "studs",
        CurrentValue = tonumber(Options.ProactiveEvadeStride) or 4.5,
        Flag = "ProactiveEvadeStrideFlag",
        Callback = function(Value)
            Options.ProactiveEvadeStride = tonumber(Value) or 4.5
        end,
    })

    Tab:CreateSlider({
        Name = "Evade Interval",
        Range = {0.2, 1.2},
        Increment = 0.05,
        Suffix = "s",
        CurrentValue = tonumber(Options.ProactiveEvadeInterval) or 0.42,
        Flag = "ProactiveEvadeIntervalFlag",
        Callback = function(Value)
            Options.ProactiveEvadeInterval = tonumber(Value) or 0.42
        end,
    })

    Tab:CreateSection("UltraHell Gamemode")

    Tab:CreateLabel("Deal damage once so the combat packet can be captured, then toggle UltraHell.")

    Tab:CreateToggle({
        Name = "UltraHell Multi-Hit",
        CurrentValue = Options.UltraHellEnabled,
        Flag = "UltraHellEnabledFlag",
        Callback = function(Value)
            Options.UltraHellEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "UltraHell Armed",
                    Content = "If no packet is captured yet, hit an enemy once first.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Multi Hit (Counts)",
        Range = {1, 100},
        Increment = 1,
        Suffix = " hits/s",
        CurrentValue = tonumber(Options.UltraHellHitsPerSecond) or 10,
        Flag = "UltraHellHitsPerSecondFlag",
        Callback = function(Value)
            Options.UltraHellHitsPerSecond = math.clamp(math.floor(tonumber(Value) or 10), 1, 100)
        end,
    })

    task.spawn(function()
        local lastKillPartText = nil
        local lastProactiveText = nil
        local lastUltraHellText = nil
        while task.wait(0.2) do
            if killPartBypass then
                local nextText = "Kill Part Bypass: " .. tostring(killPartBypass.Status or "Idle")
                if nextText ~= lastKillPartText then
                    lastKillPartText = nextText
                    setLabelText(killPartLabel, nextText)
                end
            end

            if proactiveEvade then
                local nextText = "Proactive Evade: " .. tostring(proactiveEvade.Status or "Idle")
                if nextText ~= lastProactiveText then
                    lastProactiveText = nextText
                    setLabelText(proactiveEvadeLabel, nextText)
                end
            end

            if ultraHell then
                local nextText = "UltraHell: " .. tostring(ultraHell.Status or "Idle")
                if nextText ~= lastUltraHellText then
                    lastUltraHellText = nextText
                    setLabelText(ultraHellLabel, nextText)
                end
            end
        end
    end)

    return Tab
end
