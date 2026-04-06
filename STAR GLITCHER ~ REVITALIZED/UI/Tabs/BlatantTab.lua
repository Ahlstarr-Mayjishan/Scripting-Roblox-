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

return function(Window, Options, killPartBypass)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)
    local statusLabel = Tab:CreateLabel("Zenith Status: Idle")
    local killPartLabel = Tab:CreateLabel("Kill Part Bypass: Idle")

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

    task.spawn(function()
        local lastKillPartText = nil
        while task.wait(0.2) do
            if killPartBypass then
                local nextText = "Kill Part Bypass: " .. tostring(killPartBypass.Status or "Idle")
                if nextText ~= lastKillPartText then
                    lastKillPartText = nextText
                    setLabelText(killPartLabel, nextText)
                end
            end
        end
    end)

    return Tab
end
