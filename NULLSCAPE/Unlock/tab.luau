-- [[
--  NULLSCAPE - Unlock & Radar UI Tab
--  Đóng vai trò tạo tab "Mở khóa & Radar" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Mở khóa & Radar", 4483362458)
    
    Tab:CreateSection("Radar - Fake")
    
    Tab:CreateToggle({
        Name = "Radar Gift",
        CurrentValue = Controller.GiftESPEnabled,
        Flag = "GiftESPToggle",
        Callback = function(Value)
            Controller:SetGiftESP(Value)
        end
    })
    
    Tab:CreateToggle({
        Name = "Cadence",
        CurrentValue = Controller.CadenceESPEnabled,
        Flag = "CadenceESPToggle",
        Callback = function(Value)
            Controller:SetCadenceESP(Value)
        end
    })
    
    Tab:CreateToggle({
        Name = "Định vị Đàn tế (Altar ESP)",
        CurrentValue = Controller.AltarESPEnabled,
        Flag = "AltarESPToggle",
        Callback = function(Value)
            Controller:SetAltarESP(Value)
        end
    })
end
