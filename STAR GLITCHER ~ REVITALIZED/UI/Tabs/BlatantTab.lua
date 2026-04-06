--[[
    BlatantTab.lua - Tab Blatant & Bypass (Improved v7.1)
    Contains explicit bypass-style options and UltraHell Gamemode.
]]

local function setLabelText(label, text)
    if not label then return end
    if type(label) == "table" and type(label.Set) == "function" then
        pcall(label.Set, label, text)
        return
    end
    if typeof(label) == "Instance" then
        local textLabel = label:IsA("TextLabel") and label or label:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then textLabel.Text = text end
    end
end

return function(Window, Options, killPartBypass, proactiveEvade, ultraHell)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)
    
    -- Status Labels
    local killPartLabel = Tab:CreateLabel("Kill Part Bypass: Idle")
    local proactiveEvadeLabel = Tab:CreateLabel("Proactive Evade: Idle")
    local ultraHellLabel = Tab:CreateLabel("UltraHell: Waiting for capture...")

    Tab:CreateSection("Zenith Desync Architecture")

    Tab:CreateToggle({
        Name = "Zenith Desync (Soul Mode)",
        CurrentValue = Options.ZenithDesyncEnabled or false,
        Flag = "ZenithDesyncFlag",
        Callback = function(Value)
            Options.ZenithDesyncEnabled = Value
            if Value and Rayfield then
                Rayfield:Notify({
                    Title = "Soul Separated",
                    Content = "Your physical hitbox is now hidden. You are visually desynced.",
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Silent Damage Sync",
        CurrentValue = Options.SilentDamageEnabled or false,
        Flag = "SilentDamageFlag",
        Callback = function(Value)
            Options.SilentDamageEnabled = Value
        end,
    })

    Tab:CreateSection("Client Masking")

    Tab:CreateToggle({
        Name = "Speed Spoof (Bypass)",
        CurrentValue = Options.SpeedSpoofEnabled or false,
        Flag = "SpeedSpoofFlag",
        Callback = function(Value) Options.SpeedSpoofEnabled = Value end,
    })

    Tab:CreateToggle({
        Name = "Kill Part Bypass",
        CurrentValue = Options.KillPartBypassEnabled or false,
        Flag = "KillPartBypassFlag",
        Callback = function(Value) Options.KillPartBypassEnabled = Value end,
    })

    Tab:CreateSection("Auto Evasion")

    Tab:CreateToggle({
        Name = "Proactive Evade",
        CurrentValue = Options.ProactiveEvadeEnabled or false,
        Flag = "ProactiveEvadeFlag",
        Callback = function(Value) Options.ProactiveEvadeEnabled = Value end,
    })

    Tab:CreateSlider({
        Name = "Evade Stride",
        Range = {2, 8},
        Increment = 1,
        Suffix = " studs",
        CurrentValue = math.floor(tonumber(Options.ProactiveEvadeStride) or 4.5),
        Flag = "ProactiveEvadeStrideFlag",
        Callback = function(Value) Options.ProactiveEvadeStride = tonumber(Value) or 4 end,
    })

    Tab:CreateSlider({
        Name = "Evade Interval (x0.1s)",
        Range = {2, 12},
        Increment = 1,
        Suffix = " (divide by 10)",
        CurrentValue = math.floor((tonumber(Options.ProactiveEvadeInterval) or 0.42) * 10),
        Flag = "ProactiveEvadeIntervalFlag",
        Callback = function(Value)
            local actualInterval = tonumber(Value) / 10
            Options.ProactiveEvadeInterval = actualInterval
        end,
    })

    -- CRITICAL FIX: Ensure UltraHell Section is explicitly created
    Tab:CreateSection("UltraHell Gamemode")

    Tab:CreateLabel("Deal damage once to capture combat packet, then toggle UltraHell.")

    Tab:CreateToggle({
        Name = "UltraHell Multi-Hit",
        CurrentValue = Options.UltraHellEnabled or false,
        Flag = "UltraHellEnabledFlag",
        Callback = function(Value)
            Options.UltraHellEnabled = Value
            if Value and Rayfield then
                Rayfield:Notify({
                    Title = "UltraHell Armed",
                    Content = "Hit an enemy once to begin multi-hit cycle.",
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Multi Hit Rate",
        Range = {1, 100},
        Increment = 1,
        Suffix = " hits/s",
        CurrentValue = tonumber(Options.UltraHellHitsPerSecond) or 10,
        Flag = "UltraHellHitsPerSecondFlag",
        Callback = function(Value)
            Options.UltraHellHitsPerSecond = Value
        end,
    })

    -- Background Status Loop
    task.spawn(function()
        local lastK = ""
        local lastP = ""
        local lastU = ""
        while task.wait(0.3) do
            if killPartBypass then
                local txt = "Kill Part Bypass: " .. tostring(killPartBypass.Status or "Idle")
                if txt ~= lastK then lastK = txt; setLabelText(killPartLabel, txt) end
            end
            if proactiveEvade then
                local txt = "Proactive Evade: " .. tostring(proactiveEvade.Status or "Idle")
                if txt ~= lastP then lastP = txt; setLabelText(proactiveEvadeLabel, txt) end
            end
            if ultraHell then
                local txt = "UltraHell: " .. tostring(ultraHell.Status or "Idle")
                if txt ~= lastU then lastU = txt; setLabelText(ultraHellLabel, txt) end
            end
        end
    end)

    return Tab
end
