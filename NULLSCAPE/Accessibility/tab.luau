return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Accessibility", 4483362458)
    
    Tab:CreateSection("Accessibility Features - Trợ năng")
    
    Tab:CreateToggle({
        Name = "Auto jump - Springer",
        CurrentValue = Controller.SpringerAutoJumpEnabled,
        Flag = "SpringerAutoJumpToggle",
        Callback = function(Value)
            Controller:SetSpringerAutoJump(Value)
        end
    })
end
