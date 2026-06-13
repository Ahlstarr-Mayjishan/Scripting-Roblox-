-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Phát lệnh gọi quét định vị (scan) định kỳ thông qua Executor.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/executor.luau")
local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local GC = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/GC.luau")

local Controller = {
    GiftESPEnabled = false,
    CadenceESPEnabled = false,
    AltarESPEnabled = false,
    AltarFilter = "Tất cả",
    ESPStyle = "Highlight", -- Mặc định: "Highlight" hoặc "Dot"
    Destroyed = false,
    
    NearestGiftPosition = nil,
    NearestCadencePosition = nil,
    NearestAltarPosition = nil,
    CachedGiftParts = {},
    CachedCadenceParts = {},
    CachedAltarParts = {},
}

-- Hàm trigger cập nhật ESP tức thì khi thay đổi cấu hình
local function triggerInstantUpdate()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function()
            Executor.updateESP(Controller, GC, hrp)
        end)
    end
end

-- Bật/tắt định vị hộp quà
function Controller:SetGiftESP(value)
    self.GiftESPEnabled = value
    triggerInstantUpdate()
end

-- Bật/tắt định vị nhạc cụ Cadence
function Controller:SetCadenceESP(value)
    self.CadenceESPEnabled = value
    triggerInstantUpdate()
end

-- Bật/tắt định vị Đàn tế (Altar)
function Controller:SetAltarESP(value)
    self.AltarESPEnabled = value
    triggerInstantUpdate()
end

-- Bộ lọc loại Altar
function Controller:SetAltarFilter(option)
    self.AltarFilter = option or "Tất cả"
    triggerInstantUpdate()
end

-- Thay đổi chế độ hiển thị ESP
function Controller:SetESPStyle(style)
    self.ESPStyle = style or "Highlight"
    pcall(function()
        Executor.clearVisuals(GC, true)
    end)
    triggerInstantUpdate()
end

-- Hàm phát hiện nâng cấp Radar chính thức của game đã mở khóa (Tối ưu hóa tránh đệ quy sâu)
local function checkRadarUnlocked()
    local unlocked = false
    local function check(parent)
        if not parent then return end
        
        -- Bỏ qua các thư mục GUI, Scripts, Backpack,... của Player để tránh lag
        local pName = parent.Name
        if pName == "PlayerGui" or pName == "PlayerScripts" or pName == "Backpack" or pName == "StarterGear" then
            return
        end
        
        for _, child in ipairs(parent:GetChildren()) do
            local name = child.Name:lower()
            if string.find(name, "radar") then
                if child:IsA("BoolValue") and child.Value == true then
                    unlocked = true
                    break
                elseif (child:IsA("NumberValue") or child:IsA("IntValue")) and child.Value >= 1 then
                    unlocked = true
                    break
                end
            end
            if not unlocked then
                check(child)
            end
        end
    end
    pcall(function() check(LocalPlayer) end)
    return unlocked
end

-- Hàm dọn dẹp tài nguyên (GC) khi tắt hoặc hủy UI
function Controller:CleanUp()
    self.Destroyed = true
    GC.cleanAll()
end

-- Vòng lặp định kỳ tìm kiếm và cập nhật ESP (Không gây giật lag)
task.spawn(function()
    while not Controller.Destroyed do
        task.wait(3.0) -- Chu kỳ quét 3.0 giây một lần cực kỳ tối ưu
        if Controller.Destroyed then break end
        
        -- Nếu người chơi đã mở khóa Radar chính thức của game, tắt script ngay
        if checkRadarUnlocked() then
            if getgenv().Rayfield then
                getgenv().Rayfield:Notify({
                    Title = "Radar Auto Disabled",
                    Content = "Official game radar detected. Custom radar disabled to optimize performance!",
                    Duration = 5
                })
            end
            Controller:CleanUp()
            break
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                Executor.updateESP(Controller, GC, hrp)
            end)
        end
    end
end)

-- Vòng lặp cập nhật chuyển động mượt mà của 3 mũi tên chỉ hướng
task.spawn(function()
    local runConn
    runConn = RunService.RenderStepped:Connect(function()
        if Controller.Destroyed then
            if runConn then runConn:Disconnect() end
            return
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        pcall(function()
            Logic.updateRender(Controller, GC, hrp)
        end)
    end)
    GC.registerConnection(runConn)
end)

return Controller
