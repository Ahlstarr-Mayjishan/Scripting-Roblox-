return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Accessibility", 4483362458)
    
    Tab:CreateSection("Accessibility Features")
    
    Tab:CreateToggle({
        Name = "Auto jump - Springer",
        CurrentValue = Controller.SpringerAutoJumpEnabled,
        Flag = "SpringerAutoJumpToggle",
        Callback = function(Value)
            Controller:SetSpringerAutoJump(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Infinite Air Jump",
        Info = "Refills the native DoubleJump charge, preserving the game's animation and SFX.",
        CurrentValue = Controller.InfiniteAirJumpEnabled,
        Flag = "InfiniteAirJumpToggle",
        Callback = function(Value)
            Controller:SetInfiniteAirJump(Value)
        end
    })
end
