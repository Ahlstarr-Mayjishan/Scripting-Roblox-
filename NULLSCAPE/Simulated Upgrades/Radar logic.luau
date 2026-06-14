-- [[
--  NULLSCAPE - Custom Radar & ESP Logic
--  Vai trò: Chứa toàn bộ lõi logic định vị quà, nhạc cụ Cadence và đàn tế (Altar), các thuật toán tính toán,
--  nhận diện khoảng cách và phân loại. Cung cấp API logic để Executor và Controller sử dụng.
-- ]]

local Logic = {}

-- Bảng màu dùng chung cho các Highlight/Dot (Định nghĩa tập trung)
local ESPColors = {
    -- 1. Gifts & Mines
    Gift = Color3.fromRGB(255, 255, 255),          -- Trắng
    GoldenGift = Color3.fromRGB(255, 215, 0),      -- Vàng Gold
    PassageGift = Color3.fromRGB(135, 206, 250),   -- Light Sky Blue
    Tripmine = Color3.fromRGB(255, 0, 0),          -- Đỏ
    GoldenTripmine = Color3.fromRGB(255, 0, 0),    -- Đỏ
    
    -- 2. Cadence Instruments
    Cadence = Color3.fromRGB(255, 85, 255),        -- Hồng đậm / Magenta để phân biệt với Tripmine đỏ
    
    -- 3. Altars
    Altar = {
        Purgatory = Color3.new(1, 0.5, 0),
        Chance = Color3.new(1, 1, 0.7),
        Chaos = Color3.new(0.1, 0, 0),
        Echo = Color3.new(0.5, 0.33333, 1),
        Passage = Color3.new(0.7, 0, 0),
        Protection = Color3.fromRGB(0, 255, 255),
        Purification = Color3.fromRGB(255, 0, 255),
        Unknown = Color3.fromRGB(255, 128, 0)
    }
}
Logic.ESPColors = ESPColors

-- Nhận diện loại Altar dựa vào tên đối tượng hoặc cha/con của nó
local function getAltarTypeAndColor(altarObj)
    local objName = altarObj.Name:lower()
    for name, color in pairs(ESPColors.Altar) do
        local nameLower = name:lower()
        if string.find(objName, nameLower) then
            return name, color
        end
    end
    
    local parentName = altarObj.Parent and altarObj.Parent.Name:lower() or ""
    for name, color in pairs(ESPColors.Altar) do
        local nameLower = name:lower()
        if string.find(parentName, nameLower) then
            return name, color
        end
    end
    
    for _, child in ipairs(altarObj:GetChildren()) do
        local childName = child.Name:lower()
        for name, color in pairs(ESPColors.Altar) do
            local nameLower = name:lower()
            if string.find(childName, nameLower) then
                return name, color
            end
        end
    end
    
    return "Unknown", ESPColors.Altar.Unknown
end

-- Bộ lọc nhận dạng nhạc cụ Cadence
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

-- Helper để lấy hoặc tạo mũi tên chỉ hướng (đặc, không trong suốt)
local function getOrCreateArrow(saved, key, color)
    local arrow = saved[key]
    if not arrow or not arrow.Parent then
        arrow = Instance.new("Part")
        arrow.Name = key
        
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://118015691029311"
        mesh.Parent = arrow
        
        arrow.Material = Enum.Material.Neon
        arrow.Size = Vector3.new(1.3, 1.3, 1.3)
        arrow.CanCollide = false
        arrow.Anchored = true
        arrow.Transparency = 0
        arrow.Parent = workspace
        saved[key] = arrow
    end
    arrow.Color = color
    return arrow
end

-- Các hàm helper kiểm tra tính hợp lệ thời gian thực (lọc các đối tượng đã bị nhặt/ẩn/đổi tên)
local function isGiftValid(t)
    local part = t.part
    if not part or not part.Parent or not part:IsDescendantOf(workspace) then
        return false
    end
    local targetModel = t.model or part
    local nameLower = part.Name:lower()
    local parentNameLower = part.Parent and part.Parent.Name:lower() or ""
    local modelNameLower = targetModel.Name:lower()
    
    if not (string.find(nameLower, "gift") or string.find(nameLower, "present") or string.find(nameLower, "tripmine") or
            string.find(parentNameLower, "gift") or string.find(parentNameLower, "present") or string.find(parentNameLower, "tripmine") or
            string.find(modelNameLower, "gift") or string.find(modelNameLower, "present") or string.find(modelNameLower, "tripmine")) then
        return false
    end
    
    if part.Transparency >= 0.99 then
        return false
    end
    
    return true
