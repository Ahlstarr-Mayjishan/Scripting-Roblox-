-- [[
--  NULLSCAPE - Unlock & Radar Executor
--  Thực thi dọn dẹp vẽ cũ và định vị vẽ ESP/Highlight mới.
-- ]]

local Executor = {}

-- 2. Dọn dẹp toàn bộ Highlight, Beam & Dot cũ
function Executor.clearVisuals(savedVisuals, keepArrows)
    if not savedVisuals then return end
    
    for _, hl in ipairs(savedVisuals.Highlights) do
        if hl then pcall(function() hl:Destroy() end) end
    end
    table.clear(savedVisuals.Highlights)
    
    for _, beam in ipairs(savedVisuals.Beams) do
        if beam then pcall(function() beam:Destroy() end) end
    end
    table.clear(savedVisuals.Beams)
    
    for _, att in ipairs(savedVisuals.Attachments) do
        if att then pcall(function() att:Destroy() end) end
    end
    table.clear(savedVisuals.Attachments)

    if savedVisuals.Dots then
        for _, dot in ipairs(savedVisuals.Dots) do
            if dot then pcall(function() dot:Destroy() end) end
        end
        table.clear(savedVisuals.Dots)
    else
        savedVisuals.Dots = {}
    end

    if not keepArrows then
        for _, key in ipairs({"ArrowGift", "ArrowCadence", "ArrowAltar"}) do
            if savedVisuals[key] then
                pcall(function() savedVisuals[key]:Destroy() end)
                savedVisuals[key] = nil
            end
        end
    end
end

-- Helper để lấy hoặc tạo mũi tên chỉ hướng (đặc, không trong suốt)
local function getOrCreateArrow(saved, key, color)
    local arrow = saved[key]
    if not arrow or not arrow.Parent then
        local success = pcall(function()
            arrow = Instance.new("MeshPart")
            arrow.Name = key
            arrow.MeshId = "rbxassetid://118015691029311"
        end)
        
        if not success or not arrow then
            arrow = Instance.new("Part")
            arrow.Name = key
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://118015691029311"
            mesh.Parent = arrow
        end
        
        arrow.Material = Enum.Material.Neon
        arrow.Size = Vector3.new(1.3, 1.3, 1.3)
        arrow.CanCollide = false
        arrow.Anchored = true
        arrow.Transparency = 0 -- Hoàn toàn đặc
        arrow.Parent = workspace
        saved[key] = arrow
    end
    arrow.Color = color
    return arrow
end

-- Danh sách từ khóa của các nhạc cụ Cadence thường gặp
local instrumentKeywords = {"harp", "violin", "guitar", "flute", "drum", "piano", "trumpet", "instrument"}

local function isInstrument(name)
    if not name then return false end
    local nameLower = name:lower()
    for _, keyword in ipairs(instrumentKeywords) do
        if string.find(nameLower, keyword) then
            return true
        end
    end
    return false
end

