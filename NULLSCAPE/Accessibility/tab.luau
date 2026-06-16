local ADAPT_INPUT_OPTIONS = {"T", "R", "F", "G", "C", "V", "X", "Z", "Q", "E"}

return function(Client, Controller)
    local Tab = Client.Window:CreateTab("Accessibility", 4483362458)
    
    Tab:CreateSection("Accessibility Features")
    
    Tab:CreateToggle({
        Name = "Auto jump - Springer",
        CurrentValue = Controller.SpringerAutoJumpEnabled,
        Flag = "SpringerAutoJumpToggle",
        Callback = function(Value)
            Controller:SetSpringerAutoJump(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Infinite Air Jump",
        Info = "Refills the native DoubleJump charge, preserving the game's animation and SFX.",
        CurrentValue = Controller.InfiniteAirJumpEnabled,
        Flag = "InfiniteAirJumpToggle",
        Callback = function(Value)
            Controller:SetInfiniteAirJump(Value)
        end
    })

    Tab:CreateSection("Rail Assist")

    Tab:CreateToggle({
        Name = "Rail Assist Suite",
        Info = "Master switch for rail entry helpers and speed scaling.",
        CurrentValue = Controller.RailAssistSuiteEnabled or false,
        Flag = "RailAssistSuiteToggle",
        Callback = function(Value)
            Controller:SetRailAssistSuite(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Auto Rail",
        Info = "Automatically snaps you onto nearby _RailPart segments within activation range.",
        CurrentValue = Controller.RailAutoEnabled or false,
        Flag = "RailAutoToggle",
        Callback = function(Value)
            Controller:SetRailAuto(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Rail Entry Speed",
        Info = "Multiplies your horizontal speed right when FollowRail starts.",
        Range = {1.1, 5},
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = Controller.RailSpeedMultiplier or 1.1,
        Flag = "RailSpeedMultiplierSlider",
        Callback = function(Value)
            Controller:SetRailSpeedMultiplier(Value)
        end
    })

    Tab:CreateSection("Grapple Assist")

    Tab:CreateToggle({
        Name = "Grapple Assist Suite",
        Info = "Master switch for all Grapple assist hooks. Turning it off restores Grapple logic.",
        CurrentValue = Controller.GrappleAssistSuiteEnabled or false,
        Flag = "GrappleAssistSuiteToggle",
        Callback = function(Value)
            Controller:SetGrappleAssistSuite(Value)
        end
    })

    Tab:CreateDropdown({
        Name = "Grapple Adapt Input",
        Info = "Dedicated Grapple assist input. Acts like a tap pulse, so it will not hold charge. Default is T.",
        Options = ADAPT_INPUT_OPTIONS,
        CurrentOption = Controller.GrappleAdaptInputKey or "T",
        MultipleOptions = false,
        Flag = "GrappleAdaptInputKeybind",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetGrappleAdaptInputKey(selected)
        end
    })

    Tab:CreateDropdown({
        Name = "Grappler Stamina",
        Info = "Keeps the native Grapple stamina timer full while selected.",
        Options = {"Off", "Infinite Stamina"},
        CurrentOption = Controller.GrapplerStaminaMode or "Off",
        MultipleOptions = false,
        Flag = "GrapplerStaminaModeDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetGrapplerStaminaMode(selected)
        end
    })

    Tab:CreateToggle({
        Name = "Grapple Aim Assist",
        Info = "When native Grapple cast misses, searches visible safe targets on screen and restores Cast when disabled.",
        CurrentValue = Controller.GrappleAimAssistEnabled or false,
        Flag = "GrappleAimAssistToggle",
        Callback = function(Value)
            Controller:SetGrappleAimAssist(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Grapple Rescue Assist",
        Info = "When falling fast in air, prioritizes rescue targets while you are holding Grapple.",
        CurrentValue = Controller.GrappleRescueAssistEnabled or false,
        Flag = "GrappleRescueAssistToggle",
        Callback = function(Value)
            Controller:SetGrappleRescueAssist(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Grapple Anti Bonk",
        Info = "Prevents Grapple wall-collision DiveBonk stun/knock while keeping the game's grapple end behavior.",
        CurrentValue = Controller.GrappleAntiBonkEnabled or false,
        Flag = "GrappleAntiBonkToggle",
        Callback = function(Value)
            Controller:SetGrappleAntiBonk(Value)
        end
    })

    Tab:CreateToggle({
        Name = "Grapple Smart Reel",
        Info = "Uses reel only when you really have NinjaBelt.",
        CurrentValue = Controller.GrappleSmartReelEnabled or false,
        Flag = "GrappleSmartReelToggle",
        Callback = function(Value)
            Controller:SetGrappleSmartReel(Value)
        end
    })

    Tab:CreateDropdown({
        Name = "Smart Reel Mode",
        Info = "Manual uses p2/sub-ability. Automatic reels only when NinjaBelt is really available.",
        Options = {"Manual", "Automatic"},
        CurrentOption = Controller.GrappleSmartReelMode or "Manual",
        MultipleOptions = false,
        Flag = "GrappleSmartReelModeDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetGrappleSmartReelMode(selected)
        end
    })

    Tab:CreateToggle({
        Name = "SharkTail Helper",
        Info = "Uses SharkTail only when you really have SharkTail.",
        CurrentValue = Controller.GrappleSharkTailHelperEnabled or false,
        Flag = "GrappleSharkTailHelperToggle",
        Callback = function(Value)
            Controller:SetGrappleSharkTailHelper(Value)
        end
    })

    Tab:CreateDropdown({
        Name = "SharkTail Mode",
        Info = "Manual uses p2/sub-ability during SharkTail window. Automatic triggers only when safe.",
        Options = {"Manual", "Automatic"},
        CurrentOption = Controller.GrappleSharkTailMode or "Manual",
        MultipleOptions = false,
        Flag = "GrappleSharkTailModeDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetGrappleSharkTailMode(selected)
        end
    })

    Tab:CreateToggle({
        Name = "Grapple Momentum Guard",
        Info = "Soft-limits excessive horizontal speed after reel/grapple chains.",
        CurrentValue = Controller.GrappleMomentumGuardEnabled or false,
        Flag = "GrappleMomentumGuardToggle",
        Callback = function(Value)
            Controller:SetGrappleMomentumGuard(Value)
        end
    })

    Tab:CreateToggle({
        Name = "JumpPad Uses Bypass",
        Info = "Keeps Grapple JumpPads queryable so you can test repeated pulls on the same pad.",
        CurrentValue = Controller.GrappleJumpPadUsesBypassEnabled or false,
        Flag = "GrappleJumpPadUsesBypassToggle",
        Callback = function(Value)
            Controller:SetGrappleJumpPadUsesBypass(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Grapple Air Control",
        Info = "Multiplies the native Grapple movement input force while swinging.",
        Range = {1.1, 5},
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = Controller.GrappleAirControlMultiplier or 1.1,
        Flag = "GrappleAirControlMultiplierSlider",
        Callback = function(Value)
            Controller:SetGrappleAirControlMultiplier(Value)
        end
    })

    Tab:CreateSlider({
        Name = "Grapple Reel Pull",
        Info = "Multiplies reel pull speed for GrapplePoint, JumpPad, Bell, TriaOrb, and NinjaBelt reel.",
        Range = {1.1, 5},
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = Controller.GrappleReelPullMultiplier or 1.1,
        Flag = "GrappleReelPullMultiplierSlider",
        Callback = function(Value)
            Controller:SetGrappleReelPullMultiplier(Value)
        end
    })

    Tab:CreateSlider({
        Name = "SharkTail Pull",
        Info = "Multiplies the launch strength when SharkTail fires during the Grapple window.",
        Range = {1.1, 5},
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = Controller.GrappleSharkTailPullMultiplier or 1.1,
        Flag = "GrappleSharkTailPullMultiplierSlider",
        Callback = function(Value)
            Controller:SetGrappleSharkTailPullMultiplier(Value)
        end
    })

    Tab:CreateDropdown({
        Name = "Grapple Target Priority",
        Info = "Preferred target type when several visible grapple targets are valid.",
        Options = {"GrapplePoint", "JumpPad", "Bell", "TriaOrb"},
        CurrentOption = Controller.GrappleAimAssistTargetPriority or "GrapplePoint",
        MultipleOptions = false,
        Flag = "GrappleAimAssistTargetPriorityDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetGrappleAimAssistTargetPriority(selected)
        end
    })

    Tab:CreateDropdown({
        Name = "Grapple Range Priority",
        Info = "How the assist chooses between valid visible targets.",
        Options = {"Nearest", "Farthest", "Closest To Cursor", "Random"},
        CurrentOption = Controller.GrappleAimAssistRangePriority or "Nearest",
        MultipleOptions = false,
        Flag = "GrappleAimAssistRangePriorityDropdown",
        Callback = function(Option)
            local selected = Option
            if typeof(Option) == "table" then
                selected = Option[1]
            end
            Controller:SetGrappleAimAssistRangePriority(selected)
        end
    })
end
