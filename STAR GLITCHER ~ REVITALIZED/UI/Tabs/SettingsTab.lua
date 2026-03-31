--[[
    SettingsTab.lua - Settings and script management
    UI toggle key, config actions, and maintenance tools.
]]

return function(Window, Options)
    local Tab = Window:CreateTab("Settings", 4483362458)

    Tab:CreateSection("UI & Safety")

    Tab:CreateDropdown({
        Name = "UI Toggle Key (saved for next reload)",
        Options = {
            "RightControl", "LeftControl", "RightShift", "LeftShift",
            "RightAlt", "LeftAlt", "Backquote", "Insert",
            "Home", "End", "PageUp", "PageDown",
            "F1", "F2", "F3", "F4", "F6", "F7", "F8", "F9", "F10"
        },
        CurrentOption = {Options.ToggleUIKey or "RightControl"},
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
                _G.BossAimAssist_Cleanup()
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
        Name = "Rejoin Server (Place Refresh)",
        Callback = function()
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            ts:Teleport(game.PlaceId, p)
        end,
    })

    Tab:CreateSection("Script Management")

    Tab:CreateButton({
        Name = "Install Auto-Execute",
        Callback = function()
            local command = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/STAR%20GLITCHER%20~%20REVITALIZED/Core/Main.lua"))()]]
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
