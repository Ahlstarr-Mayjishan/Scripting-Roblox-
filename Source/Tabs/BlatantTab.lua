--[[
    BlatantTab.lua — High Risk & Bypass Features
    Tạo tab Blatant & Anticheat Bypass trên Rayfield UI.
]]

return function(Window, Options, Visuals)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)

    Tab:CreateSection("🛡️ Anticheat Bypass")

    Tab:CreateToggle({
        Name = "Speed & Jump Spoof (Bypass)",
        CurrentValue = Options.SpeedSpoofEnabled,
        Flag = "SpeedSpoofToggle",
        Callback = function(Value)
            Options.SpeedSpoofEnabled = Value
            Rayfield:Notify({
                Title = "Bypass Mode",
                Content = Value and "Speed Spoofing: Active. Game scripts will read 16/50 stats." or "Speed Spoofing: Disabled.",
                Duration = 3,
                Image = 4483362458,
            })
        end,
    })

    Tab:CreateSection("🔥 Blatant Cheats")

    Tab:CreateToggle({
        Name = "Hitbox Expander",
        CurrentValue = Options.HitboxExpander,
        Flag = "HitboxExpanderToggle",
        Callback = function(Value)
            Options.HitboxExpander = Value
            if not Value then
                -- Reset hitboxes when disabled
                -- (Logic managed in Main or a separate module)
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Hitbox Size",
        Range = {1, 25},
        Increment = 1,
        Suffix = " studs",
        CurrentValue = Options.HitboxSize,
        Flag = "HitboxSizeSlider",
        Callback = function(Value)
            Options.HitboxSize = Value
        end,
    })

    Tab:CreateSection("💡 Info")
    Tab:CreateLabel("Bypass features attempt to hide your cheats from game scripts.")
    Tab:CreateLabel("Speed Multiplier in Player Tab is safer when used with Spoof.")

    return Tab
end
