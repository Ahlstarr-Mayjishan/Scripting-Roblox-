-- [[
--  NULLSCAPE - Custom Radar & ESP Logic
--  Module định vị quà, nhạc cụ Cadence và đàn tế (Altar) dưới dạng mũi tên và Highlight/Dot.
-- ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local RadarLogic = {
    GiftESPEnabled = true,
    CadenceESPEnabled = true,
    AltarESPEnabled = true,
    ESPStyle = "Highlight", -- Mặc định: "Highlight" hoặc "Dot"
    Destroyed = false,
    
    NearestGiftPosition = nil,
    NearestCadencePosition = nil,
    NearestAltarPosition = nil,
    
    ActiveConnections = {},
    SavedVisuals = {
        Highlights = {},
        Beams = {},
        Attachments = {},
        Dots = {},
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
    for _, hl in ipairs(saved.Highlights) do
        if hl then pcall(function() hl:Destroy() end) end
    end
    table.clear(saved.Highlights)
    
    for _, beam in ipairs(saved.Beams) do
        if beam then pcall(function() beam:Destroy() end) end
    end
    table.clear(saved.Beams)
    
    for _, att in ipairs(saved.Attachments) do
        if att then pcall(function() att:Destroy() end) end
    end
    table.clear(saved.Attachments)
    
    for _, dot in ipairs(saved.Dots) do
        if dot then pcall(function() dot:Destroy() end) end
    end
    table.clear(saved.Dots)

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

-- Vòng lặp quét định vị chính
local function updateESP(hrp)
    clearVisuals(RadarLogic.SavedVisuals, true)
    local saved = RadarLogic.SavedVisuals
    
    local nearestGift = nil
    local shortestGiftDist = math.huge
    local nearestCadence = nil
    local shortestCadenceDist = math.huge
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
                    if distance < shortestGiftDist then
                        shortestGiftDist = distance
                        nearestGift = obj
                    end
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
    
    -- Gộp toàn bộ để xử lý giới hạn 31 Highlight
    local allTargets = {}
    for _, t in ipairs(gifts) do table.insert(allTargets, t) end
    for _, t in ipairs(instruments) do table.insert(allTargets, t) end
    for _, t in ipairs(altars) do table.insert(allTargets, t) end
    
    table.sort(allTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Áp dụng Highlight hoặc Dot (qua tường)
    for idx, target in ipairs(allTargets) do
        local targetPart = target.part
        local targetModel = target.model or targetPart
        local color = target.color
        
        if idx <= 31 then
            -- Highlight: viền đặc (Outline = 0), ruột trong suốt (Fill = 1)
            local highlight = Instance.new("Highlight")
            highlight.FillColor = color
            highlight.FillTransparency = 1.0
            highlight.OutlineColor = color
            highlight.OutlineTransparency = 0.0
            highlight.Parent = targetModel
            table.insert(saved.Highlights, highlight)
        else
            -- Vượt quá 31: Vẽ dấu chấm tròn (BillboardGui) cho các vật thể ở xa (kích thước 2px)
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
    
    -- Cập nhật vị trí Mũi tên gần nhất
    -- A. Hộp quà
    if nearestGift then
        RadarLogic.NearestGiftPosition = nearestGift.Position
        getOrCreateArrow(saved, "ArrowGift", Color3.fromRGB(255, 255, 255))
    else
        RadarLogic.NearestGiftPosition = nil
        if saved.ArrowGift then pcall(function() saved.ArrowGift:Destroy() end) saved.ArrowGift = nil end
    end
    
    -- B. Nhạc cụ
    if nearestCadence then
        RadarLogic.NearestCadencePosition = nearestCadence.Position
        getOrCreateArrow(saved, "ArrowCadence", Color3.fromRGB(255, 0, 0))
    else
        RadarLogic.NearestCadencePosition = nil
        if saved.ArrowCadence then pcall(function() saved.ArrowCadence:Destroy() end) saved.ArrowCadence = nil end
    end
    
    -- C. Đàn tế
    if nearestAltar then
        RadarLogic.NearestAltarPosition = nearestAltar.Position
        getOrCreateArrow(saved, "ArrowAltar", Color3.fromRGB(255, 128, 0))
    else
        RadarLogic.NearestAltarPosition = nil
        if saved.ArrowAltar then pcall(function() saved.ArrowAltar:Destroy() end) saved.ArrowAltar = nil end
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

-- Vòng lặp quét định kỳ
task.spawn(function()
    while not RadarLogic.Destroyed do
        task.wait(1.5)
        if RadarLogic.Destroyed then break end
        
        -- Tự động tắt nếu đã mở khóa Radar chính thức của game
        if checkRadarUnlocked() then
            if getgenv().Rayfield then
                getgenv().Rayfield:Notify({
                    Title = "Radar tự động tắt",
                    Content = "Phát hiện bạn đã sở hữu Radar chính thức của game. Radar custom tự động tắt!",
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
    
    -- 1. Hộp quà (Trắng, tầng thấp)
    local arrowGift = RadarLogic.SavedVisuals.ArrowGift
    if arrowGift and arrowGift.Parent then
        if RadarLogic.NearestGiftPosition then
            arrowGift.Transparency = 0
            local dir = (RadarLogic.NearestGiftPosition - hrp.Position)
            local dir2D = Vector3.new(dir.X, 0, dir.Z).Unit
            local arrowPos = hrp.Position + dir2D * 5 + Vector3.new(0, -1.0, 0)
            arrowGift.CFrame = CFrame.lookAt(arrowPos, RadarLogic.NearestGiftPosition)
        else
            arrowGift.Transparency = 1
        end
    end
    
    -- 2. Nhạc cụ (Đỏ, tầng trung)
    local arrowCadence = RadarLogic.SavedVisuals.ArrowCadence
    if arrowCadence and arrowCadence.Parent then
        if RadarLogic.NearestCadencePosition then
            arrowCadence.Transparency = 0
            local dir = (RadarLogic.NearestCadencePosition - hrp.Position)
            local dir2D = Vector3.new(dir.X, 0, dir.Z).Unit
            local arrowPos = hrp.Position + dir2D * 5 + Vector3.new(0, 0.5, 0)
            arrowCadence.CFrame = CFrame.lookAt(arrowPos, RadarLogic.NearestCadencePosition)
        else
            arrowCadence.Transparency = 1
        end
    end
    
    -- 3. Đàn tế (Cam, tầng cao)
    local arrowAltar = RadarLogic.SavedVisuals.ArrowAltar
    if arrowAltar and arrowAltar.Parent then
        if RadarLogic.NearestAltarPosition then
            arrowAltar.Transparency = 0
            local dir = (RadarLogic.NearestAltarPosition - hrp.Position)
            local dir2D = Vector3.new(dir.X, 0, dir.Z).Unit
            local arrowPos = hrp.Position + dir2D * 5 + Vector3.new(0, 2.0, 0)
            arrowAltar.CFrame = CFrame.lookAt(arrowPos, RadarLogic.NearestAltarPosition)
        else
            arrowAltar.Transparency = 1
        end
    end
end)
table.insert(RadarLogic.ActiveConnections, runConn)

return RadarLogic
