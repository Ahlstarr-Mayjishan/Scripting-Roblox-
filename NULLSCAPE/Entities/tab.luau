-- [[
--  NULLSCAPE - Entities UI Tab
--  Đóng vai trò tạo tab "Miễn nhiễm thực thể" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Entitines", 4483362458)
    
    Tab:CreateSection("Entities Lists - Touch Type")
    
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
end
