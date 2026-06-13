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
    local Tab = Client.Window:CreateTab("Entities", 4483362458)
    
    Tab:CreateSection("Entities List - Touch Immunity")
    
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
            local unlockController = Client.Modules.UnlockController
            if not unlockController then return end
            
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
            
            unlockController:SetAltarFilter(finalSelection)
            
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
