--[[
    BlatantTab.lua - Tab Blatant & Bypass
    Contains only explicit bypass-style options.
]]

return function(Window, Options, apocalypse)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)

    Tab:CreateSection("Universal Hijacking")

    Tab:CreateToggle({
        Name = "Apocalypse Lock (Brilliance)",
        CurrentValue = Options.ApocalypseEnabled,
        Flag = "ApocalypseFlag",
        Callback = function(Value)
            Options.ApocalypseEnabled = Value
            if apocalypse then
                apocalypse:SetState(Value)
            end
            if Value then
                Rayfield:Notify({
                    Title = "Apocalypse Active",
                    Content = "Projectiles & Beams are now parasitically locked to bosses.",
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

    return Tab
end