-- 3. Quét định vị và vẽ các chỉ dẫn/Highlight
function Executor.updateESP(controller, hrp)
    -- Xóa các chỉ dẫn cũ (giữ lại các mũi tên để cập nhật CFrame tránh nhấp nháy)
    Executor.clearVisuals(controller.SavedVisuals, true)
    
    local saved = controller.SavedVisuals
    if not saved.Dots then saved.Dots = {} end
    
    local nearestGift = nil
    local shortestGiftDist = math.huge
    local nearestCadence = nil
    local shortestCadenceDist = math.huge
    local nearestAltar = nil
    local shortestAltarDist = math.huge
    
    local gifts = {}
    local instruments = {}
    local altars = {}
    
    -- --- PHẦN 1: THU THẬP HỘP QUÀ ---
    if controller.GiftESPEnabled then
        local itemPools = workspace:FindFirstChild("Item_Pools")
        if itemPools then
            for _, obj in ipairs(itemPools:GetDescendants()) do
                if obj:IsA("BasePart") and (string.find(obj.Name:lower(), "gift") or string.find(obj.Name:lower(), "present")) then
                    local distance = (hrp.Position - obj.Position).Magnitude
                    if distance < shortestGiftDist then
                        shortestGiftDist = distance
                        nearestGift = obj
                    end
                    table.insert(gifts, {part = obj, distance = distance, color = Color3.fromRGB(255, 255, 255), type = "Gift"})
                end
            end
        end
    end
    
    -- --- PHẦN 2: THU THẬP NHẠC CỤ CADENCE ---
    if controller.CadenceESPEnabled then
        local function scanFolderForInstruments(folder)
            for _, obj in ipairs(folder:GetDescendants()) do
                if (obj:IsA("BasePart") or obj:IsA("Model")) and isInstrument(obj.Name) then
                    local targetPart = obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj
                    if targetPart and targetPart:IsA("BasePart") then
                        local distance = (hrp.Position - targetPart.Position).Magnitude
                        if distance < shortestCadenceDist then
                            shortestCadenceDist = distance
                            nearestCadence = targetPart
                        end
                        table.insert(instruments, {part = targetPart, model = obj, distance = distance, color = Color3.fromRGB(255, 0, 0), type = "Cadence"})
                    end
                end
            end
        end
        
        local itemPools = workspace:FindFirstChild("Item_Pools")
        if itemPools then scanFolderForInstruments(itemPools) end
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then scanFolderForInstruments(enemies) end
    end
    
    -- --- PHẦN 3: THU THẬP ĐÀN TẾ (ALTAR) ---
    if controller.AltarESPEnabled then
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if currentRooms then
            for _, room in ipairs(currentRooms:GetChildren()) do
                local altarObj = room:FindFirstChild("AltarLocation") or room:FindFirstChild("AltarModel") or room:FindFirstChild("Altar")
                if altarObj then
                    local targetPart = altarObj:IsA("Model") and (altarObj:FindFirstChild("HumanoidRootPart") or altarObj:FindFirstChildWhichIsA("BasePart")) or altarObj
                    if targetPart and targetPart:IsA("BasePart") then
                        local distance = (hrp.Position - targetPart.Position).Magnitude
                        if distance < shortestAltarDist then
                            shortestAltarDist = distance
                            nearestAltar = targetPart
                        end
                        table.insert(altars, {part = targetPart, model = altarObj, distance = distance, color = Color3.fromRGB(255, 128, 0), type = "Altar"})
                    end
                end
            end
        end
    end
    
    -- --- PHẦN 4: GỘP VÀ SẮP XẾP ĐỂ RENDER HIGHLIGHTS / DOTS ---
    local allTargets = {}
    for _, t in ipairs(gifts) do table.insert(allTargets, t) end
    for _, t in ipairs(instruments) do table.insert(allTargets, t) end
    for _, t in ipairs(altars) do table.insert(allTargets, t) end
    
    table.sort(allTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    for idx, target in ipairs(allTargets) do
        local targetPart = target.part
        local targetModel = target.model or targetPart
        local color = target.color
        
        if controller.ESPStyle == "Highlight" and idx <= 31 then
            -- Vẽ Highlight phát sáng: Viền đặc (Outline = 0), Trong suốt bên trong (Fill = 1)
            local highlight = Instance.new("Highlight")
            highlight.FillColor = color
            highlight.FillTransparency = 1.0
            highlight.OutlineColor = color
            highlight.OutlineTransparency = 0.0
            highlight.Parent = targetModel
            table.insert(saved.Highlights, highlight)
        else
            -- Vẽ dấu chấm (BillboardGui) cho các vật thể xa hơn khi vượt quá 31 hoặc khi ở chế độ Dot (kích thước 2px)
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 2, 0, 2)
            billboard.AlwaysOnTop = true
            
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundColor3 = color
            frame.BorderSizePixel = 0
            
            local uiCorner = Instance.new("UICorner")
            uiCorner.CornerRadius = UDim.new(1, 0)
            uiCorner.Parent = frame
            
            frame.Parent = billboard
            billboard.Parent = targetPart
            table.insert(saved.Dots, billboard)
        end
    end
    
    -- --- PHẦN 5: CẬP NHẬT CHỈ HƯỚNG GẦN NHẤT ---
    -- A. Hộp quà
    if nearestGift then
        controller.NearestGiftPosition = nearestGift.Position
        getOrCreateArrow(saved, "ArrowGift", Color3.fromRGB(255, 255, 255))
    else
        controller.NearestGiftPosition = nil
        if saved.ArrowGift then
            pcall(function() saved.ArrowGift:Destroy() end)
            saved.ArrowGift = nil
        end
    end
    
    -- B. Nhạc cụ Cadence
    if nearestCadence then
        controller.NearestCadencePosition = nearestCadence.Position
        getOrCreateArrow(saved, "ArrowCadence", Color3.fromRGB(255, 0, 0))
    else
        controller.NearestCadencePosition = nil
        if saved.ArrowCadence then
            pcall(function() saved.ArrowCadence:Destroy() end)
            saved.ArrowCadence = nil
        end
    end
    
    -- C. Đàn tế (Altar)
    if nearestAltar then
        controller.NearestAltarPosition = nearestAltar.Position
        getOrCreateArrow(saved, "ArrowAltar", Color3.fromRGB(255, 128, 0))
    else
        controller.NearestAltarPosition = nil
        if saved.ArrowAltar then
            pcall(function() saved.ArrowAltar:Destroy() end)
            saved.ArrowAltar = nil
        end
    end
end

return Executor
