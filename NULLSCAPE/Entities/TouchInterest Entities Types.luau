-- [[
--  NULLSCAPE - TouchInterest Entities Types & Ranges Logic
--  Vai trò: Chứa toàn bộ logic định danh loại thực thể (Baby, Bell, Mart),
--  danh sách/phạm vi thực thể thuộc diện bảo vệ (TouchInterest) và các thuật toán kiểm tra
--  trạng thái TouchInterest của thực thể. Cung cấp API logic để Executor và Controller sử dụng.
-- ]]

local Logic = {}

-- Danh sách/phạm vi các thực thể cần bảo vệ
Logic.TargetNames = {
    ["Baby"] = "Baby",
    ["Bell"] = "Bell",
    ["Mart"] = "Mart",
    ["Skinwalker"] = "Skinwalker",
    ["Husk"] = "Husk"
}

-- Trả về chức năng kiểm tra trạng thái miễn nhiễm tương ứng
function Logic.getImmunityCheck(name, controller)
    if not name then return nil end
    for entityName, _ in pairs(Logic.TargetNames) do
        if string.find(name, entityName) then
            if entityName == "Baby" then
                return function() return controller.BabyImmune end
            elseif entityName == "Bell" then
                return function() return controller.BellImmune end
            elseif entityName == "Mart" then
                return function() return controller.MartImmune end
            elseif entityName == "Skinwalker" or entityName == "Husk" then
                return function() return controller.SkinwalkerImmune end
            end
        end
    end
    return nil
end

-- Kiểm tra xem một thực thể cụ thể có thuộc diện cần xử lý bảo vệ không
function Logic.isTargetEntity(name)
    if not name then return false end
    for entityName, _ in pairs(Logic.TargetNames) do
        if string.find(name, entityName) then
            return true
        end
    end
    return false
end


-- Bật miễn nhiễm (ẩn TouchInterest và tắt CanTouch) cho một thực thể cụ thể
function Logic.enableImmunity(gc, enemy)
    if not enemy then return end
    
    local isSkinwalker = string.find(enemy.Name, "Skinwalker") or string.find(enemy.Name, "Husk") or (enemy:GetAttribute("OriginalName") and (string.find(enemy:GetAttribute("OriginalName"), "Skinwalker") or string.find(enemy:GetAttribute("OriginalName"), "Husk")))
    
    if isSkinwalker then
        -- Đổi tên Model để bypass check FindFirstChild/Name của LocalScript
        if not enemy:GetAttribute("OriginalName") then
            enemy:SetAttribute("OriginalName", enemy.Name)
        end
        pcall(function()
            if not string.find(enemy.Name, "SafeWalker") then
                enemy.Name = "SafeWalker_" .. enemy.Name
            end
        end)

        -- Với Skinwalker/Husk, tắt CanTouch và đổi tên các bộ phận nhạy cảm để chặn sự kiện Touched
        for _, part in ipairs(enemy:GetDescendants()) do
            if part:IsA("BasePart") then
                if not gc.SavedPartsData[part] then
                    gc.SavedPartsData[part] = {
                        touch = nil,
                        originalCanTouch = part.CanTouch,
                        originalName = part.Name,
                        enemyName = enemy:GetAttribute("OriginalName") or enemy.Name
                    }
                end
                pcall(function() part.CanTouch = false end)
                
                -- Đổi tên đầu của Skinwalker
                if part.Name == "head" then
                    pcall(function() part.Name = "SafeHead" end)
                end
            elseif part:IsA("Decal") or part:IsA("Texture") then
                if part.Name == "sprite" then
                    if not gc.SavedPartsData[part] then
                        gc.SavedPartsData[part] = {
                            originalName = part.Name,
                            enemyName = enemy:GetAttribute("OriginalName") or enemy.Name
                        }
                    end
                    pcall(function() part.Name = "SafeSprite" end)
                end
            end
        end
    else
        -- Với Baby/Bell/Mart, tìm TouchTransmitter cụ thể
        for _, descendant in ipairs(enemy:GetDescendants()) do
            if descendant:IsA("TouchTransmitter") or descendant.Name == "TouchInterest" then
                local part = descendant.Parent
                if part and part:IsA("BasePart") then
                    if not gc.SavedPartsData[part] then
                        gc.SavedPartsData[part] = {
                            touch = descendant,
                            originalCanTouch = part.CanTouch,
                            enemyName = enemy.Name
                        }
                    end
                    pcall(function() part.CanTouch = false end)
                end
            end
        end
    end
end

function Logic.disableImmunityForType(gc, entityName)
    for part, data in pairs(gc.SavedPartsData) do
        if data and (string.find(data.enemyName, entityName) or (entityName == "Skinwalker" and string.find(data.enemyName, "Husk"))) then
            if part and part.Parent then
                if data.touch then
                    pcall(function() data.touch.Parent = part end)
                end
                pcall(function() part.CanTouch = data.originalCanTouch end)
                if data.originalName then
                    pcall(function() part.Name = data.originalName end)
                end
            end
            gc.SavedPartsData[part] = nil
        end
    end

    if entityName == "Skinwalker" then
        -- Khôi phục lại tên của Model
        local function restoreModelNames(namePattern)
            local function process(parent)
                if not parent then return end
                for _, child in ipairs(parent:GetChildren()) do
                    local originalName = child:GetAttribute("OriginalName")
                    if originalName and (string.find(originalName, namePattern) or (namePattern == "Skinwalker" and string.find(originalName, "Husk"))) then
                        pcall(function()
                            child.Name = originalName
                        end)
                        child:SetAttribute("OriginalName", nil)
                    end
                end
            end
            process(workspace:FindFirstChild("Enemies"))
            process(workspace)
        end
        restoreModelNames("Skinwalker")
    end
end

-- Khôi phục toàn bộ dữ liệu TouchInterest và dọn sạch cache
function Logic.restoreAll(gc)
    if gc.SavedPartsData then
        for part, data in pairs(gc.SavedPartsData) do
            if part and part.Parent and data then
                if data.touch then
                    pcall(function() data.touch.Parent = part end)
                end
                pcall(function() part.CanTouch = data.originalCanTouch end)
                if data.originalName then
                    pcall(function() part.Name = data.originalName end)
                end
            end
        end
        table.clear(gc.SavedPartsData)
    end

    -- Khôi phục tất cả các Model Skinwalker/Husk
    local function restoreAllModelNames()
        local function process(parent)
            if not parent then return end
            for _, child in ipairs(parent:GetChildren()) do
                local originalName = child:GetAttribute("OriginalName")
                if originalName then
                    pcall(function()
                        child.Name = originalName
                    end)
                    child:SetAttribute("OriginalName", nil)
                end
            end
        end
        process(workspace:FindFirstChild("Enemies"))
        process(workspace)
    end
    restoreAllModelNames()
end

return Logic
