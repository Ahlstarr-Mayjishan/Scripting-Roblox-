-- [[
--  NULLSCAPE - Simulated Upgrades & Radar UI Tab
--  Đóng vai trò tạo tab "Mô phỏng Upgrades & Radar" trên giao diện Rayfield
-- ]]

-- Helper để tìm Dropdown GUI trong Rayfield dựa vào tên Frame (bằng tên Dropdown)
local function getDropdownGui(name)
    local coreGui = game:GetService("CoreGui")
    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local rayfieldGui = coreGui:FindFirstChild("Rayfield") or (playerGui and playerGui:FindFirstChild("Rayfield"))
    if not rayfieldGui then return nil end
    
    for _, desc in ipairs(rayfieldGui:GetDescendants()) do
        if desc.Name == name and desc:IsA("Frame") then
            return desc
        end
    end
    return nil
end

-- Helper để tự động đóng Dropdown bằng firesignal
local function closeDropdown(dropdownGui)
    if not dropdownGui then return end
    local list = dropdownGui:FindFirstChild("List")
    local interact = dropdownGui:FindFirstChild("Interact")
    if list and list.Visible and interact then
        if typeof(firesignal) == "function" then
            firesignal(interact.MouseButton1Click)
        else
            list.Visible = false
        end
    end
end

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Simulated Upgrades & Radar", 4483362458)
    
    Tab:CreateSection("Custom ESP Locator")
    
    local isSettingESP = false
    local ESPDropdown
    ESPDropdown = Tab:CreateDropdown({
        Name = "Select ESP Type",
        Options = {"None", "Gift", "Cadence", "Altar"},
        CurrentOption = {"None"},
        MultipleOptions = true,
        Flag = "ESPSelectionDropdown",
        Callback = function(SelectedOptions)
            if isSettingESP then return end
            local hasNone = table.find(SelectedOptions, "None") ~= nil
            
            if hasNone then
                isSettingESP = true
                ESPDropdown:Set({"None"})
                isSettingESP = false
                
                Controller:SetGiftESP(false)
                Controller:SetCadenceESP(false)
                Controller:SetAltarESP(false)
                
                -- Tự động đóng cả hai dropdown
                task.spawn(function()
                    task.wait(0.1)
                    closeDropdown(getDropdownGui("Select ESP Type"))
                    closeDropdown(getDropdownGui("Select Altar Highlight"))
                end)
            else
                if #SelectedOptions == 0 then
                    isSettingESP = true
                    ESPDropdown:Set({"None"})
                    isSettingESP = false
                    
                    Controller:SetGiftESP(false)
                    Controller:SetCadenceESP(false)
                    Controller:SetAltarESP(false)
                else
                    local giftSelected = table.find(SelectedOptions, "Gift") ~= nil
                    local cadenceSelected = table.find(SelectedOptions, "Cadence") ~= nil
                    local altarSelected = table.find(SelectedOptions, "Altar") ~= nil
                    
                    Controller:SetGiftESP(giftSelected)
                    Controller:SetCadenceESP(cadenceSelected)
                    Controller:SetAltarESP(altarSelected)
                end
            end
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
    
    local isSettingAltar = false
    local AltarDropdown
    AltarDropdown = Tab:CreateDropdown({
        Name = "Select Altar Highlight",
        Options = {"None", "All", "Purgatory", "Chance", "Chaos", "Echo", "Passage", "Protection", "Purification"},
        CurrentOption = {"All"},
        MultipleOptions = true,
        Flag = "AltarFilterDropdown",
        Callback = function(SelectedOptions)
            if isSettingAltar then return end
            local unlockController = Client.Modules.UnlockController
            if not unlockController then return end
            
            local hasNone = table.find(SelectedOptions, "None") ~= nil
            
            if hasNone then
                isSettingAltar = true
                AltarDropdown:Set({"None"})
                isSettingAltar = false
                
                unlockController:SetAltarFilter({"None"})
                
                -- Tự động đóng cả hai dropdown
                task.spawn(function()
                    task.wait(0.1)
                    closeDropdown(getDropdownGui("Select ESP Type"))
                    closeDropdown(getDropdownGui("Select Altar Highlight"))
                end)
            else
                if #SelectedOptions == 0 then
                    isSettingAltar = true
                    AltarDropdown:Set({"None"})
                    isSettingAltar = false
                    
                    unlockController:SetAltarFilter({"None"})
                else
                    unlockController:SetAltarFilter(SelectedOptions)
                end
            end
        end
    })
end
