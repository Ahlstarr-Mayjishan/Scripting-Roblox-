--[[
    AimTab.lua - Unified Combat Control Center
    Consolidated: Assist Mode, FOV, Target Part, and Source Management.
    Replaces: AimbotTab.lua và TargetingTab.lua.
]]

return function(Window, Options, Visuals, NPCTracker)
    local Tab = Window:CreateTab("Aim", 4483362458)

    -- ═══════════════════════════════════════════════════
    -- SECTION: ASSIST MODE
    -- ═══════════════════════════════════════════════════
    Tab:CreateSection("Assist Mode")

    Tab:CreateDropdown({
        Name = "Main Assist Mode",
        Options = {"Off", "Camera Lock", "Silent Aim", "Highlight Only"},
        CurrentOption = {Options.AssistMode or "Off"},
        Flag = "AssistModeDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.AssistMode = selected
        end,
    })

    Tab:CreateToggle({
        Name = "Require Right Mouse Hold",
        CurrentValue = Options.HoldMouse2ToAssist,
        Flag = "HoldMouse2Toggle",
        Callback = function(Value)
            Options.HoldMouse2ToAssist = Value
        end,
    })

    -- ═══════════════════════════════════════════════════
    -- SECTION: TARGETING PARAMETERS
    -- ═══════════════════════════════════════════════════
    Tab:CreateSection("Targeting Parameters")

    Tab:CreateDropdown({
        Name = "Target Body Part",
        Options = {"HumanoidRootPart", "Torso", "Head"},
        CurrentOption = {Options.TargetPart or "HumanoidRootPart"},
        Flag = "TargetPartDropdown",
        Callback = function(Value)
            Options.TargetPart = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateSlider({
        Name = "Vertical Aim Offset (Y)",
        Range = {-50, 50},
        Increment = 5,
        Suffix = " (x0.1 Studs)",
        CurrentValue = Options.AimOffset and (Options.AimOffset * 10) or 0,
        Flag = "YOffsetSlider",
        Callback = function(Value)
            Options.AimOffset = Value / 10
        end,
    })

    -- ═══════════════════════════════════════════════════
    -- SECTION: AIM METHODS
    -- ═══════════════════════════════════════════════════
    Tab:CreateSection("Aim Methods")

    Tab:CreateDropdown({
        Name = "Aim Method",
        Options = {"FOV", "Distance", "Deadlock"},
        CurrentOption = {Options.TargetingMethod or "FOV"},
        Flag = "TargetingMethodDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.TargetingMethod = selected
            if Visuals and Visuals.FOVCircle then
                Visuals.FOVCircle.Visible = (selected ~= "Distance")
            end
        end,
    })

    Tab:CreateSlider({
        Name = "FOV / Lock Radius",
        Range = {0, 1000},
        Increment = 10,
        Suffix = "px",
        CurrentValue = Options.FOV or 100,
        Flag = "FOVSlider",
        Callback = function(Value)
            Options.FOV = Value
            if Visuals and Visuals.FOVCircle then
                Visuals.FOVCircle.Radius = Value
            end
        end,
    })

    Tab:CreateSlider({
        Name = "Distance Detect",
        Range = {0, 5000},
        Increment = 25,
        Suffix = " studs",
        CurrentValue = Options.MaxDistance or 1500,
        Flag = "DistanceDetectSlider",
        Callback = function(Value)
            Options.MaxDistance = Value
        end,
    })

    -- ═══════════════════════════════════════════════════
    -- SECTION: CAMERA SETTINGS
    -- ═══════════════════════════════════════════════════
    Tab:CreateSection("Camera Lock (Aimbot)")

    Tab:CreateSlider({
        Name = "Lock Smoothness",
        Range = {1, 100},
        Increment = 1,
        Suffix = "%",
        CurrentValue = math.floor((Options.Smoothness or 0.1) * 100),
        Flag = "SmoothnessSlider",
        Callback = function(Value)
            Options.Smoothness = math.clamp(Value / 100, 0.01, 1)
        end,
    })

    -- ═══════════════════════════════════════════════════
    -- SECTION: TARGET SOURCE
    -- ═══════════════════════════════════════════════════
    Tab:CreateSection("Target Filter")

    Tab:CreateToggle({
        Name = "Target Other Players (PvP)",
        CurrentValue = Options.TargetPlayersToggle,
        Flag = "TargetPlayersFlag",
        Callback = function(Value)
            Options.TargetPlayersToggle = Value
            if NPCTracker and NPCTracker.ClearCache then
                NPCTracker:ClearCache()
            end
        end,
    })

    return Tab
end
