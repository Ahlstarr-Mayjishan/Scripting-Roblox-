-- [[
--  NULLSCAPE - Unlock & Radar Executor
--  Thực thi các lệnh bẻ khóa nâng cấp, dọn dẹp vẽ cũ và định vị vẽ ESP/Highlight mới.
-- ]]

local Executor = {}

-- 1. Bẻ khóa nâng cấp Radar gốc của Game bằng cách thay đổi giá trị Client-Side
function Executor.spoofUpgrades(player)
    if not player then return end
    
    -- Quét tìm các Bool/Number/IntValue liên quan đến Radar/Instruments/Cadence để ép cấp độ
    local function scan(parent)
        for _, child in ipairs(parent:GetChildren()) do
            local name = child.Name:lower()
            if child:IsA("BoolValue") and (string.find(name, "radar") or string.find(name, "instrument") or string.find(name, "cadence") or string.find(name, "tracking")) then
                pcall(function() child.Value = true end)
            elseif child:IsA("NumberValue") or child:IsA("IntValue") then
                if string.find(name, "radar") or string.find(name, "instrument") or string.find(name, "cadence") or string.find(name, "tracking") then
                    pcall(function() child.Value = 99 end) -- Force cấp độ tối đa để unlock radar
                end
            end
            scan(child)
        end
    end
    scan(player)
    
    -- Tìm và ép hiển thị UI Radar gốc của Game
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("Frame") or gui:IsA("ScreenGui") then
                local name = gui.Name:lower()
                if string.find(name, "radar") or string.find(name, "cadence") or string.find(name, "tracker") then
                    pcall(function()
                        if gui:IsA("ScreenGui") then
                            gui.Enabled = true
                        else
                            gui.Visible = true
                        end
                    end)
                end
            end
        end
    end
end

-- 2. Dọn dẹp toàn bộ Highlight & Beam cũ
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

    if not keepArrows then
        for _, key in ipairs({"ArrowGift", "ArrowCadence", "ArrowAltar"}) do
            if savedVisuals[key] then
                pcall(function() savedVisuals[key]:Destroy() end)
                savedVisuals[key] = nil
            end
        end
    end
end

