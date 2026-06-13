-- [[
--  NULLSCAPE Master Script (Modular Rayfield UI Edition)
--  Tạo bởi Antigravity AI - Google DeepMind
--  Đây là file điều khiển chính (Master loader). Các tính năng sẽ được thêm dưới dạng module.
-- ]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
getgenv().Rayfield = Rayfield

-- Dịch vụ Roblox phổ biến
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- FPS & Ping Tracker
local fps = 0
local ping = 0
local lastTime = os.clock()
local frameCount = 0

local fpsConnection = RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = os.clock()
    if now - lastTime >= 1 then
        fps = math.floor(frameCount / (now - lastTime))
        frameCount = 0
        lastTime = now
    end
end)

task.spawn(function()
    while task.wait(2) do
        pcall(function()
            ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        end)
    end
end)

-- Khởi tạo Window chính
local Window = Rayfield:CreateWindow({
    Name = "NULLSCAPE Client",
    LoadingTitle = "NULLSCAPE Loader",
    LoadingSubtitle = "by Antigravity AI",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NULLSCAPE",
        FileName = "master_settings"
    },
    Discord = {
        Enabled = false,
        Invite = "nullscape",
        RememberJoins = true
    },
    KeySystem = false
})

-- Đối tượng quản lý chung của Client
local Client = {
    Window = Window,
    Tabs = {},
    Modules = {},
    ActiveConnections = {}
}
getgenv().Client = Client


-- Hàm đăng ký các module tính năng
function Client:LoadModule(moduleName, tabIcon, callback)
    local success, err = pcall(function()
        local newTab = self.Window:CreateTab(moduleName, tabIcon or 4483362458)
        self.Tabs[moduleName] = newTab
        
        -- Thực thi callback để khởi tạo các phần tử UI và Logic của module
        if callback then
            callback(newTab, self)
        end
    end)
    
    if not success then
        warn("Lỗi khi tải module [" .. tostring(moduleName) .. "]: " .. tostring(err))
    end
end

-- ==========================================
-- TAB: TRANG CHỦ (DASHBOARD)
-- ==========================================
local HomeTab = Window:CreateTab("Trang chủ", 4483362458)
Client.Tabs["Home"] = HomeTab

HomeTab:CreateSection("Thông tin người chơi")
HomeTab:CreateLabel("Tên tài khoản: " .. LocalPlayer.Name)
HomeTab:CreateLabel("Tên hiển thị: " .. LocalPlayer.DisplayName)
HomeTab:CreateLabel("Tuổi tài khoản: " .. LocalPlayer.AccountAge .. " ngày")

HomeTab:CreateSection("Thông số máy chủ")
local statsLabel = HomeTab:CreateLabel("FPS: Đang tính... | Ping: Đang tính... | Người chơi: 0/0")

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local playerCount = #Players:GetPlayers()
            local maxPlayers = Players.MaxPlayers
            statsLabel:Set(string.format("FPS: %d | Ping: %d ms | Người chơi: %d/%d", fps, ping, playerCount, maxPlayers))
        end)
    end
end)

-- ==========================================
-- TAB: CÀI ĐẶT (SETTINGS)
-- ==========================================
local SettingsTab = Window:CreateTab("Cài đặt", 4483362458)
Client.Tabs["Settings"] = SettingsTab

SettingsTab:CreateSection("Quản lý UI")
SettingsTab:CreateButton({
    Name = "Sao chép Discord Link",
    Callback = function()
        setclipboard("https://discord.gg/nullscape")
        Rayfield:Notify({
            Title = "NULLSCAPE",
            Content = "Đã sao chép link Discord vào bộ nhớ tạm!",
            Duration = 3
        })
    end
})

SettingsTab:CreateButton({
    Name = "Tắt hoàn toàn Client (Destroy UI)",
    Callback = function()
        pcall(function()
            -- Hủy các kết nối hệ thống
            if fpsConnection then fpsConnection:Disconnect() end
            for _, conn in pairs(Client.ActiveConnections) do
                if conn then conn:Disconnect() end
            end
            
            -- Hủy UI Rayfield
            Rayfield:Destroy()
        end)
    end
})

-- ==========================================
-- VÍ DỤ/HƯỚNG DẪN KHI THÊM MODULE MỚI:
-- ==========================================
-- [[
--  Để thêm một tính năng/module mới, bạn có thể gọi:
--
--  Client:LoadModule("Tên Tab Mới", 4483362458, function(Tab, Controller)
--      Tab:CreateSection("Danh mục 1")
--      Tab:CreateToggle({
--          Name = "Tính năng mẫu",
--          CurrentValue = false,
--          Callback = function(Value)
--              print("Trạng thái:", Value)
--          end
--      })
--  end)
-- ]]

-- ==========================================
-- TẢI CÁC MODULE TÍNH NĂNG
-- ==========================================
local success, err = pcall(function()
    local EntitiesController = loadstring(readfile("Entities/controller.luau"))()
    local EntitiesTab = loadstring(readfile("Entities/tab.luau"))()
    
    EntitiesTab(Client, EntitiesController)
end)

if not success then
    warn("[NULLSCAPE] Lỗi khi nạp module Entities: " .. tostring(err))
end

-- Tải cấu hình lưu trữ của Rayfield
Rayfield:LoadConfiguration()

