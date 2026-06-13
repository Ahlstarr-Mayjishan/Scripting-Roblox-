-- [[
--  NULLSCAPE - Simulated Upgrades & Radar Executor
--  Thực thi dọn dẹp vẽ cũ và định vị vẽ ESP/Highlight mới.
-- ]]

local Executor = {}

-- 2. Dọn dẹp toàn bộ Highlight, Beam, Dot và các đối tượng lưu đệm
function Executor.clearVisuals(savedVisuals, keepArrows)
    if not savedVisuals then return end
    
    if savedVisuals.ActiveTargets then
        for part, cached in pairs(savedVisuals.ActiveTargets) do
            if cached.Highlight then pcall(function() cached.Highlight:Destroy() end) end
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
        end
        table.clear(savedVisuals.ActiveTargets)
    else
        savedVisuals.ActiveTargets = {}
    end
    
    -- Xóa các mảng cũ (tương thích ngược)
    if savedVisuals.Highlights then table.clear(savedVisuals.Highlights) end
    if savedVisuals.Beams then table.clear(savedVisuals.Beams) end
    if savedVisuals.Attachments then table.clear(savedVisuals.Attachments) end
    if savedVisuals.Dots then table.clear(savedVisuals.Dots) end

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

-- Danh sách màu sắc tương ứng cho các loại Altar
local altarColors = {
    Purgatory = Color3.new(1, 0.5, 0),
    Chance = Color3.new(1, 1, 0.7),
    Chaos = Color3.new(0.1, 0, 0),
    Echo = Color3.new(0.5, 0.33333, 1),
    Passage = Color3.new(0.7, 0, 0),
    Protection = Color3.fromRGB(0, 255, 255),
    Purification = Color3.fromRGB(255, 0, 255)
}

-- Nhận diện loại Altar dựa vào tên đối tượng hoặc cha/con của nó
local function getAltarTypeAndColor(altarObj)
    local objName = altarObj.Name:lower()
    for name, color in pairs(altarColors) do
        local nameLower = name:lower()
        if string.find(objName, nameLower) then
            return name, color
        end
    end
    
    local parentName = altarObj.Parent and altarObj.Parent.Name:lower() or ""
    for name, color in pairs(altarColors) do
        local nameLower = name:lower()
        if string.find(parentName, nameLower) then
            return name, color
        end
    end
    
    for _, child in ipairs(altarObj:GetChildren()) do
        local childName = child.Name:lower()
        for name, color in pairs(altarColors) do
            local nameLower = name:lower()
            if string.find(childName, nameLower) then
                return name, color
            end
        end
    end
    
    return "Unknown", Color3.fromRGB(255, 128, 0) -- Mặc định là màu cam
end