-- Helper để lấy hoặc tạo mũi tên chỉ hướng
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
    
    -- --- PHẦN 1: HIGHLIGHT & CHỈ ĐƯỜNG ĐẾN HỘP QUÀ GẦN NHẤT ---
    if controller.GiftESPEnabled then
        local nearestGift = nil
        local shortestDistance = math.huge
        
        -- Chỉ quét trong Workspace.Item_Pools để tối ưu hóa hiệu năng tối đa
        local itemPools = workspace:FindFirstChild("Item_Pools")
        if itemPools then
            for _, obj in ipairs(itemPools:GetDescendants()) do
                if obj:IsA("BasePart") and (string.find(obj.Name:lower(), "gift") or string.find(obj.Name:lower(), "present")) then
                    local distance = (hrp.Position - obj.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        nearestGift = obj
                    end
                end
            end
        end
        
        if nearestGift then
            controller.NearestGiftPosition = nearestGift.Position
            getOrCreateArrow(saved, "ArrowGift", Color3.fromRGB(255, 255, 255)) -- Màu trắng neon
            
            local targetModel = nearestGift.Parent:IsA("Model") and nearestGift.Parent or nearestGift
            
            -- Vẽ Highlight phát sáng màu trắng neon
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.5
            highlight.OutlineColor = Color3.fromRGB(200, 200, 200)
            highlight.OutlineTransparency = 0
            highlight.Parent = targetModel
            table.insert(saved.Highlights, highlight)
            
            -- Vẽ tia sáng Beam chỉ đường
            local att0 = Instance.new("Attachment", hrp)
            att0.Name = "GiftESP_Att0"
            table.insert(saved.Attachments, att0)
            
            local att1 = Instance.new("Attachment", nearestGift)
            att1.Name = "GiftESP_Att1"
            table.insert(saved.Attachments, att1)
            
            local beam = Instance.new("Beam")
            beam.Attachment0 = att0
            beam.Attachment1 = att1
            beam.Width0 = 0.4
            beam.Width1 = 0.4
            beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
            beam.FaceCamera = true
            beam.Parent = hrp
            table.insert(saved.Beams, beam)
        else
            controller.NearestGiftPosition = nil
            if saved.ArrowGift then
                pcall(function() saved.ArrowGift:Destroy() end)
                saved.ArrowGift = nil
            end
        end
    else
        controller.NearestGiftPosition = nil
        if saved.ArrowGift then
            pcall(function() saved.ArrowGift:Destroy() end)
            saved.ArrowGift = nil
        end
    end
    
    -- --- PHẦN 2: HIGHLIGHT & CHỈ ĐƯỜNG ĐẾN TOÀN BỘ NHẠC CỤ CADENCE ---
    if controller.CadenceESPEnabled then
        local nearestCadence = nil
        local shortestDistance = math.huge
        
        local function scanFolderForInstruments(folder)
            for _, obj in ipairs(folder:GetDescendants()) do
                if (obj:IsA("BasePart") or obj:IsA("Model")) and isInstrument(obj.Name) then
                    local targetPart = obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj
                    if targetPart and targetPart:IsA("BasePart") then
                        local distance = (hrp.Position - targetPart.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearestCadence = targetPart
                        end
                        
                        -- Vẽ Highlight phát sáng màu đỏ neon
                        local highlight = Instance.new("Highlight")
                        highlight.FillColor = Color3.fromRGB(255, 0, 0)
                        highlight.FillTransparency = 0.5
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.OutlineTransparency = 0
                        highlight.Parent = obj
                        table.insert(saved.Highlights, highlight)
                        
                        -- Vẽ tia sáng Beam chỉ đường từ người chơi tới nhạc cụ
                        local att0 = Instance.new("Attachment", hrp)
                        att0.Name = "CadenceESP_Att0"
                        table.insert(saved.Attachments, att0)
                        
                        local att1 = Instance.new("Attachment", targetPart)
                        att1.Name = "CadenceESP_Att1"
                        table.insert(saved.Attachments, att1)
                        
                        local beam = Instance.new("Beam")
                        beam.Attachment0 = att0
                        beam.Attachment1 = att1
                        beam.Width0 = 0.3
                        beam.Width1 = 0.3
                        beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
                        beam.FaceCamera = true
                        beam.Parent = hrp
                        table.insert(saved.Beams, beam)
                    end
                end
            end
        end
        
        -- Tập trung quét chỉ trong Item_Pools và Enemies để tránh giật lag FPS
        local itemPools = workspace:FindFirstChild("Item_Pools")
        if itemPools then
            scanFolderForInstruments(itemPools)
        end
        local enemies = workspace:FindFirstChild("Enemies")
        if enemies then
            scanFolderForInstruments(enemies)
        end
        
        if nearestCadence then
            controller.NearestCadencePosition = nearestCadence.Position
            getOrCreateArrow(saved, "ArrowCadence", Color3.fromRGB(255, 0, 0)) -- Màu đỏ neon
        else
            controller.NearestCadencePosition = nil
            if saved.ArrowCadence then
                pcall(function() saved.ArrowCadence:Destroy() end)
                saved.ArrowCadence = nil
            end
        end
    else
        controller.NearestCadencePosition = nil
        if saved.ArrowCadence then
            pcall(function() saved.ArrowCadence:Destroy() end)
            saved.ArrowCadence = nil
        end
    end

    -- --- PHẦN 3: HIGHLIGHT & CHỈ ĐƯỜNG ĐẾN ĐÀN TẾ (ALTAR) ---
    if controller.AltarESPEnabled then
        local nearestAltar = nil
        local shortestDistance = math.huge
        
        -- Quét dưới Workspace.CurrentRooms để tối ưu hiệu năng tối đa
        local currentRooms = workspace:FindFirstChild("CurrentRooms")
        if currentRooms then
            for _, room in ipairs(currentRooms:GetChildren()) do
                local altarObj = room:FindFirstChild("AltarLocation") or room:FindFirstChild("AltarModel") or room:FindFirstChild("Altar")
                if altarObj then
                    local targetPart = altarObj:IsA("Model") and (altarObj:FindFirstChild("HumanoidRootPart") or altarObj:FindFirstChildWhichIsA("BasePart")) or altarObj
                    if targetPart and targetPart:IsA("BasePart") then
                        local distance = (hrp.Position - targetPart.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearestAltar = targetPart
                        end
                        
                        -- Vẽ Highlight phát sáng màu cam neon
                        local highlight = Instance.new("Highlight")
                        highlight.FillColor = Color3.fromRGB(255, 128, 0)
                        highlight.FillTransparency = 0.5
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.OutlineTransparency = 0
                        highlight.Parent = altarObj
                        table.insert(saved.Highlights, highlight)
                        
                        -- Vẽ tia sáng Beam chỉ hướng tới Đàn tế (Altar)
                        local att0 = Instance.new("Attachment", hrp)
                        att0.Name = "AltarESP_Att0"
                        table.insert(saved.Attachments, att0)
                        
                        local att1 = Instance.new("Attachment", targetPart)
                        att1.Name = "AltarESP_Att1"
                        table.insert(saved.Attachments, att1)
                        
                        local beam = Instance.new("Beam")
                        beam.Attachment0 = att0
                        beam.Attachment1 = att1
                        beam.Width0 = 0.3
                        beam.Width1 = 0.3
                        beam.Color = ColorSequence.new(Color3.fromRGB(255, 128, 0))
                        beam.FaceCamera = true
                        beam.Parent = hrp
                        table.insert(saved.Beams, beam)
                    end
                end
            end
        end
        
        if nearestAltar then
            controller.NearestAltarPosition = nearestAltar.Position
            getOrCreateArrow(saved, "ArrowAltar", Color3.fromRGB(255, 128, 0)) -- Màu cam neon
        else
            controller.NearestAltarPosition = nil
            if saved.ArrowAltar then
                pcall(function() saved.ArrowAltar:Destroy() end)
                saved.ArrowAltar = nil
            end
        end
    else
        controller.NearestAltarPosition = nil
        if saved.ArrowAltar then
            pcall(function() saved.ArrowAltar:Destroy() end)
            saved.ArrowAltar = nil
        end
    end
end

return Executor
