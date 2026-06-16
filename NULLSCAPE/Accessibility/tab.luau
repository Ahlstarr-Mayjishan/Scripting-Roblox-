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
