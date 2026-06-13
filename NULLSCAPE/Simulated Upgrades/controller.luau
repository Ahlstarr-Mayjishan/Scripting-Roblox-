-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Controller
--  Vai trò: Đảm nhiệm việc quan sát hiệu năng, phân tích tài nguyên và đưa ra các quyết định điều phối:
--  - Giám sát trạng thái hoạt động của script, điều phối chế độ ngủ đông (hibernating) tối ưu CPU.
--  - Phát hiện trạng thái sảnh chờ/trận đấu (khi inLobby = false sẽ kích hoạt gọi quét scan).
--  - Phát lệnh gọi quét định vị (scan) định kỳ thông qua Executor.
--  - Gửi kết nối đăng ký qua GC và phát lệnh dọn dẹp giải phóng tài nguyên.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/executor.luau")
local Logic = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/Radar logic.luau")
local GC = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/GC.luau")

local Controller = {
    GiftESPEnabled = false,
    CadenceESPEnabled = false,
    AltarESPEnabled = false,
    AltarFilter = {"All"},
    ESPStyle = "Highlight", -- Mặc định: "Highlight" hoặc "Dot"
    Destroyed = false,
    
    NearestGiftPosition = nil,
    NearestCadencePosition = nil,
    NearestAltarPosition = nil,
    CachedGiftParts = {},
    CachedCadenceParts = {},
    CachedAltarParts = {},
}

local inLobby = false       -- Đang ở sảnh chờ/lựa chọn

-- Hàm cập nhật trạng thái sảnh chờ và tự động dọn dẹp visual khi vào sảnh
local function setInLobby(val)
    if inLobby == val then return end
    inLobby = val
    if val then
        pcall(function()
            Executor.clearVisuals(GC, false)
        end)
    end
end

-- Xác minh kiểm tra trạng thái game bằng ReplicatedStorage.InRound
local function isInMatch()
    local inRoundVal = ReplicatedStorage:FindFirstChild("InRound")
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        return inRoundVal.Value
    end
    return false
end

-- Lắng nghe sự kiện đổi trạng thái game thời gian thực
task.spawn(function()
    local inRoundVal = ReplicatedStorage:WaitForChild("InRound", 15)
    if inRoundVal and inRoundVal:IsA("BoolValue") then
        local conn = inRoundVal.Changed:Connect(function(val)
            if Controller.Destroyed then return end
            setInLobby(not val)
        end)
        GC.registerConnection(conn)
    end
end)

-- Hàm trigger cập nhật ESP tức thì khi thay đổi cấu hình
local function triggerInstantUpdate()
    if inLobby then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function()
            Executor.scanTargets(Controller, GC, hrp)
            Executor.updateESPStyles(Controller, GC, hrp)
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

-- Bộ lọc loại Altar (Hỗ trợ multi-select table)
function Controller:SetAltarFilter(option)
    if typeof(option) == "string" then
        self.AltarFilter = {option}
    else
        self.AltarFilter = option or {"All"}
    end
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

-- Vòng lặp định kỳ tìm kiếm và cập nhật ESP (Không gây giật lag, hỗ trợ ngủ đông)
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
        
        local currentInMatch = isInMatch()
        setInLobby(not currentInMatch)
        if not currentInMatch then
            continue
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                Executor.scanTargets(Controller, GC, hrp)
                Executor.updateESPStyles(Controller, GC, hrp)
            end)
        end
    end
end)

-- Vòng lặp cập nhật khoảng cách & styles hiển thị (Dot <-> Highlight) cực nhanh mỗi 0.3 giây
task.spawn(function()
    while not Controller.Destroyed do
        task.wait(0.3)
        if Controller.Destroyed then break end
        if inLobby then continue end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                Executor.updateESPStyles(Controller, GC, hrp)
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
        
        -- Bỏ qua Render khi đang ở Lobby để tiết kiệm tài nguyên
        if inLobby then
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