-- 3. Quét định vị và vẽ các chỉ dẫn/Highlight bằng cơ chế lưu đệm (Caching & Reusing) để tránh giật lag
function Executor.updateESP(controller, hrp)
    local saved = controller.SavedVisuals
    if not saved.ActiveTargets then saved.ActiveTargets = {} end
    
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
    
    -- --- PHẦN 3: THU THẬP ĐÀN TẾ (ALTAR) CÓ LỌC THEO TÊN ---
    if controller.AltarESPEnabled then
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if currentRooms then
            for _, room in ipairs(currentRooms:GetChildren()) do
                local altarObj = room:FindFirstChild("AltarLocation") or room:FindFirstChild("AltarModel") or room:FindFirstChild("Altar")
                if altarObj then
                    local targetPart = altarObj:IsA("Model") and (altarObj:FindFirstChild("HumanoidRootPart") or altarObj:FindFirstChildWhichIsA("BasePart")) or altarObj
                    if targetPart and targetPart:IsA("BasePart") then
                        local altarName, altarColor = getAltarTypeAndColor(altarObj)
                        local filter = controller.AltarFilter or "Tất cả"
                        
                        if filter == "Tất cả" or filter == altarName then
                            local distance = (hrp.Position - targetPart.Position).Magnitude
                            if distance < shortestAltarDist then
                                shortestAltarDist = distance
                                nearestAltar = targetPart
                            end
                            table.insert(altars, {part = targetPart, model = altarObj, distance = distance, color = altarColor, type = "Altar"})
                        end
                    end
                end
            end
        end
    end
    
    -- --- PHẦN 4: GỘP VÀ SẮP XẾP ---
    local allTargets = {}
    for _, t in ipairs(gifts) do table.insert(allTargets, t) end
    for _, t in ipairs(instruments) do table.insert(allTargets, t) end
    for _, t in ipairs(altars) do table.insert(allTargets, t) end
    
    table.sort(allTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Xây dựng bảng các đối tượng cần hiển thị trong lần quét này
    local currentTargets = {}
    
    for idx, target in ipairs(allTargets) do
        local targetPart = target.part
        local targetModel = target.model or targetPart
        local color = target.color
        
        local desiredStyle, parentObject
        if controller.ESPStyle == "Highlight" and idx <= 31 then
            desiredStyle = "Highlight"
            parentObject = targetModel
        elseif controller.ESPStyle == "Ping" and idx <= 31 then
            desiredStyle = "Ping"
            parentObject = targetPart
        else
            desiredStyle = "Dot"
            parentObject = targetPart
        end
        
        currentTargets[targetPart] = {
            Style = desiredStyle,
            Color = color,
            ParentObject = parentObject
        }
    end
    
    local scanTime = os.clock()
    
    -- 1. Xóa các ESP lỗi thời hoặc bị đổi style hoặc không còn tồn tại
    local toRemove = {}
    for targetPart, cached in pairs(saved.ActiveTargets) do
        local current = currentTargets[targetPart]
        if not current or current.Style ~= cached.Style or not targetPart:IsDescendantOf(workspace) then
            table.insert(toRemove, targetPart)
        end
    end
    for _, targetPart in ipairs(toRemove) do
        local cached = saved.ActiveTargets[targetPart]
        if cached then
            if cached.Highlight then pcall(function() cached.Highlight:Destroy() end) end
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
            saved.ActiveTargets[targetPart] = nil
        end
    end
    
    -- 2. Tạo hoặc Cập nhật ESP mới/hiện tại
    for targetPart, current in pairs(currentTargets) do
        local cached = saved.ActiveTargets[targetPart]
        
        if not cached then
            local newCache = {
                Style = current.Style,
                Color = current.Color,
                LastSeen = scanTime,
                Highlight = nil,
                Dot = nil
            }
            
            if current.Style == "Highlight" then
                local highlight = Instance.new("Highlight")
                highlight.Name = "NULLSCAPE_ESP_Highlight"
                highlight.FillColor = current.Color
                highlight.FillTransparency = 1.0
                highlight.OutlineColor = current.Color
                highlight.OutlineTransparency = 0.0
                highlight.Parent = current.ParentObject
                newCache.Highlight = highlight
            elseif current.Style == "Ping" then
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "NULLSCAPE_ESP_Ping"
                billboard.Size = UDim2.new(0, 16, 0, 16)
                billboard.AlwaysOnTop = true
                
                local frame = Instance.new("Frame")
                frame.Name = "PingFrame"
                frame.Size = UDim2.new(0, 10, 0, 10)
                frame.AnchorPoint = Vector2.new(0.5, 0.5)
                frame.Position = UDim2.new(0.5, 0, 0.5, 0)
                frame.Rotation = 45
                frame.BackgroundColor3 = current.Color
                frame.BorderSizePixel = 0
                
                frame.Parent = billboard
                billboard.Parent = current.ParentObject
                newCache.Dot = billboard
            else
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "NULLSCAPE_ESP_Dot"
                billboard.Size = UDim2.new(0, 2, 0, 2)
                billboard.AlwaysOnTop = true
                
                local frame = Instance.new("Frame")
                frame.Size = UDim2.new(1, 0, 1, 0)
                frame.BackgroundColor3 = current.Color
                frame.BorderSizePixel = 0
                
                local uiCorner = Instance.new("UICorner")
                uiCorner.CornerRadius = UDim.new(1, 0)
                uiCorner.Parent = frame
                
                frame.Parent = billboard
                billboard.Parent = current.ParentObject
                newCache.Dot = billboard
            end
            
            saved.ActiveTargets[targetPart] = newCache
        else
            -- Đã có sẵn visual đúng loại, chỉ cập nhật LastSeen và kiểm tra màu
            cached.LastSeen = scanTime
            local inst = cached.Highlight or cached.Dot
            if inst and inst.Parent then
                if cached.Style == "Highlight" then
                    if inst.OutlineColor ~= current.Color then
                        inst.OutlineColor = current.Color
                        inst.FillColor = current.Color
                    end
                elseif cached.Style == "Ping" then
                    local frame = inst:FindFirstChild("PingFrame")
                    if frame and frame.BackgroundColor3 ~= current.Color then
                        frame.BackgroundColor3 = current.Color
                    end
                else
                    local frame = inst:FindFirstChildOfClass("Frame")
                    if frame and frame.BackgroundColor3 ~= current.Color then
                        frame.BackgroundColor3 = current.Color
                    end
                end
            else
                -- Instance đã bị hủy mất, đánh dấu xóa để lần sau tạo lại
                saved.ActiveTargets[targetPart] = nil
            end
        end
    end
    
    -- 3. Quét dọn các cache bị bỏ quên (an toàn bổ sung)
    for targetPart, cached in pairs(saved.ActiveTargets) do
        if cached.LastSeen ~= scanTime then
            if cached.Highlight then pcall(function() cached.Highlight:Destroy() end) end
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
            saved.ActiveTargets[targetPart] = nil
        end
    end
    
    -- --- PHẦN 5: CẬP NHẬT DANH SÁCH CHI TIẾT ĐỂ TÍNH REAL-TIME TRONG RENDERSTEPPED ---
    controller.CachedGiftParts = gifts
    controller.CachedCadenceParts = instruments
    controller.CachedAltarParts = altars
    
    -- Đảm bảo các mũi tên tồn tại/hủy phù hợp với cấu hình bật/tắt
    if controller.GiftESPEnabled and #gifts > 0 then
        getOrCreateArrow(saved, "ArrowGift", Color3.fromRGB(255, 255, 255))
    else
        if saved.ArrowGift then pcall(function() saved.ArrowGift:Destroy() end) saved.ArrowGift = nil end
    end
    
    if controller.CadenceESPEnabled and #instruments > 0 then
        getOrCreateArrow(saved, "ArrowCadence", Color3.fromRGB(255, 0, 0))
    else
        if saved.ArrowCadence then pcall(function() saved.ArrowCadence:Destroy() end) saved.ArrowCadence = nil end
    end
    
    if controller.AltarESPEnabled and #altars > 0 then
        local _, altarColor = getAltarTypeAndColor(nearestAltar or altars[1].part)
        getOrCreateArrow(saved, "ArrowAltar", altarColor)
    else
        if saved.ArrowAltar then pcall(function() saved.ArrowAltar:Destroy() end) saved.ArrowAltar = nil end
    end
end

return Executor
