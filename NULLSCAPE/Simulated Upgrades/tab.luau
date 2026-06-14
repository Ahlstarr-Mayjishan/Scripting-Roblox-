-- [[
--  NULLSCAPE - Simulated Upgrades & Radar UI Tab
--  Đóng vai trò tạo tab "Mô phỏng Upgrades & Radar" trên giao diện Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Upgrade Simulations", 4483362458)
    
    Tab:CreateSection("Radar Master Switch")
    
    Tab:CreateToggle({
        Name = "Enable Radar",
        CurrentValue = Controller.RadarEnabled,
        Flag = "RadarEnabledToggle",
        Callback = function(Value)
            Controller:SetRadarEnabled(Value)
        end
    })
    
    Tab:CreateSection("Custom ESP Locator")
    
    local ESPSelection
    local isSettingESP = false
    ESPSelection = Tab:CreateDropdown({
        Name = "Select ESP Type",
        Options = {"Gift", "Cadence", "Altar"},
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "ESPSelectionDropdown",
        Callback = function(SelectedOptions)
            -- Thiết lập các trạng thái tương ứng trong Controller
            local giftSelected = table.find(SelectedOptions, "Gift") ~= nil
            local cadenceSelected = table.find(SelectedOptions, "Cadence") ~= nil
            local altarSelected = table.find(SelectedOptions, "Altar") ~= nil
            
            Controller:SetGiftESP(giftSelected)
            Controller:SetCadenceESP(cadenceSelected)
            Controller:SetAltarESP(altarSelected)
            
            -- Đồng bộ hóa hiển thị giao diện Rayfield khi load config bị lỗi text "none"
            if not isSettingESP and ESPSelection then
                isSettingESP = true
                pcall(function()
                    ESPSelection:Set(SelectedOptions)
                end)
                isSettingESP = false
            end
        end
    })
    
    Tab:CreateDropdown({
        Name = "ESP Style",
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
    
    local AltarFilter
    local isSettingAltar = false
    AltarFilter = Tab:CreateDropdown({
        Name = "Select Altar Highlight",
        Options = {"All", "Purgatory", "Chance", "Chaos", "Echo", "Passage", "Protection", "Purification"},
        CurrentOption = {"All"},
        MultipleOptions = true,
        Flag = "AltarFilterDropdown",
        Callback = function(SelectedOptions)
            Controller:SetAltarFilter(SelectedOptions)
            
            -- Đồng bộ hóa hiển thị giao diện Rayfield khi load config bị lỗi text "none"
            if not isSettingAltar and AltarFilter then
                isSettingAltar = true
                pcall(function()
                    AltarFilter:Set(SelectedOptions)
                end)
                isSettingAltar = false
            end
        end
    })

    Tab:CreateSection("Auto Collect Gifts")

    Tab:CreateToggle({
        Name = "Auto Collect Gifts (Magnet Bypass)",
        CurrentValue = Controller.AutoCollectEnabled,
        Flag = "AutoCollectGiftsToggle",
        Callback = function(Value)
            Controller:SetAutoCollectEnabled(Value)
        end
    })

    Tab:CreateDropdown({
        Name = "Collection Mode",
        Options = {"Legit", "Blatant"},
        CurrentOption = Controller.AutoCollectMode or "Legit",
        MultipleOptions = false,
        Flag = "AutoCollectModeDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetAutoCollectMode(selected)
        end
    })

    Tab:CreateSlider({
        Name = "Collection Range",
        Min = 5,
        Max = 30,
        CurrentValue = Controller.AutoCollectRange,
        Increment = 1,
        ValueName = "Studs",
        Flag = "AutoCollectRangeSlider",
        Callback = function(Value)
            Controller:SetAutoCollectRange(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Tripmine Immunity (Bypass)",
        CurrentValue = Controller.TripmineBarrierEnabled,
        Flag = "TripmineBarrierToggle",
        Callback = function(Value)
            Controller:SetTripmineBarrier(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Simulate Defuse Kit",
        CurrentValue = Controller.SimulateDefuseKit or false,
        Flag = "SimulateDefuseKitToggle",
        Callback = function(Value)
            Controller:SetSimulateDefuseKit(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Defuse Kit Stacks",
        Min = 1,
        Max = 5,
        CurrentValue = Controller.DefuseKitStack or 3,
        Increment = 1,
        ValueName = "Stacks",
        Flag = "DefuseKitStackSlider",
        Callback = function(Value)
            Controller:SetDefuseKitStack(Value)
        end
    })
end
