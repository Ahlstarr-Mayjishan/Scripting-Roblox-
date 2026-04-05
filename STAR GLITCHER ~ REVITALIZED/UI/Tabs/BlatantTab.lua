--[[
    BlatantTab.lua - Tab Blatant & Bypass
    Contains only explicit bypass-style options.
]]

return function(Window, Options)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)
    local statusLabel = Tab:CreateLabel("Zenith Status: Idle")

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

    return Tab
end
