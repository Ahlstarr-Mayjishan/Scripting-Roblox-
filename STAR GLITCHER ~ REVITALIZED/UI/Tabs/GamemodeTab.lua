--[[
    GamemodeTab.lua - Tab for Game-Specific Exploits
    Contains UltraHell and Kill Part Bypass.
]]

local function setLabelText(label, text)
    if not label then return end
    if type(label) == "table" and type(label.Set) == "function" then
        pcall(label.Set, label, text)
        return
    end
end

return function(Window, Options, killPartBypass, ultraHell)
    local Tab = Window:CreateTab("Gamemode", 4483362458)
    
    Tab:CreateSection("Bypasses")

    Tab:CreateToggle({
        Name = "Kill Part Bypass",
        CurrentValue = Options.KillPartBypassEnabled or false,
        Flag = "KillPartBypassFlag",
        Callback = function(Value) Options.KillPartBypassEnabled = Value end,
    })

    Tab:CreateSection("UltraHell Gamemode")

    Tab:CreateLabel("Deal damage once to capture combat packet, then toggle UltraHell.")

    Tab:CreateToggle({
        Name = "UltraHell Multi-Hit",
        CurrentValue = Options.UltraHellEnabled or false,
        Flag = "UltraHellEnabledFlag",
        Callback = function(Value)
            Options.UltraHellEnabled = Value
            if Value and getgenv().Rayfield then
                getgenv().Rayfield:Notify({
                    Title = "UltraHell Armed",
                    Content = "Hit an enemy once to begin multi-hit cycle.",
                    Duration = 4,
                })
            end
        end,
    })

    Tab:CreateSection("Custom Value")

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

    Tab:CreateSection("Status Scripts")

    local killPartLabel = Tab:CreateLabel("Kill Part Bypass: Idle")
    local ultraHellLabel = Tab:CreateLabel("UltraHell: Waiting for capture...")

    -- Status Loop
    task.spawn(function()
        local lastK = ""
        local lastU = ""
        while task.wait(0.4) do
            if killPartBypass then
                local txt = "Kill Part Bypass: " .. tostring(killPartBypass.Status or "Idle")
                if txt ~= lastK then lastK = txt; setLabelText(killPartLabel, txt) end
            end
            if ultraHell then
                local txt = "UltraHell: " .. tostring(ultraHell.Status or "Idle")
                if txt ~= lastU then lastU = txt; setLabelText(ultraHellLabel, txt) end
            end
        end
    end)

    return Tab
end
