-- [[
--  NULLSCAPE - Unlock & Radar Controller
--  Quản lý trạng thái, vòng lặp quét định vị và thu gom rác (GC) tài nguyên.
-- ]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Executor = getgenv().loadModule("NULLSCAPE/Unlock/executor.luau")

local Controller = {
    RadarSpoofEnabled = false,
    GiftESPEnabled = false,
    CadenceESPEnabled = false,
    AltarESPEnabled = false,
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

-- Bật/tắt bẻ khóa nâng cấp Radar gốc của Game
function Controller:SetRadarSpoof(value)
    self.RadarSpoofEnabled = value
    if value then
        pcall(function()
            Executor.spoofUpgrades(LocalPlayer)
        end)
    end
end

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

-- Tạo Hộp quà Thử nghiệm (Client-Side) trong Workspace.Item_Pools
function Controller:SpawnTestGift()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if getgenv().Rayfield then
            getgenv().Rayfield:Notify({
                Title = "Lỗi",
                Content = "Không tìm thấy nhân vật để tạo Hộp quà thử nghiệm!",
                Duration = 3
            })
        end
        return
    end

    -- 1. Tìm hoặc tạo thư mục Workspace.Item_Pools
    local itemPools = workspace:FindFirstChild("Item_Pools")
    if not itemPools then
        itemPools = Instance.new("Folder")
        itemPools.Name = "Item_Pools"
        itemPools.Parent = workspace
    end

    -- 2. Tạo cấu trúc thư mục/Model: Item_Pools.GiftShell
    local giftShellFolder = itemPools:FindFirstChild("GiftShell")
    if not giftShellFolder then
        giftShellFolder = Instance.new("Folder")
        giftShellFolder.Name = "GiftShell"
        giftShellFolder.Parent = itemPools
    end

    -- 3. Tạo Part làm hộp quà thử nghiệm (dạng khối Neon màu đỏ hồng)
    local giftShell = Instance.new("Part")
    giftShell.Name = "GiftShell"
    giftShell.Material = Enum.Material.Neon
    giftShell.Color = Color3.fromRGB(255, 60, 100) -- Màu đỏ quà tặng đặc trưng
    giftShell.Size = Vector3.new(1.8, 1.8, 1.8)
    giftShell.CFrame = hrp.CFrame * CFrame.new(0, 0, -5) -- Tạo trước mặt người chơi 5 studs
    giftShell.Anchored = true
    giftShell.CanCollide = true
    giftShell.Parent = giftShellFolder

    if getgenv().Rayfield then
        getgenv().Rayfield:Notify({
            Title = "Thành công",
            Content = "Đã tạo Hộp quà Thử nghiệm tại Workspace.Item_Pools.GiftShell.GiftShell!",
            Duration = 3
        })
    end
end

-- Vòng lặp định kỳ tìm kiếm và cập nhật ESP (Không gây giật lag)
task.spawn(function()
    while not Controller.Destroyed do
        task.wait(1.5) -- Chu kỳ quét 1.5 giây một lần cực kỳ tối ưu
        if Controller.Destroyed then break end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                Executor.updateESP(Controller, hrp)
            end)
        end
    end
end)

-- Vòng lặp cập nhật chuyển động mượt mà của 3 mũi tên chỉ hướng (Bobbing & Xoay)
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
        
        local timeSec = tick()
        
        -- 1. Mũi tên Hộp quà (Màu trắng neon, tầng thấp)
        local arrowGift = Controller.SavedVisuals.ArrowGift
        if arrowGift and arrowGift.Parent then
            if Controller.NearestGiftPosition then
                arrowGift.Transparency = 0
                local bobbing = Vector3.new(0, math.sin(timeSec * 4) * 0.15, 0)
                local arrowPos = hrp.Position + Vector3.new(0, 3.5, 0) + bobbing
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
                local bobbing = Vector3.new(0, math.sin(timeSec * 4 + 1.3) * 0.15, 0)
                local arrowPos = hrp.Position + Vector3.new(0, 4.8, 0) + bobbing
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
                local bobbing = Vector3.new(0, math.sin(timeSec * 4 + 2.6) * 0.15, 0)
                local arrowPos = hrp.Position + Vector3.new(0, 6.1, 0) + bobbing
                arrowAltar.CFrame = CFrame.lookAt(arrowPos, Controller.NearestAltarPosition)
            else
                arrowAltar.Transparency = 1
            end
        end
    end)
    table.insert(Controller.ActiveConnections, runConn)
end)

return Controller
