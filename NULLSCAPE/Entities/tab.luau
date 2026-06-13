-- [[
--  NULLSCAPE - Entities UI Tab
--  Handles creating the "Entities Immunity" tab on the Rayfield interface
-- ]]

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
