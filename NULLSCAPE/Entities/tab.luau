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
    
    local AltarDropdown
    AltarDropdown = Tab:CreateDropdown({
        Name = "Select Altar Highlight",
        Options = {"None", "All", "Purgatory", "Chance", "Chaos", "Echo", "Passage", "Protection", "Purification"},
        CurrentOption = {"All"},
        MultipleOptions = true,
        Flag = "AltarFilterDropdown",
        Callback = function(SelectedOptions)
            local unlockController = Client.Modules.UnlockController
            if not unlockController then return end
            
            local hasNone = table.find(SelectedOptions, "None") ~= nil
            
            if hasNone then
                AltarDropdown:Set({"None"})
                unlockController:SetAltarFilter({"None"})
                
                -- Tự động đóng dropdown
                task.spawn(function()
                    task.wait(0.1)
                    closeDropdown(getDropdownGui("Select Altar Highlight"))
                end)
            else
                if #SelectedOptions == 0 then
                    AltarDropdown:Set({"None"})
                    unlockController:SetAltarFilter({"None"})
                else
                    unlockController:SetAltarFilter(SelectedOptions)
                end
            end
        end
    })
end
