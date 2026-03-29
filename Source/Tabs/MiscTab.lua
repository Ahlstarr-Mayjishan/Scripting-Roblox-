--[[
    MiscTab.lua — Tab Misc
    Rejoin, PvP mode toggle, No Slowdown/Delay.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return function(Window, Options, NPCTracker, noSlowdown)
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
            NPCTracker:RescanFolder()
        end,
    })

    Tab:CreateSection("Anti-Debuff")

    Tab:CreateToggle({
        Name = "No Slowdown",
        CurrentValue = Options.NoSlowdown,
        Flag = "NoSlowdownFlag",
        Callback = function(Value)
            Options.NoSlowdown = Value
        end,
    })

    Tab:CreateToggle({
        Name = "No Delay (Remove Stun/Freeze)",
        CurrentValue = Options.NoDelay,
        Flag = "NoDelayFlag",
        Callback = function(Value)
            Options.NoDelay = Value
        end,
    })

    if noSlowdown then
        Tab:CreateButton({
            Name = "Re-capture Base WalkSpeed",
            Callback = function()
                noSlowdown:CaptureBaseStats()
            end,
        })
    end

    return Tab
end
