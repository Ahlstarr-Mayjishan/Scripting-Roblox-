--[[
    SettingsTab.lua — Tab UI Settings
    Toggle menu keybind, UI visibility control.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Helper: Detect Rayfield ScreenGuis
local function isRayfieldScreenGui(screenGui)
    if not screenGui or not screenGui:IsA("ScreenGui") then
        return false
    end

    local guiName = string.lower(screenGui.Name)
    if guiName:find("rayfield", 1, true) or guiName:find("sirius", 1, true) then
        return true
    end

    for _, descendant in ipairs(screenGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local text = descendant.Text
            if text == "Boss Aim Assist" or text == "Loading..." then
                return true
            end
        end
    end

    return false
end

local function getRayfieldScreenGuis()
    local matches = {}
    local containers = {CoreGui}

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(containers, playerGui)
    end

    for _, container in ipairs(containers) do
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("ScreenGui") and isRayfieldScreenGui(descendant) then
                matches[#matches + 1] = descendant
            end
        end
    end

    return matches
end

return function(Window, Options)
    local Tab = Window:CreateTab("UI Settings", 4483362458)

    Tab:CreateKeybind({
        Name = "Toggle Menu UI",
        CurrentKeybind = "RightShift",
        HoldToInteract = false,
        Flag = "ToggleUIKey",
        Callback = function()
            pcall(function()
                local screenGuis = getRayfieldScreenGuis()
                if #screenGuis == 0 then
                    return
                end

                local nextEnabledState = true
                for _, ui in ipairs(screenGuis) do
                    if ui.Enabled then
                        nextEnabledState = false
                        break
                    end
                end

                for _, ui in ipairs(screenGuis) do
                    ui.Enabled = nextEnabledState
                end
            end)
        end,
    })

    return Tab
end
