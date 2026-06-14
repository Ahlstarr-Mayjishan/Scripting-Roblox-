return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Entities", 4483362458)
    
    Tab:CreateSection("Entities List - Touch Immunity")
    
    Tab:CreateToggle({
        Name = "Baby",
        CurrentValue = Controller.BabyImmune,
        Flag = "ImmunityBabyToggle",
        Callback = function(Value)
            Controller:SetImmunity("Baby", Value)
        end
    })
    
    Tab:CreateToggle({
        Name = "Bell",
        CurrentValue = Controller.BellImmune,
        Flag = "ImmunityBellToggle",
        Callback = function(Value)
            Controller:SetImmunity("Bell", Value)
        end
    })
    
    Tab:CreateToggle({
        Name = "Mart",
        CurrentValue = Controller.MartImmune,
        Flag = "ImmunityMartToggle",
        Callback = function(Value)
            Controller:SetImmunity("Mart", Value)
        end
    })
    
    Tab:CreateSection("Entities - Client Side")

    Tab:CreateToggle({
        Name = "ICBM",
        CurrentValue = Controller.ICBMImmune,
        Flag = "ImmunityICBMToggle",
        Callback = function(Value)
            Controller:SetImmunity("ICBM", Value)
        end
    })
    
    Tab:CreateToggle({
        Name = "Springer",
        CurrentValue = Controller.SpringerImmune,
        Flag = "ImmunitySpringerToggle",
        Callback = function(Value)
            Controller:SetImmunity("Springer", Value)
        end
    })

    Tab:CreateToggle({
        Name = "Skinwalker (Husk)",
        CurrentValue = Controller.SkinwalkerImmune,
        Flag = "ImmunitySkinwalkerToggle",
        Callback = function(Value)
            Controller:SetImmunity("Skinwalker", Value)
        end
    })

    Tab:CreateDropdown({
        Name = "Springer Mode",
        Options = {"Blatant", "Legit"},
        CurrentOption = Controller.SpringerImmunityMode or "Legit",
        MultipleOptions = false,
        Flag = "SpringerImmunityModeDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetSpringerImmunityMode(selected)
        end
    })
end
