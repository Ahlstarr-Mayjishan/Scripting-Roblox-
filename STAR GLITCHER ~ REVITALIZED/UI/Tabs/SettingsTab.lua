--[[
    SettingsTab.lua - Settings and script management
    UI toggle key, config actions, and maintenance tools.
]]

return function(Window, Options, cleaner, resourceManager)
    local Tab = Window:CreateTab("Settings", 4483362458)

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

    Tab:CreateSection("Optimization & Safety")

    local cleanerLabel = Tab:CreateLabel("Cleanup Status: Idle")
    local resourceLabel = Tab:CreateLabel("Resource Manager: Idle")

    Tab:CreateToggle({
        Name = "Auto-Clean Debris (60s interval)",
        CurrentValue = Options.AutoCleanEnabled,
        Flag = "AutoCleanFlag",
        Callback = function(Value)
            Options.AutoCleanEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Smart Cleanup Scheduler",
        CurrentValue = Options.SmartCleanupEnabled ~= false,
        Flag = "SmartCleanupEnabledFlag",
        Callback = function(Value)
            Options.SmartCleanupEnabled = Value
        end,
    })

    Tab:CreateButton({
        Name = "Clean Memory & Debris Now",
        Callback = function()
            if cleaner then
                local destroyed, queued, pending = cleaner:Clean()
                Rayfield:Notify({
                    Title = "Cleanup Scheduled",
                    Content = string.format(
                        "Destroyed %d now, queued %d, pending %d for smoother cleanup.",
                        destroyed or 0,
                        queued or 0,
                        pending or 0
                    ),
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("UI & Controls")

    Tab:CreateDropdown({
        Name = "UI Toggle Key (saved for next reload)",
        Options = {
            "RightControl", "LeftControl", "RightShift", "LeftShift",
            "RightAlt", "LeftAlt", "Backquote", "Insert",
            "Home", "End", "PageUp", "PageDown",
            "F1", "F2", "F3", "F4", "F6", "F7", "F8", "F9", "F10",
        },
        CurrentOption = { Options.ToggleUIKey or "RightControl" },
        Flag = "ToggleUIKey",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.ToggleUIKey = selected
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = "UI Key Updated",
                    Content = "UI toggle key saved as " .. tostring(selected) .. ". It applies immediately and will persist after reload.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateButton({
        Name = "Destroy Script (Emergency Stop)",
        Callback = function()
            if _G.BossAimAssist_Cleanup then
                _G.BossAimAssist_Cleanup(true)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Clean + Update Script",
        Callback = function()
            if _G.BossAimAssist_Update then
                _G.BossAimAssist_Update()
            elseif _G.BossAimAssist_Cleanup then
                _G.BossAimAssist_Cleanup(true)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Check for Updates",
        Callback = function()
            if _G.BossAimAssist_CheckForUpdates then
                _G.BossAimAssist_CheckForUpdates(true)
            elseif Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = "Updater Unavailable",
                    Content = "This runtime does not expose the update checker yet. Reload from Main.lua.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end,
    })

    Tab:CreateSection("Configuration")

    Tab:CreateButton({
        Name = "Save Current Config",
        Callback = function()
            Rayfield:SaveConfiguration()
        end,
    })

    Tab:CreateButton({
        Name = "Rejoin Server (Same Instance)",
        Callback = function()
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
        end,
    })

    Tab:CreateButton({
        Name = "Server Hop (Join New Instance)",
        Callback = function()
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            local http = game:GetService("HttpService")

            pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
                local content = game:HttpGet(url)
                local data = http:JSONDecode(content)

                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        ts:TeleportToPlaceInstance(game.PlaceId, s.id, p)
                        return
                    end
                end

                Rayfield:Notify({
                    Title = "Server Hop Failed",
                    Content = "No suitable new servers found at this time.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end)
        end,
    })

    Tab:CreateSection("Script Management")

    task.spawn(function()
        local lastCleanerText
        local lastResourceText

        while true do
            if cleaner then
                local nextText = "Cleanup Status: " .. tostring(cleaner.Status)
                if nextText ~= lastCleanerText then
                    setLabelText(cleanerLabel, nextText)
                    lastCleanerText = nextText
                end
            end
            if resourceManager then
                local nextText = string.format(
                    "Resource Manager: %s",
                    tostring(resourceManager.Status)
                )
                if nextText ~= lastResourceText then
                    setLabelText(resourceLabel, nextText)
                    lastResourceText = nextText
                end
            end
            task.wait(0.5)
        end
    end)

    Tab:CreateButton({
        Name = "Install Auto-Execute",
        Callback = function()
            local command = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/STAR%20GLITCHER%20~%20REVITALIZED/Main.lua?v=" .. tostring(os.time())))()]]
            if writefile then
                pcall(function()
                    writefile("BossAimAssist_Loader.lua", command)
                    Rayfield:Notify({
                        Title = "Success",
                        Content = "Loader saved to workspace/BossAimAssist_Loader.lua. Move this to your autoexec folder.",
                        Duration = 5,
                        Image = 4483362458,
                    })
                end)
            else
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Your executor does not support writefile.",
                    Duration = 5,
                    Image = 4483362458,
                })
            end
        end,
    })

    return Tab
end