end

local function isInstrumentValid(t)
    local part = t.part
    if not part or not part.Parent or not part:IsDescendantOf(workspace) then
        return false
    end
    local model = t.model or part
    if not isInstrument(model.Name) and not isInstrument(part.Name) then
        return false
    end
    if part.Transparency >= 0.99 then
        return false
    end
    return true
end

local function isAltarValid(t)
    local part = t.part
    if not part or not part.Parent or not part:IsDescendantOf(workspace) then
        return false
    end
    if part.Transparency >= 0.99 then
        return false
    end
    return true
end

-- Dọn dẹp toàn bộ Highlight, Beam, Dot và các đối tượng lưu đệm
function Logic.clearVisuals(gc, keepArrows)
    local saved = gc.SavedVisuals
    if not saved then return end
    
    if saved.ActiveTargets then
        for part, cached in pairs(saved.ActiveTargets) do
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
        end
        table.clear(saved.ActiveTargets)
    else
        saved.ActiveTargets = {}
    end
    
    -- Vô hiệu hóa và dọn dẹp Highlight Pool
    if saved.HighlightPool then
        for _, hl in ipairs(saved.HighlightPool) do
            hl.Adornee = nil
            hl.Enabled = false
        end
    end
    
    if saved.Highlights then table.clear(saved.Highlights) end
    if saved.Beams then table.clear(saved.Beams) end
    if saved.Attachments then table.clear(saved.Attachments) end
    if saved.Dots then table.clear(saved.Dots) end

    if saved.Barriers then
        for part, barrier in pairs(saved.Barriers) do
            pcall(function() barrier:Destroy() end)
        end
        table.clear(saved.Barriers)
    end

    if not keepArrows then
        if saved.HighlightPoolFolder then
            pcall(function() saved.HighlightPoolFolder:Destroy() end)
            saved.HighlightPoolFolder = nil
        end
        saved.HighlightPool = nil
        
        for _, key in ipairs({"ArrowGift", "ArrowCadence", "ArrowAltar"}) do
            if saved[key] then
                pcall(function() saved[key]:Destroy() end)
                saved[key] = nil
            end
        end
    end
end

