-- [[
--  NULLSCAPE - Standalone Radar Spoof Logic
--  Module chạy độc lập thực thi bẻ khóa Radar gốc của Game không in log.
-- ]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    return
end

-- 1. Quét tìm các ValueObject lưu trữ nâng cấp trong Player
local function scanForUpgrades(parent)
    for _, child in ipairs(parent:GetChildren()) do
        pcall(function()
            local nameLower = child.Name:lower()
            if string.find(nameLower, "radar") or string.find(nameLower, "instrument") or string.find(nameLower, "upgrade") or string.find(nameLower, "unlock") or string.find(nameLower, "cadence") then
                if child:IsA("BoolValue") then
                    child.Value = true
                elseif child:IsA("NumberValue") or child:IsA("IntValue") then
                    child.Value = 99
                elseif child:IsA("StringValue") then
                    child.Value = "true"
                end
            end
        end)
        scanForUpgrades(child)
    end
end

scanForUpgrades(LocalPlayer)

-- 2. Quét tìm giao diện UI Radar trong PlayerGui và kích hoạt
local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if playerGui then
    for _, gui in ipairs(playerGui:GetDescendants()) do
        pcall(function()
            local nameLower = gui.Name:lower()
            if string.find(nameLower, "radar") or string.find(nameLower, "tracker") or string.find(nameLower, "cadence") or string.find(nameLower, "minimap") then
                if gui:IsA("ScreenGui") then
                    gui.Enabled = true
                elseif gui:IsA("Frame") or gui:IsA("ImageLabel") or gui:IsA("TextLabel") or gui:IsA("ViewportFrame") then
                    gui.Visible = true
                end
            end
        end)
    end
end

-- 3. Gửi thông báo trực quan bằng Rayfield nếu có
local Rayfield = getgenv().Rayfield or (shared.Client and shared.Client.Window and getgenv().Rayfield)
if Rayfield then
    Rayfield:Notify({
        Title = "Radar Spoof Active",
        Content = "Đã kích hoạt bẻ khóa Radar gốc thành công!",
        Duration = 3
    })
end
