--!nocheck
-- [[
--  NULLSCAPE - Simulated Upgrades & Radar UI Tab
--  Dong vai tro tao tab "Mo phong Upgrades & Radar" tren giao dien Rayfield
-- ]]

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Upgrade Simulations", 4483362458)
    
    Tab:CreateSection("Radar")
    
    Tab:CreateToggle({
        Name = "Enable Radar",
        CurrentValue = Controller.RadarEnabled,
        Flag = "RadarEnabledToggle",
        Callback = function(Value)
            Controller:SetRadarEnabled(Value)
        end
    })
        
    local ESPSelection
    local isSettingESP = false
    ESPSelection = Tab:CreateDropdown({
        Name = "ESP types",
        Options = {"Gift", "Cadence", "Altar"},
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "ESPSelectionDropdown",
        Callback = function(SelectedOptions)
            if typeof(SelectedOptions) ~= "table" then
                SelectedOptions = {}
            end
            local giftSelected = table.find(SelectedOptions, "Gift") ~= nil
            local cadenceSelected = table.find(SelectedOptions, "Cadence") ~= nil
            local altarSelected = table.find(SelectedOptions, "Altar") ~= nil
            
            Controller:SetGiftESP(giftSelected)
            Controller:SetCadenceESP(cadenceSelected)
            Controller:SetAltarESP(altarSelected)
            
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
    
    local AltarFilter
    local isSettingAltar = false
    AltarFilter = Tab:CreateDropdown({
        Name = "Select Altar Highlight",
        Options = {"All", "Purgatory", "Chance", "Chaos", "Echo", "Passage", "Protection", "Purification"},
        CurrentOption = {"All"},
        MultipleOptions = true,
        Flag = "AltarFilterDropdown",
        Callback = function(SelectedOptions)
            if typeof(SelectedOptions) ~= "table" then
                SelectedOptions = {}
            end
            Controller:SetAltarFilter(SelectedOptions)
            
            if not isSettingAltar and AltarFilter then
                isSettingAltar = true
                pcall(function()
                    AltarFilter:Set(SelectedOptions)
                end)
                isSettingAltar = false
            end
        end
    })

    Tab:CreateSection("Gifts Magnet")

    Tab:CreateToggle({
        Name = "Enable Magnet Gifts",
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
        Range = {5, 30},
        CurrentValue = Controller.AutoCollectRange,
        Increment = 1,
        ValueName = "Studs",
        Flag = "AutoCollectRangeSlider",
        Callback = function(Value)
            Controller:SetAutoCollectRange(Value)
        end
    })

    Tab:CreateSection("Defuse Kits")

    Tab:CreateToggle({
        Name = "Tripmine Immunity (Bypass)",
        CurrentValue = Controller.TripmineBarrierEnabled,
        Flag = "TripmineBarrierToggle",
        Callback = function(Value)
            Controller:SetTripmineBarrier(Value)
        end
    })

    Tab:CreateDropdown({
        Name = "Tripmine Bypass Mode",
        Options = {"Delayed", "Barrier"},
        CurrentOption = Controller.TripmineMode == "Barrier" and "Barrier" or "Delayed",
        MultipleOptions = false,
        Flag = "TripmineModeDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetTripmineMode(selected)
        end
    })

    Tab:CreateSlider({
        Name = "Detonation Distance",
        Range = {5, 30},
        CurrentValue = Controller.TripmineDetonationDistance or 15,
        Increment = 1,
        ValueName = "Studs",
        Flag = "TripmineDetonationDistanceSlider",
        Callback = function(Value)
            Controller:SetTripmineDetonationDistance(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Detonation Jitter",
        Range = {0, 10},
        CurrentValue = Controller.TripmineDetonationJitter or 2,
        Increment = 1,
        ValueName = "Studs",
        Flag = "TripmineDetonationJitterSlider",
        Callback = function(Value)
            Controller:SetTripmineDetonationJitter(Value)
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
        Range = {1, 5},
        CurrentValue = Controller.DefuseKitStack or 3,
        Increment = 1,
        ValueName = "Stacks",
        Flag = "DefuseKitStackSlider",
        Callback = function(Value)
            Controller:SetDefuseKitStack(Value)
        end
    })

    Tab:CreateSection("Matrix Tetrahedron")

    Tab:CreateToggle({
        Name = "Simulate Matrix Tetrahedron",
        Info = "Instant acceleration, removes slippery momentum, and reduces ice tiles sliding.",
        CurrentValue = Controller.MatrixTetrahedronEnabled,
        Flag = "MatrixTetrahedronToggle",
        Callback = function(Value)
            Controller:SetMatrixTetrahedron(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Momentum Reduction",
        Info = "Brake animation duration: 10% -> 90%, 50% -> 50%, >=60% bypass.",
        Range = {10, 100},
        Increment = 10,
        CurrentValue = math.clamp((Controller.MomentumReduction or 1.0) * 100, 10, 100),
        Flag = "MomentumReductionSlider",
        Suffix = "%",
        Callback = function(Value)
            Controller:SetMomentumReduction(Value / 100)
        end
    })

    Tab:CreateSection("Grace Wings")

    Tab:CreateToggle({
        Name = "Enable Grace Wings",
        Info = "Master toggle. Turning it off restores movement hook and stops spoofing GraceWings.",
        CurrentValue = Controller.GraceWingsEnabled or false,
        Flag = "GraceWingsToggle",
        Callback = function(Value)
            Controller:SetGraceWings(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Air Control Multiplier",
        Range = {1.1, 5},
        Increment = 0.1,
        CurrentValue = Controller.GraceWingsAirControlMultiplier or 1.1,
        Flag = "GraceWingsAirControlSlider",
        Suffix = "x",
        Callback = function(Value)
            Controller:SetGraceWingsAirControlMultiplier(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Strong Air Control",
        Info = "Extra direct horizontal steering while falling. Keep off for closer GraceWings simulation.",
        CurrentValue = Controller.GraceWingsStrongAirControl or false,
        Flag = "GraceWingsStrongAirControlToggle",
        Callback = function(Value)
            Controller:SetGraceWingsStrongAirControl(Value)
        end
    })

    Tab:CreateSection("Advanced Gravity Coil")

    Tab:CreateToggle({
        Name = "Enable Advanced Gravity Coil",
        Info = "Spoofs the upgrade and applies the JumpPower override from Ref logic.",
        CurrentValue = Controller.AdvancedGravityCoilEnabled or false,
        Flag = "AdvancedGravityCoilToggle",
        Callback = function(Value)
            Controller:SetAdvancedGravityCoil(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Jump Power",
        Info = "Ref minimum is 35 * 0.8 = 28. Raise it up to 100.",
        Range = {28, 100},
        Increment = 1,
        CurrentValue = Controller.AdvancedGravityCoilJumpPower or 28,
        Flag = "AdvancedGravityCoilJumpPowerSlider",
        Callback = function(Value)
            Controller:SetAdvancedGravityCoilJumpPower(Value)
        end
    })

    Tab:CreateSection("Better Jump Pad")

    Tab:CreateToggle({
        Name = "Enable Better Jump Pad",
        Info = "Spoofs BetterJumpPad and raises JumpPad vertical launch.",
        CurrentValue = Controller.BetterJumpPadEnabled or false,
        Flag = "BetterJumpPadToggle",
        Callback = function(Value)
            Controller:SetBetterJumpPad(Value)
        end
    })

    Tab:CreateSlider({
        Name = "JumpPad Power",
        Info = "Ref JumpPad power is 100. Raise it up to 200.",
        Range = {100, 200},
        Increment = 1,
        CurrentValue = Controller.BetterJumpPadPower or 100,
        Flag = "BetterJumpPadPowerSlider",
        Callback = function(Value)
            Controller:SetBetterJumpPadPower(Value)
        end
    })
end
