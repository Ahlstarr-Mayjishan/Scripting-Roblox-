-- [[
--  NULLSCAPE - Unlock & Radar UI Tab
--  Đóng vai trò tạo tab "Mở khóa & Radar" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Mở khóa & Radar", 4483362458)
    
    Tab:CreateSection("Định vị Custom ESP")
    
    Tab:CreateDropdown({
        Name = "Chọn Loại ESP (Định vị)",
        Options = {"Hộp quà (Gift)", "Nhạc cụ (Cadence)", "Đàn tế (Altar)"},
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "ESPSelectionDropdown",
        Callback = function(SelectedOptions)
            local giftSelected = table.find(SelectedOptions, "Hộp quà (Gift)") ~= nil
            local cadenceSelected = table.find(SelectedOptions, "Nhạc cụ (Cadence)") ~= nil
            local altarSelected = table.find(SelectedOptions, "Đàn tế (Altar)") ~= nil
            
            Controller:SetGiftESP(giftSelected)
            Controller:SetCadenceESP(cadenceSelected)
            Controller:SetAltarESP(altarSelected)
        end
    })
    
    Tab:CreateDropdown({
        Name = "Chế độ hiển thị ESP",
        Options = {"Highlight (Bo viền)", "Dot (Dấu chấm)"},
        CurrentOption = "Highlight (Bo viền)",
        MultipleOptions = false,
        Flag = "ESPStyleDropdown",
        Callback = function(Option)
            if Option == "Highlight (Bo viền)" then
                Controller.ESPStyle = "Highlight"
            else
                Controller.ESPStyle = "Dot"
            end
        end
    })
end
