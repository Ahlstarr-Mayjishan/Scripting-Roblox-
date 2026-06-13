-- [[
--  NULLSCAPE - Entities UI Tab
--  Đóng vai trò tạo tab "Miễn nhiễm thực thể" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Miễn nhiễm thực thể", 4483362458)
    
    Tab:CreateSection("Cấu hình miễn nhiễm")
    
    Tab:CreateToggle({
        Name = "Kích hoạt miễn nhiễm",
        CurrentValue = Controller.Enabled,
        Flag = "EntityImmunityToggle",
        Callback = function(Value)
            Controller:Toggle(Value)
        end
    })
    
    Tab:CreateDropdown({
        Name = "Phương thức miễn nhiễm",
        Options = {
            "Vô hiệu hóa va chạm (Noclip)", 
            "Xóa sát thương chạm (Disable Touch)"
        },
        CurrentOption = {"Xóa sát thương chạm (Disable Touch)"},
        MultipleOptions = false,
        Flag = "EntityImmunityMethod",
        Callback = function(Option)
            local selection = Option[1]
            if selection == "Vô hiệu hóa va chạm (Noclip)" then
                Controller:SetMethod("Noclip")
            elseif selection == "Xóa sát thương chạm (Disable Touch)" then
                Controller:SetMethod("DisableTouch")
            end
        end
    })
end
