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
        Info = "Higher values make control easier. Values >= 70% remove the braking/turn animation.",
        Range = {0, 100},
        Increment = 10,
        CurrentValue = math.clamp((Controller.MomentumReduction or 0) * 100, 0, 100),
        Flag = "MomentumReductionSlider",
        Suffix = "%",
        Callback = function(Value)
            Controller:SetMomentumReduction(Value / 100)
        end
    })
    
    Tab:CreateLabel("Higher ratio = easier control. Setting to >= 70% will remove the braking animation.")
end
