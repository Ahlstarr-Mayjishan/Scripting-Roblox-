-- [[
--  NULLSCAPE - Unlock & Radar Controller
--  Quản lý trạng thái, vòng lặp quét định vị và thu gom rác (GC) tài nguyên.
-- ]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Unlock/executor.luau")

local Controller = {
    GiftESPEnabled = false,
    CadenceESPEnabled = false,
    AltarESPEnabled = false,
    ESPStyle = "Highlight", -- Mặc định: "Highlight" hoặc "Dot"
    Destroyed = false,
    
    NearestGiftPosition = nil,
    NearestCadencePosition = nil,
    NearestAltarPosition = nil,
    
    ActiveConnections = {},
    SavedVisuals = {
        Highlights = {}, -- Danh sách phát sáng
        Beams = {},      -- Danh sách tia sáng chỉ dẫn
        Attachments = {}, -- Danh sách các attachment đính kèm
        ArrowGift = nil,  -- Mũi tên chỉ hộp quà (Màu trắng)
        ArrowCadence = nil, -- Mũi tên chỉ nhạc cụ Cadence (Màu đỏ)
        ArrowAltar = nil  -- Mũi tên chỉ đàn tế / Altar (Màu cam)
    }
}

-- Bật/tắt định vị hộp quà
function Controller:SetGiftESP(value)
    self.GiftESPEnabled = value
    if not value then
        pcall(function()
            Executor.clearVisuals(self.SavedVisuals)
        end)
    end
end

-- Bật/tắt định vị nhạc cụ Cadence
function Controller:SetCadenceESP(value)
    self.CadenceESPEnabled = value
    if not value then
        pcall(function()
            Executor.clearVisuals(self.SavedVisuals)
        end)
    end
end

-- Bật/tắt định vị Đàn tế (Altar)
function Controller:SetAltarESP(value)
    self.AltarESPEnabled = value
    if not value then
        pcall(function()
            Executor.clearVisuals(self.SavedVisuals)
        end)
    end
end

-- Hàm phát hiện nâng cấp Radar chính thức của game đã mở khóa
local function checkRadarUnlocked()
    local unlocked = false
    local function check(parent)
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
            check(child)
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
        task.wait(1.5) -- Chu kỳ quét 1.5 giây một lần cực kỳ tối ưu
        if Controller.Destroyed then break end
        
        -- Nếu người chơi đã mở khóa Radar chính thức của game, tắt script ngay
        if checkRadarUnlocked() then
            if getgenv().Rayfield then
                getgenv().Rayfield:Notify({
                    Title = "Radar tự động tắt",
                    Content = "Phát hiện bạn đã sở hữu Radar chính thức của game. Radar custom tự động tắt để tối ưu hiệu năng!",
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
        
        -- 1. Mũi tên Hộp quà (Màu trắng neon, tầng thấp)
        local arrowGift = Controller.SavedVisuals.ArrowGift
        if arrowGift and arrowGift.Parent then
            if Controller.NearestGiftPosition then
                arrowGift.Transparency = 0
                local dir = (Controller.NearestGiftPosition - hrp.Position)
                local dir2D = Vector3.new(dir.X, 0, dir.Z).Unit
                local arrowPos = hrp.Position + dir2D * 5 + Vector3.new(0, -1.0, 0)
                arrowGift.CFrame = CFrame.lookAt(arrowPos, Controller.NearestGiftPosition)
            else
                arrowGift.Transparency = 1
            end
        end
        
        -- 2. Mũi tên Nhạc cụ Cadence (Màu đỏ neon, tầng trung)
        local arrowCadence = Controller.SavedVisuals.ArrowCadence
        if arrowCadence and arrowCadence.Parent then
            if Controller.NearestCadencePosition then
                arrowCadence.Transparency = 0
                local dir = (Controller.NearestCadencePosition - hrp.Position)
                local dir2D = Vector3.new(dir.X, 0, dir.Z).Unit
                local arrowPos = hrp.Position + dir2D * 5 + Vector3.new(0, 0.5, 0)
                arrowCadence.CFrame = CFrame.lookAt(arrowPos, Controller.NearestCadencePosition)
            else
                arrowCadence.Transparency = 1
            end
        end
        
        -- 3. Mũi tên Đàn tế / Altar (Màu cam neon, tầng cao)
        local arrowAltar = Controller.SavedVisuals.ArrowAltar
        if arrowAltar and arrowAltar.Parent then
            if Controller.NearestAltarPosition then
                arrowAltar.Transparency = 0
                local dir = (Controller.NearestAltarPosition - hrp.Position)
                local dir2D = Vector3.new(dir.X, 0, dir.Z).Unit
                local arrowPos = hrp.Position + dir2D * 5 + Vector3.new(0, 2.0, 0)
                arrowAltar.CFrame = CFrame.lookAt(arrowPos, Controller.NearestAltarPosition)
            else
                arrowAltar.Transparency = 1
            end
        end
    end)
    table.insert(Controller.ActiveConnections, runConn)
end)

return Controller
