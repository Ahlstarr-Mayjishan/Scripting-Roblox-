--[[
    AimbotTab.lua — Tab Aimbot & FOV
    Tạo tab Aim Assist & FOV trên Rayfield UI.
]]

return function(Window, Options, Visuals)
    local Tab = Window:CreateTab("Aim Assist & FOV", 4483362458)

    Tab:CreateDropdown({
        Name = "Assist Mode",
        Options = {"Off", "Camera Lock", "Silent Aim", "Highlight Only"},
        CurrentOption = {"Off"},
        Flag = "AssistModeDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            if selected == "Silent Aim (Highlight)" then
                selected = "Silent Aim"
            end
            Options.AssistMode = selected
        end,
    })

    Tab:CreateToggle({
        Name = "Only Assist While Holding Right Mouse",
        CurrentValue = Options.HoldMouse2ToAssist,
        Flag = "HoldMouse2Toggle",
        Callback = function(Value)
            Options.HoldMouse2ToAssist = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Show FOV Circle",
        CurrentValue = Options.ShowFOV,
        Flag = "FOVToggle",
        Callback = function(Value)
            Options.ShowFOV = Value
            Visuals.FOVCircle.Visible = Value
        end,
    })

    Tab:CreateSlider({
        Name = "FOV Circle Size (Radius)",
        Range = {0, 1000},
        Increment = 10,
        Suffix = " Pixels",
        CurrentValue = Options.FOV,
        Flag = "FOVSlider",
        Callback = function(Value)
            Options.FOV = Value
            Visuals.FOVCircle.Radius = Value
        end,
    })

    return Tab
end
