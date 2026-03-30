--[[
    MiscTab.lua — Tab Misc
    Rejoin, PvP mode toggle.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return function(Window)
    local Tab = Window:CreateTab("Misc", 4483362458)

    Tab:CreateSection("Utilities")

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

    return Tab
end
