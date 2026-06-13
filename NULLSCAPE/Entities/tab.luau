-- [[
--  NULLSCAPE - Entities UI Tab
--  Đóng vai trò tạo tab "Miễn nhiễm thực thể" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Miễn nhiễm thực thể", 4483362458)
    
    Tab:CreateSection("Danh sách thực thể")
    
    Tab:CreateToggle({
        Name = "Miễn nhiễm Baby",
        CurrentValue = Controller.BabyImmune,
        Flag = "ImmunityBabyToggle",
        Callback = function(Value)
            Controller:SetImmunity("Baby", Value)
        end
    })
    
    Tab:CreateToggle({
        Name = "Miễn nhiễm Bell",
        CurrentValue = Controller.BellImmune,
        Flag = "ImmunityBellToggle",
        Callback = function(Value)
            Controller:SetImmunity("Bell", Value)
        end
    })
    
    Tab:CreateToggle({
        Name = "Miễn nhiễm Mart",
        CurrentValue = Controller.MartImmune,
        Flag = "ImmunityMartToggle",
        Callback = function(Value)
            Controller:SetImmunity("Mart", Value)
        end
    })
end
