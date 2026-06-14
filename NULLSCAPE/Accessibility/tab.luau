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

    Tab:CreateSection("Movement")

    Tab:CreateSlider({
        Name = "Momentum Reduction",
        Range = {0, 1},
        Increment = 0.1,
        CurrentValue = Controller.MomentumReduction or 0,
        Flag = "MomentumReductionSlider",
        Suffix = " ratio",
        Callback = function(Value)
            Controller:SetMomentumReduction(Value)
        end
    })
end
