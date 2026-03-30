--[[
    BlatantTab.lua — Tab Blatant & Bypass
    Hitbox Expander (Removed), Speed Spoof, Speed Multiplier.
]]

return function(Window, Options, visuals)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)

    Tab:CreateSection("Movement Bypass")

    Tab:CreateToggle({
        Name = "Speed Spoof (Bypass)",
        CurrentValue = Options.SpeedSpoofEnabled,
        Flag = "SpeedSpoofFlag",
        Callback = function(Value)
            Options.SpeedSpoofEnabled = Value
            if Value then
                Rayfield:Notify({
                    Title = "Bypass Active",
                    Content = "Client-side WalkSpeed is now masked from server checks.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Enable Speed Multiplier",
        CurrentValue = Options.SpeedMultiplierEnabled,
        Flag = "SpeedMultiFlag",
        Callback = function(Value)
            Options.SpeedMultiplierEnabled = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Speed Multiplier Value",
        Range = {1, 10},
        Increment = 0.1,
        Suffix = "x Speed",
        CurrentValue = Options.SpeedMultiplier,
        Flag = "SpeedMultiVal",
        Callback = function(Value)
            Options.SpeedMultiplier = Value
        end,
    })

    Tab:CreateSection("Combat Cheats")
    
    Tab:CreateLabel("Notice: Use Hyper Silent Aim for 100% Hitrate.")

    return Tab
end
