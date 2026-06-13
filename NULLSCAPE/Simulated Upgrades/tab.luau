-- [[
--  NULLSCAPE - Simulated Upgrades & Radar UI Tab
--  Đóng vai trò tạo tab "Mô phỏng Upgrades & Radar" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Simulated Upgrades & Radar", 4483362458)
    
    Tab:CreateSection("Custom ESP Locator")
    
    Tab:CreateDropdown({
        Name = "Select ESP Type",
        Options = {"Gift", "Cadence", "Altar"},
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "ESPSelectionDropdown",
        Callback = function(SelectedOptions)
            local giftSelected = table.find(SelectedOptions, "Gift") ~= nil
            local cadenceSelected = table.find(SelectedOptions, "Cadence") ~= nil
            local altarSelected = table.find(SelectedOptions, "Altar") ~= nil
            
            Controller:SetGiftESP(giftSelected)
            Controller:SetCadenceESP(cadenceSelected)
            Controller:SetAltarESP(altarSelected)
        end
    })
    
    Tab:CreateDropdown({
        Name = "ESP Render Style",
        Options = {"Highlight", "Dot", "Ping"},
        CurrentOption = Controller.ESPStyle == "Highlight" and "Highlight" or (Controller.ESPStyle == "Ping" and "Ping" or "Dot"),
        MultipleOptions = false,
        Flag = "ESPStyleDropdown",
        Callback = function(Option)
            local selectedStyle = Option
            if typeof(Option) == "table" then
                selectedStyle = Option[1]
            end
            if selectedStyle == "Highlight" then
                Controller:SetESPStyle("Highlight")
            elseif selectedStyle == "Dot" then
                Controller:SetESPStyle("Dot")
            elseif selectedStyle == "Ping" then
                Controller:SetESPStyle("Ping")
            end
        end
    })

    Tab:CreateSection("Altar Settings")
    
    Tab:CreateDropdown({
        Name = "Select Altar Highlight",
        Options = {"All", "Purgatory", "Chance", "Chaos", "Echo", "Passage", "Protection", "Purification"},
        CurrentOption = "All",
        MultipleOptions = false,
        Flag = "AltarFilterDropdown",
        Callback = function(Option)
            local unlockController = Client.Modules.UnlockController
            if unlockController then
                unlockController:SetAltarFilter(Option)
            end
        end
    })
end
