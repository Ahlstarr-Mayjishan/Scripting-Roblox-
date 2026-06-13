-- [[
--  NULLSCAPE - Unlock & Radar UI Tab
--  Đóng vai trò tạo tab "Mở khóa & Radar" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Mở khóa & Radar", 4483362458)
    
    Tab:CreateSection("Bẻ khóa Game")
    
    Tab:CreateToggle({
        Name = "Bỏ qua tiến trình Radar",
        CurrentValue = Controller.RadarSpoofEnabled,
        Flag = "RadarSpoofToggle",
        Callback = function(Value)
            Controller:SetRadarSpoof(Value)
        end
    })
    
    Tab:CreateSection("Định vị Custom ESP")
    
    Tab:CreateToggle({
        Name = "Định vị Hộp quà (Gift ESP)",
        CurrentValue = Controller.GiftESPEnabled,
        Flag = "GiftESPToggle",
        Callback = function(Value)
            Controller:SetGiftESP(Value)
        end
    })
    
    Tab:CreateButton({
        Name = "Tạo Hộp quà Thử nghiệm (Client-Side)",
        Callback = function()
            Controller:SpawnTestGift()
        end
    })
    
    Tab:CreateToggle({
        Name = "Định vị Nhạc cụ Cadence",
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