-- Vòng lặp cập nhật khoảng cách, sắp xếp độ ưu tiên và chuyển đổi visual styles (chạy cực nhanh)
function Logic.updateESPStyles(controller, gc, hrp)
    local saved = gc.SavedVisuals
    if not saved.ActiveTargets then saved.ActiveTargets = {} end
    if not hrp then return end
    
    -- Khởi tạo bể chứa Highlight (Highlight Pool) cố định nếu chưa có
    if not saved.HighlightPool then
        saved.HighlightPool = {}
        local folder = Instance.new("Folder")
        folder.Name = "NULLSCAPE_HighlightPool"
        folder.Parent = workspace
        saved.HighlightPoolFolder = folder
        
        -- Tạo sẵn 15 Highlight dùng chung để tối ưu hóa hiệu năng render
        for i = 1, 15 do
            local hl = Instance.new("Highlight")
            hl.FillColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 1.0
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Enabled = false
            hl.Parent = folder
            table.insert(saved.HighlightPool, hl)
        end
    end
    
    local gifts = controller.GiftESPEnabled and (controller.ActiveGifts or {}) or {}
    local instruments = controller.CadenceESPEnabled and (controller.ActiveInstruments or {}) or {}
    local altars = controller.AltarESPEnabled and (controller.ActiveAltars or {}) or {}
    
    local validGifts = {}
    local validInstruments = {}
    local validAltars = {}
    
    -- Lọc các target hợp lệ và cập nhật khoảng cách
    for _, t in ipairs(gifts) do
        if isGiftValid(t) then
            t.distance = (hrp.Position - t.part.Position).Magnitude
            table.insert(validGifts, t)
        end
    end
    
    for _, t in ipairs(instruments) do
        if isInstrumentValid(t) then
            t.distance = (hrp.Position - t.part.Position).Magnitude
            table.insert(validInstruments, t)
        end
    end
    
    for _, t in ipairs(altars) do
        if isAltarValid(t) then
            local altarName = t.altarName or "Unknown"
            local filter = controller.AltarFilter
            local matchesFilter = false
            
            if typeof(filter) == "table" then
                if table.find(filter, "All") or table.find(filter, "Tất cả") or #filter == 0 then
                    matchesFilter = true
                else
                    matchesFilter = table.find(filter, altarName) ~= nil
                end
            else
                local filterStr = tostring(filter or "All")
                matchesFilter = (filterStr == "All" or filterStr == "Tất cả" or filterStr == altarName)
            end
            
            if matchesFilter then
                t.distance = (hrp.Position - t.part.Position).Magnitude
                table.insert(validAltars, t)
            end
        end
    end
    
    local currentTargets = {}  -- Chứa các mục tiêu vẽ 2D Dot/Ping
    local highlightTargets = {} -- Chứa các mục tiêu vẽ Highlight
    
    -- Phân loại: Altars
    for _, t in ipairs(validAltars) do
        if controller.ESPStyle == "Highlight" then
            table.insert(highlightTargets, t)
        else
            local style = controller.ESPStyle == "Ping" and "Ping" or "Dot"
            currentTargets[t.part] = {
                Style = style,
                Color = t.color,
                ParentObject = t.part
            }
        end
    end
    
    -- Phân loại: Nhạc cụ Cadence
    for _, t in ipairs(validInstruments) do
        if controller.ESPStyle == "Highlight" then
            table.insert(highlightTargets, t)
        else
            local style = controller.ESPStyle == "Ping" and "Ping" or "Dot"
            currentTargets[t.part] = {
                Style = style,
                Color = t.color,
                ParentObject = t.part
            }
        end
    end
    
    -- Phân loại: Quà & Bẫy mìn
    for _, t in ipairs(validGifts) do
        local part = t.part
        local targetModel = t.model or part
        local isGolden = (string.find(part.Name:lower(), "golden") ~= nil) or (string.find(targetModel.Name:lower(), "golden") ~= nil) or (part.Parent ~= nil and string.find(part.Parent.Name:lower(), "golden") ~= nil)
        
        if isGolden then
            -- Quà vàng/Mìn vàng luôn vẽ chấm Dot để không chiếm dụng Highlight pool
            currentTargets[part] = {
                Style = "Dot",
                Color = t.color,
                ParentObject = part
            }
        else
            if controller.ESPStyle == "Highlight" then
                table.insert(highlightTargets, t)
            else
                local style = controller.ESPStyle == "Ping" and "Ping" or "Dot"
                currentTargets[part] = {
                    Style = style,
                    Color = t.color,
                    ParentObject = part
                }
            end
        end
    end
    
    -- Phân bổ Highlight Pool cho tối đa 15 mục tiêu gần nhất sử dụng stable mapping để tránh lag giật FPS
    if not saved.Highlights then
        saved.Highlights = {}
    end
    local activeHighlights = saved.Highlights
    
    local desiredSet = {}
    local closestTargets = {}
    local numHighlights = math.min(#highlightTargets, 15)
    
    if #highlightTargets > 0 then
        table.sort(highlightTargets, function(a, b) return a.distance < b.distance end)
        
        for i = 1, numHighlights do
            local t = highlightTargets[i]
            local targetObject = t.model or t.part
            desiredSet[targetObject] = t
            table.insert(closestTargets, t)
        end
        
        -- Bất kỳ mục tiêu nào ngoài 15 mục tiêu gần nhất đều chuyển sang Dot
        for i = numHighlights + 1, #highlightTargets do
            local t = highlightTargets[i]
            currentTargets[t.part] = {
                Style = "Dot",
                Color = t.color,
                ParentObject = t.part
            }
        end
    end
    
    -- 1. Giải phóng các Highlight của các mục tiêu không còn trong top 15 nữa
    for targetObject, hl in pairs(activeHighlights) do
        if not desiredSet[targetObject] then
            hl.Adornee = nil
            hl.Enabled = false
            activeHighlights[targetObject] = nil
        end
    end
    
    -- 2. Tìm danh sách các Highlight đang rảnh trong pool
    local usedSet = {}
    for _, usedHl in pairs(activeHighlights) do
        usedSet[usedHl] = true
    end
    
    local freeHighlights = {}
    local pool = saved.HighlightPool
    for _, hl in ipairs(pool) do
        if not usedSet[hl] then
            table.insert(freeHighlights, hl)
        end
    end
    
    -- 3. Phân bổ Highlight cho các mục tiêu mới hoặc cập nhật thuộc tính
    for _, t in ipairs(closestTargets) do
        local targetObject = t.model or t.part
        local hl = activeHighlights[targetObject]
        
        if hl then
            -- Giữ nguyên Adornee để game engine không phải tính toán lại hình học (tránh drop FPS)
            if hl.OutlineColor ~= t.color then
                hl.OutlineColor = t.color
            end
            if not hl.Enabled then
                hl.Enabled = true
            end
        else
            -- Phân bổ một cái rảnh từ pool
            if #freeHighlights > 0 then
                local newHl = table.remove(freeHighlights)
                newHl.Adornee = targetObject
                newHl.OutlineColor = t.color
                newHl.Enabled = true
                activeHighlights[targetObject] = newHl
            else
                -- Fallback sang Dot
                currentTargets[t.part] = {
                    Style = "Dot",
                    Color = t.color,
                    ParentObject = t.part
                }
            end
        end
    end
    
    local scanTime = os.clock()
    
    -- 1. Xóa các BillboardGui (Dot/Ping) không còn tồn tại
    for targetPart, cached in pairs(saved.ActiveTargets) do
        local current = currentTargets[targetPart]
        if not current or not targetPart:IsDescendantOf(workspace) then
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
            saved.ActiveTargets[targetPart] = nil
        end
    end
    
    -- 2. Tạo hoặc cập nhật BillboardGui (Dot/Ping)
    for targetPart, current in pairs(currentTargets) do
        local cached = saved.ActiveTargets[targetPart]
        
        if not cached or cached.Style ~= current.Style then
            local oldDot = cached and cached.Dot
            
            local newCache = {
                Style = current.Style,
                Color = current.Color,
                LastSeen = scanTime,
                Dot = nil,
                Frame = nil
            }
            saved.ActiveTargets[targetPart] = newCache
            if oldDot then pcall(function() oldDot:Destroy() end) end
            
            pcall(function()
                if current.Style == "Ping" then
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
                    newCache.Frame = frame
                else
                    local billboard = Instance.new("BillboardGui")
                    billboard.Name = "NULLSCAPE_ESP_Dot"
                    billboard.Size = UDim2.new(0, 1, 0, 1)
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
                    newCache.Frame = frame
                end
            end)
        else
            cached.LastSeen = scanTime
            local frame = cached.Frame
            if frame and frame.Parent and frame.Parent.Parent then
                if frame.BackgroundColor3 ~= current.Color then
                    frame.BackgroundColor3 = current.Color
                end
            else
                saved.ActiveTargets[targetPart] = nil
            end
        end
    end
    
    -- 3. Xóa các BillboardGui (Dot/Ping) bị bỏ quên
    for targetPart, cached in pairs(saved.ActiveTargets) do
        if cached.LastSeen ~= scanTime then
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
            saved.ActiveTargets[targetPart] = nil
        end
    end
    
    -- Tìm các vị trí và khoảng cách gần nhất để render mũi tên trong RenderStepped (O(1))
    local nearestGiftPos = nil
    local nearestGiftColor = ESPColors.Gift
    local shortestGiftDist = math.huge
    if controller.GiftESPEnabled and #validGifts > 0 then
        for _, t in ipairs(validGifts) do
            -- Chỉ chỉ hướng tới quà thật (Gift, GoldenGift, PassageGift), tuyệt đối không chỉ vào mìn (Tripmine)
            if t.type and not string.find(t.type:lower(), "tripmine") then
                local dist = t.distance
                if dist < shortestGiftDist then
                    shortestGiftDist = dist
                    nearestGiftPos = t.part.Position
                    nearestGiftColor = t.color
                end
            end
        end
    end
    saved.NearestGiftPos = nearestGiftPos
    saved.NearestGiftDist = shortestGiftDist
    saved.NearestGiftColor = nearestGiftColor

    local nearestCadencePos = nil
    local shortestCadenceDist = math.huge
    local nearestCadenceColor = ESPColors.Cadence
    if controller.CadenceESPEnabled and #validInstruments > 0 then
        for _, t in ipairs(validInstruments) do
            local dist = t.distance
            if dist < shortestCadenceDist then
                shortestCadenceDist = dist
                nearestCadencePos = t.part.Position
                nearestCadenceColor = t.color
            end
        end
    end
    saved.NearestCadencePos = nearestCadencePos
    saved.NearestCadenceDist = shortestCadenceDist
    saved.NearestCadenceColor = nearestCadenceColor

    local nearestAltarPos = nil
    local shortestAltarDist = math.huge
    local nearestAltarColor = ESPColors.Altar.Unknown
    if controller.AltarESPEnabled and #validAltars > 0 then
        for _, t in ipairs(validAltars) do
            local dist = t.distance
            if dist < shortestAltarDist then
                shortestAltarDist = dist
                nearestAltarPos = t.part.Position
                nearestAltarColor = t.color
            end
        end
    end
    saved.NearestAltarPos = nearestAltarPos
    saved.NearestAltarDist = shortestAltarDist
    saved.NearestAltarColor = nearestAltarColor

    -- Đảm bảo các mũi tên tồn tại/hủy phù hợp dựa trên số lượng hợp lệ thực tế
    if controller.GiftESPEnabled and nearestGiftPos then
        getOrCreateArrow(saved, "ArrowGift", nearestGiftColor)
    else
        if saved.ArrowGift then
            pcall(function() saved.ArrowGift:Destroy() end)
            saved.ArrowGift = nil
        end
    end
    
    if controller.CadenceESPEnabled and nearestCadencePos then
        getOrCreateArrow(saved, "ArrowCadence", nearestCadenceColor)
    else
        if saved.ArrowCadence then
            pcall(function() saved.ArrowCadence:Destroy() end)
            saved.ArrowCadence = nil
        end
    end
    
    if controller.AltarESPEnabled and nearestAltarPos then
        getOrCreateArrow(saved, "ArrowAltar", nearestAltarColor)
    else
        if saved.ArrowAltar then
            pcall(function() saved.ArrowAltar:Destroy() end)
            saved.ArrowAltar = nil
        end
    end
end

-- Cập nhật chuyển động thời gian thực của các mũi tên và Ping
function Logic.updateRender(controller, gc, hrp)
    local saved = gc.SavedVisuals
    if not hrp then
        for _, name in ipairs({"ArrowGift", "ArrowCadence", "ArrowAltar"}) do
            local arrow = saved[name]
            if arrow then arrow.Transparency = 1 end
        end
        return
    end
    
    local nearestGiftPos = saved.NearestGiftPos
    local nearestGiftColor = saved.NearestGiftColor or ESPColors.Gift
    local nearestGiftDist = saved.NearestGiftDist or math.huge
    local nearestCadencePos = saved.NearestCadencePos
    local nearestCadenceColor = saved.NearestCadenceColor or ESPColors.Cadence
    local nearestCadenceDist = saved.NearestCadenceDist or math.huge
    local nearestAltarPos = saved.NearestAltarPos
    local nearestAltarColor = saved.NearestAltarColor or ESPColors.Altar.Unknown
    local nearestAltarDist = saved.NearestAltarDist or math.huge

    -- Xác định độ cao đầu (Head) của người chơi
    local char = hrp.Parent
    local head = char and char:FindFirstChild("Head")
    local headY = head and head.Position.Y or (hrp.Position.Y + 1.5)

    -- 2. Cập nhật hiển thị và hướng xoay cho Mũi tên Hộp quà (Trắng / Vàng / Đỏ)
    local arrowGift = saved.ArrowGift
    if arrowGift and arrowGift.Parent then
        if nearestGiftPos and nearestGiftDist > 3.5 then
            arrowGift.Transparency = 0
            arrowGift.Color = nearestGiftColor
            arrowGift.Material = Enum.Material.Neon
            
            -- Tính hướng 2D nằm ngang để tránh mũi tên bị nghiêng lên/xuống đất khi lại gần
            local flatDir = (nearestGiftPos - hrp.Position) * Vector3.new(1, 0, 1)
            if flatDir.Magnitude > 0.01 then
                flatDir = flatDir.Unit
            else
                flatDir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
                flatDir = flatDir.Magnitude > 0.01 and flatDir.Unit or Vector3.new(0, 0, -1)
            end
            
            -- Đặt song song với Head của user, cách 2.5 studs (gần nhất)
            local arrowPos = Vector3.new(hrp.Position.X + flatDir.X * 2.5, headY, hrp.Position.Z + flatDir.Z * 2.5)
            arrowGift.CFrame = CFrame.lookAt(arrowPos, arrowPos + flatDir)
        else
            arrowGift.Transparency = 1
        end
    end
    
    -- 3. Cập nhật hiển thị và hướng xoay cho Mũi tên Nhạc cụ (Hồng)
    local arrowCadence = saved.ArrowCadence
    if arrowCadence and arrowCadence.Parent then
        if nearestCadencePos and nearestCadenceDist > 3.5 then
            arrowCadence.Transparency = 0
            arrowCadence.Color = nearestCadenceColor
            arrowCadence.Material = Enum.Material.Neon
            
            local flatDir = (nearestCadencePos - hrp.Position) * Vector3.new(1, 0, 1)
            if flatDir.Magnitude > 0.01 then
                flatDir = flatDir.Unit
            else
                flatDir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
                flatDir = flatDir.Magnitude > 0.01 and flatDir.Unit or Vector3.new(0, 0, -1)
            end
            
            -- Đặt song song với Head của user, cách 3.3 studs (tầng giữa)
            local arrowPos = Vector3.new(hrp.Position.X + flatDir.X * 3.3, headY, hrp.Position.Z + flatDir.Z * 3.3)
            arrowCadence.CFrame = CFrame.lookAt(arrowPos, arrowPos + flatDir)
        else
            arrowCadence.Transparency = 1
        end
    end
    
    -- 4. Cập nhật hiển thị và hướng xoay cho Mũi tên Đàn tế (Màu tương ứng của Altar)
    local arrowAltar = saved.ArrowAltar
    if arrowAltar and arrowAltar.Parent then
        if nearestAltarPos and nearestAltarDist > 3.5 then
            arrowAltar.Transparency = 0
            arrowAltar.Color = nearestAltarColor
            arrowAltar.Material = Enum.Material.Neon
            
            local flatDir = (nearestAltarPos - hrp.Position) * Vector3.new(1, 0, 1)
            if flatDir.Magnitude > 0.01 then
                flatDir = flatDir.Unit
            else
                flatDir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
                flatDir = flatDir.Magnitude > 0.01 and flatDir.Unit or Vector3.new(0, 0, -1)
            end
            
            -- Đặt song song với Head của user, cách 4.1 studs (xa nhất)
            local arrowPos = Vector3.new(hrp.Position.X + flatDir.X * 4.1, headY, hrp.Position.Z + flatDir.Z * 4.1)
            arrowAltar.CFrame = CFrame.lookAt(arrowPos, arrowPos + flatDir)
        else
            arrowAltar.Transparency = 1
        end
    end
    
    -- 5. Cập nhật kích thước và ẩn/hiện chế độ Ping
    if controller.ESPStyle == "Ping" and saved.ActiveTargets then
        for targetPart, cached in pairs(saved.ActiveTargets) do
            if cached.Style == "Ping" and cached.Dot then
                if targetPart and targetPart.Parent and targetPart:IsDescendantOf(workspace) then
                    local dist = (hrp.Position - targetPart.Position).Magnitude
                    local frame = cached.Frame
                    if frame then
                        cached.Dot.Enabled = true
                        local size = math.clamp(dist / 20, 6, 10)
                        frame.Size = UDim2.new(0, size, 0, size)
                        frame.BackgroundTransparency = 0
                    end
                end
            end
        end
    end
end

Logic.isInstrument = isInstrument
Logic.getAltarTypeAndColor = getAltarTypeAndColor

return Logic
