--[[
    MiscTab.lua — Tab Misc
    Rejoin, PvP mode toggle.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return function(Window, Options, NPCTracker)
    local Tab = Window:CreateTab("Misc", 4483362458)

    Tab:CreateButton({
        Name = "Rejoin Server",
        Callback = function()
            local TeleportService = game:GetService("TeleportService")
            if #Players:GetPlayers() <= 1 then
                LocalPlayer:Kick("\nRejoining...")
                task.wait()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            else
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end
        end,
    })

    Tab:CreateSection("PvP Settings")

    Tab:CreateToggle({
        Name = "Target Other Players (PvP Mode)",
        CurrentValue = Options.TargetPlayersToggle,
        Flag = "TargetPlayersFlag",
        Callback = function(Value)
            Options.TargetPlayersToggle = Value
            NPCTracker:ClearCache()
        end,
    })

    return Tab
end
