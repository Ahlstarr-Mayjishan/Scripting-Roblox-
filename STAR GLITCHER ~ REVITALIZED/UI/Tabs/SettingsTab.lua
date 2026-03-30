--[[
    SettingsTab.lua — OOP Configuration Management
    Includes Auto-Execute install/uninstall functionality.
]]

return function(Window, Options)
    local Tab = Window:CreateTab("Settings", 4483362458)

    Tab:CreateSection("Script Management")

    Tab:CreateButton({
        Name = "Install Auto-Execute",
        Callback = function()
            local command = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/Source/Main.lua"))()]]
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

    Tab:CreateSection("UI Settings")

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

    return Tab
end
