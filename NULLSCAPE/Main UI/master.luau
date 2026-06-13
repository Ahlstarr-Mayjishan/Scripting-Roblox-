-- [[
--  NULLSCAPE Master Script (Modular Rayfield UI Edition)
--  Tạo bởi Antigravity AI - Google DeepMind
--  Đây là file điều khiển chính (Master loader). Các tính năng sẽ được thêm dưới dạng module.
-- ]]

-- Đối tượng quản lý chung của Client
local Client = {
    Window = nil,
    Tabs = {},
    Modules = {},
    ActiveConnections = {},
    Destroyed = false
}
getgenv().Client = Client

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
        if Client.Destroyed then break end
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
Client.Window = Window


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
HomeTab:CreateLabel("Tuổi tài khoản: " .. LocalPlayer.AccountAge .. " ngày")

HomeTab:CreateSection("Thông số máy chủ")
local statsLabel = HomeTab:CreateLabel("FPS: Đang tính... | Ping: Đang tính... | Người chơi: 0/0")

task.spawn(function()
    while task.wait(1) do
        if Client.Destroyed then break end
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

SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        pcall(function()
            -- Đánh dấu Client đã bị hủy để dừng các luồng/vòng lặp
            Client.Destroyed = true
            
            -- 1. Hủy các kết nối hệ thống chính trong master
            if fpsConnection then
                pcall(function() fpsConnection:Disconnect() end)
            end
            for _, conn in pairs(Client.ActiveConnections) do
                if conn then
                    pcall(function() conn:Disconnect() end)
                end
            end
            
            -- 2. Hủy các module con và giải phóng tài nguyên của chúng
            for name, module in pairs(Client.Modules) do
                if typeof(module) == "table" then
                    module.Destroyed = true
                    if typeof(module.CleanUp) == "function" then
                        pcall(function() module:CleanUp() end)
                    end
                    pcall(function() table.clear(module) end)
                end
            end
            
            -- 3. Hủy UI Rayfield
            Rayfield:Destroy()
            
            -- 4. Giải phóng các biến môi trường toàn cục
            getgenv().Rayfield = nil
            getgenv().Client = nil
            getgenv().loadModule = nil
            
            -- 5. Xóa sạch dữ liệu trong bảng Client chính
            table.clear(Client)
            
            -- 6. Thu gom rác (Garbage Collector) để giải phóng RAM & Memory hoàn toàn
            local cg = collectgarbage
            if cg then
                pcall(cg, "collect")
            end
        end)
    end
})

local function loadModule(path)
    local githubRawUrl = "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/"
    return loadstring(game:HttpGet(githubRawUrl .. path))()
end
getgenv().loadModule = loadModule

-- Tải các module con
local success, err = pcall(function()
    local EntitiesController = loadModule("NULLSCAPE/Entities/controller.luau")
    Client.Modules["EntitiesController"] = EntitiesController
    local EntitiesTab = loadModule("NULLSCAPE/Entities/tab.luau")
    
    EntitiesTab(Client, EntitiesController)
end)

if not success then
    warn("[NULLSCAPE] Lỗi khi nạp module Entities: " .. tostring(err))
end

-- Tải cấu hình lưu trữ của Rayfield
Rayfield:LoadConfiguration()

