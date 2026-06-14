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
    local lastESPSelection = {"None"}
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
            local finalSelection = SelectedOptions
            
            if hasNone then
                local wasNoneSelected = table.find(lastESPSelection, "None") ~= nil
                if wasNoneSelected then
                    -- "None" đã được chọn từ trước, và người dùng vừa tích chọn thêm một mục khác.
                    -- Chúng ta sẽ bỏ chọn "None" khỏi danh sách lựa chọn cuối cùng.
                    finalSelection = {}
                    for _, opt in ipairs(SelectedOptions) do
                        if opt ~= "None" then
                            table.insert(finalSelection, opt)
                        end
                    end
                    if #finalSelection == 0 then
                        finalSelection = {"None"}
                    end
                else
                    -- Người dùng vừa chủ động tích chọn mục "None". Thiết lập "None" làm lựa chọn duy nhất.
                    finalSelection = {"None"}
                end
            else
                if #SelectedOptions == 0 then
                    finalSelection = {"None"}
                end
            end
            
            -- Cập nhật lựa chọn hiển thị của Dropdown nếu có sự thay đổi
            local changed = false
            if #finalSelection ~= #SelectedOptions then
                changed = true
            else
                for _, opt in ipairs(finalSelection) do
                    if not table.find(SelectedOptions, opt) then
                        changed = true
                        break
                    end
                end
            end
            
            if changed then
                isSettingESP = true
                ESPDropdown:Set(finalSelection)
                isSettingESP = false
            end
            
            lastESPSelection = finalSelection
            
            -- Thiết lập các trạng thái tương ứng trong Controller
            local giftSelected = table.find(finalSelection, "Gift") ~= nil
            local cadenceSelected = table.find(finalSelection, "Cadence") ~= nil
            local altarSelected = table.find(finalSelection, "Altar") ~= nil
            
            Controller:SetGiftESP(giftSelected)
            Controller:SetCadenceESP(cadenceSelected)
            Controller:SetAltarESP(altarSelected)
            
            -- Tự động đóng dropdown nếu lựa chọn duy nhất hiện tại là "None"
            if #finalSelection == 1 and finalSelection[1] == "None" then
                task.spawn(function()
                    task.wait(0.1)
                    closeDropdown(getDropdownGui("Select ESP Type"))
                end)
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
    local lastAltarSelection = {"All"}
    local AltarDropdown
    AltarDropdown = Tab:CreateDropdown({
        Name = "Select Altar Highlight",
        Options = {"None", "All", "Purgatory", "Chance", "Chaos", "Echo", "Passage", "Protection", "Purification"},
        CurrentOption = {"All"},
        MultipleOptions = true,
        Flag = "AltarFilterDropdown",
        Callback = function(SelectedOptions)
            if isSettingAltar then return end
            
            local hasNone = table.find(SelectedOptions, "None") ~= nil
            local finalSelection = SelectedOptions
            
            if hasNone then
                local wasNoneSelected = table.find(lastAltarSelection, "None") ~= nil
                if wasNoneSelected then
                    -- "None" đã được chọn từ trước, và người dùng vừa tích chọn thêm một mục khác.
                    -- Chúng ta sẽ bỏ chọn "None" khỏi danh sách lựa chọn cuối cùng.
                    finalSelection = {}
                    for _, opt in ipairs(SelectedOptions) do
                        if opt ~= "None" then
                            table.insert(finalSelection, opt)
                        end
                    end
                    if #finalSelection == 0 then
                        finalSelection = {"None"}
                    end
                else
                    -- Người dùng vừa chủ động tích chọn mục "None". Thiết lập "None" làm lựa chọn duy nhất.
                    finalSelection = {"None"}
                end
            else
                if #SelectedOptions == 0 then
                    finalSelection = {"None"}
                end
            end
            
            -- Cập nhật lựa chọn hiển thị của Dropdown nếu có sự thay đổi
            local changed = false
            if #finalSelection ~= #SelectedOptions then
                changed = true
            else
                for _, opt in ipairs(finalSelection) do
                    if not table.find(SelectedOptions, opt) then
                        changed = true
                        break
                    end
                end
            end
            
            if changed then
                isSettingAltar = true
                AltarDropdown:Set(finalSelection)
                isSettingAltar = false
            end
            
            lastAltarSelection = finalSelection
            
            Controller:SetAltarFilter(finalSelection)
            
            -- Tự động đóng dropdown nếu lựa chọn duy nhất hiện tại là "None"
            if #finalSelection == 1 and finalSelection[1] == "None" then
                task.spawn(function()
                    task.wait(0.1)
                    closeDropdown(getDropdownGui("Select Altar Highlight"))
                end)
            end
        end
    })
end
