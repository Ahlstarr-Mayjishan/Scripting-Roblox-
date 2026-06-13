-- [[
--  NULLSCAPE - Custom Radar & ESP Logic
--  Vai trò: Chứa toàn bộ lõi logic định vị quà, nhạc cụ Cadence và đàn tế (Altar), các thuật toán tính toán,
--  nhận diện khoảng cách và phân loại. Cung cấp API logic để Executor và Controller sử dụng.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local RadarLogic = {
    GiftESPEnabled = true,
    CadenceESPEnabled = true,
    AltarESPEnabled = true,
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
        Highlights = {},
        Beams = {},
        Attachments = {},
        Dots = {},
        ActiveTargets = {}, -- Cache lưu các vật thể để tái sử dụng
        ArrowGift = nil,
        ArrowCadence = nil,
        ArrowAltar = nil
    }
}

-- Mũi tên chỉ hướng dùng MeshId gốc của game (đặc, không trong suốt)
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

local function clearVisuals(saved, keepArrows)
    if not saved then return end
    
    if saved.ActiveTargets then
        for part, cached in pairs(saved.ActiveTargets) do
            if cached.Highlight then pcall(function() cached.Highlight:Destroy() end) end
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
        end
        table.clear(saved.ActiveTargets)
    else
        saved.ActiveTargets = {}
    end
    
    if saved.Highlights then table.clear(saved.Highlights) end
    if saved.Beams then table.clear(saved.Beams) end
    if saved.Attachments then table.clear(saved.Attachments) end
    if saved.Dots then table.clear(saved.Dots) end

    if not keepArrows then
        for _, key in ipairs({"ArrowGift", "ArrowCadence", "ArrowAltar"}) do
            if saved[key] then
                pcall(function() saved[key]:Destroy() end)
                saved[key] = nil
            end
        end
    end
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

-- Nhận diện loại Altar
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

-- Vòng lặp quét định vị chính bằng cơ chế lưu đệm (Caching & Reusing) tránh giật lag
local function updateESP(hrp)
    local saved = RadarLogic.SavedVisuals
    if not saved.ActiveTargets then saved.ActiveTargets = {} end
    
    local nearestAltar = nil
    local shortestAltarDist = math.huge
    
    local gifts = {}
    local instruments = {}
    local altars = {}
    
    -- 1. Thu thập Hộp quà trong Workspace.Item_Pools
    if RadarLogic.GiftESPEnabled then
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
    
    -- 2. Thu thập Nhạc cụ trong Workspace.Item_Pools và Enemies
    if RadarLogic.CadenceESPEnabled then
        local function scanFolder(folder)
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
        if itemPools then scanFolder(itemPools) end
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then scanFolder(enemies) end
    end
    
    -- 3. Thu thập Đàn tế trong Workspace.CurrentRooms
    if RadarLogic.AltarESPEnabled then
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if currentRooms then
            for _, room in ipairs(currentRooms:GetChildren()) do
                local altarObj = room:FindFirstChild("AltarLocation") or room:FindFirstChild("AltarModel") or room:FindFirstChild("Altar")
                if altarObj then
                    local targetPart = altarObj:IsA("Model") and (altarObj:FindFirstChild("HumanoidRootPart") or altarObj:FindFirstChildWhichIsA("BasePart")) or altarObj
                    if targetPart and targetPart:IsA("BasePart") then
                        local altarName, altarColor = getAltarTypeAndColor(altarObj)
                        local filter = RadarLogic.AltarFilter or "Tất cả"
                        
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
    
    -- Gộp toàn bộ để xử lý giới hạn 31 Highlight
    local allTargets = {}
    for _, t in ipairs(gifts) do table.insert(allTargets, t) end
    for _, t in ipairs(instruments) do table.insert(allTargets, t) end
    for _, t in ipairs(altars) do table.insert(allTargets, t) end
    
    table.sort(allTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Xây dựng các đối tượng cần vẽ ESP
    local currentTargets = {}
    for idx, target in ipairs(allTargets) do
        local targetPart = target.part
        local targetModel = target.model or targetPart
        local color = target.color
        
        local desiredStyle, parentObject
        if RadarLogic.ESPStyle == "Highlight" and idx <= 31 then
            desiredStyle = "Highlight"
            parentObject = targetModel
        elseif RadarLogic.ESPStyle == "Ping" and idx <= 31 then
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
    for targetPart, cached in pairs(saved.ActiveTargets) do
        local current = currentTargets[targetPart]
        if not current or current.Style ~= cached.Style or not targetPart:IsDescendantOf(workspace) then
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
    
    -- 3. Quét dọn các cache bị bỏ quên
    for targetPart, cached in pairs(saved.ActiveTargets) do
        if cached.LastSeen ~= scanTime then
            if cached.Highlight then pcall(function() cached.Highlight:Destroy() end) end
            if cached.Dot then pcall(function() cached.Dot:Destroy() end) end
            saved.ActiveTargets[targetPart] = nil
        end
    end
    
    -- --- PHẦN 5: CẬP NHẬT DANH SÁCH CHI TIẾT ĐỂ TÍNH REAL-TIME TRONG RENDERSTEPPED ---
    RadarLogic.CachedGiftParts = gifts
    RadarLogic.CachedCadenceParts = instruments
    RadarLogic.CachedAltarParts = altars
    
    -- Đảm bảo các mũi tên tồn tại/hủy phù hợp với cấu hình bật/tắt
    if RadarLogic.GiftESPEnabled and #gifts > 0 then
        getOrCreateArrow(saved, "ArrowGift", Color3.fromRGB(255, 255, 255))
    else
        if saved.ArrowGift then pcall(function() saved.ArrowGift:Destroy() end) saved.ArrowGift = nil end
    end
    
    if RadarLogic.CadenceESPEnabled and #instruments > 0 then
        getOrCreateArrow(saved, "ArrowCadence", Color3.fromRGB(255, 0, 0))
    else
        if saved.ArrowCadence then pcall(function() saved.ArrowCadence:Destroy() end) saved.ArrowCadence = nil end
    end
    
    if RadarLogic.AltarESPEnabled and #altars > 0 then
        local _, altarColor = getAltarTypeAndColor(nearestAltar or altars[1].part)
        getOrCreateArrow(saved, "ArrowAltar", altarColor)
    else
        if saved.ArrowAltar then pcall(function() saved.ArrowAltar:Destroy() end) saved.ArrowAltar = nil end
    end
end

-- Hàm trigger cập nhật ESP tức thì khi thay đổi cấu hình
local function triggerInstantUpdate()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(updateESP, hrp)
    end
end

function RadarLogic:SetGiftESP(value)
    self.GiftESPEnabled = value
    triggerInstantUpdate()
end

function RadarLogic:SetCadenceESP(value)
    self.CadenceESPEnabled = value
    triggerInstantUpdate()
end

function RadarLogic:SetAltarESP(value)
    self.AltarESPEnabled = value
    triggerInstantUpdate()
end

function RadarLogic:SetAltarFilter(option)
    self.AltarFilter = option or "Tất cả"
    triggerInstantUpdate()
end

function RadarLogic:SetESPStyle(style)
    self.ESPStyle = style or "Highlight"
    pcall(function()
        clearVisuals(self.SavedVisuals, true)
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

-- Vòng lặp quét định kỳ (Chu kỳ 3 giây cực kỳ tối ưu và nhẹ)
task.spawn(function()
    while not RadarLogic.Destroyed do
        task.wait(3.0)
        if RadarLogic.Destroyed then break end
        
        -- Tự động tắt nếu đã mở khóa Radar chính thức của game
        if checkRadarUnlocked() then
            if getgenv().Rayfield then
                getgenv().Rayfield:Notify({
                    Title = "Radar Auto Disabled",
                    Content = "Official game radar detected. Custom radar disabled!",
                    Duration = 5
                })
            end
            RadarLogic.Destroyed = true
            clearVisuals(RadarLogic.SavedVisuals, false)
            break
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(updateESP, hrp)
        end
    end
end)

-- Vòng lặp RenderStepped (Mũi tên orbit cách 5 studs, đặc hoàn toàn, không nhấp nhô)
local runConn
runConn = RunService.RenderStepped:Connect(function()
    if RadarLogic.Destroyed then
        if runConn then runConn:Disconnect() end
        return
    end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        for _, name in ipairs({"ArrowGift", "ArrowCadence", "ArrowAltar"}) do
            local arrow = RadarLogic.SavedVisuals[name]
            if arrow then arrow.Transparency = 1 end
        end
        return
    end
    
    -- 1. Tìm vị trí các vật thể gần nhất thời gian thực (real-time) từ danh sách cache bộ nhớ
    local nearestGiftPos = nil
    if RadarLogic.GiftESPEnabled and RadarLogic.CachedGiftParts then
        local shortestDist = math.huge
        for _, t in ipairs(RadarLogic.CachedGiftParts) do
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
    if RadarLogic.CadenceESPEnabled and RadarLogic.CachedCadenceParts then
        local shortestDist = math.huge
        for _, t in ipairs(RadarLogic.CachedCadenceParts) do
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
    if RadarLogic.AltarESPEnabled and RadarLogic.CachedAltarParts then
        local shortestDist = math.huge
        for _, t in ipairs(RadarLogic.CachedAltarParts) do
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
    local arrowGift = RadarLogic.SavedVisuals.ArrowGift
    if arrowGift and arrowGift.Parent then
        if nearestGiftPos then
            arrowGift.Transparency = 0
            local arrowPos = hrp.Position + Vector3.new(0, 3.5, 0)
            arrowGift.CFrame = CFrame.lookAt(arrowPos, nearestGiftPos) * CFrame.Angles(0, math.pi, 0)
        else
            arrowGift.Transparency = 1
        end
    end
    
    -- 3. Cập nhật hiển thị và hướng xoay cho Mũi tên Nhạc cụ (Đỏ, tầng trung)
    local arrowCadence = RadarLogic.SavedVisuals.ArrowCadence
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
    local arrowAltar = RadarLogic.SavedVisuals.ArrowAltar
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
    if RadarLogic.SavedVisuals.ActiveTargets then
        for targetPart, cached in pairs(RadarLogic.SavedVisuals.ActiveTargets) do
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
table.insert(RadarLogic.ActiveConnections, runConn)

return RadarLogic
