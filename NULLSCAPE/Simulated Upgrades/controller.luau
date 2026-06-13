-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Controller
--  Vai trò: Đảm nhiệm việc quan sát, điều chỉnh cấu hình định vị, điều phối luồng xử lý,
--  gọi các tính năng dọn dẹp dọn rác (GC) để clean và giải phóng / giới hạn tài nguyên
--  nhằm tránh sụt giảm FPS, tối ưu hóa hiệu suất game và nâng cao trải nghiệm người dùng.
-- ]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Simulated Upgrades/executor.luau")

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
    
    ActiveConnections = {},
    SavedVisuals = {
        Highlights = {}, -- Danh sách phát sáng
        Beams = {},      -- Danh sách tia sáng chỉ dẫn
        Attachments = {}, -- Danh sách các attachment đính kèm
        Dots = {},
        ActiveTargets = {}, -- Cache lưu các vật thể đang được vẽ ESP để tái sử dụng
        ArrowGift = nil,  -- Mũi tên chỉ hộp quà (Màu trắng)
        ArrowCadence = nil, -- Mũi tên chỉ nhạc cụ Cadence (Màu đỏ)
        ArrowAltar = nil  -- Mũi tên chỉ đàn tế / Altar (Màu cam)
    }
}

-- Hàm trigger cập nhật ESP tức thì khi thay đổi cấu hình
local function triggerInstantUpdate()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function()
            Executor.updateESP(Controller, hrp)
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
        Executor.clearVisuals(self.SavedVisuals, true)
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
    -- Ngắt toàn bộ kết nối sự kiện
    for _, conn in ipairs(self.ActiveConnections) do
        if conn then conn:Disconnect() end
    end
    self.ActiveConnections = {}
    
    -- Xóa toàn bộ tia sáng & Highlight khỏi game
    pcall(function()
        Executor.clearVisuals(self.SavedVisuals)
    end)
    
    self.Destroyed = true
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
                Executor.updateESP(Controller, hrp)
            end)
        end
    end
end)

-- Vòng lặp cập nhật chuyển động mượt mà của 3 mũi tên chỉ hướng (Lấy người chơi làm trung tâm, cách 5 studs)
task.spawn(function()
    local RunService = game:GetService("RunService")
    local runConn
    runConn = RunService.RenderStepped:Connect(function()
        if Controller.Destroyed then
            if runConn then runConn:Disconnect() end
            return
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            -- Ẩn tất cả mũi tên nếu không có nhân vật
            for _, arrowName in ipairs({"ArrowGift", "ArrowCadence", "ArrowAltar"}) do
                local arrow = Controller.SavedVisuals[arrowName]
                if arrow then arrow.Transparency = 1 end
            end
            return
        end
        
        -- 1. Tìm vị trí các vật thể gần nhất thời gian thực (real-time) từ danh sách cache bộ nhớ
        local nearestGiftPos = nil
        if Controller.GiftESPEnabled and Controller.CachedGiftParts then
            local shortestDist = math.huge
            for _, t in ipairs(Controller.CachedGiftParts) do
                local part = t.part
                if part and part.Parent and part:IsDescendantOf(workspace) then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        nearestGiftPos = part.Position
                    end
                end
            end
        end

        local nearestCadencePos = nil
        if Controller.CadenceESPEnabled and Controller.CachedCadenceParts then
            local shortestDist = math.huge
            for _, t in ipairs(Controller.CachedCadenceParts) do
                local part = t.part
                if part and part.Parent and part:IsDescendantOf(workspace) then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        nearestCadencePos = part.Position
                    end
                end
            end
        end

        local nearestAltarPos = nil
        local nearestAltarColor = Color3.fromRGB(255, 128, 0)
        if Controller.AltarESPEnabled and Controller.CachedAltarParts then
            local shortestDist = math.huge
            for _, t in ipairs(Controller.CachedAltarParts) do
                local part = t.part
                if part and part.Parent and part:IsDescendantOf(workspace) then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        nearestAltarPos = part.Position
                        nearestAltarColor = t.color
                    end
                end
            end
        end

        -- 2. Cập nhật hiển thị và hướng xoay cho Mũi tên Hộp quà (Trắng, tầng thấp)
        local arrowGift = Controller.SavedVisuals.ArrowGift
        if arrowGift and arrowGift.Parent then
            if nearestGiftPos then
                arrowGift.Transparency = 0
                local arrowPos = hrp.Position + Vector3.new(0, 3.5, 0)
                arrowGift.CFrame = CFrame.lookAt(arrowPos, nearestGiftPos) * CFrame.Angles(0, math.pi, 0)
            else
                arrowGift.Transparency = 1
            end
        end
        
        -- 3. Cập nhật hiển thị và hướng xoay cho Mũi tên Nhạc cụ Cadence (Màu đỏ neon, tầng trung)
        local arrowCadence = Controller.SavedVisuals.ArrowCadence
        if arrowCadence and arrowCadence.Parent then
            if nearestCadencePos then
                arrowCadence.Transparency = 0
                local arrowPos = hrp.Position + Vector3.new(0, 4.7, 0)
                arrowCadence.CFrame = CFrame.lookAt(arrowPos, nearestCadencePos) * CFrame.Angles(0, math.pi, 0)
            else
                arrowCadence.Transparency = 1
            end
        end
        
        -- 4. Cập nhật hiển thị và hướng xoay cho Mũi tên Đàn tế / Altar (Màu tương ứng, tầng cao)
        local arrowAltar = Controller.SavedVisuals.ArrowAltar
        if arrowAltar and arrowAltar.Parent then
            if nearestAltarPos then
                arrowAltar.Transparency = 0
                arrowAltar.Color = nearestAltarColor
                local arrowPos = hrp.Position + Vector3.new(0, 5.9, 0)
                arrowAltar.CFrame = CFrame.lookAt(arrowPos, nearestAltarPos) * CFrame.Angles(0, math.pi, 0)
            else
                arrowAltar.Transparency = 1
            end
        end
        
        -- 4. Cập nhật kích thước và ẩn/hiện chế độ Ping (lại gần thì thu nhỏ về 0 và tắt để giải phóng)
        if Controller.SavedVisuals.ActiveTargets then
            for targetPart, cached in pairs(Controller.SavedVisuals.ActiveTargets) do
                if cached.Style == "Ping" and cached.Dot then
                    if not targetPart or not targetPart.Parent or not targetPart:IsDescendantOf(workspace) then
                        continue
                    end
                    local dist = (hrp.Position - targetPart.Position).Magnitude
                    local frame = cached.Dot:FindFirstChild("PingFrame")
                    if frame then
                        if dist < 50 then
                            cached.Dot.Enabled = false
                            frame.Size = UDim2.new(0, 0, 0, 0)
                        else
                            cached.Dot.Enabled = true
                            -- Thu nhỏ từ 10px (ở >= 200 studs) về 0px (ở <= 50 studs)
                            local scale = math.clamp((dist - 50) / 150, 0, 1)
                            local newSize = scale * 10
                            frame.Size = UDim2.new(0, newSize, 0, newSize)
                            frame.BackgroundTransparency = 0
                        end
                    end
                end
            end
        end
    end)
    table.insert(Controller.ActiveConnections, runConn)
end)

return Controller
